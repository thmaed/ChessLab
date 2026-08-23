import ChessKit
import Foundation
import Observation

/// LECTEUR de FINALE : on avance coup par coup dans la ligne, on lit
/// l'explication de chaque coup, et on voit les variantes à chaque position.
/// C'est LE mode d'ouvertures — simple et guidé, façon livre interactif :
/// « Suivant » suit la ligne principale, « Précédent » revient, et les autres
/// coups jouables s'affichent pour qui veut explorer une variante.
///
/// Pas d'échec, pas de quiz : on lit et on comprend. (L'entraînement en
/// répétition espacée reste accessible à part.)
@Observable
@MainActor
final class EndgameReaderViewModel {
    let course: OpeningCourse
    let orientation: Piece.Color

    private(set) var board: Board
    private(set) var currentKey: String
    private(set) var lastMove: Move?
    /// Explication à afficher : le résumé du cours au départ, puis le
    /// commentaire du DERNIER coup joué.
    private(set) var currentComment: String?
    /// Fil des coups joués (SAN), pour se repérer et sauter en arrière.
    private(set) var playedSANs: [String] = []

    private var undo: [(key: String, board: Board, lastMove: Move?, comment: String?)] = []
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    init(course: OpeningCourse) {
        self.course = course
        // OUVERTURES : le plateau se lit du côté qu'on étudie (répertoire
        // noir ⇒ noirs en bas), comme partout ailleurs dans l'app.
        // FINALES : toujours la rangée 1 en bas, convention des diagrammes
        // de livre — 27 des 77 cours ont pour héros le camp noir (défenses,
        // forteresses) et s'affichaient inversés, ce qui déroutait plus que
        // ça n'aidait (retour utilisateur du 19/08). L'ENTRAÎNEMENT, lui,
        // garde le camp joué en bas : on y JOUE, on ne lit plus.
        self.orientation = course.kind == "endgame" ? .white : course.side.color
        self.board = Board(position: OpeningFENKey.position(from: course.rootFEN) ?? .standard)
        self.currentKey = course.rootFEN
        self.currentComment = course.summary?.resolved(AppSettings.shared.appLanguage.resolvedCode)
    }

    var currentNode: PositionNode? { course.node(at: currentKey) }
    /// Nom de la variante atteinte (sous-titre).
    var positionName: String? { currentNode?.ecoName }

    /// Coups jouables, ligne principale d'abord puis par popularité club.
    var candidates: [MoveEdge] {
        (currentNode?.moves ?? []).sorted { a, b in
            if (a.role == .mainLine) != (b.role == .mainLine) { return a.role == .mainLine }
            return (a.popularityClub ?? 0) > (b.popularityClub ?? 0)
        }
    }

    /// Le coup « recommandé » (celui que joue « Suivant »).
    var mainLine: MoveEdge? { candidates.first }
    /// Les autres coups à cette position.
    var variations: [MoveEdge] { candidates.isEmpty ? [] : Array(candidates.dropFirst()) }

    var canGoBack: Bool { !undo.isEmpty }
    var isEnd: Bool { candidates.isEmpty }
    var plyCount: Int { playedSANs.count }

    // MARK: Navigation

    /// Avance sur la ligne principale.
    func next() {
        guard let edge = mainLine else { return }
        play(edge)
    }

    /// Joue un coup précis (ligne principale ou variante).
    func play(_ edge: MoveEdge) {
        guard let applied = OpeningExplorerViewModel.apply(uci: edge.uci, to: board) else { return }
        undo.append((currentKey, board, lastMove, currentComment))
        board = applied.board
        lastMove = applied.move
        currentKey = edge.toFEN
        currentComment = edge.displayableComment(languageCode)
        playedSANs.append(edge.san)
        Haptics.move()
    }

    func back() {
        guard let previous = undo.popLast() else { return }
        board = previous.board
        lastMove = previous.lastMove
        currentKey = previous.key
        currentComment = previous.comment
        if !playedSANs.isEmpty { playedSANs.removeLast() }
    }

    func reset() {
        while canGoBack { back() }
    }

    /// Revient à la position après le `ply`-ième coup joué (fil des coups).
    func jump(toPly ply: Int) {
        while playedSANs.count > ply { back() }
    }
}
