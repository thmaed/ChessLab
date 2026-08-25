import ChessKit
import Foundation
import Observation
import UIKit

/// Partie de Chess960 à deux humains sur le même appareil.
///
/// N'existe QUE par débranchement depuis ``Chess960PlayViewModel`` — voir
/// ``Chess960TwoPlayerSettings``. Reprend délibérément le MÊME plan que
/// ``Chess960PlayViewModel`` (journal UCI/SAN, cases affichées, répétition,
/// consultation, « Reprendre ici » avec annulation, export) — duplication
/// ASSUMÉE, du même ordre que celle, déjà connue et documentée, entre
/// ``PlayViewModel`` et ``TwoPlayerViewModel`` : deux écrans, deux histoires
/// de réglages, un seul mécanisme de jeu. Aucun moteur ici — c'est tout ce
/// qui change fondamentalement.
@Observable
@MainActor
final class Chess960TwoPlayerViewModel {

    // MARK: État de partie

    let settings: Chess960TwoPlayerSettings

    private(set) var game: Chess960Game
    private(set) var uciLog: [String] = []
    private(set) var sanLog: [String] = []
    private var displaySquaresLog: [(from: Square, to: Square)] = []
    private(set) var outcome: GameOutcome?
    private var repetitionCounts: [String: Int] = [:]

    let clock: GameClock?
    private let startFEN: String

    /// Côté affiché en bas — pivote après chaque coup en mode face-à-face,
    /// fixe sinon. Même mécanique que ``TwoPlayerViewModel/orientation``.
    private(set) var orientation: Piece.Color = .white

    // MARK: Interaction

    private(set) var selectedSquare: Square?
    private(set) var legalTargetSquares: [Square] = []
    struct PendingPromotion: Equatable { let from: Square; let to: Square }
    private(set) var pendingPromotion: PendingPromotion?

    // MARK: Consultation

    private(set) var reviewPly: Int?
    private var reviewGame: Chess960Game?

    // MARK: Cycle de vie

    init(settings: Chess960TwoPlayerSettings) {
        self.settings = settings
        startFEN = settings.startFEN
        game = Chess960Game(fen: settings.startFEN)!
        clock = settings.timeControl.hasClock ? GameClock(control: settings.timeControl) : nil
        repetitionCounts[game.repetitionKey] = 1
        if settings.rotationMode == .faceToFace {
            orientation = game.board.position.sideToMove
        }
        clock?.onFlagFall = { [weak self] color in
            self?.handleFlagFall(color)
        }
    }

    func handleViewAppear() {
        guard outcome == nil else { return }
        clock?.startTurn(for: game.board.position.sideToMove)
    }

    func handleViewDisappear() {
        clock?.pause()
    }

    // MARK: Affichage

    var displayedGame: Chess960Game { reviewGame ?? game }
    var displayedBoard: Board { displayedGame.board }
    var totalPlies: Int { uciLog.count }
    var displayedPly: Int { reviewPly ?? uciLog.count }
    var isReviewing: Bool { reviewPly != nil }

    var numberedMoves: [(number: Int, white: String, black: String?)] {
        stride(from: 0, to: sanLog.count, by: 2).map { index in
            (index / 2 + 1, sanLog[index], index + 1 < sanLog.count ? sanLog[index + 1] : nil)
        }
    }

    // MARK: Interaction utilisateur — les DEUX camps sont « l'utilisateur »

    private var canUserAct: Bool {
        outcome == nil && pendingPromotion == nil && !isReviewing
    }

    func selectSquare(_ square: Square) {
        guard canUserAct else { return }
        if let selected = selectedSquare, legalTargetSquares.contains(square) {
            attemptUserMove(from: selected, to: square)
            return
        }
        guard let piece = game.board.position.piece(at: square),
              piece.color == game.board.position.sideToMove
        else {
            clearSelection()
            return
        }
        selectedSquare = square
        legalTargetSquares = targets(for: square)
    }

    private func targets(for square: Square) -> [Square] {
        var targets = game.board.legalMoves(forPieceAt: square)
        if let piece = game.board.position.piece(at: square), piece.kind == .king {
            for move in game.legalMoves() {
                if case .castle = move,
                   let rookSquare = Square(String(game.uciFor(move).dropFirst(2))) as Square? {
                    targets.append(rookSquare)
                }
            }
        }
        return targets
    }

