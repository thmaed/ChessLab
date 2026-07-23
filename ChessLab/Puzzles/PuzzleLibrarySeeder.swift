import Foundation
import SwiftData

/// État observable du préchargement de la bibliothèque de puzzles, pour
/// afficher un bandeau « Préparation… » pendant l'opération (premier
/// lancement).
@MainActor
@Observable
final class PuzzleSeedingState {
    static let shared = PuzzleSeedingState()
    private(set) var isSeeding = false
    private init() {}

    fileprivate func begin() { isSeeding = true }
    fileprivate func end() { isSeeding = false }
}

/// Précharge la bibliothèque de puzzles Lichess embarquée dans la base
/// locale.
enum PuzzleLibrarySeeder {
    // V4 : bibliothèque enrichie en puzzles d'Ouverture — l'échantillon
    // V2 (49 473) n'en comptait presque aucun (618 au total, 86-210 par
    // palier), un défaut structurel de l'échantillonnage uniforme par
    // thème/rating plutôt qu'un manque réel côté Lichess (re-scan de la
    // base brute complète : ~80 000 puzzles Ouverture y sont disponibles
    // sur 6 millions). V4 en ajoute 25 450 (jusqu'à 3 000/thème en
    // Débutant, 800/thème dans les autres paliers, selon disponibilité —
    // certains thèmes rares comme skewer/sacrifice n'atteignent pas le
    // quota même dans la base complète), plus quelques centaines de
    // Milieu/Finale en Débutant pour garantir ≥ 3 000 puzzles par thème
    // toutes phases confondues sur ce palier. Une installation V1/V2/V3
    // doit repasser une fois ici : remplacement des puzzles bibliothèque
    // jamais tentés + rattrapage du champ `phaseRaw` (nouveau) sur tout
    // ce qui reste.
    private static let seededKey = "lichessPuzzleLibrarySeededV4"

    /// Précharge la bibliothèque si nécessaire, **entièrement en tâche de
    /// fond** : le chargement du JSON embarqué (~18 Mo) comme les ~75 000
    /// insertions se font sur un `ModelContext` de fond dédié, par lots —
    /// jamais sur le fil principal (sinon plusieurs secondes de gel au
    /// premier lancement, pic mémoire, voire kill watchdog). Un état
    /// observable expose la progression pour le bandeau d'accueil.
    @MainActor
    static func seedIfNeeded(container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        guard !PuzzleSeedingState.shared.isSeeding else { return }

        PuzzleSeedingState.shared.begin()
        Task.detached(priority: .utility) {
            let didSeed = seedSynchronously(container: container)
            await MainActor.run {
                if didSeed {
                    UserDefaults.standard.set(true, forKey: seededKey)
                }
                PuzzleSeedingState.shared.end()
            }
        }
    }

    /// Effectue le préchargement sur un contexte dédié au `container` donné
    /// (de fond en usage réel). Renvoie `false` si la bibliothèque embarquée
    /// est absente (le marqueur n'est alors pas posé — on retentera au
    /// prochain lancement). Exposé pour les tests (appel synchrone).
    @discardableResult
    static func seedSynchronously(container: ModelContainer) -> Bool {
        let entries = LichessPuzzleLoader.standard
        guard !entries.isEmpty else { return false }

        let context = ModelContext(container)
        context.autosaveEnabled = false
        let newIDs = Set(entries.map(\.id))

        // 1. Retire les puzzles bibliothèque absents du nouvel échantillon
        // ET jamais tentés — aucune progression SM-2 perdue.
        let lichessDescriptor = FetchDescriptor<Puzzle>(
            predicate: #Predicate<Puzzle> { $0.sourceRaw == "lichess" }
        )
        let existingLibrary = (try? context.fetch(lichessDescriptor)) ?? []
        for puzzle in existingLibrary {
            let attempts = (puzzle.successCount ?? 0) + (puzzle.failureCount ?? 0)
            if attempts == 0, !newIDs.contains(puzzle.externalID ?? "") {
                context.delete(puzzle)
            }
        }

        // 2. Insère les nouveaux, dédoublonnés par identifiant Lichess, par
        // lots de 2 000 (save intermédiaire) pour borner le pic mémoire.
        let keptIDs = Set(
            existingLibrary
                .filter { ((($0.successCount ?? 0) + ($0.failureCount ?? 0)) > 0) || newIDs.contains($0.externalID ?? "") }
                .compactMap(\.externalID)
        )
        var insertedSinceSave = 0
        for entry in entries where !keptIDs.contains(entry.id) {
            let puzzle = Puzzle()
            puzzle.fen = entry.fen
            puzzle.solutionLANs = entry.solutionLANs
            puzzle.themeRaw = entry.theme
            puzzle.phaseRaw = entry.phase ?? GamePhaseClassifier.classify(fen: entry.fen).rawValue
            puzzle.rating = entry.rating
            puzzle.sourceRaw = PuzzleSource.lichess.rawValue
            puzzle.externalID = entry.id
            context.insert(puzzle)

            insertedSinceSave += 1
            if insertedSinceSave >= 2_000 {
                try? context.save()
                insertedSinceSave = 0
            }
        }

        // 3. Rattrape `phaseRaw` sur tout puzzle d'avant ce champ.
        let missingPhaseDescriptor = FetchDescriptor<Puzzle>(
            predicate: #Predicate<Puzzle> { $0.phaseRaw == nil }
        )
        for puzzle in (try? context.fetch(missingPhaseDescriptor)) ?? [] {
            puzzle.phaseRaw = GamePhaseClassifier.classify(fen: puzzle.fen ?? "").rawValue
        }

        try? context.save()
        return true
    }
}
