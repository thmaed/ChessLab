import Foundation

/// La boîte aux lettres entre l'extension de partage (`ChessLabShare`) et l'app.
///
/// Les deux ne partagent aucun processus : « Partager › ChessLab » depuis Photos
/// lance l'extension, qui dépose l'image dans le conteneur de groupe
/// (`group.com.chesslab.ChessLab`) et s'efface. À son réveil, l'app y trouve
/// l'image, ouvre le scanner dessus et vide la boîte.
///
/// Compilé dans les DEUX cibles (dossier `Shared/`) : l'écrivain et le lecteur
/// ne peuvent pas se désaccorder sur le nom du groupe ni du fichier.
///
/// Une seule image à la fois : un second partage remplace le premier, qui n'a
/// pas été lu. Rien n'y reste plus de ``maximumAge`` — une image oubliée ne doit
/// pas surgir des jours plus tard dans le scanner.
///
/// Aucune donnée ne sort de l'appareil : le conteneur de groupe est local.
enum SharedImageInbox {
    static let groupIdentifier = "group.com.chesslab.ChessLab"

    /// Au-delà, l'image déposée est tenue pour oubliée.
    static let maximumAge: TimeInterval = 24 * 60 * 60

    private static let fileName = "partage-image"

    /// Le dossier du conteneur de groupe, ou `nil` si l'app n'a pas le droit de
    /// groupe (construction non signée) — la boîte est alors inerte, sans erreur.
    static var defaultDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }

    private static func file(in directory: URL) -> URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: Écriture (extension)

    /// Dépose l'image reçue, en remplaçant celle qui attendait.
    ///
    /// Copiée sous un nom provisoire puis déplacée : l'app ne voit jamais un
    /// fichier à moitié écrit.
    static func deposit(contentsOf source: URL, in directory: URL? = defaultDirectory) throws {
        guard let directory else { throw CocoaError(.fileNoSuchFile) }
        let destination = file(in: directory)
        let temporary = directory.appendingPathComponent("\(fileName).\(UUID().uuidString).tmp")
        try FileManager.default.copyItem(at: source, to: temporary)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    // MARK: Lecture (app)

    /// Une image attend-elle ? Une image trop vieille est supprimée au passage.
    static func hasPending(in directory: URL? = defaultDirectory, now: Date = .now) -> Bool {
        guard let directory else { return false }
        let url = file(in: directory)
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate else { return false }
        if now.timeIntervalSince(modified) > maximumAge {
            try? FileManager.default.removeItem(at: url)
            return false
        }
        return true
    }

    /// Les octets de l'image en attente, SANS vider la boîte : l'app ne la vide
    /// (``discard(in:)``) qu'une fois l'image chargée, pour qu'une vue reconstruite
    /// en cours de route ne la perde pas.
    static func peek(in directory: URL? = defaultDirectory, now: Date = .now) -> Data? {
        guard let directory, hasPending(in: directory, now: now) else { return nil }
        return try? Data(contentsOf: file(in: directory))
    }

    /// Vide la boîte.
    static func discard(in directory: URL? = defaultDirectory) {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: file(in: directory))
    }

    /// Lit puis vide, d'un seul geste : une image ne se lit qu'une fois.
    static func take(in directory: URL? = defaultDirectory, now: Date = .now) -> Data? {
        defer { discard(in: directory) }
        return peek(in: directory, now: now)
    }
}
