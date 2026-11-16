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

    /// La bibliothèque embarquée reste équilibrée : une régénération qui viderait une
    /// cellule (tranche de cote × thème) ou casserait la forme d'une solution se voit ici.
    @Test func bundledLibraryCoversEveryThemeAtEveryMainLevel() {
        let entries = LichessPuzzleLoader.standard
        #expect(entries.count >= 130_000)
        #expect(Set(entries.map(\.id)).count == entries.count)
        // Solution = coup du joueur, puis (riposte, coup)* : toujours un nombre impair.
        #expect(entries.allSatisfy { $0.solutionLANs.count % 2 == 1 })

        var cells: [String: Int] = [:]
        for entry in entries { cells["\((entry.rating / 200) * 200)|\(entry.theme)", default: 0] += 1 }
        let themes = Set(entries.map(\.theme))
        #expect(themes.count == 8)
        for bucket in stride(from: 800, through: 2200, by: 200) {
            for theme in themes {
                #expect((cells["\(bucket)|\(theme)"] ?? 0) >= 500, "tranche \(bucket), thème \(theme)")
            }
        }
        // Les séquences de 4 coups du joueur ou plus restent représentées.
        #expect(entries.filter { $0.solutionLANs.count >= 7 }.count >= 10_000)
    }

    @Test func seedingProgressIsUnknownUntilTheTotalIsKnownThenBounded() {
        #expect(SeedingProgress().fraction == nil)
        #expect(SeedingProgress(completed: 0, total: 0).fraction == nil)
        #expect(SeedingProgress(completed: 0, total: 24_841).fraction == 0)
        #expect(SeedingProgress(completed: 2_000, total: 4_000).fraction == 0.5)
        // Jamais au-delà de 100 % ni en dessous de 0, même si le compte déborde.
        #expect(SeedingProgress(completed: 5_000, total: 4_000).fraction == 1)
        #expect(SeedingProgress(completed: -3, total: 4_000).fraction == 0)
    }

    /// La relecture d'une bibliothèque existante compte aussi (retour du 16/11/2026 : roulette plus de la
    /// moitié du temps) ; une insertion pèse quatre relectures (mesuré sur iPad Pro 11").
    @Test func seedingWorkCountsTheRereadAndWeighsInserts() {
        let upgrade = SeedingWork(toScan: 106_094, toInsert: 24_841)
        #expect(upgrade.total == 106_094 + 24_841 * SeedingWork.insertCost)
        #expect(upgrade.done(scanned: 0, inserted: 0) == 0)
        let afterReread = Double(upgrade.done(scanned: 106_094, inserted: 0)) / Double(upgrade.total)
        // Mise à jour V4 → V5 : la relecture fait à peu près la moitié du chemin — c'était la moitié sans barre.
        #expect(afterReread > 0.4 && afterReread < 0.6)
        #expect(upgrade.done(scanned: 106_094, inserted: 24_841) == upgrade.total)
        // Bornée, et jamais un total nul (la barre a un sens dès la première seconde).
        #expect(upgrade.done(scanned: 999_999, inserted: 999_999) == upgrade.total)
        #expect(SeedingWork(toScan: 0, toInsert: 0).total == 1)
        // Installation neuve : rien à relire, tout est insertion.
        #expect(SeedingWork(toScan: 0, toInsert: 130_935).total == 130_935 * SeedingWork.insertCost)
    }

    /// La relecture par tranches de classement : chaque puzzle Lichess dans UNE tranche et une seule — bornes,
    /// extrêmes et puzzles sans classement compris ; les autres sources n'y entrent pas.
    @MainActor
    @Test func ratingSlicesCoverEveryLichessPuzzleExactlyOnce() throws {
        let container = try ModelContainer(for: Schema([Puzzle.self]),
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let entries = LichessPuzzleLoader.standard
        let slices = PuzzleLibrarySeeder.ratingSlices(of: entries)
        let sorted = entries.map(\.rating).sorted()
        // Des classements piégeux : chaque borne de tranche, ses voisins, les extrêmes, aucun.
        var ratings: [Int?] = [nil, Int.min, Int.max, 0, -5, 4_000]
        for index in 1..<12 {
            let bound = sorted[index * sorted.count / 12]
            ratings += [bound - 1, bound, bound + 1]
        }
        for (index, rating) in ratings.enumerated() {
            let puzzle = Puzzle()
            puzzle.sourceRaw = "lichess"
            puzzle.externalID = "test-\(index)"
            puzzle.rating = rating
            context.insert(puzzle)
        }
        let other = Puzzle()
        other.sourceRaw = "collection"
        other.rating = 1500
        context.insert(other)
        try context.save()

        let perSlice = try slices.map { try context.fetchCount(FetchDescriptor<Puzzle>(predicate: $0)) }
        #expect(perSlice.reduce(0, +) == ratings.count, "chaque puzzle Lichess compté une fois : \(perSlice)")
        var seen = Set<String>()
        for slice in slices {
            for puzzle in try context.fetch(FetchDescriptor<Puzzle>(predicate: slice)) {
                #expect(seen.insert(puzzle.externalID ?? "?").inserted, "\(puzzle.externalID ?? "?") dans deux tranches")
            }
        }
        #expect(seen.count == ratings.count)
    }

    @MainActor
    @Test func theSeedingBarNeverMovesBackwards() {
        let state = PuzzleSeedingState.shared
        state.report(completed: 60, of: 100)
        // Le total se précise en route : la part affichée ne recule pas pour autant.
        state.report(completed: 60, of: 200)
        #expect(state.fraction == 0.6)
        state.report(completed: 150, of: 200)
        #expect(state.fraction == 0.75)
    }

    @MainActor
    @Test func seedInsertsBundledPuzzlesIntoEmptyContext() throws {
        // Le marqueur "déjà semé" vit dans `UserDefaults.standard`, qui
        // persiste entre les exécutions de test sur le même simulateur —
        // réinitialisé ici pour ne pas dépendre de l'ordre d'exécution.
        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV5")

        let schema = Schema([Puzzle.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))

        PuzzleLibrarySeeder.seedSynchronously(container: container)

        let items = try ModelContext(container).fetch(FetchDescriptor<Puzzle>())
        #expect(items.count == LichessPuzzleLoader.standard.count)
        #expect(items.allSatisfy { $0.source == .lichess })
        #expect(items.allSatisfy { $0.rating != nil })
        #expect(items.allSatisfy { $0.externalID != nil })
        #expect(items.allSatisfy { $0.phaseRaw != nil })

        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV5")
    }

    /// 🐛 Régression « Aucun puzzle » : après la séparation des stores
    /// (Games / Puzzles), le marqueur "déjà semé" restait posé alors que le
    /// nouveau store `Puzzle` était VIDE — la garde court-circuitait le
    /// rechargement. ``needsSeeding`` doit revalider le marqueur contre l'état
    /// réel du store.
    @MainActor
    @Test func reSeedsWhenMarkerIsSetButStoreIsEmpty() throws {
        let schema = Schema([Puzzle.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))

        // Marqueur posé (seeding antérieur) MAIS store VIDE → re-seeding requis.
        #expect(PuzzleLibrarySeeder.needsSeeding(container: container, alreadySeeded: true))

        // Store non vide → plus besoin, même marqueur posé.
        let context = ModelContext(container)
        let puzzle = Puzzle()
        puzzle.externalID = "abc"
        context.insert(puzzle)
        try context.save()
        #expect(!PuzzleLibrarySeeder.needsSeeding(container: container, alreadySeeded: true))

        // Sans marqueur : on seede toujours (mise à niveau de version V3→V4).
        #expect(PuzzleLibrarySeeder.needsSeeding(container: container, alreadySeeded: false))
    }

    @MainActor
    @Test func seedingTwiceDoesNotDuplicatePuzzles() throws {
        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV5")

        let schema = Schema([Puzzle.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))

        PuzzleLibrarySeeder.seedSynchronously(container: container)
        // Simule un second appel avant que le marqueur `UserDefaults`
        // n'ait pu faire effet (ex. deux `.onAppear` rapprochés) : réinit
        // manuellement pour forcer le passage du garde-fou et vérifier
        // que la déduplication par `externalID` protège quand même.
        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV5")
        PuzzleLibrarySeeder.seedSynchronously(container: container)

        let items = try ModelContext(container).fetch(FetchDescriptor<Puzzle>())
        #expect(items.count == LichessPuzzleLoader.standard.count)
        let externalIDs = items.compactMap(\.externalID)
        #expect(Set(externalIDs).count == externalIDs.count)

        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV5")
    }

    /// Migration V2 → V3 : un puzzle bibliothèque déjà travaillé
    /// (progression SM-2) est conservé même s'il ne fait plus partie du
    /// nouvel échantillon ; un puzzle jamais tenté hors échantillon est
    /// remplacé ; `phaseRaw` est rattrapé partout.
    @MainActor
    @Test func reseedingKeepsAttemptedPuzzlesAndBackfillsPhase() throws {
        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV5")

        let schema = Schema([Puzzle.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
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

        UserDefaults.standard.removeObject(forKey: "lichessPuzzleLibrarySeededV5")
    }
}
