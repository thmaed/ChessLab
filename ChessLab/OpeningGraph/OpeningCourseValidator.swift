import ChessKit
import Foundation

/// Vérifie l'INTÉGRITÉ d'un cours en graphe. Utilisé par les tests (aucune
/// arête orpheline, aucun FEN invalide, transpositions cohérentes) ET,
/// plus tard, par le générateur hors app comme garde-fou avant publication
/// d'un fichier.
///
/// PUR (cours → liste de problèmes), sans SwiftData ni UI. La validation des
/// arêtes rejoue chaque coup avec ChessKit et compare la clé normalisée
/// obtenue à `toFEN` : c'est le test le plus fort, il valide à la fois la
/// légalité du coup, la cohérence du graphe ET la normalisation FEN de bout
/// en bout.
enum OpeningCourseValidator {

    struct Issue: Equatable, CustomStringConvertible {
        enum Kind: String {
            case rootMissing            // rootFEN absent du graphe
            case keyMismatch            // clé du dictionnaire ≠ node.fen
            case invalidFEN             // FEN illisible par ChessKit
            case nonNormalizedFEN       // la clé n'est pas sa propre forme normalisée
            case orphanEdge             // arête pointant vers un nœud inexistant
            case illegalMove            // SAN/UCI non jouable depuis la position source
            case edgeTargetMismatch     // le coup mène à une position ≠ toFEN
            case chapterPositionMissing // un chapitre référence une position absente
        }
        let kind: Kind
        let detail: String
        var description: String { "[\(kind.rawValue)] \(detail)" }
    }

    /// Retourne tous les problèmes détectés (vide = graphe sain).
    static func validate(_ course: OpeningCourse) -> [Issue] {
        var issues: [Issue] = []

        if course.positions[course.rootFEN] == nil {
            issues.append(Issue(kind: .rootMissing, detail: "rootFEN absent : \(course.rootFEN)"))
        }

        for (key, node) in course.positions {
            if key != node.fen {
                issues.append(Issue(kind: .keyMismatch, detail: "clé \(key) ≠ node.fen \(node.fen)"))
            }
            guard OpeningFENKey.position(from: node.fen) != nil else {
                issues.append(Issue(kind: .invalidFEN, detail: node.fen))
                continue
            }
            if OpeningFENKey.normalize(node.fen) != node.fen {
                issues.append(Issue(kind: .nonNormalizedFEN, detail: node.fen))
            }
            for edge in node.moves {
                validateEdge(edge, from: node, in: course, into: &issues)
            }
        }

        for chapter in course.chapters ?? [] {
            for fen in chapter.positionFENs where course.positions[fen] == nil {
                issues.append(Issue(
                    kind: .chapterPositionMissing,
                    detail: "chapitre « \(chapter.title) » → position absente : \(fen)"
                ))
            }
        }

        return issues
    }

    private static func validateEdge(
        _ edge: MoveEdge, from node: PositionNode, in course: OpeningCourse, into issues: inout [Issue]
    ) {
        if course.positions[edge.toFEN] == nil {
            issues.append(Issue(kind: .orphanEdge, detail: "\(node.fen) --\(edge.san)--> \(edge.toFEN) (cible absente)"))
        }
        guard let resultingKey = resultingKey(afterUCI: edge.uci, from: node.fen) else {
            issues.append(Issue(kind: .illegalMove, detail: "\(edge.san)/\(edge.uci) illégal depuis \(node.fen)"))
            return
        }
        if resultingKey != edge.toFEN {
            issues.append(Issue(
                kind: .edgeTargetMismatch,
                detail: "\(node.fen) --\(edge.uci)--> obtenu \(resultingKey), attendu \(edge.toFEN)"
            ))
        }
    }

    /// Rejoue un coup UCI depuis une FEN et retourne la clé normalisée de la
    /// position obtenue, ou `nil` si le coup est illégal/illisible. Gère la
    /// promotion (5ᵉ caractère UCI, défaut dame), même mécanique que
    /// ``OpeningLineTrainingViewModel``.
    static func resultingKey(afterUCI uci: String, from fen: String) -> String? {
        guard uci.count >= 4, let position = OpeningFENKey.position(from: fen) else { return nil }
        let start = Square(String(uci.prefix(2)))
        let end = Square(String(uci.dropFirst(2).prefix(2)))

        var board = Board(position: position)
        guard board.canMove(pieceAt: start, to: end), let move = board.move(pieceAt: start, to: end) else {
            return nil
        }
        if case .promotion = board.state {
            // UCI promeut en minuscule (« e7e8q ») ; `Piece.Kind` a des
            // rawValues MAJUSCULES (N/B/R/Q) — d'où le `.uppercased()`.
            let kind: Piece.Kind = uci.count == 5
                ? (Piece.Kind(rawValue: String(uci.suffix(1)).uppercased()) ?? .queen)
                : .queen
            board.completePromotion(of: move, to: kind)
        }
        return OpeningFENKey.key(for: board.position)
    }
}
