import ChessKit
import Foundation

/// Version du schéma des cours d'ouverture embarqués (le NOUVEAU modèle en
/// graphe, distinct des 149 familles linéaires (``OpeningTheoryEntry``) qui
/// restent en place pendant la bascule progressive).
///
/// Incrémentée à chaque changement de format non rétro-compatible. La
/// progression de l'utilisateur, elle, n'est JAMAIS versionnée par ce numéro :
/// elle est indexée par FEN normalisée (voir ``OpeningFENKey``) et survit à
/// toute régénération d'un arbre — c'est la règle architecturale fondamentale
/// du module.
enum OpeningSchema {
    static let currentVersion = 1
}

/// Camp d'étude d'un cours (perspective d'apprentissage). Format de fichier
/// STABLE et lisible (« white »/« black ») — délibérément indépendant du
/// `rawValue` de `Piece.Color` (ChessKit), pour que la donnée générée ne se
/// couple pas à une lib.
enum OpeningSide: String, Codable, Hashable, Sendable {
    case white
    case black

    var color: Piece.Color { self == .white ? .white : .black }

    init(_ color: Piece.Color) { self = color == .white ? .white : .black }
}

/// Niveau pédagogique indicatif d'un cours (pour filtrer/étiqueter).
enum OpeningLevel: String, Codable, Hashable, Sendable {
    case beginner
    case club
    case advanced
}

/// Rôle d'une arête dans le graphe — pilote l'affichage (ligne principale
/// mise en avant, piège signalé…) et, plus tard, la priorité d'entraînement.
enum MoveRole: String, Codable, Hashable, Sendable {
    case mainLine
    case sideline
    case trap
    case refutation
    case inaccuracy
}

/// Statut d'un commentaire pédagogique. RÈGLE STRICTE : l'UI n'affiche jamais
/// un `draft` comme du contenu définitif (voir ``MoveEdge/displayableComment``).
/// Les commentaires sont rédigés à la main, jamais générés automatiquement.
enum OpeningCommentStatus: String, Codable, Hashable, Sendable {
    case draft
    case validated
}

/// Texte BILINGUE (français / anglais) porté par la DONNÉE d'ouverture — les
/// commentaires, plans et résumés sont rédigés dans les deux langues et résolus
/// à l'exécution selon la langue de l'app (``AppLanguage/resolvedCode``).
///
/// Décodage souple : accepte soit un objet `{"fr": "...", "en": "..."}`, soit
/// une simple chaîne (appliquée aux deux langues) — pratique pour l'ébauche.
struct LocalizedText: Codable, Hashable, Sendable {
    var fr: String?
    var en: String?

    init(fr: String? = nil, en: String? = nil) {
        self.fr = fr
        self.en = en
    }

    /// Même texte dans les deux langues (utilitaire d'écriture/tests).
    static func both(_ text: String) -> LocalizedText { LocalizedText(fr: text, en: text) }

    enum CodingKeys: String, CodingKey { case fr, en }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            fr = single
            en = single
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fr = try container.decodeIfPresent(String.self, forKey: .fr)
        en = try container.decodeIfPresent(String.self, forKey: .en)
    }

    /// Texte pour un code langue (« fr »/« en »), avec repli sur l'autre langue,
    /// puis `nil` si les deux sont vides.
    func resolved(_ code: String) -> String? {
        let primary = code == "fr" ? fr : en
        let fallback = code == "fr" ? en : fr
        if let primary, !primary.isEmpty { return primary }
        if let fallback, !fallback.isEmpty { return fallback }
        return nil
    }
}

/// Une arête du graphe : un coup jouable depuis un ``PositionNode`` vers un
/// autre nœud (`toFEN`, clé FEN normalisée d'arrivée).
///
/// Décodage DÉFENSIF, même discipline que ``GameRecord``/``Puzzle`` : seuls
/// `san`/`uci`/`toFEN` (toujours produits par le générateur) sont requis ;
/// tout le reste est optionnel avec repli, pour qu'une donnée partielle ou
/// écrite à la main ne fasse jamais échouer le décodage de tout le cours.
struct MoveEdge: Codable, Hashable, Sendable {
    /// Coup en notation algébrique (« Nf3 », « exd5 », « O-O »).
    let san: String
    /// Coup en notation longue/UCI (« g1f3 ») — sert à jouer le coup sur le
    /// plateau sans reparser le SAN, comme le fait déjà le trainer linéaire.
    let uci: String
    /// Clé FEN normalisée du nœud d'arrivée — l'arête pointe vers
    /// `course.positions[toFEN]`.
    let toFEN: String

