import ChessKit
import Foundation
import Observation
import SwiftData

/// Mode ENTRAÎNER : répétition espacée FSRS, l'unité étant la POSITION. Une file
/// quotidienne présente les positions dues (+ un quota de neuves) ; l'utilisateur
/// retrouve le coup, note sa performance, et la position est replanifiée puis
/// SYNCHRONISÉE (``OpeningProgressStore`` → store « Games » iCloud).
///
/// - La riposte adverse (contexte après une bonne réponse) est pondérée par la
///   fréquence club (``OpeningOpponent``), jamais uniforme.
/// - Erreur → correction immédiate + explication, replanifiée au plus tôt (Again).
/// - Modes : quotidien, positions difficiles uniquement, ligne complète « sans
///   filet » (pas d'indice).
@Observable
@MainActor
final class OpeningTrainViewModel {
    enum Mode: Equatable {
        case daily
        case hardest
        case fullLine(courseID: String)
    }

    enum Phase: Equatable {
        case awaiting          // l'utilisateur doit jouer
        case correct           // bonne réponse : choix de la note
        case wrong             // mauvaise réponse : correction affichée
        case complete          // file épuisée
        case empty             // rien à réviser
    }

    let mode: Mode
    private let context: ModelContext
    private var courses: [String: OpeningCourse] = [:]
    private var rng = SystemRandomNumberGenerator()
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    private(set) var queue: [TrainCard] = []
    private(set) var index = 0
    private(set) var phase: Phase = .awaiting
    private(set) var reviewedCount = 0

    private(set) var board: Board
    private(set) var orientation: Piece.Color = .white
    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?
    var pendingPromotion: PendingPromotion?
    var hintMoves: [HintMove] = []
    private(set) var currentComment: String?
    private(set) var usedHint = false

    /// Charge les cours depuis le bundle embarqué. Les modes quotidien/difficiles
    /// se LIMITENT au répertoire personnel s'il en existe un (priorisation des
    /// révisions) ; `fullLine` ne charge que le cours ciblé.
    convenience init(mode: Mode, context: ModelContext, newLimit: Int = 20, now: Date = Date()) {
        var loaded: [String: OpeningCourse] = [:]
        if case let .fullLine(courseID) = mode {
            if let course = OpeningCourseLoader.course(id: courseID) { loaded[courseID] = course }
        } else {
            let repertoire = RepertoireStore.memberIDs(in: context)
            for entry in OpeningCourseLoader.catalog {
                if !repertoire.isEmpty && !repertoire.contains(entry.id) { continue }
                if let course = OpeningCourseLoader.course(id: entry.id) { loaded[entry.id] = course }
            }
        }
        self.init(mode: mode, context: context, courses: loaded, newLimit: newLimit, now: now)
    }

    /// Init désigné (cours injectés) — testable sans bundle.
    init(mode: Mode, context: ModelContext, courses: [String: OpeningCourse], newLimit: Int = 20, now: Date = Date()) {
        self.mode = mode
        self.context = context
        self.courses = courses
        self.board = Board(position: .standard)

        // Tire d'abord l'état synchronisé (autres appareils) avant de bâtir la file.
        OpeningProgressSync.reconcile(in: context)
        buildQueue(newLimit: newLimit, now: now)
        loadCurrentCard()
    }

    private func buildQueue(newLimit: Int, now: Date) {
        let snapshots = Self.snapshots(in: context)
        switch mode {
        case .daily:
            let cards = courses.values.flatMap { OpeningTrainingQueue.trainableCards(of: $0) }
            queue = OpeningTrainingQueue.dailyQueue(cards: cards, progress: snapshots, now: now, newLimit: newLimit)
        case .hardest:
            let cards = courses.values.flatMap { OpeningTrainingQueue.trainableCards(of: $0) }
            queue = OpeningTrainingQueue.hardestQueue(cards: cards, progress: snapshots)
        case let .fullLine(courseID):
            queue = courses[courseID].map { OpeningTrainingQueue.lineCards(of: $0) } ?? []
        }
    }

