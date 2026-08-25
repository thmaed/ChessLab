import ChessKit
import Foundation
import Observation
import UIKit

/// Partie contre l'ordinateur dans une variante où Fairy-Stockfish est
/// l'ARBITRE de légalité — Course des rois, Antéchecs, Atomique. Un seul
/// view model pour les trois, comme ``FairyVariantPlayViewModel`` pour le
/// lot A, mais l'architecture diffère sur un point central : ChessKit n'y
/// joue AUCUN coup — il ne fait plus que reconstruire un `Board`
/// d'AFFICHAGE à partir du FEN que le moteur renvoie après chaque coup
/// (``EngineLegalityVariant`` explique pourquoi : une capture Atomique vide
/// des cases qu'aucune règle ChessKit ne pourrait deviner).
///
/// Conséquence directe : appliquer un coup — même celui de l'utilisateur —
/// est désormais UN ALLER-RETOUR MOTEUR (``performMove(uci:)``), jamais une
/// opération locale instantanée. Les coups légaux de la position COURANTE
/// sont mis en cache (``legalMovesForCurrentPosition``) juste après chaque
/// coup pour que la sélection d'une case reste, elle, instantanée.
///
/// La consultation d'un coup passé, en revanche, ne coûte RIEN au moteur :
/// chaque FEN traversé est conservé (``fenLog``) au fil de la partie, donc
/// revoir un coup n'est qu'une lecture de tableau — seule la barre d'éval,
/// qui a toujours nécessité une salve moteur, continue d'en demander une.
@Observable
@MainActor
final class EngineLegalityPlayViewModel {

    // MARK: État de partie

    let variant: EngineLegalityVariant
    let settings: FairyVariantSettings
    let userColor: Piece.Color
    let engineColor: Piece.Color

    private(set) var board: Board
    private(set) var uciLog: [String] = []
    private(set) var sanLog: [String] = []
    private(set) var moveLog: [Move] = []
    private(set) var outcome: GameOutcome?
    /// FEN après CHAQUE coup, `fenLog[0]` = position de départ — le journal
    /// qui rend la consultation gratuite (voir le commentaire de tête).
    private(set) var fenLog: [String]
    private var currentFEN: String
    /// Coups légaux de la position COURANTE (UCI/LAN) — rafraîchis après
    /// chaque coup, jamais pendant la consultation d'un coup passé.
    private var legalMovesForCurrentPosition: [String] = []
    /// `false` tant que la toute première interrogation moteur n'a pas
    /// répondu — bloque l'interaction, pas seulement l'affichage.
    private(set) var isPositionReady = false

    let clock: GameClock?
    private let startFEN: String

    // MARK: Interaction

    private(set) var selectedSquare: Square?
    private(set) var legalTargetSquares: [Square] = []
    struct PendingPromotion: Equatable { let from: Square; let to: Square }
    private(set) var pendingPromotion: PendingPromotion?

    // MARK: Moteur

    private let engine = FairyEngineController()
    private var engineQueue: Task<Void, Never> = Task {}
    private(set) var isEngineThinking = false
    private(set) var isEngineUnavailable = false
    private(set) var currentEvalCp: Int?
    private(set) var currentEvalMate: Int?

    // MARK: Indice — analyse ponctuelle, PAS continue

    var hintMoves: [HintMove] = []
    private(set) var hintsWanted = false
    private(set) var isHintAnalyzing = false

    // MARK: Alerte gaffe

    var pendingBlunderWarning: PendingBlunderWarning?

    // MARK: Consultation

    private(set) var reviewPly: Int?
    private var reviewBoard: Board?

    // MARK: Cycle de vie

    init(variant: EngineLegalityVariant, settings: FairyVariantSettings) {
        self.variant = variant
        self.settings = settings
        let color = settings.resolvedColorChoice.resolved()
        userColor = color
        engineColor = color.opposite
        startFEN = variant.startFEN
        board = Board(position: Position(fen: variant.startFEN)!)
        fenLog = [variant.startFEN]
        currentFEN = variant.startFEN
        clock = settings.timeControl.hasClock ? GameClock(control: settings.timeControl) : nil

        clock?.onFlagFall = { [weak self] color in
            self?.handleFlagFall(color)
        }
    }

