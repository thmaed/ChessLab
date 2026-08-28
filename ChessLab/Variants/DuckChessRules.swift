import ChessKit

/// Règles du Duck Chess, calculées EN SWIFT — la seule variante du hub dans
/// ce cas, et elle n'avait pas le choix.
///
/// ## Pourquoi pas le moteur
///
/// Fairy-Stockfish ignore cette variante, et rien dans le moteur vendorisé ne
/// permet de la décrire : aucun mécanisme de mur ou de case bloquée
/// (`variants.ini` n'a pas de `wallingRule`). S'ajoute une impossibilité de
/// fond : un coup y est DEUX actions — déplacer une pièce, puis poser le
/// canard sur une case vide — ce que le protocole UCI ne sait pas exprimer,
/// et dont le nombre de combinaisons (coups légaux × cases vides) rendrait la
/// recherche absurde.
///
/// ## Ce qui change par rapport aux échecs
///
/// - Le canard occupe une case et la **bloque totalement** : aucune pièce ne
///   peut s'y poser, ni la traverser. Il ne se capture pas, et n'appartient à
///   personne.
/// - Il n'y a **ni échec, ni mat, ni pat**. Un roi a le droit de se mettre en
///   prise, et de rester sous une attaque. On gagne en **capturant le roi**.
///   C'est pourquoi les coups légaux de ChessKit ne conviennent pas ici : il
///   les filtre justement sur l'échec. Ce fichier génère donc lui-même les
///   coups, pseudo-légaux au sens classique.
/// - Le roque suit les règles habituelles de cases vides et de droits, mais
///   sans la contrainte d'échec — et le canard bloque comme n'importe quoi
///   d'autre.
enum DuckChessRules {

    struct Move: Hashable {
        let from: Square
        let to: Square
        var promotion: Piece.Kind?

        var uci: String {
            from.notation + to.notation + (promotion.map { $0.rawValue.lowercased() } ?? "")
        }
    }

    /// Tous les coups jouables par le camp au trait, canard compris.
    ///
    /// - parameter duck: case occupée par le canard, `nil` au tout premier
    ///   coup de la partie (il n'est pas encore posé).
    /// - parameter enPassant: case de prise en passant, si le coup précédent
    ///   était une poussée double.
    static func moves(in position: Position, duck: Square?, enPassant: Square? = nil) -> [Move] {
        let mover = position.sideToMove
        var result: [Move] = []
        for piece in position.pieces where piece.color == mover {
            result += moves(for: piece, in: position, duck: duck, enPassant: enPassant)
        }
        return result
    }

    /// Cases où le canard peut se poser : toutes les cases vides, sauf celle
    /// qu'il occupe déjà — il DOIT bouger à chaque tour.
    static func duckTargets(in position: Position, currentDuck: Square?) -> [Square] {
        allSquares.filter { square in
            position.piece(at: square) == nil && square != currentDuck
        }
    }

    /// Le coup capture-t-il un roi ? C'est la seule fin de partie.
    static func capturesKing(_ move: Move, in position: Position) -> Piece.Color? {
        guard let captured = position.piece(at: move.to), captured.kind == .king else { return nil }
        return captured.color
    }

    // MARK: Génération par pièce

