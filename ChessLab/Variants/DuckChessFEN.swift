import ChessKit

/// Écriture d'une FEN pour le Duck Chess.
///
/// Nécessaire parce que la variante joue des coups que ChessKit REFUSE — il
/// filtre sur l'échec, notion absente ici (voir ``DuckChessRules``). On ne
/// peut donc pas lui demander d'appliquer le coup et de rendre la position ;
/// on écrit le plateau résultant nous-mêmes, et on le relit.
///
/// Le canard ne figure PAS dans la FEN : il n'est pas une pièce, il vit à
/// part dans le view model. Une FEN de Duck Chess est donc une FEN ordinaire,
/// relisible par ChessKit — c'est ce qui permet de réutiliser tout l'affichage
/// sans le toucher.
enum DuckChessFEN {

    static func build(
        squares: [Square: Piece], sideToMove: Piece.Color, castling: String
    ) -> String {
        var ranks: [String] = []
        for rank in stride(from: 8, through: 1, by: -1) {
            var line = ""
            var empty = 0
            for file in "abcdefgh" {
                let square = Square("\(file)\(rank)")
                if let piece = squares[square] {
                    if empty > 0 { line += "\(empty)"; empty = 0 }
                    line += letter(for: piece)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { line += "\(empty)" }
            ranks.append(line)
        }
        let rights = castling.isEmpty ? "-" : castling
        return "\(ranks.joined(separator: "/")) \(sideToMove == .white ? "w" : "b") \(rights) - 0 1"
    }

    /// Droits de roque après un coup : le roi les perd tous, une tour perd le
    /// sien. Aucun ne se regagne.
    static func updatedCastling(
        from position: Position, movedPiece: Piece, from origin: Square, to destination: Square
    ) -> String {
        let fields = position.fen.split(separator: " ")
        var rights = fields.count >= 3 ? String(fields[2]) : "-"
        if rights == "-" { return "" }

        func drop(_ characters: [Character]) {
            rights.removeAll { characters.contains($0) }
        }
        if movedPiece.kind == .king {
            drop(movedPiece.color == .white ? ["K", "Q"] : ["k", "q"])
        }
        // Une tour qui bouge, ou qui se fait prendre sur sa case d'origine.
        for square in [origin, destination] {
            switch square.notation {
            case "a1": drop(["Q"])
            case "h1": drop(["K"])
            case "a8": drop(["q"])
            case "h8": drop(["k"])
            default: break
            }
        }
        return rights
    }

    private static func letter(for piece: Piece) -> String {
        let base: String
        switch piece.kind {
        case .pawn: base = "p"
        case .knight: base = "n"
        case .bishop: base = "b"
        case .rook: base = "r"
        case .queen: base = "q"
        case .king: base = "k"
        }
        return piece.color == .white ? base.uppercased() : base
    }
}
