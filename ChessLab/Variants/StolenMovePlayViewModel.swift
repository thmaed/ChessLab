import ChessKit
import Foundation
import Observation
import UIKit

/// Partie contre l'ordinateur en Coup Volé — voir ``StolenMoveVariant`` pour
/// les règles. Calqué sur ``FairyVariantPlayViewModel`` (ChessKit reste
/// l'arbitre de légalité pour CHAQUE coup, un `Move` ChessKit ordinaire
/// suffit partout) — la vraie différence est le TOUR : cette vue-modèle
/// gère elle-même qui doit jouer, en plus de ce que joue ChessKit.
///
/// ## Le problème du second coup
///
/// ChessKit fait alterner `board.position.sideToMove` après CHAQUE coup —
/// il n'a aucune idée qu'un même camp puisse rejouer. Le premier coup d'un
/// tour double se joue normalement (c'est déjà son tour). Pour le second,
/// cette vue-modèle interroge la légalité sur un plateau TEMPORAIRE, trait
/// remis au bon camp (``flippedBoardForSecondMove``) — sans toucher
/// `board` tant que le second coup n'est pas VRAIMENT joué. Une fois joué
/// SUR ce plateau temporaire, ChessKit fait retomber `sideToMove` sur le
/// VRAI adversaire tout seul — aucune remise à l'endroit nécessaire après
/// coup.
///
/// ## La prise en passant qui survit à un coup intercalé
///
/// Une prise en passant rendue possible par le DERNIER coup adverse doit
/// rester valable même si le premier coup d'un tour double s'intercale
/// (règle 5) — ChessKit l'aurait normalement effacée après CE premier coup,
/// comme n'importe quel coup qui n'est pas la prise elle-même.
/// ``enPassantTargetAtTurnStart`` mémorise la case AVANT le premier coup du
/// tour, ré-injectée dans le plateau temporaire du second coup si ChessKit
/// l'a effacée entre-temps.
@Observable
@MainActor
final class StolenMovePlayViewModel {

    // MARK: État de partie

    let variant = StolenMoveVariant.shared
    let settings: FairyVariantSettings
    let userColor: Piece.Color
    let engineColor: Piece.Color
    let tokenInterval: Int

    private(set) var board: Board
    private(set) var uciLog: [String] = []
    private(set) var sanLog: [String] = []
    private(set) var moveLog: [Move] = []
    private(set) var fenLog: [String]
    /// Parallèle à `uciLog` : `true` si CE coup a été joué en dépensant un
    /// jeton (premier coup d'un tour double). Nécessaire pour rejouer
    /// l'économie de jetons de façon déterministe — « dépenser » est un
    /// CHOIX, pas quelque chose qu'on peut redéduire du plateau seul.
    private(set) var tokenSpendLog: [Bool] = []
    private(set) var outcome: GameOutcome?

    private(set) var movesPlayedByColor: [Piece.Color: Int] = [.white: 0, .black: 0]
    private(set) var tokens: [Piece.Color: Int] = [.white: 0, .black: 0]
    /// Non-`nil` : ce camp DOIT encore jouer un second coup avant que le
    /// tour ne passe réellement.
    private(set) var awaitingSecondMoveBy: Piece.Color?
    /// Choix de l'utilisateur, avant de jouer : dépenser son jeton sur le
    /// PROCHAIN coup. Remis à `false` après usage (accepté ou refusé).
    var wantsToSpendToken = false
    private var enPassantTargetAtTurnStart: Square?

    let clock: GameClock?
    private let startFEN: String

    /// Le camp qui doit RÉELLEMENT jouer maintenant — `board.position.
    /// sideToMove` seul ment pendant un second coup de tour double.
    var effectiveMover: Piece.Color { awaitingSecondMoveBy ?? board.position.sideToMove }

    // MARK: Interaction

    private(set) var selectedSquare: Square?
    private(set) var legalTargetSquares: [Square] = []
    struct PendingPromotion: Equatable { let from: Square; let to: Square }
    private(set) var pendingPromotion: PendingPromotion?

    // MARK: Moteur — Stockfish STANDARD : aucune option UCI de variante
    // n'existe pour un mécanisme de tour double, propre à l'app.

