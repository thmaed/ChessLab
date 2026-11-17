import Foundation

/// État persisté d'une partie du mode Jouer, pour pouvoir la reprendre
/// si l'app est tuée (elle peut l'être à tout moment sur iOS).
struct PlayGameAutosave: Codable, Hashable, AutosaveRecord {
    var settings: PlayGameSettings
    /// Couleur effectivement attribuée à l'utilisateur (résolue une seule
    /// fois si le choix était "aléatoire").
    var resolvedUserColorRaw: String
    /// Coups joués jusqu'ici, en notation LAN moteur (ex. "e2e4", "e7e8q").
    var moveLANs: [String]
    var whiteRemaining: TimeInterval?
    var blackRemaining: TimeInterval?
    var savedAt: Date
    /// L'identité de la partie (voir ``AutosaveRecord/gameID``) : née avec elle, gardée à chaque coup et à
    /// chaque reprise. Optionnelle : les sauvegardes d'avant le 16/11/2026 n'en ont pas.
    var gameID: UUID? = nil
    /// À l'aveugle : les coups d'œil déjà pris (``PlayViewModel/peekCount``). Optionnel : absent des
    /// sauvegardes d'avant le 17/11/2026 et des parties à vue.
    var blindfoldPeeks: Int? = nil
}

/// Persistance de la partie en cours du mode Jouer : un fichier JSON dans `Documents/`, que
/// ``SyncedAutosave`` recopie dans le magasin clé-valeur iCloud quand la synchronisation est allumée —
/// la partie se reprend alors sur un autre appareil de l'utilisateur, à l'accueil.
///
/// - note: Chaque mode a son propre autosave suivant le même principe ; un magasin SwiftData partagé sert
/// à la bibliothèque de parties terminées.
enum AutosaveStore {
    static func documentURL(_ name: String) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }

    /// Voir ``SyncedAutosave/save(_:publish:)``.
    static func savePlay(_ record: PlayGameAutosave, publish: Bool = true) {
        SyncedAutosave.play.save(record, publish: publish)
    }

    static func loadPlay() -> PlayGameAutosave? {
        SyncedAutosave.play.load()
    }

    static func clearPlay() {
        SyncedAutosave.play.clear()
    }
}
