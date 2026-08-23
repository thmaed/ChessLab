import ChessKit
import Foundation
import Observation
import SwiftUI

/// Le lecteur du module « Ouvertures — Labs ».
///
/// Même graphe que le lecteur existant (``OpeningReaderViewModel``), mais une
/// question différente posée à chaque position : au lieu de « quel est le coup
/// suivant de la ligne ? », **« que fait-on ici, et pourquoi ? »** — ce que
/// jouent les maîtres, ce qu'en dit le moteur, ce qu'en dit l'auteur du cours.
///
/// ## Navigation par CHEMIN, pas par pile d'annulation
///
/// L'état de navigation est un simple `path` de coups UCI depuis la racine ;
/// tout le reste (plateau, fil des coups, position courante) s'en déduit en
/// rejouant. Le lecteur existant empile un tuple d'annulation par coup, ce qui
/// marche pour « précédent/suivant » mais ne sait pas SAUTER : or l'index des
/// lignes (écran A) doit pouvoir atterrir sur n'importe quel coup de n'importe
/// quelle ligne. Rejouer vingt coups depuis la position initiale est
/// instantané, et l'état reste par construction cohérent.
@Observable
@MainActor
final class OpeningLabsViewModel {
    let course: OpeningCourse
    let sidecar: OpeningLabsSidecar
    /// L'ARBRE des lignes, calculé une fois — c'est le contenu de l'écran A.
    let tree: OpeningLineTree.Node?
    /// L'arbre aplati en rangées, dans l'ordre de lecture.
    let rows: [OpeningLineTree.Node]
    /// Où chaque position est DÉPLIÉE dans l'arbre : identifiant de la rangée
    /// qui la développe vraiment.
    ///
    /// Sert au renvoi des transpositions : une branche qui s'arrête sur
    /// « transposition » sait ainsi vers quelle rangée envoyer le lecteur. La
    /// rangée qui transpose est exclue de la table — c'est justement celle qui
    /// ne déplie pas.
    private let expansionRows: [String: String]
    /// Nom de la variante qu'OUVRE un coup, indexé par la position atteinte.
    ///
    /// Alimenté par l'arbre de l'index : les deux écrans nomment ainsi les
    /// mêmes lignes de la même façon. Titre de chapitre écrit à la main
    /// d'abord — c'est le plus parlant (« Gambit portugais », « Attaque Fried
    /// Liver ») — nom ECO de la position à défaut.
    private let branchNames: [String: LocalizedText]
    let orientation: Piece.Color

    /// Chemin courant en UCI depuis la racine — LA source de vérité.
    private(set) var path: [String] = []
    private(set) var board: Board
    private(set) var currentKey: String
    private(set) var lastMove: Move?
    private(set) var playedSANs: [String] = []
    /// Commentaire du coup qui a mené ici (validé seulement).
    private(set) var currentComment: String?

    /// L'index est-il ouvert ? Il l'est À L'ARRIVÉE (le prompt : « au moment du
    /// choix du type d'ouverture ») puis se rappelle par l'icône de la barre.
    var isIndexPresented = true

    private let rootBoard: Board
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    init(course: OpeningCourse, sidecar: OpeningLabsSidecar) {
        self.course = course
        self.sidecar = sidecar
        self.orientation = course.side.color
        let position = OpeningFENKey.position(from: course.rootFEN) ?? .standard
        self.rootBoard = Board(position: position)
        self.board = rootBoard
        self.currentKey = course.rootFEN
        let tree = OpeningLineTree.build(
            course: course, languageCode: AppSettings.shared.appLanguage.resolvedCode,
            sidecar: sidecar
        )
        self.tree = tree
        let rows = tree?.flattened ?? []
        self.rows = rows

        var expansions: [String: String] = [:]
        for row in rows {
            // Le dernier coup d'une rangée qui transpose atterrit sur une
            // position dépliée AILLEURS : il ne l'expanse pas.
            let expanding = row.isTransposition ? row.moves.dropLast() : row.moves[...]
            for move in expanding where expansions[move.toFEN] == nil {
                expansions[move.toFEN] = row.id
            }
        }
        self.expansionRows = expansions

        var names: [String: LocalizedText] = [:]
        // Les noms ECO de la donnée d'abord…
        for (fen, node) in course.positions {
            if let eco = node.ecoName { names[fen] = LocalizedText.both(eco) }
        }
        // …puis les titres écrits à la main, qui priment.
        for row in rows where row.depth > 0 {
            guard let head = row.moves.first, let title = row.chapterTitle else { continue }
            names[head.toFEN] = title
        }
        self.branchNames = names
    }

