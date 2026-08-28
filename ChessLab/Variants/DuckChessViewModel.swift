import ChessKit
import Foundation
import Observation

/// Partie de Duck Chess à DEUX JOUEURS sur le même appareil.
///
/// Pas d'adversaire artificiel, et ce n'est pas un manque de temps : aucun
/// moteur ne sait jouer cette variante (voir ``DuckChessRules`` pour le
/// détail), et en écrire un donnerait un adversaire faible pour beaucoup de
/// code. À deux, la variante est de toute façon à son avantage — c'est un jeu
/// de salon, où poser le canard sous le nez de l'autre fait la moitié du sel.
@MainActor
@Observable
final class DuckChessViewModel {

    /// Le tour se joue en DEUX temps, et c'est toute la variante : on déplace
    /// une pièce, PUIS on pose le canard. Tant que le canard n'est pas posé,
    /// le trait n'a pas changé.
    enum Phase: Equatable {
        case movePiece
        case placeDuck
    }

    private(set) var position: Position
    private(set) var board: Board
    private(set) var phase: Phase = .movePiece
    private(set) var duckSquare: Square?
    private(set) var outcome: GameOutcome?

    private(set) var sanLog: [String] = []
    private(set) var selectedSquare: Square?
    private(set) var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?

    struct PendingPromotion: Equatable { let from: Square; let to: Square }
    private(set) var pendingPromotion: PendingPromotion?

    /// Case de prise en passant offerte par le coup précédent.
    private var enPassant: Square?

    static let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    init() {
        let start = Position(fen: Self.startFEN)!
        position = start
        board = Board(position: start)
    }

    var sideToMove: Piece.Color { position.sideToMove }

    var totalPlies: Int { sanLog.count }

    var numberedMoves: [(number: Int, white: String, black: String?)] {
        stride(from: 0, to: sanLog.count, by: 2).map { index in
            (index / 2 + 1, sanLog[index], index + 1 < sanLog.count ? sanLog[index + 1] : nil)
        }
    }

    /// Ce que l'écran doit dire de faire, ici et maintenant.
    var instruction: String {
        if outcome != nil { return LocalizationController.string("Partie terminée") }
        return phase == .movePiece
            ? LocalizationController.string("Déplacez une pièce")
            : LocalizationController.string("Posez le canard sur une case vide")
    }

    // MARK: Interaction

    func selectSquare(_ square: Square) {
        guard outcome == nil, pendingPromotion == nil else { return }

        if phase == .placeDuck {
            placeDuck(on: square)
            return
        }

        if selectedSquare != nil, legalTargetSquares.contains(square) {
            attemptMove(to: square)
            return
        }
        guard let piece = position.piece(at: square), piece.color == sideToMove else {
            clearSelection()
            return
        }
        selectedSquare = square
        legalTargetSquares = Array(Set(
            currentMoves.filter { $0.from == square }.map(\.to)
        ))
    }

    func attemptUserMove(from start: Square, to end: Square) {
        guard outcome == nil, phase == .movePiece else { return }
        guard let piece = position.piece(at: start), piece.color == sideToMove else {
            Haptics.illegal()
            return
        }
        selectedSquare = start
        legalTargetSquares = Array(Set(currentMoves.filter { $0.from == start }.map(\.to)))
        attemptMove(to: end)
    }

    private func attemptMove(to end: Square) {
        guard let from = selectedSquare else { return }
        let candidates = currentMoves.filter { $0.from == from && $0.to == end }
        guard !candidates.isEmpty else {
            Haptics.illegal()
            clearSelection()
            return
        }
        if candidates.contains(where: { $0.promotion != nil }) {
            pendingPromotion = PendingPromotion(from: from, to: end)
            clearSelection()
            return
        }
        apply(candidates[0])
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        apply(DuckChessRules.Move(from: pending.from, to: pending.to, promotion: kind))
    }

    func cancelPromotion() { pendingPromotion = nil }

    /// Pose le canard, ce qui CLÔT le tour et passe le trait.
    private func placeDuck(on square: Square) {
        guard DuckChessRules.duckTargets(in: position, currentDuck: duckSquare).contains(square) else {
            Haptics.illegal()
            return
        }
        duckSquare = square
        phase = .movePiece
        // Le trait ne change qu'ICI : c'est la pose du canard qui termine le
        // tour, pas le déplacement de la pièce.
        position = flippedSideToMove(of: position)
        board = Board(position: position)
        Haptics.move()
    }

    // MARK: Application d'un coup

