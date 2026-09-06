import Foundation
import SwiftData

/// Critères d'une série de puzzles : ce que l'utilisateur a sélectionné
/// dans ``PuzzleQueueView`` (niveau, phase, éventuellement un thème via
/// les groupes de la liste). La série est OUVERTE : plutôt qu'une liste
/// figée de N puzzles choisie à l'avance, chaque "Nouveau puzzle" retire
/// le prochain puzzle dû correspondant à ces critères — l'utilisateur
/// enchaîne tant qu'il veut et s'arrête quand il veut.
struct PuzzleSessionFilter: Hashable {
    var difficulty: DifficultyTier?
    var phase: GamePhase?
    var theme: PuzzleTheme?
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
    /// - important: PAS de déballage forcé (`$0.rating!`) dans un
    /// `#Predicate` : SwiftData ne sait pas le traduire, la requête
    /// échoue et `try?` la transformait en "zéro résultat" silencieux —
    /// c'est exactement le bug qui rendait les filtres de difficulté
    /// vides. Uniquement du `??` et des comparaisons simples.
    private static func predicate(
        matching filter: PuzzleSessionFilter, neverOpenedOnly: Bool = false, excluding excludedID: UUID? = nil
    ) -> Predicate<Puzzle> {
        let now = Date()
        let distantPast = Date.distantPast
        // Un puzzle sans rating (vos gaffes) vaut -1 : inclus quand aucun
        // niveau n'est choisi (borne Int.min), exclu sinon — la
        // difficulté n'a de sens que pour la bibliothèque notée.
        let lowerRating = filter.difficulty?.ratingRange.lowerBound ?? Int.min
        let upperRating = filter.difficulty?.ratingRange.upperBound ?? Int.max
        let phaseRaw = filter.phase?.rawValue
        let themeRaw = filter.theme?.rawValue
        // Sentinelle qui ne matche aucun puzzle réel quand rien n'est à
        // exclure — évite une branche optionnelle dans le prédicat.
        let excluded = excludedID ?? UUID()
        let requireNeverOpened = neverOpenedOnly

        return #Predicate<Puzzle> {
            ($0.dueDate ?? distantPast) <= now
                && ($0.rating ?? -1) >= lowerRating
                && ($0.rating ?? -1) <= upperRating
                && (phaseRaw == nil || $0.phaseRaw == phaseRaw)
                && (themeRaw == nil || $0.themeRaw == themeRaw)
                && (!requireNeverOpened || $0.firstOpenedAt == nil)
                && $0.id != excluded
        }
    }
}
