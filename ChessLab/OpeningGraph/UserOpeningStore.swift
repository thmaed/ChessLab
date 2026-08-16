import Foundation
import Observation
import SwiftData

/// Répertoires d'ouverture APPORTÉS par l'utilisateur : importés d'un PGN,
/// reçus d'un ami, écrits ailleurs puis versés ici.
///
/// Stockés en JSON dans `Documents/UserOpenings/`, au format EXACT des cours
/// embarqués. C'est délibéré et c'est ce qui rend le partage gratuit : un cours
/// est déjà un fichier autonome, l'exporter c'est le donner tel quel, et
/// l'importer c'est le même décodeur qu'au démarrage. Aucun serveur, aucun
/// compte, aucun format propriétaire.
///
/// La PROGRESSION n'est pas ici : elle vit dans ``OpeningPositionProgress``,
/// indexée par FEN normalisée et synchronisée par iCloud. Un cours importé
/// hérite donc immédiatement de ce que l'utilisateur sait déjà des positions
/// qu'il contient — y compris apprises dans un cours embarqué. C'est tout
/// l'intérêt d'indexer par position plutôt que par cours.
@Observable
@MainActor
final class UserOpeningStore {
    static let shared = UserOpeningStore()

    /// Préfixe d'identifiant : distingue un cours utilisateur d'un cours
    /// embarqué d'un simple coup d'œil, côté code comme côté fichier.
    static let identifierPrefix = "user-"

    /// Index en mémoire, relu du disque au démarrage. `@Observable` : la liste
    /// des ouvertures se rafraîchit d'elle-même après un import.
    private(set) var catalog: [OpeningCatalogEntry] = []

    private let directory: URL?
    /// Cours déjà décodés (le graphe complet coûte cher à relire).
    private var cache: [String: OpeningCourse] = [:]

    /// Base synchronisée. Injectée une fois au lancement par ``ChessLabApp``
    /// — le store est un singleton atteint depuis des endroits statiques
    /// (``OpeningCourseLoader``), il ne peut pas recevoir un contexte à chaque
    /// appel.
    private var context: ModelContext?

    init(directory: URL? = UserOpeningStore.defaultDirectory()) {
        self.directory = directory
        reload()
    }

    /// Branche la base, migre les fichiers existants, puis relit tout.
    ///
    /// Tant que ceci n'est pas appelé, le store continue de lire les fichiers :
    /// aucun écran ne se retrouve vide si l'initialisation échoue.
    func attach(context: ModelContext) {
        self.context = context
        migrateLegacyFilesIfNeeded()
        reload()
    }

    /// Reprend les répertoires laissés en fichiers par les versions
    /// précédentes.
    ///
    /// Les fichiers ne sont PAS supprimés : ils deviennent une sauvegarde
    /// locale muette. Effacer les données d'un utilisateur au premier
    /// lancement d'une mise à jour, sur la foi d'une migration qu'on n'a pas
    /// encore vue réussir, serait le pire moment pour se tromper.
    private func migrateLegacyFilesIfNeeded() {
        guard let context, let directory else { return }
        let existing = Set((try? context.fetch(FetchDescriptor<UserOpeningRecord>()))?.map(\.id) ?? [])
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return }

