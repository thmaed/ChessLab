import Foundation

/// VISUALISATION (18/11/2026) — s'entraîner à voir l'échiquier dans sa tête. Né du retour de Ron (testeur,
/// enseignant) : une ÉCHELLE de marches, du plus simple au plus dur, des exercices générés à l'infini (un livre
/// s'épuise, pas une app), réglables, et la trace des réussites, des échecs et de CE qui a été raté.
///
/// Décisions de l'utilisateur (18/11/2026) : le nom « Visualisation », une tuile dans « Plus » à l'accueil, le
/// lot 1 d'abord (marches 1 « Les cases » et 2 « Les lignes »), et quatre réglages : les marches, la longueur de
/// la série, « vu des Noirs », un chrono par question.
///
/// Ce fichier est la RÈGLE, pure : aucune horloge, aucune vue. Le hasard vient de l'appelant (les tests passent un
/// générateur réglé). Les exercices sont INVENTÉS ici, jamais repris d'un livre.

// MARK: - Les cases et les lignes

/// Une case, en coordonnées 0…7 (a1 = 0, 0).
struct VisualizationSquare: Hashable, Codable, Comparable {
    let file: Int
    let rank: Int

    init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }

    /// « e4 » → e4 ; `nil` si ce n'est pas une case.
    init?(_ notation: String) {
        let chars = Array(notation)
        guard chars.count == 2, let f = chars[0].asciiValue, let r = chars[1].asciiValue,
              (97...104).contains(f), (49...56).contains(r) else { return nil }
        self.init(file: Int(f) - 97, rank: Int(r) - 49)
    }

    var isValid: Bool { (0...7).contains(file) && (0...7).contains(rank) }
    var notation: String { "\(Self.fileLetters[file])\(rank + 1)" }
    var fileLetter: String { Self.fileLetters[file] }
    /// a1 est foncée.
    var isLight: Bool { (file + rank) % 2 == 1 }

    static let fileLetters = ["a", "b", "c", "d", "e", "f", "g", "h"]
    static let all: [VisualizationSquare] = (0..<8).flatMap { r in (0..<8).map { VisualizationSquare(file: $0, rank: r) } }

    static func < (a: Self, b: Self) -> Bool { (a.rank, a.file) < (b.rank, b.file) }

    func offset(_ df: Int, _ dr: Int) -> VisualizationSquare? {
        let s = VisualizationSquare(file: file + df, rank: rank + dr)
        return s.isValid ? s : nil
    }

    /// Sur une même diagonale (dans un sens ou dans l'autre).
    func sharesDiagonal(with other: VisualizationSquare) -> Bool {
        self != other && abs(file - other.file) == abs(rank - other.rank)
    }
}

/// Une diagonale, nommée par ses deux extrémités (« a1–h8 »), du bas vers le haut.
struct VisualizationDiagonal: Hashable {
    let squares: [VisualizationSquare]
    var start: VisualizationSquare { squares[0] }
    var end: VisualizationSquare { squares[squares.count - 1] }
    var name: String { "\(start.notation)–\(end.notation)" }

    /// Toutes les diagonales d'au moins trois cases, dans les deux sens.
    static let all: [VisualizationDiagonal] = {
        var result: [VisualizationDiagonal] = []
        for direction in [1, -1] {
            // Points de départ : la rangée 1, et la colonne a (sens ↗) ou h (sens ↖).
            var starts = (0..<8).map { VisualizationSquare(file: $0, rank: 0) }
            starts += (1..<8).map { VisualizationSquare(file: direction == 1 ? 0 : 7, rank: $0) }
            for start in starts {
                var squares = [start]
                while let next = squares.last!.offset(direction, 1) { squares.append(next) }
                if squares.count >= 3 { result.append(VisualizationDiagonal(squares: squares)) }
            }
        }
        return result
    }()

    static func named(_ name: String) -> VisualizationDiagonal? { all.first { $0.name == name } }
}

/// Une colonne ou une rangée.
enum VisualizationLine: Hashable {
    case file(Int)
    case rank(Int)

    func contains(_ square: VisualizationSquare) -> Bool {
        switch self {
        case let .file(f): square.file == f
        case let .rank(r): square.rank == r
        }
    }

    /// Clé de reprise : « f:d » ou « r:5 ».
    var key: String {
        switch self {
        case let .file(f): "f:\(VisualizationSquare.fileLetters[f])"
        case let .rank(r): "r:\(r + 1)"
        }
    }

