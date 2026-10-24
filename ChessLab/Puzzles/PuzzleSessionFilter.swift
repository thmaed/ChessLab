import Foundation
import SwiftData

/// Critères d'une série de puzzles : ce que l'utilisateur a sélectionné
/// dans ``PuzzleQueueView`` (provenance, ratés, niveau, phase, thème). La
/// série est OUVERTE : plutôt qu'une liste figée de N puzzles choisie à
/// l'avance, chaque "Nouveau puzzle" retire le prochain puzzle dû
/// correspondant à ces critères — l'utilisateur enchaîne tant qu'il veut et
/// s'arrête quand il veut.
struct PuzzleSessionFilter: Hashable {
    var difficulty: DifficultyTier?
    var phase: GamePhase?
    var theme: PuzzleTheme?
    /// `nil` = les deux. Sans ce critère, vos puzzles maison (quelques
    /// dizaines) se noyaient dans les ~100 000 de la bibliothèque : tirés
    /// au hasard parmi eux, ils ne sortaient pour ainsi dire jamais.
    var source: PuzzleSource?
    /// Seulement les puzzles RATÉS À LA DERNIÈRE TENTATIVE — voir
    /// ``PuzzleSessionDrawer/predicate(matching:neverOpenedOnly:excluding:)``.
    var missedOnly = false
    /// Fenêtre de cotes « À mon niveau » (``PuzzleRating/window``), calculée au
    /// lancement de la série. Prime sur `difficulty` : les deux critères disent
    /// la même chose, l'un par palier, l'autre par la cote du joueur.
    var ratingWindow: ClosedRange<Int>?
}

