import ChessKit
import Foundation
import Observation
import SwiftData

/// L'écran « Contre la montre » (voir ``PuzzleRushRun`` pour la règle).
///
/// Ce que la série NE fait PAS, par décision (17/11/2026) : toucher la cote de puzzles, la répétition
/// espacée ou la tuile « Ratés ». Les puzzles servis ne sont même pas marqués « ouverts » : la
/// bibliothèque sort de la série telle qu'elle y est entrée. Seul le JOUR d'entraînement compte.
///
/// La validation d'un coup suit celle de ``PuzzleSolveViewModel`` : un mat est toujours juste, même s'il
/// n'est pas celui de la solution enregistrée.
@Observable
@MainActor
final class PuzzleRushViewModel {
    enum Phase: Equatable {
        /// La règle en une phrase, et « Commencer ».
        case intro
        /// 3, 2, 1.
        case countdown(Int)
        case playing
        /// L'app a quitté le premier plan : temps arrêté, plateau voilé.
        case paused
        case finished
    }

    /// Le retour bref après un puzzle : « +1 » vert ou croix rouge. Le numéro relance l'animation.
    struct Flash: Equatable {
        let solved: Bool
        let id: Int
    }

    /// Un puzzle manqué, pour le bilan : sa position et la solution, en clair.
    struct Missed: Identifiable, Equatable {
        let id: UUID
        let fen: String
        let solution: String
        let rating: Int?
        let whiteToMove: Bool
    }

    private let modelContext: ModelContext
    private let duration: TimeInterval
    private let now: () -> Date
    /// Où vit le record (les tests en passent un à part).
    private let recordDefaults: UserDefaults
    private let remoteRecord: @MainActor () -> Int?

    private(set) var phase: Phase = .intro
    private(set) var run: PuzzleRushRun
    private(set) var puzzle: Puzzle?
    private(set) var board = Board(position: .standard)
    private(set) var orientation: Piece.Color = .white
    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?
    var pendingPromotion: PendingPromotion?
    private(set) var rejectedMove: ChessBoardView.RejectedMove?
    /// La bonne réponse, fléchée une demi-seconde après un coup faux.
    private(set) var hintMoves: [HintMove] = []
    /// Coup en cours de jeu automatique (riposte, flèche de la solution) : le joueur attend.
    private(set) var isBusy = false
    private(set) var flash: Flash?
    private(set) var missed: [Missed] = []
    /// Le bilan : le record d'avant la série, et s'il est battu.
    private(set) var previousBest = 0
    private(set) var isNewRecord = false
    /// Plus aucun puzzle à servir (bibliothèque vide) : la série ne peut pas commencer.
    private(set) var isUnavailable = false

    private var currentStep = 0
    private var used = Set<UUID>()
    private var nextPuzzle: Puzzle?
    private var nonce = 0
    private var tasks: [Task<Void, Never>] = []
    private var ticker: Task<Void, Never>?

    init(modelContext: ModelContext, duration: TimeInterval = PuzzleRushViewModel.configuredDuration,
         playerRating: Double = PuzzleRatingStore.load().rating, now: @escaping () -> Date = Date.init,
         recordDefaults: UserDefaults = .standard,
         remoteRecord: @escaping @MainActor () -> Int? = { PuzzleRushRecordStore.cloudValue() }) {
        self.modelContext = modelContext
        self.duration = duration
        self.now = now
        self.recordDefaults = recordDefaults
        self.remoteRecord = remoteRecord
        run = PuzzleRushRun(playerRating: playerRating, duration: duration)
        previousBest = PuzzleRushRecordStore.best(defaults: recordDefaults, remote: remoteRecord())
        // Le premier puzzle est tiré pendant qu'on lit la règle : pas d'attente au « 1 ».
        nextPuzzle = PuzzleRushDrawer.next(target: run.targetRating, excluding: used, in: modelContext)
        isUnavailable = nextPuzzle == nil
    }

