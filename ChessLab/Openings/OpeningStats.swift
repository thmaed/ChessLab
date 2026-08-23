import Foundation

/// Données SIDECAR du module Ouvertures : pour chaque position d'un cours, ce
/// que jouent les MAÎTRES et ce que dit STOCKFISH.
///
/// ## Pourquoi à côté du cours et non dedans
///
/// Les cours (`openings/<id>.json`) sont la donnée du module d'ouvertures en
/// production. Trois raisons de ne pas y toucher :
///
/// 1. **Risque.** Y ajouter des champs, c'est faire porter une régression
///    possible au décodage de tous les cours, y compris les finales, pour une
///    donnée que seules les ouvertures affichent.
/// 2. **Ce n'est pas la même donnée.** ``MoveEdge/gamesMasters`` ne décrit que
///    les arêtes CURÉES du graphe ; l'écran veut tous les coups de maîtres de
///    la position, y compris ceux que le cours ne retient pas.
/// 3. **Coût.** Le sidecar ne se charge que pour l'ouverture ouverte, et un
///    seul reste en mémoire à la fois.
///
/// Indexation par FEN NORMALISÉE (``OpeningFENKey``), exactement comme le
/// graphe : les transpositions partagent leur entrée, et le sidecar survit à
/// une régénération des arbres.
///
/// Décodage DÉFENSIF, comme partout ailleurs dans le projet : un fichier
/// absent, partiel ou corrompu donne « pas de donnée » — jamais un crash, et
/// jamais un écran vide (l'app dit ce qui manque).
enum OpeningStatsSchema {
    static let currentVersion = 1
}

/// Un coup joué par des maîtres dans une position, avec son bilan.
///
/// Les pourcentages ne sont PAS stockés : ils se dérivent de `games` et du
/// total de la position. Stocker les deux, c'est stocker deux vérités qui
/// peuvent diverger — et payer des octets pour ça sur cinq mille positions.
struct OpeningMasterMove: Codable, Hashable, Sendable, Identifiable {
    let san: String
    let uci: String
    private var games_: Int?
    private var white_: Int?
    private var draws_: Int?
    private var black_: Int?
    private var elo_: Int?
    /// Code ECO atteint par ce coup, quand Lichess le nomme.
    var eco: String?
    /// Nom de la variante atteinte (« Sicilian Defense ») — sert de sous-titre
    /// aux lignes de l'index.
    var name: String?

    enum CodingKeys: String, CodingKey {
        case san, uci, eco, name
        case games_ = "g"
        case white_ = "w"
        case draws_ = "d"
        case black_ = "b"
        case elo_ = "elo"
    }

    var id: String { uci }
    var games: Int { games_ ?? 0 }
    var whiteWins: Int { white_ ?? 0 }
    var draws: Int { draws_ ?? 0 }
    var blackWins: Int { black_ ?? 0 }
    /// Elo moyen des parties, quand il est connu.
    var averageRating: Int? { elo_ }

    /// Score des BLANCS sur ce coup (nulle = ½), dans 0...1 — `nil` si aucune
    /// partie (on n'affiche pas « 50 % » là où on ne sait rien).
    var whiteScore: Double? {
        guard games > 0 else { return nil }
        return (Double(whiteWins) + Double(draws) / 2) / Double(games)
    }

    init(
        san: String, uci: String, games: Int, white: Int, draws: Int, black: Int,
        averageRating: Int? = nil, eco: String? = nil, name: String? = nil
    ) {
        self.san = san
        self.uci = uci
        self.games_ = games
        self.white_ = white
        self.draws_ = draws
        self.black_ = black
        self.elo_ = averageRating
        self.eco = eco
        self.name = name
    }
}

/// Le bilan MAÎTRES d'une position : combien de parties y sont passées, et par
/// quels coups elles en sont sorties.
struct OpeningMasterStats: Codable, Hashable, Sendable {
    private var white_: Int?
    private var draws_: Int?
    private var black_: Int?
    private var moves_: [OpeningMasterMove]?

    enum CodingKeys: String, CodingKey {
        case white_ = "w"
        case draws_ = "d"
        case black_ = "b"
        case moves_ = "moves"
    }

    var whiteWins: Int { white_ ?? 0 }
    var draws: Int { draws_ ?? 0 }
    var blackWins: Int { black_ ?? 0 }
    var moves: [OpeningMasterMove] { moves_ ?? [] }

    /// Parties de maîtres ayant atteint cette position.
    var totalGames: Int { whiteWins + draws + blackWins }

    /// Part de ce coup parmi les parties de la position (0...1).
    ///
    /// Rapportée au TOTAL de la position, pas à la somme des coups retenus :
    /// le générateur écarte la queue statistique (coups sous 0,5 %), et
    /// renormaliser sur les seuls survivants gonflerait leurs parts jusqu'à
    /// afficher un total de 100 % là où il en manque cinq.
    func share(of move: OpeningMasterMove) -> Double {
        guard totalGames > 0 else { return 0 }
        return Double(move.games) / Double(totalGames)
    }

    init(white: Int, draws: Int, black: Int, moves: [OpeningMasterMove]) {
        self.white_ = white
        self.draws_ = draws
        self.black_ = black
        self.moves_ = moves
    }
}

