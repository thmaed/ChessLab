import ChessKit
import Testing
@testable import ChessLab

@MainActor
struct OpeningExplorerViewModelTests {

    /// Construit un nœud racine avec deux coups aux popularités croisées
    /// (e4 populaire en club, d4 populaire chez les maîtres) pour tester le tri
    /// selon la base choisie.
    private func crossedCourse() -> OpeningCourse {
        let root = OpeningFENKey.key(for: .standard)
        var b1 = Board(position: .standard); _ = b1.move(pieceAt: Square("e2"), to: Square("e4"))
        var b2 = Board(position: .standard); _ = b2.move(pieceAt: Square("d2"), to: Square("d4"))
        let k1 = OpeningFENKey.key(for: b1.position)
        let k2 = OpeningFENKey.key(for: b2.position)

        let e4 = MoveEdge(san: "e4", uci: "e2e4", toFEN: k1, role: .mainLine,
                          gamesMasters: 20, popularityMasters: 0.2, gamesClub: 600, popularityClub: 0.6)
        let d4 = MoveEdge(san: "d4", uci: "d2d4", toFEN: k2, role: .sideline,
                          gamesMasters: 70, popularityMasters: 0.7, gamesClub: 300, popularityClub: 0.3)
        let node = PositionNode(fen: root, moves: [e4, d4])
        return OpeningCourse(
            id: "t", name: "Test", rootFEN: root,
            positions: [root: node, k1: PositionNode(fen: k1), k2: PositionNode(fen: k2)]
        )
    }

    @Test func movesSortByChosenBase() {
        let vm = OpeningExplorerViewModel(course: crossedCourse())
        vm.base = .club
        #expect(vm.moves.map(\.san) == ["e4", "d4"])   // e4 plus joué en club
        vm.base = .masters
        #expect(vm.moves.map(\.san) == ["d4", "e4"])   // d4 plus joué chez les maîtres
    }

    @Test func gamesCountFollowsBase() {
        let vm = OpeningExplorerViewModel(course: crossedCourse())
        let e4 = try! #require(vm.moves.first { $0.san == "e4" })
        vm.base = .club
        #expect(vm.games(e4) == 600)
        vm.base = .masters
        #expect(vm.games(e4) == 20)
    }

    @Test func navigationAdvancesAndRewinds() {
        let vm = OpeningExplorerViewModel(course: crossedCourse())
        let root = vm.currentKey
        #expect(!vm.canGoBack)
        #expect(vm.board.position.sideToMove == .white)

        let e4 = try! #require(vm.moves.first { $0.san == "e4" })
        vm.play(e4)
        #expect(vm.currentKey == e4.toFEN)
        #expect(vm.canGoBack)
        #expect(vm.board.position.sideToMove == .black)   // le plateau a avancé
        #expect(vm.lastMove != nil)

        vm.back()
        #expect(vm.currentKey == root)
        #expect(!vm.canGoBack)
        #expect(vm.board.position.sideToMove == .white)
    }

    @Test func resetReturnsToRoot() {
        let course = OpeningGraphFixtures.linearCourse(
            id: "ruy", name: "Espagnole", sans: ["e4", "e5", "Nf3", "Nc6", "Bb5"]
        )
        let vm = OpeningExplorerViewModel(course: course)
        let root = vm.currentKey
        // Descend toute la ligne principale.
        while let next = vm.moves.first(where: { $0.role == .mainLine }) { vm.play(next) }
        #expect(vm.canGoBack)
        #expect(vm.isLeaf)
        vm.reset()
        #expect(vm.currentKey == root)
        #expect(!vm.canGoBack)
    }

    @Test func orientationFollowsCourseSide() {
        let course = OpeningGraphFixtures.linearCourse(
            id: "scandi", name: "Scandinave", sans: ["e4", "d5"], side: .black
        )
        let vm = OpeningExplorerViewModel(course: course)
        #expect(vm.orientation == .black)
    }
}

@MainActor
struct OpeningTranspositionIndexTests {

    @Test func findsOtherCoursesReachingTheSamePosition() {
        let a = OpeningGraphFixtures.linearCourse(id: "a", name: "Ouverture A", sans: ["e4", "e5"])
        let b = OpeningGraphFixtures.linearCourse(id: "b", name: "Ouverture B", sans: ["e4", "c5"])
        let index = OpeningTranspositionIndex(courses: [a, b])

        var board = Board(position: .standard)
        _ = board.move(pieceAt: Square("e2"), to: Square("e4"))
        let afterE4 = OpeningFENKey.key(for: board.position) // partagé par A et B

        #expect(index.courses(for: afterE4, excluding: "a") == ["Ouverture B"])
        #expect(index.courses(for: afterE4, excluding: "b") == ["Ouverture A"])
    }

    @Test func excludesCurrentCourseAndUnknownPositions() {
        let a = OpeningGraphFixtures.linearCourse(id: "a", name: "A", sans: ["e4", "e5"])
        let index = OpeningTranspositionIndex(courses: [a])
        let root = OpeningFENKey.key(for: .standard)
        #expect(index.courses(for: root, excluding: "a").isEmpty)         // seul cours → rien
        #expect(index.courses(for: "position inexistante", excluding: "a").isEmpty)
    }
}
