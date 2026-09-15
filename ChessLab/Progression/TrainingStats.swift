import Foundation

/// Ce que la MÉMORISATION des ouvertures a produit : combien de positions ont
/// été vues, combien tiennent, combien sont à raffermir, et ce qui est dû.
///
/// Pendant de `TrainingStats.kt`. Le portage Android a montré ce chiffre
/// avant iOS : une répétition espacée sans bilan demande de la confiance sans
/// jamais rien montrer en retour, et c'est justement ce dont on a besoin pour
/// s'y tenir.
///
/// Calcul PUR à partir des enregistrements : ni base ni horloge cachées, donc
/// vérifiable sur des valeurs écrites à la main.
struct TrainingStats: Equatable {
    /// Positions vues au moins une fois.
    let studied: Int
    /// Positions acquises : au moins une semaine de stabilité avant l'oubli.
    let solid: Int
    /// Positions oubliées ou pas encore solides.
    let hard: Int
    /// Positions dont l'échéance est passée.
    let due: Int
    let reviewsThisWeek: Int
    /// Part de révisions réussies sur les trente derniers jours, ou `nil`.
    let retention: Double?
    /// Quand la prochaine échéance tombe, si aucune n'est déjà passée.
    let nextDueAt: Date?

    /// Au-delà d'une semaine de stabilité, la position tient : on la dit
    /// acquise. Solide sans être définitif — c'est le seuil qu'utilise aussi
    /// la file d'entraînement pour ne plus la proposer en priorité.
    static let solidStabilityDays = 7.0

    var isEmpty: Bool { studied == 0 }

    var retentionLabel: String {
        guard let retention else { return "—" }
        return "\(Int((retention * 100).rounded())) %"
    }

    /// « Prochaine révision dans 3 jours » — seulement quand rien n'est dû :
    /// sinon c'est « maintenant » qu'il faut réviser, et l'annoncer pour plus
    /// tard détournerait du geste utile.
    func nextDueLabel(now: Date = Date()) -> String? {
        guard due == 0, let nextDueAt else { return nil }
        let days = Int((nextDueAt.timeIntervalSince(now) / 86_400).rounded())
        switch days {
        case ...0: return LocalizationController.string("Prochaine révision aujourd'hui")
        case 1: return LocalizationController.string("Prochaine révision demain")
        default: return LocalizationController.string("Prochaine révision dans %lld jours", days)
        }
    }

    /// Agrège les enregistrements. `logs` sert à la seule RÉTENTION : le
    /// journal porte la vérité des notes, là où la table n'a que l'état
    /// courant.
    static func compute(
        progress: [OpeningPositionProgress],
        logs: [OpeningReviewLog],
        now: Date = Date()
    ) -> TrainingStats {
        let week = now.addingTimeInterval(-7 * 86_400)
        let month = now.addingTimeInterval(-30 * 86_400)

        let recent = logs.filter { $0.reviewedAt >= month }
        let retention = recent.isEmpty
            ? nil
            : Double(recent.filter { $0.ratingRaw != FSRSRating.again.rawValue }.count) / Double(recent.count)

        return TrainingStats(
            studied: progress.filter { $0.reps > 0 }.count,
            solid: progress.filter { $0.reps > 0 && $0.stability >= solidStabilityDays }.count,
            hard: progress.filter { isHard($0) }.count,
            due: progress.filter { ($0.dueDate ?? .distantFuture) <= now }.count,
            reviewsThisWeek: logs.filter { $0.reviewedAt >= week }.count,
            retention: retention,
            nextDueAt: progress.compactMap(\.dueDate).filter { $0 > now }.min()
        )
    }

    /// Une position est DIFFICILE quand elle a déjà été oubliée, ou qu'elle
    /// n'est pas encore sortie de l'apprentissage. Même critère que la file
    /// d'entraînement : deux définitions de « difficile » finiraient par se
    /// contredire sous les yeux du lecteur.
    private static func isHard(_ record: OpeningPositionProgress) -> Bool {
        let state = FSRSState(rawValue: record.stateRaw) ?? .new
        return record.lapses > 0 || state == .learning || state == .relearning
    }
}
