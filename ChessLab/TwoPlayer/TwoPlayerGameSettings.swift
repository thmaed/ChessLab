import Foundation

/// Réglages choisis avant une partie "deux humains sur le même appareil".
///
/// Volontairement plus simple que ``PlayGameSettings`` : pas de position
/// personnalisée (le prompt ne le prévoit que pour "Contre Stockfish"),
/// pas de reprise de coup (non mentionné pour ce mode — esprit "feuille
/// de partie du club", fidélité à ce qui a été réellement joué).
struct TwoPlayerGameSettings: Codable, Equatable, Hashable {
    enum RotationMode: String, Codable {
        /// Le plateau pivote à 180° après chaque coup (les deux joueurs
        /// sont assis face à face).
        case faceToFace
        /// Orientation fixe (les deux joueurs sont côte à côte).
        case fixed
        /// Plateau fixe (comme ``fixed``), mais HUD et contrôles du
        /// joueur du haut sont retournés à 180° : personne n'a jamais
        /// besoin de faire pivoter l'appareil, chacun lit ses propres
        /// informations à l'endroit depuis son côté de la table.
        case tabletop
    }

    var whiteName: String = "Blancs"
    var blackName: String = "Noirs"
    var rotationMode: RotationMode = .faceToFace
    var timeControlID: String = TimeControl.none.id
    /// Utilisés uniquement quand `timeControlID == "custom"`.
    var customMinutes: Int = 15
    var customIncrementSeconds: Int = 0

    var timeControl: TimeControl {
        if timeControlID == "custom" {
            return .custom(minutes: customMinutes, incrementSeconds: customIncrementSeconds)
        }
        return TimeControl.presets.first { $0.id == timeControlID } ?? .none
    }

    static let `default` = TwoPlayerGameSettings()
}

/// Mémorise les derniers réglages utilisés pour préremplir l'écran de
/// configuration (noms, cadence, rotation), sur le même principe que
/// ``PlaySettingsStore``. Contrairement au FEN personnalisé du mode
/// Jouer, les noms des joueurs SONT ici persistés par défaut : deux
/// joueurs récurrents (club) rejoueront probablement sous les mêmes noms.
enum TwoPlayerSettingsStore {
    private static let key = "lastTwoPlayerGameSettings"

    static func save(_ settings: TwoPlayerGameSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> TwoPlayerGameSettings? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TwoPlayerGameSettings.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
