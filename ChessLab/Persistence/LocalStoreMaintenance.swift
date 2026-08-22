import Foundation

/// Entretien des fichiers de stores SwiftData : ce que l'app doit effacer, et
/// ce qu'elle doit garder.
///
/// Extrait de ``ChessLabApp`` pour être TESTABLE — ces fonctions suppriment et
/// déplacent des fichiers, c'est exactement le genre de code qu'on ne veut pas
/// écrire à l'aveugle. Elles reçoivent le dossier en paramètre : les tests
/// travaillent dans un dossier temporaire, l'app leur passe Application Support.
///
/// ## Ce qui a motivé ce fichier (mesures du 22/08/2026)
///
/// Un utilisateur signalait **388 Mo** de « Documents et données ». Mesure sur
/// conteneurs réels : une installation NEUVE du build courant pèse 60 Mo
/// (`Puzzles.store` 57,4 + `Games.store` 0,1). Les 328 Mo restants étaient de
/// l'accumulation historique — deux gisements, tous deux traités ici.
enum LocalStoreMaintenance {

    /// Les stores nommés que l'app utilise réellement depuis la séparation.
    static let liveStoreNames = ["Games.store", "Puzzles.store"]
    /// L'ancien store combiné, d'avant la séparation Games/Puzzles.
    static let orphanedStoreName = "default.store"
    /// Le store re-généré depuis le bundle : jamais la peine de l'archiver.
    static let rebuildableStoreName = "Puzzles.store"

    private static let journalSuffixes = ["", "-shm", "-wal"]

    // MARK: L'orphelin

    /// Supprime `default.store` et ses journaux — l'ancien store unique,
    /// d'avant la séparation en « Games » et « Puzzles ».
    ///
    /// Mesuré sur un conteneur réel : **58 Mo**, contenant les 106 094 puzzles
    /// en DOUBLE de `Puzzles.store` et des entités qui n'existent plus dans
    /// l'app (`ZREPERTOIRE`, `ZREPERTOIREITEM`). Le code ne l'ouvre jamais ;
    /// seul le chemin de quarantaine le mentionnait, et il ne s'exécute
    /// qu'après deux échecs consécutifs d'ouverture. Autrement dit, en marche
    /// normale il restait là indéfiniment.
    ///
    /// - Important: la suppression n'a lieu QUE si l'un des stores nommés
    ///   existe. Sans ce garde-fou, une future refonte qui reviendrait à un
    ///   store unique verrait ses données effacées au premier lancement.
    /// - Returns: les octets récupérés (0 si rien à faire).
    @discardableResult
    static func purgeOrphanedDefaultStore(in directory: URL) -> Int {
        let fileManager = FileManager.default
        let separationIsLive = liveStoreNames.contains { name in
            fileManager.fileExists(atPath: directory.appendingPathComponent(name).path)
        }
        guard separationIsLive else { return 0 }

        var reclaimed = 0
        for suffix in journalSuffixes {
            let url = directory.appendingPathComponent(orphanedStoreName + suffix)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            reclaimed += size(of: url)
            try? fileManager.removeItem(at: url)
        }
        return reclaimed
    }

    // MARK: La quarantaine

    /// Nombre de quarantaines conservées. UNE seule : la précédente n'a jamais
    /// servi à personne, et chacune coûtait ~120 Mo.
    static let quarantinesKept = 1
    /// Au-delà, une quarantaine ne diagnostique plus rien et n'est plus que du
    /// poids mort — l'utilisateur a mis à jour dix fois entre-temps.
    static let quarantineMaxAge: TimeInterval = 14 * 24 * 3600

