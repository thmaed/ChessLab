import Foundation

/// Réglages d'une partie contre l'ordinateur dans une variante Fairy-Stockfish
/// (Roi de la colline, Trois échecs, Horde) — même sous-ensemble que
/// ``Chess960Settings``, sans le choix de position qui n'a pas de sens ici.
struct FairyVariantSettings: Codable, Equatable, Hashable {
    var colorChoice: PlayerColorChoice.RawValue = PlayerColorChoice.white.rawValue
    var eloSliderValue: Double = 1200
    var timeControlID: String = TimeControl.none.id
    var customMinutes: Int = 15
    var customIncrementSeconds: Int = 0
    var showEvalBar: Bool = false
    var hintsEnabled: Bool = true
    var blunderAlertEnabled: Bool = true
    /// Coup Volé UNIQUEMENT (ignoré par les six autres variantes, qui
    /// partagent ce même type de réglages) — nombre de coups entre deux
    /// jetons, voir ``StolenMoveVariant/tokenIntervalRange``.
    var stolenMoveTokenInterval: Int = StolenMoveVariant.defaultTokenInterval

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = FairyVariantSettings()
        colorChoice = try container.decodeIfPresent(PlayerColorChoice.RawValue.self, forKey: .colorChoice) ?? fallback.colorChoice
        eloSliderValue = try container.decodeIfPresent(Double.self, forKey: .eloSliderValue) ?? fallback.eloSliderValue
        timeControlID = try container.decodeIfPresent(String.self, forKey: .timeControlID) ?? fallback.timeControlID
        customMinutes = try container.decodeIfPresent(Int.self, forKey: .customMinutes) ?? fallback.customMinutes
        customIncrementSeconds = try container.decodeIfPresent(Int.self, forKey: .customIncrementSeconds) ?? fallback.customIncrementSeconds
        showEvalBar = try container.decodeIfPresent(Bool.self, forKey: .showEvalBar) ?? fallback.showEvalBar
        hintsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hintsEnabled) ?? fallback.hintsEnabled
        blunderAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .blunderAlertEnabled) ?? fallback.blunderAlertEnabled
        stolenMoveTokenInterval = try container.decodeIfPresent(Int.self, forKey: .stolenMoveTokenInterval) ?? fallback.stolenMoveTokenInterval
    }

    init() {}

    var resolvedColorChoice: PlayerColorChoice {
        PlayerColorChoice(rawValue: colorChoice) ?? .white
    }

    var strength: EngineStrength {
        EngineStrength(sliderValue: eloSliderValue)
    }

    var timeControl: TimeControl {
        if timeControlID == "custom" {
            return TimeControl.custom(minutes: customMinutes, incrementSeconds: customIncrementSeconds)
        }
        return TimeControl.presets.first { $0.id == timeControlID } ?? .none
    }
}

/// Persistance des derniers réglages, PAR VARIANTE — Roi de la colline et
/// Horde n'ont aucune raison de partager la même force ou la même cadence.
enum FairyVariantSettingsStore {
    private static func key(for variantID: String) -> String {
        "lastFairyVariantSettings.\(variantID)"
    }

    static func save(_ settings: FairyVariantSettings, for variantID: String) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key(for: variantID))
    }

    static func load(for variantID: String) -> FairyVariantSettings? {
        guard let data = UserDefaults.standard.data(forKey: key(for: variantID)) else { return nil }
        return try? JSONDecoder().decode(FairyVariantSettings.self, from: data)
    }
}