    private let engine = EngineController()
    private var engineQueue: Task<Void, Never> = Task {}
    private(set) var isEngineThinking = false
    private(set) var isEngineUnavailable = false
    private(set) var currentEvalCp: Int?
    private(set) var currentEvalMate: Int?

    var hintMoves: [HintMove] = []
    private(set) var hintsWanted = false
    private(set) var isHintAnalyzing = false

    var pendingBlunderWarning: PendingBlunderWarning?

    private(set) var reviewPly: Int?
    private var reviewBoard: Board?

    // MARK: Cycle de vie

    init(settings: FairyVariantSettings) {
        self.settings = settings
        let color = settings.resolvedColorChoice.resolved()
        userColor = color
        engineColor = color.opposite
        tokenInterval = min(max(settings.stolenMoveTokenInterval, StolenMoveVariant.tokenIntervalRange.lowerBound), StolenMoveVariant.tokenIntervalRange.upperBound)
        startFEN = StolenMoveVariant.shared.startFEN
        board = Board(position: Position(fen: startFEN)!)
        fenLog = [startFEN]
        clock = settings.timeControl.hasClock ? GameClock(control: settings.timeControl) : nil

        clock?.onFlagFall = { [weak self] color in
            self?.handleFlagFall(color)
        }
    }

    func start() {
        enqueueEngineWork { [weak self] in await self?.setupEngine() }
        clock?.startTurn(for: .white)
        if effectiveMover == engineColor {
            enqueueEngineWork { [weak self] in await self?.requestEngineTurn() }
        } else {
            if settings.showEvalBar {
                enqueueEngineWork { [weak self] in await self?.updateEvalBar() }
            }
            restartHintAnalysisIfWanted()
        }
    }

    func handleViewDisappear() {
        clock?.pause()
        engineQueue.cancel()
        Task { [engine] in await engine.stop() }
    }

    // MARK: Affichage

    var displayedBoard: Board { reviewBoard ?? board }
    var totalPlies: Int { uciLog.count }
    var displayedPly: Int { reviewPly ?? uciLog.count }
    var isReviewing: Bool { reviewPly != nil }

    var numberedMoves: [(number: Int, white: String, black: String?)] {
        stride(from: 0, to: sanLog.count, by: 2).map { index in
            (index / 2 + 1, sanLog[index], index + 1 < sanLog.count ? sanLog[index + 1] : nil)
        }
    }

    var displayedLastMove: Move? {
        let index = displayedPly
        guard index > 0, index <= moveLog.count else { return nil }
        return moveLog[index - 1]
    }

    /// La partie annonce un jeton disponible pour le camp au trait — motif
    /// visuel côté vue, indépendant du bouton qui le dépense.
    var canOfferTokenNow: Bool {
        canUserAct && awaitingSecondMoveBy == nil && (tokens[userColor] ?? 0) > 0 && !isUserInCheck
    }

    private var isUserInCheck: Bool {
        if case .check = board.state, board.position.sideToMove == userColor { return true }
        return false
    }

    // MARK: Interaction utilisateur

    private var canUserAct: Bool {
        outcome == nil && pendingPromotion == nil && !isReviewing && effectiveMover == userColor
    }

    /// Plateau à utiliser pour la légalité/l'affichage du coup COURANT —
    /// celui de la partie tel quel pour un premier coup (ou un coup
    /// normal), un plateau TEMPORAIRE (trait remis au bon camp, prise en
    /// passant restaurée si besoin) pour un second coup de tour double.
    /// Jamais stocké : reconstruit à chaque interrogation, jeté aussitôt.
    private var interactionBoard: Board {
        guard let awaitingSecondMoveBy else { return board }
        return flippedBoard(to: awaitingSecondMoveBy, enPassantOverride: enPassantTargetAtTurnStart)
    }

    /// Même FEN, trait remis à `color`, prise en passant remplacée par
    /// `enPassantOverride` si ChessKit l'a déjà effacée (`-`) — sinon celle
    /// que ChessKit a calculée elle-même prévaut (un second coup peut, en
    /// théorie, créer SA PROPRE poussée de deux cases, sans rapport avec
    /// la règle 5).
    private func flippedBoard(to color: Piece.Color, enPassantOverride: Square?) -> Board {
        var fields = board.position.fen.split(separator: " ").map(String.init)
        guard fields.count == 6 else { return board }
        fields[1] = color == .white ? "w" : "b"
        if fields[3] == "-", let enPassantOverride {
            fields[3] = enPassantOverride.notation
        }
        guard let flipped = Position(fen: fields.joined(separator: " ")) else { return board }
        return Board(position: flipped)
    }

