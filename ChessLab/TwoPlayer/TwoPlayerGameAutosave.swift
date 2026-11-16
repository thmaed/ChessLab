import Foundation

/// État persisté d'une partie "deux humains" en cours, pour pouvoir la
/// reprendre si l'app est tuée — même principe que ``PlayGameAutosave``,
/// dans un fichier séparé (les deux autosaves cohabitent : démarrer une
/// partie dans un mode n'efface jamais l'autosauvegarde de l'autre).
struct TwoPlayerGameAutosave: Codable, Hashable, AutosaveRecord {
    var settings: TwoPlayerGameSettings
    /// Coups joués jusqu'ici, en notation LAN moteur (ex. "e2e4").
    var moveLANs: [String]
    var whiteRemaining: TimeInterval?
    var blackRemaining: TimeInterval?
    var savedAt: Date
    /// Voir ``PlayGameAutosave/gameID``.
    var gameID: UUID? = nil
}

extension AutosaveStore {
    static func saveTwoPlayer(_ record: TwoPlayerGameAutosave) {
        SyncedAutosave.twoPlayer.save(record)
    }

    static func loadTwoPlayer() -> TwoPlayerGameAutosave? {
        SyncedAutosave.twoPlayer.load()
    }

    static func clearTwoPlayer() {
        SyncedAutosave.twoPlayer.clear()
    }
}