    private var role_: String?
    /// Statistiques MAÎTRES (théoriquement correct).
    var gamesMasters: Int?
    var popularityMasters: Double?
    /// Statistiques CLUB (base Lichess filtrée ~1400-2000 : ce que
    /// l'utilisateur affronte vraiment). Un coup peut être rare chez les
    /// maîtres et fréquent en club (gambits douteux, anti-siciliennes).
    var gamesClub: Int?
    var popularityClub: Double?
    var scoreWhite: Double?
    var scoreDraw: Double?
    var scoreBlack: Double?
    /// Évaluation moteur en centipions (point de vue des Blancs).
    var eval: Double?
    /// Explication pédagogique BILINGUE — peut rester vide/absente.
    var comment: LocalizedText?
    private var commentStatus_: String?
    private var isCritical_: Bool?

    enum CodingKeys: String, CodingKey {
        case san, uci, toFEN
        case role_ = "role"
        case gamesMasters, popularityMasters, gamesClub, popularityClub
        case scoreWhite, scoreDraw, scoreBlack, eval, comment
        case commentStatus_ = "commentStatus"
        case isCritical_ = "isCritical"
    }

    /// Rôle typé, valeur inconnue repliée sur `.sideline` (jamais d'échec de
    /// décodage sur un rôle inattendu).
    var role: MoveRole { role_.flatMap(MoveRole.init(rawValue:)) ?? .sideline }

    /// À mémoriser impérativement (défaut : `false`).
    var isCritical: Bool { isCritical_ ?? false }

    /// Le commentaire n'est AFFICHABLE comme définitif que s'il est
    /// explicitement `validated`, résolu dans la langue demandée (« fr »/« en »,
    /// repli sur l'autre). Tout le reste (absent, brouillon, statut inconnu)
    /// reste masqué — on ne présente jamais un brouillon comme de la théorie sûre.
    func displayableComment(_ code: String) -> String? {
        guard commentStatus_ == OpeningCommentStatus.validated.rawValue else { return nil }
        return comment?.resolved(code)
    }

    /// Version bilingue brute d'un commentaire validé (résolution différée).
    var validatedComment: LocalizedText? {
        commentStatus_ == OpeningCommentStatus.validated.rawValue ? comment : nil
    }

    init(
        san: String, uci: String, toFEN: String, role: MoveRole = .sideline,
        gamesMasters: Int? = nil, popularityMasters: Double? = nil,
        gamesClub: Int? = nil, popularityClub: Double? = nil,
        scoreWhite: Double? = nil, scoreDraw: Double? = nil, scoreBlack: Double? = nil,
        eval: Double? = nil, comment: LocalizedText? = nil,
        commentStatus: OpeningCommentStatus? = nil, isCritical: Bool = false
    ) {
        self.san = san
        self.uci = uci
        self.toFEN = toFEN
        self.role_ = role.rawValue
        self.gamesMasters = gamesMasters
        self.popularityMasters = popularityMasters
        self.gamesClub = gamesClub
        self.popularityClub = popularityClub
        self.scoreWhite = scoreWhite
        self.scoreDraw = scoreDraw
        self.scoreBlack = scoreBlack
        self.eval = eval
        self.comment = comment
        self.commentStatus_ = commentStatus?.rawValue
        self.isCritical_ = isCritical
    }
}

/// Un nœud du graphe = une POSITION (clé FEN normalisée), avec les coups
/// jouables depuis elle. Deux ordres de coups menant à la même position
/// partagent ce nœud (fusion des transpositions) : c'est tout l'intérêt du
/// graphe indexé par FEN plutôt qu'un arbre.
struct PositionNode: Codable, Hashable, Sendable {
    /// FEN NORMALISÉE = clé du nœud dans ``OpeningCourse/positions``.
    let fen: String
    private var sideToMove_: OpeningSide?
    /// Nom de la variante atteinte à ce point (ex. « Scandinave, variante
    /// Mieses-Kotroc ») — facultatif.
    var ecoName: String?
    /// Plan typique dans cette structure — bilingue, facultatif, rédigé à la main.
    var plan: LocalizedText?
    /// Cases à surligner (ex. [« d5 », « e5 »]) — facultatif.
    var keySquares: [String]?
    private var moves_: [MoveEdge]?

    enum CodingKeys: String, CodingKey {
        case fen
        case sideToMove_ = "sideToMove"
        case ecoName, plan, keySquares
        case moves_ = "moves"
    }

    /// Trait, dérivé de la FEN si le champ est absent (champ 2 : « w »/« b »).
    var sideToMove: OpeningSide {
        if let sideToMove_ { return sideToMove_ }
        let fields = fen.split(separator: " ")
        return fields.count > 1 && fields[1] == "b" ? .black : .white
    }

    /// Coups jouables depuis ce nœud (défaut : aucun = feuille).
    var moves: [MoveEdge] { moves_ ?? [] }

