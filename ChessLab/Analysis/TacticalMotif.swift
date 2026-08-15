import ChessKit

/// Le motif tactique qui PUNIT un coup — ce que l'adversaire va en faire.
///
/// Chaque cas est établi en **rejouant la réfutation du moteur sur un
/// plateau**, jamais inféré d'un score : c'est toute la différence entre
/// « votre coup perd 12 % » et « votre coup perd une pièce, et voici
/// comment ». Un motif faux serait pire que pas de motif du tout — dans une
/// app d'apprentissage, une explication inventée s'apprend aussi bien qu'une
/// vraie —, d'où la règle : rien ici n'est deviné.
enum TacticalMotif: Equatable {
    /// La réfutation mate. `inMoves` compte les coups du camp qui mate (1 =
    /// mat au coup suivant).
    case checkmate(inMoves: Int, isBackRank: Bool)
    /// Une pièce de valeur est simplement prise, et rien ne peut reprendre.
    case hangingPiece(kind: Piece.Kind, on: Square)
    /// Une pièce attaque d'un seul coup au moins deux cibles de valeur — on ne
    /// peut pas les sauver toutes.
    case fork(by: Piece.Kind, on: Square, targets: [Piece.Kind])
    /// L'échec ne vient pas de la pièce qui a bougé mais de celle qu'elle
    /// vient de démasquer.
    case discoveredCheck(by: Piece.Kind)
    /// Une pièce est clouée : la bouger exposerait une pièce plus chère
    /// derrière elle (le roi, dans le cas d'un clouage absolu).
    case pin(victim: Piece.Kind, behind: Piece.Kind)
}

/// Reconnaît le motif d'UN coup — celui que l'adversaire joue pour punir.
///
/// Fonction pure sur `(coup, plateau après ce coup)` : aucune requête moteur,
/// aucune dépendance à l'interface, donc entièrement testable sur des
/// positions choisies.
///
/// - note: `PuzzleThemeDetector` fait un travail voisin sur les solutions de
///   puzzles, avec deux motifs seulement (pièce en prise, fourchette). Les
///   deux n'ont volontairement PAS été fusionnés ici : le détecteur de thèmes
///   étiquette une bibliothèque de puzzles déjà en base, et changer son
///   verdict rétiquetterait des puzzles existants. La fusion se fera quand
///   elle sera l'objet du chantier, pas en passant.
enum TacticalMotifDetector {

    /// Une cible « de valeur » : cavalier ou plus. Le roi ne vaut rien au
    /// matériel (voir ``pieceValue(_:)``) mais reste évidemment la cible qui
    /// compte le plus — d'où le cas explicite.
    static func isValuableTarget(_ kind: Piece.Kind) -> Bool {
        kind == .king || pieceValue(kind) >= 3
    }

    /// Ordre de mention dans une phrase : le roi d'abord, puis par valeur
    /// décroissante. « Fourchette sur le roi et la tour » se lit mieux que
    /// « sur la tour et le roi », et c'est aussi l'ordre de la menace.
    private static func threatRank(_ kind: Piece.Kind) -> Int {
        kind == .king ? 100 : pieceValue(kind)
    }

    /// Le motif du coup `move`, joué sur la position que `board` représente
    /// MAINTENANT (donc après le coup).
    ///
    /// L'ordre des tests est l'ordre de ce qui apprend le plus : un mat prime
    /// tout, une fourchette explique mieux qu'une simple perte matérielle, et
    /// « la pièce était en prise » ne sert que quand rien de plus fin ne
    /// s'applique. `nil` quand le coup ne porte aucun motif nommable — c'est
    /// fréquent et parfaitement normal, la perte matérielle prend alors le
    /// relais (voir ``MoveExplainer``).
    static func detect(punishing move: Move, boardAfter board: Board) -> TacticalMotif? {
        let victim = move.piece.color.opposite

        if case let .checkmate(matedColor) = board.state, matedColor == victim {
            return .checkmate(inMoves: 1, isBackRank: isBackRankMate(of: matedColor, board: board))
        }
        if let fork = detectFork(move, board: board) { return fork }
        if let discovered = detectDiscoveredCheck(move, board: board) { return discovered }
        if let pin = detectPin(move, board: board) { return pin }
        return detectHangingCapture(move, board: board)
    }

    /// Mat du couloir : le roi maté est sur SA rangée de fond et les trois
    /// cases devant lui (diagonales comprises) sont bouchées par ses propres
    /// pièces. C'est la définition littérale du motif — un roi qui étouffe
    /// derrière ses propres pions —, pas « le roi est sur la 1re rangée »,
    /// qui étiquetterait n'importe quel mat de finale.
    static func isBackRankMate(of color: Piece.Color, board: Board) -> Bool {
        guard let king = board.position.pieces.first(where: { $0.color == color && $0.kind == .king })
        else { return false }

        let homeRank = color == .white ? 1 : 8
        guard king.square.rank.value == homeRank else { return false }

        let escapeRank = color == .white ? 2 : 7
        let files = (king.square.file.number - 1)...(king.square.file.number + 1)
        let escapes = files.filter { (1...8).contains($0) }.map { square(file: $0, rank: escapeRank) }

        // Toutes bouchées par ses PROPRES pièces : une case vide (ou occupée
        // par l'adversaire, donc capturable) ferait du mat autre chose.
        return escapes.allSatisfy { board.position.piece(at: $0)?.color == color }
    }

