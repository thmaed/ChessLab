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
    /// Lot 2 (18/11/2026).
    case pieces
    case position

    var id: String { rawValue }
    var number: Int {
        switch self {
        case .squares: 1
        case .lines: 2
        case .pieces: 3
        case .position: 4
        }
    }
    /// Clé française (localisée par l'appelant).
    var title: String {
        switch self {
        case .squares: "Les cases"
        case .lines: "Les lignes"
        case .pieces: "Suivre les pièces"
        case .position: "La position sans plateau"
        }
    }
    var detail: String {
        switch self {
        case .squares: "Couleur d'une case, la trouver, la nommer"
        case .lines: "Diagonales, croisements, trajets du cavalier"
        case .pieces: "Trajets possibles, ce qu'attaque une pièce, deux pièces qui bougent"
        case .position: "Échec, pièce en prise, case attaquée"
        }
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
    /// « ♘ g1 → f3 → d4 → c6 : chaque coup est-il possible ? »
    case pathCheck
    /// « ♗ c1 → g5 → e7 : la pièce attaque-t-elle a3 ? »
    case attackAfter
    /// Deux pièces qui bougent tour à tour : « Quelle pièce attaque f7 ? »
    case twoPieces
    /// Une position en figurines : « Les Blancs font-ils échec au roi noir ? »
    case isCheck
    /// « Quelle pièce noire est en prise ? » (attaquée et non défendue ; ou aucune)
    case hangingPiece
    /// « La case e5 est-elle attaquée par les Blancs ? »
    case squareAttacked

    var id: String { rawValue }

    var step: VisualizationStep {
        switch self {
        case .squareColor, .findSquare, .nameSquare: .squares
        case .sameDiagonal, .lineIntersection, .knightDistance: .lines
        case .pathCheck, .attackAfter, .twoPieces: .pieces
        case .isCheck, .hangingPiece, .squareAttacked: .position
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
        case .pathCheck: "Trajets possibles"
        case .attackAfter: "Ce qu'attaque une pièce"
        case .twoPieces: "Deux pièces"
        case .isCheck: "Échec ?"
        case .hangingPiece: "Pièce en prise"
        case .squareAttacked: "Case attaquée"
        }
    }

    /// L'exercice se fait SUR un plateau (sans coordonnées) ; les autres, de tête.
    var usesBoard: Bool { self == .findSquare || self == .nameSquare }

    /// Le chrono par question GRANDIT avec la marche (retour de l'utilisateur, 18/11/2026 : « 5 s est bien pour le
    /// repérage des cases, trop court pour les problèmes complexes ») : le réglage est le temps de la marche 1,
    /// multiplié par le numéro de la marche — 5 s pour une case, 20 s pour une position.
    func seconds(base: Int) -> Int { base * step.number }
}

enum VisualizationAnswer: Hashable {
    case light
    case dark
    case yes
    case no
    case square(VisualizationSquare)
    case number(Int)
    /// « first », « second », « both », « none » (deux pièces) ; « none » aussi pour « aucune pièce en prise ».
    case option(String)
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
    /// Lot 2 — la position (marche 4), ou les deux pièces de départ (« Deux pièces »).
    var pieces: [VisualizationPiece] = []
    /// Lot 2 — le trajet d'une pièce (départ compris), ou les coups des deux pièces.
    var moves: [VisualizationPiece] = []

