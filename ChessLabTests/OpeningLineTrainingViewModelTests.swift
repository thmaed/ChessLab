import ChessKit
import Testing
@testable import ChessLab

@MainActor
struct OpeningLineTrainingViewModelTests {

    private let entry = OpeningLibraryEntry(
        family: "Test Opening", category: "C",
        pgn: "1. e4 1... e5 2. Nf3 2... Nc6 3. Bb5",
        hasBlack: true
    )

    @Test func whiteRepertoireStartsWithoutAutoPlaying() {
        let viewModel = OpeningLineTrainingViewModel(entry: entry, color: .white)
        let vm = try! #require(viewModel)
        #expect(vm.currentStep == 0)
        #expect(vm.isUserTurn)
        #expect(vm.board.position.fen == Position.standard.fen)
    }

    @Test func blackRepertoireAutoPlaysWhitesFirstMove() {
        let viewModel = OpeningLineTrainingViewModel(entry: entry, color: .black)
        let vm = try! #require(viewModel)
        #expect(vm.currentStep == 1)
        #expect(vm.isUserTurn)
        #expect(vm.board.position.fen != Position.standard.fen)
    }

    @Test func correctMoveAdvancesAndTriggersAutoPlay() {
        let viewModel = OpeningLineTrainingViewModel(entry: entry, color: .white)
        let vm = try! #require(viewModel)
        vm.attemptMove(from: Square("e2"), to: Square("e4"))
        #expect(vm.currentStep == 1)
        #expect(!vm.isUserTurn) // en cours de riposte auto-jouée (e5)
    }

    @Test func wrongMoveDecrementsAttemptsAndRevealsAfterThree() {
        let viewModel = OpeningLineTrainingViewModel(entry: entry, color: .white)
        let vm = try! #require(viewModel)
        vm.attemptMove(from: Square("d2"), to: Square("d4"))
        #expect(vm.attemptsRemaining == 2)
        #expect(vm.hintMoves.isEmpty)
        vm.attemptMove(from: Square("d2"), to: Square("d4"))
        #expect(vm.attemptsRemaining == 1)
        vm.attemptMove(from: Square("d2"), to: Square("d4"))
        #expect(vm.attemptsRemaining == 0)
        #expect(!vm.hintMoves.isEmpty)
    }

    @Test func showHintFlagsExpectedMoveWithoutPlayingIt() {
        let viewModel = OpeningLineTrainingViewModel(entry: entry, color: .white)
        let vm = try! #require(viewModel)
        vm.showHint()
        #expect(vm.hintMoves.count == 1)
        #expect(vm.currentStep == 0)
        #expect(vm.board.position.fen == Position.standard.fen)
    }

    @Test func nilForEmptyPGN() {
        let empty = OpeningLibraryEntry(family: "Empty", category: "A", pgn: "", hasBlack: false)
        #expect(OpeningLineTrainingViewModel(entry: empty, color: .white) == nil)
    }
}
