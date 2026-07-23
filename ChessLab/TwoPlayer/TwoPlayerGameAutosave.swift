import Foundation

/// État persisté d'une partie "deux humains" en cours, pour pouvoir la
/// reprendre si l'app est tuée — même principe que ``PlayGameAutosave``,
/// dans un fichier séparé (les deux autosaves cohabitent : démarrer une
/// partie dans un mode n'efface jamais l'autosauvegarde de l'autre).
struct TwoPlayerGameAutosave: Codable, Hashable {
    var settings: TwoPlayerGameSettings
    /// Coups joués jusqu'ici, en notation LAN moteur (ex. "e2e4").
    var moveLANs: [String]
    var whiteRemaining: TimeInterval?
    var blackRemaining: TimeInterval?
    var savedAt: Date
}

extension AutosaveStore {
    private static var twoPlayerFileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("autosave_twoplayer.json")
    }

    static func saveTwoPlayer(_ record: TwoPlayerGameAutosave) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: twoPlayerFileURL, options: .atomic)
    }

    static func loadTwoPlayer() -> TwoPlayerGameAutosave? {
        guard let data = try? Data(contentsOf: twoPlayerFileURL) else { return nil }
        return try? JSONDecoder().decode(TwoPlayerGameAutosave.self, from: data)
    }

    static func clearTwoPlayer() {
        try? FileManager.default.removeItem(at: twoPlayerFileURL)
    }
}