    private var currentMoves: [DuckChessRules.Move] {
        DuckChessRules.moves(in: position, duck: duckSquare, enPassant: enPassant)
    }

    private func apply(_ move: DuckChessRules.Move) {
        clearSelection()
        guard let piece = position.piece(at: move.from) else { return }

        let victim = DuckChessRules.capturesKing(move, in: position)
        let san = DuckChessSAN.build(
            move: move, position: position, legalMoves: currentMoves, capturesKing: victim != nil
        )

        // La prise se lit sur la position d'AVANT : après le coup, la case
        // d'arrivée porte forcément la pièce qui vient d'y aller.
        let captured = position.piece(at: move.to)
        position = applied(move, to: position)
        board = Board(position: position)
        sanLog.append(san)
        lastMove = Move(
            result: captured.map { Move.Result.capture($0) } ?? .move,
            piece: piece, start: move.from, end: move.to
        )

        // Poussée double : la case survolée devient prenable en passant.
        if piece.kind == .pawn, abs(move.to.rank.value - move.from.rank.value) == 2 {
            let middle = (move.to.rank.value + move.from.rank.value) / 2
            enPassant = Square("\(move.from.file.rawValue)\(middle)")
        } else {
            enPassant = nil
        }

        if let victim {
            // Le roi est tombé : la partie s'arrête AVANT même la pose du
            // canard, qui n'aurait plus d'objet.
            outcome = GameOutcome(winner: victim.opposite, reason: .checkmate)
            phase = .movePiece
            Haptics.gameEnded()
            SoundPlayer.shared.play(.check)
            return
        }

        phase = .placeDuck
        SoundPlayer.shared.play(san.contains("x") ? .capture : .move)
    }

    private func clearSelection() {
        selectedSquare = nil
        legalTargetSquares = []
    }

    // MARK: Manipulation de position

    /// Joue le coup sur la position, en passant par la FEN.
    ///
    /// ChessKit refuserait ces coups (il filtre sur l'échec, absent ici), donc
    /// on écrit nous-mêmes le plateau résultant — c'est la contrepartie
    /// assumée d'une variante sans arbitre.
    private func applied(_ move: DuckChessRules.Move, to position: Position) -> Position {
        var squares: [Square: Piece] = [:]
        for piece in position.pieces { squares[piece.square] = piece }

        guard let moving = squares[move.from] else { return position }
        squares[move.from] = nil

        // Prise en passant : le pion capturé n'est PAS sur la case d'arrivée.
        if moving.kind == .pawn, move.from.file != move.to.file, squares[move.to] == nil {
            let capturedRank = move.from.rank.value
            squares[Square("\(move.to.file.rawValue)\(capturedRank)")] = nil
        }
        // Roque : la tour suit le roi.
        if moving.kind == .king, abs(move.to.file.number - move.from.file.number) == 2 {
            let rank = move.from.rank.value
            let isShort = move.to.file.number > move.from.file.number
            let rookFrom = Square("\(isShort ? "h" : "a")\(rank)")
            let rookTo = Square("\(isShort ? "f" : "d")\(rank)")
            if let rook = squares[rookFrom] {
                squares[rookFrom] = nil
                squares[rookTo] = Piece(rook.kind, color: rook.color, square: rookTo)
            }
        }
        let landedKind = move.promotion ?? moving.kind
        squares[move.to] = Piece(landedKind, color: moving.color, square: move.to)

        return Position(
            fen: DuckChessFEN.build(
                squares: squares,
                // Le trait reste au MÊME camp : son tour n'est pas fini, il
                // lui reste le canard à poser. C'est ``placeDuck(on:)`` qui
                // le passe, et lui seul — les faire tous les deux basculait
                // le trait deux fois par demi-coup, donc jamais.
                sideToMove: position.sideToMove,
                castling: DuckChessFEN.updatedCastling(
                    from: position, movedPiece: moving, from: move.from, to: move.to
                )
            )
        ) ?? position
    }

    /// Rend la main à l'autre camp sans rien bouger — le trait change à la
    /// POSE du canard, pas au déplacement.
    private func flippedSideToMove(of position: Position) -> Position {
        var fields = position.fen.split(separator: " ").map(String.init)
        guard fields.count >= 2 else { return position }
        fields[1] = fields[1] == "w" ? "b" : "w"
        return Position(fen: fields.joined(separator: " ")) ?? position
    }

    // MARK: Abandon

    func resign(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .resignation)
        Haptics.gameEnded()
    }
}