    func selectSquare(_ square: Square) {
        guard canUserAct else { return }
        let interaction = interactionBoard
        if let selected = selectedSquare, legalTargetSquares.contains(square) {
            attemptUserMove(from: selected, to: square)
            return
        }
        guard let piece = interaction.position.piece(at: square), piece.color == userColor else {
            clearSelection()
            return
        }
        selectedSquare = square
        legalTargetSquares = interaction.legalMoves(forPieceAt: square)
    }

    func attemptUserMove(from start: Square, to end: Square) {
        guard canUserAct, start != end else {
            Haptics.illegal()
            clearSelection()
            return
        }
        let interaction = interactionBoard
        guard interaction.position.piece(at: start)?.color == userColor else {
            Haptics.illegal()
            clearSelection()
            return
        }

        if let piece = interaction.position.piece(at: start), piece.kind == .pawn,
           end.notation.hasSuffix(userColor == .white ? "8" : "1"),
           interaction.canMove(pieceAt: start, to: end)
        {
            pendingPromotion = PendingPromotion(from: start, to: end)
            clearSelection()
            return
        }

        let uci = start.notation + end.notation
        guard commit(uci: uci) else {
            Haptics.illegal()
            clearSelection()
            return
        }
        clearSelection()
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        // La partie a pu se terminer pendant que la fenêtre de promotion
        // était ouverte : `commit` n'a pas son propre garde-fou.
        guard outcome == nil else { return }
        _ = commit(uci: pending.from.notation + pending.to.notation + kind.rawValue.lowercased())
    }

    func cancelPromotion() { pendingPromotion = nil }

    private func clearSelection() {
        selectedSquare = nil
        legalTargetSquares = []
    }

    /// Accès de TEST : joue un coup pour le camp au trait EFFECTIF, sans
    /// passer par les gardes d'interaction — le moteur n'est jamais démarré.
    func forceMove(uci: String) {
        _ = commit(uci: uci)
    }

    // MARK: Le commit — commun utilisateur/moteur

