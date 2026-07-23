import Foundation

/// État persisté d'une partie du mode Jouer, pour pouvoir la reprendre
/// si l'app est tuée (elle peut l'être à tout moment sur iOS).
struct PlayGameAutosave: Codable, Hashable {
    var settings: PlayGameSettings
    /// Couleur effectivement attribuée à l'utilisateur (résolue une seule
    /// fois si le choix était "aléatoire").
    var resolvedUserColorRaw: String
    /// Coups joués jusqu'ici, en notation LAN moteur (ex. "e2e4", "e7e8q").
    var moveLANs: [String]
    var whiteRemaining: TimeInterval?
    var blackRemaining: TimeInterval?
    var savedAt: Date
}

/// Persistance locale simple (JSON dans Documents) de la partie en cours
/// du mode Jouer.
///
/// - note: Chaque mode aura son propre autosave suivant le même principe ;
/// un magasin SwiftData partagé arrivera avec le mode Analyser (étape 3)
/// quand une bibliothèque de parties devient nécessaire.
enum AutosaveStore {
    private static var playFileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("autosave_play.json")
    }

    static func savePlay(_ record: PlayGameAutosave) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: playFileURL, options: .atomic)
    }

    static func loadPlay() -> PlayGameAutosave? {
        guard let data = try? Data(contentsOf: playFileURL) else { return nil }
        return try? JSONDecoder().decode(PlayGameAutosave.self, from: data)
    }

    static func clearPlay() {
        try? FileManager.default.removeItem(at: playFileURL)
    }
}
