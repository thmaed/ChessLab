import Foundation
import ChessKit

/// Édition d'un répertoire PERSONNEL : ajouter une variante, en retirer une,
/// commenter un coup.
///
/// Couche PURE, sans état ni interface : chaque opération prend un cours et en
/// rend un autre. C'est ce qui la rend testable sans simulateur, et c'est
/// délibéré — un éditeur d'arbre est exactement le genre de code où une erreur
/// de graphe (arête orpheline, nœud inatteignable, chapitre pendant) ne se voit
/// pas à l'écran mais casse la validation à l'enregistrement.
///
/// Deux invariants tenus par construction, et vérifiés par les tests :
/// 1. **aucune arête que le validateur rejetterait** — le coup est rejoué par
///    ``OpeningCourseValidator/resultingKey(afterUCI:from:)``, la même mécanique
///    que l'import PGN, avant de fabriquer quoi que ce soit ;
/// 2. **aucun nœud inatteignable** — après un retrait, le graphe est reparcouru
///    depuis `rootFEN` et ce qui n'est plus joignable disparaît, chapitres
///    compris. Sans ça, `UserOpeningStore.save` refuserait le cours.
///
/// Le graphe est indexé par FEN : retirer une arête ne retire donc PAS toujours
/// les positions qui suivent, puisqu'une transposition peut encore y mener.
/// C'est pourquoi la purge se calcule par accessibilité, jamais en descendant
/// naïvement le sous-arbre.
enum OpeningCourseEditor {

    enum EditError: LocalizedError, Equatable {
        case unknownPosition(String)
        case illegalMove(String)
        case duplicateMove(String)

        var errorDescription: String? {
            switch self {
            case .unknownPosition:
                LocalizationController.string("Cette position n'est pas dans le répertoire.")
            case .illegalMove(let san):
                LocalizationController.string("Coup impossible dans cette position : %@", san)
            case .duplicateMove(let san):
                LocalizationController.string("Ce coup est déjà dans le répertoire : %@", san)
            }
        }
    }

    // MARK: Ajout

    /// Ajoute un coup depuis `fen`, en créant au besoin la position d'arrivée.
    ///
    /// Si la position d'arrivée existe déjà (transposition), elle est REUTILISÉE
    /// telle quelle : c'est tout l'intérêt du graphe, et l'utilisateur retrouve
    /// d'un coup ce qu'il a déjà écrit ailleurs.
    static func addMove(
        uci: String, from fen: String, role: MoveRole = .sideline, in course: OpeningCourse
    ) throws -> OpeningCourse {
        guard let node = course.positions[fen] else { throw EditError.unknownPosition(fen) }
        guard let played = play(uci: uci, from: fen) else { throw EditError.illegalMove(uci) }
        guard !node.moves.contains(where: { $0.uci == uci }) else {
            throw EditError.duplicateMove(played.san)
        }

        var positions = course.positions
        positions[fen] = node.replacing(
            moves: node.moves + [MoveEdge(san: played.san, uci: uci, toFEN: played.key, role: role)]
        )
        if positions[played.key] == nil {
            positions[played.key] = PositionNode(fen: played.key)
        }
        return course.replacing(positions: positions, chapters: course.chapters)
    }

    // MARK: Retrait

    /// Retire un coup, puis purge ce qui n'est plus atteignable depuis la racine.
    /// Sans effet si le coup n'existe pas — un retrait deux fois demandé n'est
    /// pas une erreur.
    static func removeMove(uci: String, from fen: String, in course: OpeningCourse) -> OpeningCourse {
        guard let node = course.positions[fen] else { return course }
        let remaining = node.moves.filter { $0.uci != uci }
        guard remaining.count != node.moves.count else { return course }

        var positions = course.positions
        positions[fen] = node.replacing(moves: remaining)
        positions = reachable(from: course.rootFEN, in: positions)
        let chapters = cleaned(course.chapters, keeping: Set(positions.keys))
        return course.replacing(positions: positions, chapters: chapters)
    }

    // MARK: Commentaire

    /// Écrit (ou efface, avec `nil`) le commentaire d'un coup dans une langue.
    ///
    /// Le statut passe à `validated` : le texte vient de l'utilisateur lui-même.
    /// La règle « jamais de brouillon affiché comme théorie sûre » vise le
    /// contenu GÉNÉRÉ, pas ce que l'auteur écrit de sa main — même raisonnement
    /// que l'import PGN, qui conserve les commentaires du fichier.
    ///
    /// L'autre langue est PRÉSERVÉE : commenter en français un cours reçu d'un
    /// ami anglophone ne doit pas effacer son texte anglais.
    static func setComment(
        _ text: String?, code: String, uci: String, from fen: String, in course: OpeningCourse
    ) -> OpeningCourse {
        guard let node = course.positions[fen],
              let index = node.moves.firstIndex(where: { $0.uci == uci })
        else { return course }

        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleared = (trimmed?.isEmpty ?? true)
        let existing = node.moves[index].comment
        let updated = LocalizedText(
            fr: code == "fr" ? (cleared ? nil : trimmed) : existing?.fr,
            en: code == "fr" ? existing?.en : (cleared ? nil : trimmed)
        )
        let isEmpty = updated.fr == nil && updated.en == nil

        var moves = node.moves
        moves[index] = moves[index].replacing(
            comment: isEmpty ? nil : updated,
            status: isEmpty ? nil : .validated
        )
        var positions = course.positions
        positions[fen] = node.replacing(moves: moves)
        return course.replacing(positions: positions, chapters: course.chapters)
    }

