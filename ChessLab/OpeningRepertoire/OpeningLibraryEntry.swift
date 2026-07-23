import Foundation

/// Style stratégique d'une ouverture — axe de classement ORTHOGONAL au code
/// ECO (qui range par premiers coups). Regroupe les familles par philosophie :
/// occuper le centre au pion (classique), le contrôler à distance
/// (hypermoderne), ou jouer une formation fixe quel que soit l'adversaire
/// (système). « Irrégulière » recueille tout ce qui ne relève d'aucune des
/// trois — ouvertures fantaisistes ou de premier coup exotique — pour que le
/// filtre reste exhaustif.
///
/// Catégorisation faite à la main (théorie échiquéenne), avec quelques
/// arbitrages assumés sur les cas hybrides : Attaque est-indienne → système,
/// Anglaise → hypermoderne, Catalane → hypermoderne, Sicilienne → classique
/// (répertoire d'apprentissage). Le contrat de valeurs est dans
/// `opening_library.json`.
enum OpeningStyle: String, Codable, CaseIterable, Hashable {
    case classical
    case hypermodern
    case system
    case irregular

    /// Libellé AFFICHÉ (traduit via le catalogue) — voir ``OpeningLibraryView``.
    var label: String {
        switch self {
        case .classical: "Classiques"
        case .hypermodern: "Hypermodernes"
        case .system: "À système"
        case .irregular: "Irrégulières"
        }
    }

    var systemImage: String {
        switch self {
        case .classical: "building.columns.fill"
        case .hypermodern: "sparkles"
        case .system: "square.grid.3x3.fill"
        case .irregular: "questionmark.diamond.fill"
        }
    }
}

/// Une famille d'ouvertures de la bibliothèque ECO embarquée
/// (`opening_library.json`) — générée hors app depuis le jeu de données
/// public `lichess-org/chess-openings` (~3 800 lignes nommées ; pour
/// chaque famille, la ligne la plus longue est retenue telle quelle,
/// voir PROGRESS.md pour le script). `pgn` est une ligne UNIQUE sans
/// variantes imbriquées — le parseur PGN de ChessKit s'est révélé
/// produire des erreurs dès qu'un point de branchement a 2+
/// alternatives dont l'une contient elle-même une sous-variation (voir
/// ``OpeningLibraryTests``), une fusion en arbre par famille n'était
/// donc pas fiable. `pgn` couvre les deux camps à la fois :
/// ``OpeningLineTrainingViewModel`` en tire le camp choisi, l'autre étant
/// simplement auto-joué. `Hashable` pour voyager dans la `NavigationPath`
/// (voir `HomeView.Route.activeOpeningLine`).
struct OpeningLibraryEntry: Codable, Hashable {
    /// Nom de la famille (ex. "Sicilian Defense"), en ANGLAIS dans la
    /// donnée — c'est la clé stable, alignée sur le dataset
    /// `lichess-org/chess-openings` dont ce fichier est généré.
    ///
    /// L'AFFICHAGE, lui, est traduit (demande utilisateur du 19/07/2026,
    /// qui renverse la décision initiale « pas de traduction ») : les 149
    /// familles ont leur nom français dans `Localizable.xcstrings`
    /// (« Partie espagnole » pour "Ruy Lopez", « Défense russe » pour
    /// "Petrov's Defense", conventions Wikipédia FR). Toute vue passe donc
    /// par `Text(LocalizedStringKey(family))` ou
    /// `LocalizationController.string(family)` — JAMAIS `Text(family)`
    /// brut, qui figerait l'anglais.
    let family: String
    /// Lettre de volume ECO (A-E) dominante dans les lignes fusionnées.
    let category: String
    let pgn: String
    /// `false` pour une poignée de familles à une seule ligne trop
    /// courte pour atteindre un coup noir (ex. "Saragossa Opening",
    /// 1. c3 seul) — pas de répertoire "Noirs" proposé dans ce cas, il
    /// serait vide.
    let hasBlack: Bool
    /// Style(s) stratégique(s), en chaînes BRUTES (pas l'enum). PLUSIEURS
    /// possibles : beaucoup d'ouvertures sont de vrais hybrides — l'Attaque
    /// est-indienne est à la fois « système » et « hypermoderne », la Londres
    /// « système » et « classique ». Le premier élément est le style
    /// DOMINANT (identité principale).
    ///
    /// Décodage défensif : chaîne brute optionnelle plutôt qu'un `[OpeningStyle]`
    /// direct — une valeur inattendue est simplement ignorée
    /// (``styleCategories`` la filtre) au lieu de faire échouer le décodage de
    /// TOUTE la bibliothèque, ce qui la viderait.
    var styles: [String]? = nil

    /// Styles typés, valeurs inconnues écartées.
    var styleCategories: [OpeningStyle] {
        (styles ?? []).compactMap(OpeningStyle.init(rawValue:))
    }
}

/// Charge la bibliothèque d'ouvertures embarquée — même schéma que
/// ``LichessPuzzleLoader``/``EcoOpeningLoader``.
enum OpeningLibraryLoader {
    static let standard: [OpeningLibraryEntry] = load(from: .main)

    static func load(from bundle: Bundle) -> [OpeningLibraryEntry] {
        guard
            let url = bundle.url(forResource: "opening_library", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([OpeningLibraryEntry].self, from: data)
        else {
            return []
        }
        return entries
    }
}