    @discardableResult
    private func commit(uci: String) -> Bool {
        let mover = effectiveMover
        let isSecondMoveOfTurn = awaitingSecondMoveBy != nil
        var working = isSecondMoveOfTurn ? interactionBoard : board
        let beforeFEN = board.position.fen

        // Le jeton se dépense au PREMIER coup — vérifié AVANT d'y toucher :
        // règle 3, impossible en échec.
        let spendsToken = !isSecondMoveOfTurn && wantsToSpendToken
            && (tokens[mover] ?? 0) > 0 && !isInCheck(working, color: mover)
        wantsToSpendToken = false

        guard let move = working.move(pieceAt: Square(String(uci.prefix(2))), to: Square(String(uci.dropFirst(2).prefix(2)))) else {
            return false
        }
        var appliedMove = move
        if case .promotion = working.state, uci.count == 5,
           let kind = Piece.Kind(rawValue: String(uci.suffix(1)).uppercased())
        {
            appliedMove = working.completePromotion(of: move, to: kind)
        }

        // N'IMPORTE QUEL coup — y compris une réponse moteur — invalide
        // l'offre d'annulation d'une reprise : la restreindre au seul coup
        // utilisateur laissait l'offre active pendant qu'un coup moteur se
        // jouait dans la foulée, et `cancelResumeFromReview()` réinjectait
        // alors l'ancienne suite écartée SANS tenir compte de ce coup
        // entretemps commité, désynchronisant les journaux (même bug
        // trouvé dans les autres vue-modèles de variantes lors de la revue
        // du 25/08/2026).
        clearResumeUndo()
        uciLog.append(uci)
        sanLog.append(appliedMove.san)
        moveLog.append(appliedMove)
        tokenSpendLog.append(spendsToken)
        fenLog.append(working.position.fen)
        playSound(for: appliedMove.san)
        hintMoves = []

        movesPlayedByColor[mover, default: 0] += 1
        if (movesPlayedByColor[mover] ?? 0) % tokenInterval == 0 {
            // Règle 2 : un nouveau jeton efface l'ancien s'il traîne encore.
            tokens[mover] = 1
        }

        let gaveCheck: Bool
        if case .check = working.state { gaveCheck = true } else { gaveCheck = false }

        if isSecondMoveOfTurn {
            // Le second coup termine TOUJOURS le tour double, qu'il mette
            // échec ou non (règle 4 ne parle que du PREMIER coup).
            board = working
            awaitingSecondMoveBy = nil
            enPassantTargetAtTurnStart = nil
        } else if spendsToken {
            tokens[mover] = 0
            if gaveCheck {
                // Règle 4 : le premier coup a mis échec, le tour s'arrête là.
                board = working
                awaitingSecondMoveBy = nil
            } else {
                // Mémorisé AVANT ce premier coup — voir le commentaire de
                // tête sur la règle 5.
                enPassantTargetAtTurnStart = Self.enPassantTarget(in: beforeFEN)
                board = working
                awaitingSecondMoveBy = mover
            }
        } else {
            board = working
        }

        if let end = GameOutcome.fromBoardState(board.state) {
            outcome = end
            clock?.pause()
            Haptics.gameEnded()
            return true
        }

        if awaitingSecondMoveBy == nil {
            clock?.startTurn(for: board.position.sideToMove, previousMover: mover)
        }

        if mover == userColor, !isSecondMoveOfTurn || uciLog.count >= 1 {
            checkForBlunderRetroactively(beforeFEN: beforeFEN, afterFEN: working.position.fen, atMoveCount: uciLog.count)
        }

        if effectiveMover == engineColor {
            enqueueEngineWork { [weak self] in await self?.requestEngineTurn() }
        } else if effectiveMover == userColor, awaitingSecondMoveBy == nil || isSecondMoveOfTurn {
            if settings.showEvalBar {
                enqueueEngineWork { [weak self] in await self?.updateEvalBar() }
            }
            restartHintAnalysisIfWanted()
        }
        return true
    }

    private func isInCheck(_ board: Board, color: Piece.Color) -> Bool {
        guard case .check = board.state else { return false }
        return board.position.sideToMove == color
    }

    /// Case de prise en passant lue directement dans un FEN — pas besoin
    /// de passer par ChessKit pour un simple champ texte.
    private static func enPassantTarget(in fen: String) -> Square? {
        let fields = fen.split(separator: " ")
        guard fields.count >= 4, fields[3] != "-" else { return nil }
        return Square(String(fields[3]))
    }

    private func playSound(for san: String) {
        if san.contains("#") || san.contains("+") {
            SoundPlayer.shared.play(.check)
        } else if san.hasPrefix("O-O") {
            SoundPlayer.shared.play(.castle)
        } else if san.contains("x") {
            SoundPlayer.shared.play(.capture)
        } else {
            SoundPlayer.shared.play(.move)
        }
    }

