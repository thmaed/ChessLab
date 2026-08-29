import ChessKit
import Foundation
import Observation

/// Tout ce qu'une partie de Duck Chess terminée transmet à son analyse.
///
/// Comme ``VariantAnalysisSeed``, les journaux passent tels quels — aucun
/// export PGN intermédiaire à re-parser. Deux journaux de plus, en revanche,
/// et ils sont indispensables : ni la position du canard ni la case de prise
/// en passant ne se redéduisent des coups joués.
struct DuckChessAnalysisSeed: Hashable {
    let startFEN: String
    let sanLog: [String]
    let uciLog: [String]
    let moveLog: [Move]
    let fenLog: [String]
    let duckLog: [Square?]
    let enPassantLog: [Square?]
    let outcome: GameOutcome?
    /// Le plateau se relit du côté où l'on a joué.
    let orientation: Piece.Color
}

/// Revue d'une partie de Duck Chess terminée.
///
/// Même promesse que ``VariantAnalysisViewModel`` — parcourir la partie,
/// voir l'éval, lire une pastille de qualité sur chaque coup — mais elle ne
/// pouvait pas le réutiliser : celui-là interroge Fairy-Stockfish avec un
/// identifiant de variante, or Fairy-Stockfish ignore le Duck Chess. On
/// s'adosse donc au même ``DuckChessEngine`` que la partie : Stockfish
/// standard, borné aux coups que le canard autorise, et jamais interrogé sur
/// une position qu'il tiendrait pour illégale.
///
/// ## Ce que vaut cette analyse
///
/// Le moteur ne voit pas le canard : il croit ouvertes des lignes que le
/// canard barre. Les évaluations sont donc des ordres de grandeur — très
/// fiables sur le matériel et les grosses gaffes, discutables sur le
/// positionnel fin. C'est aussi pourquoi le TOUR ENTIER est jugé d'un bloc
/// (coup + canard) : c'est la seule unité qui ait un sens dans cette variante.
///
/// Aucun résultat n'est écrit dans ``AnalysisEvalStore`` : sa clé est faite
/// des coups joués, et deux parties de Duck Chess peuvent partager la même
/// liste de coups avec des canards différents — donc des évaluations
/// différentes. Un cache en mémoire, le temps de l'écran, suffit.
@Observable
@MainActor
final class DuckChessAnalysisViewModel {

    private(set) var startFEN: String
    private(set) var sanLog: [String]
    private(set) var uciLog: [String]
    private(set) var moveLog: [Move]
    private(set) var fenLog: [String]
    private(set) var duckLog: [Square?]
    private(set) var enPassantLog: [Square?]
    private(set) var outcome: GameOutcome?
    let orientation: Piece.Color

    private(set) var displayedPly: Int = 0
    private(set) var moveQuality: [Int: MoveQuality] = [:]
    private(set) var isClassifying = false
    private(set) var classificationProgress: (done: Int, total: Int)?
    private(set) var isAnalyzing = false
    private(set) var isEngineUnavailable = false

    private(set) var currentEvalCp: Int?
    private(set) var hintMoves: [HintMove] = []

    private let engine = DuckChessEngine(strength: .maximum)
    private var engineQueue: Task<Void, Never> = Task {}
    private var hasClassified = false

    var variantDisplayName: String { DuckChessVariant.shared.displayName }

    init(seed: DuckChessAnalysisSeed) {
        startFEN = seed.startFEN
        sanLog = seed.sanLog
        uciLog = seed.uciLog
        moveLog = seed.moveLog
        fenLog = seed.fenLog
        duckLog = seed.duckLog
        enPassantLog = seed.enPassantLog
        outcome = seed.outcome
        orientation = seed.orientation
        // Ouvre sur le DÉBUT de la partie — même choix que les autres écrans
        // d'analyse.
        displayedPly = 0
    }

    // MARK: Cycle de vie

    /// Le moteur redémarre à CHAQUE apparition — la vue-modèle survit à la
    /// navigation, et ``handleViewDisappear()`` l'a arrêté en partant. La
    /// classification, elle, ne se refait pas : ses verdicts sont déjà là.
    func start() {
        enqueueEngineWork { [weak self] in
            guard await self?.engine.start() == true else {
                self?.isEngineUnavailable = true
                return
            }
            self?.isEngineUnavailable = false
        }
        guard !hasClassified else {
            showEvalForDisplayedPly()
            return
        }
        hasClassified = true
        classifyMainLine()
    }

    func handleViewDisappear() {
        engineQueue.cancel()
        Task { [engine] in await engine.stop() }
    }

    private func enqueueEngineWork(_ work: @escaping () async -> Void) {
        let previous = engineQueue
        engineQueue = Task {
            _ = await previous.value
            guard !Task.isCancelled else { return }
            await work()
        }
    }

    // MARK: Navigation

    var totalPlies: Int { sanLog.count }

    func review(toPly ply: Int) {
        let clamped = max(0, min(ply, totalPlies, fenLog.count - 1))
        guard clamped != displayedPly else { return }
        displayedPly = clamped
        showEvalForDisplayedPly()
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }

    var numberedMoves: [(number: Int, white: String, black: String?)] {
        stride(from: 0, to: sanLog.count, by: 2).map { index in
            (index / 2 + 1, sanLog[index], index + 1 < sanLog.count ? sanLog[index + 1] : nil)
        }
    }

    var displayedBoard: Board {
        Board(position: Position(fen: fenLog[displayedPly]) ?? Position(fen: startFEN)!)
    }

    var displayedFEN: String { fenLog[displayedPly] }
    var displayedDuck: Square? { duckLog[displayedPly] }

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

    // MARK: Évaluation

