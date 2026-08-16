import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Les répertoires personnels vivent désormais en base synchronisée.
///
/// Le test qui porte les autres est `legacyFilesAreMigrated` : des
/// utilisateurs ont déjà des répertoires en fichiers, et une migration ratée
/// les leur ferait disparaître. Les fichiers ne sont d'ailleurs pas effacés —
/// effacer les données de quelqu'un au premier lancement d'une mise à jour, sur
/// la foi d'une migration qu'on n'a pas vue réussir, est le pire moment pour se
/// tromper.
@MainActor
struct UserOpeningSyncTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: UserOpeningRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func sampleCourse(id: String, name: String) -> OpeningCourse {
        OpeningGraphFixtures.linearCourse(id: id, name: name, sans: ["e4", "e5", "Nf3"])
    }

    @Test func savingStoresTheCourseInTheDatabase() throws {
        let context = try makeContext()
        let store = UserOpeningStore(directory: nil)
        store.attach(context: context)

        let course = sampleCourse(id: "user-a", name: "Ma Scandinave")
        _ = try store.save(course)

        let records = try context.fetch(FetchDescriptor<UserOpeningRecord>())
        #expect(records.count == 1)
        #expect(records.first?.name == "Ma Scandinave")
        // Et le cours se relit intégralement depuis le blob.
        #expect(records.first?.course?.positions.count == course.positions.count)
    }

    @Test func saveThenReadBackThroughTheStore() throws {
        let store = UserOpeningStore(directory: nil)
        store.attach(context: try makeContext())
        _ = try store.save(sampleCourse(id: "user-b", name: "Test"))

        #expect(store.catalog.contains { $0.id == "user-b" })
        #expect(store.course(id: "user-b") != nil)
    }

    @Test func deletingRemovesItEverywhere() throws {
        let context = try makeContext()
        let store = UserOpeningStore(directory: nil)
        store.attach(context: context)
        _ = try store.save(sampleCourse(id: "user-c", name: "À supprimer"))

        store.delete(id: "user-c")

        #expect(try context.fetch(FetchDescriptor<UserOpeningRecord>()).isEmpty)
        #expect(store.course(id: "user-c") == nil)
        #expect(!store.catalog.contains { $0.id == "user-c" })
    }

    /// Réenregistrer le même cours le MET À JOUR au lieu d'en créer un second —
    /// c'est ce que fait l'éditeur d'arbre à chaque geste.
    @Test func savingTwiceUpdatesRatherThanDuplicates() throws {
        let context = try makeContext()
        let store = UserOpeningStore(directory: nil)
        store.attach(context: context)

        _ = try store.save(sampleCourse(id: "user-d", name: "Avant"))
        _ = try store.save(
            OpeningCourseEditor.rename(sampleCourse(id: "user-d", name: "Avant"), to: "Après")
        )

        let records = try context.fetch(FetchDescriptor<UserOpeningRecord>())
        #expect(records.count == 1)
        #expect(records.first?.name == "Après")
    }

    /// LE test de ce lot : un répertoire supprimé sur un AUTRE appareil ne
    /// doit pas revenir d'entre les morts au lancement suivant.
    ///
    /// La suppression se propage bien par CloudKit ; c'est le fichier local,
    /// resté là comme sauvegarde, qui la défaisait — la migration le
    /// réimportait, et le répertoire se resynchronisait vers l'appareil où on
    /// venait de l'effacer.
    @Test func aRepertoireDeletedElsewhereDoesNotComeBack() throws {
        UserDefaults.standard.removeObject(forKey: "userOpenings.migratedToDatabase")
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "userOpenings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let course = sampleCourse(id: "user-ghost", name: "Fantôme")
        try JSONEncoder().encode(course).write(to: directory.appending(path: "user-ghost.json"))

        let context = try makeContext()
        let store = UserOpeningStore(directory: directory)
        store.attach(context: context)
        #expect(store.course(id: "user-ghost") != nil, "la migration doit d'abord l'importer")

        // Suppression venue d'un autre appareil : l'enregistrement disparaît
        // de la base, mais le fichier local reste (on ne l'a pas effacé ici).
        for record in try context.fetch(FetchDescriptor<UserOpeningRecord>()) {
            context.delete(record)
        }
        try context.save()

        // Lancement suivant.
        store.attach(context: context)
        #expect(try context.fetch(FetchDescriptor<UserOpeningRecord>()).isEmpty,
                "le fichier local ne doit pas ressusciter un répertoire supprimé ailleurs")
        #expect(store.course(id: "user-ghost") == nil)
    }

    /// Deux appareils qui possédaient le même répertoire en fichier l'ont
    /// chacun migré : la base contient deux entrées de même identifiant, et le
    /// répertoire apparaîtrait en double. La plus récente est gardée.
    @Test func duplicateRecordsAreCollapsed() throws {
        let context = try makeContext()
        let store = UserOpeningStore(directory: nil)
        let course = sampleCourse(id: "user-dup", name: "Ancien")
        let data = try JSONEncoder().encode(course)

        context.insert(UserOpeningRecord(
            id: "user-dup", name: "Ancien", payload: data,
            updatedAt: Date(timeIntervalSince1970: 1_000)
        ))
        let newer = try JSONEncoder().encode(
            OpeningCourseEditor.rename(course, to: "Récent")
        )
        context.insert(UserOpeningRecord(
            id: "user-dup", name: "Récent", payload: newer,
            updatedAt: Date(timeIntervalSince1970: 2_000)
        ))
        try context.save()

        store.attach(context: context)

        #expect(store.catalog.filter { $0.id == "user-dup" }.count == 1)
        #expect(store.catalog.first { $0.id == "user-dup" }?.name == "Récent")
        #expect(try context.fetch(FetchDescriptor<UserOpeningRecord>()).count == 1)
    }

    /// LE test : les répertoires laissés en fichiers par les versions
    /// précédentes doivent entrer en base au premier lancement.
    @Test func legacyFilesAreMigrated() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "userOpenings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let course = sampleCourse(id: "user-legacy", name: "Ancien répertoire")
        let data = try JSONEncoder().encode(course)
        try data.write(to: directory.appending(path: "user-legacy.json"))

        UserDefaults.standard.removeObject(forKey: "userOpenings.migratedToDatabase")
        let context = try makeContext()
        let store = UserOpeningStore(directory: directory)
        store.attach(context: context)

        #expect(try context.fetch(FetchDescriptor<UserOpeningRecord>()).count == 1)
        #expect(store.course(id: "user-legacy") != nil)
        // Le fichier reste : c'est une sauvegarde, pas un doublon — la
        // migration l'ignore au second lancement puisque l'entrée existe.
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "user-legacy.json").path))

        store.attach(context: context)
        #expect(try context.fetch(FetchDescriptor<UserOpeningRecord>()).count == 1)
    }
}
