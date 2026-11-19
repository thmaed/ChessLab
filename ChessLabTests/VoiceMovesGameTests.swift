import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// COUPS À LA VOIX dans une partie (19/11/2026) : ce que la partie fait de ce que le micro a entendu — sans micro ni
/// moteur. Décisions : le coup compris est JOUÉ DIRECTEMENT, « annule » le reprend, un coup impossible ou une phrase
/// incomprise se disent, une conversation est ignorée.
@MainActor
struct VoiceMovesGameTests {
    private static func game(fen: String? = nil, voice: Bool = true) throws -> PlayViewModel {
        var settings = PlayGameSettings(startFEN: fen, hintsEnabled: true, blunderAlertEnabled: false)
        settings.voiceMoves = voice
        let container = try ModelContainer(
            for: Schema([GameRecord.self, Puzzle.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return PlayViewModel(settings: settings, modelContext: ModelContext(container), startsEngine: false)
    }

    @Test func theUnderstoodMoveIsPlayedAtOnce() throws {
        let model = try Self.game()
        #expect(model.isVoiceTurn)
        #expect(model.handleVoice(["Cavalier F3"], language: "fr", speaks: false) == .played("Nf3"))
        #expect(model.moveLog.last?.san == "Nf3")
        #expect(model.voiceNotice?.isError == false)
        #expect(!model.isVoiceTurn, "après mon coup, c'est à l'ordinateur : le micro n'écoute plus")
    }

    @Test func anImpossibleMoveIsSaidAndNotPlayed() throws {
        let model = try Self.game()
        #expect(model.handleVoice(["fou c4"], language: "fr", speaks: false) == .illegal)
        #expect(model.moveLog.isEmpty)
        #expect(model.voiceNotice?.isError == true)
    }

    @Test func aMisunderstoodMoveIsSaid() throws {
        let model = try Self.game()
        #expect(model.handleVoice(["roi"], language: "fr", speaks: false) == .notUnderstood)
        #expect(model.moveLog.isEmpty)
    }

    @Test func aConversationIsIgnored() throws {
        let model = try Self.game()
        #expect(model.handleVoice(["tu veux un café ?"], language: "fr", speaks: false) == .ignored)
        #expect(model.voiceNotice == nil)
    }

    @Test func twoPiecesForOneSquareAskWhichOne() throws {
        let model = try Self.game(fen: "4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1")
        #expect(model.handleVoice(["cavalier d2"], language: "fr", speaks: false) == .ambiguous)
        #expect(model.moveLog.isEmpty)
        #expect(model.handleVoice(["cavalier b d2"], language: "fr", speaks: false) == .played("Nbd2"))
    }

    @Test func aPromotionIsCompletedWithThePieceSaid() throws {
        let model = try Self.game(fen: "8/P7/8/8/8/8/8/k6K w - - 0 1")
        #expect(model.handleVoice(["a8 cavalier"], language: "fr", speaks: false) == .played("a8=N"))
        #expect(model.board.position.piece(at: .a8)?.kind == .knight)
    }

    @Test func otherLanguagesPlayToo() throws {
        let model = try Self.game()
        #expect(model.handleVoice(["knight to f3"], language: "en", speaks: false) == .played("Nf3"))
    }

    @Test func nothingHappensWhenTheSettingIsOff() throws {
        let model = try Self.game(voice: false)
        #expect(!model.isVoiceTurn)
        #expect(model.handleVoice(["Cavalier F3"], language: "fr", speaks: false) == .ignored)
        #expect(model.moveLog.isEmpty)
    }

    @Test func undoTakesTheMoveBack() throws {
        let model = try Self.game()
        model.handleVoice(["e4"], language: "fr", speaks: false)
        #expect(model.moveLog.count == 1)
        #expect(model.handleVoice(["annule"], language: "fr", speaks: false) == .undone)
        #expect(model.moveLog.isEmpty)
        #expect(model.isVoiceTurn, "le coup repris, c'est de nouveau à moi")
    }

    @Test func undoIsRefusedAndSaidWithAClock() throws {
        var settings = PlayGameSettings(timeControlID: TimeControl.presets.first { $0.hasClock }?.id ?? "blitz-5-0")
        settings.voiceMoves = true
        let container = try ModelContainer(
            for: Schema([GameRecord.self, Puzzle.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let model = PlayViewModel(settings: settings, modelContext: ModelContext(container), startsEngine: false)
        guard model.settings.timeControl.hasClock else { return }
        model.handleVoice(["e4"], language: "fr", speaks: false)
        #expect(model.handleVoice(["annule"], language: "fr", speaks: false) == .cannotUndo)
        #expect(model.moveLog.count == 1)
    }

    @Test func theSettingSurvivesASaveAndOldSavesReadWithoutIt() throws {
        var settings = PlayGameSettings()
        settings.voiceMoves = true
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(PlayGameSettings.self, from: data).voiceMoves)
        #expect(try JSONDecoder().decode(PlayGameSettings.self, from: Data("{}".utf8)).voiceMoves == false)
    }
}
