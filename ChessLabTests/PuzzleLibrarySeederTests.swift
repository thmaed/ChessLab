import Foundation
import SwiftData
import Testing
@testable import ChessLab

struct PuzzleLibrarySeederTests {

    @Test func bundledLichessPuzzlesAreNotEmpty() {
        // Sanity check du fichier réellement bundlé : s'il ne se charge
        // pas dans la cible de test, ajouter lichess_puzzles.json à la
        // cible ChessLabTests dans Xcode (même remarque que pour
        // eco_openings.json/opening_book.json).
        #expect(!LichessPuzzleLoader.standard.isEmpty)
    }

    @Test func bundledLichessPuzzlesHaveExpectedFields() throws {
        let sample = try #require(LichessPuzzleLoader.standard.first)
        #expect(!sample.fen.isEmpty)
        #expect(!sample.solutionLANs.isEmpty)
        #expect(!sample.theme.isEmpty)
        #expect(sample.rating > 0)
        #expect(sample.phase != nil)
    }

    /// La demande produit : au moins ~4 000 puzzles par combinaison
    /// (palier de difficulté × phase de partie) — c'est la raison d'être
    /// du rééchantillonnage V3 (la V2 n'avait que 86-210 ouvertures par
    /// palier). Tolérance à 3 800 : certaines cellules rares peuvent
    /// rester légèrement sous la cible selon la base source.
    @Test func bundledLibraryCoversAllDifficultyPhaseCells() {
        var counts: [String: Int] = [:]
        for entry in LichessPuzzleLoader.standard {
            let tier = DifficultyTier.tier(forRating: entry.rating)?.rawValue ?? "?"
            counts["\(tier)/\(entry.phase ?? "?")", default: 0] += 1
        }
        for tier in DifficultyTier.allCases {
            for phase in GamePhase.allCases {
                let count = counts["\(tier.rawValue)/\(phase.rawValue)"] ?? 0
                #expect(count >= 3_800, "cellule \(tier.rawValue)/\(phase.rawValue) : \(count) puzzles")
            }
        }
    }

    @MainActor
    @Test func seedInsertsBundledPuzzlesIntoEmptyContext() throws {
        // Le marqueur "déjà semé" vit dans `UserDefaults.standard`, qui
        // persiste entre les exécutions de test sur le même simulateur —
        // réinitialisé ici pour ne pas dépendre de l'ordre d'exécution.
        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV4")

        let schema = Schema([Puzzle.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

        PuzzleLibrarySeeder.seedSynchronously(container: container)

        let items = try ModelContext(container).fetch(FetchDescriptor<Puzzle>())
        #expect(items.count == LichessPuzzleLoader.standard.count)
        #expect(items.allSatisfy { $0.source == .lichess })
        #expect(items.allSatisfy { $0.rating != nil })
        #expect(items.allSatisfy { $0.externalID != nil })
        #expect(items.allSatisfy { $0.phaseRaw != nil })

        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV4")
    }

    @MainActor
    @Test func seedingTwiceDoesNotDuplicatePuzzles() throws {
        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV4")

        let schema = Schema([Puzzle.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

        PuzzleLibrarySeeder.seedSynchronously(container: container)
        // Simule un second appel avant que le marqueur `UserDefaults`
        // n'ait pu faire effet (ex. deux `.onAppear` rapprochés) : réinit
        // manuellement pour forcer le passage du garde-fou et vérifier
        // que la déduplication par `externalID` protège quand même.
        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV4")
        PuzzleLibrarySeeder.seedSynchronously(container: container)

        let items = try ModelContext(container).fetch(FetchDescriptor<Puzzle>())
        #expect(items.count == LichessPuzzleLoader.standard.count)
        let externalIDs = items.compactMap(\.externalID)
        #expect(Set(externalIDs).count == externalIDs.count)

        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV4")
    }

    /// Migration V2 → V3 : un puzzle bibliothèque déjà travaillé
    /// (progression SM-2) est conservé même s'il ne fait plus partie du
    /// nouvel échantillon ; un puzzle jamais tenté hors échantillon est
    /// remplacé ; `phaseRaw` est rattrapé partout.
    @MainActor
    @Test func reseedingKeepsAttemptedPuzzlesAndBackfillsPhase() throws {
        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV4")

        let schema = Schema([Puzzle.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        // Deux "anciens" puzzles bibliothèque hors nouvel échantillon :
        // un déjà travaillé, un jamais tenté.
        let attempted = Puzzle()
        attempted.fen = "8/8/8/8/8/1k6/2q5/K7 w - - 0 50"
        attempted.sourceRaw = PuzzleSource.lichess.rawValue
        attempted.externalID = "OLDatt"
        attempted.successCount = 3
        context.insert(attempted)

        let untouched = Puzzle()
        untouched.fen = "8/8/8/8/8/1k6/2q5/K7 w - - 0 50"
        untouched.sourceRaw = PuzzleSource.lichess.rawValue
        untouched.externalID = "OLDunt"
        context.insert(untouched)
        try context.save()

        PuzzleLibrarySeeder.seedSynchronously(container: container)

        let items = try ModelContext(container).fetch(FetchDescriptor<Puzzle>())
        let ids = Set(items.compactMap(\.externalID))
        #expect(ids.contains("OLDatt"))
        #expect(!ids.contains("OLDunt"))
        #expect(items.count == LichessPuzzleLoader.standard.count + 1)
        #expect(items.allSatisfy { $0.phaseRaw != nil })

        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV4")
    }
}
