import ChessKit
import Foundation
import Observation
import SwiftData
import SwiftUI
import UIKit

/// Orchestre une partie du mode "Deux humains sur le même appareil" :
/// version allégée de ``PlayViewModel``, sans aucune dépendance moteur
/// (pas d'indice, pas de barre d'éval, pas de reprise de coup — voir
/// ``TwoPlayerGameSettings``).
@Observable
@MainActor
final class TwoPlayerViewModel {

    // MARK: État d'échecs

    private(set) var board: Board
    private(set) var game: Game
    private(set) var currentIndex: MoveTree.Index
    private(set) var moveLog: [Move] = []

    let settings: TwoPlayerGameSettings
    private let modelContext: ModelContext

    // MARK: Pendule

    private(set) var clock: GameClock?
    private var clockPausedForBackground = false

    // MARK: Interaction plateau

    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?
    var pendingPromotion: PendingPromotion?

    /// Orientation courante du plateau (bas de l'écran). Pivote à 180°
    /// après chaque coup en mode ``TwoPlayerGameSettings/RotationMode/faceToFace``,
    /// reste figée (Blancs en bas) en mode ``TwoPlayerGameSettings/RotationMode/fixed``.
    private(set) var orientation: Piece.Color = .white

    private(set) var outcome: GameOutcome? {
        didSet {
            guard let outcome, oldValue == nil else { return }
            GameLibraryService.recordTwoHumanGame(
                game: game, outcome: outcome,
                whiteName: settings.whiteName, blackName: settings.blackName,
                in: modelContext
            )
            // Annonce du RÉSULTAT (Lot 4.B) : les coups étaient annoncés, la
            // fin de partie non.
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: outcome.summary(whiteName: settings.whiteName, blackName: settings.blackName)
                )
            }
        }
    }

    // MARK: Initialisation

    /// Démarre une nouvelle partie (position standard uniquement).
    init(settings: TwoPlayerGameSettings, modelContext: ModelContext) {
        self.settings = settings
        self.modelContext = modelContext

        let startPosition = Position.standard
        board = Board(position: startPosition)
        let newGame = Game(startingWith: startPosition)
        game = newGame
        currentIndex = newGame.startingIndex
        clock = settings.timeControl.hasClock ? GameClock(control: settings.timeControl) : nil

        AutosaveStore.clearTwoPlayer()
        wireClock()
    }

    /// Reprend une partie sauvegardée. `nil` si la sauvegarde est
    /// irrécupérable (voir ``replay(lans:)``).
    init?(resuming autosave: TwoPlayerGameAutosave, modelContext: ModelContext) {
        settings = autosave.settings
        self.modelContext = modelContext

        let startPosition = Position.standard
        board = Board(position: startPosition)
        let newGame = Game(startingWith: startPosition)
        game = newGame
        currentIndex = newGame.startingIndex

        clock = autosave.settings.timeControl.hasClock
            ? GameClock(control: autosave.settings.timeControl)
            : nil
        if let white = autosave.whiteRemaining, let black = autosave.blackRemaining {
            clock?.restore(white: white, black: black)
        }

        wireClock()

        // Voir ``PlayViewModel/init(resuming:modelContext:)`` : un seul LAN
        // inapplicable fausserait tous les coups suivants — la reprise est
        // déclarée impossible plutôt que de restaurer une autre partie.
        guard replay(lans: autosave.moveLANs) else {
            AutosaveStore.clearTwoPlayer()
            return nil
        }

        // Pendule restaurée à l'arrêt : sans ce démarrage, le joueur au trait
        // au moment de la reprise jouerait son premier coup hors du temps
        // (avantage arbitral). Sans `previousMover` : aucun incrément crédité.
        if outcome == nil {
            clock?.startTurn(for: board.position.sideToMove)
        }

        if settings.rotationMode == .faceToFace {
            orientation = board.position.sideToMove
        }
    }

    private func wireClock() {
        clock?.onFlagFall = { [weak self] color in
            self?.handleFlagFall(color)
        }
    }

    // MARK: Replay (restauration)

    /// - Returns: `false` au PREMIER coup inapplicable — voir
    /// ``PlayViewModel/replay(lans:)`` pour le détail : poursuivre le rejeu
    /// après un coup sauté restaure silencieusement une autre partie.
    @discardableResult
    private func replay(lans: [String]) -> Bool {
        var moves: [Move] = []

        for lan in lans {
            guard lan.count >= 4 else { return false }
            let start = Square(String(lan.prefix(2)))
            let end = Square(String(lan.dropFirst(2).prefix(2)))

            guard let applied = board.move(pieceAt: start, to: end) else { return false }
            var finalMove = applied

            if case .promotion = board.state {
                let kind: Piece.Kind = lan.count == 5
                    ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                    : .queen
                finalMove = board.completePromotion(of: applied, to: kind)
            }

            currentIndex = game.make(move: finalMove, from: currentIndex)
            moves.append(finalMove)
        }

        moveLog = moves
        lastMove = moves.last

        if let end = outcomeIfGameEnded() {
            outcome = end
        }
        return true
    }

    // MARK: Interaction utilisateur — sélection (tap-tap)

    func selectSquare(_ square: Square) {
        guard canUserAct else { return }

        if let selected = selectedSquare {
            if legalTargetSquares.contains(square) {
                attemptUserMove(from: selected, to: square)
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

    // MARK: Consultation (navigation dans la partie)

    /// Demi-coup consulté (0 = départ, `moveLog.count` = position vivante) ;
    /// `nil` = direct. Lecture seule.
    private(set) var reviewPly: Int?
    private var reviewBoard: Board?

    var isReviewing: Bool { reviewPly != nil }
    var displayedBoard: Board { reviewBoard ?? board }
    var displayedLastMove: Move? {
        guard let reviewPly else { return lastMove }
        return reviewPly > 0 ? moveLog[reviewPly - 1] : nil
    }
    var totalPlies: Int { moveLog.count }
    var displayedPly: Int { reviewPly ?? moveLog.count }

    /// Reprise possible hors pendule (les deux joueurs reviennent en
    /// arrière d'un commun accord) et pas déjà sur le dernier coup.
    var canResumeFromReview: Bool {
        guard let reviewPly else { return false }
        return clock == nil && outcome == nil && reviewPly < moveLog.count
    }

    func review(toPly ply: Int) {
        let clamped = max(0, min(ply, moveLog.count))
        guard clamped != moveLog.count else {
            reviewToLive()
            return
        }
        reviewPly = clamped
        reviewBoard = boardAfter(plies: clamped)
        clearSelection()
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }
    func reviewToStart() { review(toPly: 0) }

    func reviewToLive() {
        reviewPly = nil
        reviewBoard = nil
        clearSelection()
    }

    func resumeFromReview() {
        guard let reviewPly, canResumeFromReview else { return }
        let keep = reviewPly
        reviewToLive()
        rebuild(moves: Array(moveLog.prefix(keep)))
    }

    private func boardAfter(plies: Int) -> Board {
        var replayBoard = Board(position: .standard)
        for move in moveLog.prefix(plies) {
            guard let made = replayBoard.move(pieceAt: move.start, to: move.end) else { continue }
            if case .promotion = replayBoard.state, let promoted = move.promotedPiece {
                _ = replayBoard.completePromotion(of: made, to: promoted.kind)
            }
        }
        return replayBoard
    }

    /// Reconstruit la partie en ne gardant que `moves` (reprise depuis la
    /// position consultée) — même mécanique de rejeu que ``replay``.
    private func rebuild(moves: [Move]) {
        let startPosition = Position.standard
        var newBoard = Board(position: startPosition)
        var newGame = Game(startingWith: startPosition)
        var index = newGame.startingIndex
        var applied: [Move] = []

        for move in moves {
            guard let made = newBoard.move(pieceAt: move.start, to: move.end) else { continue }
            var finalMove = made
            if case .promotion = newBoard.state, let promoted = move.promotedPiece {
                finalMove = newBoard.completePromotion(of: made, to: promoted.kind)
            }
            index = newGame.make(move: finalMove, from: index)
            applied.append(finalMove)
        }

        board = newBoard
        game = newGame
        currentIndex = index
        moveLog = applied
        lastMove = applied.last
        outcome = outcomeIfGameEnded()
        clearSelection()
        persistAutosave()
        if settings.rotationMode == .faceToFace {
            orientation = board.position.sideToMove
        }
    }

    private var canUserAct: Bool {
        outcome == nil && pendingPromotion == nil
    }

    // MARK: Interaction utilisateur — coup (drag & drop ou tap-tap)

    /// - important: Garde de couleur indispensable — voir
    /// ``PlayViewModel/attemptUserMove(from:to:)`` : `canMove` ne consulte pas
    /// le trait, un drag sur une pièce du camp adverse jouerait deux coups de
    /// la même couleur d'affilée.
    func attemptUserMove(from start: Square, to end: Square) {
        guard
            canUserAct, start != end,
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

        commit(scratch: scratch, move: move)
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil

        var scratch = pending.scratch
        let move = scratch.completePromotion(of: pending.move, to: kind)
        commit(scratch: scratch, move: move)
    }

    func cancelPromotion() {
        pendingPromotion = nil
    }

    // MARK: Finalisation d'un coup

    private func announceMove(_ move: Move) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let who = move.piece.color == .white ? "Blancs" : "Noirs"
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(who) : \(MoveNarration.describe(san: move.san))"
        )
    }

    private func commit(scratch: Board, move: Move) {
        let previousMover = board.position.sideToMove
        board = scratch
        currentIndex = game.make(move: move, from: currentIndex)
        moveLog.append(move)
        lastMove = move

        playFeedback(for: move, state: board.state)
        announceMove(move)
        persistAutosave()

        if let end = outcomeIfGameEnded() {
            outcome = end
            clock?.pause()
            Haptics.gameEnded()
            AutosaveStore.clearTwoPlayer()
            return
        }

        clock?.startTurn(for: board.position.sideToMove, previousMover: previousMover)

        if settings.rotationMode == .faceToFace {
            withAnimation(.easeInOut(duration: 0.5)) {
                orientation = board.position.sideToMove
            }
        }
    }

    private func playFeedback(for move: Move, state: Board.State) {
        switch state {
        case .check, .checkmate:
            SoundPlayer.shared.play(.check)
            Haptics.check()
        default:
            switch move.result {
            case .castle:
                SoundPlayer.shared.play(.castle)
                Haptics.move()
            case .capture:
                SoundPlayer.shared.play(.capture)
                Haptics.capture()
            case .move:
                SoundPlayer.shared.play(.move)
                Haptics.move()
            }
        }
    }

    private func outcomeIfGameEnded() -> GameOutcome? {
        GameOutcome.fromBoardState(board.state)
    }

    // MARK: Actions utilisateur

    func resign(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .resignation)
        clock?.pause()
        Haptics.gameEnded()
        AutosaveStore.clearTwoPlayer()
    }

    func agreeToDraw() {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: nil, reason: .drawByAgreement)
        clock?.pause()
        Haptics.gameEnded()
        AutosaveStore.clearTwoPlayer()
    }

    private func handleFlagFall(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .timeout)
        Haptics.gameEnded()
        AutosaveStore.clearTwoPlayer()
    }

    // MARK: Cycle de vie de l'app (pendule en arrière-plan)

    func handleAppBackgrounded() {
        guard let clock, outcome == nil, clock.isRunning else { return }
        clock.pause()
        clockPausedForBackground = true
    }

    func handleAppForegrounded() {
        guard clockPausedForBackground else { return }
        clockPausedForBackground = false
        guard outcome == nil else { return }
        clock?.startTurn(for: board.position.sideToMove)
    }

    // MARK: Autosauvegarde

    private func persistAutosave() {
        guard outcome == nil else {
            AutosaveStore.clearTwoPlayer()
            return
        }

        let record = TwoPlayerGameAutosave(
            settings: settings,
            moveLANs: moveLog.map(\.lan),
            // `remaining(for:)` PRÉCIS et non `whiteRemaining` publié : la
            // valeur publiée n'avance qu'au pas d'affichage (jusqu'à 1 s de
            // retard) — c'est le contrat documenté de `GameClock`, qui
            // réserve les temps précis à la logique et à l'autosauvegarde.
            whiteRemaining: clock?.remaining(for: .white),
            blackRemaining: clock?.remaining(for: .black),
            savedAt: Date()
        )
        AutosaveStore.saveTwoPlayer(record)
    }

    /// Coups joués, en SAN, pour la liste de coups (révélée seulement sur
    /// l'écran de résultat — masquée pendant la partie, voir
    /// ``TwoPlayerGameView``).
    /// Pièces capturées de part et d'autre + différentiel de matériel.
    var capturedMaterial: CapturedMaterial {
        CapturedMaterial.from(moveLog: moveLog, board: board)
    }

    var sanMoveList: [String] {
        moveLog.map(\.san)
    }
}
