import ChessKit
import Foundation
import Observation
import UIKit

/// Partie de Duck Chess — contre l'ordinateur, ou à deux sur le même
/// appareil.
///
/// Le tour se joue en DEUX temps, et c'est toute la variante : on déplace une
/// pièce, PUIS on pose le canard. Tant que le canard n'est pas posé, le trait
/// n'a pas changé. Tout le reste de cette classe découle de cette phrase — la
/// phase courante, le moment où la pendule bascule, celui où l'adversaire
/// prend la main, et la façon dont un demi-coup se journalise.
///
/// L'adversaire artificiel vit dans ``DuckChessEngine`` : Stockfish standard,
/// borné aux coups que le canard autorise. Il ignore le canard dans son
/// évaluation — compromis assumé, annoncé au joueur dans l'écran de réglages.
@MainActor
@Observable
final class DuckChessViewModel {

    enum Phase: Equatable {
        case movePiece
        case placeDuck
    }

    // MARK: Position vive

    private(set) var position: Position
    private(set) var board: Board
    private(set) var phase: Phase = .movePiece
    private(set) var duckSquare: Square?
    private(set) var outcome: GameOutcome?

    private(set) var selectedSquare: Square?
    private(set) var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?

    struct PendingPromotion: Equatable { let from: Square; let to: Square }
    private(set) var pendingPromotion: PendingPromotion?

    /// Case de prise en passant offerte par le coup précédent.
    private var enPassant: Square?

    static let startFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    // MARK: Journaux
    //
    // Un seul jeu d'index pour les cinq : `xxxLog[i]` décrit l'état APRÈS le
    // demi-coup `i`, et `fenLog`/`duckLog`/`enPassantLog` portent en plus la
    // case zéro, celle du départ. C'est ce qui rend la reprise d'un coup
    // exacte SANS rejeu : reculer, c'est relire la ligne `i`, pas rejouer la
    // partie depuis le début — un rejeu devrait refaire aussi le chemin du
    // canard et des prises en passant, que rien dans les coups ne redit.

    private(set) var sanLog: [String] = []
    private(set) var uciLog: [String] = []
    private(set) var moveLog: [Move] = []
    private(set) var fenLog: [String] = []
    private(set) var duckLog: [Square?] = []
    private(set) var enPassantLog: [Square?] = []

    // MARK: Réglages et adversaire

    let settings: FairyVariantSettings
    let variant = DuckChessVariant.shared
    /// `nil` = partie à deux sur le même appareil ; sinon, la couleur que
    /// l'ORDINATEUR tient.
    let engineColor: Piece.Color?
    var userColor: Piece.Color { engineColor?.opposite ?? .white }
    var isVersusEngine: Bool { engineColor != nil }

    private let engine: DuckChessEngine?
    private(set) var isEngineThinking = false
    private(set) var isEngineUnavailable = false

    /// File d'attente SÉRIELLE des travaux moteur.
    ///
    /// ``DuckChessEngine`` est un acteur, mais la réentrance des acteurs ne
    /// protège de rien ici : une recherche suspendue sur `await` laisse
    /// entrer la suivante, et ``EngineController`` n'a qu'UNE continuation en
    /// cours — la seconde recherche invaliderait la première, qui rendrait
    /// `nil` (coup perdu, repli sur l'heuristique). Coup de l'ordinateur,
    /// indice, barre d'éval et alerte gaffe passent donc tous par ici, chacun
    /// à son tour.
    private var engineQueue: Task<Void, Never> = Task {}

    let clock: GameClock?

    private(set) var currentEvalCp: Int?

    private(set) var hintMoves: [HintMove] = []
    private(set) var hintsWanted = false

    var pendingBlunderWarning: PendingBlunderWarning?

    // MARK: Consultation d'un coup passé

    private(set) var reviewPly: Int?

    init(settings: FairyVariantSettings = FairyVariantSettings(), versusEngine: Bool = true) {
        self.settings = settings
        let start = Position(fen: Self.startFEN)!
        position = start
        board = Board(position: start)
        fenLog = [Self.startFEN]
        duckLog = [nil]
        enPassantLog = [nil]

        if versusEngine {
            let userSide = settings.resolvedColorChoice.resolved()
            engineColor = userSide.opposite
            engine = DuckChessEngine(strength: settings.strength)
        } else {
            engineColor = nil
            engine = nil
        }
        clock = settings.timeControl.hasClock ? GameClock(control: settings.timeControl) : nil
        clock?.onFlagFall = { [weak self] color in
            self?.handleFlagFall(color)
        }
    }