    private func handleFlagFall(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .timeout)
        clock?.pause()
        Haptics.gameEnded()
    }

    func userResigns() {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: engineColor, reason: .resignation)
        clock?.pause()
        Haptics.gameEnded()
    }

    // MARK: Moteur

    private func enqueueEngineWork(_ work: @escaping () async -> Void) {
        let previous = engineQueue
        engineQueue = Task {
            _ = await previous.value
            await work()
        }
    }

    private func setupEngine() async {
        guard outcome == nil else { return }
        guard await engine.start() else {
            isEngineUnavailable = true
            return
        }
        for command in settings.strength.setupCommands {
            await engine.send(command)
        }
    }

    /// L'ordinateur joue UN tour complet — un coup, et (s'il détient un
    /// jeton hors échec) un second automatiquement, sauf si le premier a
    /// mis échec. Heuristique volontairement simple : l'ordinateur dépense
    /// TOUJOURS un jeton disponible plutôt que de le garder en réserve —
    /// un jeton non dépensé est perdu au prochain de toute façon (règle 2).
    private func requestEngineTurn() async {
        guard outcome == nil, effectiveMover == engineColor else { return }
        let hasToken = (tokens[engineColor] ?? 0) > 0 && awaitingSecondMoveBy == nil
            && !isInCheck(board, color: engineColor)
        if hasToken { wantsToSpendToken = true }
        await requestEngineMove()

        guard outcome == nil, effectiveMover == engineColor else { return }
        // Le premier coup a été joué SANS mettre échec : le second suit,
        // sans que l'utilisateur n'ait rien à faire entre les deux.
        await requestEngineMove()
    }

    private func requestEngineMove() async {
        guard outcome == nil, effectiveMover == engineColor else { return }
        isEngineThinking = true
        defer { isEngineThinking = false }

        await engine.synchronize()
        await engine.send(.position(.fen(interactionBoard.position.fen)))

        let mover = engineColor
        let budgetMs: Int
        if let depth = settings.strength.maxDepth {
            await engine.send(.go(depth: depth))
            budgetMs = 15_000
        } else {
            let movetime = computeMovetime(for: mover)
            await engine.send(.go(movetime: movetime))
            budgetMs = movetime + EngineWatchdog.graceMs
        }

        let search = await EngineWatchdog.run(deadlineMs: budgetMs) { [engine] in
            var bestLAN: String?
            var cp: Int?
            var mate: Int?
            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    if (info.multipv ?? 1) == 1, let value = EngineScore.moverCentipawns(info) {
                        cp = value
                        mate = EngineScore.mateInMoves(info)
                    }
                case let .bestmove(move, _):
                    bestLAN = move
                default: break
                }
                if bestLAN != nil { break }
            }
            return (lan: bestLAN, cp: cp, mate: mate)
        }

        guard case let .finished(result) = search else {
            isEngineUnavailable = true
            return
        }
        if let cp = result.cp {
            setEval(cp: cp, mate: result.mate, moverIsWhite: mover == .white)
        }
        guard let lan = result.lan, lan != "(none)", outcome == nil, !isReviewing else {
            return
        }
        _ = commit(uci: lan)
    }

    private func updateEvalBar() async {
        guard outcome == nil else { return }
        await refreshEvalBar(fen: board.position.fen, mover: board.position.sideToMove)
    }

    private func refreshDisplayedEvalBar() {
        guard settings.showEvalBar else { return }
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            await self.refreshEvalBar(fen: self.displayedBoard.position.fen, mover: self.displayedBoard.position.sideToMove)
        }
    }

    private func refreshEvalBar(fen: String, mover: Piece.Color) async {
        await engine.synchronize()
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: 220))

        let search = await EngineWatchdog.run(deadlineMs: 220 + EngineWatchdog.graceMs) { [engine] in
            var cp: Int?
            var mate: Int?
            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    guard (info.multipv ?? 1) == 1 else { break }
                    if let m = info.score?.mate {
                        mate = m; cp = nil
                    } else if let c = info.score?.cp {
                        cp = Int(c); mate = nil
                    }
                case .bestmove:
                    return (cp: cp, mate: mate)
                default:
                    break
                }
            }
            return (cp: cp, mate: mate)
        }

        guard case let .finished(result) = search, fen == displayedBoard.position.fen,
              let cp = result.cp
        else { return }
        setEval(cp: cp, mate: result.mate, moverIsWhite: mover == .white)
    }

    private func setEval(cp: Int, mate: Int?, moverIsWhite: Bool) {
        guard settings.showEvalBar else { return }
        currentEvalCp = moverIsWhite ? cp : -cp
        currentEvalMate = mate.map { moverIsWhite ? $0 : -$0 }
    }

    private func computeMovetime(for mover: Piece.Color) -> Int {
        guard let clock, clock.control.hasClock else { return 900 }
        let remaining = clock.remaining(for: mover)
        let increment = Double(clock.control.incrementSeconds)
        let base = remaining / 30 + increment * 0.8
        return Int(min(max(base, 0.15), min(30, remaining / 4)) * 1000)
    }

    // MARK: Indice

    private static let hintBudgetMs = 1500

    func toggleHint() {
        hintsWanted.toggle()
        if hintsWanted {
            enqueueEngineWork { [weak self] in await self?.startHintAnalysis() }
        } else {
            hintMoves = []
        }
    }

    private func restartHintAnalysisIfWanted() {
        guard hintsWanted else { return }
        enqueueEngineWork { [weak self] in await self?.startHintAnalysis() }
    }

    private func startHintAnalysis() async {
        guard settings.hintsEnabled, hintsWanted, outcome == nil, effectiveMover == userColor
        else { return }

        isHintAnalyzing = true
        defer { isHintAnalyzing = false }

        let fen = interactionBoard.position.fen
        await engine.synchronize()
        await engine.send(.setoption(id: "MultiPV", value: "3"))
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: Self.hintBudgetMs))

        let search = await EngineWatchdog.run(deadlineMs: Self.hintBudgetMs + EngineWatchdog.graceMs) { [engine] in
            var lanByRank: [Int: String] = [:]
            var scoreByRank: [Int: Double] = [:]
            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    if let rank = info.multipv, let firstMove = info.pv?.first {
                        lanByRank[rank] = firstMove
                        if let mate = info.score?.mate {
                            scoreByRank[rank] = mate > 0 ? 10_000 - Double(mate) : -10_000 - Double(mate)
                        } else if let cp = info.score?.cp {
                            scoreByRank[rank] = cp
                        }
                    }
                case .bestmove:
                    return (lanByRank, scoreByRank)
                default:
                    break
                }
            }
            return (lanByRank, scoreByRank)
        }
        await engine.send(.setoption(id: "MultiPV", value: "1"))

        guard case let .finished((lanByRank, scoreByRank)) = search,
              hintsWanted, outcome == nil, fen == interactionBoard.position.fen
        else { return }

        hintMoves = HintMoveBuilder.build(lanByRank: lanByRank, scoreByRank: scoreByRank)
    }

    // MARK: Alerte gaffe (rétroactive)

    private func checkForBlunderRetroactively(beforeFEN: String, afterFEN: String, atMoveCount: Int) {
        guard settings.blunderAlertEnabled else { return }

        enqueueEngineWork { [weak self] in
            guard let self else { return }
            guard let before = await self.quickScore(fen: beforeFEN),
                  let after = await self.quickScore(fen: afterFEN)
            else { return }

            guard let severity = PlayViewModel.blunderSeverity(before: before, after: after) else { return }
            guard atMoveCount == self.uciLog.count, self.outcome == nil, self.canTakeback else { return }
            self.pendingBlunderWarning = PendingBlunderWarning(severity: severity)
        }
    }

    func dismissBlunderWarning() {
        pendingBlunderWarning = nil
    }

    func takebackAfterBlunderWarning() {
        pendingBlunderWarning = nil
        enqueueEngineWork { [weak self] in self?.takeback() }
    }

    private func quickScore(fen: String) async -> (cp: Int, mate: Int?)? {
        await engine.synchronize()
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: 300))

        let outcome = await EngineWatchdog.run(deadlineMs: 300 + EngineWatchdog.graceMs) {
            [engine] () -> (cp: Int, mate: Int?)? in
            var cp: Int?
            var mate: Int?
            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    guard (info.multipv ?? 1) == 1 else { break }
                    if let value = EngineScore.moverCentipawns(info) {
                        cp = value
                        mate = EngineScore.mateInMoves(info)
                    }
                case .bestmove:
                    if let cp { return (cp, mate) }
                    return nil
                default:
                    break
                }
            }
            if let cp { return (cp, mate) }
            return nil
        }

        guard case let .finished(score) = outcome else { return nil }
        return score
    }

    // MARK: Consultation & reprise

    func review(toPly ply: Int) {
        let clamped = max(0, min(ply, uciLog.count))
        guard clamped != uciLog.count else {
            reviewToLive()
            return
        }
        reviewPly = clamped
        reviewBoard = Board(position: Position(fen: fenLog[clamped])!)
        clearSelection()
        refreshDisplayedEvalBar()
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }

    func reviewToLive() {
        reviewPly = nil
        reviewBoard = nil
        clearSelection()
        refreshDisplayedEvalBar()
    }

    var canTakeback: Bool {
        !settings.timeControl.hasClock && !uciLog.isEmpty && outcome == nil && !isEngineThinking
    }

    /// Retire le DERNIER coup joué — un seul, même à l'intérieur d'un tour
    /// double : reprendre le second coup d'un tour double doit laisser le
    /// premier en place (l'utilisateur reprend SON second coup, pas les
    /// deux). Après une reprise en pleine réponse machine (un ou deux coups
    /// d'affilée), retirer aussi le(s) coup(s) machine déjà joué(s) — même
    /// principe que ``FairyVariantPlayViewModel/takeback()``, étendu au
    /// tour double.
    func takeback() {
        guard canTakeback else { return }
        var count = 1
        // Combien de coups l'ordinateur vient-il de jouer d'affilée (1 ou
        // 2) ? Lu dans `tokenSpendLog` : si l'avant-dernier coup a dépensé
        // un jeton ET n'a pas mis échec (donc suivi d'un second), les DEUX
        // sont à retirer pour revenir avant le tour de la machine.
        if uciLog.count >= 2 {
            let lastMoverWasEngine = moveLog.last?.piece.color == engineColor
            if lastMoverWasEngine {
                let secondToLastSpent = tokenSpendLog[uciLog.count - 2]
                if secondToLastSpent { count = 2 }
            }
        }
        truncate(to: uciLog.count - count)
    }

    var canResumeFromReview: Bool {
        guard let reviewPly else { return false }
        return !settings.timeControl.hasClock && outcome == nil && !isEngineThinking && reviewPly < uciLog.count
    }

    struct ResumeUndo { let uci: [String]; let san: [String]; var discardedCount: Int { uci.count } }
    private(set) var resumeUndo: ResumeUndo?
    private var resumeUndoTask: Task<Void, Never>?
    private static let resumeUndoDelay: Duration = .seconds(8)

    func resumeFromReview() {
        guard let reviewPly, canResumeFromReview else { return }
        let discardedUci = Array(uciLog.suffix(from: reviewPly))
        let discardedSan = Array(sanLog.suffix(from: reviewPly))
        reviewToLive()
        truncate(to: reviewPly)
        guard !discardedUci.isEmpty else { return }
        offerResumeUndo(ResumeUndo(uci: discardedUci, san: discardedSan))
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: LocalizationController.string(
                    "Partie reprise, %lld coups écartés. Annulation possible.", discardedUci.count
                )
            )
        }
    }

    func cancelResumeFromReview() {
        guard let undo = resumeUndo, outcome == nil, !isEngineThinking else { return }
        clearResumeUndo()
        uciLog.append(contentsOf: undo.uci)
        sanLog.append(contentsOf: undo.san)
        rebuildFromLogs()
    }

    private func offerResumeUndo(_ undo: ResumeUndo) {
        resumeUndoTask?.cancel()
        resumeUndo = undo
        resumeUndoTask = Task { [weak self] in
            try? await Task.sleep(for: Self.resumeUndoDelay)
            guard !Task.isCancelled else { return }
            self?.resumeUndo = nil
        }
    }

    private func clearResumeUndo() {
        resumeUndoTask?.cancel()
        resumeUndoTask = nil
        resumeUndo = nil
    }

    private func truncate(to count: Int) {
        clearResumeUndo()
        uciLog = Array(uciLog.prefix(count))
        sanLog = Array(sanLog.prefix(count))
        rebuildFromLogs()
    }

    /// Rejoue TOUT depuis ``uciLog`` — plateau, jetons, tour double en
    /// cours — le chemin commun de la reprise de coup et de l'annulation de
    /// reprise. L'économie de jetons n'est pas dans le plateau : elle doit
    /// être reconstruite à côté, à partir de ``tokenSpendLog`` (tronqué à
    /// la même longueur que `uciLog`, voir ``truncate(to:)``).
    private func rebuildFromLogs() {
        tokenSpendLog = Array(tokenSpendLog.prefix(uciLog.count))

        var rebuiltBoard = Board(position: Position(fen: startFEN)!)
        var rebuiltFenLog = [startFEN]
        var rebuiltMoves: [Move] = []
        var counts: [Piece.Color: Int] = [.white: 0, .black: 0]
        var tokenState: [Piece.Color: Int] = [.white: 0, .black: 0]
        var awaitingBy: Piece.Color?
        var epAtTurnStart: Square?

        for (index, uci) in uciLog.enumerated() {
            let isSecondMove = awaitingBy != nil
            let mover = awaitingBy ?? rebuiltBoard.position.sideToMove
            var working = isSecondMove
                ? flippedBoard(from: rebuiltBoard, to: mover, enPassantOverride: epAtTurnStart)
                : rebuiltBoard
            let beforeFEN = rebuiltBoard.position.fen
            let spendsToken = tokenSpendLog[index]

            guard let move = working.move(pieceAt: Square(String(uci.prefix(2))), to: Square(String(uci.dropFirst(2).prefix(2)))) else { break }
            var appliedMove = move
            if case .promotion = working.state, uci.count == 5,
               let kind = Piece.Kind(rawValue: String(uci.suffix(1)).uppercased())
            {
                appliedMove = working.completePromotion(of: move, to: kind)
            }
            rebuiltMoves.append(appliedMove)
            rebuiltFenLog.append(working.position.fen)

            counts[mover, default: 0] += 1
            if (counts[mover] ?? 0) % tokenInterval == 0 { tokenState[mover] = 1 }

            let gaveCheck: Bool
            if case .check = working.state { gaveCheck = true } else { gaveCheck = false }

            if isSecondMove {
                rebuiltBoard = working
                awaitingBy = nil
                epAtTurnStart = nil
            } else if spendsToken {
                tokenState[mover] = 0
                if gaveCheck {
                    rebuiltBoard = working
                    awaitingBy = nil
                } else {
                    epAtTurnStart = Self.enPassantTarget(in: beforeFEN)
                    rebuiltBoard = working
                    awaitingBy = mover
                }
            } else {
                rebuiltBoard = working
            }
        }

        board = rebuiltBoard
        fenLog = rebuiltFenLog
        moveLog = rebuiltMoves
        movesPlayedByColor = counts
        tokens = tokenState
        awaitingSecondMoveBy = awaitingBy
        enPassantTargetAtTurnStart = epAtTurnStart
        outcome = nil
        pendingBlunderWarning = nil
        clearSelection()
        currentEvalCp = nil
        currentEvalMate = nil
        hintMoves = []

        if effectiveMover == engineColor {
            enqueueEngineWork { [weak self] in await self?.requestEngineTurn() }
        } else {
            if settings.showEvalBar {
                enqueueEngineWork { [weak self] in await self?.updateEvalBar() }
            }
            restartHintAnalysisIfWanted()
        }
    }

    /// Même principe que ``flippedBoard(to:enPassantOverride:)``, mais sur
    /// un plateau EXPLICITE — nécessaire au rejeu (``rebuildFromLogs()``),
    /// où le plateau de travail n'est pas encore celui stocké dans `board`.
    private func flippedBoard(from source: Board, to color: Piece.Color, enPassantOverride: Square?) -> Board {
        var fields = source.position.fen.split(separator: " ").map(String.init)
        guard fields.count == 6 else { return source }
        fields[1] = color == .white ? "w" : "b"
        if fields[3] == "-", let enPassantOverride {
            fields[3] = enPassantOverride.notation
        }
        guard let flipped = Position(fen: fields.joined(separator: " ")) else { return source }
        return Board(position: flipped)
    }

    // MARK: Export

    var displayedFEN: String { displayedBoard.position.fen }

    var exportedPGN: String {
        var tags = [
            "[Event \"ChessLab \(variant.displayName)\"]",
            "[Variant \"\(variant.id)\"]",
        ]
        if let outcome {
            tags.append("[Result \"\(outcome.pgnResult)\"]")
        }
        // Deux coups d'affilée pour le MÊME camp cassent la numérotation
        // standard « blanc puis noir » — annotés `[jeton]` plutôt que
        // silencieusement mal numérotés : ce PGN ne prétend de toute façon
        // pas être rejouable par un lecteur externe, qui ignore tout du
        // Coup Volé.
        var moves = ""
        for (index, san) in sanLog.enumerated() {
            if index % 2 == 0 { moves += "\(index / 2 + 1). " }
            moves += san
            if tokenSpendLog.count > index, tokenSpendLog[index] {
                moves += " [jeton]"
            }
            moves += " "
        }
        if let outcome { moves += outcome.pgnResult }
        return tags.joined(separator: "\n") + "\n\n" + moves.trimmingCharacters(in: .whitespaces) + "\n"
    }
}
