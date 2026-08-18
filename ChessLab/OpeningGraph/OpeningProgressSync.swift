import Foundation
import SwiftData

/// Réconciliation multi-appareils de la progression des ouvertures.
///
/// Le TRANSPORT est déjà automatique : le store « Games » est synchronisé par
/// SwiftData + CloudKit (`cloudKitDatabase: .automatic`), les enregistrements
/// voyagent seuls. Ce service règle ce que la synchro automatique ne sait PAS
/// faire — la résolution de conflits quand deux appareils modifient la même
/// position hors ligne — et la déduplication qu'impose l'absence de contrainte
/// d'unicité (interdite par CloudKit) : deux premières révisions de la même
/// position sur deux appareils créent deux enregistrements pour une seule clé.
///
/// STRATÉGIE (structurante, donc documentée) :
/// - Le JOURNAL (``OpeningReviewLog``) est la VÉRITÉ : append-only, fusionné par
///   union (chaque appareil génère des `id` distincts), jamais écrasé.
/// - L'état FSRS d'une position est RECALCULÉ en rejouant le journal fusionné
///   trié par date à travers ``FSRS``. Déterministe : le résultat ne dépend pas
///   de l'ordre d'arrivée CloudKit, seulement de la chronologie réelle des
///   révisions. « La révision la plus récente fait foi » en découle (le replay
///   s'y termine) ; les compteurs (répétitions, échecs) sont RECALCULÉS, pas
///   synchronisés tels quels.
/// - Les doublons d'``OpeningPositionProgress`` d'une même clé sont fusionnés en
///   un seul. FILET DE SÉCURITÉ contre une course à la suppression entre
///   appareils : le journal n'étant JAMAIS supprimé, si une position perdait
///   tous ses enregistrements de progression, la réconciliation suivante la
///   recrée par replay. La progression ne peut donc pas être détruite.
///
/// IDEMPOTENT et ÉCONOME : ne réécrit un enregistrement que si le journal
/// fusionné le contredit (nombre de révisions différent), pour ne pas
/// déclencher de resynchro inutile à chaque lancement. Échec silencieux et non
/// bloquant : tout fonctionne hors ligne et sans compte iCloud.
@MainActor
enum OpeningProgressSync {

    /// Fusionne la progression synchronisée. À appeler au lancement (et, quand
    /// ils existeront, à l'ouverture des écrans d'ouvertures), comme
    /// ``PuzzleProgressSync/reconcile(in:)``.
    static func reconcile(in context: ModelContext, scheduler: FSRS = FSRS()) {
        let positionsChanged = reconcilePositions(scheduler: scheduler, in: context)
        let membershipsChanged = reconcileMemberships(in: context)
        if positionsChanged || membershipsChanged {
            PersistenceLog.save(context)
        }
    }

    // MARK: Positions

    private static func reconcilePositions(scheduler: FSRS, in context: ModelContext) -> Bool {
        let allLogs = (try? context.fetch(FetchDescriptor<OpeningReviewLog>())) ?? []
        let allProgress = (try? context.fetch(FetchDescriptor<OpeningPositionProgress>())) ?? []
        guard !allLogs.isEmpty || !allProgress.isEmpty else { return false }

        let logsByFEN = Dictionary(grouping: allLogs, by: \.fenKey)
        let progressByFEN = Dictionary(grouping: allProgress, by: \.fenKey)
        var changed = false

        for fenKey in Set(logsByFEN.keys).union(progressByFEN.keys) {
            let records = progressByFEN[fenKey] ?? []
            let logs = dedupedByID(logsByFEN[fenKey] ?? []).sorted { $0.reviewedAt < $1.reviewedAt }

            // Déjà cohérent : un seul enregistrement dont le nombre de révisions
            // égale le nombre de logs → rien à faire (pas de resynchro inutile).
            if records.count == 1, let only = records.first, !logs.isEmpty, only.reps == logs.count {
                continue
            }

            // Aucun log rejouable : on garde le plus récent et on supprime les
            // éventuels doublons (best effort, sans replay).
            guard !logs.isEmpty else {
                if records.count > 1 {
                    let sorted = records.sorted { $0.updatedAt > $1.updatedAt }
                    for extra in sorted.dropFirst() { context.delete(extra) }
                    changed = true
                }
                continue
            }

            // Enregistrement canonique (choix stable minimisant les courses) :
            // le plus « avancé » d'abord. Les doublons sont supprimés ; s'il n'en
            // existe aucun (ou si une course les a tous supprimés), on recrée.
            let canonical: OpeningPositionProgress
            if let kept = records.sorted(by: canonicalOrder).first {
                canonical = kept
                for extra in records.filter({ $0 !== kept }) { context.delete(extra) }
                if records.count > 1 { changed = true }
            } else {
                canonical = OpeningPositionProgress(fenKey: fenKey)
                context.insert(canonical)
                changed = true
            }

            let card = replay(logs, scheduler: scheduler)
            if writeState(card, firstSeen: logs.first?.reviewedAt, into: canonical) {
                changed = true
            }
        }
        return changed
    }

