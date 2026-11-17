import Foundation
import SwiftData

/// « Contre la montre » (17/11/2026) : trois minutes, autant de puzzles que possible, trois erreurs et c'est
/// fini. La difficulté MONTE à chaque réussite — on commence sous son niveau, on finit au-dessus.
///
/// Décisions de l'utilisateur (17/11/2026) : la série ne touche NI la cote de puzzles NI la tuile « Ratés »
/// (le temps fausse la mesure, même logique que Woodpecker) — les ratés restent dans le bilan ; le record suit
/// les réglages par iCloud.
///
/// Ce type est la RÈGLE, pure et datée de l'extérieur : aucune horloge, aucune base — vérifiable en test.
/// L'écran (``PuzzleRushViewModel``) lui passe l'heure.
struct PuzzleRushRun: Equatable {
    /// Durée d'une série.
    static let duration: TimeInterval = 180
    /// Au troisième coup faux, la série s'arrête.
    static let maxErrors = 3
    /// Points de difficulté gagnés à chaque puzzle trouvé.
    static let ratingStep = 30
    /// Le départ se fait ce nombre de points SOUS la cote du joueur…
    static let startBelowRating = 400
    /// … sans descendre sous ce plancher (la bibliothèque n'a presque rien en dessous de 400).
    static let lowestStart = 600
    /// Un puzzle « court » : au plus deux coups à trouver (coup, riposte, coup). Mesuré dans la bibliothèque
    /// embarquée : entre 1 750 et 11 400 par tranche de 200 points de 400 à 2400 — de quoi ne jamais
    /// répéter dans une série.
    static let maxPlies = 3

    let duration: TimeInterval
    let startRating: Int
    private(set) var solved = 0
    private(set) var errors = 0
    /// La cote du puzzle le plus difficile trouvé — « plus haut niveau atteint » au bilan.
    private(set) var highestSolvedRating: Int?
    private var elapsedBeforePause: TimeInterval = 0
    private var runningSince: Date?

    init(playerRating: Double, duration: TimeInterval = Self.duration) {
        self.duration = duration
        startRating = max(Self.lowestStart, Int(playerRating.rounded()) - Self.startBelowRating)
    }

    /// La difficulté visée pour le PROCHAIN puzzle.
    var targetRating: Int { startRating + solved * Self.ratingStep }

    var isRunning: Bool { runningSince != nil }

    func elapsed(at now: Date) -> TimeInterval {
        elapsedBeforePause + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    func remaining(at now: Date) -> TimeInterval {
        max(0, duration - elapsed(at: now))
    }

    func isOver(at now: Date) -> Bool {
        errors >= Self.maxErrors || remaining(at: now) <= 0
    }

    mutating func start(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// Le temps s'arrête : app en arrière-plan, écran quitté.
    mutating func pause(at now: Date) {
        guard let since = runningSince else { return }
        elapsedBeforePause += now.timeIntervalSince(since)
        runningSince = nil
    }

    mutating func recordSolved(rating: Int?) {
        solved += 1
        if let rating { highestSolvedRating = max(highestSolvedRating ?? rating, rating) }
    }

    mutating func recordError() {
        errors = min(Self.maxErrors, errors + 1)
    }
}

/// Tire les puzzles d'une série : de la BIBLIOTHÈQUE seulement (cotés, jamais vos parties ni vos
/// collections), courts, autour de la difficulté visée, jamais deux fois le même dans une série.
@MainActor
enum PuzzleRushDrawer {
    /// Demi-largeurs successives de la fenêtre de cotes : on élargit si la première est vide (les cotes
    /// très hautes sont rares).
    static let windows = [75, 200, 500, 3000]

    static func next(target: Int, excluding used: Set<UUID>, in context: ModelContext) -> Puzzle? {
        for half in windows {
            if let puzzle = pick(in: (target - half)...(target + half), excluding: used, context: context) {
                return puzzle
            }
        }
        return nil
    }

    /// Quelques lignes au hasard dans la fenêtre, puis le premier puzzle court et pas encore servi. La
    /// longueur de la solution n'est pas lisible dans un prédicat SwiftData (un tableau) : on la filtre
    /// sur un petit lot, sans jamais matérialiser la bibliothèque.
    private static func pick(in window: ClosedRange<Int>, excluding used: Set<UUID>, context: ModelContext) -> Puzzle? {
        let lichess = PuzzleSource.lichess.rawValue
        let low = window.lowerBound
        let high = window.upperBound
        var descriptor = FetchDescriptor<Puzzle>(predicate: #Predicate {
            $0.sourceRaw == lichess && ($0.rating ?? -1) >= low && ($0.rating ?? -1) <= high
        })
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count > 0 else { return nil }
        let batch = 24
        for _ in 0..<4 {
            descriptor.fetchOffset = Int.random(in: 0..<max(1, count - batch + 1))
            descriptor.fetchLimit = batch
            let candidates = ((try? context.fetch(descriptor)) ?? []).shuffled()
            if let found = candidates.first(where: { isPlayable($0) && !used.contains($0.id) }) {
                return found
            }
        }
        return nil
    }

    /// Un puzzle jouable dans une série : une position lisible et une solution courte qui commence par le
    /// coup du joueur (les puzzles de la bibliothèque n'ont pas de coup de préparation).
    static func isPlayable(_ puzzle: Puzzle) -> Bool {
        let plies = puzzle.solutionLANs?.count ?? 0
        return plies >= 1 && plies <= PuzzleRushRun.maxPlies && puzzle.setupLAN == nil && !(puzzle.fen ?? "").isEmpty
    }
}

/// Le record, dans les réglages : il suit les appareils par iCloud avec eux (``SettingsCloudSync``).
///
/// Le magasin fusionne en « dernière écriture gagne » : un appareil resté hors ligne avec un ancien record
/// pourrait écraser un meilleur. D'où la lecture du MAXIMUM entre l'appareil et le nuage, avant de comparer
/// comme avant d'écrire.
@MainActor
enum PuzzleRushRecordStore {
    static let key = "puzzleRush.best.v1"

    /// Le record du nuage, quand la synchro est allumée.
    static func cloudValue() -> Int? {
        guard CloudSyncSettingsStore.isEnabled else { return nil }
        return (NSUbiquitousKeyValueStore.default.object(forKey: key) as? NSNumber)?.intValue
    }

    static func best(defaults: UserDefaults = .standard, remote: Int? = cloudValue()) -> Int {
        max(defaults.integer(forKey: key), remote ?? 0)
    }

    /// Enregistre le score s'il bat le record. Rend l'ANCIEN record (0 s'il n'y en avait pas) et si celui-ci
    /// est battu.
    @discardableResult
    static func submit(_ score: Int, defaults: UserDefaults = .standard,
                       remote: Int? = cloudValue()) -> (previous: Int, isNew: Bool) {
        let previous = best(defaults: defaults, remote: remote)
        guard score > previous else {
            // Le nuage portait mieux que l'appareil : on le recopie, pour que l'écran des puzzles l'affiche.
            if defaults.integer(forKey: key) < previous { defaults.set(previous, forKey: key) }
            return (previous, false)
        }
        defaults.set(score, forKey: key)
        return (previous, true)
    }
}
