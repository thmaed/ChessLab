import ChessKit
import Foundation
import Observation

/// Revue d'une partie Chess960 TERMINÉE : rejouer coup par coup, avec
/// l'évaluation et les meilleurs coups de la position affichée.
///
/// Volontairement ALLÉGÉ par rapport à ``AnalysisViewModel`` — décision du
/// 25/08 : ni classification des coups (gaffe/imprécision/erreur), ni
/// génération de puzzles, ni bibliothèque persistée. Ces trois-là exploitent
/// en profondeur l'infrastructure ChessKit existante (types `Move.Assessment`,
/// modèles SwiftData `GameRecord`/`Puzzle`…) qu'un portage complet au Chess960
/// demanderait de récrire ou de dupliquer entièrement — chantier à part,
/// hors de portée de cette session. Ce qui reste — rejouer, évaluer,
/// suggérer — couvre l'essentiel de « regarder sa partie qui vient de finir ».
@Observable
@MainActor
final class Chess960AnalysisViewModel {

    private(set) var startFEN: String
    private(set) var sanLog: [String] = []
    private(set) var uciLog: [String] = []
    private(set) var displaySquaresLog: [(from: Square, to: Square)] = []
    /// En-têtes du PGN d'origine — noms des joueurs, résultat.
    let tags: Game.Tags

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
        for uci in ucis {
            if let s = game.displaySquares(forUCI: uci) { squares.append(s) }
            _ = game.apply(uci: uci)
        }
        displaySquaresLog = squares
        displayedGame = game
        displayedPly = ucis.count
    }

    func start() {
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            guard await self.engine.start() else { return }
            await self.engine.send(.setoption(id: "UCI_Chess960", value: "true"))
        }
        refreshAnalysis()
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
        refreshAnalysis()
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
