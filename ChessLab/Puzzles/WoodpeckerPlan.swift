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
        /// Le coup de préparation d'un puzzle importé (voir ``Puzzle/setupLAN``) :
        /// absent des plans écrits avant lui, qui se lisent donc comme avant.
        var setupLAN: String?
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

    // MARK: Synchronisation par réponses (17/11/2026)

    /// Une réponse JOURNALISÉE (``WoodpeckerAttemptRecord``) : à quel cycle, à quelle place du cycle.
    struct LoggedAttempt: Equatable {
        var cycle: Int
        var step: Int
        var attempt: Attempt
        var at: Date
    }

    /// L'ordre d'un cycle tiré d'une GRAINE stable — le programme et le numéro du cycle : deux appareils qui
    /// ouvrent le même cycle tirent le même ordre, sans se le transmettre. Le premier cycle d'un programme et
    /// ceux des versions précédentes gardent l'ordre écrit dans le plan.
    static func seededOrder(count: Int, programID: UUID, cycle: Int) -> [Int] {
        var generator = SeededCycleGenerator(programID: programID, cycle: cycle)
        return Array(0..<count).shuffled(using: &generator)
    }

    /// Un nouveau passage dans l'ordre de la graine (voir ``seededOrder(count:programID:cycle:)``).
    mutating func startNextCycle(at date: Date = Date(), programID: UUID) {
        guard currentCycle.isComplete else { return }
        let number = currentCycle.number + 1
        cycles.append(Cycle(number: number, order: Self.seededOrder(count: items.count, programID: programID, cycle: number),
                            startedAt: date))
    }

    /// Verse les réponses journalisées dans le plan : chaque cycle reçoit, à la suite des réponses qu'il porte
    /// déjà, celles de ses places suivantes — sans trou (une réponse arrivée avant celle qui la précède attend
    /// la suivante synchronisation). Deux appareils ayant répondu à la même place : la plus ancienne compte.
    /// Un cycle suivant connu seulement par ses réponses est ouvert, dans l'ordre de sa graine.
    mutating func merge(_ logged: [LoggedAttempt], programID: UUID) {
        guard !logged.isEmpty else { return }
        var byCycle: [Int: [Int: LoggedAttempt]] = [:]
        for entry in logged.sorted(by: { $0.at < $1.at }) where byCycle[entry.cycle]?[entry.step] == nil {
            byCycle[entry.cycle, default: [:]][entry.step] = entry
        }
        var index = 0
        while index < cycles.count {
            var cycle = cycles[index]
            let steps = byCycle[cycle.number] ?? [:]
            while !cycle.isComplete, let entry = steps[cycle.attempts.count] {
                cycle.attempts.append(entry.attempt)
                if cycle.isComplete { cycle.finishedAt = entry.at }
            }
            cycles[index] = cycle
            if index == cycles.count - 1, cycle.isComplete,
               let next = byCycle[cycle.number + 1], let first = next.values.map(\.at).min() {
                cycles.append(Cycle(number: cycle.number + 1,
                                    order: Self.seededOrder(count: items.count, programID: programID, cycle: cycle.number + 1),
                                    startedAt: first))
            }
            index += 1
        }
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

    /// Les deux cycles à comparer en barres (C8) : la part de puzzles trouvés
    /// et le temps, l'ancien cycle contre le nouveau. Barres de temps ramenées
    /// au plus long des deux. `nil` sans cycle précédent.
    var cycleComparison: CycleComparison? {
        guard let previous = previousCycle, currentCycle.isComplete, previous.isComplete else { return nil }
        return CycleComparison(previous: previous, current: currentCycle)
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
            rating: puzzle.rating, playedMoveSAN: puzzle.playedMoveSAN,
            setupLAN: puzzle.setupLAN
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
        puzzle.setupLAN = setupLAN
        return puzzle
    }
}

/// Générateur à graine (SplitMix64) : le MÊME ordre de cycle sur tous les appareils.
struct SeededCycleGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(programID: UUID, cycle: Int) {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        withUnsafeBytes(of: programID.uuid) { bytes in
            for byte in bytes { seed = (seed ^ UInt64(byte)) &* 0x100_0000_01B3 }
        }
        state = seed ^ (UInt64(truncatingIfNeeded: cycle) &* 0xBF58_476D_1CE4_E5B9)
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Un programme Woodpecker enregistré : son plan, et ce qu'il faut pour le
/// lister. Dans le store « Games » SYNCHRONISÉ, comme la progression des
/// puzzles — ajout ADDITIF, même discipline CloudKit (valeurs par défaut,
/// aucune contrainte unique, aucune relation).
///
/// ## Ce qui voyage, et quand (17/11/2026)
///
/// Le plan — les puzzles copiés et les cycles — ne s'écrit qu'à la création et au début de chaque cycle.
/// Chaque RÉPONSE est un petit enregistrement à part (``WoodpeckerAttemptRecord``, quelques dizaines
/// d'octets). Avant, le plan entier repartait vers iCloud après chaque puzzle : 20 Ko pour un programme de
/// 50 puzzles, 200 Ko pour une collection de 500 — des centaines de Mo sur un programme complet. Les réponses
/// de deux appareils s'additionnent, là où le plan écrit en dernier écrasait l'autre.
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

    /// Le plan ÉCRIT, augmenté des réponses journalisées (d'ici ou d'un autre appareil). L'écrire réécrit le
    /// plan entier, réponses comprises : à réserver à la création et aux débuts de cycle — une réponse passe
    /// par ``logAttempt(cycle:step:solved:seconds:at:)``.
    var plan: WoodpeckerPlan? {
        get {
            guard var written = planData.flatMap(WoodpeckerPlan.init(storedData:)) else { return nil }
            written.merge(loggedAttempts(), programID: id)
            return written
        }
        set {
            planData = newValue?.storedData
            updatedAt = Date()
        }
    }

