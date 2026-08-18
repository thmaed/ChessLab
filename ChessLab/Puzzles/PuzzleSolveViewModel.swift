import ChessKit
import Foundation
import Observation
import SwiftData

/// Résout un puzzle : "Trouvez mieux que dans la partie", validation
/// coup par coup contre la séquence stockée, riposte adverse
/// automatique, échec une fois les essais épuisés (voir
/// ``AppSettings/puzzleAttempts``, un seul par défaut) → solution fléchée.
/// Met à jour la répétition espacée (SM-2) du puzzle sur résolution (succès
/// ou échec).
@Observable
@MainActor
final class PuzzleSolveViewModel {
    private(set) var puzzle: Puzzle
    private let modelContext: ModelContext
    /// Critères de la série en cours (niveau/phase/thème choisis dans
    /// ``PuzzleQueueView``) — chaque "Nouveau puzzle" retire le prochain
    /// puzzle dû correspondant, la série est ouverte (voir
    /// ``PuzzleSessionFilter``).
    private let filter: PuzzleSessionFilter
    /// Prétiré à la fin du puzzle courant (voir `finish`) : détermine si
    /// "Nouveau puzzle" est proposé, sans requête dans `body`.
    private var nextPuzzle: Puzzle?
    /// Numéro du puzzle courant dans la série (1-based).
    private(set) var sessionIndex = 1

    private(set) var board: Board
    private(set) var orientation: Piece.Color

    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?
    var pendingPromotion: PendingPromotion?
    /// Coup faux en cours de rejeu visuel (aller-retour + flash rouge dans
    /// ``ChessBoardView``) — le plateau réel n'est PAS muté, on ne fait que
    /// montrer l'erreur puis l'annuler. `nil` hors animation.
    private(set) var rejectedMove: ChessBoardView.RejectedMove?
    private var rejectNonce = 0
    /// Tâche différée qui joue le coup révélé 0,5 s après le dernier échec (voir
    /// ``revealSolution()``) — suivie pour pouvoir l'ANNULER : « Nouveau
    /// puzzle » est déjà proposé pendant ce délai, et le coup révélé de
    /// l'ancien puzzle s'appliquait alors au plateau du SUIVANT (coup fantôme,
    /// puzzle rendu insoluble) dès qu'il s'y trouvait légal.
    private var revealTask: Task<Void, Never>?
    /// Riposte adverse différée — suivie pour pouvoir l'annuler au puzzle
    /// suivant, exactement comme ``revealTask``.
    private var forcedReplyTask: Task<Void, Never>?

    private(set) var currentStep = 0
    /// Essais accordés à CE puzzle — figé à son ouverture d'après
    /// ``AppSettings/puzzleAttempts``, pour qu'un changement de réglage en
    /// cours de résolution ne modifie pas le puzzle sous les doigts.
    private(set) var allowedAttempts = AppSettings.shared.puzzleAttempts
    private(set) var attemptsRemaining = AppSettings.shared.puzzleAttempts
    private(set) var isSolved = false
    private(set) var isFailed = false
    /// Vrai pendant le court délai avant la riposte adverse automatique —
    /// empêche un coup de l'utilisateur de s'intercaler.
    private(set) var isAutoPlaying = false
    var hintMoves: [HintMove] = []

    var isFinished: Bool { isSolved || isFailed }
    private var solutionMoves: [String] { puzzle.solutionLANs ?? [] }

    /// Tire le premier puzzle de la série — `nil` si plus aucun puzzle dû
    /// ne correspond au filtre (l'appelant n'affiche le bouton de
    /// lancement que si le compte est non nul, ce cas reste défensif).
    init?(filter: PuzzleSessionFilter, modelContext: ModelContext) {
        guard let first = PuzzleSessionDrawer.drawNext(matching: filter, in: modelContext) else { return nil }
        self.puzzle = first
        self.filter = filter
        self.modelContext = modelContext
        let position = Position(fen: first.fen ?? "") ?? .standard
        board = Board(position: position)
        orientation = position.sideToMove
        markFirstOpenIfNeeded(first)
    }

    /// Série ouverte : pas de total connu à l'avance, seulement le rang
    /// du puzzle courant.
    var sessionProgressText: String? {
        "Puzzle n°\(sessionIndex)"
    }

    var hasNextPuzzle: Bool { nextPuzzle != nil }

