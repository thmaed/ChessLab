import Testing
@testable import ChessLab

/// Le nom du palier sous le curseur : le préréglage le plus proche, l'égalité
/// au plus bas, et « Maximum » tout en haut.
@Suite struct EnginePresetBandTests {
    private func label(_ value: Double) -> String? { EnginePreset.nearest(toSliderValue: value)?.label }

    @Test func bandsFollowTheMidpointsBetweenPresets() {
        #expect(label(800) == "Grand débutant")
        #expect(label(900) == "Grand débutant", "l'égalité va au plus bas")
        #expect(label(950) == "Débutant")
        #expect(label(1100) == "Débutant")
        #expect(label(1150) == "Débutant confirmé")
        #expect(label(1300) == "Débutant confirmé")
        #expect(label(1350) == "Intermédiaire")
        #expect(label(1550) == "Intermédiaire confirmé")
        #expect(label(1850) == "Avancé / Expert")
        #expect(label(2200) == "Maître national")
        #expect(label(2450) == "Grand Maître")
        #expect(label(3150) == "Grand Maître")
    }

    @Test func theTopOfTheSliderIsMaximumNotAPreset() {
        #expect(label(3190) == nil)
        #expect(EngineStrength(sliderValue: 3190).displayLabel == "Maximum")
    }
}
