import ChessKit
import Foundation
import Observation
import UIKit

/// Partie de Chess960 contre l'ordinateur.
///
/// Un view model DÉDIÉ et volontairement plus petit que ``PlayViewModel`` :
/// la légalité vient de ``Chess960Game`` (couche partagée, prouvée par
/// perft), et le journal de partie est en UCI/SAN — pas en `Move` ChessKit,
/// qu'un roque 960 ne sait pas représenter. Les composants extraits, eux,
/// sont repris tels quels : ``ChessBoardView``, ``PlayControlBar``,
/// ``GameClock``, ``EngineStrength``, ``EvalBarView``.
///
/// Périmètre du lot 2 : couleur, force Elo, cadence avec pendule, barre
/// d'évaluation, consultation + « Reprendre ici » avec annulation (le
/// pattern du 24/08), reprise de coup, abandon, export FEN/PGN. Sans indice,
/// alerte gaffe, livre (pas de théorie en 960) ni autosauvegarde — lots
/// suivants, documentés dans le plan.
@Observable
@MainActor
final class Chess960PlayViewModel {

    // MARK: État de partie

    let settings: Chess960Settings
    let userColor: Piece.Color
    let engineColor: Piece.Color

    private(set) var game: Chess960Game
    /// Journal en UCI (dialecte roi-prend-tour) — la source de vérité du
    /// rejeu ; le SAN, parallèle, sert à l'affichage et au PGN.
    private(set) var uciLog: [String] = []
    private(set) var sanLog: [String] = []
    /// Cases à surligner, un couple par coup — voir
    /// ``Chess960Game/displaySquares(forUCI:)`` : pour un roque, l'arrivée
    /// affichée est celle du ROI, pas le dialecte roi-prend-tour de l'UCI
    /// moteur.
    private var displaySquaresLog: [(from: Square, to: Square)] = []
    private(set) var outcome: GameOutcome?
    /// Occurrences de chaque position (clé : 4 champs Shredder) — la nulle
    /// par répétition vit ICI : le compteur interne de ChessKit ne survit pas
    /// à la reconstruction qu'exige un roque.
    private var repetitionCounts: [String: Int] = [:]

    let clock: GameClock?
    private let startFEN: String

    // MARK: Interaction

    private(set) var selectedSquare: Square?
    private(set) var legalTargetSquares: [Square] = []
    struct PendingPromotion: Equatable { let from: Square; let to: Square }
    private(set) var pendingPromotion: PendingPromotion?

    // MARK: Moteur

    private let engine = EngineController()
    private var engineQueue: Task<Void, Never> = Task {}
    private(set) var isEngineThinking = false
    private(set) var isEngineUnavailable = false
    private(set) var currentEvalCp: Int?
    private(set) var currentEvalMate: Int?

    // MARK: Indice — analyse ponctuelle, PAS continue (voir startHintAnalysis)

    var hintMoves: [HintMove] = []
    private(set) var hintsWanted = false
    private(set) var isHintAnalyzing = false

    // MARK: Alerte gaffe

    var pendingBlunderWarning: PendingBlunderWarning?

    // MARK: Consultation

    private(set) var reviewPly: Int?
    private var reviewGame: Chess960Game?

    // MARK: Cycle de vie

    init(settings: Chess960Settings) {
        self.settings = settings
        let color = settings.resolvedColorChoice.resolved()
        userColor = color
        engineColor = color.opposite
        let fen = Chess960Position.startingFEN(number: settings.positionNumber)
            ?? Chess960Position.startingFEN(number: 518)!
        startFEN = fen
        game = Chess960Game(fen: fen)!
        clock = settings.timeControl.hasClock ? GameClock(control: settings.timeControl) : nil
        repetitionCounts[game.repetitionKey] = 1

        clock?.onFlagFall = { [weak self] color in
            self?.handleFlagFall(color)
        }
    }