/// Compte et tire les puzzles dus correspondant à un
/// ``PuzzleSessionFilter`` — partagé entre la file (comptage/groupes par
/// thème) et l'écran de résolution (tirage du puzzle suivant).
///
/// Tout passe par `fetchCount`/`fetchOffset` côté store : avec ~50 000
/// puzzles presque tous dus, matérialiser les candidats en objets
/// SwiftData pour les compter ou en tirer UN rendait chaque tap de
/// filtre perceptiblement lent. La phase est lue depuis `phaseRaw`
/// (stockée au préchargement, voir ``PuzzleLibrarySeeder``) — plus
/// aucune classification de FEN au moment du filtrage.
@MainActor
enum PuzzleSessionDrawer {
    /// Le prochain puzzle à présenter pour ce filtre — même priorité
    /// "jamais ouverts d'abord" que ``PuzzleSessionBuilder``, mais en
    /// deux tirages aléatoires par offset plutôt qu'en mélangeant une
    /// liste matérialisée.
    static func drawNext(
        matching filter: PuzzleSessionFilter, excluding excludedID: UUID? = nil, in context: ModelContext
    ) -> Puzzle? {
        // Mode déterministe (captures App Store) : SERVIR le puzzle Lichess
        // 00008, inséré au besoin — le semis de la bibliothèque
        // ÉCHANTILLONNE le fichier embarqué, aucun « premier par id » n'est
        // donc stable d'une installation à l'autre (constaté sur trois
        // prises : trois puzzles différents). Les parcours vidéo scriptés
        // jouent sa solution connue (Re7 / Nc1 / Dxc1).
        if CommandLine.arguments.contains("-uiTestDeterministicPuzzles") {
            let wanted = "00008"
            var pinned = FetchDescriptor<Puzzle>(predicate: #Predicate { $0.externalID == wanted })
            pinned.fetchLimit = 1
            if let existing = ((try? context.fetch(pinned)) ?? []).first { return existing }
            let fixed = Puzzle()
            fixed.externalID = wanted
            fixed.fen = "r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2b1/PqP3PP/7K w - - 0 25"
            fixed.solutionLANs = ["e6e7", "b2b1", "b3c1", "b1c1", "h6c1"]
            fixed.themeRaw = "hangingPiece"
            fixed.rating = 1784
            fixed.phaseRaw = "middlegame"
            fixed.sourceRaw = "lichess"
            context.insert(fixed)
            try? context.save()
            return fixed
        }
        if let neverOpened = randomPick(matching: filter, neverOpenedOnly: true, excluding: excludedID, in: context) {
            return neverOpened
        }
        return randomPick(matching: filter, neverOpenedOnly: false, excluding: excludedID, in: context)
    }

    /// Le lot d'un programme Woodpecker : jusqu'à `count` puzzles DISTINCTS
    /// correspondant au filtre, tirés au hasard, dus ou non — un programme ne
    /// suit pas la répétition espacée. Moins que demandé si le filtre n'en
    /// offre pas assez.
    static func sample(matching filter: PuzzleSessionFilter, count: Int, in context: ModelContext) -> [Puzzle] {
        var descriptor = FetchDescriptor<Puzzle>(predicate: predicate(matching: filter, ignoresSchedule: true))
        let total = (try? context.fetchCount(descriptor)) ?? 0
        guard total > 0, count > 0 else { return [] }
        // Des offsets distincts, puis un puzzle par offset : même raison que
        // ``randomPick`` — ne jamais matérialiser des dizaines de milliers
        // d'objets pour en garder cinquante.
        let offsets = Array(0..<total).shuffled().prefix(count)
        descriptor.fetchLimit = 1
        var seen = Set<UUID>()
        return offsets.compactMap { offset in
            descriptor.fetchOffset = offset
            // Sans tri, rien ne GARANTIT que deux requêtes rangent les lignes
            // dans le même ordre : un doublon reste possible, on l'écarte.
            guard let puzzle = ((try? context.fetch(descriptor)) ?? []).first,
                  seen.insert(puzzle.id).inserted else { return nil }
            return puzzle
        }
    }

    /// Combien de puzzles à tirer pour ce filtre (dus, ou ratés en mode
    /// « ratés ») — la séance du jour (A5) en fait ses étapes.
    static func count(matching filter: PuzzleSessionFilter, in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<Puzzle>(predicate: predicate(matching: filter)))) ?? 0
    }

    /// Existe-t-il au moins un puzzle de cette provenance, dû ou non ?
    static func hasAnyPuzzle(from source: PuzzleSource, in context: ModelContext) -> Bool {
        let sourceRaw = source.rawValue
        let legacySourceRaw = PuzzleSource.ownGames.rawValue
        var descriptor = FetchDescriptor<Puzzle>(predicate: #Predicate { ($0.sourceRaw ?? legacySourceRaw) == sourceRaw })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Un puzzle de vos parties existe-t-il déjà pour cette position ? Les
    /// insertions pas encore sauvegardées comptent (`includePendingChanges`
    /// par défaut) — utile pendant une génération en cours.
    static func hasOwnPuzzle(fen: String, in context: ModelContext) -> Bool {
        let legacySourceRaw = PuzzleSource.ownGames.rawValue
        let target: String? = fen
        var descriptor = FetchDescriptor<Puzzle>(predicate: #Predicate {
            $0.fen == target && ($0.sourceRaw ?? legacySourceRaw) == legacySourceRaw
        })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private static func randomPick(
        matching filter: PuzzleSessionFilter, neverOpenedOnly: Bool, excluding excludedID: UUID?, in context: ModelContext
    ) -> Puzzle? {
        var descriptor = FetchDescriptor<Puzzle>(
            predicate: predicate(matching: filter, neverOpenedOnly: neverOpenedOnly, excluding: excludedID)
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count > 0 else { return nil }
        descriptor.fetchOffset = Int.random(in: 0..<count)
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor)) ?? []).first
    }

    /// Prédicat unique couvrant toutes les combinaisons de filtres, via
    /// des bornes/valeurs neutres pour les critères absents.
    ///
    /// « Raté » se lit sans nouveau champ : un échec remet `repetitions` à
    /// zéro (``SpacedRepetition``), un succès l'incrémente. `failureCount > 0
    /// && repetitions == 0` dit donc exactement « la dernière tentative a
    /// échoué » — et le puzzle quitte la liste dès qu'on le réussit. Un puzzle
    /// réussi avec l'indice compte comme réussi (décision du 23/10/2026).
    ///
    /// En mode « ratés », l'échéance est IGNORÉE : un échec fixe la révision
    /// au lendemain, le filtre serait donc vide juste après la séance — au
    /// moment précis où l'on veut rejouer ce qu'on vient de manquer. Rejouer
    /// en avance ne fausse pas SM-2 : après un échec comme après le succès
    /// qui suit, la révision tombe le lendemain.
    ///
    /// - important: PAS de déballage forcé (`$0.rating!`) dans un
    /// `#Predicate` : SwiftData ne sait pas le traduire, la requête
    /// échoue et `try?` la transformait en "zéro résultat" silencieux —
    /// c'est exactement le bug qui rendait les filtres de difficulté
    /// vides. Uniquement du `??` et des comparaisons simples.
    private static func predicate(
        matching filter: PuzzleSessionFilter, neverOpenedOnly: Bool = false, excluding excludedID: UUID? = nil,
        ignoresSchedule: Bool = false
    ) -> Predicate<Puzzle> {
        let now = Date()
        let distantPast = Date.distantPast
        // Un puzzle sans rating (vos gaffes) vaut -1 : inclus quand aucun
        // niveau n'est choisi (borne Int.min), exclu sinon — la
        // difficulté n'a de sens que pour la bibliothèque notée.
        let lowerRating = filter.ratingWindow?.lowerBound
            ?? filter.difficulty?.ratingRange.lowerBound ?? Int.min
        let upperRating = filter.ratingWindow?.upperBound
            ?? filter.difficulty?.ratingRange.upperBound ?? Int.max
        let phaseRaw = filter.phase?.rawValue
        let themeRaw = filter.theme?.rawValue
        // Sentinelle qui ne matche aucun puzzle réel quand rien n'est à
        // exclure — évite une branche optionnelle dans le prédicat.
        let excluded = excludedID ?? UUID()
        let requireNeverOpened = neverOpenedOnly

        let criteria = #Predicate<Puzzle> {
            ($0.rating ?? -1) >= lowerRating
                && ($0.rating ?? -1) <= upperRating
                && (phaseRaw == nil || $0.phaseRaw == phaseRaw)
                && (themeRaw == nil || $0.themeRaw == themeRaw)
                && (!requireNeverOpened || $0.firstOpenedAt == nil)
                && $0.id != excluded
        }
        // Trois prédicats composés plutôt qu'un seul : d'un bloc, le
        // compilateur renonçait à typer l'expression.
        let schedule: Predicate<Puzzle>
        if filter.missedOnly {
            schedule = #Predicate { ($0.failureCount ?? 0) > 0 && ($0.repetitions ?? 0) == 0 }
        } else if ignoresSchedule {
            schedule = #Predicate { _ in true }
        } else {
            schedule = #Predicate { ($0.dueDate ?? distantPast) <= now }
        }
        // Un puzzle sans `sourceRaw` date d'avant ce champ : il venait
        // forcément de vos parties (voir ``Puzzle/source``).
        let legacySourceRaw = PuzzleSource.ownGames.rawValue
        let provenance: Predicate<Puzzle>
        if let sourceRaw = filter.source?.rawValue {
            provenance = #Predicate { ($0.sourceRaw ?? legacySourceRaw) == sourceRaw }
        } else {
            provenance = #Predicate { _ in true }
        }

        return #Predicate<Puzzle> {
            criteria.evaluate($0) && schedule.evaluate($0) && provenance.evaluate($0)
        }
    }
}
