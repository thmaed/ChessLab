import ChessKit
import Foundation
import Observation

/// Revue d'une partie Chess960 TERMINÉE : rejouer coup par coup, avec
/// l'évaluation, les meilleurs coups et les pastilles de qualité de la
/// position affichée — même style que ``AnalysisViewModel`` : une passe
/// RAPIDE classe toute la ligne principale dès l'ouverture, puis se met en
/// cache (25/08, second lot).
///
/// Volontairement ALLÉGÉ par rapport à ``AnalysisViewModel`` : pas de bandeau
/// coach (texte expliquant le POURQUOI), pas d'affinage ×10 des verdicts
/// limites, ni génération de puzzles, ni bibliothèque persistée. Ces
/// derniers exploitent en profondeur l'infrastructure ChessKit existante
/// (types `Move.Assessment`, modèles SwiftData `GameRecord`/`Puzzle`…) qu'un
/// portage complet au Chess960 demanderait de récrire ou de dupliquer
/// entièrement — chantier à part, hors de portée de cette session.
@Observable
@MainActor
final class Chess960AnalysisViewModel {

    private(set) var startFEN: String
    private(set) var sanLog: [String] = []
    private(set) var uciLog: [String] = []
    private(set) var displaySquaresLog: [(from: Square, to: Square)] = []
    /// Coup Chess960 résolu à chaque ply — même longueur que ``uciLog``.
    private var moveLog: [Chess960Game.Move] = []
    /// En-têtes du PGN d'origine — noms des joueurs, résultat.
    let tags: Game.Tags

    /// Qualité de chaque coup de la ligne principale, clé = demi-coup
    /// (1 = premier coup) — rempli par ``classifyMainLine()``.
    private(set) var moveQuality: [Int: MoveQuality] = [:]
    private(set) var isClassifying = false
    private(set) var classificationProgress: (done: Int, total: Int)?

    private(set) var displayedPly: Int = 0
    private(set) var displayedGame: Chess960Game

    private(set) var currentEvalCp: Int?
    private(set) var currentEvalMate: Int?
    var hintMoves: [HintMove] = []
    private(set) var isAnalyzing = false

    private let engine = EngineController()
    private var engineQueue: Task<Void, Never> = Task {}
    /// Jeton de fraîcheur : une analyse dont le jeton ne correspond plus à
    /// `analysisToken` au moment de conclure est jetée — même principe que
    /// la comparaison de FEN de ``Chess960PlayViewModel/updateEvalBar()``,
    /// mais nécessaire ICI en plus des deux (la navigation peut changer
    /// `displayedPly` plusieurs fois avant qu'une analyse ne conclue).
    private var analysisToken = 0

    /// `nil` si le PGN n'a pas de position Chess960 reconnaissable — voir
    /// ``Chess960PGNParser``.
    init?(pgn: String) {
        guard let parsed = Chess960PGNParser.parse(pgn) else { return nil }
        let ucis = parsed.moves.map(\.uci)
        startFEN = parsed.startFEN
        sanLog = parsed.moves.map(\.san)
        uciLog = ucis
        tags = parsed.tags

        var game = Chess960Game(fen: parsed.startFEN)!
        var squares: [(from: Square, to: Square)] = []
        var moves: [Chess960Game.Move] = []
        for uci in ucis {
            // Résout le coup joué à ce ply — pas seulement son UCI — pour que
            // la classification puisse s'appuyer sur ``MoveClassifier``
            // (sacrifice, coup forcé…) sans le reconstruire une seconde fois.
            guard let move = game.legalMoves().first(where: { game.uciFor($0) == uci }) else { break }
            moves.append(move)
            if let s = game.displaySquares(forUCI: uci) { squares.append(s) }
            _ = game.apply(move)
        }
        displaySquaresLog = squares
        moveLog = moves
        // Ouvre sur le DÉBUT de la partie (demande du 25/08) : `game` a été
        // mutée jusqu'à la fin par la boucle ci-dessus, pour construire
        // ``displaySquaresLog``/``moveLog`` — il faut donc une position
        // fraîche pour l'affichage initial, pas celle-là.
        displayedGame = Chess960Game(fen: parsed.startFEN)!
        displayedPly = 0
    }

