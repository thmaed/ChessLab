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

/// Le travail du préchargement en UNITÉS de durée comparable, pour une barre qui avance du début à la fin.
///
/// Retour du 16/11/2026 : la roulette tournait plus de la moitié du temps avant que la barre ne parte. La
/// relecture de la bibliothèque déjà en base (mise à jour d'une version antérieure) n'était pas comptée — et
/// c'est elle qui durait. Mesuré sur un iPad Pro 11" (A12X) : relire un puzzle ≈ 0,08 ms (par tranches),
/// en insérer un ≈ 0,3 ms. Une insertion vaut donc à peu près quatre relectures.
struct SeedingWork: Equatable {
    static let insertCost = 4
    var toScan: Int
    var toInsert: Int

    var total: Int { max(1, toScan + toInsert * Self.insertCost) }

    func done(scanned: Int, inserted: Int) -> Int {
        min(max(0, scanned), toScan) + min(max(0, inserted), toInsert) * Self.insertCost
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

    /// La barre part à 0 % DÈS le début (plus d'attente sans chiffre).
    fileprivate func begin() { isSeeding = true; progress = SeedingProgress(completed: 0, total: 1) }
    fileprivate func end() { isSeeding = false; progress = SeedingProgress() }
    /// Une barre ne recule jamais : le total peut se préciser en route (le compte exact des puzzles à
    /// insérer n'est connu qu'après la relecture), la part affichée, elle, ne fait que croître.
    func report(completed: Int, of total: Int) {
        let next = SeedingProgress(completed: completed, total: total)
        if let shown = progress.fraction, let candidate = next.fraction, candidate < shown { return }
        progress = next
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
        if reseeds {
            didDebugReseed = true
            // Le repère « déjà préchargée » tombe d'emblée : une simulation interrompue (app quittée en route)
            // reprend alors d'elle-même au lancement NORMAL suivant, au lieu de laisser une bibliothèque
            // incomplète qu'on croirait finie.
            UserDefaults.standard.removeObject(forKey: seededKey)
        }
        #else
        let reseeds = false
        #endif
        let alreadySeeded = !reseeds && UserDefaults.standard.bool(forKey: seededKey)
        guard reseeds || needsSeeding(container: container, alreadySeeded: alreadySeeded) else { return }

        // Le bandeau part tout de suite — sauf pour le crochet de débogage, qui prépare d'abord en silence
        // sa « mise à jour » simulée (le bandeau doit montrer le préchargement, pas ce montage).
        if !reseeds { PuzzleSeedingState.shared.begin() }
        Task.detached(priority: .utility) {
            #if DEBUG
            if reseeds {
                removeSomeUntriedLibraryPuzzles(container: container)
                await MainActor.run { PuzzleSeedingState.shared.begin() }
            }
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

    /// Simule une MISE À JOUR de la bibliothèque : retire les puzzles jamais tentés du cinquième le plus facile
    /// (ceux qu'un préchargement remet à l'identique). Le préchargement relit alors les autres — l'étape qui
    /// tournait sans barre avant le 16/11/2026 — puis réinsère les manquants. Toute progression reste.
    ///
    /// Une suppression GROUPÉE, faite dans la base : retirer 26 000 puzzles un par un, après les avoir tous
    /// chargés, prenait plus d'une minute et demie sur un iPad de 2018 — avant même le bandeau.
    nonisolated private static func removeSomeUntriedLibraryPuzzles(container: ModelContainer) {
        let ratings = LichessPuzzleLoader.standard.map(\.rating).sorted()
        guard !ratings.isEmpty else { return }
        let cutoff = ratings[ratings.count / 5]
        let untriedAndEasy = #Predicate<Puzzle> { puzzle in
            puzzle.sourceRaw == "lichess"
                && puzzle.successCount.flatMap { $0 == 0 } != false
                && puzzle.failureCount.flatMap { $0 == 0 } != false
                && puzzle.rating.flatMap { $0 < cutoff } == true
        }
        let context = ModelContext(container)
        try? context.delete(model: Puzzle.self, where: untriedAndEasy)
        try? context.save()
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

    /// Les tranches de la relecture : les puzzles sans classement, puis douze tranches de classement calées
    /// sur la répartition de la bibliothèque embarquée (de taille comparable, donc une barre régulière).
    /// Ensemble, elles couvrent TOUS les puzzles Lichess, chacun une seule fois.
    static func ratingSlices(of entries: [LichessPuzzleEntry], count: Int = 12) -> [Predicate<Puzzle>] {
        let ratings = entries.map(\.rating).sorted()
        var bounds: [Int] = []
        if !ratings.isEmpty {
            for index in 1..<count {
                let bound = ratings[index * ratings.count / count]
                if bound != bounds.last { bounds.append(bound) }
            }
        }
        var slices: [Predicate<Puzzle>] = [#Predicate<Puzzle> { $0.sourceRaw == "lichess" && $0.rating == nil }]
        var lower = Int.min
        for upper in bounds + [Int.max] {
            let low = lower, high = upper
            slices.append(#Predicate<Puzzle> { puzzle in
                puzzle.sourceRaw == "lichess" && puzzle.rating.flatMap { $0 >= low && $0 < high } == true
            })
            lower = upper
        }
        // Le dernier bord est exclusif : `Int.max` lui-même tomberait hors de toute tranche.
        let topRating: Int? = Int.max
        slices.append(#Predicate<Puzzle> { $0.sourceRaw == "lichess" && $0.rating == topRating })
        return slices
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

        // 1. Relit la bibliothèque déjà en base (mise à jour d'une version antérieure), PAR TRANCHES — et en ne
        // chargeant que les champs utiles : la barre avance pendant cette étape, qui durait sans rien dire
        // (≈ 10 s sur un iPad de 2018). Retient ce qui reste ; note les puzzles absents du nouvel échantillon
        // ET jamais tentés, retirés ensuite — aucune progression SM-2 perdue.
        //
        // Tranches de CLASSEMENT, pas pages triées : trier 130 000 identifiants à chaque page triplait la
        // durée (29 s au lieu de 10 sur l'iPad). Chaque tranche est une requête filtrée, sans tri ni
        // décalage : elles se partagent la bibliothèque sans recouvrement ni oubli, quoi qu'il arrive.
        let lichess = #Predicate<Puzzle> { $0.sourceRaw == "lichess" }
        let existingCount = (try? context.fetchCount(FetchDescriptor<Puzzle>(predicate: lichess))) ?? 0
        // Estimation d'avant relecture : les anciens identifiants sont conservés d'une version à l'autre.
        var work = SeedingWork(toScan: existingCount, toInsert: max(0, entries.count - existingCount))
        Self.publishProgress(completed: 0, of: work.total)
        var keptIDs = Set<String>()
        var obsolete: [PersistentIdentifier] = []
        var scanned = 0
        if existingCount > 0 {
            for slice in ratingSlices(of: entries) {
                var page = FetchDescriptor<Puzzle>(predicate: slice)
                page.propertiesToFetch = [\.externalID, \.successCount, \.failureCount]
                for puzzle in (try? context.fetch(page)) ?? [] {
                    let attempts = (puzzle.successCount ?? 0) + (puzzle.failureCount ?? 0)
                    let id = puzzle.externalID ?? ""
                    if attempts > 0 || newIDs.contains(id) {
                        if puzzle.externalID != nil { keptIDs.insert(id) }
                    } else {
                        obsolete.append(puzzle.persistentModelID)
                    }
                    scanned += 1
                }
                Self.publishProgress(completed: work.done(scanned: scanned, inserted: 0), of: work.total)
            }
        }
        for id in obsolete {
            context.delete(context.model(for: id))
        }

        // 2. Insère les nouveaux, dédoublonnés par identifiant Lichess, par
        // lots de 2 000 (save intermédiaire) pour borner le pic mémoire.
        let toInsert = entries.reduce(0) { $0 + (keptIDs.contains($1.id) ? 0 : 1) }
        work.toInsert = toInsert
        work.toScan = scanned
        Self.publishProgress(completed: work.done(scanned: scanned, inserted: 0), of: work.total)
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
                Self.publishProgress(completed: work.done(scanned: scanned, inserted: inserted), of: work.total)
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
