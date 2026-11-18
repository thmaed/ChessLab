import ChessKit
import Foundation
import Observation
import SwiftData

/// Une série de Visualisation (voir ``VisualizationSettings`` pour les réglages, ``VisualizationDrawer`` pour le
/// tirage). L'heure vient de l'extérieur (`now`) : les tests la règlent.
///
/// Le temps s'arrête quand l'app quitte le premier plan (``pause()`` / ``resume()``), comme « Contre la montre ».
@Observable
@MainActor
final class VisualizationViewModel {
    enum Phase: Equatable {
        case setup
        case playing
        case finished
    }

    /// Le retour sur une réponse, affiché un instant avant la question suivante.
    struct Feedback: Equatable {
        let given: VisualizationAnswer?
        let isCorrect: Bool
    }

    /// Un juste passe vite ; une erreur laisse le temps de lire la bonne réponse.
    static let correctPause: TimeInterval = 0.45
    static let wrongPause: TimeInterval = 1.6

    var settings: VisualizationSettings {
        didSet { VisualizationStore.save(settings, defaults: defaults) }
    }
    private(set) var stats: VisualizationStats
    private(set) var phase: Phase = .setup
    private(set) var question: VisualizationQuestion?
    private(set) var answered: [VisualizationAnswered] = []
    private(set) var feedback: Feedback?
    /// Relu par la vue pour les chronos (rafraîchi pendant la série).
    private(set) var now: Date
    /// Marche 5 : la position est montrée — le chrono de la question attend que le joueur la cache.
    private(set) var isMemorizing = false
    /// Marche 5 : la case de départ touchée sur le plateau caché.
    private(set) var selectedFrom: VisualizationSquare?

