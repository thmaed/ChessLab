import Foundation
import Testing
@testable import ChessLab

/// Stockage des répertoires personnels : écriture, relecture, partage,
/// suppression — sur un dossier temporaire, jamais celui de l'app.
///
/// L'aller-retour compte plus que le reste : le fichier écrit ici est
/// EXACTEMENT ce que `ShareLink` envoie à un ami et ce que son app relira. S'il
/// ne revient pas identique, le partage est cassé sans que rien ne le signale.
@MainActor
struct UserOpeningStoreTests {

    private func makeStore() throws -> (UserOpeningStore, URL) {
        let directory = URL.temporaryDirectory.appending(path: "UserOpeningsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (UserOpeningStore(directory: directory), directory)
    }

    private func sampleCourse(id: String = UserOpeningStore.newIdentifier()) throws -> OpeningCourse {
        try OpeningPGNImporter.course(
            fromPGN: "1. e4 e5 (1... c5 2. Nf3) 2. Nf3 Nc6 *",
            name: "Mon répertoire", side: .white, id: id
        ).course
    }

    @Test func savedCourseIsListedAndReloadable() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let course = try sampleCourse()
        let entry = try store.save(course)

        #expect(entry.id == course.id)
        #expect(entry.positionCount == course.positions.count)
        #expect(store.catalog.map(\.id) == [course.id])
        #expect(store.course(id: course.id)?.positions.count == course.positions.count)

        // Relecture À FROID : c'est le chemin du prochain lancement de l'app.
        let reopened = UserOpeningStore(directory: directory)
        #expect(reopened.catalog.map(\.id) == [course.id])
        #expect(reopened.course(id: course.id)?.name == "Mon répertoire")
    }

    /// Aller-retour complet : exporter le fichier, le relire comme s'il venait
    /// d'un ami, retrouver le même graphe.
    @Test func exportedFileCanBeImportedBack() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let course = try sampleCourse()
        try store.save(course)
        let shared = try #require(store.fileURL(for: course.id))
        #expect(FileManager.default.fileExists(atPath: shared.path))

        let (other, otherDirectory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: otherDirectory) }
        let received = try other.importCourseFile(at: shared)

        // Nouvel identifiant (on n'écrase jamais un import existant), même
        // graphe : le contenu voyage, l'identité est locale.
        #expect(received.id != course.id)
        #expect(UserOpeningStore.isUserCourse(id: received.id))
        let reimported = try #require(other.course(id: received.id))
        #expect(reimported.positions == course.positions)
        #expect(reimported.name == course.name)
    }

    /// Un graphe incohérent ne doit pas pouvoir entrer par la porte utilisateur
    /// alors qu'il est refusé par celle du bundle.
    @Test func invalidCourseIsRefused() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let root = OpeningFENKey.key(for: .standard)
        let broken = OpeningCourse(
            id: UserOpeningStore.newIdentifier(), name: "Cassé", rootFEN: root,
            positions: [root: PositionNode(fen: root, moves: [
                MoveEdge(san: "e4", uci: "e2e4", toFEN: "position-inexistante")
            ])]
        )
        #expect(throws: (any Error).self) { try store.save(broken) }
        #expect(store.catalog.isEmpty)
    }

    @Test func deletionRemovesFileAndEntry() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let course = try sampleCourse()
        try store.save(course)
        let url = try #require(store.fileURL(for: course.id))

        store.delete(id: course.id)
        #expect(store.catalog.isEmpty)
        #expect(store.course(id: course.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    /// Les identifiants utilisateur sont reconnaissables et ne peuvent pas
    /// entrer en collision avec les 58 cours embarqués.
    @Test func identifiersAreNamespaced() {
        let id = UserOpeningStore.newIdentifier()
        #expect(UserOpeningStore.isUserCourse(id: id))
        #expect(!UserOpeningStore.isUserCourse(id: "scandinavian"))
        #expect(OpeningCourseLoader.catalog.allSatisfy { !UserOpeningStore.isUserCourse(id: $0.id) })
    }
}
