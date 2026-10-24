import ChessKit
import Foundation
import SwiftData

/// Le premier coup où le joueur QUITTE son répertoire dans une partie (A3).
struct RepertoireExit: Equatable, Sendable {
    let courseID: String
    let courseName: String
    /// Clé FEN de la position AVANT le coup — celle qui rejoint les révisions.
    let fenKey: String
    /// Rang du demi-coup (0 = premier coup des Blancs).
    let ply: Int
    let playedSAN: String
    let playedUCI: String
    /// Le coup du répertoire (ligne principale du cours, comme l'entraînement).
    let expectedSAN: String
    let expectedUCI: String

    var moveNumber: Int { ply / 2 + 1 }
}

/// Un cours que le joueur suit, et jusqu'où.
struct FollowedCourse {
    let course: OpeningCourse
    /// Vrai pour un répertoire personnel ou marqué : toute sa théorie compte.
    /// Faux pour un cours livré simplement ÉTUDIÉ : seules comptent les
    /// positions que le joueur a réellement travaillées, sinon jouer 1.d4 une
    /// fois « quitterait » l'Italienne qu'il a révisée trois fois.
    let followsAll: Bool
}

/// Compare une partie aux répertoires que le joueur suit (voir
/// ``followedCourses(in:)``). Module pur, sans SwiftData.
///
/// Trois cas, tranchés :
/// - le joueur joue un coup du répertoire → on continue ;
/// - il en joue un autre alors que la position est dans un cours de son camp →
///   SORTIE, la seule chose que le module signale (la première de la partie) ;
/// - la position n'est dans AUCUN cours (l'adversaire a quitté la théorie
///   le premier, ou la ligne s'arrête) → on s'arrête SANS rien signaler : ce
///   n'est pas une faute du joueur.
///
/// Un coup que le cours note `inaccuracy` ou `refutation` ne compte pas comme
/// « dans le répertoire » : le jouer, c'est tomber dans un piège connu.
enum RepertoireExitDetector {

    static func firstExit(
        in game: Game, userColor: Piece.Color, courses: [FollowedCourse], studied: Set<String>
    ) -> RepertoireExit? {
        let own = courses.filter { !$0.course.isEndgame && $0.course.side.color == userColor }
        guard !own.isEmpty else { return nil }

        var index = game.startingIndex
        var ply = 0
        while game.moves.hasIndex(after: index) {
            let next = game.moves.index(after: index)
            guard let position = game.positions[index], let move = game.moves[next] else { return nil }
            if position.sideToMove == userColor {
                let key = OpeningFENKey.key(for: position)
                let known = own.compactMap { followed -> (OpeningCourse, PositionNode)? in
                    guard let node = followed.course.node(at: key), !node.moves.isEmpty,
                          followed.followsAll || studied.contains(key)
                    else { return nil }
                    return (followed.course, node)
                }
                // Hors théorie : l'adversaire a dévié le premier (ou fin de ligne).
                guard !known.isEmpty else { return nil }
                let played = move.lan
                let inRepertoire = known.contains { _, node in
                    node.moves.contains { $0.uci == played && $0.role != .inaccuracy && $0.role != .refutation }
                }
                if !inRepertoire {
                    let (course, node) = known[0]
                    let expected = node.moves.first { $0.role == .mainLine } ?? node.moves[0]
                    return RepertoireExit(
                        courseID: course.id, courseName: course.name, fenKey: key, ply: ply,
                        playedSAN: move.san, playedUCI: played,
                        expectedSAN: expected.san, expectedUCI: expected.uci
                    )
                }
            }
            index = next
            ply += 1
        }
        return nil
    }

    /// Les cours que l'utilisateur suit et les positions qu'il a travaillées :
    /// - répertoires marqués (``RepertoireMembership``) et personnels
    ///   (``UserOpeningStore``) : tout compte ;
    /// - cours livrés dont il a révisé au moins une position : seules comptent
    ///   les positions révisées.
    @MainActor
    static func followedCourses(in context: ModelContext) -> (courses: [FollowedCourse], studied: Set<String>) {
        let rows = (try? context.fetch(FetchDescriptor<OpeningPositionProgress>())) ?? []
        let studied = Set(rows.filter { $0.reps > 0 }.map(\.fenKey))
        var always = RepertoireStore.memberIDs(in: context)
        always.formUnion(UserOpeningStore.shared.catalog.map(\.id))

        var result: [FollowedCourse] = []
        for id in always {
            if let course = OpeningCatalog.course(id: id) { result.append(FollowedCourse(course: course, followsAll: true)) }
        }
        guard !studied.isEmpty else { return (result, studied) }
        for entry in OpeningCourseLoader.catalog where !always.contains(entry.id) {
            guard let course = OpeningCourseLoader.course(id: entry.id), !course.isEndgame,
                  course.positions.keys.contains(where: studied.contains)
            else { continue }
            result.append(FollowedCourse(course: course, followsAll: false))
        }
        return (result, studied)
    }
}