    // MARK: Renommage

    static func rename(_ course: OpeningCourse, to name: String) -> OpeningCourse {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return course }
        return OpeningCourse(
            schemaVersion: course.schemaVersion, id: course.id, name: trimmed,
            eco: course.eco, side: course.side, level: course.level, summary: course.summary,
            rootFEN: course.rootFEN, chapters: course.chapters, positions: course.positions
        )
    }

    // MARK: Interne

    /// Rejoue un coup et rend (SAN, clé normalisée d'arrivée). `nil` si le coup
    /// est illégal — c'est le seul juge, on ne fait jamais confiance à l'appelant.
    static func play(uci: String, from fen: String) -> (san: String, key: String)? {
        guard uci.count >= 4, let position = OpeningFENKey.position(from: fen) else { return nil }
        let start = Square(String(uci.prefix(2)))
        let end = Square(String(uci.dropFirst(2).prefix(2)))

        // Le TRAIT d'abord : `canMove`/`legalMoves` de ChessKit ne le consultent
        // pas (piège documenté dans ``ChessBoardView/draggableColor``). Sans ce
        // garde, déplacer une pièce noire quand les Blancs ont le trait
        // fabriquerait une arête vers une position que personne ne peut
        // atteindre — et le validateur ne verrait rien, puisqu'il rejoue le coup
        // avec la même mécanique permissive.
        guard let piece = position.piece(at: start), piece.color == position.sideToMove else {
            return nil
        }

        var board = Board(position: position)
        guard board.canMove(pieceAt: start, to: end), let move = board.move(pieceAt: start, to: end) else {
            return nil
        }
        if case .promotion = board.state {
            // UCI promeut en minuscule (« e7e8q »), `Piece.Kind` est en
            // MAJUSCULES — même conversion que le validateur.
            let kind: Piece.Kind = uci.count == 5
                ? (Piece.Kind(rawValue: String(uci.suffix(1)).uppercased()) ?? .queen)
                : .queen
            board.completePromotion(of: move, to: kind)
        }
        return (move.san, OpeningFENKey.key(for: board.position))
    }

    /// Sous-graphe réellement atteignable depuis la racine. La racine est
    /// toujours conservée, même devenue une feuille : un répertoire vidé de ses
    /// variantes reste un répertoire, et son fichier doit rester valide.
    private static func reachable(
        from root: String, in positions: [String: PositionNode]
    ) -> [String: PositionNode] {
        guard positions[root] != nil else { return positions }
        var keep: Set<String> = [root]
        var queue: [String] = [root]
        while let key = queue.popLast() {
            for edge in positions[key]?.moves ?? [] where !keep.contains(edge.toFEN) {
                keep.insert(edge.toFEN)
                queue.append(edge.toFEN)
            }
        }
        return positions.filter { keep.contains($0.key) }
    }

    /// Retire des chapitres les positions disparues, puis les chapitres devenus
    /// vides — un chapitre pendant fait échouer la validation.
    private static func cleaned(
        _ chapters: [OpeningChapter]?, keeping keys: Set<String>
    ) -> [OpeningChapter]? {
        guard let chapters else { return nil }
        let rebuilt = chapters.compactMap { chapter -> OpeningChapter? in
            let fens = chapter.positionFENs.filter { keys.contains($0) }
            guard !fens.isEmpty else { return nil }
            return OpeningChapter(
                id: chapter.id, title: chapter.title, summary: chapter.summary, positionFENs: fens
            )
        }
        return rebuilt.isEmpty ? nil : rebuilt
    }
}

// MARK: - Recopies ciblées
//
// Les champs de stockage (`moves_`, `role_`, `commentStatus_`) sont privés :
// modifier un nœud ou une arête passe donc par une reconstruction. Ces deux
// aides la centralisent, pour qu'un champ ajouté au modèle demain n'ait qu'un
// seul endroit à mettre à jour au lieu de quatre sites d'appel.

private extension PositionNode {
    /// `sideToMove` n'est pas recopié : il se dérive de la FEN, qui ne change
    /// pas ici. Le matérialiser alourdirait le fichier sans rien apprendre.
    func replacing(moves: [MoveEdge]) -> PositionNode {
        PositionNode(
            fen: fen, ecoName: ecoName, plan: plan, keySquares: keySquares, moves: moves
        )
    }
}

private extension MoveEdge {
    func replacing(comment: LocalizedText?, status: OpeningCommentStatus?) -> MoveEdge {
        MoveEdge(
            san: san, uci: uci, toFEN: toFEN, role: role,
            gamesMasters: gamesMasters, popularityMasters: popularityMasters,
            gamesClub: gamesClub, popularityClub: popularityClub,
            scoreWhite: scoreWhite, scoreDraw: scoreDraw, scoreBlack: scoreBlack,
            eval: eval, comment: comment, commentStatus: status, isCritical: isCritical
        )
    }
}

private extension OpeningCourse {
    func replacing(positions: [String: PositionNode], chapters: [OpeningChapter]?) -> OpeningCourse {
        OpeningCourse(
            schemaVersion: schemaVersion, id: id, name: name, eco: eco, side: side,
            level: level, summary: summary, rootFEN: rootFEN, chapters: chapters,
            positions: positions
        )
    }
}
