import ChessKit
import Foundation
import Observation

/// Base statistique affichée dans l'Explorer : parties de MAÎTRES
/// (théoriquement correct) ou parties de CLUB (~1400-2000, ce que l'utilisateur
/// affronte vraiment). Double pondération conservée par le générateur.
enum ExplorerBase: String, CaseIterable, Hashable {
    case masters
    case club

    var label: String { self == .masters ? "Maîtres" : "Club" }
}

/// Explorer : navigation LIBRE dans le graphe d'un cours depuis n'importe quelle
/// position. On avance en tapant un coup de la liste (trié par popularité de la
/// base choisie), on remonte, on réinitialise. Le plateau ne fait qu'AFFICHER —
/// c'est le mode le moins risqué, il valide le modèle sans logique
/// d'entraînement.
///
/// Robuste aux données PARSEMÉES des pilotes actuels (lignes d'entrée peu
/// profondes) : un nœud feuille ou sans statistiques s'affiche proprement.
@Observable
@MainActor
final class OpeningExplorerViewModel {
    let course: OpeningCourse
    let orientation: Piece.Color

    private(set) var board: Board
    private(set) var currentKey: String
    private(set) var lastMove: Move?
    var base: ExplorerBase = .club
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    /// Pile de navigation (position précédente + plateau + dernier coup).
    private var history: [(key: String, board: Board, lastMove: Move?)] = []
    private let transpositionLookup: (String) -> [String]

    init(course: OpeningCourse, transpositionLookup: @escaping (String) -> [String] = { _ in [] }) {
        self.course = course
        self.orientation = course.side.color
        self.transpositionLookup = transpositionLookup
        let position = OpeningFENKey.position(from: course.rootFEN) ?? .standard
        self.board = Board(position: position)
        self.currentKey = course.rootFEN
    }

    var currentNode: PositionNode? { course.node(at: currentKey) }
    var ecoName: String? { currentNode?.ecoName }
    var plan: String? { currentNode?.plan?.resolved(languageCode) }
    var keySquares: [String] { currentNode?.keySquares ?? [] }

    /// Coups jouables depuis la position, triés par popularité de la base
    /// choisie (décroissant) ; les coups sans statistique passent en dernier.
    var moves: [MoveEdge] {
        (currentNode?.moves ?? []).sorted { popularity($0) > popularity($1) }
    }

    func popularity(_ edge: MoveEdge) -> Double {
        (base == .masters ? edge.popularityMasters : edge.popularityClub) ?? 0
    }

    func games(_ edge: MoveEdge) -> Int? {
        base == .masters ? edge.gamesMasters : edge.gamesClub
    }

    /// Autres cours atteignant la position courante (transpositions).
    var transpositions: [String] { transpositionLookup(currentKey) }

    var canGoBack: Bool { !history.isEmpty }
    var isLeaf: Bool { currentNode?.moves.isEmpty ?? true }
    var plyDepth: Int { history.count }

    // MARK: Navigation

    func play(_ edge: MoveEdge) {
        guard let applied = Self.apply(uci: edge.uci, to: board) else { return }
        history.append((currentKey, board, lastMove))
        board = applied.board
        lastMove = applied.move
        currentKey = edge.toFEN
    }

    func back() {
        guard let previous = history.popLast() else { return }
        board = previous.board
        lastMove = previous.lastMove
        currentKey = previous.key
    }

    func reset() {
        guard canGoBack else { return }
        let root = history.first!
        board = root.board
        lastMove = root.lastMove
        currentKey = root.key
        history.removeAll()
    }

    /// Rejoue un coup UCI sur une COPIE du plateau (gère la promotion, défaut
    /// dame), même mécanique que le trainer linéaire.
    static func apply(uci: String, to board: Board) -> (board: Board, move: Move)? {
        guard uci.count >= 4 else { return nil }
        let start = Square(String(uci.prefix(2)))
        let end = Square(String(uci.dropFirst(2).prefix(2)))
        var scratch = board
        guard scratch.canMove(pieceAt: start, to: end), let move = scratch.move(pieceAt: start, to: end) else {
            return nil
        }
        var finalMove = move
        if case .promotion = scratch.state {
            let kind: Piece.Kind = uci.count == 5
                ? (Piece.Kind(rawValue: String(uci.suffix(1)).uppercased()) ?? .queen)
                : .queen
            finalMove = scratch.completePromotion(of: move, to: kind)
        }
        return (scratch, finalMove)
    }
}
