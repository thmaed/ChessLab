import ChessKit
import Foundation
import Observation

/// Mode APPRENDRE (façon Chessable) : on parcourt la LIGNE PRINCIPALE du cours
/// coup par coup, mais l'utilisateur JOUE lui-même chaque coup de son camp
/// (rappel actif, pas de bouton « suivant »). Les coups adverses sont
/// auto-joués. Chaque coup montre son commentaire (s'il est validé), et un
/// bouton « pourquoi pas autre chose ? » déplie les alternatives du nœud avec
/// leurs statistiques. À la fin, la ligne peut être revue d'un trait.
///
/// Mécanique d'interaction/relance calquée sur ``OpeningLineTrainingViewModel``
/// (3 essais puis coup révélé, jamais un échec bloquant), mais pilotée par le
/// GRAPHE (arêtes `mainLine`) et non par un PGN linéaire. La progression FSRS
/// (par position) sera branchée en J8.
@Observable
@MainActor
final class OpeningLearnViewModel {
    let course: OpeningCourse
    let color: Piece.Color
    let orientation: Piece.Color
    /// Langue courante de l'app pour résoudre les textes bilingues.
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    /// Ligne principale : suite d'arêtes `mainLine` depuis la racine, et clé du
    /// nœud AVANT chaque arête (pour retrouver les alternatives/plans).
    private let edges: [MoveEdge]
    private let fromKeys: [String]

    private(set) var board: Board
    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?
    var pendingPromotion: PendingPromotion?

    private(set) var currentStep = 0
    private(set) var attemptsRemaining = 3
    private(set) var isLineComplete = false
    private(set) var isAutoPlaying = false
    var hintMoves: [HintMove] = []

    /// Dernier commentaire VALIDÉ rencontré (persiste tant qu'un coup commenté
    /// plus récent ne le remplace pas — un coup adverse sans commentaire ne
    /// l'efface pas).
    private(set) var currentComment: String?
    /// Panneau « pourquoi pas autre chose ? ».
    var showAlternatives = false

    var resultingFEN: String? { isLineComplete ? board.position.fen : nil }

    init?(course: OpeningCourse) {
        let line = Self.mainLine(of: course)
        guard !line.edges.isEmpty else { return nil }
        self.course = course
        self.edges = line.edges
        self.fromKeys = line.fromKeys
        self.color = course.side.color
        self.orientation = course.side.color
        self.board = Board(position: OpeningFENKey.position(from: course.rootFEN) ?? .standard)
        advanceOpponentMoves()
    }

    /// Suit les arêtes `mainLine` (à défaut, la plus jouée en club) depuis la
    /// racine, en évitant les cycles de transposition. `nonisolated` : pure,
    /// réutilisée par ``OpeningTrainingQueue`` (contexte non-isolé).
    nonisolated static func mainLine(of course: OpeningCourse) -> (edges: [MoveEdge], fromKeys: [String]) {
        var edges: [MoveEdge] = []
        var fromKeys: [String] = []
        var key = course.rootFEN
        var visited: Set<String> = []
        while let node = course.node(at: key), !node.moves.isEmpty, !visited.contains(key), edges.count < 60 {
            visited.insert(key)
            let edge = node.moves.first { $0.role == .mainLine }
                ?? node.moves.max(by: { ($0.popularityClub ?? 0) < ($1.popularityClub ?? 0) })
            guard let edge else { break }
            edges.append(edge)
            fromKeys.append(key)
            key = edge.toFEN
        }
        return (edges, fromKeys)
    }

    // MARK: État dérivé

    var isUserTurn: Bool {
        !isLineComplete && !isAutoPlaying && pendingPromotion == nil
            && currentStep < edges.count && board.position.sideToMove == color
    }

    var expectedEdge: MoveEdge? { currentStep < edges.count ? edges[currentStep] : nil }
    var currentNode: PositionNode? { currentStep < fromKeys.count ? course.node(at: fromKeys[currentStep]) : nil }

    /// Autres coups jouables depuis la position courante (hors coup attendu).
    var alternatives: [MoveEdge] {
        guard let node = currentNode, let expected = expectedEdge else { return [] }
        return node.moves.filter { $0.uci != expected.uci }
    }

    var plan: String? { currentNode?.plan?.resolved(languageCode) }
    var chapterTitle: String { course.chapters?.first?.title.resolved(languageCode) ?? course.name }
    var progressText: String { "Coup \(currentStep) sur \(edges.count)" }
    var totalPlies: Int { edges.count }

    func restart() {
        board = Board(position: OpeningFENKey.position(from: course.rootFEN) ?? .standard)
        selectedSquare = nil
        legalTargetSquares = []
        lastMove = nil
        pendingPromotion = nil
        currentStep = 0
        attemptsRemaining = 3
        isLineComplete = false
        isAutoPlaying = false
        hintMoves = []
        currentComment = nil
        showAlternatives = false
        advanceOpponentMoves()
    }

