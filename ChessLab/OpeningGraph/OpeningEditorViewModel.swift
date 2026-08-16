import ChessKit
import Foundation
import Observation

/// État de l'éditeur d'arbre : où l'on se trouve dans le répertoire, et ce que
/// l'on y modifie.
///
/// Toute la logique de graphe vit dans ``OpeningCourseEditor`` (pure, testée) ;
/// ce modèle ne fait que trois choses : tenir la position courante, traduire
/// les gestes du plateau en coups, et enregistrer.
///
/// **L'enregistrement est immédiat.** Pas de bouton « Enregistrer », pas d'état
/// « modifié non sauvé » : chaque geste part sur le disque, et si l'écriture
/// échoue l'utilisateur le voit tout de suite plutôt qu'en quittant l'écran.
/// Le fichier EST le répertoire — c'est déjà ce que fait l'import.
@Observable
@MainActor
final class OpeningEditorViewModel {

    private(set) var course: OpeningCourse
    private(set) var board: Board
    private(set) var currentKey: String
    /// Coups joués depuis la racine, pour le fil et le retour arrière.
    private(set) var trail: [(san: String, key: String)] = []
    private(set) var lastMove: Move?

    /// Case sélectionnée au premier tap (le second tap joue le coup).
    var selectedSquare: Square?
    var legalTargets: [Square] = []

    /// Message d'erreur à montrer — coup illégal, doublon, écriture refusée.
    var errorMessage: String?

    private let store: UserOpeningStore
    /// Même source que le lecteur et l'entraîneur : le réglage de l'app,
    /// pas la langue du système.
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    init(course: OpeningCourse, store: UserOpeningStore = .shared) {
        self.course = course
        self.store = store
        self.currentKey = course.rootFEN
        self.board = Board(position: OpeningFENKey.position(from: course.rootFEN) ?? .standard)
    }

    // MARK: Lecture

    var currentNode: PositionNode? { course.positions[currentKey] }
    var moves: [MoveEdge] { currentNode?.moves ?? [] }
    var isAtRoot: Bool { trail.isEmpty }
    var orientation: OpeningSide { course.side }

    /// Nombre de positions — l'indicateur de taille que voit l'utilisateur.
    var positionCount: Int { course.positions.count }

    func comment(for edge: MoveEdge) -> String? {
        edge.displayableComment(languageCode)
    }

    // MARK: Navigation

    func enter(_ edge: MoveEdge) {
        guard let move = applyOnBoard(uci: edge.uci) else { return }
        lastMove = move
        trail.append((san: edge.san, key: edge.toFEN))
        currentKey = edge.toFEN
        clearSelection()
    }

    /// Coup que « Suivant » jouerait : la LIGNE PRINCIPALE si elle est
    /// marquée, sinon le premier coup écrit. Dans un arbre, « suivant » est
    /// ambigu dès qu'il y a une bifurcation ; on suit la ligne principale et
    /// la liste reste là pour choisir une autre branche.
    var nextEdge: MoveEdge? {
        moves.first { $0.role == .mainLine } ?? moves.first
    }

    func forward() {
        guard let nextEdge else { return }
        enter(nextEdge)
    }

    func back() {
        guard !trail.isEmpty else { return }
        trail.removeLast()
        rebuildBoard()
    }

    func jump(toPly ply: Int) {
        guard ply >= 0, ply <= trail.count else { return }
        trail.removeSubrange(ply...)
        rebuildBoard()
    }

    // MARK: Gestes du plateau

    func tap(_ square: Square) {
        if let selected = selectedSquare {
            if selected == square {
                clearSelection()
            } else if legalTargets.contains(square) {
                addMove(from: selected, to: square)
            } else {
                select(square)
            }
            return
        }
        select(square)
    }

    func drop(from start: Square, to end: Square) {
        addMove(from: start, to: end)
    }

    private func select(_ square: Square) {
        guard let piece = board.position.piece(at: square),
              piece.color == board.position.sideToMove
        else {
            clearSelection()
            return
        }
        selectedSquare = square
        legalTargets = board.legalMoves(forPieceAt: square)
    }