/// Une ligne du moteur, calculée d'AVANCE (MultiPV, rang implicite par
/// l'ordre du tableau).
///
/// Évaluation TOUJOURS du point de vue des BLANCS, comme le champ `eval` des
/// cours et comme ``EvalBarView`` — une seule convention dans toute l'app, ce
/// qui évite l'inversion de signe la plus classique du domaine.
struct OpeningEngineLine: Codable, Hashable, Sendable, Identifiable {
    let san: String
    let uci: String
    /// Centipions (point de vue blanc). Absent si la ligne est un mat.
    var cp: Int?
    /// Mat en N (positif = les blancs matent). Absent sinon.
    var mate: Int?

    var id: String { uci }

    init(san: String, uci: String, cp: Int? = nil, mate: Int? = nil) {
        self.san = san
        self.uci = uci
        self.cp = cp
        self.mate = mate
    }
}

/// Ce que Labs sait d'une position. Les deux champs sont indépendamment
/// facultatifs : le moteur couvre tout, les maîtres non (une position de
/// profondeur 20 dans une sous-variante n'a jamais été jouée en tournoi).
struct OpeningPositionStats: Codable, Hashable, Sendable {
    var masters: OpeningMasterStats?
    private var engine_: [OpeningEngineLine]?

    enum CodingKeys: String, CodingKey {
        case masters
        case engine_ = "engine"
    }

    /// Les meilleurs coups du moteur, au plus trois (le prompt) — borné ICI et
    /// pas seulement à la génération, pour qu'un fichier plus bavard (version
    /// future, fichier bricolé) ne fasse pas déborder l'affichage.
    var engine: [OpeningEngineLine] { Array((engine_ ?? []).prefix(3)) }

    var isEmpty: Bool { masters == nil && engine.isEmpty }

    init(masters: OpeningMasterStats? = nil, engine: [OpeningEngineLine] = []) {
        self.masters = masters
        self.engine_ = engine
    }
}

/// Le sidecar d'un cours : ses positions, indexées par clé FEN normalisée.
struct OpeningStatsSidecar: Codable, Hashable, Sendable {
    var schemaVersion: Int?
    let id: String
    /// Profondeur à laquelle le moteur a été passé — affichée dans l'app,
    /// parce qu'une évaluation sans sa profondeur ne veut pas dire grand-chose.
    var engineDepth: Int?
    let positions: [String: OpeningPositionStats]

    func data(at fen: String) -> OpeningPositionStats? { positions[fen] }

    init(schemaVersion: Int? = OpeningStatsSchema.currentVersion, id: String, engineDepth: Int? = nil, positions: [String: OpeningPositionStats]) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.engineDepth = engineDepth
        self.positions = positions
    }
}

/// Charge les sidecars — un fichier par cours, à la demande.
///
/// Un cours sans sidecar (répertoire importé par l'utilisateur, ouverture
/// ajoutée depuis la dernière génération) donne un sidecar VIDE plutôt que
/// `nil` : l'écran s'affiche normalement, seules les sections statistiques
/// disent qu'elles n'ont rien. C'est le même parti que le reste du module —
/// la donnée manquante ne doit jamais retirer une fonctionnalité.
@MainActor
enum OpeningStatsLoader {
    /// Un seul sidecar gardé en mémoire : le lecteur en ouvre un à la fois, et
    /// les garder tous ferait grossir la mémoire au fil de la navigation
    /// (~40 Ko par ouverture, cinquante-huit ouvertures).
    private static var cached: (id: String, sidecar: OpeningStatsSidecar)?

    /// Sous-dossier de ressources — même convention que `openings/`.
    static let subdirectory = "openings_stats"

    static func sidecar(id: String, in bundle: Bundle = .main) -> OpeningStatsSidecar {
        if let cached, cached.id == id { return cached.sidecar }
        let loaded = load(id: id, in: bundle) ?? OpeningStatsSidecar(id: id, positions: [:])
        cached = (id, loaded)
        return loaded
    }

    /// Vide le cache mémoire (tests).
    static func flush() { cached = nil }

    private static func load(id: String, in bundle: Bundle) -> OpeningStatsSidecar? {
        guard
            let url = url(id: id, in: bundle),
            let data = try? Data(contentsOf: url),
            let sidecar = try? JSONDecoder().decode(OpeningStatsSidecar.self, from: data)
        else {
            return nil
        }
        return sidecar
    }

    private static func url(id: String, in bundle: Bundle) -> URL? {
        // Le nom porte « .stats » pour ne pas entrer en collision avec le
        // cours du même identifiant si un dossier de ressources se retrouvait
        // aplati au moment de la copie (c'est déjà arrivé, cf.
        // `OpeningCourseLoader`).
        bundle.url(forResource: "\(id).stats", withExtension: "json", subdirectory: subdirectory)
            ?? bundle.url(forResource: "\(id).stats", withExtension: "json")
    }

    /// Décode depuis des octets bruts — pour les tests, sans dépendance au bundle.
    nonisolated static func decode(from data: Data) throws -> OpeningStatsSidecar {
        try JSONDecoder().decode(OpeningStatsSidecar.self, from: data)
    }
}