    // MARK: Position courante

    var currentNode: PositionNode? { course.node(at: currentKey) }
    /// Nom de la variante atteinte — le sous-titre de l'écran.
    var positionName: String? { currentNode?.ecoName }
    var plan: String? { currentNode?.plan?.resolved(languageCode) }
    var isRoot: Bool { path.isEmpty }
    var canGoBack: Bool { !path.isEmpty }
    var isEnd: Bool { candidates.isEmpty }

    /// FEN complète (6 champs) — les écrans de réglages des autres modes
    /// attendent une FEN standard, la clé du graphe n'en a que quatre.
    var currentFEN: String {
        OpeningFENKey.position(from: currentKey)?.fen ?? currentKey
    }

    /// Coups du RÉPERTOIRE jouables ici : ligne principale d'abord, puis par
    /// popularité club (même ordre que le lecteur existant, pour que passer
    /// d'un module à l'autre ne réordonne pas la liste sous les yeux).
    var candidates: [MoveEdge] {
        (currentNode?.moves ?? []).sorted { a, b in
            if (a.role == .mainLine) != (b.role == .mainLine) { return a.role == .mainLine }
            return (a.popularityClub ?? 0) > (b.popularityClub ?? 0)
        }
    }

    var mainLine: MoveEdge? { candidates.first }

    // MARK: Données Labs

    private var labsData: LabsPositionData? { sidecar.data(at: currentKey) }

    /// Ce que jouent les maîtres ici — `nil` si aucune partie de maître n'est
    /// connue pour cette position (l'écran le dit plutôt que d'afficher zéro).
    var masterStats: LabsMasterStats? { labsData?.masters }

    /// Les trois meilleurs coups du moteur, calculés d'avance.
    var engineLines: [LabsEngineLine] { labsData?.engine ?? [] }
    var engineDepth: Int? { sidecar.engineDepth }

    /// Évaluation de la position en centipions, POINT DE VUE BLANC.
    ///
    /// La ligne de tête du moteur d'abord (c'est l'évaluation de la position,
    /// à profondeur connue) ; à défaut, l'évaluation portée par le coup qui a
    /// mené ici, déjà présente dans le cours. `nil` si on ne sait pas — et la
    /// barre affiche alors l'égalité sans prétendre à un chiffre.
    var evalCp: Int? {
        if let line = engineLines.first, line.mate == nil { return line.cp }
        if engineLines.first?.mate != nil { return nil }
        guard let edgeEval = lastEdge?.eval else { return nil }
        return Int((edgeEval * 100).rounded())
    }

    var evalMate: Int? { engineLines.first?.mate }

    /// Vrai si l'évaluation affichée vient bien du moteur pré-calculé (et non
    /// d'un repli) — l'écran n'annonce « profondeur 20 » que dans ce cas.
    var hasPrecomputedEval: Bool { !engineLines.isEmpty }

    /// L'arête du répertoire qui a mené à la position courante.
    private var lastEdge: MoveEdge? {
        guard let last = path.last, path.count >= 1 else { return nil }
        let previousKey = key(afterReplaying: path.dropLast())
        return course.node(at: previousKey)?.moves.first { $0.uci == last }
    }

    /// Un coup de maître est-il DANS le répertoire (donc jouable d'ici) ?
    ///
    /// Labs ne quitte pas le graphe : hors répertoire, il n'y a ni sidecar, ni
    /// commentaire, ni suite — on afficherait un écran vide. Les coups hors
    /// répertoire restent visibles (c'est une information : les maîtres jouent
    /// aussi ça) mais ne sont pas des boutons.
    func edge(forUCI uci: String) -> MoveEdge? {
        currentNode?.moves.first { $0.uci == uci }
    }

    /// Nom de la variante qu'ouvre ce coup, s'il en a un — affiché sur la
    /// ligne du répertoire pour qu'on sache ce qu'on s'apprête à explorer
    /// avant de taper dessus.
    func branchName(for edge: MoveEdge) -> String? {
        branchNames[edge.toFEN]?.resolved(languageCode)
    }

