import Foundation

/// Charge la base ECO embarquée (`eco_openings.json`) — même schéma que
/// ``OpeningBookLoader``.
enum EcoOpeningLoader {
    /// Décodée une seule fois par process. Base vide en cas de fichier
    /// manquant ou corrompu : l'en-tête d'ouverture s'affiche simplement
    /// vide, jamais de crash.
    ///
    /// Base ECO « nommée » : 76 entrées avec code (A04…), mais COURTES
    /// (médiane 2 coups). Sert à NOMMER l'ouverture (le code ECO le plus
    /// précis), pas à mesurer la profondeur de théorie — voir ``bookLines``.
    static let standard: [EcoOpening] = load(from: .main)

    /// Base ÉTENDUE pour la détection « coup de théorie » de la
    /// classification : la base ECO courte COMPLÉTÉE par les lignes de la
    /// bibliothèque d'ouvertures (149 familles, ~11 coups chacune). Sans
    /// elles, la théorie s'arrêtait au premier échange (2 coups) ; avec, un
    /// coup reste « Théorie » tant qu'il suit une ligne principale connue,
    /// bien plus profondément.
    static let bookLines: [EcoOpening] = standard + libraryLines()

    static func load(from bundle: Bundle) -> [EcoOpening] {
        guard
            let url = bundle.url(forResource: "eco_openings", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let openings = try? JSONDecoder().decode([EcoOpening].self, from: data)
        else {
            return []
        }
        return openings
    }

    /// Convertit chaque famille de la bibliothèque en ligne de théorie : le
    /// PGN « 1. e4 1... Nf6 2. e5 … » devient la séquence SAN attendue par
    /// ``EcoOpeningLookup``. `eco` vide : ces lignes servent la PROFONDEUR,
    /// pas le nom (que ``standard`` fournit avec son code).
    private static func libraryLines() -> [EcoOpening] {
        OpeningLibraryLoader.standard.map { entry in
            EcoOpening(eco: "", name: entry.family, moves: sanMoves(fromPGN: entry.pgn))
        }
    }

    /// Extrait la séquence SAN d'un PGN de la bibliothèque : on jette les
    /// jetons de numérotation (`1.`, `1...`) — les seuls à contenir un point —
    /// et l'on garde les coups.
    static func sanMoves(fromPGN pgn: String) -> [String] {
        pgn.split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty && !$0.contains(".") }
    }
}