    private func markFirstOpenIfNeeded(_ puzzle: Puzzle) {
        // Marque la toute première présentation réelle (pas seulement
        // listée dans la file) — voir `PuzzleQueueView`, qui priorise
        // les puzzles jamais ouverts avant de répéter celui-ci.
        if puzzle.firstOpenedAt == nil {
            puzzle.firstOpenedAt = Date()
            PersistenceLog.save(modelContext)
        }
    }

    /// Charge le puzzle suivant de la série dans cette même vue (sans
    /// navigation), pour le bouton "Nouveau puzzle" affiché sous le
    /// résultat — no-op si plus rien de dû ne correspond au filtre
    /// (voir `hasNextPuzzle`, alimenté par le prétirage de `finish`).
    func loadNextPuzzle() {
        guard let next = nextPuzzle else { return }
        // Avant toute chose : une révélation de solution encore en attente
        // jouerait son coup sur le plateau du puzzle qu'on charge ici.
        revealTask?.cancel()
        forcedReplyTask?.cancel()
        revealTask = nil
        nextPuzzle = nil
        sessionIndex += 1

        puzzle = next
        let position = Position(fen: next.fen ?? "") ?? .standard
        board = Board(position: position)
        orientation = position.sideToMove

        selectedSquare = nil
        legalTargetSquares = []
        lastMove = nil
        pendingPromotion = nil
        currentStep = 0
        allowedAttempts = AppSettings.shared.puzzleAttempts
        attemptsRemaining = allowedAttempts
        isSolved = false
        isFailed = false
        isAutoPlaying = false
        hintMoves = []
        rejectedMove = nil

        markFirstOpenIfNeeded(next)
    }

    // MARK: Interaction utilisateur

    func selectSquare(_ square: Square) {
        guard !isFinished, !isAutoPlaying else { return }

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

    /// Flèche le prochain coup attendu SANS le jouer ni terminer le
    /// puzzle — contrairement à `revealSolution` (déclenchée après 3
    /// échecs), qui elle joue le coup et clôt la carte. Un indice reste
    /// une aide facultative pendant l'apprentissage, pas un abandon.
    func showHint() {
        guard !isFinished, !isAutoPlaying, currentStep < solutionMoves.count else { return }
        let lan = solutionMoves[currentStep]
        guard lan.count >= 4 else { return }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        hintMoves = [HintMove(rank: 1, from: start, to: end, strength: 1)]
    }

    /// - important: Le garde de COULEUR évite qu'un drag manifestement
    /// accidentel (une pièce du camp adverse, légale au sens de ChessKit qui
    /// ne consulte pas le trait) ne soit décompté comme un essai raté — voir
    /// ``PlayViewModel/attemptUserMove(from:to:)``.
    func attemptMove(from start: Square, to end: Square) {
        guard
            !isFinished, !isAutoPlaying,
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

    func cancelPromotion() {
        pendingPromotion = nil
    }

    // MARK: Validation / progression

    private func validate(scratch: Board, move: Move) {
        guard currentStep < solutionMoves.count else { return }

        guard move.lan == solutionMoves[currentStep] else {
            rejectWrongMove(move)
            return
        }

        board = scratch
        lastMove = move
        hintMoves = []
        Haptics.move()
        currentStep += 1

        if currentStep >= solutionMoves.count {
            finish(success: true)
        } else {
            playForcedReply()
        }
    }

    /// Essai raté : le plateau ne bouge pas (on ne joue pas le coup faux) —
    /// ``ChessBoardView`` anime l'aller-retour + le flash rouge, puis
    /// rappelle ``finishRejectedAttempt()``. L'interaction est bloquée
    /// pendant l'animation via `isAutoPlaying`, comme pour la riposte auto.
    private func rejectWrongMove(_ move: Move) {
        Haptics.illegal()
        isAutoPlaying = true
        rejectNonce += 1
        rejectedMove = ChessBoardView.RejectedMove(id: rejectNonce, from: move.start, to: move.end)
    }

    /// Appelé par ``ChessBoardView`` à la fin de l'animation de rejet.
    func finishRejectedAttempt() {
        rejectedMove = nil
        isAutoPlaying = false
        registerWrongAttempt()
    }

    private func registerWrongAttempt() {
        attemptsRemaining -= 1
        if attemptsRemaining <= 0 {
            revealSolution()
        }
    }

    /// Joue la riposte adverse forcée de la séquence après un court délai
    /// (rythme naturel, même idée que
    /// `PlayViewModel.bookMoveIfAvailable`), pas instantanément.
    private func playForcedReply() {
        guard currentStep < solutionMoves.count else { return }
        let lan = solutionMoves[currentStep]
        isAutoPlaying = true
        // Tâche SUIVIE, comme `revealTask` : sans ça, la riposte différée de
        // l'ancien puzzle se jouait sur le plateau du nouveau dès que
        // l'enchaînement changerait. Latent aujourd'hui (« Nouveau puzzle »
        // n'apparaît qu'après `finish`), mais le même piège a déjà été corrigé
        // une fois à côté — autant ne pas le laisser en embuscade.
        forcedReplyTask?.cancel()
        forcedReplyTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64.random(in: 400_000_000...700_000_000))
            guard !Task.isCancelled else { return }
            self?.applyForcedMove(lan: lan)
        }
    }

