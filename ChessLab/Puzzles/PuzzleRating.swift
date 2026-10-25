import Foundation

/// La cote de puzzle PERSONNELLE du joueur (B3, 24/10/2026), sur l'échelle des
/// puzzles Lichess — celle de ``Puzzle/rating``.
///
/// Méthode : Glicko (v1), un puzzle comptant pour une « partie » contre un
/// adversaire dont la cote est celle du puzzle. Glicko plutôt qu'Elo parce qu'il
/// porte sa propre INCERTITUDE (`deviation`) : une cote de départ n'est qu'une
/// estimation, qui doit bouger vite au début et se stabiliser ensuite — et
/// l'écran peut dire « environ 1 480 » tant qu'elle n'est pas sûre.
///
/// Valeur pure : aucune horloge, aucune base — vérifiable en test.
///
/// - note: Un puzzle réussi AVEC l'indice ne rapporte rien et coûte quelques
///   points (décision du 25/10/2026, voir ``hintPenalty``) ; les puzzles tirés de vos parties n'ont pas de cote et ne
///   comptent pas ; un programme Woodpecker n'y touche pas (rejouer les mêmes
///   puzzles gonflerait la cote).
struct PuzzleRating: Codable, Equatable {
    var rating: Double = 1500
    var deviation: Double = 350
    var count: Int = 0

    static let initial = PuzzleRating()
    /// L'incertitude ne descend pas sous ce plancher : la cote reste mobile.
    static let minDeviation = 60.0
    /// Incertitude supposée de la cote d'un puzzle de la bibliothèque.
    static let puzzleDeviation = 80.0
    /// Nombre de puzzles à partir duquel on parle de « votre cote » sans « environ ».
    static let settledCount = 10

    private static let q = log(10.0) / 400.0

    private static func g(_ deviation: Double) -> Double {
        1 / sqrt(1 + 3 * q * q * deviation * deviation / (.pi * .pi))
    }

    /// Un puzzle réussi avec l'indice vaut ce que la formule attendait MOINS cette
    /// part : la cote ne peut pas monter, et perd quelques points (environ 3 sur
    /// un puzzle de son niveau, contre 10 pour un échec franc). Sans cela l'indice
    /// serait gratuit, et gonflerait la cote de qui hésite.
    static let hintPenalty = 0.15

    /// Enregistre un puzzle de cote `puzzleRating`, réussi ou non.
    /// - Parameter usedHint: l'indice a été demandé ; ne compte que si le puzzle
    ///   est réussi (un échec reste un échec).
    mutating func record(solved: Bool, usedHint: Bool = false, againstPuzzleRated puzzleRating: Int) {
        let gj = Self.g(Self.puzzleDeviation)
        let expected = 1 / (1 + pow(10, -gj * (rating - Double(puzzleRating)) / 400))
        let dSquared = 1 / (Self.q * Self.q * gj * gj * expected * (1 - expected))
        let precision = 1 / (deviation * deviation) + 1 / dSquared
        let score: Double
        if !solved { score = 0 } else if usedHint { score = max(0, expected - Self.hintPenalty) } else { score = 1 }
        rating += Self.q / precision * gj * (score - expected)
        deviation = max(Self.minDeviation, sqrt(1 / precision))
        count += 1
    }

    /// La cote arrondie, telle qu'on l'affiche.
    var displayed: Int { Int(rating.rounded()) }

    /// Une cote encore jeune s'annonce « environ ».
    var isSettled: Bool { count >= Self.settledCount }

    /// La fenêtre de puzzles « à mon niveau » : la cote ± une demi-largeur qui
    /// suit l'incertitude (100 au plus serré, 250 au plus large).
    var window: ClosedRange<Int> {
        let half = min(250, max(100, deviation * 0.6))
        let low = max(400, Int((rating - half).rounded()))
        let high = max(low + 1, Int((rating + half).rounded()))
        return low...high
    }
}

/// Où la cote vit : `UserDefaults`, sous une clé que ``SettingsCloudSync``
/// fait voyager — la dernière écriture gagne, ce qui suffit à un nombre qui
/// n'évolue que de quelques points par puzzle.
enum PuzzleRatingStore {
    static let key = "puzzleRating.v1"

    static func load(from defaults: UserDefaults = .standard) -> PuzzleRating {
        guard let data = defaults.data(forKey: key),
              let rating = try? JSONDecoder().decode(PuzzleRating.self, from: data)
        else { return .initial }
        return rating
    }

    static func save(_ rating: PuzzleRating, to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(rating) {
            defaults.set(data, forKey: key)
        }
    }

    /// Lit, met à jour, écrit. Rend la cote d'APRÈS.
    @discardableResult
    static func record(
        solved: Bool, usedHint: Bool = false, againstPuzzleRated puzzleRating: Int, in defaults: UserDefaults = .standard
    ) -> PuzzleRating {
        var current = load(from: defaults)
        current.record(solved: solved, usedHint: usedHint, againstPuzzleRated: puzzleRating)
        save(current, to: defaults)
        return current
    }
}
