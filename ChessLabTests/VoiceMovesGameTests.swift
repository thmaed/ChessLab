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

    /// iPhone XS, iOS 18.7 (19/11/2026) : avec « Siri et Dictée » coupé, la reconnaissance classique se dit disponible
    /// puis refuse chaque phrase par cette erreur — l'app doit la reconnaître pour le DIRE, pas se taire.
    @Test func theDictationSwitchErrorIsRecognized() {
        let off = NSError(domain: "kLSRErrorDomain", code: 201,
                          userInfo: [NSLocalizedDescriptionKey: "Siri and Dictation are disabled"])
        #expect(VoiceRecognizers.isDictationOff(off))
        #expect(!VoiceRecognizers.isDictationOff(NSError(domain: "kAFAssistantErrorDomain", code: 1110)),
                "« rien entendu » n'est pas une dictée coupée")
        #expect(!VoiceRecognizers.isDictationOff(NSError(domain: "kLSRErrorDomain", code: 301)))
    }

    /// iPhone XS en français de Suisse (19/11/2026) : la reconnaissance classique doit demander fr-CH, la variante de
    /// la dictée, et non fr-FR (refusé avec la même erreur que la dictée coupée).
    @Test func theClassicRecognitionAsksForThePhonesOwnVariant() {
        let known: Set<String> = ["fr-FR", "fr-CH", "fr-CA", "de-DE", "de-CH", "en-US", "en-GB"]
        #expect(VoiceRecognizers.classicLocale(for: "fr", device: Locale(identifier: "fr_CH"), supported: known, installed: { _ in true })
            .identifier(.bcp47) == "fr-CH")
        #expect(VoiceRecognizers.classicLocale(for: "fr", device: Locale(identifier: "fr_FR"), supported: known, installed: { _ in true })
            .identifier(.bcp47) == "fr-FR")
        #expect(VoiceRecognizers.classicLocale(for: "en", device: Locale(identifier: "en_GB"), supported: known, installed: { _ in true })
            .identifier(.bcp47) == "en-GB")
        #expect(VoiceRecognizers.classicLocale(for: "de", device: Locale(identifier: "fr_CH"), supported: known, installed: { _ in true })
            .identifier(.bcp47) == "de-DE", "téléphone dans une autre langue que l'app : la variante par défaut")
        #expect(VoiceRecognizers.classicLocale(for: "it", device: Locale(identifier: "it_CH"), supported: known, installed: { _ in true })
            .identifier(.bcp47) == "it-IT", "variante inconnue d'iOS : celle par défaut")
    }

    /// iPhone XS en français, clavier « Anglais (Royaume-Uni) » seul (21/11/2026) : l'app, réglée en anglais, demandait
    /// « en-US » (modèle absent) et se disait indisponible. Elle prend la variante dont le modèle est installé.
    @Test func theClassicRecognitionFallsBackToAnInstalledVariantOfTheLanguage() {
        let known: Set<String> = ["fr-FR", "fr-CH", "en-US", "en-GB", "en-AU", "de-DE"]
        let phone = Locale(identifier: "fr_FR")
        #expect(VoiceRecognizers.classicLocale(for: "en", device: phone, supported: known, installed: { $0 == "en-GB" })
            .identifier(.bcp47) == "en-GB")
        #expect(VoiceRecognizers.classicLocale(for: "en", device: phone, supported: known, installed: { $0 == "en-US" })
            .identifier(.bcp47) == "en-US", "la variante par défaut reste préférée quand elle est là")
        #expect(VoiceRecognizers.classicLocale(for: "en", device: Locale(identifier: "en_GB"), supported: known,
                                               installed: { $0 == "en-US" || $0 == "en-GB" })
            .identifier(.bcp47) == "en-GB", "celle du téléphone d'abord")
        #expect(VoiceRecognizers.classicLocale(for: "en", device: phone, supported: known, installed: { $0 == "en-AU" })
            .identifier(.bcp47) == "en-AU")
        #expect(VoiceRecognizers.classicLocale(for: "en", device: phone, supported: known, installed: { _ in false })
            .identifier(.bcp47) == "en-US", "aucun modèle : la défaut, l'app dira « indisponible »")
        #expect(VoiceRecognizers.classicLocale(for: "fr", device: phone, supported: known, installed: { $0 == "fr-CH" })
            .identifier(.bcp47) == "fr-CH", "le français aussi")
        #expect(VoiceRecognizers.classicLocale(for: "de", device: phone, supported: known, installed: { $0 == "en-GB" })
            .identifier(.bcp47) == "de-DE", "jamais une autre langue")
    }

    /// La ligne orange de Nouvelle partie (20/11/2026) : seulement avec la reconnaissance classique d'avant iOS 26.
    @Test func theAccuracyWarningIsForTheClassicRecognitionOnly() {
        #expect(NewGameSetupView.warnsAboutAccuracy(.available(precise: false)))
        #expect(!NewGameSetupView.warnsAboutAccuracy(.available(precise: true)))
        #expect(!NewGameSetupView.warnsAboutAccuracy(.unavailable), "indisponible : une autre note le dit")
        #expect(!NewGameSetupView.warnsAboutAccuracy(.dictationOff))
        #expect(!NewGameSetupView.warnsAboutAccuracy(nil))
    }

    @Test func theUnderstoodMoveIsPlayedAtOnce() throws {
        let model = try Self.game()
        #expect(model.isVoiceTurn)
        #expect(model.handleVoice(["Cavalier F3"], language: "fr", speaks: false) == .played("Nf3"))
        #expect(model.moveLog.last?.san == "Nf3")
        #expect(model.voiceNotice?.isError == false)
        #expect(!model.isVoiceTurn, "après mon coup, c'est à l'ordinateur : le micro n'écoute plus")
    }

    @Test func blindWithTheVoiceOnTheMoveIsRepeatedAloud() throws {
        var settings = PlayGameSettings(hintsEnabled: true, blunderAlertEnabled: false)
        settings.voiceMoves = true
        settings.blindfold = .allHidden
        settings.blindfoldVoice = true
        let container = try ModelContainer(
            for: Schema([GameRecord.self, Puzzle.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let model = PlayViewModel(settings: settings, modelContext: ModelContext(container), startsEngine: false)
        #expect(model.handleVoice(["cavalier f3"], language: "fr", speaks: false) == .played("Nf3"))
        #expect(model.lastSpokenVoiceText == MoveNarration.describe(san: "Nf3"),
                "comme l'adversaire dans les Règles FIDE (annexe D.2.1), l'app répète le coup")
    }

    @Test func withoutTheBlindVoiceTheMoveIsOnlyShown() throws {
        let model = try Self.game()
        #expect(model.handleVoice(["cavalier f3"], language: "fr", speaks: false) == .played("Nf3"))
        #expect(model.lastSpokenVoiceText == nil, "retour À L'ÉCRAN seulement (décision du 19/11/2026)")
        #expect(model.voiceNotice?.text == MoveNarration.describe(san: "Nf3"))
    }

    /// L'essai anticipé (20/11/2026) ne joue que ce qui est déjà un coup sûr ; le reste attend la fin de la phrase.
    @Test func onlyADecisiveMoveIsPlayedEarly() throws {
        let model = try Self.game()
        #expect(model.voiceIsDecisive(["cavalier f3"], language: "fr"))
        #expect(!model.voiceIsDecisive(["cavalier"], language: "fr"), "une moitié de phrase attend la suite")
        #expect(!model.voiceIsDecisive(["fou c4"], language: "fr"), "un coup impossible se dit, à la fin")
        #expect(!model.voiceIsDecisive(["tu veux un café ?"], language: "fr"))
        #expect(!model.voiceIsDecisive(["annule"], language: "fr"))
        #expect(model.moveLog.isEmpty, "la question ne joue rien")
        let twins = try Self.game(fen: "4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1")
        #expect(!twins.voiceIsDecisive(["cavalier d2"], language: "fr"))
        let promotion = try Self.game(fen: "8/P7/8/8/8/8/8/k6K w - - 0 1")
        #expect(!promotion.voiceIsDecisive(["a8"], language: "fr"), "« a8… cavalier » coupé deviendrait une dame")
        #expect(!promotion.voiceIsDecisive(["a8 cavalier"], language: "fr"))
        #expect(!(try Self.game(voice: false)).voiceIsDecisive(["cavalier f3"], language: "fr"))
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

    // MARK: Interrupteur « Micro » (19/11/2026) et plateau

    @Test func theBoardStillPlaysWithTheVoiceOn() throws {
        let model = try Self.game()
        model.selectSquare(Square("e2"))
        model.selectSquare(Square("e4"))
        #expect(model.moveLog.last?.san == "e4", "voix allumée, le plateau joue comme d'habitude")
        #expect(!model.isVoiceTurn)
        #expect(model.handleVoice(["cavalier f6"], language: "fr", speaks: false) == .ignored,
                "une phrase en retard ne joue pas un second coup")
    }

    @Test func theMicSwitchOffStopsListeningButNotTheBoard() throws {
        let model = try Self.game()
        model.setVoiceMic(false)
        #expect(!model.voiceMicOn)
        #expect(!model.isVoiceTurn, "micro coupé : plus d'écoute")
        #expect(model.handleVoice(["e4"], language: "fr", speaks: false) == .ignored)
        #expect(model.moveLog.isEmpty)
        model.selectSquare(Square("d2"))
        model.selectSquare(Square("d4"))
        #expect(model.moveLog.last?.san == "d4", "micro coupé, le plateau joue")
        model.setVoiceMic(true)
        #expect(model.voiceMicOn)
    }

    @Test func theMicSwitchTravelsWithTheSavedGame() throws {
        var settings = PlayGameSettings()
        settings.voiceMoves = true
        let autosave = PlayGameAutosave(
            settings: settings, resolvedUserColorRaw: Piece.Color.white.rawValue, moveLANs: ["e2e4", "e7e5"],
            whiteRemaining: nil, blackRemaining: nil, savedAt: Date(), gameID: UUID(), voiceMicOff: true
        )
        let decoded = try JSONDecoder().decode(PlayGameAutosave.self, from: JSONEncoder().encode(autosave))
        let container = try ModelContainer(
            for: Schema([GameRecord.self, Puzzle.self]),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let off = try #require(PlayViewModel(resuming: decoded, modelContext: ModelContext(container), startsEngine: false))
        #expect(!off.voiceMicOn, "on retrouve le micro coupé en revenant à la partie")
        var old = autosave
        old.voiceMicOff = nil
        let on = try #require(PlayViewModel(resuming: old, modelContext: ModelContext(container), startsEngine: false))
        #expect(on.voiceMicOn, "sauvegarde d'avant l'interrupteur : micro allumé")
    }

    /// iPhone 11 (21/11/2026) : « e3 » entendu `["A3", "E3"]` jouait a3. Désormais la partie ne joue rien, DIT les
    /// deux coups, et « deuxième » joue le second.
    @Test func whenTheRecognitionHesitatesTheGameAsksAndTheAnswerPlays() throws {
        let model = try Self.game()
        #expect(model.handleVoice(["A3", "E3"], language: "fr", speaks: false) == .conflicting)
        #expect(model.moveLog.isEmpty, "rien ne se joue tant qu'on n'a pas choisi")
        #expect(model.lastSpokenVoiceText == "pion en a 3 ou pion en e 3 ? Dites premier ou deuxième.")
        #expect(model.voiceIsDecisive(["le deuxième"], language: "fr"), "la réponse se joue sans attendre")
        #expect(model.handleVoice(["le deuxième"], language: "fr", speaks: false) == .played("e3"))
        #expect(model.board.position.piece(at: .e3)?.kind == .pawn)
    }

    /// « premier » sans question posée n'est pas un coup : rien ne se joue, et la phrase est ignorée.
    @Test func firstOrSecondMeansNothingWithoutAQuestion() throws {
        let model = try Self.game()
        #expect(model.handleVoice(["premier"], language: "fr", speaks: false) == .ignored)
        #expect(model.moveLog.isEmpty)
        #expect(!model.voiceIsDecisive(["premier"], language: "fr"))
    }

    /// Une phrase qui donne un coup net (« pion e3 ») annule la question en attente et se joue.
    @Test func aClearMoveAfterTheQuestionIsPlayedAsIs() throws {
        let model = try Self.game()
        _ = model.handleVoice(["A3", "E3"], language: "fr", speaks: false)
        #expect(model.handleVoice(["pion e3"], language: "fr", speaks: false) == .played("e3"))
    }
}
