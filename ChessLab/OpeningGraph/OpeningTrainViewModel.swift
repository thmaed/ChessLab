import ChessKit
import Foundation
import Observation
import SwiftData

/// Mode ENTRAÎNER — « ligne guidée » : on parcourt une ouverture sur UN seul
/// échiquier continu (comme le lecteur), sauf que c'est l'utilisateur qui joue
/// SON camp ; l'adversaire répond tout seul, sur la ligne principale de la
/// branche courante.
///
/// - Coup principal → accepté, l'adversaire enchaîne, on continue (pas de clic).
/// - Variante du répertoire → l'utilisateur CHOISIT : la jouer, ou rester sur
///   la principale (``pendingVariation`` / ``playVariation`` / ``keepMainLine``).
/// - Coup hors répertoire → erreur : flèche du bon coup + commentaire, puis
///   ``continueAfterWrong`` joue le bon coup et poursuit.
///
/// La répétition espacée FSRS reste EN COULISSE : chaque position jouée est
/// notée automatiquement (``OpeningProgressStore`` → store « Games » iCloud),
/// planification inchangée. Modes : quotidien, positions difficiles, une ligne.
@Observable
@MainActor
final class OpeningTrainViewModel {
    enum Mode: Equatable {
        case daily
        case hardest
        case fullLine(courseID: String)
    }

    enum Phase: Equatable {
        case awaiting          // à l'utilisateur de jouer
        case opponentMoving    // l'adversaire va répondre (auto)
        case variation         // l'utilisateur a joué une variante : à lui de choisir
        case wrong             // coup hors répertoire : correction affichée
        case complete          // séance terminée
        case empty             // rien à entraîner
    }

    let mode: Mode
    private let context: ModelContext
    private let synchronousOpponent: Bool
    private var languageCode: String { AppSettings.shared.appLanguage.resolvedCode }

    // Séance : suite de cours (ouvertures) à parcourir.
    private var sessionCourses: [OpeningCourse] = []
    private var courseIndex = 0
    private(set) var course: OpeningCourse?

    // Marche du graphe sur un plateau continu.
    private(set) var board: Board
    private(set) var orientation: Piece.Color = .white
    private(set) var currentKey: String = ""
    private(set) var lastMove: Move?
    private(set) var playedSANs: [String] = []
    private(set) var currentComment: String?

    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    var pendingPromotion: PendingPromotion?
    private(set) var hintMoves: [HintMove] = []
    private(set) var usedHint = false

    private(set) var phase: Phase = .awaiting
    private(set) var reviewedCount = 0

    // Variante en attente de choix ; coup correct à rejouer après une erreur.
    private var pendingVariation: (played: MoveEdge, main: MoveEdge)?
    private var wrongMainEdge: MoveEdge?
    var variationPlayedSAN: String? { pendingVariation?.played.san }
    var variationMainSAN: String? { pendingVariation?.main.san }
    var wrongCorrectSAN: String? { wrongMainEdge?.san }

    private var opponentToken = 0

    var courseName: String { course?.name ?? "" }
    var isUserTurn: Bool { phase == .awaiting && pendingPromotion == nil }

    // MARK: Init

    convenience init(mode: Mode, context: ModelContext, newLimit: Int = 20, now: Date = Date()) {
        var loaded: [String: OpeningCourse] = [:]
        if case let .fullLine(courseID) = mode {
            if let c = OpeningCatalog.course(id: courseID) { loaded[courseID] = c }
        } else {
            loaded = Self.reviewableCourses(in: context)
        }
        self.init(mode: mode, context: context, courses: loaded, newLimit: newLimit, now: now)
    }

    /// Les cours que la séance quotidienne a le droit de servir.
    ///
    /// L'étoile du répertoire ne filtre que les cours JAMAIS travaillés : un
    /// cours où l'utilisateur a de la progression est TOUJOURS servi, membre
    /// ou pas. Sans cela (bug18aout.md §2, arbitré le 18/08), entraîner la
    /// Lucena avec trois ouvertures étoilées gonflait le compteur « à
    /// revoir » de positions que la séance ne servait jamais — on révise ce
    /// qu'on a appris.
    static func reviewableCourses(in context: ModelContext) -> [String: OpeningCourse] {
        var loaded: [String: OpeningCourse] = [:]
        let repertoire = RepertoireStore.memberIDs(in: context)
        let trainedFENs: Set<String> = repertoire.isEmpty
            ? []  // pas de filtre → pas besoin de l'intersection
            : Set(snapshots(in: context).filter { $0.value.reps > 0 }.keys)
        for entry in OpeningCatalog.all {
            guard let c = OpeningCatalog.course(id: entry.id) else { continue }
            if !repertoire.isEmpty && !repertoire.contains(entry.id) {
                // Une seule position déjà travaillée suffit : la progression
                // est attachée aux POSITIONS, et une transposition entraînée
                // ailleurs y ouvre droit aussi.
                guard c.positions.keys.contains(where: trainedFENs.contains) else { continue }
            }
            loaded[entry.id] = c
        }
        return loaded
    }