    init?(key: String) {
        let parts = key.split(separator: ":").map(String.init)
        guard parts.count == 2 else { return nil }
        if parts[0] == "f", let f = VisualizationSquare.fileLetters.firstIndex(of: parts[1]) { self = .file(f) }
        else if parts[0] == "r", let r = Int(parts[1]), (1...8).contains(r) { self = .rank(r - 1) }
        else { return nil }
    }
}

/// Le plus court chemin d'un cavalier, en coups (0 sur place).
enum KnightDistance {
    static let jumps = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)]

    static func between(_ from: VisualizationSquare, _ to: VisualizationSquare) -> Int {
        var distance = [from: 0]
        var queue = [from]
        var head = 0
        while head < queue.count {
            let square = queue[head]
            head += 1
            if square == to { return distance[square]! }
            for (df, dr) in jumps {
                if let next = square.offset(df, dr), distance[next] == nil {
                    distance[next] = distance[square]! + 1
                    queue.append(next)
                }
            }
        }
        return 0
    }
}

// MARK: - Les marches et les exercices

/// Une marche de l'échelle. Le lot 1 en livre deux.
enum VisualizationStep: String, Codable, CaseIterable, Identifiable {
    case squares
    case lines

    var id: String { rawValue }
    var number: Int { self == .squares ? 1 : 2 }
    /// Clé française (localisée par l'appelant).
    var title: String { self == .squares ? "Les cases" : "Les lignes" }
    var detail: String {
        self == .squares ? "Couleur d'une case, la trouver, la nommer" : "Diagonales, croisements, trajets du cavalier"
    }
    var kinds: [VisualizationKind] { VisualizationKind.allCases.filter { $0.step == self } }
}

enum VisualizationKind: String, Codable, CaseIterable, Identifiable {
    /// « La case e5 est-elle claire ou foncée ? » — sans plateau.
    case squareColor
    /// « Touchez f3 » — sur un plateau sans coordonnées.
    case findSquare
    /// Une case surlignée sur un plateau sans coordonnées : laquelle est-ce ?
    case nameSquare
    /// « c1 et h6 sont-elles sur la même diagonale ? » — sans plateau.
    case sameDiagonal
    /// « Quelle case est sur la colonne d et sur la diagonale a1–h8 ? » — sans plateau.
    case lineIntersection
    /// « En combien de coups un cavalier va-t-il de b1 à f5 ? » — sans plateau.
    case knightDistance

    var id: String { rawValue }

    var step: VisualizationStep {
        switch self {
        case .squareColor, .findSquare, .nameSquare: .squares
        case .sameDiagonal, .lineIntersection, .knightDistance: .lines
        }
    }

    /// Le nom court, au bilan (clé française).
    var title: String {
        switch self {
        case .squareColor: "Couleur d'une case"
        case .findSquare: "Trouver une case"
        case .nameSquare: "Nommer une case"
        case .sameDiagonal: "Même diagonale"
        case .lineIntersection: "Croisements"
        case .knightDistance: "Trajets du cavalier"
        }
    }

    /// L'exercice se fait SUR un plateau (sans coordonnées) ; les autres, de tête.
    var usesBoard: Bool { self == .findSquare || self == .nameSquare }
}

enum VisualizationAnswer: Hashable {
    case light
    case dark
    case yes
    case no
    case square(VisualizationSquare)
    case number(Int)
}

/// Une question : ce qu'il faut dire, la bonne réponse, et les choix proposés (vides pour « Touchez… » : on
/// répond sur le plateau).
struct VisualizationQuestion: Equatable {
    let kind: VisualizationKind
    /// Les cases de l'énoncé : la case à juger, à trouver ou à nommer ; les deux cases comparées ; départ et
    /// arrivée du cavalier ; la réponse du croisement.
    let squares: [VisualizationSquare]
    /// Croisements : la colonne ou la rangée, et la diagonale.
    let line: VisualizationLine?
    let diagonal: VisualizationDiagonal?
    let answer: VisualizationAnswer
    let choices: [VisualizationAnswer]

    /// Ce qui permet de reposer la MÊME question plus tard (les erreurs reviennent).
    var reviewKey: String {
        switch kind {
        case .squareColor, .findSquare, .nameSquare:
            "\(kind.rawValue)|\(squares[0].notation)"
        case .sameDiagonal, .knightDistance:
            "\(kind.rawValue)|\(squares[0].notation)|\(squares[1].notation)"
        case .lineIntersection:
            "\(kind.rawValue)|\(line!.key)|\(diagonal!.name)"
        }
    }
}

// MARK: - Le générateur

