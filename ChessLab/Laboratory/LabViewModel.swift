import ChessKit
import CStockfishKit
import Foundation
import os

/// Pilote une série de parties Stockfish contre Stockfish.
///
/// Un seul `EngineController` sert les deux camps : avant chaque coup, on
/// (re)pousse les `setoption` du camp au trait — commutation bon marché qui
/// évite un second process moteur. Toute la série tourne dans une unique
/// `Task` (consommateur unique du flux de réponses, comme le reste du
/// projet), qui met à jour l'état `@MainActor` entre les coups et
/// s'interrompt proprement à l'annulation.
@Observable
@MainActor
final class LabViewModel {
    private static let watchdogLogger = Logger(subsystem: "ChessLab", category: "engine-watchdog")

    #if DEBUG
    /// Audit du décompte : une ligne par partie terminée (résultat, raison,
    /// couleur de A, éval finale POV blancs) + un AVERTISSEMENT si le résultat
    /// contredit l'éval finale. Le Labo n'affiche que des stats agrégées ;
    /// impossible sinon de vérifier après coup qu'un gain des blancs est bien
    /// crédité aux blancs, la série enchaînant trop vite pour l'œil.
    private static let resultLogger = Logger(subsystem: "ChessLab", category: "lab-results")
    #endif

    let settings: LabGameSettings

    /// Plateau de la partie en cours (affiché en direct).
    private(set) var board: Board
    private(set) var lastMove: Move?
    private(set) var completed: [LabCompletedGame]
    private(set) var currentGameIndex: Int
    private(set) var currentPlyCount = 0
    private(set) var isRunning = false
    private(set) var isPaused = false
    private(set) var isFinished = false

    /// Éval de la partie en cours (point de vue des Blancs, en centipions).
    private(set) var currentEvalCp: Int?

    /// Courbe de progression (score cumulé de A + IC 95 %), un point par
    /// partie terminée — matérialisée plutôt que recalculée dans `body`.
    private(set) var progressPoints: [LabProgressPoint] = []

    private var engine: EngineController?
    private var runTask: Task<Void, Never>?

    /// Garde de veille (Lot 2.D). Injectable pour les tests : `UIApplication`
    /// est un état global qu'un test ne peut pas lire proprement.
    let idleTimerGuard: IdleTimerGuard

    /// Sécurité anti-partie-infinie (400 demi-coups = 200 coups).
    private let maxPlies = 400

    // MARK: Init

    /// Nouvelle série vierge.
    init(settings: LabGameSettings, idleTimerGuard: IdleTimerGuard = IdleTimerGuard()) {
        self.settings = settings
        self.idleTimerGuard = idleTimerGuard
        board = Board(position: settings.startingPosition)
        completed = []
        currentGameIndex = 0
    }

    /// Reprise d'une série interrompue (relance là où elle s'était arrêtée).
    init(resuming state: LabSeriesState, idleTimerGuard: IdleTimerGuard = IdleTimerGuard()) {
        settings = state.settings
        self.idleTimerGuard = idleTimerGuard
        board = Board(position: state.settings.startingPosition)
        completed = state.completed
        currentGameIndex = state.completed.count
        progressPoints = LabStats.progression(of: state.completed)
    }

    var stats: LabStats {
        LabStats(results: completed.map(\.labResult), plyCounts: completed.map(\.plyCount))
    }

    var progressFraction: Double {
        settings.gameCount == 0 ? 0 : Double(completed.count) / Double(settings.gameCount)
    }

    // MARK: Contrôle

    func start() {
        guard runTask == nil, !isFinished else { return }
        isRunning = true
        isPaused = false
        // Une série tourne plusieurs minutes sans qu'on touche l'écran : sans
        // ça, l'appareil s'endort et la série s'arrête au milieu (Lot 2.D).
        if settings.keepAwake { idleTimerGuard.enable() }
        runTask = Task { await runSeries() }
    }

    func togglePause() {
        isPaused.toggle()
    }