    func start() {
        enqueueEngineWork { [weak self] in await self?.setupEngine() }
        enqueueEngineWork { [weak self] in await self?.initializePosition() }
        clock?.startTurn(for: .white)
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

    // MARK: Interaction utilisateur

    private var canUserAct: Bool {
        isPositionReady && outcome == nil && pendingPromotion == nil && !isReviewing
            && board.position.sideToMove == userColor
    }

    func selectSquare(_ square: Square) {
        guard canUserAct else { return }
        if let selected = selectedSquare, legalTargetSquares.contains(square) {
            attemptUserMove(from: selected, to: square)
            return
        }
        guard let piece = board.position.piece(at: square), piece.color == userColor else {
            clearSelection()
            return
        }
        // Toujours affecter, même si `targets` est vide (Antéchecs : une
        // pièce sans capture disponible pendant qu'une capture existe
        // ailleurs) — un retour anticipé ici laisserait la sélection/les
        // cases légales de la pièce précédente en résidu, comme si la
        // nouvelle pièce héritait des coups de l'ancienne. Même discipline
        // que ``FairyVariantPlayViewModel/selectSquare(_:)``.
        let uciPrefix = square.notation
        let targets = legalMovesForCurrentPosition
            .filter { $0.hasPrefix(uciPrefix) }
            .compactMap { move -> Square? in
                guard move.count >= 4 else { return nil }
                return Square(String(move.dropFirst(2).prefix(2)))
            }
        selectedSquare = square
        legalTargetSquares = Array(Set(targets))
    }

    func attemptUserMove(from start: Square, to end: Square) {
        guard canUserAct, start != end else {
            Haptics.illegal()
            clearSelection()
            return
        }
        let prefix = start.notation + end.notation
        let matching = legalMovesForCurrentPosition.filter { $0.hasPrefix(prefix) }
        guard !matching.isEmpty else {
            Haptics.illegal()
            clearSelection()
            return
        }
        clearSelection()
        if matching.contains(where: { $0.count == 5 }) {
            pendingPromotion = PendingPromotion(from: start, to: end)
            return
        }
        enqueueEngineWork { [weak self] in await self?.performMove(uci: prefix) }
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        let uci = pending.from.notation + pending.to.notation + kind.rawValue.lowercased()
        enqueueEngineWork { [weak self] in await self?.performMove(uci: uci) }
    }

    func cancelPromotion() { pendingPromotion = nil }

    private func clearSelection() {
        selectedSquare = nil
        legalTargetSquares = []
    }

    /// Accès de TEST : joue un coup pour le camp au trait, SANS enchaîner
    /// sur la réponse moteur — juste l'état, comme
    /// ``FairyVariantPlayViewModel/forceMove(uci:)``. Poser plusieurs coups
    /// de suite (position de test) doit rester déterministe ; enchaîner ici
    /// aurait fait jouer l'ordinateur À L'INTÉRIEUR du premier `forceMove`
    /// avant même que le second n'ait la main — trouvé en écrivant les
    /// tests : la position de test partait dans une direction imprévisible,
    /// et chaque coup « forcé » déclenchait une VRAIE recherche moteur.
    func forceMove(uci: String) async {
        _ = await runOnEngineQueue { [weak self] in
            await self?.applyMoveState(uci: uci) ?? false
        }
    }

    // MARK: Le coup — commun utilisateur/moteur, TOUJOURS un aller-retour moteur

    /// Enchaîne sur la réponse moteur/l'éval/l'indice si la partie continue
    /// — le chemin normal d'un coup joué en jeu réel (utilisateur ou
    /// ordinateur). ``forceMove(uci:)`` (tests) s'arrête, lui, à
    /// ``applyMoveState(uci:)`` seul.
    private func performMove(uci: String) async {
        guard await applyMoveState(uci: uci), outcome == nil else { return }

        if board.position.sideToMove == engineColor {
            await requestEngineMove()
        } else {
            if settings.showEvalBar {
                await updateEvalBar()
            }
            restartHintAnalysisIfWanted()
        }
    }

    /// Aller-retour moteur + mise à jour de TOUT l'état dérivé d'un coup —
    /// jamais la suite (réponse moteur/éval/indice), voir
    /// ``performMove(uci:)`` vs ``forceMove(uci:)``.
    @discardableResult
    private func applyMoveState(uci: String) async -> Bool {
        guard outcome == nil else { return false }
        let beforeFEN = currentFEN
        let previousMover = board.position.sideToMove
        let candidateLog = uciLog + [uci]
        // PAS de ``runOnEngineQueue`` ici : `applyMoveState` tourne TOUJOURS
        // déjà à l'intérieur d'un travail mis en file par son appelant
        // (``performMove(uci:)`` via `enqueueEngineWork`, ou
        // ``forceMove(uci:)`` via ``runOnEngineQueue`` lui-même) — s'y
        // remettre en file ICI serait un AUTO-RÉFÉRENCEMENT qui bloque
        // indéfiniment (elle attendrait sa propre fin). La sérialisation se
        // fait UNE SEULE FOIS, au point d'entrée.
        guard let query = await engine.queryPosition(startFEN: startFEN, uciLog: candidateLog) else {
            return false
        }

        // N'IMPORTE QUEL coup — y compris une réponse moteur — invalide
        // l'offre d'annulation d'une reprise : la restreindre au seul coup
        // utilisateur laissait l'offre active pendant qu'un coup moteur se
        // jouait dans la foulée, et `cancelResumeFromReview()` réinjectait
        // alors l'ancienne suite écartée SANS tenir compte de ce coup
        // entretemps commité, désynchronisant les journaux. Trouvé lors de
        // la revue du 25/08/2026.
        clearResumeUndo()

        let isMate = query.legalMoves.isEmpty && query.inCheck
        let san = EngineLegalitySAN.build(
            uci: uci, beforeFEN: beforeFEN, legalMovesAtPosition: legalMovesForCurrentPosition,
            isCheck: query.inCheck, isMate: isMate
        )
        uciLog = candidateLog
        sanLog.append(san)
        fenLog.append(query.fen)
        if let beforePosition = Position(fen: beforeFEN) {
            let from = Square(String(uci.prefix(2)))
            let to = Square(String(uci.dropFirst(2).prefix(2)))
            if let piece = beforePosition.piece(at: from) {
                // Case d'arrivée occupée (capture directe) OU pion en
                // diagonale vers une case VIDE (prise en passant, la pièce
                // prise n'est pas SUR la case d'arrivée) — même détection
                // qu'``EngineLegalitySAN``. Sans ce marquage, `moveLog`
                // disait TOUJOURS `.move`, jamais `.capture` : l'analyse
                // (``MoveClassifier/involvesSacrifice``, qui lit
                // `move.result` pour connaître la valeur reprise) aurait vu
                // chaque capture comme un pur don de matériel.
                let capturedAtTarget = beforePosition.piece(at: to)
                let isEnPassant = piece.kind == .pawn && from.file != to.file && capturedAtTarget == nil
                let result: Move.Result
                if let capturedAtTarget {
                    result = .capture(capturedAtTarget)
                } else if isEnPassant {
                    result = .capture(Piece(.pawn, color: piece.color.opposite, square: to))
                } else {
                    result = .move
                }
                moveLog.append(Move(result: result, piece: piece, start: from, end: to))
            }
        }
        currentFEN = query.fen
        board = Board(position: Position(fen: query.fen)!)
        legalMovesForCurrentPosition = query.legalMoves
        playSound(for: san)
        hintMoves = []

        if let end = variant.outcome(afterFEN: query.fen, legalMovesForNextMover: query.legalMoves, inCheck: query.inCheck) {
            outcome = end
            clock?.pause()
            Haptics.gameEnded()
            return true
        }

        clock?.startTurn(for: board.position.sideToMove, previousMover: previousMover)

        if previousMover == userColor {
            checkForBlunderRetroactively(beforeFEN: beforeFEN, afterFEN: query.fen, atMoveCount: uciLog.count)
        }
        return true
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

    // MARK: Position initiale

    private func initializePosition() async {
        // PAS de ``runOnEngineQueue`` ici : cette méthode tourne déjà À
        // L'INTÉRIEUR d'un travail mis en file par `start()` — s'auto-mettre
        // en file bloquerait indéfiniment (elle attendrait sa propre fin).
        guard let query = await engine.queryPosition(startFEN: startFEN, uciLog: []) else {
            isEngineUnavailable = true
            return
        }
        currentFEN = query.fen
        fenLog = [query.fen]
        board = Board(position: Position(fen: query.fen)!)
        legalMovesForCurrentPosition = query.legalMoves
        isPositionReady = true

        if let end = variant.outcome(afterFEN: query.fen, legalMovesForNextMover: query.legalMoves, inCheck: query.inCheck) {
            outcome = end
            return
        }
        if board.position.sideToMove == engineColor {
            await requestEngineMove()
        } else {
            if settings.showEvalBar {
                await updateEvalBar()
            }
            restartHintAnalysisIfWanted()
        }
    }

    // MARK: Moteur

    private func enqueueEngineWork(_ work: @escaping () async -> Void) {
        let previous = engineQueue
        engineQueue = Task {
            _ = await previous.value
            await work()
        }
    }

    /// Même file que ``enqueueEngineWork(_:)``, mais qui RENVOIE une valeur —
    /// nécessaire pour ``applyMoveState(uci:)``, qui a besoin du résultat
    /// immédiatement. Sans cette sérialisation, un `queryPosition` appelé
    /// directement (hors file) pouvait s'entrelacer avec une alerte gaffe en
    /// vol (``checkForBlunderRetroactively``, elle-même mise en file) sur le
    /// MÊME acteur moteur : deux captures de lignes brutes concurrentes se
    /// corrompaient l'une l'autre (``FairyEngineController/rawLineBuffer``
    /// n'admet qu'UN appelant à la fois). Trouvé en écrivant les tests :
    /// la légalité observée après une alerte gaffe en vol ne correspondait
    /// plus à la position réelle.
    private func runOnEngineQueue<T: Sendable>(_ work: @escaping () async -> T) async -> T {
        let previous = engineQueue
        let task = Task<T, Never> {
            _ = await previous.value
            return await work()
        }
        engineQueue = Task { _ = await task.value }
        return await task.value
    }

    private func setupEngine() async {
        guard outcome == nil else { return }
        guard await engine.start(variant: variant.id) else {
            isEngineUnavailable = true
            return
        }
        for command in settings.strength.setupCommands {
            await engine.send(command)
        }
    }

    private func requestEngineMove() async {
        guard outcome == nil, board.position.sideToMove == engineColor else { return }
        isEngineThinking = true
        defer { isEngineThinking = false }

        await engine.synchronize()
        await engine.send(.position(.fen(board.position.fen)))

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
        await performMove(uci: lan)
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
        guard settings.hintsEnabled, hintsWanted, outcome == nil,
              board.position.sideToMove == userColor
        else { return }

        isHintAnalyzing = true
        defer { isHintAnalyzing = false }

        let fen = board.position.fen
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
              hintsWanted, outcome == nil, fen == board.position.fen
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
        takeback()
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
        isPositionReady && !settings.timeControl.hasClock && !uciLog.isEmpty && outcome == nil && !isEngineThinking
    }

    func takeback() {
        guard canTakeback else { return }
        let whiteJustMoved = board.position.sideToMove == .black
        let moverWasEngine = (whiteJustMoved ? Piece.Color.white : .black) == engineColor
        let count = (moverWasEngine && uciLog.count >= 2) ? 2 : 1
        truncate(to: uciLog.count - count)
    }

    var canResumeFromReview: Bool {
        guard let reviewPly else { return false }
        return isPositionReady && !settings.timeControl.hasClock && outcome == nil && !isEngineThinking && reviewPly < uciLog.count
    }

    struct ResumeUndo {
        let uci: [String]; let san: [String]; let fen: [String]; let moves: [Move]
        var discardedCount: Int { uci.count }
    }
    private(set) var resumeUndo: ResumeUndo?
    private var resumeUndoTask: Task<Void, Never>?
    private static let resumeUndoDelay: Duration = .seconds(8)

    func resumeFromReview() {
        guard let reviewPly, canResumeFromReview else { return }
        let discardedUci = Array(uciLog.suffix(from: reviewPly))
        let discardedSan = Array(sanLog.suffix(from: reviewPly))
        let discardedFen = Array(fenLog.suffix(from: reviewPly + 1))
        let discardedMoves = Array(moveLog.suffix(from: reviewPly))
        reviewToLive()
        truncate(to: reviewPly)
        guard !discardedUci.isEmpty else { return }
        offerResumeUndo(ResumeUndo(uci: discardedUci, san: discardedSan, fen: discardedFen, moves: discardedMoves))
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
        fenLog.append(contentsOf: undo.fen)
        moveLog.append(contentsOf: undo.moves)
        currentFEN = fenLog.last ?? currentFEN
        board = Board(position: Position(fen: currentFEN)!)
        outcome = nil
        clearSelection()
        isPositionReady = false
        enqueueEngineWork { [weak self] in await self?.refreshLegalMovesAndContinue() }
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
        fenLog = Array(fenLog.prefix(count + 1))
        moveLog = Array(moveLog.prefix(count))
        currentFEN = fenLog.last ?? startFEN
        board = Board(position: Position(fen: currentFEN)!)
        outcome = nil
        pendingBlunderWarning = nil
        clearSelection()
        currentEvalCp = nil
        currentEvalMate = nil
        hintMoves = []
        isPositionReady = false
        enqueueEngineWork { [weak self] in await self?.refreshLegalMovesAndContinue() }
    }

    /// Rafraîchit les coups légaux de la position COURANTE après une
    /// reprise/annulation — jamais besoin de revalider la fin de partie
    /// ici : on revient toujours à une position déjà jouée, donc non
    /// terminale par construction. Enchaîne ensuite comme
    /// ``initializePosition()``/``performMove(uci:)``.
    private func refreshLegalMovesAndContinue() async {
        guard let query = await engine.queryPosition(startFEN: startFEN, uciLog: uciLog) else { return }
        legalMovesForCurrentPosition = query.legalMoves
        isPositionReady = true

        if board.position.sideToMove == engineColor {
            await requestEngineMove()
        } else {
            if settings.showEvalBar {
                await updateEvalBar()
            }
            restartHintAnalysisIfWanted()
        }
    }

    // MARK: Export

    var displayedFEN: String { displayedBoard.position.fen }

    /// PGN — tag `Variant` propre à Fairy-Stockfish. Course des rois n'a pas
    /// la position de départ classique : le dire au format PGN standard
    /// (comme Horde/Chess960) pour qu'un lecteur externe la retrouve.
    var exportedPGN: String {
        var tags = [
            "[Event \"ChessLab \(variant.displayName)\"]",
            "[Variant \"\(variant.id)\"]",
        ]
        if variant.id == EngineLegalityVariant.racingKings.id {
            tags.append("[SetUp \"1\"]")
            tags.append("[FEN \"\(startFEN)\"]")
        }
        if let outcome {
            tags.append("[Result \"\(outcome.pgnResult)\"]")
        }
        var moves = ""
        for (index, san) in sanLog.enumerated() {
            if index % 2 == 0 { moves += "\(index / 2 + 1). " }
            moves += san + " "
        }
        if let outcome { moves += outcome.pgnResult }
        return tags.joined(separator: "\n") + "\n\n" + moves.trimmingCharacters(in: .whitespaces) + "\n"
    }
}
