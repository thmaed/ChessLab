import Foundation

/// Un puzzle de la bibliothèque Lichess embarquée (`lichess_puzzles.json`),
/// avant insertion en base — voir PROGRESS.md pour les critères
/// d'échantillonnage (échantillon CC0 de `database.lichess.org`, environ
/// 10 000 puzzles répartis uniformément par tranche de rating et par
/// thème tactique).
struct LichessPuzzleEntry: Codable {
    let id: String
    let fen: String
    let solutionLANs: [String]
    let theme: String
    let rating: Int
    /// Phase de partie (``GamePhase``) précalculée par le script de
    /// génération (même heuristique que ``GamePhaseClassifier``) —
    /// stockée telle quelle dans `Puzzle.phaseRaw` au préchargement,
    /// aucun FEN à classifier côté app. Optionnelle pour rester
    /// décodable face à un JSON d'une génération antérieure.
    let phase: String?
}

/// Charge la bibliothèque de puzzles Lichess embarquée — même schéma que
/// ``EcoOpeningLoader``/``OpeningBookLoader``.
enum LichessPuzzleLoader {
    /// Décodée une seule fois par process. Liste vide en cas de fichier
    /// manquant ou corrompu : aucun préchargement n'a lieu, jamais de
    /// crash.
    static let standard: [LichessPuzzleEntry] = load(from: .main)

    static func load(from bundle: Bundle) -> [LichessPuzzleEntry] {
        guard
            let url = bundle.url(forResource: "lichess_puzzles", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let puzzles = try? JSONDecoder().decode([LichessPuzzleEntry].self, from: data)
        else {
            return []
        }
        return puzzles
    }
}
