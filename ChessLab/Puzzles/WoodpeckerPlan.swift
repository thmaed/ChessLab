import Foundation
import SwiftData

/// La méthode Woodpecker (Smith & Tikkanen) : un lot FIXE de puzzles, résolu
/// en entier, puis repris depuis le début en cycles successifs — avec
/// l'objectif d'en trouver plus, et plus vite, à chaque passage. C'est la
/// répétition qui grave les motifs, pas la nouveauté.
///
/// Valeur pure (aucun SwiftData, aucune horloge implicite), donc vérifiable
/// en test. Décisions du 23/10/2026 :
/// - le programme ne touche PAS la répétition espacée (SM-2) des puzzles :
///   deux méthodes, deux comptes séparés ;
/// - lots de 10, 25 ou 50 puzzles, 25 par défaut (ramenés de 25/50/100 le
///   23/10/2026, à la demande de l'utilisateur) ;
/// - l'ordre est MÉLANGÉ à chaque cycle : reconnaître le motif, pas la place
///   du puzzle dans la série ;
/// - le nombre d'essais suit le réglage habituel (``AppSettings/puzzleAttempts``) ;
/// - un puzzle réussi avec l'indice compte comme réussi.
///
/// Les puzzles sont COPIÉS dans le plan (position, solution, thème…) plutôt
/// que référencés : la bibliothèque est échantillonnée différemment à chaque
/// installation, et un programme synchronisé pourrait sinon désigner des
/// puzzles absents de l'autre appareil. Vos puzzles maison y entrent aussi.
struct WoodpeckerPlan: Codable, Equatable {
    static let sizes = [10, 25, 50]
    static let defaultSize = 25

    struct Item: Codable, Equatable {
        var fen: String
        var solutionLANs: [String]
        var themeRaw: String?
        var phaseRaw: String?
        var rating: Int?
        var playedMoveSAN: String?
    }

    /// Une réponse : trouvée ou non, et le temps passé dessus.
    struct Attempt: Codable, Equatable {
        var solved: Bool
        var seconds: Double
    }

    struct Cycle: Codable, Equatable {
        var number: Int
        /// L'ordre de passage de CE cycle : des index dans ``WoodpeckerPlan/items``.
        var order: [Int]
        /// Les réponses dans l'ordre de passage : `attempts[k]` répond à
        /// `order[k]`. Leur nombre est donc aussi la position dans le cycle.
        var attempts: [Attempt] = []
        var startedAt: Date
        var finishedAt: Date?

        var isComplete: Bool { attempts.count >= order.count }
        var solvedCount: Int { attempts.filter(\.solved).count }
        /// Temps ACTIF : la somme des temps de réponse, pas l'écart entre le
        /// début et la fin du cycle — un cycle de cinquante puzzles s'étale
        /// sur plusieurs séances, et les heures entre deux ne comptent pas.
        var activeSeconds: Double { attempts.reduce(0) { $0 + $1.seconds } }
    }

    var items: [Item]
    var cycles: [Cycle]

    /// Premier cycle d'un nouveau programme. `nil` sans aucun puzzle.
    static func start<R: RandomNumberGenerator>(
        items: [Item], at date: Date = Date(), using generator: inout R
    ) -> WoodpeckerPlan? {
        guard !items.isEmpty else { return nil }
        let order = Array(items.indices).shuffled(using: &generator)
        return WoodpeckerPlan(items: items, cycles: [Cycle(number: 1, order: order, startedAt: date)])
    }

    static func start(items: [Item], at date: Date = Date()) -> WoodpeckerPlan? {
        var generator = SystemRandomNumberGenerator()
        return start(items: items, at: date, using: &generator)
    }

    var currentCycle: Cycle { cycles[cycles.count - 1] }

    /// Le puzzle à présenter, `nil` une fois le cycle terminé.
    var currentItemIndex: Int? {
        let cycle = currentCycle
        return cycle.isComplete ? nil : cycle.order[cycle.attempts.count]
    }

