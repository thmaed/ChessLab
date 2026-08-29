import ChessKit

/// Construit une notation SAN à partir d'un coup UCI/LAN — nécessaire pour
/// ``EngineLegalityVariant`` : contrairement à ``FairyVariant`` (lot A), les
/// coups n'y sont jamais joués via ChessKit (`Board.move(pieceAt:to:)`,
/// qui fournirait `Move.san` gratuitement) — ChessKit ne sert plus qu'à
/// LIRE un FEN fourni par le moteur, jamais à statuer sur un coup. Fairy-
/// Stockfish lui-même ne rend le SAN nulle part (`go perft`/`d` parlent
/// UCI/LAN) : à construire à la main.
enum EngineLegalitySAN {
    /// - parameter uci: coup joué, notation UCI/LAN (`"e2e4"`, `"e7e8q"`).
    /// - parameter beforeFEN: position AVANT le coup.
    /// - parameter legalMovesAtPosition: coups légaux de `beforeFEN` (même
    ///   format UCI) — sert à la désambiguïsation (deux pièces identiques
    ///   pouvant atteindre la même case).
    /// - parameter isCheck: le coup met-il l'adversaire en échec.
    /// - parameter isMate: le coup met-il l'adversaire échec et mat.
    static func build(
        uci: String, beforeFEN: String, legalMovesAtPosition: [String],
        isCheck: Bool, isMate: Bool
    ) -> String {
        // Une POSE (Crazyhouse) s'écrit déjà en SAN : `P@e4` est la notation
        // standard, il ne manque que le suffixe d'échec. Traitée en premier,
        // car tout ce qui suit suppose une case de DÉPART, qu'une pose n'a pas.
        if let atIndex = uci.firstIndex(of: "@") {
            let kind = String(uci[uci.startIndex..<atIndex]).uppercased()
            let square = String(uci[uci.index(after: atIndex)...])
            return kind + "@" + square + suffix(isCheck: isCheck, isMate: isMate)
        }
        // FEN assainie : celle du moteur porte la réserve du Crazyhouse et
        // ses marques de promotion, que ChessKit lit de travers — voir
        // ``CrazyhouseFEN``.
        guard let position = Position(fen: VariantFEN.forChessKit(beforeFEN)), uci.count >= 4
        else { return uci }
        let from = Square(String(uci.prefix(2)))
        let to = Square(String(uci.dropFirst(2).prefix(2)))
        guard let piece = position.piece(at: from) else { return uci }
        let promotion = uci.count == 5 ? String(uci.suffix(1)).uppercased() : nil

        if piece.kind == .king, abs(to.file.number - from.file.number) == 2 {
            let base = to.file.number > from.file.number ? "O-O" : "O-O-O"
            return base + suffix(isCheck: isCheck, isMate: isMate)
        }

        let targetOccupied = position.piece(at: to) != nil
        let isEnPassant = piece.kind == .pawn && from.file != to.file && !targetOccupied
        let isCapture = targetOccupied || isEnPassant

        var body = ""
        if piece.kind == .pawn {
            if isCapture { body += String(from.notation.prefix(1)) + "x" }
            body += to.notation
            if let promotion { body += "=" + promotion }
        } else {
            body += piece.kind.rawValue
            body += disambiguation(piece: piece, from: from, to: to, legalMoves: legalMovesAtPosition, position: position)
            if isCapture { body += "x" }
            body += to.notation
        }
        return body + suffix(isCheck: isCheck, isMate: isMate)
    }

    private static func suffix(isCheck: Bool, isMate: Bool) -> String {
        isMate ? "#" : (isCheck ? "+" : "")
    }

    /// Cases d'ORIGINE d'autres coups légaux de la MÊME pièce vers la MÊME
    /// case d'arrivée — désambiguïsation SAN standard (colonne d'abord,
    /// rangée si la colonne ne suffit pas, les deux en dernier recours).
    private static func disambiguation(
        piece: Piece, from: Square, to: Square, legalMoves: [String], position: Position
    ) -> String {
        let others = legalMoves.compactMap { move -> Square? in
            guard move.count >= 4 else { return nil }
            let candidateFrom = Square(String(move.prefix(2)))
            let candidateTo = Square(String(move.dropFirst(2).prefix(2)))
            guard candidateFrom != from, candidateTo == to,
                  let candidatePiece = position.piece(at: candidateFrom),
                  candidatePiece.kind == piece.kind, candidatePiece.color == piece.color
            else { return nil }
            return candidateFrom
        }
        guard !others.isEmpty else { return "" }
        if !others.contains(where: { $0.file == from.file }) {
            return String(from.notation.prefix(1))
        }
        if !others.contains(where: { $0.rank == from.rank }) {
            return String(from.notation.suffix(1))
        }
        return from.notation
    }
}
