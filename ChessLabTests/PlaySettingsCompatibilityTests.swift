import Foundation
import Testing
@testable import ChessLab

/// Réglages de partie : le champ « Stockfish peut abandonner », et surtout la
/// compatibilité avec les réglages DÉJÀ enregistrés sur l'appareil.
struct PlaySettingsCompatibilityTests {

    /// ⚠️ Le décodeur synthétisé de Swift n'utilise pas les valeurs par
    /// défaut : il exige chaque clé. Comme `PlaySettingsStore.load()` décode
    /// avec `try?`, tout champ ajouté ferait échouer en SILENCE le décodage
    /// des réglages existants, qui repartiraient aux valeurs d'usine —
    /// couleur, force et cadence comprises.
    @Test func settingsSavedBeforeTheResignationFieldStillDecode() throws {
        // Exactement ce qu'une version antérieure écrivait : aucune clé
        // `engineResignationEnabled`.
        let legacy = """
        {
          "colorChoice": "black",
          "eloSliderValue": 2200,
          "timeControlID": "blitz5_0",
          "customMinutes": 15,
          "customIncrementSeconds": 0,
          "hintsEnabled": false,
          "blunderAlertEnabled": false,
          "showEvalBar": true,
          "multiMoveTakebackEnabled": true,
          "bookEnabled": false,
          "bookWidth": "mainLinesOnly"
        }
        """
        let data = try #require(legacy.data(using: .utf8))
        let settings = try JSONDecoder().decode(PlayGameSettings.self, from: data)

        // Les choix de l'utilisateur survivent…
        #expect(settings.colorChoice == "black")
        #expect(settings.eloSliderValue == 2200)
        #expect(settings.timeControlID == "blitz5_0")
        #expect(settings.showEvalBar)
        #expect(!settings.hintsEnabled)
        // …et le champ absent prend son défaut, sans faire échouer le reste.
        #expect(settings.engineResignationEnabled)
    }

    /// Un JSON réduit au strict minimum doit encore donner des réglages
    /// utilisables : c'est la garantie qui protège TOUS les ajouts futurs,
    /// pas seulement celui du jour.
    @Test func anAlmostEmptyPayloadFallsBackToDefaults() throws {
        let data = try #require("{}".data(using: .utf8))
        let settings = try JSONDecoder().decode(PlayGameSettings.self, from: data)

        #expect(settings == PlayGameSettings.default)
    }

    @Test func theResignationFieldSurvivesARoundTrip() throws {
        var settings = PlayGameSettings.default
        settings.engineResignationEnabled = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(PlayGameSettings.self, from: data)

        #expect(!decoded.engineResignationEnabled)
    }
}