    private let defaults: UserDefaults
    private let clock: () -> Date
    private var rng: any RandomNumberGenerator
    /// Temps de série écoulé avant la dernière reprise, et début de la reprise en cours.
    private var seriesElapsedBefore: TimeInterval = 0
    private var questionElapsedBefore: TimeInterval = 0
    private var runningSince: Date?
    /// Début du morceau de temps en cours pour la QUESTION (le chrono par question), à part de celui de la série.
    private var questionSince: Date?
    private var ticker: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?
    private var nextID = 0
    /// La bibliothèque de puzzles (marche 5) ; sans elle, les positions de secours.
    private let modelContext: ModelContext?
    private var usedPuzzles = Set<UUID>()

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init,
         rng: any RandomNumberGenerator = SystemRandomNumberGenerator(), modelContext: ModelContext? = nil) {
        self.defaults = defaults
        self.modelContext = modelContext
        self.clock = now
        self.rng = rng
        self.now = now()
        settings = VisualizationStore.loadSettings(defaults: defaults)
        stats = VisualizationStore.loadStats(defaults: defaults)
    }

    // MARK: Réglages

    func toggle(_ step: VisualizationStep) {
        if settings.steps.contains(step) {
            // Jamais aucune marche : la dernière reste cochée.
            guard settings.steps.count > 1 else { return }
            settings.steps.remove(step)
        } else {
            settings.steps.insert(step)
        }
    }

    /// Les questions ratées qui attendent, parmi les marches choisies.
    var reviewCount: Int { stats.reviewKeys(for: settings.kinds).count }

    // MARK: Le temps

    var seriesElapsed: TimeInterval {
        seriesElapsedBefore + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    /// Série d'une minute : ce qu'il reste. `nil` pour une série en nombre de questions.
    var seriesRemaining: TimeInterval? {
        guard let duration = settings.length.duration else { return nil }
        return max(0, duration - seriesElapsed)
    }

    /// Chrono par question : la fraction de temps restante (1 → 0). `nil` sans chrono.
    var questionTimeFraction: Double? {
        guard let base = settings.secondsPerQuestion, phase == .playing, let question else { return nil }
        if isMemorizing { return 1 }
        let seconds = question.kind.seconds(base: base)
        let elapsed = questionElapsedBefore + (questionSince.map { now.timeIntervalSince($0) } ?? 0)
        return max(0, 1 - elapsed / Double(seconds))
    }

    var correctCount: Int { answered.filter(\.isCorrect).count }

    // MARK: La série

    func start() {
        usedPuzzles = []
        answered = []
        feedback = nil
        nextID = 0
        seriesElapsedBefore = 0
        phase = .playing
        now = clock()
        runningSince = now
        question = nil
        serveNext()
        startTicker()
    }

    func answer(_ given: VisualizationAnswer) {
        guard phase == .playing, feedback == nil, let question else { return }
        settle(question, given: given)
    }

    // MARK: Marche 5

    /// « J'ai mémorisé » : les pièces disparaissent, le chrono de la question part.
    func hidePosition() {
        guard isMemorizing, phase == .playing else { return }
        isMemorizing = false
        if runningSince != nil { questionSince = clock() }
    }

    /// Un toucher sur le plateau caché : la case de départ, puis la case d'arrivée qui joue le coup.
    func tapCalculationSquare(_ square: VisualizationSquare) {
        guard phase == .playing, feedback == nil, !isMemorizing, let question, question.kind.step == .calculation else { return }
        guard let from = selectedFrom else {
            selectedFrom = square
            return
        }
        selectedFrom = nil
        if from == square { return }
        settle(question, given: VisualizationCalc.judge(from: from, to: square, in: question))
    }

    /// Un puzzle de la bibliothèque : court, un peu sous le niveau du joueur (de tête, c'est plus dur), jamais deux
    /// fois dans la série. « Calculer la suite » veut trois coups.
    private func puzzleQuestion(_ kind: VisualizationKind) -> VisualizationQuestion? {
        guard let modelContext else { return nil }
        let target = max(600, Int(PuzzleRatingStore.load().rating.rounded()) - 300)
        for _ in 0..<8 {
            guard let puzzle = PuzzleRushDrawer.next(target: target, excluding: usedPuzzles, in: modelContext) else { return nil }
            usedPuzzles.insert(puzzle.id)
            if let question = VisualizationCalc.question(kind, fen: puzzle.fen ?? "", solution: puzzle.solutionLANs ?? []) {
                return question
            }
        }
        return nil
    }

    /// L'app quitte le premier plan : le temps s'arrête.
    func pause() {
        guard let since = runningSince else { return }
        let t = clock()
        seriesElapsedBefore += t.timeIntervalSince(since)
        if let q = questionSince { questionElapsedBefore += t.timeIntervalSince(q) }
        runningSince = nil
        questionSince = nil
        now = t
    }

    func resume() {
        guard phase == .playing, runningSince == nil else { return }
        now = clock()
        runningSince = now
        // Pendant la mémorisation (marche 5), le chrono de la question n'a pas encore commencé.
        questionSince = isMemorizing ? nil : now
    }

    /// Quitter la série en cours : ce qui a été répondu reste compté.
    func stop() {
        ticker?.cancel()
        advanceTask?.cancel()
        if phase == .playing { finish() }
    }

    func backToSetup() {
        ticker?.cancel()
        advanceTask?.cancel()
        phase = .setup
        question = nil
        feedback = nil
    }

    /// Le bilan, exercice par exercice : (exercice, justes, posées), dans l'ordre de l'échelle.
    var summaryByKind: [(kind: VisualizationKind, correct: Int, total: Int)] {
        VisualizationKind.allCases.compactMap { kind in
            let items = answered.filter { $0.question.kind == kind }
            return items.isEmpty ? nil : (kind, items.filter(\.isCorrect).count, items.count)
        }
    }

    var misses: [VisualizationAnswered] { answered.filter { !$0.isCorrect } }

    // MARK: Interne

    private func serveNext() {
        question = VisualizationDrawer.next(kinds: settings.kinds, stats: stats, previous: question, using: &rng,
                                            puzzles: { [weak self] kind in self?.puzzleQuestion(kind) })
        questionElapsedBefore = 0
        selectedFrom = nil
        isMemorizing = question?.kind.step == .calculation
        questionSince = runningSince != nil && !isMemorizing ? clock() : nil
        feedback = nil
    }

    private func settle(_ question: VisualizationQuestion, given: VisualizationAnswer?) {
        let item = VisualizationAnswered(id: nextID, question: question, given: given)
        nextID += 1
        answered.append(item)
        stats.record(question, correct: item.isCorrect)
        VisualizationStore.save(stats, defaults: defaults)
        feedback = Feedback(given: given, isCorrect: item.isCorrect)
        if item.isCorrect { Haptics.move() } else { Haptics.illegal() }
        let pause = item.isCorrect ? Self.correctPause : Self.wrongPause
        advanceTask?.cancel()
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(pause))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    private func advance() {
        guard phase == .playing else { return }
        if let count = settings.length.questionCount, answered.count >= count {
            finish()
        } else if let remaining = seriesRemaining, remaining <= 0 {
            finish()
        } else {
            serveNext()
        }
    }

    /// Le battement de la série : rafraîchit les chronos, et tranche quand un temps est écoulé.
    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    /// Exposé pour les tests : un battement, à l'heure de `clock`.
    func tick() {
        guard phase == .playing, runningSince != nil else { return }
        now = clock()
        if let remaining = seriesRemaining, remaining <= 0 {
            // La minute est écoulée : la question en cours ne compte pas.
            finish()
            return
        }
        if feedback == nil, !isMemorizing, let fraction = questionTimeFraction, fraction <= 0, let question {
            settle(question, given: nil)
        }
    }

    private func finish() {
        ticker?.cancel()
        advanceTask?.cancel()
        if let since = runningSince { seriesElapsedBefore += clock().timeIntervalSince(since) }
        runningSince = nil
        questionSince = nil
        feedback = nil
        question = nil
        phase = .finished
        if !answered.isEmpty { Haptics.gameEnded() }
    }
}
