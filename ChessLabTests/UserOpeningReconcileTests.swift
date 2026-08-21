import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Réconciliation des répertoires personnels quand DEUX enregistrements
/// portent le même identifiant de cours.
///
/// Le cas arrive pour de bon : deux appareils possédaient le même répertoire en
/// fichier avant la mise à jour, chacun l'a migré de son côté, et la synchro les
/// met en présence. CloudKit interdisant les contraintes d'unicité, c'est au
/// chargement qu'on tranche.
///
/// La règle testée ici tient en une phrase : **on ne supprime que ce qui est
/// vraiment identique**. Garder « le plus récent » et jeter l'autre est correct
/// pour un doublon de migration, mais détruirait le travail de quelqu'un si les
/// deux copies ont divergé.
@MainActor
struct UserOpeningReconcileTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: UserOpeningRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func payload(_ course: OpeningCourse) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return try encoder.encode(course)
    }

    // MARK: Vrai doublon

    @Test("Deux migrations du même fichier ne laissent qu'un répertoire")
    func identicalCopiesCollapseToOne() throws {
        let context = try makeContext()
        let course = OpeningGraphFixtures.linearCourse(
            id: "user-a", name: "Ma Scandinave", sans: ["e4", "d5"]
        )
        let data = try payload(course)
        context.insert(UserOpeningRecord(id: "user-a", name: course.name, payload: data))
        let newer = UserOpeningRecord(id: "user-a", name: course.name, payload: data)
        newer.updatedAt = Date().addingTimeInterval(60)
        context.insert(newer)

        let store = UserOpeningStore(directory: nil)
        store.attach(context: context)

        #expect(try context.fetch(FetchDescriptor<UserOpeningRecord>()).count == 1)
        #expect(store.catalog.count == 1)
        #expect(store.catalog.first?.name == "Ma Scandinave")
    }

    @Test("L'ordre des clés JSON ne fait pas passer deux copies pour divergentes")
    func keyOrderDoesNotCreateFalseDivergence() throws {
        // Deux appareils encodent le même cours : rien ne garantit le même
        // ordre de clés (un dictionnaire n'a pas d'ordre). L'empreinte doit
        // donc canonicaliser avant de comparer.
        let a = Data(#"{"id":"user-a","name":"X","positions":{"p":{"a":1,"b":2}}}"#.utf8)
        let b = Data(#"{"positions":{"p":{"b":2,"a":1}},"name":"X","id":"user-a"}"#.utf8)

        #expect(a != b, "les octets bruts diffèrent bien")
        #expect(UserOpeningStore.contentFingerprint(of: a)
                == UserOpeningStore.contentFingerprint(of: b),
                "mais le contenu est le même")
    }

    @Test("Un renommage ne dédouble pas le répertoire")
    func renamingDoesNotFork() throws {
        // Le nom n'est pas le travail : renommer sur un appareil doit fusionner,
        // pas créer un second répertoire (c'est le cas d'usage le plus courant).
        let course = OpeningGraphFixtures.linearCourse(id: "user-a", name: "Ancien", sans: ["e4", "d5"])
        let renamed = OpeningCourseEditor.rename(course, to: "Récent")

        #expect(UserOpeningStore.contentFingerprint(of: try payload(course))
                == UserOpeningStore.contentFingerprint(of: try payload(renamed)))
    }

    @Test("Ajouter une variante rend bien les copies divergentes")
    func addingAMoveMakesCopiesDiverge() throws {
        let course = OpeningGraphFixtures.linearCourse(id: "user-a", name: "R", sans: ["e4", "d5"])
        let extended = try OpeningCourseEditor.addMove(uci: "g1f3", from: course.rootFEN, in: course)

        #expect(UserOpeningStore.contentFingerprint(of: try payload(course))
                != UserOpeningStore.contentFingerprint(of: try payload(extended)))
    }

    // MARK: Divergence

    @Test("Deux éditions concurrentes sont toutes deux conservées")
    func divergentCopiesAreBothKept() throws {
        let context = try makeContext()
        let onA = OpeningGraphFixtures.linearCourse(
            id: "user-a", name: "Ma Scandinave", sans: ["e4", "d5"]
        )
        // L'autre appareil a poussé la ligne plus loin avant la synchro.
        let onB = OpeningGraphFixtures.linearCourse(
            id: "user-a", name: "Ma Scandinave", sans: ["e4", "d5", "exd5", "Qxd5"]
        )
        let older = UserOpeningRecord(id: "user-a", name: onA.name, payload: try payload(onA))
        older.updatedAt = Date().addingTimeInterval(-60)
        context.insert(older)
        context.insert(UserOpeningRecord(id: "user-a", name: onB.name, payload: try payload(onB)))

        let store = UserOpeningStore(directory: nil)
        store.attach(context: context)

        let records = try context.fetch(FetchDescriptor<UserOpeningRecord>())
        #expect(records.count == 2, "aucune des deux versions ne doit disparaître")
        #expect(Set(records.map(\.id)).count == 2, "et elles ne partagent plus d'identifiant")
        #expect(store.catalog.count == 2)

        // Le canonique garde son identifiant et son nom ; le divergent est
        // ré-identifié et signalé comme venant d'ailleurs.
        let canonical = try #require(records.first { $0.id == "user-a" })
        #expect(canonical.course?.positions.count == onB.positions.count,
                "le plus récent reste le canonique")
        let forked = try #require(records.first { $0.id != "user-a" })
        #expect(forked.name.contains("Ma Scandinave"))
        #expect(forked.course?.positions.count == onA.positions.count)
        #expect(forked.course?.id == forked.id, "le cours et son enregistrement portent le même id")
    }

    @Test("Une réconciliation ne se rejoue pas indéfiniment")
    func reconcilingIsStable() throws {
        let context = try makeContext()
        let onA = OpeningGraphFixtures.linearCourse(id: "user-a", name: "R", sans: ["e4"])
        let onB = OpeningGraphFixtures.linearCourse(id: "user-a", name: "R", sans: ["d4", "d5"])
        let older = UserOpeningRecord(id: "user-a", name: "R", payload: try payload(onA))
        older.updatedAt = Date().addingTimeInterval(-60)
        context.insert(older)
        context.insert(UserOpeningRecord(id: "user-a", name: "R", payload: try payload(onB)))

        let store = UserOpeningStore(directory: nil)
        store.attach(context: context)
        let afterFirst = try context.fetch(FetchDescriptor<UserOpeningRecord>()).map(\.id).sorted()

        store.reload()
        store.reload()
        let afterMore = try context.fetch(FetchDescriptor<UserOpeningRecord>()).map(\.id).sorted()

        #expect(afterFirst == afterMore, "le fork n'a lieu qu'une fois")
        #expect(afterMore.count == 2)
    }

    // MARK: Cas ordinaire

    @Test("Sans doublon, la réconciliation ne touche à rien")
    func untouchedWhenThereIsNoDuplicate() throws {
        let context = try makeContext()
        for (id, name) in [("user-a", "Un"), ("user-b", "Deux")] {
            let course = OpeningGraphFixtures.linearCourse(id: id, name: name, sans: ["e4"])
            context.insert(UserOpeningRecord(id: id, name: name, payload: try payload(course)))
        }

        let store = UserOpeningStore(directory: nil)
        store.attach(context: context)

        #expect(try context.fetch(FetchDescriptor<UserOpeningRecord>()).count == 2)
        #expect(store.catalog.map(\.name).sorted() == ["Deux", "Un"])
    }
}