    /// Init désigné (cours injectés) — testable sans bundle. `synchronousOpponent`
    /// joue la riposte adverse immédiatement (sans délai) pour les tests.
    init(
        mode: Mode, context: ModelContext, courses: [String: OpeningCourse],
        newLimit: Int = 20, now: Date = Date(), synchronousOpponent: Bool = false
    ) {
        self.mode = mode
        self.context = context
        self.synchronousOpponent = synchronousOpponent
        self.board = Board(position: .standard)

        OpeningProgressSync.reconcile(in: context)
        sessionCourses = Self.buildSession(mode: mode, courses: courses, context: context, newLimit: newLimit, now: now)
        if let first = sessionCourses.first {
            startCourse(first)
        } else {
            phase = .empty
        }
    }

    /// Suite de cours à parcourir : la ligne ciblée en `fullLine`, sinon les
    /// ouvertures (du répertoire) qui ont des positions dues / difficiles, par
    /// ordre d'urgence et plafonnées.
    private static func buildSession(
        mode: Mode, courses: [String: OpeningCourse], context: ModelContext, newLimit: Int, now: Date
    ) -> [OpeningCourse] {
        switch mode {
        case let .fullLine(id):
            return courses[id].map { [$0] } ?? []
        case .daily, .hardest:
            let snapshots = snapshots(in: context)
            let allCards = courses.values.flatMap { OpeningTrainingQueue.trainableCards(of: $0) }
            let queue: [TrainCard] = {
                if case .daily = mode {
                    return OpeningTrainingQueue.dailyQueue(cards: allCards, progress: snapshots, now: now, newLimit: newLimit)
                }
                return OpeningTrainingQueue.hardestQueue(cards: allCards, progress: snapshots)
            }()
            var seen = Set<String>()
            var ids: [String] = []
            for card in queue where seen.insert(card.courseID).inserted { ids.append(card.courseID) }
            return ids.prefix(8).compactMap { courses[$0] }
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

    // MARK: Marche du graphe

    /// Coups jouables à `key`, ligne principale d'abord puis par popularité club.
    private func candidates(at key: String) -> [MoveEdge] {
        (course?.node(at: key)?.moves ?? []).sorted { a, b in
            if (a.role == .mainLine) != (b.role == .mainLine) { return a.role == .mainLine }
            return (a.popularityClub ?? 0) > (b.popularityClub ?? 0)
        }
    }

    private var mainEdge: MoveEdge? { candidates(at: currentKey).first }

    private func startCourse(_ c: OpeningCourse) {
        course = c
        orientation = c.side.color
        board = Board(position: OpeningFENKey.position(from: c.rootFEN) ?? .standard)
        currentKey = c.rootFEN
        playedSANs = []
        lastMove = nil
        currentComment = c.summary?.resolved(languageCode)
        clearTurnState()
        advanceTurn()
    }

    private func clearTurnState() {
        clearSelection()
        hintMoves = []
        usedHint = false
        pendingVariation = nil
        wrongMainEdge = nil
        pendingPromotion = nil
    }

    /// Détermine à qui de jouer à `currentKey` et enchaîne : fin de ligne →
    /// cours suivant ; trait à l'utilisateur → on attend ; sinon l'adversaire joue.
    private func advanceTurn() {
        if candidates(at: currentKey).isEmpty {
            nextCourseOrComplete()
            return
        }
        if board.position.sideToMove == orientation {
            phase = .awaiting
        } else {
            phase = .opponentMoving
            if synchronousOpponent {
                performOpponentMove()
            } else {
                scheduleOpponentMove()
            }
        }
    }

    private func scheduleOpponentMove() {
        opponentToken += 1
        let token = opponentToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self, self.opponentToken == token, self.phase == .opponentMoving else { return }
            self.performOpponentMove()
        }
    }

    private func performOpponentMove() {
        guard let edge = mainEdge else { nextCourseOrComplete(); return }
        apply(edge, isUser: false)
        advanceTurn()
    }

    private func nextCourseOrComplete() {
        courseIndex += 1
        if courseIndex < sessionCourses.count {
            startCourse(sessionCourses[courseIndex])
        } else {
            phase = .complete
        }
    }

    /// Applique une arête au plateau continu et affiche le commentaire du coup
    /// (le « 1 demi-coup après » : le commentaire suit le coup joué).
    private func apply(_ edge: MoveEdge, isUser: Bool) {
        guard let applied = OpeningExplorerViewModel.apply(uci: edge.uci, to: board) else { return }
        board = applied.board
        lastMove = applied.move
        currentKey = edge.toFEN
        currentComment = edge.displayableComment(languageCode)
        playedSANs.append(edge.san)
        hintMoves = []
        if isUser { reviewedCount += 1 }
        Haptics.move()
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
        evaluate(uci: move.lan)
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        var scratch = pending.scratch
        let move = scratch.completePromotion(of: pending.move, to: kind)
        evaluate(uci: move.lan)
    }

    func cancelPromotion() { pendingPromotion = nil }

    /// Classe le coup joué : principal, variante, ou hors répertoire.
    private func evaluate(uci: String) {
        let cands = candidates(at: currentKey)
        guard let main = cands.first else { return }
        if let edge = cands.first(where: { $0.uci == uci }) {
            if edge.uci == main.uci {
                recordReview(usedHint ? .hard : .good)
                apply(edge, isUser: true)
                advanceTurn()
            } else {
                // Variante valide : on demande à l'utilisateur.
                pendingVariation = (played: edge, main: main)
                phase = .variation
            }
        } else {
            // Hors répertoire → erreur : on montre le bon coup, on ne l'applique
            // pas encore (le plateau reste sur la position).
            recordReview(.again)
            wrongMainEdge = main
            hintMoves = [arrow(for: main.uci)]
            currentComment = main.displayableComment(languageCode)
            phase = .wrong
            Haptics.illegal()
        }
    }

    /// « Jouer la variante » : on suit cette branche.
    func playVariation() {
        guard let pv = pendingVariation else { return }
        recordReview(usedHint ? .hard : .good)
        pendingVariation = nil
        apply(pv.played, isUser: true)
        advanceTurn()
    }

    /// « Rester sur la principale » : on joue le coup principal à la place et on
    /// note que la variante était aussi jouable.
    func keepMainLine() {
        guard let pv = pendingVariation else { return }
        recordReview(usedHint ? .hard : .good)
        let alt = pv.played.san
        pendingVariation = nil
        apply(pv.main, isUser: true)
        let note = languageCode == "fr" ? "Aussi jouable : \(alt)." : "Also playable: \(alt)."
        currentComment = [note, currentComment].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        advanceTurn()
    }

    /// Après une erreur : on joue le bon coup et on poursuit la ligne.
    func continueAfterWrong() {
        guard let main = wrongMainEdge else { return }
        wrongMainEdge = nil
        apply(main, isUser: true)
        advanceTurn()
    }

    func showHint() {
        guard isUserTurn, let main = mainEdge else { return }
        usedHint = true
        hintMoves = [arrow(for: main.uci)]
    }

    /// Recommence la séance depuis le début.
    func restart() {
        courseIndex = 0
        reviewedCount = 0
        if let first = sessionCourses.first {
            startCourse(first)
        } else {
            phase = .empty
        }
    }

    // MARK: Progression FSRS

    /// Note FSRS auto-dérivée : erreur → Encore, indice → Difficile, sinon Bien.
    /// Enregistre pour la position OÙ l'utilisateur devait jouer (`currentKey`).
    private func recordReview(_ rating: FSRSRating) {
        var effective = rating
        if usedHint, effective.rawValue > FSRSRating.hard.rawValue { effective = .hard }
        OpeningProgressStore.recordReview(fenKey: currentKey, rating: effective, in: context)
    }

    private func arrow(for uci: String) -> HintMove {
        HintMove(rank: 1, from: Square(String(uci.prefix(2))), to: Square(String(uci.dropFirst(2).prefix(2))), strength: 1)
    }
}