        var migrated = 0
        for url in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let course = try? OpeningCourseLoader.decodeCourse(from: data),
                  !existing.contains(course.id)
            else { continue }
            context.insert(UserOpeningRecord(id: course.id, name: course.name, payload: data))
            migrated += 1
        }
        if migrated > 0 { try? context.save() }
    }

    static func isUserCourse(id: String) -> Bool { id.hasPrefix(identifierPrefix) }

    static func newIdentifier() -> String { identifierPrefix + UUID().uuidString.lowercased() }

    private static func defaultDirectory() -> URL? {
        guard let documents = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        let directory = documents.appending(path: "UserOpenings", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: Lecture

    /// Relit l'index depuis le disque. Un fichier illisible est IGNORÉ, jamais
    /// fatal — même discipline défensive que le chargeur des cours embarqués.
    func reload() {
        cache = [:]
        if let context {
            let records = (try? context.fetch(FetchDescriptor<UserOpeningRecord>())) ?? []
            catalog = records
                .compactMap { record -> OpeningCatalogEntry? in
                    guard let course = record.course else { return nil }
                    cache[course.id] = course
                    return OpeningCatalogEntry(course)
                }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return
        }
        // Repli : base pas encore branchée.
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil
              )
        else {
            catalog = []
            return
        }
        catalog = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> OpeningCatalogEntry? in
                guard let course = decodeCourse(at: url) else { return nil }
                cache[course.id] = course
                return OpeningCatalogEntry(course)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func course(id: String) -> OpeningCourse? {
        if let cached = cache[id] { return cached }
        guard let url = fileURL(for: id), let course = decodeCourse(at: url) else { return nil }
        cache[id] = course
        return course
    }

    /// URL du fichier d'un cours — emplacement HÉRITÉ, conservé pour la
    /// migration et le repli.
    func fileURL(for id: String) -> URL? {
        guard Self.isUserCourse(id: id), let directory else { return nil }
        return directory.appending(path: "\(id).json")
    }

    /// Fichier à PARTAGER, écrit à la demande dans le dossier temporaire.
    ///
    /// Le répertoire vit désormais en base ; le fichier n'est plus la vérité
    /// mais reste le format d'échange — c'est lui qu'on envoie par AirDrop ou
    /// Messages, et c'est ce qui garde le partage sans compte ni serveur.
    ///
    /// Nommé d'après le TITRE du répertoire et non son identifiant : celui qui
    /// le reçoit voit « Ma Scandinave.pgn.json » plutôt qu'un UUID.
    func exportFileURL(for id: String) -> URL? {
        guard let course = course(id: id) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(course) else { return nil }
        let safeName = course.name
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(safeName.isEmpty ? id : safeName).json")
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    // MARK: Écriture

    enum StoreError: LocalizedError {
        case noStorage
        case writeFailed(String)
        case invalidCourse([String])

        var errorDescription: String? {
            switch self {
            case .noStorage:
                LocalizationController.string("Stockage indisponible sur cet appareil.")
            case .writeFailed(let detail):
                LocalizationController.string("Échec de l'enregistrement : %@", detail)
            case .invalidCourse(let issues):
                LocalizationController.string("Répertoire incohérent : %@", issues.prefix(3).joined(separator: " · "))
            }
        }
    }

    /// Enregistre un cours. Il passe D'ABORD le même validateur d'intégrité que
    /// les cours embarqués : un graphe incohérent ne doit pas pouvoir entrer par
    /// la porte utilisateur alors qu'il est interdit par la porte du bundle.
    @discardableResult
    func save(_ course: OpeningCourse) throws -> OpeningCatalogEntry {
        let issues = OpeningCourseValidator.validate(course)
        guard issues.isEmpty else {
            throw StoreError.invalidCourse(issues.map(\.description))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(course) else {
            throw StoreError.writeFailed("encodage impossible")
        }

        if let context {
            let id = course.id
            var descriptor = FetchDescriptor<UserOpeningRecord>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            if let existing = try? context.fetch(descriptor).first {
                existing.name = course.name
                existing.payload = data
                existing.updatedAt = Date()
            } else {
                context.insert(UserOpeningRecord(id: course.id, name: course.name, payload: data))
            }
            do { try context.save() } catch {
                throw StoreError.writeFailed(error.localizedDescription)
            }
        } else {
            guard let url = fileURL(for: course.id) else { throw StoreError.noStorage }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                throw StoreError.writeFailed(error.localizedDescription)
            }
        }
        cache[course.id] = course
        let entry = OpeningCatalogEntry(course)
        catalog.removeAll { $0.id == course.id }
        catalog.append(entry)
        catalog.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return entry
    }

    /// Supprime le cours. La PROGRESSION reste : elle est indexée par position,
    /// pas par cours, et l'utilisateur qui réimporte le même répertoire (ou en
    /// rencontre les positions ailleurs) retrouve ce qu'il savait.
    func delete(id: String) {
        if let context {
            var descriptor = FetchDescriptor<UserOpeningRecord>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            if let record = try? context.fetch(descriptor).first {
                context.delete(record)
                try? context.save()
            }
        }
        // Le fichier hérité part aussi, sans quoi la migration le ferait
        // revenir au prochain lancement.
        if let url = fileURL(for: id) { try? FileManager.default.removeItem(at: url) }
        cache[id] = nil
        catalog.removeAll { $0.id == id }
    }

    /// Importe un fichier `.json` de cours reçu de l'extérieur (AirDrop,
    /// Messages, Fichiers). Ré-identifie le cours pour ne jamais écraser un
    /// import existant et pour garder le préfixe utilisateur, quel que soit ce
    /// que contenait le fichier.
    @discardableResult
    func importCourseFile(at url: URL) throws -> OpeningCatalogEntry {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let decoded = try OpeningCourseLoader.decodeCourse(from: data)
        return try save(rekeyed(decoded, to: Self.newIdentifier()))
    }

    /// Recopie un cours sous un nouvel identifiant (le graphe, lui, ne bouge
    /// pas : il est indexé par FEN).
    func rekeyed(_ course: OpeningCourse, to id: String, name: String? = nil) -> OpeningCourse {
        OpeningCourse(
            schemaVersion: course.schemaVersion, id: id, name: name ?? course.name,
            eco: course.eco, side: course.side, level: course.level, summary: course.summary,
            rootFEN: course.rootFEN, chapters: course.chapters, positions: course.positions
        )
    }

    private func decodeCourse(at url: URL) -> OpeningCourse? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? OpeningCourseLoader.decodeCourse(from: data)
    }
}