enum VisualizationGenerator {
    static func question<R: RandomNumberGenerator>(_ kind: VisualizationKind, using rng: inout R) -> VisualizationQuestion {
        switch kind {
        case .squareColor:
            return squareColor(VisualizationSquare.all.randomElement(using: &rng)!)
        case .findSquare:
            return findSquare(VisualizationSquare.all.randomElement(using: &rng)!)
        case .nameSquare:
            return nameSquare(VisualizationSquare.all.randomElement(using: &rng)!, using: &rng)
        case .sameDiagonal:
            let pair = sameDiagonalPair(on: Bool.random(using: &rng), using: &rng)
            return sameDiagonal(pair.0, pair.1)
        case .lineIntersection:
            let diagonal = VisualizationDiagonal.all.randomElement(using: &rng)!
            let square = diagonal.squares.randomElement(using: &rng)!
            let line: VisualizationLine = Bool.random(using: &rng) ? .file(square.file) : .rank(square.rank)
            return lineIntersection(line, diagonal, using: &rng)!
        case .knightDistance:
            var from = VisualizationSquare.all.randomElement(using: &rng)!
            var to = VisualizationSquare.all.randomElement(using: &rng)!
            // Un trajet nul n'a pas de sens ; on évite aussi de trop servir le saut unique, trop facile.
            while to == from || (KnightDistance.between(from, to) == 1 && Int.random(in: 0..<3, using: &rng) > 0) {
                from = VisualizationSquare.all.randomElement(using: &rng)!
                to = VisualizationSquare.all.randomElement(using: &rng)!
            }
            return knightDistance(from, to)
        }
    }

    /// La même question qu'avant, reconstruite de sa clé (``VisualizationQuestion/reviewKey``).
    static func question<R: RandomNumberGenerator>(reviewKey: String, using rng: inout R) -> VisualizationQuestion? {
        let parts = reviewKey.split(separator: "|").map(String.init)
        guard let kind = parts.first.flatMap(VisualizationKind.init(rawValue:)) else { return nil }
        switch kind {
        case .squareColor, .findSquare, .nameSquare:
            guard parts.count == 2, let s = VisualizationSquare(parts[1]) else { return nil }
            return kind == .squareColor ? squareColor(s) : kind == .findSquare ? findSquare(s) : nameSquare(s, using: &rng)
        case .sameDiagonal, .knightDistance:
            guard parts.count == 3, let a = VisualizationSquare(parts[1]), let b = VisualizationSquare(parts[2]), a != b
            else { return nil }
            return kind == .sameDiagonal ? sameDiagonal(a, b) : knightDistance(a, b)
        case .lineIntersection:
            guard parts.count == 3, let line = VisualizationLine(key: parts[1]),
                  let diagonal = VisualizationDiagonal.named(parts[2]) else { return nil }
            return lineIntersection(line, diagonal, using: &rng)
        }
    }

    static func squareColor(_ s: VisualizationSquare) -> VisualizationQuestion {
        VisualizationQuestion(kind: .squareColor, squares: [s], line: nil, diagonal: nil,
                              answer: s.isLight ? .light : .dark, choices: [.light, .dark])
    }

    static func findSquare(_ s: VisualizationSquare) -> VisualizationQuestion {
        VisualizationQuestion(kind: .findSquare, squares: [s], line: nil, diagonal: nil, answer: .square(s), choices: [])
    }

