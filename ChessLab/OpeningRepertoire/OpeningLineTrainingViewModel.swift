import ChessKit
import Foundation
import Observation

/// Rejoue une ouverture de la bibliothèque ECO coup après coup, du début
/// à la fin de la ligne : l'utilisateur trouve
/// chacun de ses coups dans l'ordre, la riposte adverse est auto-jouée
/// entre deux, jusqu'à épuiser la ligne. Un coup manqué (3 essais) est
/// simplement révélé et joué — la révision continue, elle ne s'arrête
/// pas comme un puzzle raté. Pas de répétition espacée : une entrée de
/// bibliothèque se rejoue à volonté, ce n'est pas un répertoire personnel
/// à faire progresser.
@Observable
@MainActor
final class OpeningLineTrainingViewModel {
    let familyName: String
    let color: Piece.Color
    /// Ligne complète (les deux camps), dans l'ordre — un seul chemin,
    /// jamais de variante (voir ``OpeningLibraryEntry``).
    private let moves: [(san: String, lan: String)]

    private(set) var board: Board
    let orientation: Piece.Color

    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?
    var pendingPromotion: PendingPromotion?

    /// Index du prochain coup à jouer dans `moves` (0-based, les deux
    /// camps confondus).
    private(set) var currentStep = 0
    private(set) var attemptsRemaining = 3
    private(set) var isLineComplete = false
    /// Vrai pendant le court délai avant la riposte adverse automatique
    /// (ou avant l'auto-jeu d'un coup révélé) — empêche un coup de
    /// l'utilisateur de s'intercaler, même mécanique que
    /// ``PuzzleSolveViewModel``.
    private(set) var isAutoPlaying = false
    var hintMoves: [HintMove] = []

    /// FEN de la position finale, une fois la ligne terminée — pour
    /// "Continuer contre Stockfish depuis ici".
    var resultingFEN: String? { isLineComplete ? board.position.fen : nil }

    var isUserTurn: Bool {
        !isLineComplete && !isAutoPlaying && pendingPromotion == nil && currentStep < moves.count
    }

    var progressText: String {
        "Coup \(currentStep) sur \(moves.count)"
    }

    /// `nil` si le PGN de l'entrée ne contient aucun coup (ne devrait pas
    /// arriver pour une entrée embarquée valide, mais reste défensif).
    init?(entry: OpeningLibraryEntry, color: Piece.Color) {
        guard let game = try? Game(pgn: entry.pgn) else { return nil }

        var collected: [(san: String, lan: String)] = []
        var index = game.startingIndex
        while game.moves.hasIndex(after: index) {
            index = game.moves.index(after: index)
            if let move = game.moves[index] {
                collected.append((san: move.san, lan: move.lan))
            }
        }
        guard !collected.isEmpty else { return nil }

        moves = collected
        familyName = entry.family
        self.color = color
        orientation = color
        board = Board(position: .standard)

        advanceOpponentMoves()
    }

    private func plyColor(at ply: Int) -> Piece.Color {
        ply % 2 == 0 ? .white : .black
    }

    /// Rejoue la même ligne depuis le début (bouton "Rejouer").
    func restart() {
        board = Board(position: .standard)
        selectedSquare = nil
        legalTargetSquares = []
        lastMove = nil
        pendingPromotion = nil
        currentStep = 0
        attemptsRemaining = 3
        isLineComplete = false
        isAutoPlaying = false
        hintMoves = []
        advanceOpponentMoves()
    }

    // MARK: Interaction utilisateur

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

    /// - important: Le garde de COULEUR évite qu'un drag manifestement
    /// accidentel (une pièce du camp adverse, légale au sens de ChessKit qui
    /// ne consulte pas le trait) ne soit décompté comme un essai raté — voir
    /// ``PlayViewModel/attemptUserMove(from:to:)``.
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

    func cancelPromotion() {
        pendingPromotion = nil
    }

    /// Flèche le coup à jouer sans le jouer ni terminer la ligne — reste
    /// une aide facultative, contrairement au coup révélé après 3 échecs
    /// (qui lui est auto-joué).
    func showHint() {
        guard isUserTurn else { return }
        let lan = moves[currentStep].lan
        guard lan.count >= 4 else { return }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        hintMoves = [HintMove(rank: 1, from: start, to: end, strength: 1)]
    }

    // MARK: Progression

    private func validate(scratch: Board, move: Move) {
        guard currentStep < moves.count else { return }

        guard move.lan == moves[currentStep].lan else {
            Haptics.illegal()
            registerWrongAttempt()
            return
        }

        board = scratch
        lastMove = move
        hintMoves = []
        attemptsRemaining = 3
        Haptics.move()
        currentStep += 1

        if currentStep >= moves.count {
            isLineComplete = true
            Haptics.gameEnded()
        } else {
            playOpponentReply()
        }
    }

    private func registerWrongAttempt() {
        attemptsRemaining -= 1
        if attemptsRemaining <= 0 {
            revealCurrentMove()
        }
    }

    /// Flèche PUIS joue le coup manqué après un court délai (le temps de
    /// voir la flèche), et enchaîne — ne met jamais fin à la session,
    /// contrairement à un puzzle : c'est toute la ligne qu'on apprend.
    private func revealCurrentMove() {
        let lan = moves[currentStep].lan
        guard lan.count >= 4 else { return }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        hintMoves = [HintMove(rank: 1, from: start, to: end, strength: 1)]

        isAutoPlaying = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            self?.applyRevealedMove()
        }
    }

    private func applyRevealedMove() {
        defer { isAutoPlaying = false }
        applyMove(at: currentStep)
        hintMoves = []
        attemptsRemaining = 3
        Haptics.move()
        currentStep += 1

        if currentStep >= moves.count {
            isLineComplete = true
            Haptics.gameEnded()
        } else {
            playOpponentReply()
        }
    }

    /// Joue automatiquement tous les coups de l'adversaire en tête de
    /// ligne (utile quand `color == .black` : le premier coup, blanc,
    /// doit être joué avant même que l'utilisateur n'interagisse).
    private func advanceOpponentMoves() {
        while currentStep < moves.count, plyColor(at: currentStep) != color {
            applyMove(at: currentStep)
            currentStep += 1
        }
        if currentStep >= moves.count {
            isLineComplete = true
        }
    }

    /// Riposte adverse après un court délai naturel (même rythme que
    /// ``PuzzleSolveViewModel/playForcedReply``).
    private func playOpponentReply() {
        guard currentStep < moves.count, plyColor(at: currentStep) != color else { return }
        isAutoPlaying = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64.random(in: 400_000_000...700_000_000))
            self?.finishOpponentReply()
        }
    }

    private func finishOpponentReply() {
        defer { isAutoPlaying = false }
        applyMove(at: currentStep)
        Haptics.move()
        currentStep += 1

        if currentStep >= moves.count {
            isLineComplete = true
            Haptics.gameEnded()
        }
    }

    @discardableResult
    private func applyMove(at ply: Int) -> Move? {
        let lan = moves[ply].lan
        guard lan.count >= 4 else { return nil }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))

        var scratch = board
        guard let applied = scratch.move(pieceAt: start, to: end) else { return nil }
        var finalMove = applied

        if case .promotion = scratch.state {
            let kind: Piece.Kind = lan.count == 5
                ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                : .queen
            finalMove = scratch.completePromotion(of: applied, to: kind)
        }

        board = scratch
        lastMove = finalMove
        return finalMove
    }
}