    /// La rangée de l'arbre où une branche qui transpose se poursuit vraiment.
    /// `nil` si l'arbre ne déplie cette position nulle part (donnée partielle).
    func destinationRow(of row: OpeningLineTree.Node) -> String? {
        guard row.isTransposition, let landing = row.moves.last else { return nil }
        return expansionRows[landing.toFEN]
    }

    /// Coup du répertoire correspondant à une FLÈCHE du plateau.
    ///
    /// Une flèche ne connaît que ses deux cases (« e7e8 ») ; une promotion a
    /// un cinquième caractère (« e7e8q »). On cherche donc par PRÉFIXE, et le
    /// premier coup trouvé gagne — les candidats sont triés ligne principale
    /// d'abord, donc taper la flèche joue la promotion recommandée plutôt
    /// qu'une sous-promotion.
    func edge(from: String, to: String) -> MoveEdge? {
        let prefix = from + to
        return candidates.first { $0.uci.hasPrefix(prefix) }
    }

    // MARK: Navigation

    func next() {
        guard let edge = mainLine else { return }
        play(edge)
    }

    func play(_ edge: MoveEdge) {
        jump(path: path + [edge.uci])
        Haptics.move()
    }

    func back() {
        guard canGoBack else { return }
        jump(path: Array(path.dropLast()))
    }

    func reset() { jump(path: []) }

    /// Revient au `ply`-ième demi-coup du chemin courant (fil des coups).
    func jump(toPly ply: Int) {
        guard ply >= 0, ply <= path.count else { return }
        jump(path: Array(path.prefix(ply)))
    }

    /// Saute à une position en REJOUANT un chemin depuis la racine — le point
    /// d'entrée de l'index des lignes.
    ///
    /// Le rejeu s'arrête au premier coup injouable (donnée incohérente) plutôt
    /// que d'échouer en bloc : on atterrit alors aussi loin que la donnée le
    /// permet, ce qui reste utilisable, au lieu de ne rien faire du tout.
    func jump(path newPath: [String]) {
        var replayBoard = rootBoard
        var key = course.rootFEN
        var sans: [String] = []
        var accepted: [String] = []
        var move: Move?

        for uci in newPath {
            guard
                let edge = course.node(at: key)?.moves.first(where: { $0.uci == uci }),
                let applied = OpeningExplorerViewModel.apply(uci: uci, to: replayBoard)
            else {
                break
            }
            replayBoard = applied.board
            move = applied.move
            key = edge.toFEN
            sans.append(edge.san)
            accepted.append(uci)
        }

        board = replayBoard
        currentKey = key
        lastMove = move
        playedSANs = sans
        path = accepted
        currentComment = lastEdge?.displayableComment(languageCode)
    }

    /// Clé atteinte en rejouant un chemin — sans toucher à l'état courant.
    private func key(afterReplaying path: some Sequence<String>) -> String {
        var key = course.rootFEN
        for uci in path {
            guard let edge = course.node(at: key)?.moves.first(where: { $0.uci == uci }) else { return key }
            key = edge.toFEN
        }
        return key
    }

    // MARK: Index des lignes

    /// La rangée de l'arbre sur laquelle on se trouve, s'il y en a une : celle
    /// dont un coup a exactement le chemin courant. Sert à rouvrir l'index
    /// déroulé au bon endroit plutôt qu'en haut de l'arbre.
    var currentRowID: String? {
        guard !path.isEmpty else { return nil }
        return rows.first { row in
            row.moves.contains { $0.path == path }
        }?.id
    }

    /// Ce coup de l'index est-il SUR le chemin courant ?
    ///
    /// C'est ce qui permet à l'index de montrer, d'un coup d'œil, dans quelles
    /// lignes on se trouve et où elles divergent : tous les coups partagés
    /// avec le chemin courant s'allument, les autres non.
    func isOnCurrentPath(_ move: OpeningLineIndex.IndexedMove) -> Bool {
        move.path.count <= path.count && Array(path.prefix(move.path.count)) == move.path
    }

    /// Ce coup est-il exactement la position affichée ?
    func isCurrent(_ move: OpeningLineIndex.IndexedMove) -> Bool { move.path == path }
}