    func start() {
        enqueueEngineWork { [weak self] in await self?.setupEngine() }
        clock?.startTurn(for: .white)
        if game.board.position.sideToMove == engineColor {
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

    /// Voir le commentaire jumeau sur
    /// ``FairyVariantPlayViewModel/stopEngineBeforeAnalysis()``.
    func stopEngineBeforeAnalysis() async {
        engineQueue.cancel()
        await engine.stop()
    }

    // MARK: Affichage

    var displayedGame: Chess960Game { reviewGame ?? game }
    var displayedBoard: Board { displayedGame.board }
    var totalPlies: Int { uciLog.count }
    var displayedPly: Int { reviewPly ?? uciLog.count }
    var isReviewing: Bool { reviewPly != nil }

    /// Paires (n° de coup, blanc, noir?) pour la liste des coups.
    var numberedMoves: [(number: Int, white: String, black: String?)] {
        stride(from: 0, to: sanLog.count, by: 2).map { index in
            (index / 2 + 1, sanLog[index], index + 1 < sanLog.count ? sanLog[index + 1] : nil)
        }
    }

    // MARK: Interaction utilisateur

    private var canUserAct: Bool {
        outcome == nil && pendingPromotion == nil && !isReviewing
            && game.board.position.sideToMove == userColor
    }

    func selectSquare(_ square: Square) {
        guard canUserAct else { return }
        if let selected = selectedSquare, legalTargetSquares.contains(square) {
            attemptUserMove(from: selected, to: square)
            return
        }
        guard let piece = game.board.position.piece(at: square), piece.color == userColor else {
            clearSelection()
            return
        }
        selectedSquare = square
        legalTargetSquares = targets(for: square)
    }

    /// Destinations d'une pièce — pour le roi s'y ajoutent les cases de SES
    /// tours d'origine : le geste de roque du 960 est « le roi prend sa
    /// tour », comme sur Lichess et dans le dialecte UCI du moteur.
    private func targets(for square: Square) -> [Square] {
        var targets = game.board.legalMoves(forPieceAt: square)
        if let piece = game.board.position.piece(at: square), piece.kind == .king {
            for move in game.legalMoves() {
                if case .castle = move,
                   let rookSquare = Square(String(game.uciFor(move).dropFirst(2))) as Square? {
                    targets.append(rookSquare)
                }
            }
        }
        return targets
    }

    func attemptUserMove(from start: Square, to end: Square) {
        guard canUserAct, start != end,
              game.board.position.piece(at: start)?.color == userColor
        else {
            Haptics.illegal()
            clearSelection()
            return
        }

        // Promotion : demander la pièce AVANT de jouer, comme en mode Jouer.
        if let piece = game.board.position.piece(at: start), piece.kind == .pawn,
           end.notation.hasSuffix(userColor == .white ? "8" : "1"),
           game.board.canMove(pieceAt: start, to: end) {
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

    /// Accès de TEST : joue un coup pour le camp au trait, quel qu'il soit,
    /// sans passer par les gardes d'interaction. La suite de tests pilote les
    /// deux camps — le moteur n'y est jamais démarré.
    func forceMove(uci: String) {
        _ = commit(uci: uci)
    }

    // MARK: Le commit — commun utilisateur/moteur

    @discardableResult
    private func commit(uci: String) -> Bool {
        let previousMover = game.board.position.sideToMove
        let beforeFEN = game.shredderFEN
        let squares = game.displaySquares(forUCI: uci)
        guard let san = game.apply(uci: uci) else { return false }
        // N'IMPORTE QUEL coup — y compris une réponse moteur — invalide
        // l'offre d'annulation d'une reprise : la restreindre au seul coup
        // utilisateur laissait l'offre active pendant qu'un coup moteur se
        // jouait dans la foulée, et `cancelResumeFromReview()` réinjectait
        // alors l'ancienne suite écartée SANS tenir compte de ce coup
        // entretemps commité, désynchronisant les journaux. Trouvé lors de
        // la revue du 25/08/2026.
        clearResumeUndo()
        uciLog.append(uci)
        sanLog.append(san)
        if let squares { displaySquaresLog.append(squares) }
        playSound(for: san)
        hintMoves = []

        let key = game.repetitionKey
        repetitionCounts[key, default: 0] += 1

        if let end = detectOutcome(repetitions: repetitionCounts[key] ?? 1) {
            outcome = end
            clock?.pause()
            Haptics.gameEnded()
            return true
        }

        clock?.startTurn(for: game.board.position.sideToMove, previousMover: previousMover)

        // AVANT la réponse du moteur, pas après — même ordre que
        // ``PlayViewModel/commit(scratch:move:)``. Inversé au premier jet,
        // la réponse du moteur (enfilée sur la MÊME file sérielle) consommait
        // le tour et faisait toujours échouer le garde de fraîcheur de la
        // vérification (`atMoveCount == uciLog.count`) avant même qu'elle
        // s'exécute — un défaut RÉEL, pas un artefact de test : l'alerte
        // gaffe n'aurait presque jamais pu se déclencher en jeu normal.
        // Attrapé par `blunderAlertFiresOnAHangingQueen`.
        if previousMover == userColor {
            checkForBlunderRetroactively(beforeFEN: beforeFEN, afterFEN: game.shredderFEN, atMoveCount: uciLog.count)
        }

        if game.board.position.sideToMove == engineColor {
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

    private func detectOutcome(repetitions: Int) -> GameOutcome? {
        if let end = game.boardEnd {
            switch end {
            case let .checkmate(winner): return GameOutcome(winner: winner, reason: .checkmate)
            case .stalemate: return GameOutcome(winner: nil, reason: .draw(.stalemate))
            case .insufficientMaterial: return GameOutcome(winner: nil, reason: .draw(.insufficientMaterial))
            case .fiftyMoves: return GameOutcome(winner: nil, reason: .draw(.fiftyMoves))
            }
        }
        if repetitions >= 3 { return GameOutcome(winner: nil, reason: .draw(.repetition)) }
        return nil
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
        guard outcome == nil else { return }
        guard await engine.start() else {
            isEngineUnavailable = true
            return
        }
        // LE réglage qui fait la variante : sous `UCI_Chess960`, Stockfish lit
        // les droits Shredder et rend le roque en roi-prend-tour — le dialecte
        // exact de `Chess960Game.apply(uci:)`.
        await engine.send(.setoption(id: "UCI_Chess960", value: "true"))
        for command in settings.strength.setupCommands {
            await engine.send(command)
        }
    }

    private func requestEngineMove() async {
        guard outcome == nil, game.board.position.sideToMove == engineColor else { return }
        isEngineThinking = true
        defer { isEngineThinking = false }

        await engine.synchronize()
        await engine.send(.position(.fen(game.shredderFEN)))

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
            lastEngineEvalCp = cp
            setEval(cp: cp, mate: result.mate, moverIsWhite: mover == .white)
        }
        guard let lan = result.lan, lan != "(none)", outcome == nil, !isReviewing else {
            if outcome == nil, game.boardEnd != nil { outcome = detectOutcome(repetitions: 1) }
            return
        }
        _ = commit(uci: lan)
    }

    /// Défaut corrigé le 25/08 : cette méthode appelait
    /// ``EngineController/computeBestMove(fen:setupCommands:movetimeMs:depth:)``
    /// — l'API à LECTEUR PERMANENT, réservée au Laboratoire (self-play en
    /// continu). Elle démarre `ensureMoveReader()`, qui installe une tâche de
    /// fond consommant `responseStream` POUR TOUJOURS ; ``requestEngineMove``
    /// lit ce même flux À LA MAIN, comme partout ailleurs dans l'app —
    /// `responseStream` est un `AsyncStream` à consommateur UNIQUE. Dès que
    /// la barre d'éval s'affichait une seule fois (au démarrage, si l'utilisateur
    /// joue les blancs), le lecteur permanent restait vivant, et le premier
    /// `synchronize()` du coup moteur suivant heurtait l'assertion qui garde
    /// précisément cette discipline (« deux `next()` concurrents =
    /// fatalError du stdlib ») — silencieusement gelé hors débogueur, en
    /// trappe DANS le débogueur : exactement le signalement du 25/08,
    /// « après le premier coup blanc, l'ordinateur ne joue jamais ».
    ///
    /// Le remède : la MÊME lecture manuelle que ``requestEngineMove`` et que
    /// ``PlayViewModel/updateEvalBar()``, jamais `computeBestMove`.
    private func updateEvalBar() async {
        guard outcome == nil else { return }
        await refreshEvalBar(fen: game.shredderFEN, mover: game.board.position.sideToMove)
    }

    /// Même salve, mais pour la position AFFICHÉE (consultation comprise) —
    /// appelée par ``review(toPly:)``. Séparée de ``updateEvalBar()`` : celle
    /// du direct se tait après une fin de partie (rien à évaluer, le coup
    /// suivant n'existe pas), la consultation doit au contraire fonctionner
    /// PARTICULIÈREMENT après la fin — c'est là qu'on revoit la partie.
    private func refreshDisplayedEvalBar() {
        guard settings.showEvalBar else { return }
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            await self.refreshEvalBar(fen: self.displayedGame.shredderFEN, mover: self.displayedGame.board.position.sideToMove)
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

        // Position obsolète (un coup joué OU une navigation de consultation
        // pendant la recherche courte) : comparée à la position AFFICHÉE,
        // pas seulement la position live — sinon une salve lancée en
        // consultation s'appliquerait à tort après un retour au direct.
        // Même convention que ``requestEngineMove`` : un score de mat sans
        // `cp` n'est pas affiché — comportement PRÉEXISTANT, pas retouché ici.
        guard case let .finished(result) = search, fen == displayedGame.shredderFEN,
              let cp = result.cp
        else { return }
        setEval(cp: cp, mate: result.mate, moverIsWhite: mover == .white)
    }

    /// La barre parle TOUJOURS du point de vue des blancs.
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

    /// Analyse PONCTUELLE et BORNÉE (~1,5 s), pas continue comme
    /// ``PlayViewModel/startHintAnalysis()``. Ce dernier tourne tant que
    /// l'indice reste affiché, ce qui exige toute une machinerie
    /// d'interruption (`isHintAnalyzing`, `hintTask`, `stopHintIfNeeded`,
    /// `interruptHintAnalysisIfNeeded`) pour ne jamais laisser deux
    /// consommateurs se disputer `responseStream` — exactement la classe de
    /// défaut qui a gelé cette variante plus tôt aujourd'hui
    /// (``updateEvalBar()``). Une salve BORNÉE encaisse le même risque sans
    /// cette machinerie : elle passe par la file sérielle comme tout le
    /// reste, se termine d'elle-même, et un résultat qui arrive après que la
    /// position a changé est simplement jeté (garde `hintsWanted` /
    /// `sideToMove` revérifiée après coup) plutôt qu'annulé activement.
    /// Contrepartie assumée : les flèches n'affinent pas leur profondeur en
    /// temps réel, elles apparaissent une fois, au bout d'~1,5 s.
    private static let hintBudgetMs = 1500

    func toggleHint() {
        hintsWanted.toggle()
        if hintsWanted {
            enqueueEngineWork { [weak self] in await self?.startHintAnalysis() }
        } else {
            hintMoves = []
        }
    }

    /// Relance l'indice sur la file sérielle si l'utilisateur l'avait
    /// activé avant le coup qui vient d'être joué — même rôle que
    /// ``PlayViewModel/restartHintAnalysisIfWanted()``.
    private func restartHintAnalysisIfWanted() {
        guard hintsWanted else { return }
        enqueueEngineWork { [weak self] in await self?.startHintAnalysis() }
    }

    private func startHintAnalysis() async {
        guard settings.hintsEnabled, hintsWanted, outcome == nil,
              game.board.position.sideToMove == userColor
        else { return }

        isHintAnalyzing = true
        defer { isHintAnalyzing = false }

        let fen = game.shredderFEN
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

        // Résultat obsolète (position changée, indice redésactivé pendant la
        // salve) : on le jette plutôt que de l'appliquer à l'aveugle.
        guard case let .finished((lanByRank, scoreByRank)) = search,
              hintsWanted, outcome == nil, fen == game.shredderFEN
        else { return }

        hintMoves = HintMoveBuilder.build(lanByRank: lanByRank, scoreByRank: scoreByRank)
            .map(remappedForCastle)
    }

    /// Une flèche d'indice sur un roque parlerait, comme l'UCI moteur, du
    /// roi qui « prend » sa tour — la case d'ARRIVÉE affichée doit être
    /// celle où le roi atterrit VRAIMENT, même correction que
    /// ``displayedLastMove``.
    private func remappedForCastle(_ hint: HintMove) -> HintMove {
        guard let squares = game.displaySquares(forUCI: hint.from.notation + hint.to.notation),
              squares.to != hint.to
        else { return hint }
        return HintMove(rank: hint.rank, from: hint.from, to: squares.to, strength: hint.strength,
                        kind: hint.kind, tint: hint.tint)
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

    /// Passe par la file sérielle plutôt que d'appeler `takeback()`
    /// directement — même raison que ``PlayViewModel/takebackAfterBlunderWarning()``.
    func takebackAfterBlunderWarning() {
        pendingBlunderWarning = nil
        enqueueEngineWork { [weak self] in self?.takeback() }
    }

    /// Même contrat que ``PlayViewModel``'s équivalent privé : score en
    /// centipions ET mat en N éventuel, du point de vue du camp au trait.
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

    // MARK: Consultation & reprise — le pattern du 24/08

    func review(toPly ply: Int) {
        let clamped = max(0, min(ply, uciLog.count))
        guard clamped != uciLog.count else {
            reviewToLive()
            return
        }
        reviewPly = clamped
        reviewGame = replayed(prefix: clamped)
        clearSelection()
        refreshDisplayedEvalBar()
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }

    func reviewToLive() {
        reviewPly = nil
        reviewGame = nil
        clearSelection()
        refreshDisplayedEvalBar()
    }

    var canTakeback: Bool {
        !settings.timeControl.hasClock && !uciLog.isEmpty && outcome == nil && !isEngineThinking
    }

    func takeback() {
        guard canTakeback else { return }
        let whiteJustMoved = game.board.position.sideToMove == .black
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

    /// Mêmes gardes que ``canTakeback`` — voir la revue du 24/08 : sans
    /// `outcome == nil`, annuler ressuscitait une partie abandonnée ; sans
    /// `!isEngineThinking`, le plateau changeait sous la recherche.
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

    /// Reconstruit `game` et le compteur de répétitions depuis les journaux —
    /// LE chemin commun de la reprise de coup et de l'annulation de reprise.
    private func rebuildFromLogs() {
        var rebuilt = Chess960Game(fen: startFEN)!
        var counts: [String: Int] = [rebuilt.repetitionKey: 1]
        var squaresLog: [(from: Square, to: Square)] = []
        for uci in uciLog {
            if let squares = rebuilt.displaySquares(forUCI: uci) { squaresLog.append(squares) }
            _ = rebuilt.apply(uci: uci)
            counts[rebuilt.repetitionKey, default: 0] += 1
        }
        game = rebuilt
        repetitionCounts = counts
        displaySquaresLog = squaresLog
        outcome = nil
        pendingBlunderWarning = nil
        clearSelection()
        currentEvalCp = nil
        currentEvalMate = nil
        hintMoves = []

        if game.board.position.sideToMove == engineColor {
            enqueueEngineWork { [weak self] in await self?.requestEngineMove() }
        } else {
            if settings.showEvalBar {
                enqueueEngineWork { [weak self] in await self?.updateEvalBar() }
            }
            restartHintAnalysisIfWanted()
        }
    }

    private func replayed(prefix count: Int) -> Chess960Game {
        var replayed = Chess960Game(fen: startFEN)!
        for uci in uciLog.prefix(count) { _ = replayed.apply(uci: uci) }
        return replayed
    }

    /// Coup à surligner sur l'échiquier — celui qui mène à la position
    /// affichée, consultation comprise (même convention que
    /// ``PlayViewModel/displayedLastMove``). `piece` n'est utilisé nulle
    /// part pour la surbrillance elle-même (seuls `start`/`end` comptent),
    /// mais `Move` l'exige : on y met la pièce réellement arrivée sur la
    /// case de destination.
    var displayedLastMove: Move? {
        let index = displayedPly
        guard index > 0, index <= displaySquaresLog.count else { return nil }
        let squares = displaySquaresLog[index - 1]
        guard let piece = displayedBoard.position.piece(at: squares.to) else { return nil }
        return Move(result: .move, piece: piece, start: squares.from, end: squares.to)
    }

    // MARK: Export

    var displayedFEN: String { displayedGame.shredderFEN }

    /// PGN de la variante : tags `Variant`/`SetUp`/`FEN`, roque en O-O — le
    /// format que Lichess et les autres logiciels 960 relisent.
    var exportedPGN: String {
        var tags = [
            "[Event \"ChessLab Chess960\"]",
            "[Variant \"Chess960\"]",
            "[SetUp \"1\"]",
            "[FEN \"\(startFEN)\"]",
        ]
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