    static func snapshots(in context: ModelContext) -> [String: OpeningProgressSnapshot] {
        let all = (try? context.fetch(FetchDescriptor<OpeningPositionProgress>())) ?? []
        var map: [String: OpeningProgressSnapshot] = [:]
        for p in all {
            map[p.fenKey] = OpeningProgressSnapshot(
                dueDate: p.dueDate, lapses: p.lapses, stability: p.stability, reps: p.reps
            )
        }
        return map
    }

    // MARK: État dérivé

    var currentCard: TrainCard? { index < queue.count ? queue[index] : nil }
    var total: Int { queue.count }
    var remaining: Int { max(0, queue.count - index) }
    var allowsHints: Bool { if case .fullLine = mode { return false } else { return true } }
    var isUserTurn: Bool { phase == .awaiting && pendingPromotion == nil }

    /// Notes proposées à l'utilisateur selon la phase (un indice utilisé plafonne
    /// une bonne réponse à « Difficile »).
    var ratingOptions: [FSRSRating] {
        switch phase {
        case .correct: return usedHint ? [.hard] : [.hard, .good, .easy]
        case .wrong: return [.again]
        default: return []
        }
    }

    // MARK: Chargement de carte

    private func loadCurrentCard() {
        clearSelection()
        hintMoves = []
        usedHint = false
        currentComment = nil
        lastMove = nil
        pendingPromotion = nil
        guard let card = currentCard else {
            phase = queue.isEmpty ? .empty : .complete
            return
        }
        orientation = courses[card.courseID]?.side.color ?? .white
        board = Board(position: OpeningFENKey.position(from: card.fenKey) ?? .standard)
        phase = .awaiting
    }

    // MARK: Interaction

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
        evaluate(scratch: scratch, move: move)
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        var scratch = pending.scratch
        let move = scratch.completePromotion(of: pending.move, to: kind)
        evaluate(scratch: scratch, move: move)
    }

    func cancelPromotion() { pendingPromotion = nil }

    func showHint() {
        guard isUserTurn, allowsHints, let card = currentCard, card.expectedUCI.count >= 4 else { return }
        usedHint = true
        hintMoves = [arrow(for: card.expectedUCI)]
    }

    private func evaluate(scratch: Board, move: Move) {
        guard let card = currentCard else { return }
        if move.lan == card.expectedUCI {
            board = scratch
            lastMove = move
            if let comment = card.comment?.resolved(languageCode) { currentComment = comment }
            playOpponentContext(for: card)
            phase = .correct
            Haptics.move()
        } else {
            revealCorrect(card)
            phase = .wrong
            Haptics.illegal()
        }
    }

    /// Après une bonne réponse, joue une riposte adverse PONDÉRÉE (contexte).
    private func playOpponentContext(for card: TrainCard) {
        guard let course = courses[card.courseID] else { return }
        let key = OpeningFENKey.key(for: board.position)
        guard let node = course.node(at: key), !node.moves.isEmpty,
              let reply = OpeningOpponent.weightedReply(from: node, using: &rng),
              let applied = OpeningExplorerViewModel.apply(uci: reply.uci, to: board)
        else { return }
        board = applied.board
        lastMove = applied.move
    }

    /// Sur une erreur, révèle le bon coup (flèche + application) et son commentaire.
    private func revealCorrect(_ card: TrainCard) {
        hintMoves = [arrow(for: card.expectedUCI)]
        if let applied = OpeningExplorerViewModel.apply(uci: card.expectedUCI, to: board) {
            board = applied.board
            lastMove = applied.move
        }
        if let comment = card.comment?.resolved(languageCode) { currentComment = comment }
    }

    private func arrow(for uci: String) -> HintMove {
        HintMove(rank: 1, from: Square(String(uci.prefix(2))), to: Square(String(uci.dropFirst(2).prefix(2))), strength: 1)
    }

    // MARK: Notation / progression

    /// Enregistre la note FSRS (replanifie + journalise + synchronise) et passe
    /// à la carte suivante.
    func grade(_ rating: FSRSRating) {
        guard let card = currentCard, phase == .correct || phase == .wrong else { return }
        var effective = rating
        // Un indice utilisé plafonne une réussite à « Difficile ».
        if usedHint, rating.rawValue > FSRSRating.hard.rawValue { effective = .hard }
        OpeningProgressStore.recordReview(fenKey: card.fenKey, rating: effective, in: context)
        reviewedCount += 1
        index += 1
        loadCurrentCard()
    }
}