    private func applyForcedMove(lan: String) {
        defer { isAutoPlaying = false }
        guard lan.count >= 4 else { return }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))

        var scratch = board
        guard let applied = scratch.move(pieceAt: start, to: end) else { return }
        var finalMove = applied

        if case .promotion = scratch.state {
            let kind: Piece.Kind = lan.count == 5
                ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                : .queen
            finalMove = scratch.completePromotion(of: applied, to: kind)
        }

        board = scratch
        lastMove = finalMove
        Haptics.move()
        currentStep += 1

        if currentStep >= solutionMoves.count {
            finish(success: true)
        }
    }

    private func revealSolution() {
        guard currentStep < solutionMoves.count else {
            finish(success: false)
            return
        }
        let lan = solutionMoves[currentStep]
        guard lan.count >= 4 else {
            finish(success: false)
            return
        }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        hintMoves = [HintMove(rank: 1, from: start, to: end, strength: 1)]
        finish(success: false)
        // Ancre la solution : après un court délai, joue le coup révélé sur
        // le plateau (comme la révision de répertoire), la flèche restant
        // visible — voir « le jouer sur le plateau après 0,5 s » (§G7).
        revealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            // `try?` avale l'annulation du sleep : sans ce contrôle, un
            // « Nouveau puzzle » pendant le délai jouerait quand même le coup.
            guard !Task.isCancelled else { return }
            self?.playRevealedMove(lan: lan)
        }
    }

    private func playRevealedMove(lan: String) {
        guard lan.count >= 4 else { return }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        var scratch = board
        guard let applied = scratch.move(pieceAt: start, to: end) else { return }
        var finalMove = applied
        if case .promotion = scratch.state {
            let kind: Piece.Kind = lan.count == 5
                ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                : .queen
            finalMove = scratch.completePromotion(of: applied, to: kind)
        }
        board = scratch
        lastMove = finalMove
        Haptics.move()
    }

    private func finish(success: Bool) {
        if success {
            isSolved = true
        } else {
            isFailed = true
        }
        Haptics.gameEnded()
        updateSchedule(success: success)
        // Prétire le puzzle suivant APRÈS la mise à jour SM-2 : le puzzle
        // courant n'est alors plus dû (son `dueDate` vient d'avancer) et
        // ne peut pas être retiré ; l'exclusion explicite reste par
        // sécurité.
        nextPuzzle = PuzzleSessionDrawer.drawNext(matching: filter, excluding: puzzle.id, in: modelContext)
    }

    private func updateSchedule(success: Bool) {
        let schedule = SpacedRepetition.Schedule(
            easinessFactor: puzzle.easinessFactor ?? 2.5,
            intervalDays: puzzle.intervalDays ?? 0,
            repetitions: puzzle.repetitions ?? 0
        )
        let next = SpacedRepetition.next(after: schedule, success: success)
        puzzle.easinessFactor = next.easinessFactor
        puzzle.intervalDays = next.intervalDays
        puzzle.repetitions = next.repetitions
        puzzle.dueDate = SpacedRepetition.dueDate(for: next)
        puzzle.successCount = (puzzle.successCount ?? 0) + (success ? 1 : 0)
        puzzle.failureCount = (puzzle.failureCount ?? 0) + (success ? 0 : 1)
        PersistenceLog.save(modelContext)
        // Recopie la progression vers son miroir SYNCHRONISÉ (iCloud) : la
        // bibliothèque reste locale, seule cette progression personnelle suit
        // les appareils (voir ``PuzzleProgressSync``).
        PuzzleProgressSync.mirror(puzzle, in: modelContext)
    }
}