    /// Quatre noms : le bon, et les confusions les plus fréquentes — la case vue de l'autre côté, son reflet par
    /// colonne ou par rangée, une voisine.
    static func nameSquare<R: RandomNumberGenerator>(_ s: VisualizationSquare, using rng: inout R) -> VisualizationQuestion {
        let lookalikes = [
            VisualizationSquare(file: 7 - s.file, rank: 7 - s.rank),
            VisualizationSquare(file: 7 - s.file, rank: s.rank),
            VisualizationSquare(file: s.file, rank: 7 - s.rank),
        ] + [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1)].compactMap { s.offset($0.0, $0.1) }
        let choices = distractors(for: s, from: lookalikes, using: &rng)
        return VisualizationQuestion(kind: .nameSquare, squares: [s], line: nil, diagonal: nil,
                                     answer: .square(s), choices: choices)
    }

    static func sameDiagonal(_ a: VisualizationSquare, _ b: VisualizationSquare) -> VisualizationQuestion {
        VisualizationQuestion(kind: .sameDiagonal, squares: [a, b], line: nil, diagonal: nil,
                              answer: a.sharesDiagonal(with: b) ? .yes : .no, choices: [.yes, .no])
    }

    /// Deux cases d'une même diagonale, pas voisines (trop facile) ; ou deux cases qui en sont à UNE colonne
    /// près — le piège qu'on veut travailler.
    static func sameDiagonalPair<R: RandomNumberGenerator>(on: Bool, using rng: inout R) -> (VisualizationSquare, VisualizationSquare) {
        while true {
            let diagonal = VisualizationDiagonal.all.randomElement(using: &rng)!
            let i = Int.random(in: 0..<diagonal.squares.count, using: &rng)
            let j = Int.random(in: 0..<diagonal.squares.count, using: &rng)
            guard abs(i - j) >= 2 else { continue }
            let a = diagonal.squares[i]
            let b = diagonal.squares[j]
            if on { return (a, b) }
            guard let shifted = b.offset(Bool.random(using: &rng) ? 1 : -1, 0), !a.sharesDiagonal(with: shifted),
                  shifted != a else { continue }
            return (a, shifted)
        }
    }

    /// `nil` si la ligne ne croise pas la diagonale.
    static func lineIntersection<R: RandomNumberGenerator>(_ line: VisualizationLine, _ diagonal: VisualizationDiagonal,
                                                           using rng: inout R) -> VisualizationQuestion? {
        guard let answer = diagonal.squares.first(where: line.contains) else { return nil }
        let index = diagonal.squares.firstIndex(of: answer)!
        var lookalikes = [index - 1, index + 1].compactMap { diagonal.squares.indices.contains($0) ? diagonal.squares[$0] : nil }
        switch line {
        case .file: lookalikes += [answer.offset(0, 1), answer.offset(0, -1), answer.offset(0, 2)].compactMap { $0 }
        case .rank: lookalikes += [answer.offset(1, 0), answer.offset(-1, 0), answer.offset(2, 0)].compactMap { $0 }
        }
        lookalikes.append(VisualizationSquare(file: answer.rank, rank: answer.file))
        let choices = distractors(for: answer, from: lookalikes, using: &rng)
        return VisualizationQuestion(kind: .lineIntersection, squares: [answer], line: line, diagonal: diagonal,
                                     answer: .square(answer), choices: choices)
    }

    /// Au plus loin, six coups (a1–h8) : on répond par un chiffre de 1 à 6.
    static func knightDistance(_ from: VisualizationSquare, _ to: VisualizationSquare) -> VisualizationQuestion {
        VisualizationQuestion(kind: .knightDistance, squares: [from, to], line: nil, diagonal: nil,
                              answer: .number(KnightDistance.between(from, to)),
                              choices: (1...6).map { .number($0) })
    }

    /// La bonne case et trois leurres DIFFÉRENTS, mélangés ; complétés au hasard si les leurres manquent.
    private static func distractors<R: RandomNumberGenerator>(for answer: VisualizationSquare, from candidates: [VisualizationSquare],
                                                             using rng: inout R) -> [VisualizationAnswer] {
        var picked: [VisualizationSquare] = []
        for candidate in candidates.shuffled(using: &rng) where candidate != answer && candidate.isValid && !picked.contains(candidate) {
            picked.append(candidate)
            if picked.count == 3 { break }
        }
        while picked.count < 3 {
            let random = VisualizationSquare.all.randomElement(using: &rng)!
            if random != answer, !picked.contains(random) { picked.append(random) }
        }
        return ([answer] + picked).shuffled(using: &rng).map { .square($0) }
    }
}

// MARK: - Les réglages

struct VisualizationSettings: Codable, Equatable {
    enum Length: String, Codable, CaseIterable, Identifiable {
        case ten
        case twenty
        case oneMinute

        var id: String { rawValue }
        /// `nil` : autant de questions qu'en une minute.
        var questionCount: Int? {
            switch self {
            case .ten: 10
            case .twenty: 20
            case .oneMinute: nil
            }
        }
        var title: String {
            switch self {
            case .ten: "10 questions"
            case .twenty: "20 questions"
            case .oneMinute: "1 minute"
            }
        }
    }

    var steps: Set<VisualizationStep> = [.squares]
    var length: Length = .ten
    /// Le plateau des exercices sur plateau, vu du côté noir.
    var fromBlack = false
    /// Secondes pour répondre à chaque question ; `nil` : pas de chrono.
    var secondsPerQuestion: Int?

    static let secondsChoices = [10, 5]
    static let seriesDuration: TimeInterval = 60