    func attemptUserMove(from start: Square, to end: Square) {
        let mover = game.board.position.sideToMove
        guard canUserAct, start != end, game.board.position.piece(at: start)?.color == mover else {
            Haptics.illegal()
            clearSelection()
            return
        }

        if let piece = game.board.position.piece(at: start), piece.kind == .pawn,
           end.notation.hasSuffix(mover == .white ? "8" : "1"),
           game.board.canMove(pieceAt: start, to: end) {
            pendingPromotion = PendingPromotion(from: start, to: end)
            clearSelection()
            return
        }

        let uci = start.notation + end.notation
        guard commit(uci: uci) else {
            Haptics.illegal()
            clearSelection()
            return
        }
        clearSelection()
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        _ = commit(uci: pending.from.notation + pending.to.notation + kind.rawValue.lowercased())
    }

    func cancelPromotion() { pendingPromotion = nil }

    private func clearSelection() {
        selectedSquare = nil
        legalTargetSquares = []
    }

    // MARK: Le commit

    @discardableResult
    private func commit(uci: String) -> Bool {
        let previousMover = game.board.position.sideToMove
        let squares = game.displaySquares(forUCI: uci)
        guard let san = game.apply(uci: uci) else { return false }
        clearResumeUndo()
        uciLog.append(uci)
        sanLog.append(san)
        if let squares { displaySquaresLog.append(squares) }
        playSound(for: san)

        let key = game.repetitionKey
        repetitionCounts[key, default: 0] += 1

        if let end = detectOutcome(repetitions: repetitionCounts[key] ?? 1) {
            outcome = end
            clock?.pause()
            Haptics.gameEnded()
            return true
        }

        clock?.startTurn(for: game.board.position.sideToMove, previousMover: previousMover)
        if settings.rotationMode == .faceToFace {
            orientation = game.board.position.sideToMove
        }
        return true
    }

    private func playSound(for san: String) {
        if san.contains("#") || san.contains("+") {
            SoundPlayer.shared.play(.check)
        } else if san.hasPrefix("O-O") {
            SoundPlayer.shared.play(.castle)
        } else if san.contains("x") {
            SoundPlayer.shared.play(.capture)
        } else {
            SoundPlayer.shared.play(.move)
        }
    }

    private func detectOutcome(repetitions: Int) -> GameOutcome? {
        if let end = game.boardEnd {
            switch end {
            case let .checkmate(winner): return GameOutcome(winner: winner, reason: .checkmate)
            case .stalemate: return GameOutcome(winner: nil, reason: .draw(.stalemate))
            case .insufficientMaterial: return GameOutcome(winner: nil, reason: .draw(.insufficientMaterial))
            case .fiftyMoves: return GameOutcome(winner: nil, reason: .draw(.fiftyMoves))
            }
        }
        if repetitions >= 3 { return GameOutcome(winner: nil, reason: .draw(.repetition)) }
        return nil
    }

