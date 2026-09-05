import Foundation
import Testing
@testable import ChessLab

/// Entretien des stores locaux — du code qui SUPPRIME des fichiers, donc du
/// code qui se teste, et sur les cas de travers autant que sur le cas nominal.
///
/// Le contexte, mesuré le 22/08/2026 sur des conteneurs réels : une
/// installation neuve pèse 60 Mo, mais un appareil venu des versions
/// précédentes en traînait jusqu'à 388. Deux gisements — l'ancien store
/// combiné (58 Mo de doublons jamais rouverts) et les quarantaines (jusqu'à
/// 240 Mo invisibles).
struct LocalStoreMaintenanceTests {

    /// Dossier jetable : ces fonctions effacent, elles ne s'approchent jamais
    /// d'un vrai Application Support pendant les tests.
    private func makeDirectory() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "StoreMaintenance-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ name: String, bytes: Int = 16, in directory: URL) throws {
        try Data(repeating: 0, count: bytes).write(to: directory.appending(path: name))
    }

    private func exists(_ name: String, in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appending(path: name).path)
    }

    // MARK: L'orphelin

    @Test("L'ancien store combiné est supprimé, journaux compris")
    func orphanedDefaultStoreIsPurged() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try write("Games.store", in: directory)
        try write("Puzzles.store", in: directory)
        for suffix in ["", "-shm", "-wal"] {
            try write("default.store" + suffix, bytes: 1024, in: directory)
        }

        let reclaimed = LocalStoreMaintenance.purgeOrphanedDefaultStore(in: directory)

        #expect(!exists("default.store", in: directory))
        #expect(!exists("default.store-shm", in: directory))
        #expect(!exists("default.store-wal", in: directory))
        #expect(reclaimed == 3 * 1024)
        #expect(exists("Games.store", in: directory), "les stores vivants ne sont pas touchés")
        #expect(exists("Puzzles.store", in: directory))
    }

    @Test("Sans store nommé, l'orphelin n'est PAS supprimé")
    func purgeRefusesWhenNoNamedStoreExists() throws {
        // Le garde-fou qui compte : si une future refonte revenait à un store
        // unique nommé « default », ce ménage effacerait les données de
        // l'utilisateur au premier lancement. Il ne doit agir que s'il a la
        // preuve que la séparation est en vigueur.
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try write("default.store", bytes: 4096, in: directory)

        let reclaimed = LocalStoreMaintenance.purgeOrphanedDefaultStore(in: directory)

        #expect(exists("default.store", in: directory), "aucune preuve de séparation : on ne touche à rien")
        #expect(reclaimed == 0)
    }

    @Test("Un seul store nommé suffit à prouver la séparation")
    func oneNamedStoreIsEnoughProof() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try write("Puzzles.store", in: directory)
        try write("default.store", in: directory)

        LocalStoreMaintenance.purgeOrphanedDefaultStore(in: directory)

        #expect(!exists("default.store", in: directory))
    }

    @Test("Rien à supprimer n'est pas une erreur")
    func purgingNothingIsHarmless() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try write("Games.store", in: directory)

        #expect(LocalStoreMaintenance.purgeOrphanedDefaultStore(in: directory) == 0)
        #expect(exists("Games.store", in: directory))
    }

    // MARK: La quarantaine

    @Test("La quarantaine archive Games mais SUPPRIME Puzzles")
    func quarantineArchivesGamesAndDropsPuzzles() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try write("Games.store", bytes: 512, in: directory)
        try write("Puzzles.store", bytes: 60_000, in: directory)
        try write("default.store", bytes: 60_000, in: directory)

        LocalStoreMaintenance.quarantineStores(in: directory)

        // Les stores quittent tous leur place — l'app doit les recréer à neuf.
        #expect(!exists("Games.store", in: directory))
        #expect(!exists("Puzzles.store", in: directory))
        #expect(!exists("default.store", in: directory))

        let root = directory.appending(path: "StoreQuarantine")
        let archives = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        let archived = try #require(archives.first)
        let names = try FileManager.default.contentsOfDirectory(atPath: archived.path)
        #expect(names.contains("Games.store"), "ce qui porte les données utilisateur est conservé")
        #expect(names.contains("default.store"))
        #expect(!names.contains("Puzzles.store"),
                "57 Mo régénérables depuis le bundle : les archiver ne diagnostique rien")
    }

    @Test("Une seule quarantaine est conservée")
    func onlyOneQuarantineSurvives() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appending(path: "StoreQuarantine")
        for stamp in ["2026-08-01T10-00-00Z", "2026-08-10T10-00-00Z", "2026-08-20T10-00-00Z"] {
            try FileManager.default.createDirectory(
                at: root.appending(path: stamp), withIntermediateDirectories: true)
        }

        LocalStoreMaintenance.pruneQuarantines(in: directory, now: Date(timeIntervalSince1970: 1_787_000_000))

        let left = try FileManager.default.contentsOfDirectory(atPath: root.path).sorted()
        #expect(left == ["2026-08-20T10-00-00Z"], "la plus récente, et elle seule")
    }

    @Test("Une quarantaine périmée est supprimée même si c'est la seule")
    func staleQuarantineIsRemovedEvenWhenAlone() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appending(path: "StoreQuarantine")
        let old = root.appending(path: "2026-01-01T00-00-00Z")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)

        LocalStoreMaintenance.pruneQuarantines(in: directory, now: Date(timeIntervalSince1970: 1_787_000_000))

        #expect(!FileManager.default.fileExists(atPath: old.path),
                "au-delà de deux semaines, une quarantaine ne diagnostique plus rien")
    }

    @Test("L'âge se lit dans le NOM, pas dans la date du fichier")
    func ageComesFromTheNameNotTheFilesystem() throws {
        // Le cas réel : un téléphone restauré depuis une vieille sauvegarde.
        // Tous les fichiers y portent une date de modification du jour, alors
        // que leur contenu a des mois. Sans cette lecture du nom, aucune
        // quarantaine restaurée ne périmerait jamais.
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appending(path: "StoreQuarantine")
        let old = root.appending(path: "2026-01-01T00-00-00Z")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        // Fraîchement « restaurée » : mtime d'aujourd'hui.
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: old.path)

        let read = try #require(LocalStoreMaintenance.creationDate(of: old))
        #expect(read.timeIntervalSince1970 < 1_770_000_000, "la date lue vient du nom")

        LocalStoreMaintenance.pruneQuarantines(in: directory, now: Date(timeIntervalSince1970: 1_787_000_000))
        #expect(!FileManager.default.fileExists(atPath: old.path))
    }

    @Test("Un nom illisible retombe sur la date du fichier")
    func unparsableNameFallsBackToFilesystemDate() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appending(path: "StoreQuarantine")
        let odd = root.appending(path: "sauvegarde-manuelle")
        try FileManager.default.createDirectory(at: odd, withIntermediateDirectories: true)

        let read = LocalStoreMaintenance.creationDate(of: odd)

        #expect(read != nil, "on ne renonce pas à dater un dossier au nom inattendu")
    }

    @Test("Une quarantaine récente est conservée")
    func recentQuarantineIsKept() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let root = directory.appending(path: "StoreQuarantine")
        // Datée d'IL Y A UNE HEURE, au format de production — pas une date en
        // dur : « 2026-08-22 » était récente à l'écriture du test et périmée
        // quinze jours plus tard, rougissant la suite sans qu'aucun code
        // n'ait changé (pourriture de date, constatée le 05/09/2026).
        let stamp = ISO8601DateFormatter()
            .string(from: Date().addingTimeInterval(-3600))
            .replacingOccurrences(of: ":", with: "-")
        let fresh = root.appending(path: stamp)
        try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)

        LocalStoreMaintenance.pruneQuarantines(in: directory)

        #expect(FileManager.default.fileExists(atPath: fresh.path))
    }

    @Test("Élaguer sans dossier de quarantaine ne fait rien")
    func pruningWithoutQuarantineFolderIsHarmless() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try write("Games.store", in: directory)

        LocalStoreMaintenance.pruneQuarantines(in: directory)

        #expect(exists("Games.store", in: directory))
    }
}