    // MARK: Affichage

    var sideToMove: Piece.Color { position.sideToMove }
    var totalPlies: Int { sanLog.count }
    var displayedPly: Int { reviewPly ?? totalPlies }
    var isReviewing: Bool { reviewPly != nil }

    var displayedBoard: Board {
        guard let reviewPly, reviewPly < fenLog.count,
              let reviewed = Position(fen: fenLog[reviewPly])
        else { return board }
        return Board(position: reviewed)
    }

    /// Le canard tel qu'il était au coup consulté — sinon celui de la partie.
    var displayedDuck: Square? {
        guard let reviewPly, reviewPly < duckLog.count else { return duckSquare }
        return duckLog[reviewPly]
    }

    var displayedLastMove: Move? {
        let index = displayedPly
        guard index > 0, index <= moveLog.count else { return nil }
        return moveLog[index - 1]
    }

    var displayedFEN: String {
        let index = min(displayedPly, fenLog.count - 1)
        return fenLog[index]
    }

    var numberedMoves: [(number: Int, white: String, black: String?)] {
        stride(from: 0, to: sanLog.count, by: 2).map { index in
            (index / 2 + 1, sanLog[index], index + 1 < sanLog.count ? sanLog[index + 1] : nil)
        }
    }

    /// Ce que l'écran doit dire de faire, ici et maintenant.
    var instruction: String {
        if outcome != nil { return LocalizationController.string("Partie terminée") }
        if isReviewing { return LocalizationController.string("Consultation d'un coup passé") }
        if isVersusEngine, sideToMove != userColor {
            return LocalizationController.string("L'ordinateur réfléchit")
        }
        return phase == .movePiece
            ? LocalizationController.string("Déplacez une pièce")
            : LocalizationController.string("Posez le canard sur une case vide")
    }

    // MARK: Cycle de vie

    /// Appelée à CHAQUE apparition de l'écran, pas seulement à la première.
    ///
    /// La vue-modèle survit à la navigation (``SessionStore`` la conserve
    /// exprès), et ``handleViewDisappear()`` a arrêté le moteur en partant.
    /// Sans redémarrage, l'ordinateur revenait MUET : `chooseMove` se
    /// repliait sur son heuristique locale et jouait au hasard, sans rien
    /// dire. Le trait est relancé sur le camp RÉELLEMENT au trait — pas sur
    /// les Blancs — et sans incrément, la pendule ne reprenant pas un tour
    /// qu'elle n'a pas fini.
    func start() {
        clock?.startTurn(for: sideToMove)
        guard isVersusEngine, let engine else { return }
        enqueueEngineWork { [weak self] in
            guard await engine.start() else {
                self?.isEngineUnavailable = true
                return
            }
            self?.isEngineUnavailable = false
        }
        playEngineTurnIfNeeded()
        refreshEvalBar()
        refreshHints()
    }

    func handleViewDisappear() {
        clock?.pause()
        engineQueue.cancel()
        // Le travail en file ne s'exécutera jamais, donc son `defer` non plus :
        // sans ce rappel à la main, l'écran gardait un tourniquet allumé pour
        // toujours et interdisait la reprise d'un coup.
        isEngineThinking = false
        if let engine { Task { await engine.stop() } }
    }

    /// Le moteur d'analyse et celui de la partie partagent `std::cin`/
    /// `std::cout` : deux processus ne peuvent pas coexister (voir
    /// ``FairyVariantPlayViewModel/stopEngineBeforeAnalysis()``). Celui-ci
    /// s'efface avant que l'écran d'analyse ne démarre le sien.
    func stopEngineBeforeAnalysis() async {
        engineQueue.cancel()
        isEngineThinking = false
        if let engine { await engine.stop() }
    }

    private func enqueueEngineWork(_ work: @escaping () async -> Void) {
        let previous = engineQueue
        engineQueue = Task {
            _ = await previous.value
            guard !Task.isCancelled else { return }
            await work()
        }
    }

