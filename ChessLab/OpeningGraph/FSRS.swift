import Foundation

/// Implémentation MAISON de FSRS (Free Spaced Repetition Scheduler), version 5.
///
/// Choix assumé (décision utilisateur du 09/08/2026) : pas de dépendance
/// externe (ni `open-spaced-repetition/swift-fsrs` ni `4rays/swift-fsrs`) —
/// on maîtrise l'algorithme et son évolution. FSRS-5 plutôt que FSRS-6 : decay
/// FIXE (-0,5), 19 poids, formules stables et abondamment documentées ; le
/// léger gain d'exactitude de FSRS-6 (decay apprenable, mémoire court terme
/// affinée) ne justifie pas le risque d'une implémentation maison subtilement
/// fausse sur la donnée la plus douloureuse à perdre. Une montée en FSRS-6
/// reste possible plus tard sans toucher au stockage.
///
/// L'unité de révision est la POSITION (clé FEN normalisée), pas la ligne.
/// L'état (`stability`, `difficulty`, `reps`, `lapses`, `lastReview`, `due`,
/// `state`) est stocké BRUT dans notre propre `@Model`
/// (``OpeningPositionProgress``), CloudKit-compatible et indépendant de toute
/// lib — cette structure n'est donc qu'un calculateur pur, sans persistance.
///
/// PUR et testable (aucune I/O, aucun état global) : mêmes invariants vérifiés
/// que le reste du module (``FSRSTests``).
enum FSRSRating: Int, Codable, Sendable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4
}

/// État FSRS d'une carte (au sens répétition espacée), stocké tel quel.
enum FSRSState: Int, Codable, Sendable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

/// État complet d'une position pour la planification. Value type pur.
struct FSRSCard: Equatable, Sendable {
    var stability: Double
    var difficulty: Double
    var state: FSRSState
    var reps: Int
    var lapses: Int
    var lastReview: Date?
    var due: Date?

    /// Carte jamais révisée.
    static let new = FSRSCard(
        stability: 0, difficulty: 0, state: .new, reps: 0, lapses: 0, lastReview: nil, due: nil
    )
}

/// Résultat d'une révision : la carte replanifiée + l'entrée de journal
/// correspondante (le journal se FUSIONNE entre appareils, jamais écrasé —
/// voir la synchro).
struct FSRSReviewOutcome: Sendable {
    var card: FSRSCard
    var rating: FSRSRating
    var reviewedAt: Date
    var elapsedDays: Double
    var scheduledDays: Double
    var stabilityBefore: Double
    var stabilityAfter: Double
}

/// Paramètres du planificateur : les 19 poids FSRS-5 + la rétention cible.
struct FSRSParameters: Equatable, Sendable {
    /// 19 poids (w0…w18).
    var w: [Double]
    /// Rétention désirée à l'échéance (probabilité de rappel visée). 0,9 par
    /// défaut, comme FSRS.
    var requestRetention: Double
    /// Borne haute d'intervalle (jours) — anti-débordement.
    var maximumIntervalDays: Int

    /// Poids par défaut FSRS-5 (jeu publié par le projet
    /// open-spaced-repetition). Non ré-optimisés en l'absence d'historique
    /// utilisateur : les défauts conviennent très bien tant qu'on n'entraîne
    /// pas les poids sur les logs.
    static let defaultWeights: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
        1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315,
        2.9898, 0.51655, 0.6621,
    ]

    static let `default` = FSRSParameters(
        w: defaultWeights, requestRetention: 0.9, maximumIntervalDays: 36500
    )
}

/// Le planificateur FSRS-5. Sans état : on lui passe une carte + une note, il
/// rend la carte replanifiée.
struct FSRS: Sendable {
    var parameters: FSRSParameters

    /// Décroissance fixe de la courbe d'oubli (FSRS-5).
    static let decay = -0.5
    /// Facteur associé : `0.9^(1/decay) - 1` = `19/81`.
    static let factor = 19.0 / 81.0
    /// Plancher de stabilité (jours) — évite les intervalles dégénérés.
    static let minimumStability = 0.01

    init(parameters: FSRSParameters = .default) {
        self.parameters = parameters
    }

    private var w: [Double] { parameters.w }

    // MARK: Courbe d'oubli / intervalle

    /// Probabilité de rappel (retrievability) `t` jours après la dernière
    /// révision, pour une stabilité `s`.
    static func retrievability(elapsedDays t: Double, stability s: Double) -> Double {
        guard s > 0 else { return 0 }
        return pow(1 + factor * max(0, t) / s, decay)
    }