    func start() {
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            guard await self.engine.start() else { return }
            await self.engine.send(.setoption(id: "UCI_Chess960", value: "true"))
        }
        // Enfilée AVANT toute salve d'indices : la file est sérielle (FIFO),
        // donc la classification passe la première — exactement l'ordre de
        // ``AnalysisViewModel/setupEngine()``. `classifyMainLine()` se charge
        // ELLE-MÊME de montrer l'éval de la position affichée une fois finie
        // (en cache, sans nouvelle salve) — voir
        // ``showCurrentCachedEvalOrRefresh()``.
        classifyMainLine()
    }

    func handleViewDisappear() {
        engineQueue.cancel()
        Task { [engine] in await engine.stop() }
    }

    // MARK: Navigation

    var totalPlies: Int { uciLog.count }

    func review(toPly ply: Int) {
        let clamped = max(0, min(ply, uciLog.count))
        guard clamped != displayedPly else { return }
        displayedPly = clamped
        var game = Chess960Game(fen: startFEN)!
        for uci in uciLog.prefix(clamped) { _ = game.apply(uci: uci) }
        displayedGame = game
        // La classification a déjà évalué CHAQUE position de la ligne
        // principale : pas de nouvelle salve moteur pour un aller-retour dans
        // des coups déjà classés, seulement pour une position hors de cette
        // couverture (classification encore en cours, ou incomplète).
        showCurrentCachedEvalOrRefresh()
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }

    var numberedMoves: [(number: Int, white: String, black: String?)] {
        stride(from: 0, to: sanLog.count, by: 2).map { index in
            (index / 2 + 1, sanLog[index], index + 1 < sanLog.count ? sanLog[index + 1] : nil)
        }
    }

    /// Coup qui mène à la position affichée — même convention que
    /// ``Chess960PlayViewModel/displayedLastMove``.
    var displayedLastMove: Move? {
        guard displayedPly > 0, displayedPly <= displaySquaresLog.count else { return nil }
        let squares = displaySquaresLog[displayedPly - 1]
        guard let piece = displayedGame.board.position.piece(at: squares.to) else { return nil }
        return Move(result: .move, piece: piece, start: squares.from, end: squares.to)
    }

    var displayedFEN: String { displayedGame.shredderFEN }

    /// Pastille à poser sur le plateau : la qualité du coup affiché, sur sa
    /// case d'arrivée RÉELLE (``displayedLastMove``, déjà corrigée pour le
    /// roque) — même contrat que ``AnalysisViewModel/qualityBadge``.
    var qualityBadge: (square: Square, quality: MoveQuality)? {
        guard displayedPly > 0, let quality = moveQuality[displayedPly],
              let lastMove = displayedLastMove
        else { return nil }
        return (lastMove.end, quality)
    }

    // MARK: Analyse de la position affichée

    private func enqueueEngineWork(_ work: @escaping () async -> Void) {
        let previous = engineQueue
        engineQueue = Task {
            _ = await previous.value
            await work()
        }
    }

    /// Relance l'évaluation et les flèches pour la position COURANTE — à
    /// chaque pas de la navigation. Salve bornée, même discipline que
    /// ``Chess960PlayViewModel/startHintAnalysis()`` : jamais de flux moteur
    /// consommé par deux lecteurs à la fois, un résultat obsolète est jeté
    /// plutôt qu'annulé activement.
    private static let analysisBudgetMs = 1500

    private func refreshAnalysis() {
        analysisToken += 1
        let token = analysisToken
        currentEvalCp = nil
        currentEvalMate = nil
        hintMoves = []
        let fen = displayedGame.shredderFEN
        let mover = displayedGame.board.position.sideToMove

        enqueueEngineWork { [weak self] in
            guard let self else { return }
            self.isAnalyzing = true
            defer { self.isAnalyzing = false }

            await self.engine.synchronize()
            // S'abonner AVANT d'envoyer : un abonné ne reçoit que ce qui suit
            // son abonnement (voir ``EngineController/responseStream``) — lu
            // APRÈS le `go`, un `bestmove` rapide se perdait sous charge.
            let responses = await self.engine.responseStream
            await self.engine.send(.setoption(id: "MultiPV", value: "3"))
            await self.engine.send(.position(.fen(fen)))
            await self.engine.send(.go(movetime: Self.analysisBudgetMs))

            let search = await EngineWatchdog.run(deadlineMs: Self.analysisBudgetMs + EngineWatchdog.graceMs) { [engine = self.engine] in
                var lanByRank: [Int: String] = [:]
                // Encodage ±10 000 pour `HintMoveBuilder` (flèches) — voir sa
                // doc : un mat doit rester COMPARABLE aux centipions pour
                // classer les rangs entre eux.
                var scoreByRank: [Int: Double] = [:]
                // Score BRUT de la ligne 1, pour la barre d'éval — mat et
                // centipions restent SÉPARÉS, comme
                // ``Chess960PlayViewModel/updateEvalBar()``.
                var bestCp: Int?
                var bestMate: Int?
                for await response in responses {
                    switch response {
                    case let .info(info):
                        if (info.multipv ?? 1) == 1 {
                            if let mate = EngineScore.mateInMoves(info) {
                                bestMate = mate; bestCp = nil
                            } else if let cp = EngineScore.moverCentipawns(info) {
                                bestCp = cp; bestMate = nil
                            }
                        }
                        if let rank = info.multipv, let firstMove = info.pv?.first {
                            lanByRank[rank] = firstMove
                            if let mate = info.score?.mate {
                                scoreByRank[rank] = mate > 0 ? 10_000 - Double(mate) : -10_000 - Double(mate)
                            } else if let cp = info.score?.cp {
                                scoreByRank[rank] = cp
                            }
                        }
                    case .bestmove:
                        return (lanByRank, scoreByRank, bestCp, bestMate)
                    default:
                        break
                    }
                }
                return (lanByRank, scoreByRank, bestCp, bestMate)
            }
            await self.engine.send(.setoption(id: "MultiPV", value: "1"))

            guard case let .finished((lanByRank, scoreByRank, bestCp, bestMate)) = search,
                  token == self.analysisToken, fen == self.displayedGame.shredderFEN
            else { return }

            if let bestCp {
                self.currentEvalCp = mover == .white ? bestCp : -bestCp
                self.currentEvalMate = nil
            } else if let bestMate {
                self.currentEvalMate = mover == .white ? bestMate : -bestMate
                self.currentEvalCp = nil
            }
            self.hintMoves = HintMoveBuilder.build(lanByRank: lanByRank, scoreByRank: scoreByRank)
                .map { self.remappedForCastle($0) }
        }
    }

    private func remappedForCastle(_ hint: HintMove) -> HintMove {
        guard let squares = displayedGame.displaySquares(forUCI: hint.from.notation + hint.to.notation),
              squares.to != hint.to
        else { return hint }
        return HintMove(rank: hint.rank, from: hint.from, to: squares.to, strength: hint.strength,
                        kind: hint.kind, tint: hint.tint)
    }

    /// Montre l'éval de ``displayedPly`` depuis ``evalCache`` si la
    /// classification l'a déjà couverte, sinon retombe sur une salve
    /// ponctuelle (``refreshAnalysis()``) — le seul cas où une position de la
    /// ligne principale n'est PAS en cache : la classification n'y est pas
    /// encore arrivée, ou s'est arrêtée en route (moteur muet).
    private func showCurrentCachedEvalOrRefresh() {
        if let cached = evalCache[displayedPly] {
            showCachedEval(cached)
        } else {
            refreshAnalysis()
        }
    }

    /// Affiche une éval déjà connue SANS toucher le moteur — c'est tout
    /// l'intérêt de la classification eager : naviguer dans une partie déjà
    /// classée ne recalcule plus rien.
    private func showCachedEval(_ cached: RankedEval) {
        // Invalide toute salve encore en vol pour une position antérieure —
        // même jeton de fraîcheur que ``refreshAnalysis()``.
        analysisToken += 1
        currentEvalCp = cached.mateWhite == nil ? cached.cpWhite : nil
        currentEvalMate = cached.mateWhite

        if !cached.scoreByRank.isEmpty {
            // Cas courant (position classée CETTE session) : les deux rangs
            // MultiPV sont connus en centipions, comme une salve fraîche —
            // vert « reviewBest » plutôt que le gris de l'analyse live, voir
            // ``HintMove/Kind``.
            hintMoves = HintMoveBuilder.build(lanByRank: cached.lanByRank, scoreByRank: cached.scoreByRank)
                .map { remappedForCastle($0) }
                .map { HintMove(rank: $0.rank, from: $0.from, to: $0.to, strength: $0.strength, kind: .reviewBest) }
        } else if let bestLan = cached.lanByRank[1], bestLan.count >= 4 {
            // Cas d'un instantané rechargé du DISQUE (relance de l'app) :
            // seul le meilleur coup a survécu à la sérialisation (voir
            // ``AnalysisEvalStore.PositionEval``, qui ne porte pas de score
            // en centipions par rang) — une seule flèche plutôt qu'un
            // classement approximatif entre deux coups.
            let start = Square(String(bestLan.prefix(2)))
            let end = Square(String(bestLan.dropFirst(2).prefix(2)))
            hintMoves = [remappedForCastle(HintMove(rank: 1, from: start, to: end, strength: 1, kind: .reviewBest))]
        } else {
            hintMoves = []
        }
    }

    // MARK: Classification (pastilles) — passe rapide, une fois, toute la ligne

    /// Éval d'une position. Alimente à la fois la classification (pastilles)
    /// ET la navigation (barre d'éval + flèches SANS repasser par le
    /// moteur) — voir ``evalCache``, ``showCachedEval(_:)``.
    private struct RankedEval {
        /// POV BLANCS — même convention que ``currentEvalCp``.
        var cpWhite: Int
        var mateWhite: Int?
        var winPercentWhite: Double
        /// UCI par rang (1 = meilleur), POV DU TRAIT. Un instantané
        /// RECHARGÉ DU DISQUE ne porte que le rang 1 (voir
        /// ``AnalysisEvalStore.PositionEval``, qui ne persiste pas de score
        /// par rang) — ``scoreByRank`` reste alors vide, signal pour
        /// ``showCachedEval(_:)`` de n'afficher qu'une flèche.
        var lanByRank: [Int: String]
        /// Score en centipions par rang, POV DU TRAIT — la même convention
        /// que ``refreshAnalysis()`` passe à ``HintMoveBuilder``.
        var scoreByRank: [Int: Double]
        /// Écart de probabilité de gain (POV du trait) entre le 1er et le
        /// 2e choix — ce qu'attend ``MoveClassifier/Input``.
        var gapToSecondBestWinPercent: Double?
    }

    /// Éval de CHAQUE position déjà rencontrée (classification ou salve
    /// ponctuelle), clé = demi-coup (0 = position de départ) — permet à la
    /// navigation de ne JAMAIS rappeler le moteur pour un coup déjà couvert.
    private var evalCache: [Int: RankedEval] = [:]

    private static let classificationMultiPV = 2
    /// Le budget partagé (``DevicePerformance/classificationNodeBudget``)
    /// est calibré pour la revue standard ; Chess960 se le permet un peu
    /// plus profond (demande du 25/08) sans toucher au budget partagé, qui
    /// reste celui du mode normal.
    private static let classificationNodeMultiplier = 1.3

    /// Convertit un coup Chess960 (``Chess960Game/Move``, un simple couple
    /// cases/promotion) en `Move` ChessKit — le type qu'attend
    /// ``MoveClassifier``. `board` est la position AVANT ce coup. `nil` pour
    /// un roque : aucun `Move.Result` ChessKit ne représente le dialecte
    /// roi-prend-tour, et un roque ne sacrifie de toute façon jamais rien.
    private static func chessKitMove(for move: Chess960Game.Move, board: Board) -> Move? {
        guard case let .ordinary(from, to, _) = move,
              let piece = board.position.piece(at: from)
        else { return nil }
        let result: Move.Result = board.position.piece(at: to).map { .capture($0) } ?? .move
        return Move(result: result, piece: piece, start: from, end: to)
    }

    /// Classe toute la ligne principale, séquentiellement, une seule fois —
    /// même discipline que ``AnalysisViewModel/classifyMainLine()`` : un seul
    /// `EngineController`, la file sérielle existante, lecture manuelle du
    /// flux (jamais `computeBestMove`). Budget RAPIDE et fixe
    /// (``DevicePerformance/classificationNodeBudget``, MultiPV 2) — pas
    /// d'affinage ×10 des verdicts limites, pas de livre d'ouvertures (aucun
    /// sens en Chess960) : décision du 25/08, second lot, « aller vite ».
    private func classifyMainLine() {
        guard !moveLog.isEmpty,
              let key = AnalysisEvalStore.key(startFEN: startFEN, lans: uciLog)
        else {
            // Rien à classer (parseur qui n'a résolu aucun coup) : afficher
            // quand même la position, comme le mode normal démarrerait son
            // analyse en continu sur une FEN sans historique.
            showCurrentCachedEvalOrRefresh()
            return
        }

        enqueueEngineWork { [weak self] in
            guard let self else { return }

            if let cached = AnalysisEvalStore.load(key: key, profile: AnalysisEvalStore.chess960Profile) {
                for (ply, verdict) in cached.verdicts {
                    guard let quality = MoveQuality(rawValue: verdict.quality) else { continue }
                    self.moveQuality[ply] = quality
                }
                for (ply, positionEval) in cached.evals {
                    self.evalCache[ply] = RankedEval(
                        cpWhite: Int((positionEval.pawns * 100).rounded()),
                        mateWhite: nil,
                        winPercentWhite: positionEval.winPercent,
                        lanByRank: positionEval.bestLan.map { [1: $0] } ?? [:],
                        scoreByRank: [:],
                        gapToSecondBestWinPercent: positionEval.gapToSecondBest
                    )
                }
                self.showCurrentCachedEvalOrRefresh()
                return
            }

            self.isClassifying = true
            self.classificationProgress = (done: 0, total: self.moveLog.count)

            var game = Chess960Game(fen: self.startFEN)!
            var verdicts: [Int: AnalysisEvalStore.MoveVerdict] = [:]

            for (i, move) in self.moveLog.enumerated() {
                let ply = i + 1
                let mover = game.board.position.sideToMove
                let isForced = game.legalMoves().count == 1
                let boardBeforeMove = game.board
                guard let before = await self.rankedEval(at: i, game: game) else { break }

                _ = game.apply(move)
                let boardAfterMove = game.board
                guard let after = await self.rankedEval(at: ply, game: game) else { break }

                let winPercentBeforeMover = mover == .white ? before.winPercentWhite : 100 - before.winPercentWhite
                let winPercentAfterMover = mover == .white ? after.winPercentWhite : 100 - after.winPercentWhite

                // Le roque ne se convertit pas en `Move` ChessKit (dialecte
                // roi-prend-tour sans équivalent dans `Move.Result`) — sans
                // conséquence : un roque ne sacrifie jamais rien.
                let classifierMove = Self.chessKitMove(for: move, board: boardBeforeMove)
                let isSacrifice = classifierMove.map {
                    MoveClassifier.involvesSacrifice(move: $0, boardAfterMove: boardAfterMove)
                } ?? false
                let nextClassifierMove = (self.moveLog.count > ply)
                    ? Self.chessKitMove(for: self.moveLog[ply], board: boardAfterMove)
                    : nil
                let sacrificeRecaptured = classifierMove.map {
                    MoveClassifier.isImmediatelyRecaptured($0, byNext: nextClassifierMove)
                } ?? false

                let quality = MoveClassifier.classify(MoveClassifier.Input(
                    winPercentBefore: winPercentBeforeMover,
                    winPercentAfter: winPercentAfterMover,
                    isBestMove: before.lanByRank[1] == self.uciLog[i],
                    gapToSecondBest: before.gapToSecondBestWinPercent,
                    isBook: false,
                    isSacrifice: isSacrifice,
                    sacrificeImmediatelyRecaptured: sacrificeRecaptured,
                    // Non porté (25/08) : distinguer « Occasion manquée » de
                    // « Gaffe » exige de rejouer le meilleur coup manqué sur
                    // un plateau annexe pour voir s'il matait/capturait — les
                    // deux restent des fautes signalées, seule l'étiquette
                    // fine change.
                    bestMoveWasTactical: false,
                    isForced: isForced
                ))

                self.moveQuality[ply] = quality
                verdicts[ply] = AnalysisEvalStore.MoveVerdict(
                    winPercentAfterMover: winPercentAfterMover, quality: quality.rawValue
                )
                self.classificationProgress = (done: ply, total: self.moveLog.count)
            }

            self.isClassifying = false
            self.classificationProgress = nil
            // La position affichée (le début, voir l'``init``) est forcément
            // couverte à ce stade — montrer son éval EN CACHE, sans salve.
            self.showCurrentCachedEvalOrRefresh()

            // Une passe incomplète (moteur muet, écran quitté) ne se met pas
            // en cache : la prochaine ouverture repart proprement plutôt que
            // de figer un verdict partiel.
            guard verdicts.count == self.moveLog.count else { return }
            let evals = self.evalCache.mapValues {
                AnalysisEvalStore.PositionEval(
                    winPercent: $0.winPercentWhite, pawns: min(10, max(-10, Double($0.cpWhite) / 100)),
                    bestLan: $0.lanByRank[1], gapToSecondBest: $0.gapToSecondBestWinPercent
                )
            }
            AnalysisEvalStore.save(
                AnalysisEvalStore.Snapshot(profile: AnalysisEvalStore.chess960Profile, evals: evals, verdicts: verdicts),
                key: key
            )
        }
    }

    /// Position terminale (mat/pat) : éval CERTAINE, sans requête moteur —
    /// même raison que ``AnalysisViewModel/terminalCachedEval(at:)``.
    private func terminalRankedEval(game: Chess960Game) -> RankedEval? {
        switch game.board.state {
        case let .checkmate(matedColor):
            let cpWhite = matedColor == .white ? -EngineScore.mateCentipawns : EngineScore.mateCentipawns
            return RankedEval(
                cpWhite: cpWhite, mateWhite: nil, winPercentWhite: matedColor == .white ? 0 : 100,
                lanByRank: [:], scoreByRank: [:], gapToSecondBestWinPercent: nil
            )
        case .draw:
            return RankedEval(
                cpWhite: 0, mateWhite: nil, winPercentWhite: 50,
                lanByRank: [:], scoreByRank: [:], gapToSecondBestWinPercent: nil
            )
        default:
            return nil
        }
    }

    /// Éval d'une position — lit ``evalCache`` d'abord, sinon interroge le
    /// moteur et l'y range. `ply` est la clé de cache (0 = position de
    /// départ) ; `game` DOIT être à cette même position.
    private func rankedEval(at ply: Int, game: Chess960Game) async -> RankedEval? {
        if let cached = evalCache[ply] { return cached }
        if let terminal = terminalRankedEval(game: game) {
            evalCache[ply] = terminal
            return terminal
        }

        await engine.synchronize()
        await engine.send(.setoption(id: "MultiPV", value: "\(Self.classificationMultiPV)"))
        await engine.send(.position(.fen(game.shredderFEN)))
        let nodes = max(1, Int(
            Double(DevicePerformance.classificationNodeBudget)
                * Self.classificationNodeMultiplier * ThermalMonitor.shared.nodeFactor
        ))
        // S'abonner AVANT d'envoyer : un abonné ne reçoit que ce qui suit
        // son abonnement (voir ``EngineController/responseStream``) — lu
        // APRÈS le `go`, un `bestmove` rapide se perdait sous charge.
        let responses = await engine.responseStream
        await engine.send(.go(nodes: nodes, movetime: DevicePerformance.classificationCapMs))

        let outcome = await EngineWatchdog.run(
            deadlineMs: DevicePerformance.classificationCapMs + EngineWatchdog.graceMs
        ) { [engine = self.engine] in
            var lanByRank: [Int: String] = [:]
            var scoreByRank: [Int: Double] = [:]
            var mateByRank: [Int: Int] = [:]
            for await response in responses {
                switch response {
                case let .info(info):
                    guard let rank = info.multipv, let firstMove = info.pv?.first else { break }
                    lanByRank[rank] = firstMove
                    if let mate = info.score?.mate {
                        mateByRank[rank] = Int(mate)
                        scoreByRank[rank] = mate > 0 ? Double(EngineScore.mateCentipawns) : Double(-EngineScore.mateCentipawns)
                    } else if let cp = info.score?.cp {
                        scoreByRank[rank] = Double(cp)
                    } else {
                        break
                    }
                case .bestmove:
                    return (lanByRank, scoreByRank, mateByRank)
                default:
                    break
                }
            }
            return (lanByRank, scoreByRank, mateByRank)
        }
        guard case let .finished((lanByRank, scoreByRank, mateByRank)) = outcome,
              let bestScore = scoreByRank[1]
        else { return nil }

        let sideToMove = game.board.position.sideToMove
        let cpWhite = sideToMove == .white ? Int(bestScore) : -Int(bestScore)
        let mateWhite = mateByRank[1].map { sideToMove == .white ? $0 : -$0 }
        let ranked = RankedEval(
            cpWhite: cpWhite,
            mateWhite: mateWhite,
            winPercentWhite: EvalConversion.winPercentage(cp: cpWhite),
            lanByRank: lanByRank,
            scoreByRank: scoreByRank,
            // POV du trait, comme ``AnalysisViewModel/makeCachedEval`` — les
            // deux scores UCI comparés (best/2e) sont déjà POV trait.
            gapToSecondBestWinPercent: scoreByRank[2].map {
                EvalConversion.winPercentage(cp: Int(bestScore)) - EvalConversion.winPercentage(cp: Int($0))
            }
        )
        evalCache[ply] = ranked
        return ranked
    }



    /// Précision par joueur — même calcul qu'en mode « Contre l'ordinateur »
    /// (voir ``VariantAccuracy``). Se complète au fil de la classification :
    /// les demi-coups pas encore évalués sont simplement sautés.
    var accuracyByColor: [Piece.Color: Double] {
        VariantAccuracy.byColor(
            plyCount: totalPlies,
            winPercentWhite: { evalCache[$0]?.winPercentWhite },
            // Pas de journal de FEN ici (cet écran REJOUE la partie plutôt
            // que de la relire), mais pas besoin : au Chess960 les Blancs
            // ouvrent toujours, et les camps alternent sans exception — ni
            // pose, ni tour double, ni trait qui saute un temps.
            moverAt: { $0.isMultiple(of: 2) ? .white : .black }
        )
    }

    // MARK: Courbe d'évaluation

    /// Les points de la courbe, tels qu'``EvalCurveView`` les attend.
    ///
    /// Tirés du CACHE de classification : la courbe se dessine donc au fur et
    /// à mesure que la passe avance, au lieu d'apparaître d'un coup à la fin.
    /// Les positions non encore évaluées sont simplement absentes — une
    /// courbe qui pousse vaut mieux qu'un rectangle vide.
    var evalCurvePoints: [EvalCurvePoint<Int>] {
        (0...max(0, totalPlies)).compactMap { ply in
            guard let cached = evalCache[ply] else { return nil }
            return EvalCurvePoint(
                id: ply, ply: ply, centipawnsWhite: cached.cpWhite, quality: moveQuality[ply]
            )
        }
    }

    // MARK: Export

    var exportedPGN: String {
        var lines = [
            "[Event \"ChessLab Chess960\"]",
            "[Variant \"Chess960\"]",
            "[SetUp \"1\"]",
            "[FEN \"\(startFEN)\"]",
        ]
        if !tags.white.isEmpty { lines.append("[White \"\(tags.white)\"]") }
        if !tags.black.isEmpty { lines.append("[Black \"\(tags.black)\"]") }
        if !tags.result.isEmpty { lines.append("[Result \"\(tags.result)\"]") }
        var moves = ""
        for (index, san) in sanLog.enumerated() {
            if index % 2 == 0 { moves += "\(index / 2 + 1). " }
            moves += san + " "
        }
        if !tags.result.isEmpty { moves += tags.result }
        return lines.joined(separator: "\n") + "\n\n" + moves.trimmingCharacters(in: .whitespaces) + "\n"
    }
}
