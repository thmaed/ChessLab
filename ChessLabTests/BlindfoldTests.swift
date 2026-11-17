import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Partie À L'AVEUGLE (17/11/2026) : les niveaux, le réglage, et ce que le modèle de partie fait quand le
/// plateau cache des pièces. Aucun de ces tests ne démarre Stockfish.
@MainActor
struct BlindfoldTests {

    private static func inMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema([GameRecord.self, Puzzle.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    private func blindGame(_ level: BlindfoldLevel, color: PlayerColorChoice = .white) throws -> PlayViewModel {
        var settings = PlayGameSettings(colorChoice: color.rawValue, hintsEnabled: true, blunderAlertEnabled: true)
        settings.blindfold = level
        return PlayViewModel(settings: settings, modelContext: try Self.inMemoryContext(), startsEngine: false)
    }

    // MARK: Les niveaux

    @Test func eachLevelHidesWhatTheTestersMailSaid() {
        let pawn = { (c: Piece.Color) in Piece(.pawn, color: c, square: .e4) }
        #expect(BlindfoldLevel.off.mask(user: .white) == .none)
        #expect(BlindfoldLevel.occupiedSquares.mask(user: .white).display(pawn(.black)) == .disc)
        #expect(BlindfoldLevel.opponentHidden.mask(user: .white).display(pawn(.black)) == .hidden)
        #expect(BlindfoldLevel.opponentHidden.mask(user: .white).display(pawn(.white)) == .glyph)
        #expect(BlindfoldLevel.ownHidden.mask(user: .white).display(pawn(.white)) == .hidden)
        #expect(BlindfoldLevel.ownHidden.mask(user: .white).display(pawn(.black)) == .glyph)
        #expect(BlindfoldLevel.allHidden.mask(user: .black).display(pawn(.white)) == .hidden)
        #expect(BlindfoldLevel.allHidden.mask(user: .black).display(pawn(.black)) == .hidden)
    }

    @Test func onlyVisiblePiecesCanBeDragged() {
        #expect(BlindfoldLevel.opponentHidden.canDrag(user: .white))
        #expect(!BlindfoldLevel.ownHidden.canDrag(user: .white))
        #expect(!BlindfoldLevel.occupiedSquares.canDrag(user: .white))
        #expect(!BlindfoldLevel.allHidden.canDrag(user: .white))
    }

    // MARK: Le réglage

    @Test func aSettingSavedBeforeBlindfoldExistedStillLoads_withTheBoardVisible() throws {
        let old = #"{"colorChoice":"white","eloSliderValue":1400,"timeControlID":"none","hintsEnabled":true}"#
        let settings = try JSONDecoder().decode(PlayGameSettings.self, from: Data(old.utf8))
        #expect(settings.eloSliderValue == 1400)
        #expect(settings.blindfold == .off)
        #expect(!settings.blindfoldVoice)
    }

    @Test func theLevelAndTheVoiceTravelWithTheSetting() throws {
        var settings = PlayGameSettings()
        settings.blindfold = .ownHidden
        settings.blindfoldVoice = true
        let decoded = try JSONDecoder().decode(PlayGameSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.blindfold == .ownHidden)
        #expect(decoded.blindfoldVoice)
    }

    // MARK: La partie

    @Test func anySquareCanBeSelected_soATapNeverRevealsWhatIsThere() throws {
        let game = try blindGame(.allHidden)
        game.selectSquare(Square("e5"))                       // vide
        #expect(game.selectedSquare == Square("e5"))
        #expect(game.legalTargetSquares.isEmpty, "jamais de points de coups légaux à l'aveugle")
        game.selectSquare(Square("e5"))                       // le même : on désélectionne
        #expect(game.selectedSquare == nil)
    }

    @Test func anIllegalMoveSaysSo_withoutSayingWhy_andIsNotPlayed() throws {
        let game = try blindGame(.allHidden)
        game.selectSquare(Square("e2"))
        game.selectSquare(Square("e5"))                       // un pion ne fait pas trois pas
        #expect(game.moveLog.isEmpty)
        #expect(game.blindNotice != nil)
        #expect(game.selectedSquare == nil)
    }

    @Test func aLegalMoveIsPlayedByTouchingStartThenEnd() throws {
        let game = try blindGame(.allHidden)
        game.selectSquare(Square("g1"))
        game.selectSquare(Square("f3"))
        #expect(game.moveLog.map(\.lan) == ["g1f3"])
        #expect(game.blindNotice == nil)
    }

    @Test func peeksAreCounted_andTheBoardShowsEverythingWhileHeld() throws {
        let game = try blindGame(.opponentHidden)
        #expect(game.boardMask == .hidden([.black]))
        game.beginPeek()
        #expect(game.boardMask == .none)
        game.beginPeek()                                      // encore appuyé : ne compte pas deux fois
        game.endPeek()
        game.beginPeek()
        game.endPeek()
        #expect(game.peekCount == 2)
        #expect(game.boardMask == .hidden([.black]))
        #expect(game.blindSummaryLine.contains("2"))
    }

    @Test func aBoardInViewIsUnchanged() throws {
        let game = try blindGame(.off)
        #expect(game.boardMask == .none)
        game.beginPeek()
        #expect(game.peekCount == 0, "pas de coup d'œil quand tout se voit")
        game.selectSquare(Square("e5"))
        #expect(game.selectedSquare == nil, "à vue, une case vide ne se sélectionne pas")
    }

    @Test func thePeekCountTravelsWithTheSavedGame() throws {
        let autosave = PlayGameAutosave(
            settings: { var s = PlayGameSettings(); s.blindfold = .allHidden; return s }(),
            resolvedUserColorRaw: Piece.Color.white.rawValue, moveLANs: ["e2e4", "e7e5"],
            whiteRemaining: nil, blackRemaining: nil, savedAt: Date(), gameID: UUID(), blindfoldPeeks: 3
        )
        let decoded = try JSONDecoder().decode(PlayGameAutosave.self, from: JSONEncoder().encode(autosave))
        let game = try #require(PlayViewModel(resuming: decoded, modelContext: try Self.inMemoryContext(), startsEngine: false))
        #expect(game.peekCount == 3)
        #expect(game.isBlindfold)
    }
}