    // MARK: Le tour de l'ordinateur

    /// Le tour COMPLET de l'ordinateur : son coup, puis son canard.
    ///
    /// Les deux temps s'enchaînent dans un seul travail — un tour n'a pas de
    /// sens à moitié, et l'utilisateur ne doit jamais reprendre la main entre
    /// les deux.
    private func playEngineTurnIfNeeded() {
        guard let engine, let engineColor, outcome == nil, !isReviewing,
              sideToMove == engineColor, phase == .movePiece
        else { return }

        isEngineThinking = true
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            defer { self.isEngineThinking = false }

            // Rien n'a bougé depuis la mise en file ? On le revérifie : la
            // reprise d'un coup ou l'abandon ont pu passer entre-temps.
            guard self.outcome == nil, self.sideToMove == engineColor, self.phase == .movePiece
            else { return }

            guard let move = await engine.chooseMove(
                position: self.position, duck: self.duckSquare, enPassant: self.enPassant
            ) else { return }
            guard !Task.isCancelled, self.outcome == nil, self.sideToMove == engineColor,
                  self.phase == .movePiece
            else { return }
            self.apply(move)

            // La partie peut s'être terminée sur la prise du roi : le canard
            // n'a alors plus d'objet.
            guard self.outcome == nil, !Task.isCancelled else { return }
            if let square = await engine.chooseDuckSquare(
                position: self.position, currentDuck: self.duckSquare, enPassant: self.enPassant
            ), !Task.isCancelled {
                self.placeDuck(on: square)
            }
        }
    }

    // MARK: Indice

    var hintsAvailable: Bool { isVersusEngine && settings.hintsEnabled }

    func toggleHint() {
        guard hintsAvailable else { return }
        hintsWanted.toggle()
        if hintsWanted { refreshHints() } else { hintMoves = [] }
    }

    private func refreshHints() {
        guard hintsWanted, let engine, outcome == nil, !isReviewing,
              phase == .movePiece, sideToMove == userColor
        else { hintMoves = []; return }
        let fenAtRequest = position.fen
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            guard let move = await engine.chooseMove(
                position: self.position, duck: self.duckSquare, enPassant: self.enPassant
            ) else { return }
            guard self.hintsWanted, self.position.fen == fenAtRequest else { return }
            self.hintMoves = [HintMove(rank: 1, from: move.from, to: move.to, strength: 1.0)]
        }
    }

    // MARK: Barre d'éval

    private func refreshEvalBar() {
        guard settings.showEvalBar, let engine else { return }
        let fen = displayedFEN
        let duck = displayedDuck
        let ep = isReviewing ? enPassantLog[min(displayedPly, enPassantLog.count - 1)] : enPassant
        guard let evaluated = Position(fen: fen) else { return }
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            let result = await engine.evaluate(
                position: evaluated, duck: duck, enPassant: ep, movetimeMs: 400
            )
            guard self.displayedFEN == fen else { return }
            self.currentEvalCp = result?.cpWhite
        }
    }

    // MARK: Alerte gaffe

    /// Le coup de l'utilisateur vient-il de tout casser ?
    ///
    /// Mesuré sur le TOUR complet (canard compris) et non sur le seul
    /// déplacement : en Duck Chess, une pièce bien placée et un canard mal
    /// posé font un mauvais tour, et l'inverse est vrai aussi.
    private func checkForBlunder(
        beforeFEN: String, beforeDuck: Square?, beforeEnPassant: Square?, atPly: Int
    ) {
        guard settings.blunderAlertEnabled, let engine, isVersusEngine else { return }
        guard let before = Position(fen: beforeFEN) else { return }
        let afterFEN = position.fen
        let afterDuck = duckSquare
        let afterEP = enPassant

        enqueueEngineWork { [weak self] in
            guard let self else { return }
            guard let evalBefore = await engine.evaluate(
                position: before, duck: beforeDuck, enPassant: beforeEnPassant, movetimeMs: 300
            ) else { return }
            guard let after = Position(fen: afterFEN),
                  let evalAfter = await engine.evaluate(
                      position: after, duck: afterDuck, enPassant: afterEP, movetimeMs: 300
                  )
            else { return }

            // ``PlayViewModel/blunderSeverity(before:after:)`` raisonne du
            // point de vue du camp AU TRAIT de chaque position.
            let moverBefore = before.sideToMove
            let beforeCp = moverBefore == .white ? evalBefore.cpWhite : -evalBefore.cpWhite
            let afterCp = after.sideToMove == .white ? evalAfter.cpWhite : -evalAfter.cpWhite
            guard let severity = PlayViewModel.blunderSeverity(
                before: (cp: beforeCp, mate: nil), after: (cp: afterCp, mate: nil)
            ) else { return }
            guard atPly == self.totalPlies, self.outcome == nil, self.canTakeback else { return }
            self.pendingBlunderWarning = PendingBlunderWarning(severity: severity)
        }
    }

    func dismissBlunderWarning() { pendingBlunderWarning = nil }

    func takebackAfterBlunderWarning() {
        pendingBlunderWarning = nil
        takeback()
    }

    private func handleFlagFall(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .timeout)
        clock?.pause()
        Haptics.gameEnded()
    }

    // MARK: Interaction

    private var canUserAct: Bool {
        outcome == nil && pendingPromotion == nil && !isReviewing
            && !(isVersusEngine && sideToMove != userColor)
    }

    func selectSquare(_ square: Square) {
        guard canUserAct else { return }

        if phase == .placeDuck {
            placeDuck(on: square)
            return
        }

        if selectedSquare != nil, legalTargetSquares.contains(square) {
            attemptMove(to: square)
            return
        }
        guard let piece = position.piece(at: square), piece.color == sideToMove else {
            clearSelection()
            return
        }
        selectedSquare = square
        legalTargetSquares = Array(Set(
            currentMoves.filter { $0.from == square }.map(\.to)
        ))
    }

    func attemptUserMove(from start: Square, to end: Square) {
        guard canUserAct, phase == .movePiece else { return }
        guard let piece = position.piece(at: start), piece.color == sideToMove else {
            Haptics.illegal()
            return
        }
        selectedSquare = start
        legalTargetSquares = Array(Set(currentMoves.filter { $0.from == start }.map(\.to)))
        attemptMove(to: end)
    }

    private func attemptMove(to end: Square) {
        guard let from = selectedSquare else { return }
        let candidates = currentMoves.filter { $0.from == from && $0.to == end }
        guard !candidates.isEmpty else {
            Haptics.illegal()
            clearSelection()
            return
        }
        if candidates.contains(where: { $0.promotion != nil }) {
            pendingPromotion = PendingPromotion(from: from, to: end)
            clearSelection()
            return
        }
        apply(candidates[0])
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        apply(DuckChessRules.Move(from: pending.from, to: pending.to, promotion: kind))
    }

    func cancelPromotion() { pendingPromotion = nil }

    /// L'état du tour au moment où l'utilisateur l'a commencé — sert de point
    /// de comparaison à l'alerte gaffe, qui juge le tour ENTIER.
    private var turnStartFEN: String?
    private var turnStartDuck: Square?
    private var turnStartEnPassant: Square?

    /// Pose le canard, ce qui CLÔT le tour et passe le trait.
    private func placeDuck(on square: Square) {
        guard phase == .placeDuck, outcome == nil,
              DuckChessRules.duckTargets(in: position, currentDuck: duckSquare).contains(square)
        else {
            Haptics.illegal()
            return
        }
        let mover = sideToMove
        duckSquare = square
        phase = .movePiece
        // Le trait ne change qu'ICI : c'est la pose du canard qui termine le
        // tour, pas le déplacement de la pièce.
        position = Self.flippedSideToMove(of: position)
        board = Board(position: position)
        duckLog[duckLog.count - 1] = square
        fenLog[fenLog.count - 1] = position.fen
        sanLog[sanLog.count - 1] += "@" + square.notation
        Haptics.move()
        clock?.startTurn(for: sideToMove, previousMover: mover)
        hintMoves = []

        if mover == userColor, let startFEN = turnStartFEN {
            checkForBlunder(
                beforeFEN: startFEN, beforeDuck: turnStartDuck,
                beforeEnPassant: turnStartEnPassant, atPly: totalPlies
            )
        }
        turnStartFEN = nil
        turnStartDuck = nil
        turnStartEnPassant = nil

        refreshEvalBar()
        playEngineTurnIfNeeded()
        refreshHints()
    }

    // MARK: Application d'un coup

    private var currentMoves: [DuckChessRules.Move] {
        DuckChessRules.moves(in: position, duck: duckSquare, enPassant: enPassant)
    }

    private func apply(_ move: DuckChessRules.Move) {
        clearSelection()
        guard let piece = position.piece(at: move.from) else { return }

        if piece.color == userColor {
            turnStartFEN = position.fen
            turnStartDuck = duckSquare
            turnStartEnPassant = enPassant
        }

        let victim = DuckChessRules.capturesKing(move, in: position)
        let san = DuckChessSAN.build(
            move: move, position: position, legalMoves: currentMoves, capturesKing: victim != nil
        )

        // La prise se lit sur la position d'AVANT : après le coup, la case
        // d'arrivée porte forcément la pièce qui vient d'y aller.
        let captured = position.piece(at: move.to)
        position = Self.applied(move, to: position)
        board = Board(position: position)
        let played = Move(
            result: captured.map { Move.Result.capture($0) } ?? .move,
            piece: piece, start: move.from, end: move.to
        )
        lastMove = played

        // Poussée double : la case survolée devient prenable en passant.
        if piece.kind == .pawn, abs(move.to.rank.value - move.from.rank.value) == 2 {
            let middle = (move.to.rank.value + move.from.rank.value) / 2
            enPassant = Square("\(move.from.file.rawValue)\(middle)")
        } else {
            enPassant = nil
        }

        sanLog.append(san)
        uciLog.append(move.uci)
        moveLog.append(played)
        fenLog.append(position.fen)
        duckLog.append(duckSquare)
        enPassantLog.append(enPassant)

        if let victim {
            // Le roi est tombé : la partie s'arrête AVANT même la pose du
            // canard, qui n'aurait plus d'objet.
            outcome = GameOutcome(winner: victim.opposite, reason: .checkmate)
            phase = .movePiece
            clock?.pause()
            hintMoves = []
            Haptics.gameEnded()
            SoundPlayer.shared.play(.check)
            return
        }

        phase = .placeDuck
        SoundPlayer.shared.play(san.contains("x") ? .capture : .move)
    }

    private func clearSelection() {
        selectedSquare = nil
        legalTargetSquares = []
    }

    // MARK: Consultation & reprise

    func review(toPly ply: Int) {
        let clamped = max(0, min(ply, totalPlies))
        guard clamped != totalPlies else {
            reviewToLive()
            return
        }
        reviewPly = clamped
        clearSelection()
        hintMoves = []
        refreshEvalBar()
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }

    func reviewToLive() {
        reviewPly = nil
        clearSelection()
        refreshEvalBar()
        refreshHints()
    }

    /// Un tour INCOMPLET ne se reprend pas : le canard est déjà en l'air.
    var canTakeback: Bool {
        !settings.timeControl.hasClock && !sanLog.isEmpty && outcome == nil
            && !isEngineThinking && phase == .movePiece
    }

    /// Retire le dernier tour de l'utilisateur ET la réponse de l'ordinateur
    /// s'il a déjà répondu — sinon reprendre un coup rendrait la main à la
    /// machine, qui rejouerait aussitôt.
    func takeback() {
        guard canTakeback else { return }
        var count = 1
        if isVersusEngine, moveLog.last?.piece.color == engineColor, sanLog.count >= 2 {
            count = 2
        }
        truncate(to: max(0, sanLog.count - count))
    }

    var canResumeFromReview: Bool {
        guard let reviewPly else { return false }
        return !settings.timeControl.hasClock && outcome == nil && !isEngineThinking
            && reviewPly < totalPlies
    }

    /// Les demi-coups écartés par une reprise, gardés le temps d'une
    /// annulation. Tous les journaux y passent : le canard et la prise en
    /// passant ne se redéduisent pas des seuls coups.
    struct ResumeUndo {
        let san: [String]
        let uci: [String]
        let moves: [Move]
        let fens: [String]
        let ducks: [Square?]
        let enPassants: [Square?]
        var discardedCount: Int { san.count }
    }

    private(set) var resumeUndo: ResumeUndo?
    private var resumeUndoTask: Task<Void, Never>?
    private static let resumeUndoDelay: Duration = .seconds(8)

    func resumeFromReview() {
        guard let reviewPly, canResumeFromReview else { return }
        let undo = ResumeUndo(
            san: Array(sanLog.suffix(from: reviewPly)),
            uci: Array(uciLog.suffix(from: reviewPly)),
            moves: Array(moveLog.suffix(from: reviewPly)),
            fens: Array(fenLog.suffix(from: reviewPly + 1)),
            ducks: Array(duckLog.suffix(from: reviewPly + 1)),
            enPassants: Array(enPassantLog.suffix(from: reviewPly + 1))
        )
        reviewToLive()
        truncate(to: reviewPly)
        guard !undo.san.isEmpty else { return }
        offerResumeUndo(undo)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(
                notification: .announcement,
                argument: LocalizationController.string(
                    "Partie reprise, %lld coups écartés. Annulation possible.", undo.discardedCount
                )
            )
        }
    }

    func cancelResumeFromReview() {
        guard let undo = resumeUndo, outcome == nil, !isEngineThinking else { return }
        clearResumeUndo()
        sanLog += undo.san
        uciLog += undo.uci
        moveLog += undo.moves
        fenLog += undo.fens
        duckLog += undo.ducks
        enPassantLog += undo.enPassants
        restoreLiveState()
        refreshEvalBar()
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
        engineQueue.cancel()
        isEngineThinking = false
        sanLog = Array(sanLog.prefix(count))
        uciLog = Array(uciLog.prefix(count))
        moveLog = Array(moveLog.prefix(count))
        fenLog = Array(fenLog.prefix(count + 1))
        duckLog = Array(duckLog.prefix(count + 1))
        enPassantLog = Array(enPassantLog.prefix(count + 1))
        restoreLiveState()
        refreshEvalBar()
        playEngineTurnIfNeeded()
        refreshHints()
    }

    /// Recale la position vive sur la DERNIÈRE ligne des journaux.
    private func restoreLiveState() {
        let last = fenLog.count - 1
        position = Position(fen: fenLog[last]) ?? position
        board = Board(position: position)
        duckSquare = duckLog[last]
        enPassant = enPassantLog[last]
        phase = .movePiece
        outcome = nil
        pendingPromotion = nil
        pendingBlunderWarning = nil
        turnStartFEN = nil
        turnStartDuck = nil
        turnStartEnPassant = nil
        lastMove = moveLog.last
        hintMoves = []
        clearSelection()
    }

    // MARK: Abandon

    func resign(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .resignation)
        clock?.pause()
        hintMoves = []
        Haptics.gameEnded()
    }

    func userResigns() { resign(userColor) }

    // MARK: Nulle proposée

    /// Dernière évaluation du moteur, de SON point de vue.
    ///
    /// Le Duck Chess n'a pas de nulle « selon les règles » — on y gagne en
    /// capturant le roi, il n'y a ni pat ni matériel insuffisant (un fou seul
    /// prend un roi). La nulle par ACCORD, elle, garde tout son sens : deux
    /// joueurs peuvent convenir d'en rester là.
    private var lastEngineEvalCp: Int? {
        guard let currentEvalCp, let engineColor else { return nil }
        return engineColor == .white ? currentEvalCp : -currentEvalCp
    }

    var drawOfferDeclinedByEngine = false

    /// L'avis du moteur ne traîne pas toujours à portée : `currentEvalCp` ne
    /// se remplit que si le joueur a laissé la barre d'évaluation allumée. On
    /// le lui DEMANDE alors, plutôt que de refuser la nulle pour une raison
    /// qui n'a rien à voir avec la position.
    func offerDrawToEngine() {
        guard outcome == nil, isVersusEngine, !isEngineThinking, let engine else { return }
        if let known = lastEngineEvalCp {
            settleDrawOffer(engineEvalCp: known)
            return
        }
        enqueueEngineWork { [weak self] in
            guard let self, self.outcome == nil else { return }
            let evaluated = await engine.evaluate(
                position: self.position, duck: self.duckSquare,
                enPassant: self.enPassant, movetimeMs: 400
            )
            let cp = evaluated.map { self.engineColor == .white ? $0.cpWhite : -$0.cpWhite }
            self.settleDrawOffer(engineEvalCp: cp)
        }
    }

    private func settleDrawOffer(engineEvalCp: Int?) {
        guard outcome == nil else { return }
        guard VariantDrawRules.engineAcceptsDraw(lastEngineEvalCp: engineEvalCp) else {
            drawOfferDeclinedByEngine = true
            return
        }
        outcome = GameOutcome(winner: nil, reason: .drawByAgreement)
        clock?.pause()
        hintMoves = []
        Haptics.gameEnded()
    }

    /// À deux sur le même appareil, personne n'a besoin d'être convaincu.
    func agreeToDraw() {
        guard outcome == nil, !isVersusEngine else { return }
        outcome = GameOutcome(winner: nil, reason: .drawByAgreement)
        clock?.pause()
        hintMoves = []
        Haptics.gameEnded()
    }

    // MARK: Export & analyse

    /// PGN annoté à la mode Duck Chess : `e4@f6` — le coup, puis la case du
    /// canard. Aucun lecteur externe ne connaît cette variante ; l'export sert
    /// à relire et à partager une partie, pas à la rejouer ailleurs.
    var exportedPGN: String {
        var tags = [
            "[Event \"ChessLab \(variant.displayName)\"]",
            "[Variant \"\(variant.id)\"]",
        ]
        if isVersusEngine, let engineColor {
            let user = LocalizationController.string("Vous")
            let machine = LocalizationController.string("Ordinateur")
            tags.append("[White \"\(engineColor == .white ? machine : user)\"]")
            tags.append("[Black \"\(engineColor == .black ? machine : user)\"]")
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

    var analysisSeed: DuckChessAnalysisSeed {
        DuckChessAnalysisSeed(
            startFEN: Self.startFEN,
            sanLog: sanLog,
            uciLog: uciLog,
            moveLog: moveLog,
            fenLog: fenLog,
            duckLog: duckLog,
            enPassantLog: enPassantLog,
            outcome: outcome,
            orientation: userColor
        )
    }

    // MARK: Manipulation de position

    /// Joue le coup sur la position, en passant par la FEN.
    ///
    /// ChessKit refuserait ces coups (il filtre sur l'échec, absent ici), donc
    /// on écrit nous-mêmes le plateau résultant — c'est la contrepartie
    /// assumée d'une variante sans arbitre.
    static func applied(_ move: DuckChessRules.Move, to position: Position) -> Position {
        var squares: [Square: Piece] = [:]
        for piece in position.pieces { squares[piece.square] = piece }

        guard let moving = squares[move.from] else { return position }
        squares[move.from] = nil

        // Prise en passant : le pion capturé n'est PAS sur la case d'arrivée.
        if moving.kind == .pawn, move.from.file != move.to.file, squares[move.to] == nil {
            let capturedRank = move.from.rank.value
            squares[Square("\(move.to.file.rawValue)\(capturedRank)")] = nil
        }
        // Roque : la tour suit le roi.
        if moving.kind == .king, abs(move.to.file.number - move.from.file.number) == 2 {
            let rank = move.from.rank.value
            let isShort = move.to.file.number > move.from.file.number
            let rookFrom = Square("\(isShort ? "h" : "a")\(rank)")
            let rookTo = Square("\(isShort ? "f" : "d")\(rank)")
            if let rook = squares[rookFrom] {
                squares[rookFrom] = nil
                squares[rookTo] = Piece(rook.kind, color: rook.color, square: rookTo)
            }
        }
        let landedKind = move.promotion ?? moving.kind
        squares[move.to] = Piece(landedKind, color: moving.color, square: move.to)

        return Position(
            fen: DuckChessFEN.build(
                squares: squares,
                // Le trait reste au MÊME camp : son tour n'est pas fini, il
                // lui reste le canard à poser. C'est ``placeDuck(on:)`` qui
                // le passe, et lui seul — les faire tous les deux basculait
                // le trait deux fois par demi-coup, donc jamais.
                sideToMove: position.sideToMove,
                castling: DuckChessFEN.updatedCastling(
                    from: position, movedPiece: moving, from: move.from, to: move.to
                )
            )
        ) ?? position
    }

    /// Rend la main à l'autre camp sans rien bouger — le trait change à la
    /// POSE du canard, pas au déplacement.
    static func flippedSideToMove(of position: Position) -> Position {
        DuckChessEngine.sideToMoveFlipped(position) ?? position
    }
}