    /// Revoit la ligne entière d'un trait (démonstration) : rejoue tous les
    /// coups automatiquement depuis le début.
    func replayLine() {
        board = Board(position: OpeningFENKey.position(from: course.rootFEN) ?? .standard)
        lastMove = nil
        currentStep = 0
        currentComment = nil
        isLineComplete = false
        showAlternatives = false
        clearSelection()
        isAutoPlaying = true
        Task { [weak self] in await self?.runReplay() }
    }

    private func runReplay() async {
        while currentStep < edges.count {
            try? await Task.sleep(nanoseconds: 650_000_000)
            applyMove(at: currentStep)
            currentStep += 1
        }
        isAutoPlaying = false
        isLineComplete = true
        Haptics.gameEnded()
    }

    // MARK: Interaction

    func toggleAlternatives() { showAlternatives.toggle() }

    func selectSquare(_ square: Square) {
        guard isUserTurn else { return }
        if let selected = selectedSquare {
            if legalTargetSquares.contains(square) {
                attemptMove(from: selected, to: square)
                return
            }
            selectedSquare = nil
            legalTargetSquares = []
        }
        if let piece = board.position.piece(at: square), piece.color == board.position.sideToMove {
            selectedSquare = square
            legalTargetSquares = board.legalMoves(forPieceAt: square)
        }
    }

    func clearSelection() {
        selectedSquare = nil
        legalTargetSquares = []
    }

    func attemptMove(from start: Square, to end: Square) {
        guard
            isUserTurn,
            board.position.piece(at: start)?.color == board.position.sideToMove,
            board.canMove(pieceAt: start, to: end)
        else {
            Haptics.illegal()
            clearSelection()
            return
        }
        var scratch = board
        guard let move = scratch.move(pieceAt: start, to: end) else {
            clearSelection()
            return
        }
        clearSelection()
        if case .promotion = scratch.state {
            pendingPromotion = PendingPromotion(scratch: scratch, move: move)
            return
        }
        validate(scratch: scratch, move: move)
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        var scratch = pending.scratch
        let move = scratch.completePromotion(of: pending.move, to: kind)
        validate(scratch: scratch, move: move)
    }

    func cancelPromotion() { pendingPromotion = nil }

    func showHint() {
        guard isUserTurn, let uci = expectedEdge?.uci, uci.count >= 4 else { return }
        hintMoves = [HintMove(rank: 1, from: Square(String(uci.prefix(2))), to: Square(String(uci.dropFirst(2).prefix(2))), strength: 1)]
    }

    // MARK: Progression

    private func validate(scratch: Board, move: Move) {
        guard let expected = expectedEdge else { return }
        guard move.lan == expected.uci else {
            Haptics.illegal()
            registerWrongAttempt()
            return
        }
        board = scratch
        lastMove = move
        advance(playing: expected)
    }

    private func advance(playing edge: MoveEdge) {
        hintMoves = []
        attemptsRemaining = 3
        showAlternatives = false
        Haptics.move()
        if let comment = edge.displayableComment(languageCode) { currentComment = comment }
        currentStep += 1
        if currentStep >= edges.count {
            isLineComplete = true
            Haptics.gameEnded()
        } else {
            playOpponentReply()
        }
    }

    private func registerWrongAttempt() {
        attemptsRemaining -= 1
        if attemptsRemaining <= 0 { revealCurrentMove() }
    }

    private func revealCurrentMove() {
        guard let uci = expectedEdge?.uci, uci.count >= 4 else { return }
        hintMoves = [HintMove(rank: 1, from: Square(String(uci.prefix(2))), to: Square(String(uci.dropFirst(2).prefix(2))), strength: 1)]
        isAutoPlaying = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            self?.applyRevealedMove()
        }
    }

    private func applyRevealedMove() {
        defer { isAutoPlaying = false }
        guard let edge = expectedEdge else { return }
        applyMove(at: currentStep)
        advance(playing: edge)
    }

    private func advanceOpponentMoves() {
        while currentStep < edges.count, board.position.sideToMove != color {
            let edge = edges[currentStep]
            applyMove(at: currentStep)
            if let comment = edge.displayableComment(languageCode) { currentComment = comment }
            currentStep += 1
        }
        if currentStep >= edges.count { isLineComplete = true }
    }

    private func playOpponentReply() {
        guard currentStep < edges.count, board.position.sideToMove != color else { return }
        isAutoPlaying = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64.random(in: 400_000_000...700_000_000))
            self?.finishOpponentReply()
        }
    }

    private func finishOpponentReply() {
        defer { isAutoPlaying = false }
        guard currentStep < edges.count else { return }
        let edge = edges[currentStep]
        applyMove(at: currentStep)
        if let comment = edge.displayableComment(languageCode) { currentComment = comment }
        Haptics.move()
        currentStep += 1
        if currentStep >= edges.count {
            isLineComplete = true
            Haptics.gameEnded()
        }
    }

    @discardableResult
    private func applyMove(at ply: Int) -> Move? {
        guard ply < edges.count, let applied = OpeningExplorerViewModel.apply(uci: edges[ply].uci, to: board) else { return nil }
        board = applied.board
        lastMove = applied.move
        return applied.move
    }
}
