import Foundation
import Testing
@testable import ChessLab

struct PuzzleSessionBuilderTests {

    private func makePuzzle(opened: Bool) -> Puzzle {
        let puzzle = Puzzle()
        puzzle.firstOpenedAt = opened ? Date() : nil
        return puzzle
    }

    @Test func neverOpenedPuzzlesComeBeforeAlreadyOpenedOnes() {
        let opened = (0..<5).map { _ in makePuzzle(opened: true) }
        let neverOpened = (0..<5).map { _ in makePuzzle(opened: false) }
        let session = PuzzleSessionBuilder.buildSession(from: opened + neverOpened, cap: 100)

        let firstOpenedIndex = session.firstIndex { $0.firstOpenedAt != nil }
        let lastNeverOpenedIndex = session.lastIndex { $0.firstOpenedAt == nil }
        guard let firstOpenedIndex, let lastNeverOpenedIndex else {
            Issue.record("Les deux groupes devraient être représentés")
            return
        }
        #expect(lastNeverOpenedIndex < firstOpenedIndex)
    }

    @Test func doesNotIncludeAlreadyOpenedPuzzlesWhileUnopenedOnesRemain() {
        let opened = (0..<3).map { _ in makePuzzle(opened: true) }
        let neverOpened = (0..<10).map { _ in makePuzzle(opened: false) }
        let session = PuzzleSessionBuilder.buildSession(from: opened + neverOpened, cap: 5)

        #expect(session.allSatisfy { $0.firstOpenedAt == nil })
    }

    @Test func fallsBackToAlreadyOpenedPuzzlesOnceUnopenedPoolExhausted() {
        let opened = (0..<10).map { _ in makePuzzle(opened: true) }
        let neverOpened = (0..<3).map { _ in makePuzzle(opened: false) }
        let session = PuzzleSessionBuilder.buildSession(from: opened + neverOpened, cap: 5)

        #expect(session.count == 5)
        #expect(session.filter { $0.firstOpenedAt == nil }.count == 3)
        #expect(session.filter { $0.firstOpenedAt != nil }.count == 2)
    }

    @Test func respectsCapWithoutDuplicates() {
        let candidates = (0..<30).map { _ in makePuzzle(opened: false) }
        let session = PuzzleSessionBuilder.buildSession(from: candidates, cap: 20)

        #expect(session.count == 20)
        #expect(Set(session.map(\.id)).count == 20)
    }

    @Test func returnsAllCandidatesWhenFewerThanCap() {
        let candidates = (0..<5).map { _ in makePuzzle(opened: false) }
        let session = PuzzleSessionBuilder.buildSession(from: candidates, cap: 20)
        #expect(session.count == 5)
    }
}