    /// Ce qui permet de reposer la MÊME question plus tard (les erreurs reviennent).
    var reviewKey: String {
        switch kind {
        case .pathCheck:
            "\(kind.rawValue)|\(moves[0].kind.rawValue)|\(moves.map(\.square.notation).joined(separator: ","))"
        case .attackAfter:
            "\(kind.rawValue)|\(moves[0].kind.rawValue)|\(moves.map(\.square.notation).joined(separator: ","))|\(squares[0].notation)"
        case .twoPieces:
            "\(kind.rawValue)|\(VisualizationPiece.codes(pieces))|\(VisualizationPiece.codes(moves))|\(squares[0].notation)"
        case .isCheck, .hangingPiece:
            "\(kind.rawValue)|\(VisualizationPiece.codes(pieces))"
        case .squareAttacked:
            "\(kind.rawValue)|\(VisualizationPiece.codes(pieces))|\(squares[0].notation)"
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
        case .pathCheck:
            return randomPathCheck(possible: Bool.random(using: &rng), using: &rng)
        case .attackAfter:
            return randomAttackAfter(attacked: Bool.random(using: &rng), using: &rng)
        case .twoPieces:
            return randomTwoPieces(using: &rng)
        case .isCheck:
            return randomIsCheck(check: Bool.random(using: &rng), using: &rng)
        case .hangingPiece:
            return randomHangingPiece(one: Double.random(in: 0..<1, using: &rng) < 0.7, using: &rng)
        case .squareAttacked:
            return randomSquareAttacked(attacked: Bool.random(using: &rng), using: &rng)
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
        case .pathCheck, .attackAfter:
            guard parts.count >= 3, let pieceKind = VisualizationPieceKind(rawValue: parts[1]) else { return nil }
            let path = parts[2].split(separator: ",").compactMap { VisualizationSquare(String($0)) }
            guard path.count >= 2 else { return nil }
            if kind == .pathCheck { return pathCheck(pieceKind, path) }
            guard parts.count == 4, let target = VisualizationSquare(parts[3]) else { return nil }
            return attackAfter(pieceKind, path, target: target)
        case .twoPieces:
            guard parts.count == 4, let starts = VisualizationPiece.parse(parts[1]), starts.count == 2,
                  let moves = VisualizationPiece.parse(parts[2]), let target = VisualizationSquare(parts[3]) else { return nil }
            return twoPieces(starts, moves, target: target)
        case .isCheck, .hangingPiece, .squareAttacked:
            guard parts.count >= 2, let position = VisualizationPiece.parse(parts[1]) else { return nil }
            switch kind {
            case .isCheck: return isCheck(position)
            case .hangingPiece: return hangingPiece(position, using: &rng)
            default:
                guard parts.count == 3, let target = VisualizationSquare(parts[2]) else { return nil }
                return squareAttacked(position, target: target)
            }
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

    /// « Court », « Moyen », « Long » — 5, 10 et 15 s pour une case : des MOTS plutôt que des secondes dans le menu
    /// (retour de l'utilisateur, 18/11/2026) ; le temps grandit de toute façon avec la marche (Long : une minute pour
    /// une position).
    static let secondsChoices = [5, 10, 15]

    /// Clé française du nom d'un chrono (localisée par l'appelant).
    static func timerTitle(_ seconds: Int) -> String { seconds <= 5 ? "Court" : seconds <= 10 ? "Moyen" : "Long" }
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

// MARK: - Lot 2 : les pièces, et ce qu'elles attaquent

/// Une pièce, notée en lettres anglaises dans les clés (« N », « b »…) et montrée en FIGURINES (♘) : la même
/// écriture dans les cinq langues.
enum VisualizationPieceKind: String, Codable, CaseIterable {
    case king = "K", queen = "Q", rook = "R", bishop = "B", knight = "N", pawn = "P"

    var whiteFigurine: String {
        switch self {
        case .king: "♔"
        case .queen: "♕"
        case .rook: "♖"
        case .bishop: "♗"
        case .knight: "♘"
        case .pawn: "♙"
        }
    }

    var blackFigurine: String {
        switch self {
        case .king: "♚"
        case .queen: "♛"
        case .rook: "♜"
        case .bishop: "♝"
        case .knight: "♞"
        case .pawn: "♟"
        }
    }
}

struct VisualizationPiece: Hashable {
    let kind: VisualizationPieceKind
    let isWhite: Bool
    let square: VisualizationSquare

    /// La figurine, forcée en TEXTE (sans le sélecteur, ♟ s'affiche en émoji).
    var figurine: String { (isWhite ? kind.whiteFigurine : kind.blackFigurine) + "\u{FE0E}" }
    var label: String { figurine + square.notation }
    /// « Ng1 » (blanc), « kg8 » (noir).
    var code: String { (isWhite ? kind.rawValue : kind.rawValue.lowercased()) + square.notation }

    init(_ kind: VisualizationPieceKind, white: Bool = true, _ square: VisualizationSquare) {
        self.kind = kind
        isWhite = white
        self.square = square
    }

    init?(code: String) {
        guard code.count == 3, let first = code.first, let kind = VisualizationPieceKind(rawValue: first.uppercased()),
              let square = VisualizationSquare(String(code.dropFirst())) else { return nil }
        self.init(kind, white: first.isUppercase, square)
    }

    static func codes(_ pieces: [VisualizationPiece]) -> String { pieces.map(\.code).joined(separator: ",") }

    static func parse(_ text: String) -> [VisualizationPiece]? {
        let pieces = text.split(separator: ",").map { VisualizationPiece(code: String($0)) }
        return pieces.contains(where: { $0 == nil }) ? nil : pieces.compactMap { $0 }
    }
}

enum VisualizationAttacks {
    private static let straight = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    private static let diagonal = [(1, 1), (1, -1), (-1, 1), (-1, -1)]

    /// Les cases qu'attaque une pièce ; une ligne s'arrête sur la première case OCCUPÉE (comprise).
    static func from(_ kind: VisualizationPieceKind, white: Bool = true, at s: VisualizationSquare,
                     occupied: Set<VisualizationSquare> = []) -> Set<VisualizationSquare> {
        func rays(_ directions: [(Int, Int)]) -> Set<VisualizationSquare> {
            var result = Set<VisualizationSquare>()
            for (df, dr) in directions {
                var current = s
                while let next = current.offset(df, dr) {
                    result.insert(next)
                    if occupied.contains(next) { break }
                    current = next
                }
            }
            return result
        }
        switch kind {
        case .king: return Set((straight + diagonal).compactMap { s.offset($0.0, $0.1) })
        case .queen: return rays(straight + diagonal)
        case .rook: return rays(straight)
        case .bishop: return rays(diagonal)
        case .knight: return Set(KnightDistance.jumps.compactMap { s.offset($0.0, $0.1) })
        case .pawn: return Set([-1, 1].compactMap { s.offset($0, white ? 1 : -1) })
        }
    }

    /// Tout ce qu'attaque un camp dans une position.
    static func by(white: Bool, in position: [VisualizationPiece]) -> Set<VisualizationSquare> {
        let occupied = Set(position.map(\.square))
        return position.filter { $0.isWhite == white }.reduce(into: Set()) {
            $0.formUnion(from($1.kind, white: $1.isWhite, at: $1.square, occupied: occupied))
        }
    }
}

extension VisualizationGenerator {
    // MARK: Marche 3 — suivre les pièces

    static let travellers: [VisualizationPieceKind] = [.knight, .bishop, .rook, .queen, .king]

    /// Un trajet LÉGAL sur un plateau vide : le départ, puis `steps` coups, sans repasser par une case.
    static func legalPath<R: RandomNumberGenerator>(_ kind: VisualizationPieceKind, steps: Int,
                                                    using rng: inout R) -> [VisualizationSquare] {
        while true {
            var path = [VisualizationSquare.all.randomElement(using: &rng)!]
            for _ in 0..<steps {
                let options = VisualizationAttacks.from(kind, at: path.last!).subtracting(path)
                guard let next = options.sorted().randomElement(using: &rng) else { break }
                path.append(next)
            }
            if path.count == steps + 1 { return path }
        }
    }

    static func isLegalPath(_ kind: VisualizationPieceKind, _ path: [VisualizationSquare]) -> Bool {
        zip(path, path.dropFirst()).allSatisfy { VisualizationAttacks.from(kind, at: $0).contains($1) }
    }

    static func pathCheck(_ kind: VisualizationPieceKind, _ path: [VisualizationSquare]) -> VisualizationQuestion {
        VisualizationQuestion(kind: .pathCheck, squares: [], line: nil, diagonal: nil,
                              answer: isLegalPath(kind, path) ? .yes : .no, choices: [.yes, .no],
                              moves: path.map { VisualizationPiece(kind, $0) })
    }

    /// Trois coups ; « impossible » : UN coup déplacé d'une case — le piège qu'on veut travailler.
    static func randomPathCheck<R: RandomNumberGenerator>(possible: Bool, using rng: inout R) -> VisualizationQuestion {
        let kind = travellers.randomElement(using: &rng)!
        while true {
            var path = legalPath(kind, steps: 3, using: &rng)
            if !possible {
                let i = Int.random(in: 1...3, using: &rng)
                let candidates = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]
                    .compactMap { path[i].offset($0.0, $0.1) }
                    .filter { !path.contains($0) && !VisualizationAttacks.from(kind, at: path[i - 1]).contains($0) }
                guard let wrong = candidates.randomElement(using: &rng) else { continue }
                path[i] = wrong
            }
            return pathCheck(kind, path)
        }
    }

    static func attackAfter(_ kind: VisualizationPieceKind, _ path: [VisualizationSquare],
                            target: VisualizationSquare) -> VisualizationQuestion {
        let attacked = VisualizationAttacks.from(kind, at: path.last!).contains(target)
        return VisualizationQuestion(kind: .attackAfter, squares: [target], line: nil, diagonal: nil,
                                     answer: attacked ? .yes : .no, choices: [.yes, .no],
                                     moves: path.map { VisualizationPiece(kind, $0) })
    }

    /// Deux coups ; la case visée est attaquée, ou en est tout près.
    static func randomAttackAfter<R: RandomNumberGenerator>(attacked: Bool, using rng: inout R) -> VisualizationQuestion {
        let kind = travellers.randomElement(using: &rng)!
        while true {
            let path = legalPath(kind, steps: 2, using: &rng)
            let end = path.last!
            let attackedSet = VisualizationAttacks.from(kind, at: end)
            let pool: [VisualizationSquare] = attacked
                ? attackedSet.sorted()
                : VisualizationSquare.all.filter {
                    !attackedSet.contains($0) && $0 != end && max(abs($0.file - end.file), abs($0.rank - end.rank)) <= 3
                }
            guard let target = pool.randomElement(using: &rng) else { continue }
            return attackAfter(kind, path, target: target)
        }
    }

    /// Les deux pièces après leurs coups, et qui attaque la case visée (l'une peut masquer l'autre).
    static func twoPieces(_ starts: [VisualizationPiece], _ moves: [VisualizationPiece],
                          target: VisualizationSquare) -> VisualizationQuestion {
        var a = starts[0].square
        var b = starts[1].square
        for move in moves {
            if move.kind == starts[0].kind { a = move.square } else { b = move.square }
        }
        let occupied: Set = [a, b]
        let byA = VisualizationAttacks.from(starts[0].kind, at: a, occupied: occupied).contains(target)
        let byB = VisualizationAttacks.from(starts[1].kind, at: b, occupied: occupied).contains(target)
        let answer: String = byA && byB ? "both" : byA ? "first" : byB ? "second" : "none"
        return VisualizationQuestion(kind: .twoPieces, squares: [target], line: nil, diagonal: nil,
                                     answer: .option(answer),
                                     choices: ["first", "second", "both", "none"].map { .option($0) },
                                     pieces: starts, moves: moves)
    }

    static func randomTwoPieces<R: RandomNumberGenerator>(using rng: inout R) -> VisualizationQuestion {
        let wanted = ["first", "second", "both", "none"].randomElement(using: &rng)!
        while true {
            let kinds = Array([VisualizationPieceKind.knight, .bishop, .rook, .queen].shuffled(using: &rng).prefix(2))
            let a0 = VisualizationSquare.all.randomElement(using: &rng)!
            let b0 = VisualizationSquare.all.randomElement(using: &rng)!
            guard a0 != b0 else { continue }
            var current = [a0, b0]
            var moves: [VisualizationPiece] = []
            for mover in [0, 1, 0] {
                let other = current[1 - mover]
                let options = VisualizationAttacks.from(kinds[mover], at: current[mover], occupied: [other])
                    .subtracting([other]).sorted()
                guard let next = options.randomElement(using: &rng) else { break }
                current[mover] = next
                moves.append(VisualizationPiece(kinds[mover], next))
            }
            guard moves.count == 3 else { continue }
            let starts = [VisualizationPiece(kinds[0], a0), VisualizationPiece(kinds[1], b0)]
            let targets = VisualizationSquare.all.filter { !current.contains($0) }.shuffled(using: &rng)
            if let target = targets.first(where: { twoPieces(starts, moves, target: $0).answer == .option(wanted) }) {
                return twoPieces(starts, moves, target: target)
            }
        }
    }

    // MARK: Marche 4 — la position sans plateau

    /// Deux rois qui ne se touchent pas, deux ou trois pièces de chaque côté (une dame au plus), des pions hors des
    /// bords ; le roi blanc n'est pas en échec.
    static func randomPosition<R: RandomNumberGenerator>(using rng: inout R) -> [VisualizationPiece] {
        let pool: [VisualizationPieceKind] = [.queen, .rook, .rook, .bishop, .bishop, .knight, .knight, .pawn, .pawn]
        while true {
            var taken = Set<VisualizationSquare>()
            func free(pawn: Bool) -> VisualizationSquare? {
                let candidates = VisualizationSquare.all.filter { !taken.contains($0) && (!pawn || (1...6).contains($0.rank)) }
                return candidates.randomElement(using: &rng)
            }
            var position: [VisualizationPiece] = []
            guard let wk = free(pawn: false) else { continue }
            taken.insert(wk)
            position.append(VisualizationPiece(.king, white: true, wk))
            guard let bk = free(pawn: false), max(abs(bk.file - wk.file), abs(bk.rank - wk.rank)) > 1 else { continue }
            taken.insert(bk)
            position.append(VisualizationPiece(.king, white: false, bk))
            for white in [true, false] {
                let count = Int.random(in: 2...3, using: &rng)
                var kinds = Array(pool.shuffled(using: &rng).prefix(count))
                if kinds.filter({ $0 == .queen }).count > 1 { kinds = kinds.map { $0 == .queen ? .rook : $0 } }
                for kind in kinds {
                    guard let s = free(pawn: kind == .pawn) else { continue }
                    taken.insert(s)
                    position.append(VisualizationPiece(kind, white: white, s))
                }
            }
            if VisualizationAttacks.by(white: false, in: position).contains(wk) { continue }
            return position
        }
    }

    static func isCheck(_ position: [VisualizationPiece]) -> VisualizationQuestion {
        let blackKing = position.first { $0.kind == .king && !$0.isWhite }!.square
        let check = VisualizationAttacks.by(white: true, in: position).contains(blackKing)
        return VisualizationQuestion(kind: .isCheck, squares: [], line: nil, diagonal: nil,
                                     answer: check ? .yes : .no, choices: [.yes, .no], pieces: position)
    }

    static func randomIsCheck<R: RandomNumberGenerator>(check: Bool, using rng: inout R) -> VisualizationQuestion {
        for _ in 0..<400 {
            let q = isCheck(randomPosition(using: &rng))
            if q.answer == (check ? .yes : .no) { return q }
        }
        return isCheck(randomPosition(using: &rng))
    }

    /// Les pièces noires (hors roi) attaquées par les Blancs et que rien de noir ne défend.
    static func hanging(in position: [VisualizationPiece]) -> [VisualizationPiece] {
        let byWhite = VisualizationAttacks.by(white: true, in: position)
        let byBlack = VisualizationAttacks.by(white: false, in: position)
        return position.filter { !$0.isWhite && $0.kind != .king && byWhite.contains($0.square) && !byBlack.contains($0.square) }
    }

    /// `nil` si la position n'a pas UNE réponse (deux pièces en prise) ou trop peu de pièces noires à proposer.
    static func hangingPiece<R: RandomNumberGenerator>(_ position: [VisualizationPiece], using rng: inout R) -> VisualizationQuestion? {
        let blacks = position.filter { !$0.isWhite && $0.kind != .king }
        let hung = hanging(in: position)
        guard blacks.count >= 2, hung.count <= 1 else { return nil }
        let answer: VisualizationAnswer = hung.first.map { .square($0.square) } ?? .option("none")
        let choices = blacks.shuffled(using: &rng).map { VisualizationAnswer.square($0.square) } + [.option("none")]
        return VisualizationQuestion(kind: .hangingPiece, squares: [], line: nil, diagonal: nil,
                                     answer: answer, choices: choices, pieces: position)
    }

    static func randomHangingPiece<R: RandomNumberGenerator>(one: Bool, using rng: inout R) -> VisualizationQuestion {
        var fallback: VisualizationQuestion?
        for _ in 0..<600 {
            guard let q = hangingPiece(randomPosition(using: &rng), using: &rng) else { continue }
            if (q.answer != .option("none")) == one { return q }
            fallback = fallback ?? q
        }
        if let fallback { return fallback }
        while true { if let q = hangingPiece(randomPosition(using: &rng), using: &rng) { return q } }
    }

    static func squareAttacked(_ position: [VisualizationPiece], target: VisualizationSquare) -> VisualizationQuestion {
        let attacked = VisualizationAttacks.by(white: true, in: position).contains(target)
        return VisualizationQuestion(kind: .squareAttacked, squares: [target], line: nil, diagonal: nil,
                                     answer: attacked ? .yes : .no, choices: [.yes, .no], pieces: position)
    }

    static func randomSquareAttacked<R: RandomNumberGenerator>(attacked: Bool, using rng: inout R) -> VisualizationQuestion {
        while true {
            let position = randomPosition(using: &rng)
            let occupied = Set(position.map(\.square))
            let byWhite = VisualizationAttacks.by(white: true, in: position)
            let pool = VisualizationSquare.all.filter { !occupied.contains($0) && byWhite.contains($0) == attacked }
            if let target = pool.randomElement(using: &rng) { return squareAttacked(position, target: target) }
        }
    }
}
