import ChessKit
import Foundation
import Observation
import UIKit

/// Partie contre l'ordinateur dans une variante Fairy-Stockfish (Roi de la
/// colline, Trois échecs, Horde) — un SEUL view model pour les trois : leur
/// plateau et leurs coups restent ceux de ChessKit, seule la condition de
/// victoire diffère (voir ``FairyVariant/specialOutcome(board:mover:checkCounts:)``).
/// Structure calquée sur ``Chess960PlayViewModel`` (même discipline moteur,
/// même pattern « Reprendre ici »), mais plus simple : pas de couche de
/// règles à part, pas de dialecte de roque à corriger à l'affichage — un
/// `Move` ChessKit ordinaire suffit partout.
@Observable
@MainActor
final class FairyVariantPlayViewModel {

    // MARK: État de partie

    let variant: FairyVariant
    let settings: FairyVariantSettings
    let userColor: Piece.Color
    let engineColor: Piece.Color

    private(set) var board: Board
    private(set) var uciLog: [String] = []
    private(set) var sanLog: [String] = []
    private(set) var moveLog: [Move] = []
    /// FEN après CHAQUE coup, `fenLog[0]` = position de départ — pour rien
    /// pendant la partie (ChessKit rejoue localement, voir le commentaire de
    /// tête), mais lu directement par ``VariantAnalysisViewModel`` au lancement
    /// de l'analyse : même API que ``EngineLegalityPlayViewModel/fenLog``, où
    /// il est, lui, indispensable — pas de rejeu local possible côté moteur.
    private(set) var fenLog: [String]
    private(set) var outcome: GameOutcome?
    /// Échecs infligés par chaque camp — Trois échecs seulement, ignoré
    /// sinon (mais toujours tenu à jour : coût négligeable).
    private(set) var checkCounts: [Piece.Color: Int] = [.white: 0, .black: 0]

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

    // MARK: Indice — analyse ponctuelle, PAS continue (voir Chess960PlayViewModel)

    var hintMoves: [HintMove] = []
    private(set) var hintsWanted = false
    private(set) var isHintAnalyzing = false

    // MARK: Alerte gaffe

    var pendingBlunderWarning: PendingBlunderWarning?

    // MARK: Consultation

    private(set) var reviewPly: Int?
    private var reviewBoard: Board?

    // MARK: Cycle de vie

    init(variant: FairyVariant, settings: FairyVariantSettings) {
        self.variant = variant
        self.settings = settings
        let color = settings.resolvedColorChoice.resolved()
        userColor = color
        engineColor = color.opposite
        startFEN = variant.startFEN
        board = Board(position: Position(fen: variant.startFEN)!)
        fenLog = [variant.startFEN]
        clock = settings.timeControl.hasClock ? GameClock(control: settings.timeControl) : nil

        clock?.onFlagFall = { [weak self] color in
            self?.handleFlagFall(color)
        }
    }