    init(
        fen: String, sideToMove: OpeningSide? = nil, ecoName: String? = nil,
        plan: LocalizedText? = nil, keySquares: [String]? = nil, moves: [MoveEdge] = []
    ) {
        self.fen = fen
        self.sideToMove_ = sideToMove
        self.ecoName = ecoName
        self.plan = plan
        self.keySquares = keySquares
        self.moves_ = moves
    }
}

/// Un chapitre = un regroupement AFFICHABLE de positions (« Ligne principale »,
/// « Contre 3.Cf3 », « Les pièges à connaître ») — pas une liste plate. Il
/// référence des nœuds du graphe par leur FEN.
struct OpeningChapter: Codable, Hashable, Sendable, Identifiable {
    let id: String
    var title: LocalizedText
    var summary: LocalizedText?
    /// FEN (normalisées) des positions couvertes par ce chapitre, dans l'ordre
    /// pédagogique. Chacune doit exister dans ``OpeningCourse/positions``.
    var positionFENs: [String]

    init(id: String, title: LocalizedText, summary: LocalizedText? = nil, positionFENs: [String] = []) {
        self.id = id
        self.title = title
        self.summary = summary
        self.positionFENs = positionFENs
    }
}

/// Un cours d'ouverture complet : le GRAPHE (indexé par FEN normalisée) plus
/// ses regroupements pédagogiques. Décodé depuis un fichier compact par
/// ouverture (chargement paresseux, voir ``OpeningCourseLoader``).
///
/// `Hashable`/`Equatable` par `id` seul (identité stable) : le graphe complet
/// n'est ni hashé ni comparé nœud à nœud, et l'`id` suffit à voyager dans une
/// `NavigationPath` le moment venu.
struct OpeningCourse: Codable, Identifiable, Hashable, Sendable {
    /// Version du schéma ayant produit ce fichier (voir ``OpeningSchema``).
    var schemaVersion: Int?
    let id: String
    let name: String
    var eco: [String]?
    private var side_: OpeningSide?
    private var level_: String?
    var summary: LocalizedText?
    /// Nature du cours : absent = ouverture, `"endgame"` = finale. Les 58
    /// cours d'ouvertures ne portent pas ce champ — le décodage défensif en
    /// fait des ouvertures, rien ne change pour eux.
    var kind: String?
    /// Famille de finales (pawns|rooks|queens|mates|practical) — le critère
    /// de regroupement de l'écran Finales.
    var family: String?
    /// FEN normalisée de la position de départ du cours (souvent la position
    /// initiale, mais pas forcément pour un cours « côté noir »).
    let rootFEN: String
    var chapters: [OpeningChapter]?
    /// Le graphe, indexé par FEN normalisée.
    let positions: [String: PositionNode]

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, eco
        case side_ = "side"
        case level_ = "level"
        case summary, kind, family, rootFEN, chapters, positions
    }

    /// Perspective d'étude (défaut : blancs).
    var side: OpeningSide { side_ ?? .white }
    /// Niveau (défaut : club).
    var level: OpeningLevel { level_.flatMap(OpeningLevel.init(rawValue:)) ?? .club }
    var isEndgame: Bool { kind == "endgame" }

    func node(at fen: String) -> PositionNode? { positions[fen] }
    var rootNode: PositionNode? { positions[rootFEN] }

    static func == (lhs: OpeningCourse, rhs: OpeningCourse) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(
        schemaVersion: Int? = OpeningSchema.currentVersion, id: String, name: String,
        eco: [String]? = nil, side: OpeningSide = .white, level: OpeningLevel = .club,
        summary: LocalizedText? = nil, rootFEN: String, chapters: [OpeningChapter]? = nil,
        positions: [String: PositionNode]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.eco = eco
        self.side_ = side
        self.level_ = level.rawValue
        self.summary = summary
        self.rootFEN = rootFEN
        self.chapters = chapters
        self.positions = positions
    }
}

