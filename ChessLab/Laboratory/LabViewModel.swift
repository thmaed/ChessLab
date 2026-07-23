import ChessKit
import ChessKitEngine
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
        let controller = EngineController(type: .stockfish)
        engine = controller
        // Passe par le moniteur thermique comme les autres modes : une série
        // tourne plusieurs minutes d'affilée, c'est précisément le cas où
        // l'appareil chauffe et où s'obstiner à pleins threads ralentit tout.
        await controller.start(
            threads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads),
            hashMB: AppSettings.engineHashMB, multipv: 1
        )

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
            let outcome = await playOneGame(engine: controller, gameIndex: completed.count)
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
                await controller.restart(
                    coreCount: EngineController.coreCount(
                        forThreads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads)
                    ),
                    multipv: 1,
                    setupCommands: [.setoption(id: "Hash", value: "\(AppSettings.engineHashMB)")]
                )
            }
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

    /// Issue d'une partie du Laboratoire.
    private enum GameLoopOutcome {
        /// Partie menée à une vraie fin (règles, adjudication, ou plafond de
        /// coups) et enregistrée dans `completed`.
        case completed
        /// Le moteur n'a pas rendu de coup exploitable — rien n'est
        /// enregistré, l'appelant rejoue.
        case interrupted
    }

    private func playOneGame(engine: EngineController, gameIndex: Int) async -> GameLoopOutcome {
        let aWhite = !settings.alternateColors || gameIndex.isMultiple(of: 2)

        board = Board(position: settings.startingPosition)
        lastMove = nil
        currentPlyCount = 0
        currentEvalCp = nil

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

            var moveLAN: String?
            var whiteEval: Int?

            if bookEnabled,
               let san = OpeningBookEngine.pickNextMove(book: OpeningBookLoader.standard, sanPath: sanPath, width: settings.bookWidth),
               let bookMove = Move(san: san, position: board.position) {
                moveLAN = bookMove.lan
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
