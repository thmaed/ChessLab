import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// La copie iCloud des collections importées : envoi, rendu, renommage,
/// suppression, et ce qu'un appareil fait de ce qu'il ne connaît pas encore.
///
/// Deux « appareils » se jouent avec UN conteneur et DEUX jeux de réglages
/// (`UserDefaults`) : les enregistrements synchronisés sont communs, la mémoire de
/// chaque appareil — qui enregistrement correspond à quelle collection — est à lui.
///
/// - important: UN SEUL `ModelContainer`, `.serialized` — voir ``PuzzleSessionDrawerTests``.
@MainActor
@Suite(.serialized)
struct PuzzleCollectionSyncTests {
    private static let container: ModelContainer = {
        try! ModelContainer(
            for: Puzzle.self, PuzzleProgress.self, WoodpeckerProgram.self, SyncedPuzzleCollection.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }()

    private func makeContext() throws -> ModelContext {
        let context = ModelContext(Self.container)
        try context.delete(model: Puzzle.self)
        try context.delete(model: SyncedPuzzleCollection.self)
        try context.save()
        return context
    }

    /// Les réglages d'un appareil : un jeu neuf par test et par appareil.
    private func device() -> UserDefaults {
        UserDefaults(suiteName: "PuzzleCollectionSyncTests-\(UUID().uuidString)")!
    }

    private func parsed(_ count: Int) -> PuzzleCollectionImporter.Result {
        PuzzleCollectionImporter.Result(
            puzzles: (0..<count).map { index in
                .init(
                    fen: "r5k1/5ppp/p7/8/8/4R3/5PPP/4R1K1 w - - 0 \(index + 1)", setupLAN: "a7a6",
                    solutionLANs: ["e3e8", "a8e8", "e1e8"], themeRaw: "checkmate", phaseRaw: "endgame"
                )
            },
            gameCount: count
        )
    }

    private func records(_ context: ModelContext) throws -> [SyncedPuzzleCollection] {
        try context.fetch(FetchDescriptor<SyncedPuzzleCollection>())
    }

    /// Un appareil qui n'a plus les puzzles (store neuf ou détruit) : les copies, elles, restent.
    private func wipePuzzles(_ context: ModelContext) throws {
        try context.delete(model: Puzzle.self)
        try context.save()
    }

    // MARK: Le PGN compressé

    @Test func packedPGNRoundTripsAndIsSmall() throws {
        let pgn = PuzzleCollectionExporter.pgn(
            collection: "A",
            entries: (0..<200).map { index in
                .init(
                    fen: "r5k1/5ppp/p7/8/8/4R3/5PPP/4R1K1 w - - 0 \(index + 1)", setupLAN: "a7a6",
                    solutionLANs: ["e3e8", "a8e8", "e1e8"]
                )
            }
        )
        let data = try #require(PuzzleCollectionSync.pack(pgn))
        #expect(PuzzleCollectionSync.unpack(data) == pgn)
        #expect(data.count < pgn.utf8.count / 3)
    }

    @Test func unpackRefusesWhatIsNotOurs() {
        #expect(PuzzleCollectionSync.unpack(Data("{}".utf8)) == nil)
        #expect(PuzzleCollectionSync.unpack(Data()) == nil)
    }

    // MARK: Envoyer

    @Test func backupWritesOneRecordAndRewritesItInPlace() throws {
        let context = try makeContext()
        let defaults = device()
        PuzzleCollectionStore.add(parsed(3), toCollection: "A", in: context)
        PuzzleCollectionSync.backup("A", in: context, defaults: defaults)
        let first = try records(context)
        #expect(first.count == 1)
        #expect(first.first?.name == "A")
        #expect(first.first?.puzzleCount == 3)

        PuzzleCollectionStore.add(parsed(5), toCollection: "A", in: context)
        PuzzleCollectionSync.backup("A", in: context, defaults: defaults)
        let second = try records(context)
        #expect(second.count == 1)
        #expect(second.first?.id == first.first?.id)
        #expect(second.first?.puzzleCount == 5)
    }

    @Test func backupOfAnEmptyCollectionWritesNothing() throws {
        let context = try makeContext()
        PuzzleCollectionSync.backup("Rien", in: context, defaults: device())
        #expect(try records(context).isEmpty)
    }

    @Test func backfillSendsExistingCollectionsOnlyOnce() throws {
        let context = try makeContext()
        let defaults = device()
        PuzzleCollectionStore.add(parsed(2), toCollection: "A", in: context)
        PuzzleCollectionStore.add(parsed(2), toCollection: "B", in: context)
        PuzzleCollectionSync.backfillIfNeeded(in: context, defaults: defaults)
        #expect(try records(context).map(\.name).sorted() == ["A", "B"])

        // Supprimée ailleurs depuis : ce n'est pas elle qui doit revenir.
        try context.delete(model: SyncedPuzzleCollection.self)
        try context.save()
        PuzzleCollectionSync.backfillIfNeeded(in: context, defaults: defaults)
        #expect(try records(context).isEmpty)
    }

    // MARK: Rendre

    @Test func restoreRebuildsACollectionFromItsCopy() async throws {
        let context = try makeContext()
        let deviceA = device(), deviceB = device()
        PuzzleCollectionStore.add(parsed(4), toCollection: "Fourchettes", in: context)
        PuzzleCollectionSync.backup("Fourchettes", in: context, defaults: deviceA)
        let original = PuzzleCollectionStore.puzzles(inCollection: "Fourchettes", in: context)
        let originalFENs = Set(original.compactMap(\.fen))

        try wipePuzzles(context)
        await PuzzleCollectionSync.restore(in: context, defaults: deviceB)

        let restored = PuzzleCollectionStore.puzzles(inCollection: "Fourchettes", in: context)
        #expect(restored.count == 4)
        #expect(Set(restored.compactMap(\.fen)) == originalFENs)
        #expect(restored.allSatisfy { $0.solutionLANs == ["e3e8", "a8e8", "e1e8"] })
        #expect(restored.allSatisfy { $0.setupLAN == "a7a6" })
        #expect(restored.allSatisfy { $0.sourceRaw == PuzzleSource.imported.rawValue })
    }

    @Test func restoringTwiceDoesNotDuplicate() async throws {
        let context = try makeContext()
        let deviceA = device(), deviceB = device()
        PuzzleCollectionStore.add(parsed(3), toCollection: "A", in: context)
        PuzzleCollectionSync.backup("A", in: context, defaults: deviceA)
        try wipePuzzles(context)

        await PuzzleCollectionSync.restore(in: context, defaults: deviceB)
        await PuzzleCollectionSync.restore(in: context, defaults: deviceB)
        #expect(PuzzleCollectionStore.puzzles(inCollection: "A", in: context).count == 3)
    }

    @Test func restoreAddsOnlyWhatIsMissingToAnExistingCollection() async throws {
        let context = try makeContext()
        let deviceA = device(), deviceB = device()
        PuzzleCollectionStore.add(parsed(5), toCollection: "A", in: context)
        PuzzleCollectionSync.backup("A", in: context, defaults: deviceA)
        // L'autre appareil n'en a que deux, importés à la main.
        try wipePuzzles(context)
        PuzzleCollectionStore.add(parsed(2), toCollection: "A", in: context)

        await PuzzleCollectionSync.restore(in: context, defaults: deviceB)
        #expect(PuzzleCollectionStore.puzzles(inCollection: "A", in: context).count == 5)
        #expect(try records(context).count == 1)
    }

    @Test func aStoreDestroyedAfterRestoreIsRestoredAgain() async throws {
        let context = try makeContext()
        let deviceA = device()
        PuzzleCollectionStore.add(parsed(3), toCollection: "A", in: context)
        PuzzleCollectionSync.backup("A", in: context, defaults: deviceA)
        // Rien n'a changé dans la copie, mais les puzzles ont disparu : même appareil.
        try wipePuzzles(context)
        await PuzzleCollectionSync.restore(in: context, defaults: deviceA)
        #expect(PuzzleCollectionStore.puzzles(inCollection: "A", in: context).count == 3)
    }

    // MARK: Renommer, supprimer

    @Test func aRenameDoneElsewhereIsFollowedNotDuplicated() async throws {
        let context = try makeContext()
        let deviceA = device(), deviceB = device()
        PuzzleCollectionStore.add(parsed(3), toCollection: "Ancien", in: context)
        PuzzleCollectionSync.backup("Ancien", in: context, defaults: deviceA)
        // B reçoit la collection…
        try wipePuzzles(context)
        await PuzzleCollectionSync.restore(in: context, defaults: deviceB)
        #expect(PuzzleCollectionStore.names(in: context) == ["Ancien"])

        // … puis A la renomme : la copie change de nom, avec une date plus récente.
        let record = try #require(try records(context).first)
        record.name = "Neuf"
        record.updatedAt = Date().addingTimeInterval(60)
        try context.save()

        await PuzzleCollectionSync.restore(in: context, defaults: deviceB)
        #expect(PuzzleCollectionStore.names(in: context) == ["Neuf"])
        #expect(PuzzleCollectionStore.puzzles(inCollection: "Neuf", in: context).count == 3)
    }

    @Test func renamingLocallyRenamesTheCopy() throws {
        let context = try makeContext()
        let defaults = device()
        PuzzleCollectionStore.add(parsed(2), toCollection: "Vieux", in: context)
        PuzzleCollectionSync.backup("Vieux", in: context, defaults: defaults)
        #expect(PuzzleCollectionStore.rename("Vieux", to: "Neuf", in: context))
        PuzzleCollectionSync.renamed(from: "Vieux", to: "Neuf", in: context, defaults: defaults)

        let all = try records(context)
        #expect(all.count == 1)
        #expect(all.first?.name == "Neuf")
    }

    @Test func deletingRemovesTheCopyAndNothingComesBack() async throws {
        let context = try makeContext()
        let defaults = device()
        PuzzleCollectionStore.add(parsed(2), toCollection: "A", in: context)
        PuzzleCollectionStore.add(parsed(2), toCollection: "B", in: context)
        PuzzleCollectionSync.backfillIfNeeded(in: context, defaults: defaults)

        PuzzleCollectionStore.delete("A", in: context)
        PuzzleCollectionSync.deleted("A", in: context, defaults: defaults)
        #expect(try records(context).map(\.name) == ["B"])

        await PuzzleCollectionSync.restore(in: context, defaults: defaults)
        #expect(PuzzleCollectionStore.names(in: context) == ["B"])
    }

    @Test func aDeviceThatKeepsADeletedCollectionDoesNotResurrectIt() async throws {
        let context = try makeContext()
        let deviceA = device(), deviceB = device()
        PuzzleCollectionStore.add(parsed(2), toCollection: "A", in: context)
        PuzzleCollectionSync.backup("A", in: context, defaults: deviceA)
        // B a déjà fait son envoi initial avant de voir la suppression.
        PuzzleCollectionSync.backfillIfNeeded(in: context, defaults: deviceB)

        PuzzleCollectionSync.deleted("A", in: context, defaults: deviceA)
        PuzzleCollectionSync.backfillIfNeeded(in: context, defaults: deviceB)
        #expect(try records(context).isEmpty)
        // B garde sa collection locale : on ne la lui retire pas.
        #expect(PuzzleCollectionStore.names(in: context) == ["A"])
    }
}
