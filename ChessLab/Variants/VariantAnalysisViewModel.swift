import ChessKit
import Foundation
import Observation

/// Ce qu'il faut pour lancer une analyse depuis une partie de variante déjà
/// en mémoire — passé directement par ``FairyVariantPlayViewModel``/
/// ``EngineLegalityPlayViewModel`` à la fin de la partie, SANS export PGN
/// intermédiaire (voir le commentaire de tête de ``VariantAnalysisViewModel``).
/// `Hashable` (pas `Codable` : ``HomeView.Route`` ne l'exige pas) pour
/// voyager dans une `NavigationPath` comme les autres cas de la route.
struct VariantAnalysisSeed: Hashable {
    let variantID: String
    let variantDisplayName: String
    let startFEN: String
    let uciLog: [String]
    let sanLog: [String]
    let moveLog: [Move]
    let fenLog: [String]
    let outcome: GameOutcome?
}

/// Revue d'une partie de variante (les six écrans du hub « Variantes »
/// hors Chess960, qui garde son propre ``Chess960AnalysisViewModel``) —
/// même principe que lui : une passe RAPIDE classe toute la ligne
/// principale à l'ouverture, puis se met en cache.
///
/// Contrairement à Chess960, aucun rejeu n'est nécessaire à la
/// construction : les deux vues-modèles de partie (``FairyVariantPlayViewModel``
/// pour Roi de la colline/Trois échecs/Horde, ``EngineLegalityPlayViewModel``
/// pour Course des rois/Antéchecs/Atomique) tiennent DÉJÀ `fenLog`/`moveLog`
/// à jour à chaque coup — cette vue-modèle les reçoit directement, sans
/// passer par un export PGN suivi d'un nouveau parseur (ce que fait
/// Chess960, à cause d'une limite de `PGNLoader` propre au roque ; les six
/// variantes ici n'ont pas ce problème, leurs coups sont des `Move`
/// ChessKit ordinaires).
@Observable
@MainActor
final class VariantAnalysisViewModel {

    private(set) var startFEN: String
    private(set) var sanLog: [String]
    private(set) var uciLog: [String]
    private(set) var moveLog: [Move]
    /// FEN après CHAQUE coup, `fenLog[0]` = position de départ.
    private(set) var fenLog: [String]
    private(set) var variantID: String
    private(set) var variantDisplayName: String
    /// Résultat déjà connu de la partie SOURCE — jamais re-dérivé ici (les
    /// six variantes ont chacune leur propre condition de victoire, voir
    /// ``FairyVariant/specialOutcome(board:mover:checkCounts:)``/
    /// ``EngineLegalityVariant/outcome(afterFEN:legalMovesForNextMover:inCheck:)`` —
    /// les reproduire ICI serait dupliquer une logique déjà correcte).
    private(set) var outcome: GameOutcome?

    private(set) var moveQuality: [Int: MoveQuality] = [:]
    private(set) var isClassifying = false
    private(set) var classificationProgress: (done: Int, total: Int)?

    private(set) var displayedPly: Int = 0

    private(set) var currentEvalCp: Int?
    private(set) var currentEvalMate: Int?
    var hintMoves: [HintMove] = []
    private(set) var isAnalyzing = false

    private let engine = FairyEngineController()
    private var engineQueue: Task<Void, Never> = Task {}
    private var analysisToken = 0

    init(
        variantID: String, variantDisplayName: String, startFEN: String,
        uciLog: [String], sanLog: [String], moveLog: [Move], fenLog: [String],
        outcome: GameOutcome?
    ) {
        self.variantID = variantID
        self.variantDisplayName = variantDisplayName
        self.startFEN = startFEN
        self.uciLog = uciLog
        self.sanLog = sanLog
        self.moveLog = moveLog
        self.fenLog = fenLog
        self.outcome = outcome
        // Ouvre sur le DÉBUT de la partie — même choix que Chess960.
        displayedPly = 0
    }

    convenience init(seed: VariantAnalysisSeed) {
        self.init(
            variantID: seed.variantID, variantDisplayName: seed.variantDisplayName, startFEN: seed.startFEN,
            uciLog: seed.uciLog, sanLog: seed.sanLog, moveLog: seed.moveLog, fenLog: seed.fenLog,
            outcome: seed.outcome
        )
    }

