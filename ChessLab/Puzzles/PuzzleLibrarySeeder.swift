import Foundation
import SwiftData

/// Avancement du préchargement : puzzles déjà enregistrés / à enregistrer. `total`
/// reste à zéro tant que le compte n'est pas connu — le bandeau montre alors une
/// attente sans pourcentage plutôt qu'une barre qui recule ou saute.
struct SeedingProgress: Equatable {
    var completed = 0
    var total = 0

    /// De 0 à 1, jamais au-delà ; `nil` tant que le total est inconnu.
    var fraction: Double? {
        total > 0 ? min(1, Double(max(0, completed)) / Double(total)) : nil
    }
}

/// État observable du préchargement de la bibliothèque de puzzles, pour
/// afficher un bandeau « Préparation… » pendant l'opération (premier
/// lancement).
@MainActor
@Observable
final class PuzzleSeedingState {
    static let shared = PuzzleSeedingState()
    private(set) var isSeeding = false
    private(set) var progress = SeedingProgress()
    private init() {}

    /// La part faite, de 0 à 1 ; `nil` tant que le total est inconnu.
    var fraction: Double? { progress.fraction }

    fileprivate func begin() { isSeeding = true; progress = SeedingProgress() }
    fileprivate func end() { isSeeding = false; progress = SeedingProgress() }
    fileprivate func report(completed: Int, of total: Int) {
        progress = SeedingProgress(completed: completed, total: total)
    }
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
    //
    // V5 (28/10/2026) : +24 841 puzzles (130 935 au total) pour combler les niveaux
    // extrêmes (sous 600, au-dessus de 2400) et les séquences de 4 coups ou plus —
    // voir `tools/puzzles-library/extend.py`. Les anciens identifiants sont tous
    // conservés : une installation V4 repasse ici UNE fois et n'ajoute que les nouveaux,
    // sans rien supprimer ni toucher à une progression.
    private static let seededKey = "lichessPuzzleLibrarySeededV5"

    /// Précharge la bibliothèque si nécessaire, **entièrement en tâche de
    /// fond** : le chargement du JSON embarqué (~18 Mo) comme les ~75 000
    /// insertions se font sur un `ModelContext` de fond dédié, par lots —
    /// jamais sur le fil principal (sinon plusieurs secondes de gel au
    /// premier lancement, pic mémoire, voire kill watchdog). Un état
    /// observable expose la progression pour le bandeau d'accueil.
    @MainActor
    static func seedIfNeeded(container: ModelContainer) {
        guard !PuzzleSeedingState.shared.isSeeding else { return }
        #if DEBUG
        // `-reseedPuzzles` : revoir le bandeau et sa barre sur un appareil déjà préchargé. Une
        // seule fois par lancement (l'accueil rappelle cette fonction à chaque apparition).
        let reseeds = CommandLine.arguments.contains("-reseedPuzzles") && !didDebugReseed
        if reseeds { didDebugReseed = true }
        #else
        let reseeds = false
        #endif
        let alreadySeeded = !reseeds && UserDefaults.standard.bool(forKey: seededKey)
        guard reseeds || needsSeeding(container: container, alreadySeeded: alreadySeeded) else { return }

        PuzzleSeedingState.shared.begin()
        Task.detached(priority: .utility) {
            #if DEBUG
            if reseeds { removeUntriedLibraryPuzzles(container: container) }
            #endif
            let didSeed = seedSynchronously(container: container)
            await MainActor.run {
                if didSeed {
                    UserDefaults.standard.set(true, forKey: seededKey)
                }
                PuzzleSeedingState.shared.end()
            }
        }
    }

    #if DEBUG
    @MainActor private static var didDebugReseed = false

    /// Vide la bibliothèque de ses puzzles JAMAIS tentés (ceux qu'un préchargement remet à
    /// l'identique) : toute progression reste, les puzzles tentés aussi.
    nonisolated private static func removeUntriedLibraryPuzzles(container: ModelContainer) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let library = (try? context.fetch(FetchDescriptor<Puzzle>(
            predicate: #Predicate<Puzzle> { $0.sourceRaw == "lichess" }
        ))) ?? []
        for puzzle in library where ((puzzle.successCount ?? 0) + (puzzle.failureCount ?? 0)) == 0 {
            context.delete(puzzle)
        }
        PersistenceLog.saveInBackground(context)
    }
    #endif

    /// Faut-il (re)précharger ? Vrai si :
    /// - la version courante n'a jamais été seedée (`alreadySeeded == false`,
    ///   ex. mise à niveau V3→V4), OU
    /// - le marqueur EST posé mais le store est **vide**.
    ///
    /// 🐛 Le second cas est le bug « Aucun puzzle » : la séparation des stores
    /// (Games / Puzzles) a recréé un store `Puzzle` VIDE, mais le marqueur
    /// `UserDefaults` d'un seeding antérieur restait à `true` — la garde
    /// court-circuitait alors le rechargement et la bibliothèque restait vide.
    /// On revalide donc le marqueur contre l'état RÉEL du store (un simple
    /// `COUNT`, indexé, négligeable même à ~75 000 lignes, et seulement quand
    /// le marqueur est posé).
    @MainActor
    static func needsSeeding(container: ModelContainer, alreadySeeded: Bool) -> Bool {
        guard alreadySeeded else { return true }
        let count = (try? ModelContext(container).fetchCount(FetchDescriptor<Puzzle>())) ?? 0
        return count == 0
    }

    /// Remonte l'avancement au fil principal, d'où le bandeau d'accueil le lit.
    private static func publishProgress(completed: Int, of total: Int) {
        Task { @MainActor in PuzzleSeedingState.shared.report(completed: completed, of: total) }
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
        let toInsert = entries.reduce(0) { $0 + (keptIDs.contains($1.id) ? 0 : 1) }
        Self.publishProgress(completed: 0, of: toInsert)
        var inserted = 0
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
            inserted += 1
            if insertedSinceSave >= 2_000 {
                PersistenceLog.saveInBackground(context)
                insertedSinceSave = 0
                // Annoncé APRÈS l'enregistrement : la barre ne dépasse jamais ce qui est écrit.
                Self.publishProgress(completed: inserted, of: toInsert)
                #if DEBUG
                // `-reseedPuzzles` : une seconde par lot, pour avoir le temps de regarder la barre.
                if CommandLine.arguments.contains("-reseedPuzzles") { Thread.sleep(forTimeInterval: 1) }
                #endif
            }
        }

        // 3. Rattrape `phaseRaw` sur tout puzzle d'avant ce champ.
        let missingPhaseDescriptor = FetchDescriptor<Puzzle>(
            predicate: #Predicate<Puzzle> { $0.phaseRaw == nil }
        )
        for puzzle in (try? context.fetch(missingPhaseDescriptor)) ?? [] {
            puzzle.phaseRaw = GamePhaseClassifier.classify(fen: puzzle.fen ?? "").rawValue
        }

        PersistenceLog.saveInBackground(context)
        return true
    }
}