    /// Arrête la série ; les parties déjà terminées restent affichées et
    /// persistées (la partie en cours, elle, est abandonnée sans être
    /// comptée).
    func cancel() {
        // `runSeries` est le SEUL responsable du `stop()` moteur : l'annulation
        // de sa `Task` le fait sortir de sa boucle et exécuter son `await
        // controller.stop()` final. On évite ainsi un second `stop()` concurrent
        // sur l'acteur (fragile si `stop()` devenait non idempotent côté
        // ChessKitEngine). Voir instructions.md §B4.
        //
        // `runTask`/`isRunning` ne sont PAS remis à zéro ici : la boucle peut
        // mettre plusieurs secondes à se terminer (recherche en cours +
        // `stop()`), et pendant cette fenêtre un `runTask == nil` laisserait
        // `start()` lancer une SECONDE série concurrente — deux moteurs, états
        // entremêlés, et le `runTask = nil` final de l'ancienne boucle rendrait
        // la nouvelle inannulable. C'est `runSeries` qui les remet à zéro,
        // à sa fin réelle.
        runTask?.cancel()
        isPaused = false
        // Dès l'annulation, pas seulement à la fin réelle de la boucle : le
        // moteur peut mettre plusieurs secondes à s'arrêter, l'appareil n'a
        // aucune raison de rester éveillé pendant ce temps.
        idleTimerGuard.disable()
    }

    func handleViewDisappear() {
        cancel()
        // Ceinture ET bretelles : `cancel()` le fait déjà, mais laisser fuiter
        // `isIdleTimerDisabled = true` donnerait un appareil qui ne s'endort
        // plus longtemps après qu'on a quitté l'écran.
        idleTimerGuard.disable()
    }

    // MARK: Boucle de série

    private func runSeries() async {
        let controller = EngineController()
        engine = controller
        // Passe par le moniteur thermique comme les autres modes : une série
        // tourne plusieurs minutes d'affilée, c'est précisément le cas où
        // l'appareil chauffe et où s'obstiner à pleins threads ralentit tout.
        //
        // Succès VÉRIFIÉ, contrairement à avant : `computeBestMove` écrit vers
        // le moteur, et écrire dans un moteur qui n'a pas démarré (NNUE absent,
        // mémoire) segfaute ChessKitEngine. Play et Analyse gardaient déjà ce
        // cas ; le Laboratoire fonçait dans la boucle et faisait planter l'app.
        // On saute la série plutôt que d'écrire dans un moteur mort.
        let started = await controller.start(
            threads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads),
            hashMB: AppSettings.engineHashMB, multipv: 1
        )

        // Le(s) camp(s) Maia : un seul modèle pour la série, chargé hors du
        // MainActor. S'il manque, le camp joue Stockfish bridé à sa consigne
        // (même repli que le mode Jouer) — et la série le dit.
        var maia: MaiaOpponent?
        if settings.usesMaia {
            maia = await Task.detached(priority: .userInitiated) { MaiaOpponent() }.value
            if maia == nil {
                Self.watchdogLogger.warning("Modèle Maia-3 introuvable : le camp personnage joue Stockfish bridé")
            }
        }

