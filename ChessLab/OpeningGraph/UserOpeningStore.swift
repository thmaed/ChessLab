import Foundation
import Observation

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

    init(directory: URL? = UserOpeningStore.defaultDirectory()) {
        self.directory = directory
        reload()
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

    /// URL du fichier d'un cours — c'est elle qu'on passe à `ShareLink`.
    func fileURL(for id: String) -> URL? {
        guard Self.isUserCourse(id: id), let directory else { return nil }
        return directory.appending(path: "\(id).json")
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
        guard let url = fileURL(for: course.id) else { throw StoreError.noStorage }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            try encoder.encode(course).write(to: url, options: .atomic)
        } catch {
            throw StoreError.writeFailed(error.localizedDescription)
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
        guard let url = fileURL(for: id) else { return }
        try? FileManager.default.removeItem(at: url)
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