    func start() {
        enqueueEngineWork { [weak self] in await self?.setupEngine() }
        // Gardée et au camp RÉEL — voir ``EngineLegalityPlayViewModel/start()``.
        if outcome == nil { clock?.startTurn(for: board.position.sideToMove) }
        if board.position.sideToMove == engineColor {
            enqueueEngineWork { [weak self] in await self?.requestEngineMove() }
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

    /// Comme ``handleViewDisappear()``, mais ATTEND que le moteur soit
    /// réellement arrêté — nécessaire avant une navigation qui va elle-même
    /// démarrer un AUTRE moteur (« Analyser ») : `.onDisappear` ne peut pas
    /// `await`, donc son arrêt reste détaché ; livré sans garantie d'ordre
    /// face au nouvel écran d'analyse qui démarre le SIEN au même instant.
    /// Les deux se disputent alors `std::cin`/`std::cout`, globaux au
    /// process — même défaut que documenté sur
    /// ``EngineController/acquireEngineProcess(timeoutMs:)``, cette fois
    /// signalé par l'utilisateur sur CE chemin précis : « moteur souvent
    /// indisponible à la fin de l'analyse après une partie variantes ».
    func stopEngineBeforeAnalysis() async {
        engineQueue.cancel()
        await engine.stop()
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

    /// Coup à surligner — celui qui mène à la position affichée. Aucune
    /// correction à faire (contrairement à Chess960) : le `Move` ChessKit
    /// EST déjà la vérité affichée, roque compris.
    var displayedLastMove: Move? {
        let index = displayedPly
        guard index > 0, index <= moveLog.count else { return nil }
        return moveLog[index - 1]
    }

    // MARK: Interaction utilisateur

    private var canUserAct: Bool {
        outcome == nil && pendingPromotion == nil && !isReviewing
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
        selectedSquare = square
        legalTargetSquares = board.legalMoves(forPieceAt: square)
    }

    func attemptUserMove(from start: Square, to end: Square) {
        guard canUserAct, start != end,
              board.position.piece(at: start)?.color == userColor
        else {
            Haptics.illegal()
            clearSelection()
            return
        }

        if let piece = board.position.piece(at: start), piece.kind == .pawn,
           end.notation.hasSuffix(userColor == .white ? "8" : "1"),
           board.canMove(pieceAt: start, to: end) {
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

    /// Accès de TEST : joue un coup pour le camp au trait, sans passer par
    /// les gardes d'interaction — le moteur n'est jamais démarré.
    func forceMove(uci: String) {
        _ = commit(uci: uci)
    }

    // MARK: Le commit — commun utilisateur/moteur

    @discardableResult
    private func commit(uci: String) -> Bool {
        let previousMover = board.position.sideToMove
        let beforeFEN = board.position.fen
        guard let move = FairyVariant.apply(uci: uci, to: &board) else { return false }
        // N'IMPORTE QUEL coup — y compris une réponse moteur — invalide
        // l'offre d'annulation d'une reprise : la restreindre au seul coup
        // utilisateur laissait l'offre active pendant qu'un coup moteur se
        // jouait dans la foulée, et `cancelResumeFromReview()` réinjectait
        // alors l'ancienne suite écartée SANS tenir compte de ce coup
        // entretemps commité, désynchronisant les journaux. Trouvé lors de
        // la revue du 25/08/2026.
        clearResumeUndo()
        uciLog.append(uci)
        sanLog.append(move.san)
        moveLog.append(move)
        fenLog.append(board.position.fen)
        playSound(for: move.san)
        hintMoves = []

        if case .check = board.state {
            checkCounts[previousMover, default: 0] += 1
        }

        if let end = detectOutcome(mover: previousMover) {
            outcome = end
            clock?.pause()
            Haptics.gameEnded()
            return true
        }

        clock?.startTurn(for: board.position.sideToMove, previousMover: previousMover)

        // AVANT la réponse du moteur — même ordre que
        // ``Chess960PlayViewModel/commit(uci:)`` (défaut réel trouvé le
        // 25/08 : inversé, la réponse moteur consommait le tour avant que
        // la vérification n'ait sa chance).
        if previousMover == userColor {
            checkForBlunderRetroactively(beforeFEN: beforeFEN, afterFEN: board.position.fen, atMoveCount: uciLog.count)
        }

        if board.position.sideToMove == engineColor {
            enqueueEngineWork { [weak self] in await self?.requestEngineMove() }
        } else {
            if settings.showEvalBar {
                enqueueEngineWork { [weak self] in await self?.updateEvalBar() }
            }
            restartHintAnalysisIfWanted()
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

    /// Mat/pat/nulle standard D'ABORD (un mat reste un mat même sur la
    /// colline), PUIS la condition propre à la variante.
    private func detectOutcome(mover: Piece.Color) -> GameOutcome? {
        if let standard = GameOutcome.fromBoardState(board.state) {
            return standard
        }
        return variant.specialOutcome(board: board, mover: mover, checkCounts: checkCounts)
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

    // MARK: Nulle proposée

    /// Dernière évaluation du MOTEUR, de son point de vue (positif = il se
    /// voit mieux). Relevée sur sa propre recherche, et non sur la barre
    /// d'évaluation, que le joueur peut avoir éteinte.
    private(set) var lastEngineEvalCp: Int?

    /// Signalé brièvement quand l'ordinateur refuse la nulle (remis à zéro
    /// par la vue après affichage).
    var drawOfferDeclinedByEngine = false

    /// L'utilisateur propose nulle. Même règle qu'en mode « Contre
    /// l'ordinateur » : accepté si le moteur ne se voit pas mieux qu'une
    /// quasi-égalité sur son dernier coup, refusé sinon — et refusé tant
    /// qu'il n'a pas joué, faute d'avoir un avis.
    func offerDrawToEngine() {
        guard outcome == nil, !isEngineThinking else { return }
        guard VariantDrawRules.engineAcceptsDraw(lastEngineEvalCp: lastEngineEvalCp) else {
            drawOfferDeclinedByEngine = true
            return
        }
        outcome = GameOutcome(winner: nil, reason: .drawByAgreement)
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
        // Plus de garde `outcome == nil` : même correctif que
        // ``EngineLegalityPlayViewModel/setupEngine()`` (30/08). Ici le
        // symptôme était plus discret — pas de bandeau, mais au retour d'une
        // analyse sur partie finie le moteur restait arrêté, et consulter un
        // coup ne rafraîchissait plus jamais la barre d'évaluation.
        guard await engine.start(variant: variant.id) else {
            isEngineUnavailable = true
            return
        }
        // Un démarrage qui aboutit efface le bandeau d'un échec passé.
        isEngineUnavailable = false
        for command in settings.strength.setupCommands {
            await engine.send(command)
        }
    }

    private func requestEngineMove() async {
        guard outcome == nil, board.position.sideToMove == engineColor else { return }
        isEngineThinking = true
        defer { isEngineThinking = false }

        await engine.synchronize()
        // S'abonner AVANT d'envoyer : un abonné ne reçoit que ce qui suit
        // son abonnement (voir ``EngineController/responseStream``) — lu
        // APRÈS le `go`, un `bestmove` rapide se perdait sous charge.
        let responses = await engine.responseStream
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
            // Capture de MAINTIEN, pas une survivance : quand le garde-fou
            // abandonne cette branche, elle survit au view model — seul `engine`
            // garde alors l'acteur (et le flux qu'on lit) en vie jusqu'à la
            // vraie fin de la lecture. L'usage EST la capture :
            _ = engine
            var bestLAN: String?
            var cp: Int?
            var mate: Int?
            for await response in responses {
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
            lastEngineEvalCp = cp
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

    /// Même salve, pour la position AFFICHÉE (consultation comprise) —
    /// appelée par ``review(toPly:)``/``reviewToLive()``. Séparée
    /// d'``updateEvalBar()`` : celle du direct se tait après une fin de
    /// partie, la consultation doit au contraire fonctionner
    /// PARTICULIÈREMENT après la fin.
    private func refreshDisplayedEvalBar() {
        guard settings.showEvalBar else { return }
        // EFFACER D'ABORD, et de façon SYNCHRONE. Sans cela, la barre gardait
        // la valeur de la position précédente pendant tout le temps du calcul
        // — soit un cinquième de seconde à afficher une évaluation qui ne
        // correspond pas à ce qu'on voit. Une barre neutre le temps du
        // calcul dit « je ne sais pas encore », ce qui est vrai ; l'ancienne
        // valeur dit quelque chose de faux. C'est aussi ce qui rend
        // observable, donc testable, le fait que consulter un coup passé
        // relance bien l'évaluation.
        currentEvalCp = nil
        currentEvalMate = nil
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            await self.refreshEvalBar(fen: self.displayedBoard.position.fen, mover: self.displayedBoard.position.sideToMove)
        }
    }

    private func refreshEvalBar(fen: String, mover: Piece.Color) async {
        await engine.synchronize()
        // S'abonner AVANT d'envoyer : un abonné ne reçoit que ce qui suit
        // son abonnement (voir ``EngineController/responseStream``) — lu
        // APRÈS le `go`, un `bestmove` rapide se perdait sous charge.
        let responses = await engine.responseStream
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: 220))

        let search = await EngineWatchdog.run(deadlineMs: 220 + EngineWatchdog.graceMs) { [engine] in
            _ = engine  // capture de MAINTIEN — voir le premier garde-fou du fichier
            var cp: Int?
            var mate: Int?
            for await response in responses {
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

        // Comparée à la position AFFICHÉE (pas seulement la position live) :
        // une salve lancée en consultation ne doit pas s'appliquer à tort
        // après un retour au direct, ni l'inverse.
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
        // S'abonner AVANT d'envoyer : un abonné ne reçoit que ce qui suit
        // son abonnement (voir ``EngineController/responseStream``) — lu
        // APRÈS le `go`, un `bestmove` rapide se perdait sous charge.
        let responses = await engine.responseStream
        await engine.send(.setoption(id: "MultiPV", value: "3"))
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: Self.hintBudgetMs))

        let search = await EngineWatchdog.run(deadlineMs: Self.hintBudgetMs + EngineWatchdog.graceMs) { [engine] in
            _ = engine  // capture de MAINTIEN — voir le premier garde-fou du fichier
            var lanByRank: [Int: String] = [:]
            var scoreByRank: [Int: Double] = [:]
            for await response in responses {
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
        enqueueEngineWork { [weak self] in self?.takeback() }
    }

    private func quickScore(fen: String) async -> (cp: Int, mate: Int?)? {
        await engine.synchronize()
        // S'abonner AVANT d'envoyer : un abonné ne reçoit que ce qui suit
        // son abonnement (voir ``EngineController/responseStream``) — lu
        // APRÈS le `go`, un `bestmove` rapide se perdait sous charge.
        let responses = await engine.responseStream
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: 300))

        let outcome = await EngineWatchdog.run(deadlineMs: 300 + EngineWatchdog.graceMs) {
            [engine] () -> (cp: Int, mate: Int?)? in
            _ = engine  // capture de MAINTIEN — voir le premier garde-fou du fichier
            var cp: Int?
            var mate: Int?
            for await response in responses {
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
        reviewBoard = replayed(prefix: clamped)
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

    func takeback() {
        guard canTakeback else { return }
        let whiteJustMoved = board.position.sideToMove == .black
        let moverWasEngine = (whiteJustMoved ? Piece.Color.white : .black) == engineColor
        let count = (moverWasEngine && uciLog.count >= 2) ? 2 : 1
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

    /// Reconstruit `board`, le journal des coups et le compteur d'échecs
    /// depuis ``uciLog``/``sanLog`` — le chemin commun de la reprise de coup
    /// et de l'annulation de reprise.
    private func rebuildFromLogs() {
        var rebuilt = Board(position: Position(fen: startFEN)!)
        var counts: [Piece.Color: Int] = [.white: 0, .black: 0]
        var rebuiltMoves: [Move] = []
        var rebuiltFens: [String] = [startFEN]
        for uci in uciLog {
            let mover = rebuilt.position.sideToMove
            guard let move = FairyVariant.apply(uci: uci, to: &rebuilt) else { break }
            rebuiltMoves.append(move)
            rebuiltFens.append(rebuilt.position.fen)
            if case .check = rebuilt.state {
                counts[mover, default: 0] += 1
            }
        }
        board = rebuilt
        moveLog = rebuiltMoves
        fenLog = rebuiltFens
        checkCounts = counts
        outcome = nil
        pendingBlunderWarning = nil
        clearSelection()
        currentEvalCp = nil
        currentEvalMate = nil
        hintMoves = []

        if board.position.sideToMove == engineColor {
            enqueueEngineWork { [weak self] in await self?.requestEngineMove() }
        } else {
            if settings.showEvalBar {
                enqueueEngineWork { [weak self] in await self?.updateEvalBar() }
            }
            restartHintAnalysisIfWanted()
        }
    }

    private func replayed(prefix count: Int) -> Board {
        var replayed = Board(position: Position(fen: startFEN)!)
        for uci in uciLog.prefix(count) { _ = FairyVariant.apply(uci: uci, to: &replayed) }
        return replayed
    }

    // MARK: Export

    var displayedFEN: String { displayedBoard.position.fen }

    /// PGN — tag `Variant` propre à Fairy-Stockfish (lu par Lichess et les
    /// autres logiciels compatibles).
    var exportedPGN: String {
        var tags = [
            "[Event \"ChessLab \(variant.displayName)\"]",
            "[Variant \"\(variant.id)\"]",
        ]
        // Horde n'a pas la position de départ classique : le dire au format
        // PGN standard (comme Chess960) pour qu'un lecteur externe la
        // retrouve, plutôt que de supposer la position initiale usuelle.
        if variant.id == FairyVariant.horde.id {
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