    private func handleFlagFall(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .timeout)
        clock?.pause()
        Haptics.gameEnded()
    }

    func resign(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .resignation)
        clock?.pause()
        Haptics.gameEnded()
    }

    func agreeToDraw() {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: nil, reason: .drawByAgreement)
        clock?.pause()
        Haptics.gameEnded()
    }

    // MARK: Consultation & reprise — le pattern du 24/08

    func review(toPly ply: Int) {
        let clamped = max(0, min(ply, uciLog.count))
        guard clamped != uciLog.count else {
            reviewToLive()
            return
        }
        reviewPly = clamped
        reviewGame = replayed(prefix: clamped)
        clearSelection()
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }

    func reviewToLive() {
        reviewPly = nil
        reviewGame = nil
        clearSelection()
    }

    var canTakeback: Bool {
        !settings.timeControl.hasClock && !uciLog.isEmpty && outcome == nil
    }

    func takeback() {
        guard canTakeback else { return }
        truncate(to: uciLog.count - 1)
    }

    var canResumeFromReview: Bool {
        guard let reviewPly else { return false }
        return !settings.timeControl.hasClock && outcome == nil && reviewPly < uciLog.count
    }

    struct ResumeUndo { let uci: [String]; let san: [String]; var discardedCount: Int { uci.count } }
    private(set) var resumeUndo: ResumeUndo?
    private var resumeUndoTask: Task<Void, Never>?
    private static let resumeUndoDelay: Duration = .seconds(8)

    func resumeFromReview() {
        guard let reviewPly, canResumeFromReview else { return }
        let discardedUci = Array(uciLog.suffix(from: reviewPly))
        let discardedSan = Array(sanLog.suffix(from: reviewPly))
        reviewToLive()
        truncate(to: reviewPly)
        guard !discardedUci.isEmpty else { return }
        offerResumeUndo(ResumeUndo(uci: discardedUci, san: discardedSan))
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: LocalizationController.string(
                    "Partie reprise, %lld coups écartés. Annulation possible.", discardedUci.count
                )
            )
        }
    }

    /// Même garde qu'en mode Jouer (revue du 24/08) : sans `outcome == nil`,
    /// annuler ressuscitait une partie terminée déjà enregistrée.
    func cancelResumeFromReview() {
        guard let undo = resumeUndo, outcome == nil else { return }
        clearResumeUndo()
        uciLog.append(contentsOf: undo.uci)
        sanLog.append(contentsOf: undo.san)
        rebuildFromLogs()
    }

    private func offerResumeUndo(_ undo: ResumeUndo) {
        resumeUndoTask?.cancel()
        resumeUndo = undo
        resumeUndoTask = Task { [weak self] in
            try? await Task.sleep(for: Self.resumeUndoDelay)
            guard !Task.isCancelled else { return }
            self?.resumeUndo = nil
        }
    }

    private func clearResumeUndo() {
        resumeUndoTask?.cancel()
        resumeUndoTask = nil
        resumeUndo = nil
    }

    private func truncate(to count: Int) {
        clearResumeUndo()
        uciLog = Array(uciLog.prefix(count))
        sanLog = Array(sanLog.prefix(count))
        rebuildFromLogs()
    }

    private func rebuildFromLogs() {
        var rebuilt = Chess960Game(fen: startFEN)!
        var counts: [String: Int] = [rebuilt.repetitionKey: 1]
        var squaresLog: [(from: Square, to: Square)] = []
        for uci in uciLog {
            if let squares = rebuilt.displaySquares(forUCI: uci) { squaresLog.append(squares) }
            _ = rebuilt.apply(uci: uci)
            counts[rebuilt.repetitionKey, default: 0] += 1
        }
        game = rebuilt
        repetitionCounts = counts
        displaySquaresLog = squaresLog
        outcome = nil
        clearSelection()
        if settings.rotationMode == .faceToFace {
            orientation = game.board.position.sideToMove
        }
    }

    private func replayed(prefix count: Int) -> Chess960Game {
        var replayed = Chess960Game(fen: startFEN)!
        for uci in uciLog.prefix(count) { _ = replayed.apply(uci: uci) }
        return replayed
    }

    var displayedLastMove: Move? {
        let index = displayedPly
        guard index > 0, index <= displaySquaresLog.count else { return nil }
        let squares = displaySquaresLog[index - 1]
        guard let piece = displayedBoard.position.piece(at: squares.to) else { return nil }
        return Move(result: .move, piece: piece, start: squares.from, end: squares.to)
    }

    // MARK: Export

    var displayedFEN: String { displayedGame.shredderFEN }

    var exportedPGN: String {
        var tags = [
            "[Event \"ChessLab Chess960\"]",
            "[White \"\(settings.whiteName)\"]",
            "[Black \"\(settings.blackName)\"]",
            "[Variant \"Chess960\"]",
            "[SetUp \"1\"]",
            "[FEN \"\(startFEN)\"]",
        ]
        if let outcome {
            tags.append("[Result \"\(outcome.pgnResult)\"]")
        }
        var moves = ""
        for (index, san) in sanLog.enumerated() {
            if index % 2 == 0 { moves += "\(index / 2 + 1). " }
            moves += san + " "
        }
        if let outcome { moves += outcome.pgnResult }
        return tags.joined(separator: "\n") + "\n\n" + moves.trimmingCharacters(in: .whitespaces) + "\n"
    }
}
