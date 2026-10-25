import Foundation
import Testing
@testable import ChessLab

struct TimeLimitSelectionTests {

    private func freshDefaults() -> UserDefaults {
        let name = "TimeLimitSelectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Éteinte par défaut : pas de pendule, cadence de repli rapide 10+0")
    func offByDefault() {
        let selection = TimeLimitSelection(savedID: "none", customMinutes: 15, customIncrement: 0, memoryKey: "x", defaults: freshDefaults())
        #expect(!selection.isEnabled)
        #expect(selection.effective == .none)
        #expect(selection.remembered == TimeLimitSelection.fallbackPreset)
    }

    @Test("Une cadence enregistrée allume l'interrupteur et la retrouve")
    func savedCadenceTurnsItOn() {
        let selection = TimeLimitSelection(savedID: TimeControl.blitz3_2.id, customMinutes: 15, customIncrement: 0, memoryKey: "x", defaults: freshDefaults())
        #expect(selection.isEnabled)
        #expect(selection.category == .blitz)
        #expect(selection.effective == .blitz3_2)
    }

    @Test("Éteinte, la dernière cadence est mémorisée et revient au rallumage")
    func rememberedWhenOff() {
        let defaults = freshDefaults()
        var selection = TimeLimitSelection(savedID: TimeControl.bullet2_1.id, customMinutes: 15, customIncrement: 0, memoryKey: "x", defaults: defaults)
        selection.isEnabled = false
        #expect(selection.effective == .none)
        selection.remember(memoryKey: "x", defaults: defaults)

        var again = TimeLimitSelection(savedID: "none", customMinutes: 15, customIncrement: 0, memoryKey: "x", defaults: defaults)
        #expect(!again.isEnabled)
        again.isEnabled = true
        #expect(again.effective == .bullet2_1)
    }

    @Test("La cadence personnalisée est gardée avec ses minutes")
    func customIsRemembered() {
        let defaults = freshDefaults()
        var selection = TimeLimitSelection(savedID: "custom", customMinutes: 7, customIncrement: 3, memoryKey: "x", defaults: defaults)
        #expect(selection.isCustom)
        #expect(selection.effective.initialSeconds == 420)
        selection.isEnabled = false
        selection.remember(memoryKey: "x", defaults: defaults)
        let again = TimeLimitSelection(savedID: "none", customMinutes: 7, customIncrement: 3, memoryKey: "x", defaults: defaults)
        #expect(again.isCustom)
        #expect(again.remembered.incrementSeconds == 3)
    }

    @Test("Changer de famille garde toujours une cadence valide")
    func selectingACategoryPicksAPreset() {
        var selection = TimeLimitSelection(savedID: "none", customMinutes: 15, customIncrement: 0, memoryKey: "x", defaults: freshDefaults())
        selection.isEnabled = true
        selection.select(.classical)
        #expect(selection.effective.category == .classical)
        selection.select(TimeControlCategory.none)
        #expect(selection.category == .classical)
    }
}