    private static func moves(
        for piece: Piece, in position: Position, duck: Square?, enPassant: Square?
    ) -> [Move] {
        let from = piece.square
        let file = from.file.number
        let rank = from.rank.value

        switch piece.kind {
        case .pawn:
            return pawnMoves(piece: piece, file: file, rank: rank, position: position, duck: duck, enPassant: enPassant)
        case .knight:
            let jumps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]
            return jumps.compactMap { step in
                guard let to = square(file + step.0, rank + step.1),
                      isLandable(to, for: piece.color, position: position, duck: duck)
                else { return nil }
                return Move(from: from, to: to)
            }
        case .bishop:
            return slide(from: from, color: piece.color, directions: diagonals, position: position, duck: duck)
        case .rook:
            return slide(from: from, color: piece.color, directions: straights, position: position, duck: duck)
        case .queen:
            return slide(from: from, color: piece.color, directions: diagonals + straights, position: position, duck: duck)
        case .king:
            var moves = (diagonals + straights).compactMap { step -> Move? in
                guard let to = square(file + step.0, rank + step.1),
                      isLandable(to, for: piece.color, position: position, duck: duck)
                else { return nil }
                return Move(from: from, to: to)
            }
            moves += castles(for: piece, position: position, duck: duck)
            return moves
        }
    }

    private static func pawnMoves(
        piece: Piece, file: Int, rank: Int, position: Position, duck: Square?, enPassant: Square?
    ) -> [Move] {
        let forward = piece.color == .white ? 1 : -1
        let startRank = piece.color == .white ? 2 : 7
        let lastRank = piece.color == .white ? 8 : 1
        let from = piece.square
        var moves: [Move] = []

        func add(_ to: Square) {
            if to.rank.value == lastRank {
                for kind in [Piece.Kind.queen, .rook, .bishop, .knight] {
                    moves.append(Move(from: from, to: to, promotion: kind))
                }
            } else {
                moves.append(Move(from: from, to: to))
            }
        }

        // Poussée simple, puis double — l'une comme l'autre exige une case
        // LIBRE, et le canard occupe une case comme n'importe quelle pièce.
        if let one = square(file, rank + forward), isEmpty(one, position: position, duck: duck) {
            add(one)
            if rank == startRank, let two = square(file, rank + 2 * forward),
               isEmpty(two, position: position, duck: duck) {
                moves.append(Move(from: from, to: two))
            }
        }
        // Prises en diagonale : sur une pièce adverse, ou en passant. JAMAIS
        // sur le canard, qui ne se capture pas.
        for side in [-1, 1] {
            guard let to = square(file + side, rank + forward), to != duck else { continue }
            if let target = position.piece(at: to), target.color != piece.color {
                add(to)
            } else if let enPassant, to == enPassant, position.piece(at: to) == nil {
                moves.append(Move(from: from, to: to))
            }
        }
        return moves
    }

    private static func castles(for king: Piece, position: Position, duck: Square?) -> [Move] {
        let rights = castlingRights(in: position)
        let rank = king.color == .white ? 1 : 8
        guard king.square == square(5, rank) else { return [] }
        var moves: [Move] = []

        // Petit roque : f et g libres. Grand roque : b, c et d libres.
        let plans: [(right: Character, empties: [Int], kingTo: Int)] = [
            (king.color == .white ? "K" : "k", [6, 7], 7),
            (king.color == .white ? "Q" : "q", [2, 3, 4], 3),
        ]
        for plan in plans where rights.contains(plan.right) {
            let squares = plan.empties.compactMap { square($0, rank) }
            guard squares.count == plan.empties.count,
                  squares.allSatisfy({ isEmpty($0, position: position, duck: duck) }),
                  let to = square(plan.kingTo, rank)
            else { continue }
            // Aucune vérification d'échec : en Duck Chess, le roi peut roquer
            // à travers une case attaquée, et même « en échec » — la notion
            // n'existe pas.
            moves.append(Move(from: king.square, to: to))
        }
        return moves
    }

    private static func slide(
        from: Square, color: Piece.Color, directions: [(Int, Int)], position: Position, duck: Square?
    ) -> [Move] {
        var moves: [Move] = []
        for step in directions {
            var file = from.file.number + step.0
            var rank = from.rank.value + step.1
            while let to = square(file, rank) {
                // Le canard ARRÊTE la ligne sans pouvoir être pris : c'est ce
                // qui le distingue d'une pièce adverse.
                if to == duck { break }
                if let occupant = position.piece(at: to) {
                    if occupant.color != color { moves.append(Move(from: from, to: to)) }
                    break
                }
                moves.append(Move(from: from, to: to))
                file += step.0
                rank += step.1
            }
        }
        return moves
    }

    // MARK: Outils

    private static let diagonals = [(1, 1), (1, -1), (-1, -1), (-1, 1)]
    private static let straights = [(0, 1), (1, 0), (0, -1), (-1, 0)]
    private static let files = "abcdefgh"

    static let allSquares: [Square] = (1...8).flatMap { rank in
        (1...8).compactMap { file in square(file, rank) }
    }

    private static func square(_ file: Int, _ rank: Int) -> Square? {
        guard (1...8).contains(file), (1...8).contains(rank) else { return nil }
        let letter = files[files.index(files.startIndex, offsetBy: file - 1)]
        return Square("\(letter)\(rank)")
    }

    private static func isEmpty(_ square: Square, position: Position, duck: Square?) -> Bool {
        position.piece(at: square) == nil && square != duck
    }

    /// Une case est atteignable si le canard n'y est pas et qu'elle ne porte
    /// pas une pièce AMIE.
    private static func isLandable(
        _ square: Square, for color: Piece.Color, position: Position, duck: Square?
    ) -> Bool {
        guard square != duck else { return false }
        guard let occupant = position.piece(at: square) else { return true }
        return occupant.color != color
    }

    /// Droits de roque, lus dans la FEN — `Position` ne les expose pas.
    private static func castlingRights(in position: Position) -> String {
        let fields = position.fen.split(separator: " ")
        guard fields.count >= 3 else { return "" }
        let rights = String(fields[2])
        return rights == "-" ? "" : rights
    }
}