    func start() {
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            _ = await self.engine.start(variant: self.variantID)
        }
        classifyMainLine()
    }

    func handleViewDisappear() {
        engineQueue.cancel()
        Task { [engine] in await engine.stop() }
    }

    // MARK: Navigation

    var totalPlies: Int { uciLog.count }

    func review(toPly ply: Int) {
        // Borné sur `fenLog.count - 1`, pas seulement `totalPlies` : une
        // partie SOURCE corrompue (désync `uciLog`/`fenLog`) ne doit jamais
        // faire planter `fenLog[displayedPly]` plus bas, même si le vrai
        // correctif vit en amont, côté vue-modèle de partie. Trouvé lors de
        // la revue du 25/08/2026.
        let clamped = max(0, min(ply, totalPlies, fenLog.count - 1))
        guard clamped != displayedPly else { return }
        displayedPly = clamped
        // Aucun rejeu : `fenLog` couvre déjà CHAQUE position, la navigation
        // n'a jamais besoin de repasser par ChessKit ni par le moteur pour
        // le plateau — seule l'éval affichée peut demander une salve.
        showCurrentCachedEvalOrRefresh()
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }

    var numberedMoves: [(number: Int, white: String, black: String?)] {
        stride(from: 0, to: sanLog.count, by: 2).map { index in
            (index / 2 + 1, sanLog[index], index + 1 < sanLog.count ? sanLog[index + 1] : nil)
        }
    }

    var displayedBoard: Board { Board(position: Position(fen: fenLog[displayedPly])!) }
    var displayedFEN: String { fenLog[displayedPly] }

    var displayedLastMove: Move? {
        guard displayedPly > 0, displayedPly <= moveLog.count else { return nil }
        return moveLog[displayedPly - 1]
    }

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

    private static let analysisBudgetMs = 1500

    private func refreshAnalysis() {
        analysisToken += 1
        let token = analysisToken
        currentEvalCp = nil
        currentEvalMate = nil
        hintMoves = []
        let fen = fenLog[displayedPly]
        guard let mover = Position(fen: fen)?.sideToMove else { return }

        enqueueEngineWork { [weak self] in
            guard let self else { return }
            self.isAnalyzing = true
            defer { self.isAnalyzing = false }

            await self.engine.synchronize()
            await self.engine.send(.setoption(id: "MultiPV", value: "3"))
            await self.engine.send(.position(.fen(fen)))
            await self.engine.send(.go(movetime: Self.analysisBudgetMs))

            let search = await EngineWatchdog.run(deadlineMs: Self.analysisBudgetMs + EngineWatchdog.graceMs) { [engine = self.engine] in
                var lanByRank: [Int: String] = [:]
                var scoreByRank: [Int: Double] = [:]
                var bestCp: Int?
                var bestMate: Int?
                for await response in await engine.responseStream {
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
                  token == self.analysisToken, fen == self.fenLog[self.displayedPly]
            else { return }

            if let bestCp {
                self.currentEvalCp = mover == .white ? bestCp : -bestCp
                self.currentEvalMate = nil
            } else if let bestMate {
                self.currentEvalMate = mover == .white ? bestMate : -bestMate
                self.currentEvalCp = nil
            }
            self.hintMoves = HintMoveBuilder.build(lanByRank: lanByRank, scoreByRank: scoreByRank)
        }
    }

    private func showCurrentCachedEvalOrRefresh() {
        if let cached = evalCache[displayedPly] {
            showCachedEval(cached)
        } else if displayedPly == totalPlies, let terminal = terminalRankedEval() {
            // Même garde-fou que ``rankedEval(at:)`` (utilisé par la passe de
            // classification) : la dernière position d'une partie Atomique
            // terminée par explosion du roi n'a PLUS de roi d'un des deux
            // camps. Sans ce court-circuit, naviguer jusqu'au tout dernier
            // coup AVANT que la classification n'ait elle-même atteint cette
            // position (fenêtre de course à l'ouverture de l'écran) envoyait
            // cette position sans roi au moteur réel via `refreshAnalysis()`
            // — Fairy-Stockfish n'est jamais censé recevoir une position
            // qu'aucune partie normale ne lui aurait jamais demandé
            // d'évaluer. Signalé par l'utilisateur : « plantée du moteur à
            // la fin de l'atomique ».
            evalCache[displayedPly] = terminal
            showCachedEval(terminal)
        } else {
            refreshAnalysis()
        }
    }

    private func showCachedEval(_ cached: RankedEval) {
        analysisToken += 1
        currentEvalCp = cached.mateWhite == nil ? cached.cpWhite : nil
        currentEvalMate = cached.mateWhite

        if !cached.scoreByRank.isEmpty {
            hintMoves = HintMoveBuilder.build(lanByRank: cached.lanByRank, scoreByRank: cached.scoreByRank)
                .map { HintMove(rank: $0.rank, from: $0.from, to: $0.to, strength: $0.strength, kind: .reviewBest) }
        } else if let bestLan = cached.lanByRank[1], bestLan.count >= 4 {
            let start = Square(String(bestLan.prefix(2)))
            let end = Square(String(bestLan.dropFirst(2).prefix(2)))
            hintMoves = [HintMove(rank: 1, from: start, to: end, strength: 1, kind: .reviewBest)]
        } else {
            hintMoves = []
        }
    }

    // MARK: Classification (pastilles) — passe rapide, une fois, toute la ligne

    private struct RankedEval {
        var cpWhite: Int
        var mateWhite: Int?
        var winPercentWhite: Double
        var lanByRank: [Int: String]
        var scoreByRank: [Int: Double]
        var gapToSecondBestWinPercent: Double?
    }

    private var evalCache: [Int: RankedEval] = [:]

    private static let classificationMultiPV = 2
    private static let classificationNodeMultiplier = 1.3

    private func classifyMainLine() {
        guard !uciLog.isEmpty,
              let key = AnalysisEvalStore.key(startFEN: startFEN, lans: uciLog, variantID: variantID)
        else {
            showCurrentCachedEvalOrRefresh()
            return
        }

        enqueueEngineWork { [weak self] in
            guard let self else { return }

            if let cached = AnalysisEvalStore.load(key: key, profile: AnalysisEvalStore.variantsProfile) {
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
            self.classificationProgress = (done: 0, total: self.uciLog.count)

            var verdicts: [Int: AnalysisEvalStore.MoveVerdict] = [:]

            // `min(..., fenLog.count - 1)` : même garde-fou qu'en
            // ``review(toPly:)`` — une partie SOURCE corrompue ne doit
            // jamais faire indexer `fenLog` hors bornes ici non plus.
            for i in 0..<min(self.uciLog.count, self.fenLog.count - 1) {
                let ply = i + 1
                guard let mover = Position(fen: self.fenLog[i])?.sideToMove else { break }
                guard let before = await self.rankedEval(at: i) else { break }
                guard let after = await self.rankedEval(at: ply) else { break }

                let winPercentBeforeMover = mover == .white ? before.winPercentWhite : 100 - before.winPercentWhite
                let winPercentAfterMover = mover == .white ? after.winPercentWhite : 100 - after.winPercentWhite

                let move = self.moveLog[i]
                let boardAfterMove = Board(position: Position(fen: self.fenLog[ply])!)
                let isSacrifice = MoveClassifier.involvesSacrifice(move: move, boardAfterMove: boardAfterMove)
                let nextMove = (i + 1 < self.moveLog.count) ? self.moveLog[i + 1] : nil
                let sacrificeRecaptured = MoveClassifier.isImmediatelyRecaptured(move, byNext: nextMove)
                // Un seul coup rendu malgré un MultiPV 2 demandé : la
                // position n'en offrait pas d'autre — même signal que
                // `game.legalMoves().count == 1` côté Chess960, sans salve
                // supplémentaire.
                let isForced = before.lanByRank.count == 1

                let quality = MoveClassifier.classify(MoveClassifier.Input(
                    winPercentBefore: winPercentBeforeMover,
                    winPercentAfter: winPercentAfterMover,
                    isBestMove: before.lanByRank[1] == self.uciLog[i],
                    gapToSecondBest: before.gapToSecondBestWinPercent,
                    isBook: false,
                    isSacrifice: isSacrifice,
                    sacrificeImmediatelyRecaptured: sacrificeRecaptured,
                    bestMoveWasTactical: false,
                    isForced: isForced
                ))

                self.moveQuality[ply] = quality
                verdicts[ply] = AnalysisEvalStore.MoveVerdict(
                    winPercentAfterMover: winPercentAfterMover, quality: quality.rawValue
                )
                self.classificationProgress = (done: ply, total: self.uciLog.count)
            }

            self.isClassifying = false
            self.classificationProgress = nil
            self.showCurrentCachedEvalOrRefresh()

            guard verdicts.count == self.uciLog.count else { return }
            let evals = self.evalCache.mapValues {
                AnalysisEvalStore.PositionEval(
                    winPercent: $0.winPercentWhite, pawns: min(10, max(-10, Double($0.cpWhite) / 100)),
                    bestLan: $0.lanByRank[1], gapToSecondBest: $0.gapToSecondBestWinPercent
                )
            }
            AnalysisEvalStore.save(
                AnalysisEvalStore.Snapshot(profile: AnalysisEvalStore.variantsProfile, evals: evals, verdicts: verdicts),
                key: key
            )
        }
    }

    /// Position terminale (dernier ply, partie déjà finie) : éval CERTAINE
    /// tirée du résultat déjà connu — jamais interrogée au moteur, qui
    /// n'a de toute façon aucune idée des conditions de victoire propres à
    /// chaque variante (roi sur la colline, trois échecs, plus aucune pièce…).
    private func terminalRankedEval() -> RankedEval? {
        guard let outcome else { return nil }
        guard let winner = outcome.winner else {
            return RankedEval(cpWhite: 0, mateWhite: nil, winPercentWhite: 50, lanByRank: [:], scoreByRank: [:], gapToSecondBestWinPercent: nil)
        }
        let cpWhite = winner == .white ? EngineScore.mateCentipawns : -EngineScore.mateCentipawns
        return RankedEval(
            cpWhite: cpWhite, mateWhite: nil, winPercentWhite: winner == .white ? 100 : 0,
            lanByRank: [:], scoreByRank: [:], gapToSecondBestWinPercent: nil
        )
    }

    private func rankedEval(at ply: Int) async -> RankedEval? {
        if let cached = evalCache[ply] { return cached }
        if ply == totalPlies, let terminal = terminalRankedEval() {
            evalCache[ply] = terminal
            return terminal
        }

        let fen = fenLog[ply]
        guard let sideToMove = Position(fen: fen)?.sideToMove else { return nil }

        await engine.synchronize()
        await engine.send(.setoption(id: "MultiPV", value: "\(Self.classificationMultiPV)"))
        await engine.send(.position(.fen(fen)))
        let nodes = max(1, Int(
            Double(DevicePerformance.classificationNodeBudget)
                * Self.classificationNodeMultiplier * ThermalMonitor.shared.nodeFactor
        ))
        await engine.send(.go(nodes: nodes, movetime: DevicePerformance.classificationCapMs))

        let outcome = await EngineWatchdog.run(
            deadlineMs: DevicePerformance.classificationCapMs + EngineWatchdog.graceMs
        ) { [engine = self.engine] in
            var lanByRank: [Int: String] = [:]
            var scoreByRank: [Int: Double] = [:]
            var mateByRank: [Int: Int] = [:]
            for await response in await engine.responseStream {
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

        let cpWhite = sideToMove == .white ? Int(bestScore) : -Int(bestScore)
        let mateWhite = mateByRank[1].map { sideToMove == .white ? $0 : -$0 }
        let ranked = RankedEval(
            cpWhite: cpWhite,
            mateWhite: mateWhite,
            winPercentWhite: EvalConversion.winPercentage(cp: cpWhite),
            lanByRank: lanByRank,
            scoreByRank: scoreByRank,
            gapToSecondBestWinPercent: scoreByRank[2].map {
                EvalConversion.winPercentage(cp: Int(bestScore)) - EvalConversion.winPercentage(cp: Int($0))
            }
        )
        evalCache[ply] = ranked
        return ranked
    }

    // MARK: Export

    var exportedPGN: String {
        var lines = [
            "[Event \"ChessLab \(variantDisplayName)\"]",
            "[Variant \"\(variantID)\"]",
            "[SetUp \"1\"]",
            "[FEN \"\(startFEN)\"]",
        ]
        if let outcome {
            lines.append("[Result \"\(outcome.pgnResult)\"]")
        }
        var moves = ""
        for (index, san) in sanLog.enumerated() {
            if index % 2 == 0 { moves += "\(index / 2 + 1). " }
            moves += san + " "
        }
        if let outcome { moves += outcome.pgnResult }
        return lines.joined(separator: "\n") + "\n\n" + moves.trimmingCharacters(in: .whitespaces) + "\n"
    }
}