    /// Met les stores locaux en quarantaine — déplacés, jamais supprimés, dans
    /// un dossier horodaté récupérable au support.
    ///
    /// Deux différences avec la version d'origine, toutes deux mesurées :
    ///
    /// 1. **`Puzzles.store` n'est PAS archivé, il est supprimé.** Il pèse
    ///    57 Mo et se reconstruit intégralement depuis le bundle — le seeder
    ///    gère déjà nativement le store vide. L'archiver revenait à conserver
    ///    114 Mo de bibliothèque Lichess identique sur tous les appareils du
    ///    monde, au motif de « pouvoir diagnostiquer ».
    /// 2. **Une seule quarantaine est conservée, et elle périme.** Deux
    ///    quarantaines faisaient jusqu'à 240 Mo invisibles pour l'utilisateur,
    ///    sans aucun moyen de les effacer hors désinstallation.
    ///
    /// Ce qui compte vraiment pour le support — `Games.store`, qui porte les
    /// parties, les répertoires personnels et la progression — reste archivé
    /// intégralement.
    static func quarantineStores(in directory: URL, now: Date = Date()) {
        let fileManager = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: now)
            .replacingOccurrences(of: ":", with: "-")
        let root = directory.appendingPathComponent("StoreQuarantine", isDirectory: true)
        let quarantine = root.appendingPathComponent(stamp, isDirectory: true)
        try? fileManager.createDirectory(at: quarantine, withIntermediateDirectories: true)

        for base in liveStoreNames + [orphanedStoreName] {
            for suffix in journalSuffixes {
                let name = base + suffix
                let source = directory.appendingPathComponent(name)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                if base == rebuildableStoreName {
                    // Re-généré depuis le bundle : rien à diagnostiquer.
                    try? fileManager.removeItem(at: source)
                } else {
                    // Déplacement, jamais suppression : si le déplacement
                    // échoue, mieux vaut laisser le fichier en place et échouer
                    // à recréer que détruire des données utilisateur.
                    try? fileManager.moveItem(at: source, to: quarantine.appendingPathComponent(name))
                }
            }
        }

        pruneQuarantines(in: directory, now: now)
    }

    /// Applique les deux limites : le nombre, et l'âge. Appelée après chaque
    /// mise en quarantaine, et au démarrage pour rattraper les archives
    /// laissées par les versions précédentes.
    static func pruneQuarantines(in directory: URL, now: Date = Date()) {
        let fileManager = FileManager.default
        let root = directory.appendingPathComponent("StoreQuarantine", isDirectory: true)
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        // Les noms sont des horodatages ISO 8601 : l'ordre lexicographique est
        // l'ordre chronologique, sans dépendre des dates du système de fichiers.
        let sorted = entries.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let tooMany = sorted.dropLast(quarantinesKept)
        for url in tooMany { try? fileManager.removeItem(at: url) }

        for url in sorted.suffix(quarantinesKept) {
            guard let created = creationDate(of: url) else { continue }
            guard now.timeIntervalSince(created) > quarantineMaxAge else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    /// Date d'une quarantaine, lue d'ABORD dans son nom.
    ///
    /// Le nom EST un horodatage ISO 8601, écrit au moment de la mise en
    /// quarantaine ; la date de modification du système de fichiers, elle, se
    /// réécrit à la moindre restauration de sauvegarde ou copie de conteneur.
    /// Or c'est précisément le cas qui nous intéresse : un téléphone restauré
    /// depuis une vieille sauvegarde présenterait des archives de plusieurs
    /// mois avec une mtime du jour, et elles ne périmeraient jamais. On retombe
    /// sur la mtime seulement si le nom est illisible (dossier créé à la main,
    /// version future au format différent).
    static func creationDate(of quarantine: URL) -> Date? {
        let name = quarantine.lastPathComponent.replacingOccurrences(of: "-", with: ":")
        // Le nom a remplacé les « : » de l'ISO 8601 par des « - » ; on refait
        // le chemin inverse, en préservant les tirets de la date elle-même.
        let restored = name.replacingOccurrences(
            of: #"^(\d{4}):(\d{2}):(\d{2})"#, with: "$1-$2-$3", options: .regularExpression)
        if let parsed = ISO8601DateFormatter().date(from: restored) { return parsed }
        return (try? quarantine.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
    }

    // MARK: Détail

    /// Taille d'un fichier, 0 s'il est illisible — on ne fait échouer aucun
    /// ménage pour un compteur d'octets.
    private static func size(of url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    }
}