/// Ligne LÉGÈRE du catalogue (index) : de quoi peupler la liste des cours sans
/// charger le graphe complet de chacun. Le fichier `opening_catalog.json`
/// embarqué en contient une par cours ; le graphe complet vit dans un fichier
/// séparé chargé à la demande.
struct OpeningCatalogEntry: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    var eco: [String]?
    private var side_: OpeningSide?
    private var level_: String?
    var summary: LocalizedText?
    /// Nature du cours : absent = ouverture, `"endgame"` = finale.
    var kind: String?
    /// Famille de finales — voir ``OpeningCourse/family``.
    var family: String?
    /// Nombre de positions du graphe (pour l'affichage « couverture »).
    var positionCount: Int?
    /// Profondeur max en demi-coups (indicatif).
    var maxDepth: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, eco
        case side_ = "side"
        case level_ = "level"
        case summary, kind, family, positionCount, maxDepth
    }

    var side: OpeningSide { side_ ?? .white }
    var level: OpeningLevel { level_.flatMap(OpeningLevel.init(rawValue:)) ?? .club }
    var isEndgame: Bool { kind == "endgame" }

    /// Ligne de catalogue DÉRIVÉE d'un cours complet.
    ///
    /// Les cours embarqués ont un index pré-calculé (`opening_catalog.json`) ;
    /// ceux qu'apporte l'utilisateur n'en ont pas — leur fichier EST le cours.
    /// Cette dérivation évite d'inventer un second format d'index rien que pour
    /// eux. Elle est dans ce fichier parce que `side_`/`level_` y sont privés.
    init(_ course: OpeningCourse) {
        id = course.id
        name = course.name
        eco = course.eco
        side_ = course.side
        level_ = course.level.rawValue
        summary = course.summary
        kind = course.kind
        family = course.family
        positionCount = course.positions.count
        maxDepth = Self.depth(of: course)
    }

    /// Profondeur en demi-coups depuis la racine (parcours en largeur : le
    /// graphe peut contenir des cycles par transposition, un parcours naïf en
    /// profondeur ne terminerait pas).
    private static func depth(of course: OpeningCourse) -> Int {
        var seen: Set<String> = [course.rootFEN]
        var frontier = [course.rootFEN]
        var depth = 0
        while !frontier.isEmpty {
            var next: [String] = []
            for fen in frontier {
                for edge in course.positions[fen]?.moves ?? [] where !seen.contains(edge.toFEN) {
                    seen.insert(edge.toFEN)
                    next.append(edge.toFEN)
                }
            }
            if next.isEmpty { break }
            depth += 1
            frontier = next
        }
        return depth
    }
}

/// Charge les cours d'ouverture embarqués — un fichier par cours (chargement
/// PARESSEUX), plus un index léger. Même schéma défensif que
/// ``OpeningLibraryLoader``/``EcoOpeningLoader`` : fichier manquant/corrompu →
/// résultat vide, jamais de crash (le module retombe sur la bibliothèque
/// linéaire existante pendant la bascule).
enum OpeningCourseLoader {
    /// Index de tous les cours disponibles (décodé une fois par process).
    static let catalog: [OpeningCatalogEntry] = loadCatalog(from: .main)

    static func loadCatalog(from bundle: Bundle) -> [OpeningCatalogEntry] {
        guard
            let url = bundle.url(forResource: "opening_catalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode([OpeningCatalogEntry].self, from: data)
        else {
            return []
        }
        return entries
    }

    /// Charge le graphe complet d'un cours par identifiant. Convention de
    /// nommage : `openings/<id>.json` dans le bundle (sous-dossier de ressources
    /// pour ne pas encombrer la racine du bundle avec des dizaines de fichiers).
    static func course(id: String, in bundle: Bundle = .main) -> OpeningCourse? {
        guard
            let url = courseURL(id: id, in: bundle),
            let data = try? Data(contentsOf: url),
            let course = try? JSONDecoder().decode(OpeningCourse.self, from: data)
        else {
            return nil
        }
        return course
    }

    private static func courseURL(id: String, in bundle: Bundle) -> URL? {
        // Essaie d'abord un sous-dossier « openings », puis la racine du bundle
        // (les ressources d'un dossier synchronisé peuvent être aplaties).
        bundle.url(forResource: id, withExtension: "json", subdirectory: "openings")
            ?? bundle.url(forResource: id, withExtension: "json")
    }

    /// Décode un cours depuis des données brutes — utilisé par les tests et par
    /// tout appelant qui a déjà les octets (pas de dépendance au bundle).
    static func decodeCourse(from data: Data) throws -> OpeningCourse {
        try JSONDecoder().decode(OpeningCourse.self, from: data)
    }
}

/// Les cours DISPONIBLES : ceux du bundle plus ceux qu'a apportés
/// l'utilisateur (voir ``UserOpeningStore``). C'est ce que doit consulter toute
/// l'interface — ``OpeningCourseLoader`` reste, lui, strictement le bundle.
///
/// Isolé sur l'acteur principal parce que le magasin utilisateur l'est (il est
/// observable et se rafraîchit après un import) ; toutes les vues et les view
/// models du module y sont déjà.
@MainActor
enum OpeningCatalog {
    /// Le catalogue complet. Les cours importés passent EN TÊTE : ce sont ceux
    /// que l'utilisateur a choisi d'ajouter, ils ne doivent pas se perdre au
    /// milieu de cinquante-huit ouvertures livrées.
    static var all: [OpeningCatalogEntry] {
        UserOpeningStore.shared.catalog + OpeningCourseLoader.catalog
    }

    /// Charge un cours, quelle que soit sa provenance.
    static func course(id: String) -> OpeningCourse? {
        if UserOpeningStore.isUserCourse(id: id) {
            return UserOpeningStore.shared.course(id: id)
        }
        return OpeningCourseLoader.course(id: id)
    }
}