    // MARK: Motifs

    /// La pièce qui vient d'arriver attaque au moins deux cibles de valeur.
    ///
    /// `legalMoves(forPieceAt:)` de ChessKit ignore le trait et inclut les
    /// cases occupées par l'adversaire, roi compris — c'est exactement ce
    /// qu'il faut ici, et c'est ce qui donne la fourchette royale (échec + une
    /// pièce) sans traitement à part.
    private static func detectFork(_ move: Move, board: Board) -> TacticalMotif? {
        let victim = move.piece.color.opposite
        let targets = board.legalMoves(forPieceAt: move.end)
            .compactMap { board.position.piece(at: $0) }
            .filter { $0.color == victim && isValuableTarget($0.kind) }

        guard targets.count >= 2 else { return nil }
        return .fork(
            by: arrivingKind(of: move, board: board),
            on: move.end,
            targets: targets.map(\.kind).sorted { threatRank($0) > threatRank($1) }
        )
    }

    /// Échec donné par une pièce AUTRE que celle qui vient de bouger.
    private static func detectDiscoveredCheck(_ move: Move, board: Board) -> TacticalMotif? {
        let victim = move.piece.color.opposite
        guard case let .check(checkedColor) = board.state, checkedColor == victim else { return nil }
        guard let kingSquare = board.position.pieces
            .first(where: { $0.color == victim && $0.kind == .king })?.square
        else { return nil }

        // Si la pièce arrivée attaque elle-même le roi, l'échec est direct :
        // rien de « découvert » à raconter.
        guard !board.legalMoves(forPieceAt: move.end).contains(kingSquare) else { return nil }

        // Nommer la pièce qui donne RÉELLEMENT l'échec — c'est elle, le sujet
        // de la phrase, pas celle qui s'est écartée.
        let checker = board.position.pieces.first {
            $0.color == move.piece.color
                && $0.square != move.end
                && board.legalMoves(forPieceAt: $0.square).contains(kingSquare)
        }
        return .discoveredCheck(by: checker?.kind ?? arrivingKind(of: move, board: board))
    }

    /// Clouage créé par la pièce qui vient d'arriver : en partant d'elle, la
    /// première pièce rencontrée sur un rayon est adverse, et derrière elle se
    /// trouve une pièce du même camp plus chère (ou le roi).
    private static func detectPin(_ move: Move, board: Board) -> TacticalMotif? {
        let directions: [(file: Int, rank: Int)]
        switch arrivingKind(of: move, board: board) {
        case .rook: directions = orthogonal
        case .bishop: directions = diagonal
        case .queen: directions = orthogonal + diagonal
        default: return nil  // Seule une pièce à longue portée peut clouer.
        }

        let victim = move.piece.color.opposite
        for direction in directions {
            var file = move.end.file.number + direction.file
            var rank = move.end.rank.value + direction.rank
            var pinned: Piece?

            while (1...8).contains(file), (1...8).contains(rank) {
                if let piece = board.position.piece(at: square(file: file, rank: rank)) {
                    guard let front = pinned else {
                        // Première pièce du rayon. Un roi n'est pas cloué, il
                        // est en échec — et une pièce à nous bloque le rayon.
                        guard piece.color == victim, piece.kind != .king else { break }
                        pinned = piece
                        file += direction.file
                        rank += direction.rank
                        continue
                    }
                    // Deuxième pièce : le clouage n'existe que si elle est du
                    // même camp que la première et vaut plus cher qu'elle.
                    guard piece.color == victim else { break }
                    guard piece.kind == .king || pieceValue(piece.kind) > pieceValue(front.kind) else { break }
                    return .pin(victim: front.kind, behind: piece.kind)
                }
                file += direction.file
                rank += direction.rank
            }
        }
        return nil
    }

    /// Le coup prend une pièce de valeur que rien ne peut reprendre : elle
    /// était vraiment en prise, ce n'était pas un échange.
    private static func detectHangingCapture(_ move: Move, board: Board) -> TacticalMotif? {
        guard case let .capture(captured) = move.result, isValuableTarget(captured.kind) else { return nil }

        let victim = move.piece.color.opposite
        let canRecapture = board.position.pieces
            .filter { $0.color == victim }
            .contains { board.canMove(pieceAt: $0.square, to: move.end) }

        return canRecapture ? nil : .hangingPiece(kind: captured.kind, on: move.end)
    }

    // MARK: Utilitaires

    /// Le type de la pièce qui se trouve à l'arrivée — et non `move.piece`,
    /// qui vaut « pion » après une promotion. Une dame fraîchement promue qui
    /// cloue doit être nommée dame.
    private static func arrivingKind(of move: Move, board: Board) -> Piece.Kind {
        board.position.piece(at: move.end)?.kind ?? move.piece.kind
    }

    private static let orthogonal: [(file: Int, rank: Int)] = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let diagonal: [(file: Int, rank: Int)] = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

    /// `Square.init(_:_:)` (fichier, rangée) est interne à ChessKit ; on passe
    /// donc par la notation, seul constructeur public. Les appelants bornent
    /// déjà `file` et `rank` à 1...8.
    private static func square(file: Int, rank: Int) -> Square {
        Square(Square.File(file).rawValue + "\(rank)")
    }
}
