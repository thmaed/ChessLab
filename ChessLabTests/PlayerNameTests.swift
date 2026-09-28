import Foundation
import Testing
@testable import ChessLab

/// Le nom du joueur, affiché et exporté.
///
/// Motif : un testeur anglophone, interface entièrement en anglais, voyait
/// ses parties signées « Vous » (27/09/2026). La bibliothèque stockait le mot
/// français EN CLAIR et l'affichait tel quel. Il cherchait aussi — sans le
/// trouver — le réglage pour s'appeler autrement.
@MainActor
struct PlayerNameTests {

    /// Le contrat central : rien de ce qui est stocké ne s'affiche tel quel.
    /// Les deux sentinelles, française et anglaise, mènent au même nom — celui
    /// de la langue du jour.
    @Test func bothStoredSentinelsResolveToTheSameDisplayedName() {
        #expect(PlayerName.display("Vous") == PlayerName.you)
        #expect(PlayerName.display("You") == PlayerName.you)
        #expect(PlayerName.display("Ordinateur") == PlayerName.computer)
        #expect(PlayerName.display("Computer") == PlayerName.computer)
        // Le nom stocké par les versions d'avant le renommage.
        #expect(PlayerName.display("Stockfish") == PlayerName.computer)
        #expect(PlayerName.display("Blancs") == PlayerName.white)
        #expect(PlayerName.display("White") == PlayerName.white)
    }

    /// « Vous » a bien sa traduction dans les chaînes LIVRÉES : sans elle, le
    /// résolveur aurait beau faire, il rendrait le mot français.
    @Test func theSentinelIsTranslatedInTheShippedStrings() throws {
        let url = try #require(
            Bundle.main.url(forResource: "Localizable", withExtension: "strings",
                            subdirectory: nil, localization: "en"),
            "les chaînes anglaises compilées sont introuvables"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        let english = try #require(plist as? [String: String])

        #expect(english["Vous"] == "You")
        #expect(english["Ordinateur"] == "Computer")
        #expect(english["Votre nom"] == "Your name")
    }

    /// Un vrai nom — saisi ici ou venu d'un PGN importé — traverse intact.
    @Test func arealNameIsLeftAlone() {
        #expect(PlayerName.display("Fischer, Robert J.") == "Fischer, Robert J.")
        #expect(PlayerName.display("  Maia  ") == "Maia")
    }

    /// Rien de stocké, ou « ? » : c'est à l'appelant de choisir son repli.
    @Test func nothingStoredMeansNoName() {
        #expect(PlayerName.display(nil) == nil)
        #expect(PlayerName.display("") == nil)
        #expect(PlayerName.display("?") == nil)
        #expect(PlayerName.display(nil, fallback: "Blancs") == "Blancs")
    }

    /// Le nom choisi remplace « Vous » partout où il s'affiche — y compris
    /// pour les parties DÉJÀ enregistrées, qui portent la sentinelle.
    @Test func theChosenNameReplacesTheDefault() {
        let previous = AppSettings.shared.playerName
        defer { AppSettings.shared.playerName = previous }

        AppSettings.shared.playerName = "Ron"
        #expect(PlayerName.you == "Ron")
        #expect(PlayerName.display("Vous") == "Ron")

        // Un nom réduit à des espaces ne compte pas pour un nom.
        AppSettings.shared.playerName = "   "
        #expect(PlayerName.you == LocalizationController.string("Vous"))

        AppSettings.shared.playerName = ""
        #expect(PlayerName.you == LocalizationController.string("Vous"))
    }

    /// Ce nom part dans des balises PGN : ni guillemet, ni crochet, ni saut de
    /// ligne, et pas mille caractères. Les espaces, eux, survivent à la
    /// frappe — on les coupe à la lecture, pas à l'écriture.
    @Test func theChosenNameIsSanitized() {
        #expect(AppSettings.sanitizedPlayerName("Ron \"Rocket\" Lasser") == "Ron Rocket Lasser")
        #expect(AppSettings.sanitizedPlayerName("[Ron]\nLasser") == "Ron Lasser")
        #expect(AppSettings.sanitizedPlayerName("Ron ") == "Ron ")
        #expect(
            AppSettings.sanitizedPlayerName(String(repeating: "a", count: 200)).count
                == AppSettings.playerNameMaxLength
        )
    }
}
