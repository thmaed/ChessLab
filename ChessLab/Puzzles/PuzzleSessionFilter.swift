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
    /// Nombre de puzzles dus correspondant au filtre — requête de
    /// comptage pure, aucun objet matérialisé.
    static func countDue(matching filter: PuzzleSessionFilter, in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Puzzle>(predicate: predicate(matching: filter))
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Le prochain puzzle à présenter pour ce filtre — même priorité
    /// "jamais ouverts d'abord" que ``PuzzleSessionBuilder``, mais en
    /// deux tirages aléatoires par offset plutôt qu'en mélangeant une
    /// liste matérialisée.
    static func drawNext(
        matching filter: PuzzleSessionFilter, excluding excludedID: UUID? = nil, in context: ModelContext
    ) -> Puzzle? {
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