    private func clearSelection() {
        selectedSquare = nil
        legalTargets = []
    }

    // MARK: Modifications

    /// Ajoute le coup au répertoire PUIS y entre — l'utilisateur continue sa
    /// ligne sans avoir à retaper le coup qu'il vient de créer.
    ///
    /// La promotion est toujours une DAME : proposer les quatre pièces dans un
    /// éditeur de répertoire compliquerait l'écran pour un cas qui, en
    /// ouverture, n'arrive quasiment jamais. Le sous-promotion reste possible en
    /// important un PGN.
    func addMove(from start: Square, to end: Square) {
        defer { clearSelection() }
        // Le trait est vérifié ici ET dans `OpeningCourseEditor.play` : ChessKit
        // ne le consulte pas, et un glissement échappe au filtre de `select`.
        guard let piece = board.position.piece(at: start),
              piece.color == board.position.sideToMove,
              board.canMove(pieceAt: start, to: end)
        else { return }
        let uci = uciString(from: start, to: end)

        // Le coup existe déjà : on y entre au lieu de refuser. C'est ce qu'un
        // utilisateur attend en rejouant une ligne qu'il a déjà écrite.
        if let existing = moves.first(where: { $0.uci == uci }) {
            enter(existing)
            return
        }
        apply { try OpeningCourseEditor.addMove(uci: uci, from: currentKey, in: $0) }
        if let added = moves.first(where: { $0.uci == uci }) { enter(added) }
    }

    func delete(_ edge: MoveEdge) {
        apply { OpeningCourseEditor.removeMove(uci: edge.uci, from: currentKey, in: $0) }
    }

    func setComment(_ text: String?, for edge: MoveEdge) {
        let code = languageCode
        apply {
            OpeningCourseEditor.setComment(
                text, code: code, uci: edge.uci, from: currentKey, in: $0
            )
        }
    }

    func rename(to name: String) {
        apply { OpeningCourseEditor.rename($0, to: name) }
    }

    // MARK: Interne

    /// Applique une transformation, enregistre, et ne garde le résultat QUE si
    /// l'écriture a réussi. En cas d'échec le cours en mémoire reste celui du
    /// disque : jamais d'écran qui montre des modifications que le fichier
    /// ignore.
    private func apply(_ transform: (OpeningCourse) throws -> OpeningCourse) {
        do {
            let updated = try transform(course)
            try store.save(updated)
            course = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyOnBoard(uci: String) -> Move? {
        guard uci.count >= 4 else { return nil }
        let start = Square(String(uci.prefix(2)))
        let end = Square(String(uci.dropFirst(2).prefix(2)))
        guard board.canMove(pieceAt: start, to: end),
              let move = board.move(pieceAt: start, to: end)
        else { return nil }
        if case .promotion = board.state {
            let kind: Piece.Kind = uci.count == 5
                ? (Piece.Kind(rawValue: String(uci.suffix(1)).uppercased()) ?? .queen)
                : .queen
            board.completePromotion(of: move, to: kind)
        }
        return move
    }

    /// Rejoue le fil depuis la racine. Plus simple et plus sûr qu'un « défaire »
    /// sur le plateau, et le fil est court par nature.
    private func rebuildBoard() {
        board = Board(position: OpeningFENKey.position(from: course.rootFEN) ?? .standard)
        lastMove = nil
        var key = course.rootFEN
        for step in trail {
            guard let edge = course.positions[key]?.moves.first(where: { $0.toFEN == step.key }),
                  let move = applyOnBoard(uci: edge.uci)
            else { break }
            lastMove = move
            key = step.key
        }
        currentKey = key
        clearSelection()
    }

    private func uciString(from start: Square, to end: Square) -> String {
        // La promotion est forcée en dame (voir `addMove`). ChessKit signale la
        // promotion APRÈS coup ; on la détecte ici sur le couple pion + dernière
        // rangée, seul cas où le 5e caractère est requis.
        let piece = board.position.piece(at: start)
        let isPromotion = piece?.kind == .pawn && (end.rank.value == 1 || end.rank.value == 8)
        return "\(start)\(end)" + (isPromotion ? "q" : "")
    }
}