    /// Rétrievabilité d'une carte à une date donnée.
    func retrievability(of card: FSRSCard, at date: Date) -> Double {
        guard card.state != .new, let last = card.lastReview else { return 0 }
        let t = date.timeIntervalSince(last) / 86_400
        return Self.retrievability(elapsedDays: t, stability: card.stability)
    }

    /// Intervalle (jours) pour atteindre la rétention désirée avec une
    /// stabilité donnée. Borné à [1, max].
    func intervalDays(forStability s: Double) -> Int {
        let raw = (s / Self.factor) * (pow(parameters.requestRetention, 1 / Self.decay) - 1)
        let rounded = Int(raw.rounded())
        return min(max(rounded, 1), parameters.maximumIntervalDays)
    }

    // MARK: Révision

    /// Applique une note à une carte à l'instant `now` et retourne la carte
    /// replanifiée + le journal.
    func review(_ card: FSRSCard, rating: FSRSRating, at now: Date = Date()) -> FSRSReviewOutcome {
        let elapsedDays = card.lastReview.map { max(0, now.timeIntervalSince($0) / 86_400) } ?? 0
        let stabilityBefore = card.stability

        var next = card
        next.reps += 1

        if card.state == .new {
            next.difficulty = initialDifficulty(rating)
            next.stability = max(initialStability(rating), Self.minimumStability)
            next.state = rating == .again ? .learning : .review
        } else if elapsedDays < 1 {
            // Révision le MÊME jour : formule court terme (FSRS-5).
            next.difficulty = nextDifficulty(card.difficulty, rating: rating)
            next.stability = max(shortTermStability(card.stability, rating: rating), Self.minimumStability)
            if rating == .again { next.lapses += 1; next.state = .relearning } else { next.state = .review }
        } else {
            let r = Self.retrievability(elapsedDays: elapsedDays, stability: card.stability)
            next.difficulty = nextDifficulty(card.difficulty, rating: rating)
            if rating == .again {
                next.lapses += 1
                next.stability = max(forgetStability(difficulty: card.difficulty, stability: card.stability, retrievability: r), Self.minimumStability)
                next.state = .relearning
            } else {
                next.stability = max(recallStability(difficulty: card.difficulty, stability: card.stability, retrievability: r, rating: rating), Self.minimumStability)
                next.state = .review
            }
        }

        let interval = intervalDays(forStability: next.stability)
        next.lastReview = now
        next.due = Calendar.current.date(byAdding: .day, value: interval, to: now)

        return FSRSReviewOutcome(
            card: next, rating: rating, reviewedAt: now, elapsedDays: elapsedDays,
            scheduledDays: Double(interval), stabilityBefore: stabilityBefore, stabilityAfter: next.stability
        )
    }

    // MARK: Formules FSRS-5

    /// Stabilité initiale (première révision) = poids de la note, borné.
    func initialStability(_ rating: FSRSRating) -> Double {
        w[rating.rawValue - 1]
    }

    /// Difficulté initiale D₀(G) = w4 − e^{w5·(G−1)} + 1, bornée [1, 10].
    func initialDifficulty(_ rating: FSRSRating) -> Double {
        clampDifficulty(w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1)
    }

    /// Difficulté suivante : amortissement linéaire + retour à la moyenne vers
    /// D₀(Facile) (FSRS-5).
    func nextDifficulty(_ difficulty: Double, rating: FSRSRating) -> Double {
        let deltaD = -w[6] * Double(rating.rawValue - 3)
        let damped = difficulty + deltaD * (10 - difficulty) / 9
        let anchor = clampDifficulty(w[4] - exp(w[5] * 3) + 1) // D₀(Easy)
        let reverted = w[7] * anchor + (1 - w[7]) * damped
        return clampDifficulty(reverted)
    }

    /// Stabilité après un RAPPEL réussi (hard/good/easy).
    func recallStability(difficulty d: Double, stability s: Double, retrievability r: Double, rating: FSRSRating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1
        let easyBonus = rating == .easy ? w[16] : 1
        return s * (1 + exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus)
    }

    /// Stabilité après un OUBLI (again).
    func forgetStability(difficulty d: Double, stability s: Double, retrievability r: Double) -> Double {
        w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
    }

    /// Stabilité court terme (révision le même jour).
    func shortTermStability(_ s: Double, rating: FSRSRating) -> Double {
        s * exp(w[17] * (Double(rating.rawValue) - 3 + w[18]))
    }

    private func clampDifficulty(_ d: Double) -> Double { min(max(d, 1), 10) }
}
