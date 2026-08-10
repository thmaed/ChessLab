import ChessKit
import Testing
@testable import ChessLab

@MainActor
struct OpeningLearnViewModelTests {

    private func key(after moves: [(String, String)]) -> String {
        var board = Board(position: .standard)
        for (from, to) in moves { _ = board.move(pieceAt: Square(from), to: Square(to)) }
        return OpeningFENKey.key(for: board.position)
    }

    /// Cours à une arête (e4) côté blancs, avec commentaire paramétrable.
    private func singleMoveCourse(comment: LocalizedText?, status: OpeningCommentStatus?) -> OpeningCourse {
        let root = OpeningFENKey.key(for: .standard)
        let k1 = key(after: [("e2", "e4")])
        let e4 = MoveEdge(san: "e4", uci: "e2e4", toFEN: k1, role: .mainLine,
                          comment: comment, commentStatus: status)
        return OpeningCourse(
            id: "c", name: "Cours", side: .white, rootFEN: root,
            positions: [root: PositionNode(fen: root, moves: [e4]), k1: PositionNode(fen: k1)]
        )
    }

    // MARK: Ligne principale

    @Test func mainLinePrefersRoleOverPopularity() {
        let root = OpeningFENKey.key(for: .standard)
        let ke4 = key(after: [("e2", "e4")])
        let kd4 = key(after: [("d2", "d4")])
        // d4 plus « populaire » mais e4 est la ligne principale (par rôle).
        let sideline = MoveEdge(san: "d4", uci: "d2d4", toFEN: kd4, role: .sideline, popularityClub: 0.9)
        let main = MoveEdge(san: "e4", uci: "e2e4", toFEN: ke4, role: .mainLine, popularityClub: 0.1)
        let course = OpeningCourse(
            id: "c", name: "C", side: .white, rootFEN: root,
            positions: [root: PositionNode(fen: root, moves: [sideline, main]),
                        ke4: PositionNode(fen: ke4), kd4: PositionNode(fen: kd4)]
        )
        #expect(OpeningLearnViewModel.mainLine(of: course).edges.first?.san == "e4")
    }

    @Test func alternativesExcludeExpectedMove() {
        let root = OpeningFENKey.key(for: .standard)
        let ke4 = key(after: [("e2", "e4")])
        let kd4 = key(after: [("d2", "d4")])
        let main = MoveEdge(san: "e4", uci: "e2e4", toFEN: ke4, role: .mainLine)
        let alt = MoveEdge(san: "d4", uci: "d2d4", toFEN: kd4, role: .sideline)
        let course = OpeningCourse(
            id: "c", name: "C", side: .white, rootFEN: root,
            positions: [root: PositionNode(fen: root, moves: [main, alt]),
                        ke4: PositionNode(fen: ke4), kd4: PositionNode(fen: kd4)]
        )
        let vm = try! #require(OpeningLearnViewModel(course: course))
        #expect(vm.alternatives.map(\.san) == ["d4"])
    }

    // MARK: Rappel actif

    @Test func whiteCourseStartsWaitingForUser() {
        let vm = try! #require(OpeningLearnViewModel(course: singleMoveCourse(comment: nil, status: nil)))
        #expect(vm.currentStep == 0)
        #expect(vm.isUserTurn)
        #expect(vm.board.position.sideToMove == .white)
    }

    @Test func blackCourseAutoPlaysWhitesFirstMove() {
        let course = OpeningGraphFixtures.linearCourse(id: "scandi", name: "Scandinave", sans: ["e4", "d5"], side: .black)
        let vm = try! #require(OpeningLearnViewModel(course: course))
        #expect(vm.currentStep == 1)                       // 1.e4 auto-joué à l'init
        #expect(vm.isUserTurn)
        #expect(vm.board.position.sideToMove == .black)

        vm.attemptMove(from: Square("d7"), to: Square("d5"))
        #expect(vm.currentStep == 2)
        #expect(vm.isLineComplete)
    }

    @Test func correctMoveAdvancesThenAutoPlaysOpponent() {
        let course = OpeningGraphFixtures.linearCourse(
            id: "ital", name: "Italienne", sans: ["e4", "e5", "Nf3", "Nc6", "Bc4"], side: .white
        )
        let vm = try! #require(OpeningLearnViewModel(course: course))
        vm.attemptMove(from: Square("e2"), to: Square("e4"))
        #expect(vm.currentStep == 1)
        #expect(!vm.isUserTurn)   // riposte adverse (e5) en cours d'auto-jeu
    }

    @Test func wrongMoveDecrementsThenRevealsAfterThree() {
        let course = OpeningGraphFixtures.linearCourse(
            id: "ital", name: "Italienne", sans: ["e4", "e5", "Nf3"], side: .white
        )
        let vm = try! #require(OpeningLearnViewModel(course: course))
        vm.attemptMove(from: Square("d2"), to: Square("d4"))
        #expect(vm.attemptsRemaining == 2)
        #expect(vm.currentStep == 0)
        vm.attemptMove(from: Square("d2"), to: Square("d4"))
        vm.attemptMove(from: Square("d2"), to: Square("d4"))
        #expect(vm.attemptsRemaining == 0)
        #expect(!vm.hintMoves.isEmpty)   // coup révélé
    }

    // MARK: Commentaires

    @Test func validatedCommentIsShownAfterPlaying() {
        let vm = try! #require(OpeningLearnViewModel(
            course: singleMoveCourse(comment: .both("Contrôle le centre."), status: .validated)
        ))
        vm.attemptMove(from: Square("e2"), to: Square("e4"))
        #expect(vm.currentComment == "Contrôle le centre.")
    }

    @Test func draftCommentIsNeverShown() {
        let vm = try! #require(OpeningLearnViewModel(
            course: singleMoveCourse(comment: .both("Brouillon à relire."), status: .draft)
        ))
        vm.attemptMove(from: Square("e2"), to: Square("e4"))
        #expect(vm.currentComment == nil)
    }

    @Test func nilWhenCourseHasNoMainLine() {
        let root = OpeningFENKey.key(for: .standard)
        let course = OpeningCourse(id: "empty", name: "Vide", rootFEN: root,
                                   positions: [root: PositionNode(fen: root)])
        #expect(OpeningLearnViewModel(course: course) == nil)
    }
}
