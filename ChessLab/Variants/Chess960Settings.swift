import Foundation

/// Réglages d'une partie de Chess960 contre l'ordinateur — le sous-ensemble
/// de ``PlayGameSettings`` qui a un sens dans la variante, plus le choix de
/// position. Pas de livre d'ouvertures (il n'y a pas de théorie), et les
/// aides d'analyse (indice, alerte gaffe) arrivent avec le lot « aides » —
/// le style de « Contre l'ordinateur », par étapes.
struct Chess960Settings: Codable, Equatable, Hashable {
    var colorChoice: PlayerColorChoice.RawValue = PlayerColorChoice.white.rawValue
    var eloSliderValue: Double = 1200
    var timeControlID: String = TimeControl.none.id
    var customMinutes: Int = 15
    var customIncrementSeconds: Int = 0
    var showEvalBar: Bool = false
    var hintsEnabled: Bool = true
    var blunderAlertEnabled: Bool = true
    /// Dernier numéro de Scharnagl joué — c'est lui que « Rejouer la même »
    /// relance, et il est TOUJOURS affiché pendant la partie.
    var positionNumber: Int = 518

    /// Décodage défensif, champ à champ — même contrat que
    /// ``PlayGameSettings`` : un réglage ajouté demain ne doit pas faire
    /// perdre ceux d'hier.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Chess960Settings()
        colorChoice = try container.decodeIfPresent(PlayerColorChoice.RawValue.self, forKey: .colorChoice) ?? fallback.colorChoice
        eloSliderValue = try container.decodeIfPresent(Double.self, forKey: .eloSliderValue) ?? fallback.eloSliderValue
        timeControlID = try container.decodeIfPresent(String.self, forKey: .timeControlID) ?? fallback.timeControlID
        customMinutes = try container.decodeIfPresent(Int.self, forKey: .customMinutes) ?? fallback.customMinutes
        customIncrementSeconds = try container.decodeIfPresent(Int.self, forKey: .customIncrementSeconds) ?? fallback.customIncrementSeconds
        showEvalBar = try container.decodeIfPresent(Bool.self, forKey: .showEvalBar) ?? fallback.showEvalBar
        hintsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hintsEnabled) ?? fallback.hintsEnabled
        blunderAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .blunderAlertEnabled) ?? fallback.blunderAlertEnabled
        positionNumber = try container.decodeIfPresent(Int.self, forKey: .positionNumber) ?? fallback.positionNumber
        if !(0...959).contains(positionNumber) { positionNumber = fallback.positionNumber }
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

/// Persistance des derniers réglages — même mécanique que
/// ``PlaySettingsStore``, clé distincte.
enum Chess960SettingsStore {
    private static let key = "lastChess960Settings"

    static func save(_ settings: Chess960Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> Chess960Settings? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Chess960Settings.self, from: data)
    }
}