    /// Le cycle d'avant le cycle courant, pour la comparaison.
    var previousCycle: Cycle? { cycles.count >= 2 ? cycles[cycles.count - 2] : nil }

    /// Enregistre la réponse au puzzle courant et passe au suivant. Sans
    /// effet si le cycle est déjà terminé.
    mutating func record(solved: Bool, seconds: Double, at date: Date = Date()) {
        guard !currentCycle.isComplete else { return }
        let last = cycles.count - 1
        cycles[last].attempts.append(Attempt(solved: solved, seconds: max(0, seconds)))
        if cycles[last].isComplete { cycles[last].finishedAt = date }
    }

    /// Un nouveau passage sur le MÊME lot, dans un nouvel ordre. Sans effet
    /// tant que le cycle courant n'est pas fini.
    mutating func startNextCycle<R: RandomNumberGenerator>(at date: Date = Date(), using generator: inout R) {
        guard currentCycle.isComplete else { return }
        let order = Array(items.indices).shuffled(using: &generator)
        cycles.append(Cycle(number: currentCycle.number + 1, order: order, startedAt: date))
    }

    mutating func startNextCycle(at date: Date = Date()) {
        var generator = SystemRandomNumberGenerator()
        startNextCycle(at: date, using: &generator)
    }

    /// « 7:05 », « 1:02:03 » — minutes et secondes, les heures seulement
    /// quand il y en a.
    static func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// L'objectif classique de la méthode : boucler le cycle suivant en la
    /// moitié du temps du précédent. `nil` tant qu'aucun cycle n'est fini.
    var nextCycleTargetSeconds: Double? {
        guard let finished = cycles.last(where: \.isComplete) else { return nil }
        return finished.activeSeconds / 2
    }
}

extension WoodpeckerPlan.Item {
    init(_ puzzle: Puzzle) {
        self.init(
            fen: puzzle.fen ?? "", solutionLANs: puzzle.solutionLANs ?? [],
            themeRaw: puzzle.themeRaw, phaseRaw: puzzle.phaseRaw,
            rating: puzzle.rating, playedMoveSAN: puzzle.playedMoveSAN
        )
    }

    /// Un ``Puzzle`` TRANSITOIRE, jamais inséré en base, pour l'écran de
    /// résolution : il ne sait jouer que des `Puzzle`, et un programme ne doit
    /// rien écrire dans la bibliothèque (ni échéance, ni compteur).
    func makePuzzle() -> Puzzle {
        let puzzle = Puzzle()
        puzzle.fen = fen
        puzzle.solutionLANs = solutionLANs
        puzzle.themeRaw = themeRaw
        puzzle.phaseRaw = phaseRaw
        puzzle.rating = rating
        puzzle.playedMoveSAN = playedMoveSAN
        return puzzle
    }
}

/// Un programme Woodpecker enregistré : son plan, et ce qu'il faut pour le
/// lister. Dans le store « Games » SYNCHRONISÉ, comme la progression des
/// puzzles — ajout ADDITIF, même discipline CloudKit (valeurs par défaut,
/// aucune contrainte unique, aucune relation). Le plan voyage en un seul bloc
/// JSON : un programme se joue sur un appareil à la fois.
@Model
final class WoodpeckerProgram {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Les critères qui ont composé le lot, en clair (« Intermédiaire ·
    /// Fourchette »), pour le reconnaître dans la liste.
    var criteria: String = ""
    var planData: Data?
    /// Abandonné par l'utilisateur : gardé (son historique), plus proposé.
    var isArchived: Bool = false

    init() {}

    var plan: WoodpeckerPlan? {
        get { planData.flatMap { try? JSONDecoder().decode(WoodpeckerPlan.self, from: $0) } }
        set {
            planData = newValue.flatMap { try? JSONEncoder().encode($0) }
            updatedAt = Date()
        }
    }
}
