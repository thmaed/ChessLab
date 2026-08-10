import ChessKit
@testable import ChessLab

/// Fabriques de cours en graphe pour les tests. Construites avec le VRAI code
/// (ChessKit + ``OpeningFENKey``) pour garantir des FEN normalisées et des
/// arêtes légales — un fixture écrit à la main risquerait des clés fausses.
enum OpeningGraphFixtures {

    /// Construit un cours LINÉAIRE valide depuis la position initiale : chaque
    /// position rencontrée devient un nœud, chaque coup une arête `mainLine`
    /// vers le nœud suivant. Les clés sont normalisées, les UCI/SAN sont ceux
    /// que ChessKit produit réellement.
    static func linearCourse(
        id: String, name: String, sans: [String], side: OpeningSide = .white
    ) -> OpeningCourse {
        var board = Board(position: .standard)
        let rootKey = OpeningFENKey.key(for: board.position)
        var order: [String] = [rootKey]
        var edgesByKey: [String: [MoveEdge]] = [:]
        var currentKey = rootKey

        for san in sans {
            guard
                let parsed = Move(san: san, position: board.position),
                let applied = board.move(pieceAt: parsed.start, to: parsed.end)
            else { break }
            let toKey = OpeningFENKey.key(for: board.position)
            edgesByKey[currentKey, default: []].append(
                MoveEdge(san: applied.san, uci: applied.lan, toFEN: toKey, role: .mainLine)
            )
            order.append(toKey)
            currentKey = toKey
        }

        var positions: [String: PositionNode] = [:]
        for key in order {
            positions[key] = PositionNode(fen: key, moves: edgesByKey[key] ?? [])
        }
        let chapter = OpeningChapter(id: "main", title: .both("Ligne principale"), positionFENs: order)
        return OpeningCourse(
            id: id, name: name, side: side, rootFEN: rootKey, chapters: [chapter], positions: positions
        )
    }

    /// Renvoie une copie du cours dont une arête a été redirigée vers une clé
    /// bidon (pour tester la détection d'arêtes orphelines).
    static func withBrokenEdge(_ course: OpeningCourse, badTarget: String = "GARBAGE") -> OpeningCourse {
        var positions = course.positions
        for (key, node) in positions where !node.moves.isEmpty {
            let first = node.moves[0]
            let broken = MoveEdge(san: first.san, uci: first.uci, toFEN: badTarget, role: first.role)
            positions[key] = PositionNode(fen: node.fen, moves: [broken] + node.moves.dropFirst())
            break
        }
        return OpeningCourse(
            id: course.id, name: course.name, side: course.side, rootFEN: course.rootFEN,
            chapters: course.chapters, positions: positions
        )
    }
}