    var kinds: [VisualizationKind] {
        VisualizationKind.allCases.filter { steps.contains($0.step) }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = VisualizationSettings()
        steps = (try c.decodeIfPresent(Set<VisualizationStep>.self, forKey: .steps)).flatMap { $0.isEmpty ? nil : $0 } ?? fallback.steps
        length = try c.decodeIfPresent(Length.self, forKey: .length) ?? fallback.length
        fromBlack = try c.decodeIfPresent(Bool.self, forKey: .fromBlack) ?? fallback.fromBlack
        secondsPerQuestion = try c.decodeIfPresent(Int.self, forKey: .secondsPerQuestion)
    }
}

// MARK: - Les statistiques et les erreurs à revoir

/// Ce que le joueur a fait, exercice par exercice, et CE qu'il a raté : une question ratée revient dans les séries
/// suivantes jusqu'à deux réussites (la même idée que la répétition espacée des puzzles, en plus simple).
struct VisualizationStats: Codable, Equatable {
    var attempts: [String: Int] = [:]
    var correct: [String: Int] = [:]
    /// Clé de question → réussites encore nécessaires pour la retirer.
    var review: [String: Int] = [:]

    static let successesToClear = 2

    mutating func record(_ question: VisualizationQuestion, correct isCorrect: Bool) {
        let kind = question.kind.rawValue
        attempts[kind, default: 0] += 1
        if isCorrect { correct[kind, default: 0] += 1 }
        let key = question.reviewKey
        if !isCorrect {
            review[key] = Self.successesToClear
        } else if let remaining = review[key] {
            review[key] = remaining > 1 ? remaining - 1 : nil
        }
    }

    func attempts(for step: VisualizationStep) -> Int { step.kinds.reduce(0) { $0 + attempts[$1.rawValue, default: 0] } }
    func correct(for step: VisualizationStep) -> Int { step.kinds.reduce(0) { $0 + correct[$1.rawValue, default: 0] } }

    /// Réussite d'une marche, en pour cent ; `nil` tant qu'elle n'a pas été jouée.
    func accuracy(for step: VisualizationStep) -> Int? {
        let n = attempts(for: step)
        guard n > 0 else { return nil }
        return Int((Double(correct(for: step)) / Double(n) * 100).rounded())
    }

    /// Les questions à revoir parmi les exercices choisis.
    func reviewKeys(for kinds: [VisualizationKind]) -> [String] {
        let wanted = Set(kinds.map(\.rawValue))
        return review.keys.filter { key in key.split(separator: "|").first.map { wanted.contains(String($0)) } ?? false }.sorted()
    }
}

/// Réglages et statistiques, sur l'appareil.
enum VisualizationStore {
    static let settingsKey = "visualization.settings.v1"
    static let statsKey = "visualization.stats.v1"

    static func loadSettings(defaults: UserDefaults = .standard) -> VisualizationSettings {
        defaults.data(forKey: settingsKey).flatMap { try? JSONDecoder().decode(VisualizationSettings.self, from: $0) } ?? .init()
    }

    static func save(_ settings: VisualizationSettings, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: settingsKey) }
    }

    static func loadStats(defaults: UserDefaults = .standard) -> VisualizationStats {
        defaults.data(forKey: statsKey).flatMap { try? JSONDecoder().decode(VisualizationStats.self, from: $0) } ?? .init()
    }

    static func save(_ stats: VisualizationStats, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: statsKey) }
    }
}

// MARK: - La série

/// Le tirage de la question suivante : parmi les exercices choisis, une question RATÉE revient environ une fois sur
/// trois ; jamais deux fois de suite la même.
enum VisualizationDrawer {
    static let reviewShare = 0.3

    static func next<R: RandomNumberGenerator>(kinds: [VisualizationKind], stats: VisualizationStats,
                                              previous: VisualizationQuestion?, using rng: inout R) -> VisualizationQuestion {
        precondition(!kinds.isEmpty)
        let review = stats.reviewKeys(for: kinds).filter { $0 != previous?.reviewKey }
        if !review.isEmpty, Double.random(in: 0..<1, using: &rng) < reviewShare,
           let key = review.randomElement(using: &rng),
           let question = VisualizationGenerator.question(reviewKey: key, using: &rng) {
            return question
        }
        for _ in 0..<20 {
            let question = VisualizationGenerator.question(kinds.randomElement(using: &rng)!, using: &rng)
            if question.reviewKey != previous?.reviewKey { return question }
        }
        return VisualizationGenerator.question(kinds.randomElement(using: &rng)!, using: &rng)
    }
}

/// Une réponse donnée, pour le bilan.
struct VisualizationAnswered: Identifiable, Equatable {
    let id: Int
    let question: VisualizationQuestion
    /// `nil` : le temps de la question s'est écoulé.
    let given: VisualizationAnswer?
    var isCorrect: Bool { given == question.answer }
}
