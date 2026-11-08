import Foundation
import Testing
@testable import ChessLab

/// Retour de Ron (08/11/2026) : le thème affiché au-dessus du puzzle est un indice, il doit
/// pouvoir se masquer. Allumé par défaut, mémorisé quand on l'éteint.
@MainActor
struct PuzzleThemeSettingTests {
    @Test func isOnByDefaultAndRemembersBeingTurnedOff() {
        let settings = AppSettings.shared
        let saved = settings.showPuzzleTheme
        defer { settings.showPuzzleTheme = saved }

        settings.showPuzzleTheme = false
        #expect(UserDefaults.standard.object(forKey: "settings.showPuzzleTheme") as? Bool == false)
        settings.showPuzzleTheme = true
        #expect(UserDefaults.standard.object(forKey: "settings.showPuzzleTheme") as? Bool == true)
    }
}