    /// Une réponse : UN petit enregistrement. Ni le plan ni la date du programme ne sont touchés — sinon le
    /// programme entier repartirait vers iCloud.
    func logAttempt(cycle: Int, step: Int, solved: Bool, seconds: Double, at date: Date = Date()) {
        guard let modelContext else { return }
        let record = WoodpeckerAttemptRecord()
        record.programID = id
        record.cycleNumber = cycle
        record.step = step
        record.solved = solved
        record.seconds = max(0, seconds)
        record.answeredAt = date
        modelContext.insert(record)
    }

    private func loggedAttempts() -> [WoodpeckerPlan.LoggedAttempt] {
        guard let modelContext else { return [] }
        let programID = id
        let records = (try? modelContext.fetch(FetchDescriptor<WoodpeckerAttemptRecord>(
            predicate: #Predicate { $0.programID == programID }
        ))) ?? []
        return records.map {
            WoodpeckerPlan.LoggedAttempt(cycle: $0.cycleNumber, step: $0.step,
                                         attempt: WoodpeckerPlan.Attempt(solved: $0.solved, seconds: $0.seconds),
                                         at: $0.answeredAt)
        }
    }
}

/// Une réponse d'un programme Woodpecker (voir ``WoodpeckerProgram``) : le cycle, la place dans le cycle,
/// trouvé ou non, le temps. Store « Games » synchronisé ; ajout ADDITIF, mêmes règles CloudKit (valeurs par
/// défaut, aucune relation — le programme est désigné par son identifiant).
@Model
final class WoodpeckerAttemptRecord {
    var id: UUID = UUID()
    var programID: UUID = UUID()
    var cycleNumber: Int = 0
    var step: Int = 0
    var solved: Bool = false
    var seconds: Double = 0
    var answeredAt: Date = Date()

    init() {}
}

/// Le plan tel qu'il est GARDÉ : son JSON, compressé.
///
/// Un enregistrement CloudKit pèse au plus 1 Mo, et le plan voyage en un seul
/// bloc. Un programme de 1 000 puzzles pèse ~210 Ko au premier cycle et y ajoute
/// ~45 Ko par cycle bouclé (réponses + ordre) : ~1 Mo au vingtième, trop pour
/// iCloud. Le JSON, très répétitif, se réduit par zlib à ~15 % (mesuré : 133 Ko
/// au vingtième cycle). Android n'est pas concerné : sa base est locale, sans cette limite.
///
/// Format : le JSON brut tant qu'il tient sous ``compressionThreshold``, et SEULEMENT
/// au-delà un octet nul puis le JSON compressé. Les versions 2.0 et 2.1 lisent le plan
/// d'un enregistrement iCloud comme du JSON : un plan compressé leur serait illisible, elles
/// verraient un programme vide, en proposeraient un neuf et écraseraient l'historique des
/// cycles (revue du 08/11/2026). Le JSON brut, lui, se relit sur toutes les versions ; il ne
/// commence jamais par un octet nul (`{`), ce qui distingue les deux formats.
extension WoodpeckerPlan {
    private static let compressedMarker: UInt8 = 0

    /// Au-delà de ce poids de JSON brut, on compresse : le plan voyage en UN enregistrement
    /// CloudKit, d'au plus 1 Mo en tout ; 600 Ko laissent la marge aux autres champs.
    static let compressionThreshold = 600_000

    var storedData: Data? {
        guard let json = try? JSONEncoder().encode(self) else { return nil }
        guard json.count > Self.compressionThreshold else { return json }
        guard let packed = try? (json as NSData).compressed(using: .zlib) else { return nil }
        return Data([Self.compressedMarker]) + (packed as Data)
    }

    init?(storedData data: Data) {
        let json: Data
        if data.first == Self.compressedMarker {
            guard let unpacked = try? (data.dropFirst() as NSData).decompressed(using: .zlib) else { return nil }
            json = unpacked as Data
        } else {
            json = data
        }
        guard let plan = try? JSONDecoder().decode(WoodpeckerPlan.self, from: json) else { return nil }
        self = plan
    }
}


/// Comparaison de deux cycles bouclés : mêmes chiffres, mêmes seuils sur
/// Android (`CycleComparison` dans `WoodpeckerPlan.kt`).
struct CycleComparison: Equatable {
    let previousScore: Double
    let currentScore: Double
    /// Temps ramenés à 0...1 par le plus long des deux.
    let previousTime: Double
    let currentTime: Double
    /// Secondes gagnées (positif) ou perdues (négatif) sur le cycle d'avant.
    let secondsSaved: Double

    init(previous: WoodpeckerPlan.Cycle, current: WoodpeckerPlan.Cycle) {
        previousScore = Double(previous.solvedCount) / Double(max(1, previous.order.count))
        currentScore = Double(current.solvedCount) / Double(max(1, current.order.count))
        let longest = max(1, previous.activeSeconds, current.activeSeconds)
        previousTime = previous.activeSeconds / longest
        currentTime = current.activeSeconds / longest
        secondsSaved = previous.activeSeconds - current.activeSeconds
    }

    /// Vrai quand le nouveau cycle est à la fois plus rapide et au moins aussi juste.
    var isProgress: Bool { secondsSaved > 0 && currentScore >= previousScore }
}