    /// Budget par position, en NŒUDS d'abord — le même verdict sur tous les
    /// appareils — avec le temps en simple filet de sécurité. Mêmes réglages
    /// que la classification des autres écrans d'analyse.
    private static var evaluationNodes: Int { DevicePerformance.classificationNodeBudget }
    private static var evaluationCapMs: Int { DevicePerformance.classificationCapMs }

    private struct CachedEval {
        var cpWhite: Int
        var winPercentWhite: Double
        var bestUCI: String?
    }

    private var evalCache: [Int: CachedEval] = [:]

    private func showEvalForDisplayedPly() {
        if let cached = evalCache[displayedPly] {
            show(cached)
            return
        }
        currentEvalCp = nil
        hintMoves = []
        let ply = displayedPly
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            self.isAnalyzing = true
            defer { self.isAnalyzing = false }
            guard let evaluated = await self.evaluation(at: ply), self.displayedPly == ply else { return }
            self.show(evaluated)
        }
    }

    private func show(_ cached: CachedEval) {
        currentEvalCp = cached.cpWhite
        guard let best = cached.bestUCI, best.count >= 4 else {
            hintMoves = []
            return
        }
        hintMoves = [HintMove(
            rank: 1,
            from: Square(String(best.prefix(2))),
            to: Square(String(best.dropFirst(2).prefix(2))),
            strength: 1,
            kind: .reviewBest
        )]
    }

    /// Éval CERTAINE de la position finale, tirée du résultat déjà connu —
    /// jamais demandée au moteur, qui ne connaît pas la seule fin de partie
    /// du Duck Chess (la prise du roi) et se retrouverait de toute façon
    /// devant un plateau à un seul roi.
    private func terminalEval() -> CachedEval? {
        guard let outcome else { return nil }
        guard let winner = outcome.winner else {
            return CachedEval(cpWhite: 0, winPercentWhite: 50, bestUCI: nil)
        }
        let cp = winner == .white ? DuckChessEngine.winningCentipawns : -DuckChessEngine.winningCentipawns
        return CachedEval(cpWhite: cp, winPercentWhite: winner == .white ? 100 : 0, bestUCI: nil)
    }

    private func evaluation(at ply: Int) async -> CachedEval? {
        if let cached = evalCache[ply] { return cached }
        if ply == totalPlies, let terminal = terminalEval() {
            evalCache[ply] = terminal
            return terminal
        }
        guard ply < fenLog.count, let position = Position(fen: fenLog[ply]) else { return nil }
        guard let result = await engine.evaluate(
            position: position,
            duck: duckLog[ply],
            enPassant: enPassantLog[ply],
            movetimeMs: Self.evaluationCapMs,
            nodes: Self.evaluationNodes
        ) else { return nil }

        let cached = CachedEval(
            cpWhite: result.cpWhite,
            winPercentWhite: EvalConversion.winPercentage(cp: result.cpWhite),
            bestUCI: result.bestUCI
        )
        evalCache[ply] = cached
        return cached
    }

    // MARK: Classification (pastilles)

    /// Une passe unique, toute la ligne principale, à l'ouverture de l'écran.
    ///
    /// Le TOUR entier est jugé : la position d'avant porte déjà le canard tel
    /// qu'il était, celle d'après le canard nouvellement posé. Un canard mal
    /// placé pèse donc dans la note, exactement comme une pièce mal placée.
    private func classifyMainLine() {
        guard !sanLog.isEmpty else {
            showEvalForDisplayedPly()
            return
        }
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            self.isClassifying = true
            self.classificationProgress = (done: 0, total: self.sanLog.count)
            defer {
                self.isClassifying = false
                self.classificationProgress = nil
            }

            for index in 0..<min(self.sanLog.count, self.fenLog.count - 1) {
                guard !Task.isCancelled else { return }
                let ply = index + 1
                guard let mover = Position(fen: self.fenLog[index])?.sideToMove else { break }
                // Un demi-coup peut rester SANS pastille, et c'est voulu :
                // une position où un roi reste en prise est normale ici mais
                // illégale pour Stockfish, qui refuse alors de l'évaluer
                // (voir ``DuckChessEngine``). Mieux vaut un coup sans note
                // qu'une note inventée.
                guard let before = await self.evaluation(at: index),
                      let after = await self.evaluation(at: ply)
                else {
                    self.classificationProgress = (done: ply, total: self.sanLog.count)
                    continue
                }

                let winBefore = mover == .white ? before.winPercentWhite : 100 - before.winPercentWhite
                let winAfter = mover == .white ? after.winPercentWhite : 100 - after.winPercentWhite

                let move = self.moveLog[index]
                guard let positionAfter = Position(fen: self.fenLog[ply]) else { continue }
                let boardAfter = Board(position: positionAfter)
                let next = (index + 1 < self.moveLog.count) ? self.moveLog[index + 1] : nil

                self.moveQuality[ply] = MoveClassifier.classify(MoveClassifier.Input(
                    winPercentBefore: winBefore,
                    winPercentAfter: winAfter,
                    isBestMove: before.bestUCI == self.uciLog[index],
                    gapToSecondBest: nil,
                    isBook: false,
                    isSacrifice: MoveClassifier.involvesSacrifice(move: move, boardAfterMove: boardAfter),
                    sacrificeImmediatelyRecaptured: MoveClassifier.isImmediatelyRecaptured(move, byNext: next),
                    bestMoveWasTactical: false,
                    isForced: false
                ))
                self.classificationProgress = (done: ply, total: self.sanLog.count)
            }
            self.showEvalForDisplayedPly()
        }
    }

    // MARK: Export

    var exportedPGN: String {
        var lines = [
            "[Event \"ChessLab \(variantDisplayName)\"]",
            "[Variant \"\(DuckChessVariant.shared.id)\"]",
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
