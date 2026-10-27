import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// A3 — la sortie de répertoire : seule la première déviation DU JOUEUR compte.
@Suite
@MainActor
struct RepertoireExitDetectorTests {

    private struct Step { let uci: String; let san: String; let role: MoveRole }

    /// Un répertoire blanc minimal : 1.e4 e5 2.Nf3 (ligne principale), 2.Bc4
    /// (variante), 2.Qh5 (marqué réfutation).
    private func whiteCourse() -> OpeningCourse {
        func key(_ moves: [(String, String)]) -> String {
            var board = Board(position: .standard)
            for (from, to) in moves { _ = board.move(pieceAt: Square(from), to: Square(to)) }
            return OpeningFENKey.key(for: board.position)
        }
        let root = key([])
        let afterE4 = key([("e2", "e4")])
        let afterE4E5 = key([("e2", "e4"), ("e7", "e5")])
        let afterNf3 = key([("e2", "e4"), ("e7", "e5"), ("g1", "f3")])
        let afterBc4 = key([("e2", "e4"), ("e7", "e5"), ("f1", "c4")])
        let afterQh5 = key([("e2", "e4"), ("e7", "e5"), ("d1", "h5")])
        return OpeningCourse(
            id: "test-ouverture-blanche", name: "Ouverture test", side: .white, rootFEN: root,
            positions: [
                root: PositionNode(fen: root, moves: [
                    MoveEdge(san: "e4", uci: "e2e4", toFEN: afterE4, role: .mainLine)]),
                afterE4: PositionNode(fen: afterE4, moves: [
                    MoveEdge(san: "e5", uci: "e7e5", toFEN: afterE4E5, role: .mainLine)]),
                afterE4E5: PositionNode(fen: afterE4E5, moves: [
                    MoveEdge(san: "Nf3", uci: "g1f3", toFEN: afterNf3, role: .mainLine),
                    MoveEdge(san: "Bc4", uci: "f1c4", toFEN: afterBc4, role: .sideline),
                    MoveEdge(san: "Qh5", uci: "d1h5", toFEN: afterQh5, role: .refutation)]),
            ]
        )
    }

    private func exit(
        _ pgn: String, color: Piece.Color = .white,
        courses: [FollowedCourse]? = nil, studied: Set<String> = []
    ) throws -> RepertoireExit? {
        let game = try #require(PGNLoader.game(from: pgn))
        return RepertoireExitDetector.firstExit(
            in: game, userColor: color,
            courses: courses ?? [FollowedCourse(course: whiteCourse(), followsAll: true)], studied: studied)
    }

    @Test("Suivre le répertoire, ligne principale ou variante, n'est pas une sortie")
    func staysInRepertoire() throws {
        #expect(try exit("1. e4 e5 2. Nf3 Nc6") == nil)
        #expect(try exit("1. e4 e5 2. Bc4 Nf6") == nil)
    }

    @Test("Quitter le répertoire est signalé, avec le coup attendu")
    func exitIsReported() throws {
        let found = try #require(try exit("1. e4 e5 2. Nc3 Nf6"))
        #expect(found.ply == 2)
        #expect(found.moveNumber == 2)
        #expect(found.playedSAN == "Nc3")
        #expect(found.expectedSAN == "Nf3")
        #expect(found.expectedUCI == "g1f3")
        #expect(found.courseID == "test-ouverture-blanche")
    }

    @Test("Le premier coup peut déjà être une sortie")
    func exitAtFirstMove() throws {
        let found = try #require(try exit("1. d4 d5"))
        #expect(found.ply == 0)
        #expect(found.expectedSAN == "e4")
    }

    @Test("Quand l'adversaire quitte la théorie le premier, ce n'est pas une faute du joueur")
    func opponentLeavesTheoryFirst() throws {
        #expect(try exit("1. e4 c5 2. Nf3 d6") == nil)
    }

    @Test("Un coup marqué réfutation par le cours compte comme une sortie")
    func refutationIsAnExit() throws {
        let found = try #require(try exit("1. e4 e5 2. Qh5 Nc6"))
        #expect(found.playedSAN == "Qh5")
    }

    @Test("Un cours de l'autre camp, ou aucun cours, ne signale rien")
    func otherSideOrNoCourse() throws {
        #expect(try exit("1. d4 d5", color: .black) == nil)
        #expect(try exit("1. d4 d5", courses: []) == nil)
    }

    @Test("Un cours simplement étudié ne compte que sur les positions réellement travaillées")
    func studiedCourseOnlyCountsStudiedPositions() throws {
        let course = whiteCourse()
        let studiedOnly = [FollowedCourse(course: course, followsAll: false)]
        // Rien de travaillé : jouer autre chose n'est la sortie de personne.
        #expect(try exit("1. d4 d5", courses: studiedOnly) == nil)
        // La position de départ a été révisée : 1.d4 la quitte.
        let found = try #require(try exit("1. d4 d5", courses: studiedOnly, studied: [course.rootFEN]))
        #expect(found.expectedSAN == "e4")
        // Les positions suivantes, non travaillées, ne signalent rien.
        #expect(try exit("1. e4 e5 2. Nc3 Nf6", courses: studiedOnly, studied: [course.rootFEN]) == nil)
    }

    @Test("Seule la première sortie est rendue")
    func onlyTheFirstExit() throws {
        let found = try #require(try exit("1. d4 e5 2. e4 d5"))
        #expect(found.ply == 0)
    }
}

/// Le branchement complet, sans moteur : répertoire de l'utilisateur → sortie
/// repérée → position replanifiée par FSRS → pastille.
@Suite(.serialized)
@MainActor
struct RepertoireExitServiceTests {

    @Test("Une sortie de répertoire rejoint les révisions FSRS et allume la pastille")
    func exitJoinsTheReviews() throws {
        let container = try ModelContainer(
            for: Schema([OpeningPositionProgress.self, OpeningReviewLog.self, RepertoireMembership.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)

        // Un vrai cours blanc livré dont la racine ne connaît pas 1.a3.
        let course = try #require(OpeningCourseLoader.catalog.lazy.compactMap { entry -> OpeningCourse? in
            guard let course = OpeningCourseLoader.course(id: entry.id), !course.isEndgame,
                  course.side == .white, let root = course.rootNode,
                  !root.moves.contains(where: { $0.uci == "a2a3" })
            else { return nil }
            return course
        }.first)
        RepertoireStore.toggle(courseID: course.id, side: .white, in: context)

        let service = AnalysisFollowUpService.shared
        service.acknowledgeRepertoireExits()
        let viewModel = AnalysisViewModel(source: .pgn("1. a3 e5 2. h3 d5"), isBackground: true)
        service.recordRepertoireExit(from: viewModel, color: .white, context: context)
        defer { service.acknowledgeRepertoireExits() }

        #expect(service.repertoireExitCount == 1)
        let rootKey = course.rootFEN
        let progress = try #require(OpeningProgressStore.progress(forFEN: rootKey, in: context))
        #expect(progress.reps == 1)
        #expect(progress.dueDate != nil)

        // Joué avec les Noirs, le même coup n'est la sortie de personne.
        service.recordRepertoireExit(from: viewModel, color: .black, context: context)
        #expect(service.repertoireExitCount == 1)
    }
}
