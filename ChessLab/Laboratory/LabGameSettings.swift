import ChessKit
import Foundation

/// Réglages d'une série Laboratoire (Stockfish contre Stockfish).
///
/// Deux « camps » abstraits A et B, chacun avec sa propre force et son
/// propre livre : comme les couleurs alternent (voir `alternateColors`),
/// A n'est pas « les Blancs » mais un réglage moteur fixe suivi d'une série
/// à l'autre, ce qui permet d'estimer un écart Elo A↔B sans biais de
/// couleur.
struct LabGameSettings: Codable, Hashable {
    var sideAEloSlider: Double = 2200
    var sideBEloSlider: Double = 2000
    /// Budget de réflexion par coup, en millisecondes (mode « rapide » =
    /// petite valeur). Ignoré pour un réglage très faible qui plafonne la
    /// profondeur (voir ``EngineStrength/maxDepth``).
    var movetimeMs: Int = 150
    var sideABookEnabled: Bool = true
    var sideBBookEnabled: Bool = true
    var bookWidth: OpeningBookWidth = .includeSidelines
    /// Nombre de parties dans la série (1…500).
    var gameCount: Int = 20
    /// Alterne la couleur de A d'une partie à l'autre (recommandé pour un
    /// Elo non biaisé).
    var alternateColors: Bool = true
    /// Position de départ personnalisée (FEN) ; `nil` = position standard.
    var startFEN: String?
    /// Autorise l'abandon : un camp nettement perdant (|éval| ≥ 8 pions de
    /// façon prolongée) abandonne au lieu de jouer jusqu'au mat.
    var resignationEnabled: Bool = true
    /// Autorise la nulle par accord : sur une position nulle de façon
    /// prolongée (éval ~0), les deux camps « acceptent » la nulle. Les
    /// nulles selon les RÈGLES (pat, matériel insuffisant, 50 coups,
    /// répétition) restent, elles, toujours déclarées, indépendamment de
    /// ce réglage.
    var drawAgreementEnabled: Bool = true
    /// Anime le plateau coup par coup. Désactivé = mode « rapide » : la
    /// série défile au maximum, sans temporisation de visualisation.
    var liveVisualization: Bool = true

    /// Empêche la mise en veille pendant la série (Lot 2.D).
    ///
    /// Optionnel dans le modèle (`Bool?`) : une série sauvegardée par une
    /// version antérieure n'a pas ce champ, et un `Bool` non optionnel ferait
    /// échouer son décodage — donc perdre la reprise. C'est
    /// ``keepAwake`` qui tranche le défaut.
    var keepAwakeSetting: Bool?

    static let `default` = LabGameSettings()

    /// Une longue série tourne plusieurs minutes sans qu'on touche l'écran :
    /// activé par défaut au-delà de ~20 parties, où l'appareil s'endormirait
    /// à coup sûr avant la fin. En deçà, on ne prend pas la main sur un
    /// réglage système que l'utilisateur n'a pas demandé.
    var keepAwake: Bool {
        keepAwakeSetting ?? (gameCount > 20)
    }

    var sideAStrength: EngineStrength { EngineStrength(sliderValue: sideAEloSlider) }
    var sideBStrength: EngineStrength { EngineStrength(sliderValue: sideBEloSlider) }

    var startingPosition: Position {
        if let startFEN, let position = Position(fen: startFEN) {
            return position
        }
        return .standard
    }
}

/// Une partie terminée de la série — conserve tout le nécessaire pour les
/// stats, l'export (PGN/CSV) et la reprise après fermeture de l'app.
struct LabCompletedGame: Codable, Hashable, Identifiable {
    var index: Int
    /// A jouait-il les Blancs dans CETTE partie (dépend de l'alternance).
    var aWasWhite: Bool
    /// Résultat côté échiquier ("1-0", "0-1", "1/2-1/2").
    var pgnResult: String
    /// Raison stable de fin (voir ``GameOutcome/Reason/storageLabel``).
    var reasonLabel: String
    var plyCount: Int
    var pgn: String

    var id: Int { index }

    /// Résultat rapporté au camp A (indépendant de la couleur).
    var labResult: LabGameResult {
        switch pgnResult {
        case "1-0": aWasWhite ? .winA : .winB
        case "0-1": aWasWhite ? .winB : .winA
        default: .draw
        }
    }
}

/// État complet et reprenable d'une série : réglages + parties déjà jouées.
/// Persisté après CHAQUE partie pour survivre à une fermeture de l'app
/// (critère d'acceptation de l'étape 6).
struct LabSeriesState: Codable, Hashable {
    var settings: LabGameSettings
    var completed: [LabCompletedGame]
    var savedAt: Date

    var nextGameIndex: Int { completed.count }
    var isComplete: Bool { completed.count >= settings.gameCount }
}

/// Mémorise les derniers réglages utilisés (UserDefaults), comme
/// ``PlaySettingsStore`` — pour préremplir l'écran de configuration.
enum LabSettingsStore {
    private static let key = "labGameSettings.v1"

    static func save(_ settings: LabGameSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> LabGameSettings? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LabGameSettings.self, from: data)
    }
}

/// Persistance locale (JSON dans Documents) de la série Laboratoire en
/// cours — même principe que ``AutosaveStore`` pour le mode Jouer.
enum LabAutosaveStore {
    private static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lab_series.json")
    }

    static func save(_ state: LabSeriesState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func load() -> LabSeriesState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LabSeriesState.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