        if started {
            // Budget d'essais : une partie interrompue par un raté moteur n'est
            // PAS enregistrée (sinon elle fausserait les stats en fausse nulle),
            // elle est simplement rejouée — `completed.count` n'ayant pas avancé,
            // la boucle repart sur le même index. Le budget borne le nombre total
            // de tentatives pour éviter une boucle infinie si le moteur ne répond
            // plus (cas catastrophique : la série s'arrête proprement, sans
            // fausse partie).
            let maxAttempts = settings.gameCount * 2 + 4
            var attempts = 0
            while completed.count < settings.gameCount, attempts < maxAttempts, !Task.isCancelled {
                attempts += 1
                let outcome = await playOneGame(engine: controller, maia: maia, gameIndex: completed.count)
                if Task.isCancelled { break }

                switch outcome {
                case .completed:
                    currentGameIndex = completed.count
                    progressPoints = LabStats.progression(of: completed)
                    LabAutosaveStore.save(LabSeriesState(settings: settings, completed: completed, savedAt: Date()))
                case .interrupted:
                    // Raté moteur (aucun coup rendu à l'échéance, ou coup
                    // inapplicable) : la partie n'est pas enregistrée et sera
                    // rejouée — sur une instance REDÉMARRÉE. Rejouer sur un
                    // moteur resté muet brûlerait tout le budget d'essais, à
                    // ~9 s d'attente la tentative. `os_log` et surtout pas
                    // `print` : stdout est le canal UCI de ChessKitEngine.
                    Self.watchdogLogger.warning(
                        "Partie \(self.completed.count) interrompue (moteur muet ?) — redémarrage puis nouvelle tentative"
                    )
                    let restarted = await controller.restart(
                        coreCount: EngineController.coreCount(
                            forThreads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads)
                        ),
                        multipv: 1,
                        setupCommands: [.setoption(id: "Hash", value: "\(AppSettings.engineHashMB)")]
                    )
                    guard restarted else {
                        // Un redémarrage raté laissait la boucle continuer sur un
                        // moteur mort jusqu'à épuiser `maxAttempts` en silence — la
                        // série s'arrêtait sans jamais l'annoncer. Trouvé lors de
                        // la revue du 25/08/2026.
                        Self.watchdogLogger.warning("Redémarrage du moteur impossible — série interrompue")
                        break
                    }
                }
            }
        } else {
            Self.watchdogLogger.warning("Moteur indisponible au démarrage de la série Laboratoire — série non lancée")
        }

        await controller.stop()
        engine = nil
        runTask = nil
        isRunning = false
        idleTimerGuard.disable()
        if completed.count >= settings.gameCount {
            isFinished = true
        }
    }

    /// Un coup de personnage au Laboratoire : Maia, puis le MÊME filet que le
    /// mode Jouer (``MaiaTurnResolver``), avec les budgets de la série.
    /// `nil` si Maia n'a pas répondu — l'appelant retombe sur Stockfish
    /// bridé, comme le mode Jouer.
    private func maiaTurn(
        engine: EngineController, maia: MaiaOpponent, profile: OpponentProfile,
        positions: [Position], level: Int, targetElo: Double?, opponentLevel: Int, strength: EngineStrength
    ) async -> (lan: String, moverCp: Int?)? {
        let choice: MaiaOpponent.Choice?
        do {
            choice = try await maia.chooseMove(
                history: positions, board: board,
                selfElo: targetElo ?? Double(level), oppoElo: Double(opponentLevel),
                temperature: profile.temperature, topP: profile.topP
            )
        } catch {
            choice = nil
        }
        guard let choice else { return nil }

        let quickBudget = Int(Double(settings.movetimeMs) * ThermalMonitor.shared.movetimeFactor)
        let quick = await engine.computeBestMove(
            fen: board.position.fen, setupCommands: EngineStrength.maximum.setupCommands,
            movetimeMs: quickBudget, depth: nil
        )
        let decision = MaiaTurnResolver.resolve(
            maiaUCI: choice.uci,
            quick: quick.map { MaiaTurnResolver.QuickSearch(lan: $0.lan, cp: $0.moverCp, mate: $0.moverMate) },
            level: level, pieceCount: board.position.pieces.count,
            policy: profile.safetyNet, board: board
        )
        switch decision {
        case let .play(lan):
            return (lan, quick?.moverCp)
        case let .override(lan, _):
            return (lan, quick?.moverCp)
        case .searchBridled:
            let bridled = await engine.computeBestMove(
                fen: board.position.fen, setupCommands: strength.setupCommands,
                movetimeMs: strength.maxDepth == nil ? quickBudget : nil, depth: strength.maxDepth
            )
            guard let bridled else { return (choice.uci, quick?.moverCp) }
            return (bridled.lan, bridled.moverCp ?? quick?.moverCp)
        }
    }

    /// Issue d'une partie du Laboratoire.
    private enum GameLoopOutcome {
        /// Partie menée à une vraie fin (règles, adjudication, ou plafond de
        /// coups) et enregistrée dans `completed`.
        case completed
        /// Le moteur n'a pas rendu de coup exploitable — rien n'est
        /// enregistré, l'appelant rejoue.
        case interrupted
    }

    private func playOneGame(engine: EngineController, maia: MaiaOpponent?, gameIndex: Int) async -> GameLoopOutcome {
        let aWhite = !settings.alternateColors || gameIndex.isMultiple(of: 2)

        board = Board(position: settings.startingPosition)
        lastMove = nil
        currentPlyCount = 0
        currentEvalCp = nil
        // L'historique dont Maia a besoin (voir ``MaiaEncoder``).
        var positions: [Position] = [board.position]

        var game = Game(startingWith: settings.startingPosition)
        var gameIndexNode = game.startingIndex
        await engine.send(.ucinewgame)

        var sanPath: [String] = []
        var whiteEvalHistory: [Int] = []
        var end: GameEnd? = terminalEnd(for: board.state)

        while end == nil, currentPlyCount < maxPlies, !Task.isCancelled {
            while isPaused, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            if Task.isCancelled { return .interrupted }

            let mover = board.position.sideToMove
            let moverIsA = (mover == .white) == aWhite
            let strength = moverIsA ? settings.sideAStrength : settings.sideBStrength
            let bookEnabled = moverIsA ? settings.sideABookEnabled : settings.sideBBookEnabled
            let profile = moverIsA ? settings.sideAProfile : settings.sideBProfile

            var moveLAN: String?
            var whiteEval: Int?

            if bookEnabled,
               let san = OpeningBookEngine.pickNextMove(book: OpeningBookLoader.standard, sanPath: sanPath, width: settings.bookWidth),
               let bookMove = Move(san: san, position: board.position) {
                moveLAN = bookMove.lan
            } else if let profile, let maia,
                      let turn = await maiaTurn(
                          engine: engine, maia: maia, profile: profile, positions: positions,
                          level: Int((moverIsA ? settings.sideAEloSlider : settings.sideBEloSlider).rounded()),
                          targetElo: moverIsA ? settings.sideAMaiaTargetElo : settings.sideBMaiaTargetElo,
                          opponentLevel: Int((moverIsA ? settings.sideBEloSlider : settings.sideAEloSlider).rounded()),
                          strength: strength
                      ) {
                if Task.isCancelled { return .interrupted }
                moveLAN = turn.lan
                if let moverCp = turn.moverCp {
                    whiteEval = mover == .white ? moverCp : -moverCp
                }
            } else {
                // Toute la recherche + consommation du flux se fait sur
                // l'acteur moteur (hors MainActor) : un seul `await` ici, le
                // fil principal reste libre pour l'UI pendant le calcul.
                // Surchauffe : moitié moins de temps par coup (Lot 2.C). Une
                // série, c'est des centaines de recherches à la suite — le
                // scénario qui fait le plus chauffer l'appareil.
                let movetime = strength.maxDepth == nil
                    ? Int(Double(settings.movetimeMs) * ThermalMonitor.shared.movetimeFactor)
                    : nil
                let result = await engine.computeBestMove(
                    fen: board.position.fen,
                    setupCommands: strength.setupCommands,
                    movetimeMs: movetime,
                    depth: strength.maxDepth
                )
                if Task.isCancelled { return .interrupted }
                moveLAN = result?.lan
                if let moverCp = result?.moverCp {
                    whiteEval = mover == .white ? moverCp : -moverCp
                }
            }

            // Raté moteur (aucun coup rendu, ou coup illégal) : on interrompt
            // cette partie SANS l'enregistrer — l'appelant la rejoue. Ne pas
            // la confondre avec le plafond de coups (vraie « partie trop
            // longue », traité après la boucle).
            guard let lan = moveLAN, let applied = apply(lan: lan) else {
                return .interrupted
            }
            gameIndexNode = game.make(move: applied, from: gameIndexNode)
            lastMove = applied
            sanPath.append(applied.san)
            positions.append(board.position)
            currentPlyCount += 1
            if let whiteEval {
                currentEvalCp = whiteEval
                whiteEvalHistory.append(whiteEval)
            }

            // Respiration UI + rythme de visualisation.
            if settings.liveVisualization {
                try? await Task.sleep(nanoseconds: 90_000_000)
            } else {
                await Task.yield()
            }

            // Les fins selon les règles (mat, pat, matériel insuffisant,
            // 50 coups, répétition) priment et s'appliquent toujours ;
            // abandon / nulle par accord ne s'ajoutent que si autorisés.
            end = terminalEnd(for: board.state)
            if end == nil {
                end = resignationOrAgreedDraw(whiteEvalHistory, ply: currentPlyCount)
            }
        }

        if Task.isCancelled { return .interrupted }

        // Sortie de boucle sans fin détectée ⇒ plafond de coups réellement
        // atteint : vraie nulle « partie trop longue » (à distinguer d'un
        // raté moteur, déjà renvoyé en `.interrupted` plus haut).
        let finalEnd = end ?? GameEnd(pgnResult: "1/2-1/2", reasonLabel: "Partie trop longue")

        #if DEBUG
        // Audit du décompte. `finalWhiteEval` est POV blancs (la même échelle
        // que la barre). Sur une fin DÉCISIVE, résultat et éval finale sont
        // posés au même demi-coup et doivent avoir le même signe : un « 1-0 »
        // (blancs) avec une éval finale nettement négative — ou l'inverse —
        // serait l'inversion suspectée (« barre blanche mais point aux noirs »).
        let finalWhiteEval = whiteEvalHistory.last ?? 0
        Self.resultLogger.debug(
            "Partie \(gameIndex, privacy: .public) → \(finalEnd.pgnResult, privacy: .public) (\(finalEnd.reasonLabel, privacy: .public)) | A=\(aWhite ? "Blancs" : "Noirs", privacy: .public) | éval finale blancs=\(finalWhiteEval, privacy: .public)"
        )
        let resultsContradictEval =
            (finalEnd.pgnResult == "1-0" && finalWhiteEval <= -200)
            || (finalEnd.pgnResult == "0-1" && finalWhiteEval >= 200)
        if resultsContradictEval {
            Self.resultLogger.warning(
                "⚠️ INCOHÉRENCE décompte : résultat \(finalEnd.pgnResult, privacy: .public) mais éval finale blancs=\(finalWhiteEval, privacy: .public)"
            )
        }
        #endif

        completed.append(
            LabCompletedGame(
                index: gameIndex,
                aWasWhite: aWhite,
                pgnResult: finalEnd.pgnResult,
                reasonLabel: finalEnd.reasonLabel,
                plyCount: currentPlyCount,
                pgn: PGNExport.pgn(for: game)
            )
        )
        return .completed
    }

    // MARK: Fin de partie

    private struct GameEnd {
        let pgnResult: String
        let reasonLabel: String
    }

    private func terminalEnd(for state: Board.State) -> GameEnd? {
        guard let outcome = GameOutcome.fromBoardState(state) else { return nil }
        let reason: String
        switch outcome.reason {
        case .checkmate: reason = "Mat"
        case let .draw(drawReason): reason = drawReason.displayLabel.capitalizedFirst
        default: reason = "Nulle"
        }
        return GameEnd(pgnResult: outcome.pgnResult, reasonLabel: reason)
    }

    /// Abandon et nulle par accord, chacun conditionné à son réglage.
    /// Nulle par accord : éval proche de 0 sur une fenêtre prolongée après
    /// un minimum de coups. Abandon : un camp mène de ≥ 8 pions sur une
    /// fenêtre prolongée, l'autre abandonne. Seuils fixes (compromis
    /// raisonnable documenté ; le brief les prévoit configurables — reporté).
    private func resignationOrAgreedDraw(_ whiteEvals: [Int], ply: Int) -> GameEnd? {
        let drawWindow = 10
        let winWindow = 6
        if settings.drawAgreementEnabled, ply >= 60, whiteEvals.count >= drawWindow {
            let recent = whiteEvals.suffix(drawWindow)
            if recent.allSatisfy({ abs($0) <= 15 }) {
                return GameEnd(pgnResult: "1/2-1/2", reasonLabel: "Nulle par accord")
            }
        }
        if settings.resignationEnabled, whiteEvals.count >= winWindow {
            let recent = whiteEvals.suffix(winWindow)
            if recent.allSatisfy({ $0 >= 800 }) {
                return GameEnd(pgnResult: "1-0", reasonLabel: "Abandon")
            }
            if recent.allSatisfy({ $0 <= -800 }) {
                return GameEnd(pgnResult: "0-1", reasonLabel: "Abandon")
            }
        }
        return nil
    }

    /// Applique un coup en notation LAN moteur au plateau en cours (le mute
    /// en place, ce qui rafraîchit l'affichage) et renvoie le `Move` appliqué
    /// pour l'ajouter à la partie ChessKit.
    private func apply(lan: String) -> Move? {
        guard lan.count >= 4 else { return nil }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        guard let move = board.move(pieceAt: start, to: end) else { return nil }
        if case .promotion = board.state {
            let kind: Piece.Kind = lan.count == 5
                ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                : .queen
            return board.completePromotion(of: move, to: kind)
        }
        return move
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