    /// Ordre canonique pour choisir le survivant d'un groupe de doublons —
    /// déterministe sur le CONTENU (identique sur tous les appareils une fois
    /// synchronisés), donc les appareils convergent vers le même survivant.
    /// La correction de l'ÉTAT vient de toute façon du replay ; ceci ne choisit
    /// que l'objet conservé.
    private static func canonicalOrder(_ a: OpeningPositionProgress, _ b: OpeningPositionProgress) -> Bool {
        if a.reps != b.reps { return a.reps > b.reps }
        let la = a.lastReviewedAt ?? .distantPast
        let lb = b.lastReviewedAt ?? .distantPast
        if la != lb { return la > lb }
        return (a.firstSeenAt ?? .distantFuture) < (b.firstSeenAt ?? .distantFuture)
    }

    /// Rejoue un journal (déjà trié) à travers FSRS pour reconstruire l'état.
    /// PUR : l'état d'une position est une fonction de son journal.
    static func replay(_ logs: [OpeningReviewLog], scheduler: FSRS = FSRS()) -> FSRSCard {
        var card = FSRSCard.new
        for log in logs {
            let rating = FSRSRating(rawValue: log.ratingRaw) ?? .good
            card = scheduler.review(card, rating: rating, at: log.reviewedAt).card
        }
        return card
    }

    /// Écrit l'état FSRS dans l'enregistrement ; retourne `true` s'il a
    /// réellement changé. `updatedAt` = date de la dernière révision (donc
    /// DÉTERMINISTE, pas `Date()`) pour éviter tout ping-pong de synchro.
    @discardableResult
    private static func writeState(_ card: FSRSCard, firstSeen: Date?, into progress: OpeningPositionProgress) -> Bool {
        let newUpdatedAt = card.lastReview ?? progress.updatedAt
        let unchanged = progress.reps == card.reps
            && progress.lapses == card.lapses
            && progress.stateRaw == card.state.rawValue
            && progress.lastReviewedAt == card.lastReview
            && progress.dueDate == card.due
            && progress.firstSeenAt == firstSeen
            && abs(progress.stability - card.stability) < 1e-9
            && abs(progress.difficulty - card.difficulty) < 1e-9
        guard !unchanged else { return false }

        progress.stability = card.stability
        progress.difficulty = card.difficulty
        progress.stateRaw = card.state.rawValue
        progress.reps = card.reps
        progress.lapses = card.lapses
        progress.lastReviewedAt = card.lastReview
        progress.dueDate = card.due
        progress.firstSeenAt = firstSeen
        progress.updatedAt = newUpdatedAt
        return true
    }

    private static func dedupedByID(_ logs: [OpeningReviewLog]) -> [OpeningReviewLog] {
        var seen = Set<UUID>()
        return logs.filter { seen.insert($0.id).inserted }
    }

    // MARK: Répertoire

    /// Déduplique les appartenances au répertoire par (cours, camp) : on garde
    /// la plus récente et on fusionne le drapeau favori par OU logique.
    private static func reconcileMemberships(in context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<RepertoireMembership>())) ?? []
        guard all.count > 1 else { return false }

        let grouped = Dictionary(grouping: all) { $0.courseID + "\u{1}" + $0.sideRaw }
        var changed = false
        for (_, records) in grouped where records.count > 1 {
            let sorted = records.sorted { $0.updatedAt > $1.updatedAt }
            let keep = sorted[0]
            let anyFavorite = records.contains { $0.isFavorite }
            if keep.isFavorite != anyFavorite { keep.isFavorite = anyFavorite }
            for extra in sorted.dropFirst() { context.delete(extra) }
            changed = true
        }
        return changed
    }
}
