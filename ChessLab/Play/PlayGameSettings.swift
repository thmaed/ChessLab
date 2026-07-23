import ChessKit
import Foundation

/// Réglages choisis avant de démarrer une partie contre le moteur.
struct PlayGameSettings: Codable, Equatable, Hashable {
    var colorChoice: PlayerColorChoice.RawValue = PlayerColorChoice.white.rawValue
    /// Défaut accueillant (Intermédiaire ~1200) plutôt que la pleine
    /// puissance : un débutant qui démarre sans régler ne doit pas
    /// affronter Stockfish à fond.
    var eloSliderValue: Double = 1200
    var timeControlID: String = TimeControl.none.id
    /// Utilisés uniquement quand `timeControlID == "custom"`.
    var customMinutes: Int = 15
    var customIncrementSeconds: Int = 0
    var startFEN: String?
    var hintsEnabled: Bool = true
    var blunderAlertEnabled: Bool = true
    var showEvalBar: Bool = false
    /// Autorise, en tapant un coup antérieur dans la liste, de reprendre
    /// plusieurs coups d'un coup plutôt qu'un seul à la fois (bouton
    /// "Reprendre" habituel). Désactivé par défaut : c'est une aide plus
    /// appuyée que les autres, laissée en opt-in.
    var multiMoveTakebackEnabled: Bool = false
    /// Le moteur pioche ses premiers coups dans le livre d'ouvertures tant
    /// que la position y figure (voir ``OpeningBookEngine``). Actif par
    /// défaut, cohérent avec le côté accueillant du reste des réglages.
    var bookEnabled: Bool = true
    var bookWidth: OpeningBookWidth = .mainLinesOnly
    /// Le moteur s'autorise à abandonner quand il se sait nettement perdu
    /// (voir ``PlayViewModel/maybeEngineResignsOrOffersDraw()``). Désactivable
    /// pour qui veut conclure lui-même : un débutant qui vient de gagner une
    /// dame apprend en donnant le mat, pas en voyant la partie s'arrêter.
    var engineResignationEnabled: Bool = true

    /// Décodage TOLÉRANT aux champs absents.
    ///
    /// ⚠️ Le décodeur synthétisé de Swift n'utilise PAS les valeurs par
    /// défaut : il exige chaque clé. Comme `PlaySettingsStore.load()` décode
    /// avec `try?`, ajouter un simple champ non optionnel faisait échouer en
    /// silence le décodage de TOUS les réglages déjà enregistrés — l'écran
    /// repartait aux valeurs d'usine, couleur, force et cadence comprises,
    /// sans que rien ne l'explique. `decodeIfPresent` partout règle la classe
    /// entière du problème, pas seulement le champ du jour.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = PlayGameSettings()

        colorChoice = try container.decodeIfPresent(PlayerColorChoice.RawValue.self, forKey: .colorChoice) ?? fallback.colorChoice
        eloSliderValue = try container.decodeIfPresent(Double.self, forKey: .eloSliderValue) ?? fallback.eloSliderValue
        timeControlID = try container.decodeIfPresent(String.self, forKey: .timeControlID) ?? fallback.timeControlID
        customMinutes = try container.decodeIfPresent(Int.self, forKey: .customMinutes) ?? fallback.customMinutes
        customIncrementSeconds = try container.decodeIfPresent(Int.self, forKey: .customIncrementSeconds) ?? fallback.customIncrementSeconds
        startFEN = try container.decodeIfPresent(String.self, forKey: .startFEN)
        hintsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hintsEnabled) ?? fallback.hintsEnabled
        blunderAlertEnabled = try container.decodeIfPresent(Bool.self, forKey: .blunderAlertEnabled) ?? fallback.blunderAlertEnabled
        showEvalBar = try container.decodeIfPresent(Bool.self, forKey: .showEvalBar) ?? fallback.showEvalBar
        multiMoveTakebackEnabled = try container.decodeIfPresent(Bool.self, forKey: .multiMoveTakebackEnabled) ?? fallback.multiMoveTakebackEnabled
        bookEnabled = try container.decodeIfPresent(Bool.self, forKey: .bookEnabled) ?? fallback.bookEnabled
        bookWidth = try container.decodeIfPresent(OpeningBookWidth.self, forKey: .bookWidth) ?? fallback.bookWidth
        engineResignationEnabled = try container.decodeIfPresent(Bool.self, forKey: .engineResignationEnabled) ?? fallback.engineResignationEnabled
    }

    /// Requis dès qu'un `init(from:)` explicite existe : il masque
    /// l'initialiseur mémbre à mémbre synthétisé.
    init(
        colorChoice: PlayerColorChoice.RawValue = PlayerColorChoice.white.rawValue,
        eloSliderValue: Double = 1200,
        timeControlID: String = TimeControl.none.id,
        customMinutes: Int = 15,
        customIncrementSeconds: Int = 0,
        startFEN: String? = nil,
        hintsEnabled: Bool = true,
        blunderAlertEnabled: Bool = true,
        showEvalBar: Bool = false,
        multiMoveTakebackEnabled: Bool = false,
        bookEnabled: Bool = true,
        bookWidth: OpeningBookWidth = .mainLinesOnly,
        engineResignationEnabled: Bool = true
    ) {
        self.colorChoice = colorChoice
        self.eloSliderValue = eloSliderValue
        self.timeControlID = timeControlID
        self.customMinutes = customMinutes
        self.customIncrementSeconds = customIncrementSeconds
        self.startFEN = startFEN
        self.hintsEnabled = hintsEnabled
        self.blunderAlertEnabled = blunderAlertEnabled
        self.showEvalBar = showEvalBar
        self.multiMoveTakebackEnabled = multiMoveTakebackEnabled
        self.bookEnabled = bookEnabled
        self.bookWidth = bookWidth
        self.engineResignationEnabled = engineResignationEnabled
    }

    var resolvedColorChoice: PlayerColorChoice {
        PlayerColorChoice(rawValue: colorChoice) ?? .white
    }

    var strength: EngineStrength {
        EngineStrength(sliderValue: eloSliderValue)
    }

    var timeControl: TimeControl {
        if timeControlID == "custom" {
            return .custom(minutes: customMinutes, incrementSeconds: customIncrementSeconds)
        }
        return TimeControl.presets.first { $0.id == timeControlID } ?? .none
    }

    var startingPosition: Position {
        if let startFEN, let position = Position(fen: startFEN) {
            position
        } else {
            .standard
        }
    }

    static let `default` = PlayGameSettings()
}

/// Mémorise les derniers réglages utilisés pour préremplir l'écran
/// "Nouvelle partie" (couleur, force, cadence, aides…).
///
/// Le FEN de départ n'est volontairement PAS mémorisé : une position
/// personnalisée est un choix ponctuel, pas une préférence durable.
enum PlaySettingsStore {
    private static let key = "lastPlayGameSettings"

    static func save(_ settings: PlayGameSettings) {
        var toStore = settings
        toStore.startFEN = nil
        guard let data = try? JSONEncoder().encode(toStore) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> PlayGameSettings? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PlayGameSettings.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