    /// Crochet de test (Debug) : `-puzzleRushSeconds 6` raccourcit la série, pour voir le bilan sans
    /// attendre trois minutes.
    static var configuredDuration: TimeInterval {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "-puzzleRushSeconds"), index + 1 < arguments.count,
           let seconds = Double(arguments[index + 1]) {
            return seconds
        }
        #endif
        return PuzzleRushRun.duration
    }

    func remaining() -> TimeInterval { run.remaining(at: now()) }

    var score: Int { run.solved }
    var errors: Int { run.errors }

    // MARK: Déroulé

    /// « Commencer » : décompte, puis le premier puzzle.
    func begin() {
        guard phase == .intro || phase == .finished, !isUnavailable else { return }
        if phase == .finished { reset() }
        phase = .countdown(3)
        Haptics.prepare()
        schedule {
            for value in [2, 1] {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                self.phase = .countdown(value)
            }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self.startPlaying()
        }
    }

    private func reset() {
        cancelTasks()
        run = PuzzleRushRun(playerRating: PuzzleRatingStore.load().rating, duration: duration)
        previousBest = PuzzleRushRecordStore.best(defaults: recordDefaults, remote: remoteRecord())
        isNewRecord = false
        missed = []
        used = []
        flash = nil
        puzzle = nil
        nextPuzzle = PuzzleRushDrawer.next(target: run.targetRating, excluding: used, in: modelContext)
        isUnavailable = nextPuzzle == nil
    }

    private func startPlaying() {
        phase = .playing
        loadNextPuzzle()
        run.start(at: now())
        startTicker()
    }

    /// L'app quitte le premier plan (ou l'écran se ferme) : le temps s'arrête, le plateau se voile — on ne
    /// réfléchit pas pendant la pause.
    func pause() {
        switch phase {
        case .playing:
            run.pause(at: now())
            ticker?.cancel()
            phase = .paused
        case .countdown:
            cancelTasks()
            phase = .intro
        default:
            break
        }
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        run.start(at: now())
        startTicker()
    }

    /// Le temps qui s'écoule : vérifié quatre fois par seconde.
    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                if self.phase == .playing, self.run.remaining(at: self.now()) <= 0 { self.finishRun() }
            }
        }
    }

    private func finishRun() {
        guard phase == .playing || phase == .paused else { return }
        run.pause(at: now())
        ticker?.cancel()
        cancelTasks()
        isBusy = false
        selectedSquare = nil
        legalTargetSquares = []
        pendingPromotion = nil
        let result = PuzzleRushRecordStore.submit(run.solved, defaults: recordDefaults, remote: remoteRecord())
        previousBest = result.previous
        isNewRecord = result.isNew
        if run.solved + run.errors > 0 { TrainingDays.markToday() }
        phase = .finished
        Haptics.gameEnded()
    }

    // MARK: Puzzles

    private func loadNextPuzzle() {
        let next = nextPuzzle ?? PuzzleRushDrawer.next(target: run.targetRating, excluding: used, in: modelContext)
        nextPuzzle = nil
        guard let next, let position = Position(fen: next.fen ?? "") else {
            finishRun()
            return
        }
        used.insert(next.id)
        puzzle = next
        board = Board(position: position)
        orientation = position.sideToMove
        lastMove = nil
        currentStep = 0
        hintMoves = []
        rejectedMove = nil
        selectedSquare = nil
        legalTargetSquares = []
        isBusy = false
    }

    /// Le suivant est tiré dès le précédent réglé, à la NOUVELLE difficulté, pendant le court retour visuel.
    private func prefetch() {
        nextPuzzle = PuzzleRushDrawer.next(target: run.targetRating, excluding: used, in: modelContext)
    }

    private var solution: [String] { puzzle?.solutionLANs ?? [] }

    // MARK: Interaction

    var acceptsInput: Bool { phase == .playing && !isBusy && puzzle != nil }

    func selectSquare(_ square: Square) {
        guard acceptsInput else { return }
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

    func attemptMove(from start: Square, to end: Square) {
        guard acceptsInput,
              board.position.piece(at: start)?.color == board.position.sideToMove,
              board.canMove(pieceAt: start, to: end) else {
            Haptics.illegal()
            selectedSquare = nil
            legalTargetSquares = []
            return
        }
        var scratch = board
        guard let move = scratch.move(pieceAt: start, to: end) else { return }
        selectedSquare = nil
        legalTargetSquares = []
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

    private func validate(scratch: Board, move: Move) {
        guard currentStep < solution.count else { return }
        var mates = false
        if case .checkmate = scratch.state { mates = true }
        guard move.lan == solution[currentStep] || mates else {
            reject(move)
            return
        }
        board = scratch
        lastMove = move
        Haptics.move()
        currentStep += 1
        if currentStep >= solution.count || mates {
            puzzleSolved()
        } else {
            playReply()
        }
    }

    /// La riposte adverse, vite : la série se joue au rythme du chrono.
    private func playReply() {
        guard currentStep < solution.count else { return }
        let lan = solution[currentStep]
        isBusy = true
        schedule {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            if let move = self.apply(lan: lan) {
                self.lastMove = move
                Haptics.move()
            }
            self.currentStep += 1
            self.isBusy = false
            if self.currentStep >= self.solution.count { self.puzzleSolved() }
        }
    }

    private func puzzleSolved() {
        run.recordSolved(rating: puzzle?.rating)
        nonce += 1
        flash = Flash(solved: true, id: nonce)
        isBusy = true
        prefetch()
        schedule {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self.loadNextPuzzle()
        }
    }

    /// Coup faux : il clignote en rouge (animation de ``ChessBoardView``), qui rappelle ensuite
    /// ``finishRejectedAttempt()``.
    private func reject(_ move: Move) {
        Haptics.illegal()
        isBusy = true
        nonce += 1
        rejectedMove = ChessBoardView.RejectedMove(id: nonce, from: move.start, to: move.end)
    }

    /// Fin de l'animation du coup faux : une erreur, la bonne réponse fléchée un instant, puis la suite.
    func finishRejectedAttempt() {
        rejectedMove = nil
        guard phase == .playing, let puzzle else { return }
        run.recordError()
        nonce += 1
        flash = Flash(solved: false, id: nonce)
        missed.append(Missed(id: puzzle.id, fen: puzzle.fen ?? "", solution: Self.solutionText(of: puzzle),
                             rating: puzzle.rating, whiteToMove: orientation == .white))
        if currentStep < solution.count {
            let lan = solution[currentStep]
            hintMoves = [HintMove(rank: 1, from: Square(String(lan.prefix(2))),
                                  to: Square(String(lan.dropFirst(2).prefix(2))), strength: 1)]
        }
        if run.errors >= PuzzleRushRun.maxErrors {
            schedule {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                self.finishRun()
            }
            return
        }
        prefetch()
        schedule {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self.loadNextPuzzle()
        }
    }

    @discardableResult
    private func apply(lan: String) -> Move? {
        guard lan.count >= 4 else { return nil }
        var scratch = board
        guard let applied = scratch.move(pieceAt: Square(String(lan.prefix(2))),
                                         to: Square(String(lan.dropFirst(2).prefix(2)))) else { return nil }
        var final = applied
        if case .promotion = scratch.state {
            let kind = lan.count == 5 ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen) : .queen
            final = scratch.completePromotion(of: applied, to: kind)
        }
        board = scratch
        return final
    }

    /// La solution entière en notation de l'utilisateur, numérotée : « 1. Fxh7+ Rf8 2. Te5 ».
    static func solutionText(of puzzle: Puzzle) -> String {
        guard let position = Position(fen: puzzle.fen ?? "") else { return "" }
        var board = Board(position: position)
        var sans: [String] = []
        for lan in puzzle.solutionLANs ?? [] where lan.count >= 4 {
            guard var move = board.move(pieceAt: Square(String(lan.prefix(2))),
                                        to: Square(String(lan.dropFirst(2).prefix(2)))) else { break }
            if case .promotion = board.state {
                let kind = lan.count == 5 ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen) : .queen
                move = board.completePromotion(of: move, to: kind)
            }
            sans.append(move.san)
        }
        let shown = SANFormatter.display(sans)
        let whiteFirst = position.sideToMove == .white
        var number = position.clock.fullmoves
        var parts: [String] = []
        for (index, san) in shown.enumerated() {
            let isWhite = whiteFirst ? index % 2 == 0 : index % 2 == 1
            if isWhite { parts.append("\(number). \(san)") }
            else if index == 0 { parts.append("\(number)… \(san)") }
            else { parts.append(san) }
            if !isWhite { number += 1 }
        }
        return parts.joined(separator: " ")
    }

    // MARK: Tâches

    private func schedule(_ work: @escaping @MainActor () async -> Void) {
        tasks.append(Task { await work() })
    }

    private func cancelTasks() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    /// L'écran se ferme : plus rien ne tourne.
    func tearDown() {
        cancelTasks()
        ticker?.cancel()
    }
}
