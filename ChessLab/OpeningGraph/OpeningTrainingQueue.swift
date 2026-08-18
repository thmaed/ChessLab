import Foundation

/// Une carte de révision : une POSITION (clé FEN) où c'est au camp d'étude de
/// jouer, avec le coup attendu (ligne principale). L'unité de révision est la
/// POSITION, pas la ligne — c'est la position qui porte la progression FSRS.
struct TrainCard: Equatable, Hashable {
    let courseID: String
    let fenKey: String
    let expectedUCI: String
    let expectedSAN: String
    let comment: LocalizedText?
}

/// Instantané de la progression d'une position, pour bâtir la file sans
/// dépendre de SwiftData (testable).
struct OpeningProgressSnapshot {
    let dueDate: Date?
    let lapses: Int
    let stability: Double
    let reps: Int
}

/// Construction PURE des files de révision (aucune dépendance SwiftData/UI).
/// Le ViewModel fournit les cours et un instantané de progression par FEN.
enum OpeningTrainingQueue {

    /// La LIGNE PRINCIPALE d'un cours : rôle `mainLine` d'abord, popularité
    /// sinon, bornée et protégée des cycles de transposition.
    ///
    /// Vivait dans `OpeningLearnViewModel` — supprimé le 18/08 avec le flux
    /// Explorateur (bug18aout §1, option A) : la file d'entraînement était
    /// son dernier consommateur vivant.
    static func mainLine(of course: OpeningCourse) -> (edges: [MoveEdge], fromKeys: [String]) {
        var edges: [MoveEdge] = []
        var fromKeys: [String] = []
        var key = course.rootFEN
        var visited: Set<String> = []
        while let node = course.node(at: key), !node.moves.isEmpty, !visited.contains(key), edges.count < 60 {
            visited.insert(key)
            let edge = node.moves.first { $0.role == .mainLine }
                ?? node.moves.max(by: { ($0.popularityClub ?? 0) < ($1.popularityClub ?? 0) })
            guard let edge else { break }
            edges.append(edge)
            fromKeys.append(key)
            key = edge.toFEN
        }
        return (edges, fromKeys)
    }

    /// Toutes les positions entraînables d'un cours : au trait du camp d'étude
    /// ET dotées d'un coup de ligne principale (la « bonne réponse »).
    static func trainableCards(of course: OpeningCourse) -> [TrainCard] {
        var cards: [TrainCard] = []
        for (key, node) in course.positions {
            guard node.sideToMove == course.side,
                  let main = node.moves.first(where: { $0.role == .mainLine }) ?? node.moves.first
            else { continue }
            cards.append(TrainCard(
                courseID: course.id, fenKey: key,
                expectedUCI: main.uci, expectedSAN: main.san, comment: main.validatedComment
            ))
        }
        return cards
    }

    /// Positions entraînables d'un cours DANS L'ORDRE de la ligne principale
    /// (pour le mode « ligne complète sans filet »).
    static func lineCards(of course: OpeningCourse) -> [TrainCard] {
        let line = mainLine(of: course)
        var cards: [TrainCard] = []
        for (edge, fromKey) in zip(line.edges, line.fromKeys) {
            let side = OpeningFENKey.position(from: fromKey)?.sideToMove
            guard side == course.side.color else { continue }
            cards.append(TrainCard(
                courseID: course.id, fenKey: fromKey,
                expectedUCI: edge.uci, expectedSAN: edge.san, comment: edge.validatedComment
            ))
        }
        return cards
    }

    /// File QUOTIDIENNE : positions DUES (échéance passée) d'abord, les plus en
    /// retard en tête, puis un quota de positions NEUVES (jamais vues).
    /// Dédupliquée par clé FEN (une position ne se révise qu'une fois, même si
    /// plusieurs cours la contiennent par transposition).
    static func dailyQueue(
        cards: [TrainCard], progress: [String: OpeningProgressSnapshot],
        now: Date = Date(), newLimit: Int = 20
    ) -> [TrainCard] {
        var seen = Set<String>()
        var due: [(card: TrainCard, date: Date)] = []
        var fresh: [TrainCard] = []
        for card in cards where seen.insert(card.fenKey).inserted {
            guard let snap = progress[card.fenKey] else {
                fresh.append(card)
                continue
            }
            if let date = snap.dueDate {
                if date <= now { due.append((card, date)) }
            } else {
                // Enregistrement SANS échéance : la position n'était ni « due »
                // ni « neuve », donc elle disparaissait définitivement de la
                // file, en silence. Inatteignable tant que seul `recordReview`
                // crée des enregistrements — mais `ensureProgress` est
                // `@discardableResult` et visible dans tout le module, et
                // `firstSeenAt` suggère une création « à la première
                // présentation » : le jour où quelqu'un l'appelle, la position
                // se volatilise. On la traite comme neuve, ce qu'elle est.
                fresh.append(card)
            }
        }
        due.sort { $0.date < $1.date }
        return due.map(\.card) + fresh.prefix(newLimit)
    }

    /// Positions DIFFICILES uniquement : celles déjà ratées (lapses > 0), triées
    /// du plus raté au moins raté, puis stabilité la plus faible.
    static func hardestQueue(
        cards: [TrainCard], progress: [String: OpeningProgressSnapshot], limit: Int = 30
    ) -> [TrainCard] {
        var seen = Set<String>()
        var scored: [(card: TrainCard, lapses: Int, stability: Double)] = []
        for card in cards where seen.insert(card.fenKey).inserted {
            guard let snap = progress[card.fenKey], snap.lapses > 0 else { continue }
            scored.append((card, snap.lapses, snap.stability))
        }
        // Plus d'échecs d'abord ; à égalité, stabilité la plus faible (plus fragile).
        scored.sort { $0.lapses != $1.lapses ? $0.lapses > $1.lapses : $0.stability < $1.stability }
        return scored.prefix(limit).map(\.card)
    }
}
