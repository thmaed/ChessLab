import Foundation

/// Le dernier niveau choisi pour chaque personnage, mémorisé séparément :
/// on joue Pablo à 1 000 et Nadia à 1 800, et l'écran Nouvelle partie doit
/// s'en souvenir par personnage, pas d'un seul curseur pour tous.
///
/// JSON dans UserDefaults, clé synchronisée iCloud (voir
/// `SettingsCloudSync.syncedKeys`).
enum OpponentLevelStore {
    static let key = "opponentLevels.v1"

    static func level(for profileID: String, defaults: UserDefaults = .standard) -> Double? {
        levels(defaults: defaults)[profileID]
    }

    static func save(level: Double, for profileID: String, defaults: UserDefaults = .standard) {
        var all = levels(defaults: defaults)
        all[profileID] = level
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: key)
    }

    static func levels(defaults: UserDefaults = .standard) -> [String: Double] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return [:] }
        return decoded
    }
}
