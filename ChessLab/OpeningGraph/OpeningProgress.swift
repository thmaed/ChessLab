import Foundation
import SwiftData

/// Progression d'une POSITION d'ouverture, indexée par **FEN normalisée**
/// (``OpeningFENKey``) — jamais par identifiant de cours ni index de coup.
/// C'est la règle architecturale fondamentale : régénérer/approfondir les
/// arbres ne détruit jamais la mémorisation, une position apprise reste apprise.
///
/// Modèle SYNCHRONISÉ (store « Games », base privée CloudKit), calqué sur
/// ``PuzzleProgress`` : plat, granulaire (une entrée par position pour éviter
/// les conflits massifs), toutes propriétés optionnelles ou à valeur par
/// défaut, **aucune contrainte unique, aucune relation** (contraintes CloudKit).
///
/// L'état FSRS-5 est stocké BRUT (stabilité, difficulté, état, répétitions,
/// échecs, dates) : ``FSRS`` n'est qu'un calculateur pur, la vérité vit ici.
/// `updatedAt` départage les états au merge (la révision la plus récente fait
/// foi — voir la stratégie de conflit en J3).
@Model
final class OpeningPositionProgress {
    /// Clé FEN normalisée — identifiant naturel, stable et identique sur tous
    /// les appareils (la donnée d'ouverture est embarquée et déterministe).
    var fenKey: String = ""

    // MARK: État FSRS-5 (brut)
    var stability: Double = 0
    var difficulty: Double = 0
    /// ``FSRSState`` (0=new … 3=relearning).
    var stateRaw: Int = 0
    var reps: Int = 0
    var lapses: Int = 0
    var lastReviewedAt: Date?
    var dueDate: Date?

    /// Première fois que la position a été présentée à l'utilisateur.
    var firstSeenAt: Date?
    /// Dernière modification — résolution de conflit multi-appareils.
    var updatedAt: Date = Date()

    init(fenKey: String) {
        self.fenKey = fenKey
    }

    /// Vue FSRS de cet enregistrement (calcul).
    var fsrsCard: FSRSCard {
        FSRSCard(
            stability: stability, difficulty: difficulty,
            state: FSRSState(rawValue: stateRaw) ?? .new,
            reps: reps, lapses: lapses, lastReview: lastReviewedAt, due: dueDate
        )
    }

    /// Reporte le résultat d'une révision FSRS dans le stockage.
    func apply(_ outcome: FSRSReviewOutcome) {
        let card = outcome.card
        stability = card.stability
        difficulty = card.difficulty
        stateRaw = card.state.rawValue
        reps = card.reps
        lapses = card.lapses
        lastReviewedAt = card.lastReview
        dueDate = card.due
        if firstSeenAt == nil { firstSeenAt = outcome.reviewedAt }
        updatedAt = outcome.reviewedAt
    }
}

/// Journal des révisions : une entrée APPEND-ONLY par événement de révision.
/// Se FUSIONNE entre appareils (union par `id`), jamais écrasé — les compteurs
/// agrégés seront recalculés à partir du journal fusionné (voir J3). Même
/// store synchronisé, mêmes contraintes CloudKit.
@Model
final class OpeningReviewLog {
    /// Identifiant unique de l'événement — clé de dédoublonnage à la fusion
    /// (chaque appareil génère des UUID distincts, l'union ne perd rien).
    var id: UUID = UUID()
    var fenKey: String = ""
    /// ``FSRSRating`` (1=again … 4=easy).
    var ratingRaw: Int = 0
    var reviewedAt: Date = Date()
    var elapsedDays: Double = 0
    var scheduledDays: Double = 0
    /// Stabilité obtenue après cette révision (pour reconstruire une courbe).
    var stabilityAfter: Double = 0

    init(
        id: UUID = UUID(), fenKey: String, rating: FSRSRating, reviewedAt: Date,
        elapsedDays: Double, scheduledDays: Double, stabilityAfter: Double
    ) {
        self.id = id
        self.fenKey = fenKey
        self.ratingRaw = rating.rawValue
        self.reviewedAt = reviewedAt
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.stabilityAfter = stabilityAfter
    }
}

/// Appartenance au RÉPERTOIRE personnel : un cours marqué « mon répertoire
/// blanc/noir » et/ou favori, pour prioriser les révisions. Indexé par
/// identifiant de cours (donnée embarquée stable). Synchronisé.
@Model
final class RepertoireMembership {
    var courseID: String = ""
    /// ``OpeningSide`` (« white »/« black ») — le camp sous lequel ce cours est
    /// enregistré au répertoire.
    var sideRaw: String = ""
    var isFavorite: Bool = false
    var addedAt: Date?
    var updatedAt: Date = Date()

    init(courseID: String, sideRaw: String, isFavorite: Bool = false) {
        self.courseID = courseID
        self.sideRaw = sideRaw
        self.isFavorite = isFavorite
    }
}

/// Point d'accès à la progression des ouvertures (store « Games »). J2 fournit
/// la lecture/écriture de base indexée par FEN et la replanification FSRS ; la
/// FUSION multi-appareils (mirror/reconcile, recalcul des agrégats) arrive en
/// J3, calquée sur ``PuzzleProgressSync``.
@MainActor
enum OpeningProgressStore {

    /// Progression d'une position, ou `nil` si jamais révisée.
    static func progress(forFEN fenKey: String, in context: ModelContext) -> OpeningPositionProgress? {
        var descriptor = FetchDescriptor<OpeningPositionProgress>(
            predicate: #Predicate { $0.fenKey == fenKey }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Progression existante ou nouvelle (insérée) pour cette position.
    @discardableResult
    static func ensureProgress(forFEN fenKey: String, in context: ModelContext) -> OpeningPositionProgress {
        if let existing = progress(forFEN: fenKey, in: context) { return existing }
        let created = OpeningPositionProgress(fenKey: fenKey)
        context.insert(created)
        return created
    }

    /// Enregistre une révision : replanifie la position via FSRS et ajoute une
    /// entrée au journal. Retourne la progression mise à jour.
    @discardableResult
    static func recordReview(
        fenKey: String, rating: FSRSRating, at now: Date = Date(),
        scheduler: FSRS = FSRS(), in context: ModelContext
    ) -> OpeningPositionProgress {
        let progress = ensureProgress(forFEN: fenKey, in: context)
        let outcome = scheduler.review(progress.fsrsCard, rating: rating, at: now)
        progress.apply(outcome)

        let log = OpeningReviewLog(
            fenKey: fenKey, rating: rating, reviewedAt: outcome.reviewedAt,
            elapsedDays: outcome.elapsedDays, scheduledDays: outcome.scheduledDays,
            stabilityAfter: outcome.stabilityAfter
        )
        context.insert(log)
        try? context.save()
        return progress
    }
}
