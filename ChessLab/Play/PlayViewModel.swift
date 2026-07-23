import ChessKit
import ChessKitEngine
import Foundation
import Observation
import os
import SwiftData
import UIKit

/// Coup en attente de sélection de promotion.
struct PendingPromotion {
    let scratch: Board
    let move: Move
}

/// Avertissement de gaffe **rétroactif** : le coup est déjà joué (le
/// plateau réagit toujours immédiatement au geste de l'utilisateur), on
/// propose seulement de reprendre après coup si l'évaluation s'est
/// nettement dégradée.
struct PendingBlunderWarning {
    enum Severity: Equatable {
        /// Perte d'évaluation en centipions (cas courant).
        case centipawns(Int)
        /// Le coup a laissé passer un mat forcé qu'on avait.
        case missedMate
        /// Le coup concède un mat forcé à l'adversaire.
        case allowsMate
    }
    let severity: Severity

    /// Message prêt à afficher — le cas centipions est borné à ~10 pions
    /// (un mat encodé en ±10 000 cp donnerait sinon « 92 pion(s) »).
    var message: String {
        switch severity {
        case .missedMate:
            "Ce coup laisse passer un mat forcé."
        case .allowsMate:
            "Ce coup permet un mat forcé à l'adversaire."
        case let .centipawns(drop):
            "Ce coup fait perdre environ \(min(drop, 1_000) / 100) pion(s) d'évaluation."
        }
    }
}

/// Orchestre une partie du mode Jouer : état de l'échiquier (``Board``),
/// historique (``Game``), moteur adverse, pendule et aides.
@Observable
@MainActor
final class PlayViewModel {

    // MARK: État d'échecs

    private(set) var board: Board
    private(set) var game: Game
    private(set) var currentIndex: MoveTree.Index
    /// Historique linéaire des coups joués (utilisé pour la liste de coups,
    /// le takeback et l'autosauvegarde).
    private(set) var moveLog: [Move] = []

    // MARK: Rôles

    let settings: PlayGameSettings
    let userColor: Piece.Color
    let engineColor: Piece.Color
    private let modelContext: ModelContext

    // MARK: Moteur

    private var engine: EngineController?
    private(set) var isEngineThinking = false
    private var recentEngineEvalsCp: [Int] = []
    /// Vrai si Stockfish n'a pas démarré (réseau NNUE absent, mémoire…).
    /// Sans cet état, l'échec était totalement silencieux : les commandes
    /// partaient dans le vide, aucun `bestmove` n'arrivait jamais et la
    /// partie restait figée sans le moindre message — la vue affiche
    /// désormais une bannière « Moteur indisponible ».
    private(set) var isEngineUnavailable = false

    /// Vrai le temps d'une tentative de reprise : le bouton « Réessayer »
    /// affiche alors un indicateur, et un second appui ne relance pas un
    /// redémarrage par-dessus le premier.
    private(set) var isRetryingEngine = false

    /// File sérielle pour tout ce qui touche au moteur : garantit qu'une
    /// seule opération (coup du moteur, indice en continu, barre d'éval,
    /// vérification de gaffe) parle au moteur à la fois, sans quoi leurs
    /// flux de réponses UCI se mélangeraient.
    private var engineQueue: Task<Void, Never> = Task {}

    // MARK: Pendule

    private(set) var clock: GameClock?
    /// Vrai si la pendule a été suspendue par un passage en arrière-plan
    /// (et doit donc reprendre au retour au premier plan).
    private var clockPausedForBackground = false

    // MARK: Interaction plateau

    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?
    var hintMoves: [HintMove] = []
    private(set) var isHintAnalyzing = false
    /// Vrai tant que l'utilisateur n'a pas désactivé l'indice : contrairement
    /// à ``isHintAnalyzing`` (recherche moteur en cours), ce drapeau survit
    /// aux coups joués pour permettre de relancer automatiquement l'analyse
    /// une fois le trait revenu à l'utilisateur.
    private(set) var hintsWanted = false
    /// Profondeur de recherche atteinte par l'analyse d'indice en cours (nil
    /// tant qu'aucune info n'est encore arrivée ou que l'indice est arrêté).
    private(set) var hintDepth: Int?
    private var hintTask: Task<Void, Never>?

    // MARK: Barre d'évaluation (optionnelle)

    /// Évaluation courante en centipions du point de vue des BLANCS.
    private(set) var currentEvalCp: Int?
    /// Mat en N (positif = les blancs matent), du point de vue des BLANCS.
    private(set) var currentEvalMate: Int?

    // MARK: Sheets / alertes

    var pendingPromotion: PendingPromotion?
    var pendingBlunderWarning: PendingBlunderWarning?
    var pendingDrawOffer = false
    /// Le moteur ne propose nulle qu'une fois par partie ; sans ce verrou,
    /// une finale égale redéclencherait l'offre à chaque coup après refus.
    private var engineHasOfferedDraw = false
    private(set) var outcome: GameOutcome? {
        didSet {
            guard let outcome, oldValue == nil else { return }
            GameLibraryService.recordVsEngineGame(
                game: game, outcome: outcome,
                userColor: userColor, engineColor: engineColor,
                strength: settings.strength, in: modelContext
            )
            // HORS file, et AVANT `releaseEngine()` : une analyse d'indice
            // tourne en `go infinite` et son maillon de file ne se termine
            // qu'au `stop`. Sans cette interruption préalable, Stockfish
            // continuerait de chercher à pleine puissance derrière l'écran de
            // fin de partie. Concerne les fins posées sans coup joué
            // (abandon, nulle acceptée, chute de drapeau), les seules où
            // l'indice peut encore tourner.
            interruptHintAnalysisIfNeeded()
            releaseEngine()
            announceOutcome(outcome)
        }
    }

    /// Annonce VoiceOver du RÉSULTAT (Lot 4.B). Les coups étaient annoncés,
    /// la fin de partie non : un utilisateur non voyant voyait le moteur
    /// cesser de répondre sans jamais savoir qu'il venait de gagner.
    private func announceOutcome(_ outcome: GameOutcome) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: outcome.summary(userColor: userColor)
        )
    }

    /// Libère le process Stockfish dès la fin de partie, sans attendre la
    /// libération du view model : depuis l'écran de fin, "Analyser cette
    /// partie" EMPILE un nouvel écran par-dessus celui-ci — sans cet arrêt,
    /// deux moteurs coexisteraient (celui-ci, désormais inutile, plus celui
    /// de l'analyse). Passe par
    /// la file sérielle : exécuté après l'opération moteur éventuellement
    /// en cours, jamais pendant. Toute opération enfilée ensuite trouve
    /// `engine == nil` et devient un no-op — aucun besoin moteur ne
    /// subsiste une fois `outcome` posé.
    private func releaseEngine() {
        guard let engine else { return }
        // `engine` mis à nil TOUT DE SUITE : aucune opération enfilée ensuite
        // ne le retrouve, et un second appel est un no-op.
        self.engine = nil
        // Capture FORTE dans une tâche détachée, PAS `[weak self]` : à la
        // sortie d'écran le view model est libéré presque aussitôt, et une
        // capture faible trouvait `self` déjà nil — `stop()` n'était alors
        // JAMAIS appelé, le moteur (78 Mo de réseau NNUE) survivait jusqu'à la
        // libération paresseuse de ChessKitEngine, et ouvrir Analyser dans la
        // foulée faisait coexister deux réseaux, au risque de faire tuer l'app
        // pour dépassement mémoire (Lot 6.A).
        Task { await engine.stop() }
    }

    // MARK: Initialisation

    /// Démarre une nouvelle partie avec les réglages fournis.
    init(settings: PlayGameSettings, modelContext: ModelContext) {
        self.settings = settings
        self.modelContext = modelContext
        let startPosition = settings.startingPosition
        let resolvedColor = settings.resolvedColorChoice.resolved()

        userColor = resolvedColor
        engineColor = resolvedColor.opposite
        board = Board(position: startPosition)
        let newGame = Game(startingWith: startPosition)
        game = newGame
        currentIndex = newGame.startingIndex
        clock = settings.timeControl.hasClock ? GameClock(control: settings.timeControl) : nil

        // Position de départ DÉJÀ terminée (mat/pat) : sans ce calcul, le
        // moteur recevait un `go` sur une position terminée, répondait
        // `bestmove (none)`, et l'écran restait mort — ni coup, ni fin de
        // partie, ni message (seul « Abandonner » répondait encore). Voir
        // ``GameOutcome/ofStartingPosition(_:)`` pour la limite de ChessKit
        // qui rend ce cas invisible via `board.state`.
        //
        // Assigné directement dans le corps de l'init, où les observateurs de
        // propriété ne se déclenchent pas : une partie sans le moindre coup
        // joué n'a rien à faire dans la bibliothèque.
        outcome = GameOutcome.ofStartingPosition(board.position)

        AutosaveStore.clearPlay()
        wireClock()
        enqueueEngineWork { await self.setupEngine() }
    }

    /// Reprend une partie sauvegardée.
    init?(resuming autosave: PlayGameAutosave, modelContext: ModelContext) {
        guard let resolvedColor = Piece.Color(rawValue: autosave.resolvedUserColorRaw) else {
            return nil
        }

        settings = autosave.settings
        self.modelContext = modelContext
        userColor = resolvedColor
        engineColor = resolvedColor.opposite

        let startPosition = autosave.settings.startingPosition
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

        // Un seul LAN inapplicable (sauvegarde tronquée/corrompue, LAN d'une
        // version future) rendrait TOUS les coups suivants faux : mieux vaut
        // déclarer la reprise impossible que restaurer silencieusement une
        // autre partie — que le prochain coup re-persisterait par-dessus.
        // `ResumedGameHost` affiche alors « Reprise impossible ».
        guard replay(lans: autosave.moveLANs) else {
            AutosaveStore.clearPlay()
            return nil
        }

        // La pendule restaurée est à l'ARRÊT : sans ce démarrage, le joueur
        // au trait disposerait d'un temps illimité et non décompté sur son
        // premier coup après reprise — répétable à volonté en relançant
        // l'app à chaque coup difficile. Sans `previousMover` : aucun
        // incrément n'est crédité (le coup n'est pas encore joué).
        if outcome == nil {
            clock?.startTurn(for: board.position.sideToMove)
        }

        enqueueEngineWork { await self.setupEngine() }
        if outcome == nil, board.position.sideToMove == engineColor {
            enqueueEngineWork { await self.requestEngineMove() }
        }
    }

    private func wireClock() {
        clock?.onFlagFall = { [weak self] color in
            self?.handleFlagFall(color)
        }
    }

    /// Chaîne `work` à la suite de toute opération moteur déjà en cours,
    /// pour sérialiser tous les accès à l'unique instance `EngineController`.
    private func enqueueEngineWork(_ work: @escaping () async -> Void) {
        let previous = engineQueue
        engineQueue = Task {
            _ = await previous.value
            await work()
        }
    }

    private func setupEngine() async {
        // Partie déjà terminée (reprise d'une autosauvegarde arrivée en
        // position finale — cas limite) : aucun moteur à démarrer, sinon
        // il tournerait à vide jusqu'à la libération du view model.
        guard outcome == nil else { return }
        guard await startEngine() else { return }

        // `moveLog.isEmpty` : à la reprise d'une autosauvegarde, c'est l'init
        // qui met le coup du moteur en file, pas nous — sans ce garde, il
        // serait demandé deux fois.
        if board.position.sideToMove == engineColor, moveLog.isEmpty {
            await requestEngineMove()
        } else if settings.showEvalBar {
            await updateEvalBar()
        }
    }

    /// Crée une instance, la démarre et lui envoie les réglages de force.
    ///
    /// - returns: `false` en cas d'échec — la bannière est alors levée et
    ///   aucun contrôleur n'est conservé : `Engine.send` ignore silencieusement
    ///   toute commande tant que le moteur ne tourne pas, un contrôleur mort
    ///   donnerait donc un écran d'apparence normale où le moteur ne jouerait
    ///   jamais.
    private func startEngine() async -> Bool {
        let controller = EngineController(type: .stockfish)

        // MultiPV reste à 1 par défaut : les requêtes rapides (gaffe,
        // barre d'éval, coup du moteur) n'en ont pas besoin. Il est monté
        // à 3 ponctuellement pendant l'indice (voir `startHintAnalysis`).
        // `AppSettings` et non `settings` : ce dernier, ici, ce sont les
        // réglages de la PARTIE (force, cadence), pas ceux du moteur — qui
        // ne se règlent plus du tout, ils se déduisent de l'appareil.
        guard await controller.start(
            threads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads),
            hashMB: AppSettings.engineHashMB, multipv: 1
        ) else {
            isEngineUnavailable = true
            await controller.stop()
            return false
        }

        engine = controller
        isEngineUnavailable = false
        await controller.send(.ucinewgame)
        for command in settings.strength.setupCommands {
            await controller.send(command)
        }
        return true
    }

    /// Reprise après panne moteur (bouton « Réessayer » de la bannière).
    ///
    /// Passe par la file moteur comme tout le reste : un redémarrage lancé en
    /// parallèle d'une recherche en cours parlerait à une instance en train
    /// d'être arrêtée.
    func retryEngine() {
        guard !isRetryingEngine else { return }
        isRetryingEngine = true
        enqueueEngineWork { await self.recoverEngine() }
    }

    /// Redémarre l'instance existante, ou en crée une si la panne datait du
    /// démarrage (aucun contrôleur n'est conservé dans ce cas), puis reprend
    /// depuis le FEN courant — c'est `requestEngineMove` qui envoie la
    /// position, il n'y a donc rien à repositionner ici.
    private func recoverEngine() async {
        defer { isRetryingEngine = false }
        guard outcome == nil else { return }

        if let engine {
            // Mêmes réglages qu'au premier démarrage : `restart` sans
            // `coreCount` repartirait sur UN seul thread, et sans `Hash`
            // sur les 16 Mo par défaut — moteur affaibli en silence.
            guard await engine.restart(
                coreCount: EngineController.coreCount(
                    forThreads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads)
                ),
                multipv: 1,
                setupCommands: [.setoption(id: "Hash", value: "\(AppSettings.engineHashMB)")]
                    + settings.strength.setupCommands
            ) else {
                self.engine = nil
                isEngineUnavailable = true
                return
            }
            isEngineUnavailable = false
        } else {
            guard await startEngine() else { return }
        }

        if board.position.sideToMove == engineColor {
            await requestEngineMove()
        } else if settings.showEvalBar {
            await updateEvalBar()
        }
    }

    // MARK: Chien de garde moteur

    private static let watchdogLogger = Logger(subsystem: "ChessLab", category: "engine-watchdog")

    /// Redémarrage D'OFFICE après détection d'un moteur muet (aucune
    /// réponse à l'échéance du chien de garde) — l'équivalent automatique
    /// du bouton « Réessayer », sans attendre l'utilisateur.
    ///
    /// Réémet TOUS les réglages de session : threads (perdus sinon —
    /// `restart` repart sur `coreCount` nil, soit un seul thread), table de
    /// hachage, et force Elo. Un moteur redémarré à pleine puissance quand
    /// la partie est réglée à 1400 Elo jouerait soudain comme un maître.
    private func recoverFromSilentEngine() async -> Bool {
        guard let engine else { return false }
        Self.watchdogLogger.warning("Moteur muet à l'échéance : redémarrage automatique")
        let restarted = await engine.restart(
            coreCount: EngineController.coreCount(
                forThreads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads)
            ),
            multipv: 1,
            setupCommands: [.setoption(id: "Hash", value: "\(AppSettings.engineHashMB)")]
                + settings.strength.setupCommands
        )
        isEngineUnavailable = !restarted
        return restarted
    }

    // MARK: Replay (restauration / takeback)

    /// Rejoue une suite de coups LAN sur l'état vivant.
    ///
    /// - Returns: `false` au PREMIER coup inapplicable — le rejeu s'arrête
    /// là et l'état est à jeter. Sauter le coup fautif et poursuivre (ancien
    /// comportement) appliquait tous les coups suivants à une position
    /// devenue fausse : partie restaurée silencieusement différente de celle
    /// qu'on avait laissée.
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

    private func rebuild(moves: [Move]) {
        // Toute reconstruction (reprise de coup) sort de la consultation :
        // `reviewPly` pourrait sinon pointer au-delà du nouveau `moveLog`.
        reviewToLive()
        let startPosition = settings.startingPosition
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

        if let piece = board.position.piece(at: square), piece.color == userColor {
            selectedSquare = square
            legalTargetSquares = board.legalMoves(forPieceAt: square)
        }
    }

    func clearSelection() {
        selectedSquare = nil
        legalTargetSquares = []
    }

    private var canUserAct: Bool {
        outcome == nil
            && !isEngineThinking
            && pendingPromotion == nil
            && board.position.sideToMove == userColor
    }

    // MARK: Interaction utilisateur — coup (drag & drop ou tap-tap)

    /// Joue immédiatement le coup si légal (aucune attente réseau/moteur
    /// avant que la pièce ne bouge à l'écran). L'alerte gaffe, si activée,
    /// est vérifiée *après coup* de façon non bloquante — voir
    /// ``checkForBlunderRetroactively``.
    ///
    /// - important: Le garde de COULEUR est indispensable ici et ne peut pas
    /// être délégué à ChessKit : `Board.legalMoves`/`canMove` ne consultent
    /// PAS le trait, et `Position.move` le bascule inconditionnellement.
    /// Sans lui, glisser (même par accident) une pièce du moteur jouerait un
    /// coup adverse, puis le moteur répondrait à son propre coup — deux coups
    /// noirs d'affilée, partie définitivement invalide. Le chemin tap-tap est
    /// protégé en amont par ``selectSquare(_:)``, pas le drag & drop.
    func attemptUserMove(from start: Square, to end: Square) {
        guard
            canUserAct, start != end,
            board.position.piece(at: start)?.color == userColor,
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
        hintMoves = []
        hintDepth = nil
        interruptHintAnalysisIfNeeded()

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

    // MARK: Alerte gaffe (rétroactive)

    private func checkForBlunderRetroactively(before: Position, after: Position, atMoveCount: Int) {
        guard settings.blunderAlertEnabled else { return }

        enqueueEngineWork { [weak self] in
            guard let self, let engine = self.engine else { return }
            await self.stopHintIfNeeded()

            let severity = await self.blunderSeverity(before: before, after: after, engine: engine)

            guard
                let severity,
                atMoveCount == self.moveLog.count,  // aucun autre coup joué depuis
                self.outcome == nil,
                self.canTakeback  // inutile de proposer une reprise impossible
            else { return }

            self.pendingBlunderWarning = PendingBlunderWarning(severity: severity)
        }
    }

    func dismissBlunderWarning() {
        pendingBlunderWarning = nil
    }

    /// Passe par la file sérielle plutôt que d'appeler `takeback()`
    /// directement : au moment où l'utilisateur répond à l'alerte, la
    /// riposte du moteur est très probablement déjà en cours de calcul
    /// (sa requête est mise en file juste après la vérification de
    /// gaffe) — un takeback immédiat échouerait silencieusement sur le
    /// garde `!isEngineThinking` de `canTakeback`. Exécuté après la
    /// riposte, `takeback()` retire alors la paire de coups (riposte +
    /// gaffe), exactement comme le bouton "Reprendre" habituel.
    func takebackAfterBlunderWarning() {
        pendingBlunderWarning = nil
        enqueueEngineWork { [weak self] in self?.takeback() }
    }

    /// Classe la gravité d'un coup a posteriori. `before` est du point de
    /// vue de celui qui joue, `after` de celui de l'adversaire (nouveau
    /// trait) — d'où l'inversion de signe. Distingue les cas de mat pour un
    /// message clair (voir ``PendingBlunderWarning``), plutôt qu'un « perte
    /// de 92 pions » absurde issu du mat encodé en ±10 000 cp.
    private func blunderSeverity(
        before: Position, after: Position, engine: EngineController
    ) async -> PendingBlunderWarning.Severity? {
        guard
            let b = await quickScore(fen: before.fen, engine: engine),
            let a = await quickScore(fen: after.fen, engine: engine)
        else { return nil }
        return Self.blunderSeverity(before: b, after: a)
    }

    /// Décision pure, isolée de la recherche moteur pour être testable telle
    /// quelle. `before` est du point de vue de celui qui joue, `after` de
    /// celui de l'adversaire (nouveau trait).
    static func blunderSeverity(
        before b: (cp: Int, mate: Int?), after a: (cp: Int, mate: Int?)
    ) -> PendingBlunderWarning.Severity? {
        if let mateA = a.mate, mateA > 0 {
            // Sauf si l'adversaire avait DÉJÀ un mat forcé avant le coup
            // (`b.mate < 0`, POV de celui qui joue) : aucun coup ne pouvait
            // l'éviter, et l'alerte se redéclenchait alors à CHAQUE coup dans
            // une position perdue avec mat annoncé. Garde symétrique de celui
            // qui existe déjà pour `missedMate` ci-dessous.
            if let mateB = b.mate, mateB < 0 { return nil }
            return .allowsMate // l'adversaire a désormais un mat forcé
        }
        if let mateB = b.mate, mateB > 0 {
            // On AVAIT un mat forcé : s'il tient encore (adversaire au trait
            // en train de se faire mater, mateA < 0), pas d'alerte ; sinon
            // on l'a laissé filer.
            if let mateA = a.mate, mateA < 0 { return nil }
            return .missedMate
        }
        // Cas normal en centipions.
        let drop = b.cp - (-a.cp)
        guard drop >= 200 else { return nil }
        return .centipawns(drop)
    }

    /// Évaluation rapide d'une position : score en centipions ET mat en N
    /// éventuel (du point de vue du camp au trait). Un mat est aussi encodé
    /// en ±10 000 cp pour rester comparable, mais `mate` permet un message
    /// dédié.
    private func quickScore(fen: String, engine: EngineController) async -> (cp: Int, mate: Int?)? {
        await engine.synchronize()
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: 300))

        let outcome = await EngineWatchdog.run(deadlineMs: 300 + EngineWatchdog.graceMs) {
            () -> (cp: Int, mate: Int?)? in
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

        switch outcome {
        case let .finished(score):
            return score
        case .timedOut:
            // Pas d'alerte gaffe cette fois-ci — mais un moteur remis sur
            // pied pour la suite de la partie.
            _ = await recoverFromSilentEngine()
            return nil
        }
    }

    // MARK: Barre d'évaluation

    private func updateEvalBar() async {
        guard settings.showEvalBar, let engine else { return }
        await stopHintIfNeeded()

        let fen = board.position.fen
        let mover = board.position.sideToMove

        await engine.synchronize()
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: 300))

        let outcome = await EngineWatchdog.run(deadlineMs: 300 + EngineWatchdog.graceMs) {
            var cp: Int?
            var mate: Int?

            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    guard (info.multipv ?? 1) == 1 else { break }
                    if let m = info.score?.mate {
                        mate = m
                        cp = nil
                    } else if let c = info.score?.cp {
                        cp = Int(c)
                        mate = nil
                    }
                case .bestmove:
                    guard self.board.position.fen == fen else { return }  // position obsolète
                    if let mate {
                        self.currentEvalMate = mover == .white ? mate : -mate
                        self.currentEvalCp = nil
                    } else {
                        self.currentEvalCp = mover == .white ? cp : cp.map { -$0 }
                        self.currentEvalMate = nil
                    }
                    return
                default:
                    break
                }
            }
        }

        if case .timedOut = outcome {
            _ = await recoverFromSilentEngine()
        }
    }

    // MARK: Indice (analyse en continu)

    /// Démarre ou arrête l'analyse continue pour l'indice. Tant qu'elle
    /// tourne, les flèches (jusqu'à 3, classées) se mettent à jour au fur
    /// et à mesure que le moteur creuse plus profond.
    func toggleHint() {
        if hintsWanted {
            hintsWanted = false
            hintMoves = []
            hintDepth = nil
            interruptHintAnalysisIfNeeded()
        } else {
            hintsWanted = true
            startHintAnalysis()
        }
    }

    private func startHintAnalysis() {
        guard
            settings.hintsEnabled, hintsWanted, !isEngineThinking,
            board.position.sideToMove == userColor, outcome == nil
        else {
            return
        }

        isHintAnalyzing = true
        hintMoves = []
        hintDepth = nil

        enqueueEngineWork { [weak self] in
            guard let self, let engine = self.engine else { return }
            // L'analyse a pu être annulée (coup joué, indice re-basculé…)
            // avant même que ce maillon de la file ne s'exécute : dans ce
            // cas, ne surtout pas lancer un `go infinite` que plus personne
            // n'arrêterait.
            guard self.isHintAnalyzing else { return }

            let task = Task {
                await engine.synchronize()
                await engine.send(.setoption(id: "MultiPV", value: "3"))
                await engine.send(.position(.fen(self.board.position.fen)))
                // Bornée en PROFONDEUR plutôt que `go infinite` (cohérence avec
                // l'analyse en continu) : les flèches d'indice n'évoluent plus à
                // l'œil au-delà, et le moteur passe en idle au lieu de tourner
                // les cœurs tant que l'indice reste affiché. La boucle traite
                // déjà `.bestmove` comme fin ; `await task.value` (plus bas)
                // retourne alors à la convergence, ce qui libère la file — la
                // prochaine opération n'a plus besoin de stopper un indice déjà
                // terminé (`stopHintIfNeeded` gère une `hintTask` finie).
                await engine.send(.go(
                    depth: ThermalMonitor.shared.liveDepth(preferred: AppSettings.liveAnalysisDepth),
                    movetime: 8000
                ))

                // Si l'arrêt a été demandé pendant la mise en place, le
                // `stop` de `stopHintIfNeeded` est peut-être parti AVANT le
                // `go` ci-dessus (tâche concurrente) et n'a alors rien
                // stoppé : on le renvoie d'ici, où l'ordre est garanti.
                if !self.isHintAnalyzing {
                    await engine.send(.stop)
                }

                var lanByRank: [Int: String] = [:]
                var scoreByRank: [Int: Double] = [:]

                for await response in await engine.responseStream {
                    switch response {
                    case let .info(info):
                        // L'arrêt (coup joué, indice re-basculé…) a pu être
                        // demandé pendant qu'on attendait la prochaine
                        // réponse : sans ce garde-fou, des `info` déjà
                        // bufferisés par le moteur continueraient de
                        // repeupler `hintMoves` juste après qu'on les a
                        // effacés (flèches qui "reviennent" furtivement
                        // avant de disparaître pour de bon). On continue
                        // néanmoins de VIDER le flux jusqu'au `bestmove` qui
                        // clôt la session — l'abandonner en cours de route
                        // le laisserait traîner pour être lu par erreur par
                        // la prochaine commande moteur (ex. le coup suivant
                        // du moteur, qui le prendrait à tort pour le sien).
                        guard self.isHintAnalyzing else { break }
                        if let depth = info.depth {
                            self.hintDepth = depth
                        }
                        if let rank = info.multipv, let firstMove = info.pv?.first {
                            lanByRank[rank] = firstMove
                            if let mate = info.score?.mate {
                                scoreByRank[rank] = mate > 0 ? 10_000 - Double(mate) : -10_000 - Double(mate)
                            } else if let cp = info.score?.cp {
                                scoreByRank[rank] = cp
                            }
                            self.hintMoves = HintMoveBuilder.build(lanByRank: lanByRank, scoreByRank: scoreByRank)
                        }
                    case .bestmove:
                        self.isHintAnalyzing = false
                        return
                    default:
                        break
                    }
                }
                self.isHintAnalyzing = false
            }

            self.hintTask = task
            // La file sérielle attend la fin de l'analyse (stoppée via
            // `stopHintIfNeeded`) avant de traiter l'opération suivante.
            await task.value
        }
    }

    /// Arrête l'analyse d'indice en cours, si besoin, et attend que le
    /// moteur ait bien renvoyé son `bestmove` de clôture avant de rendre
    /// la main — appelé en tête de toute autre opération moteur.
    ///
    /// - important: Cette fonction peut être appelée par PLUSIEURS chemins
    /// concurrents pour un même arrêt (la tâche détachée d'
    /// ``interruptHintAnalysisIfNeeded()`` et l'appel défensif en tête de
    /// ``requestEngineMove()``/``updateEvalBar()``/vérification de gaffe).
    /// `engine.responseStream` est un flux à **consommateur unique** : si
    /// l'un de ces appels renvoyait tôt dès que `isHintAnalyzing` était
    /// déjà à `false` (mis par l'appel concurrent) SANS attendre la fin de
    /// `hintTask`, il se remettait aussitôt à lire le flux pendant que la
    /// boucle d'indice l'écoutait encore pour son propre `bestmove` de
    /// clôture — les deux se disputaient alors les réponses, et le
    /// `bestmove` du VRAI coup suivant pouvait être volé par la boucle
    /// d'indice (coup du moteur silencieusement perdu). Chaque appelant
    /// doit donc attendre `hintTask` tant qu'il existe, que ce soit lui ou
    /// un autre appelant qui ait envoyé le `stop`.
    private func stopHintIfNeeded() async {
        if isHintAnalyzing {
            isHintAnalyzing = false
            await engine?.send(.stop)
        }
        guard let task = hintTask else { return }
        // Attente elle-même bornée : le `bestmove` de clôture vient du
        // moteur, et un moteur planté ne l'enverra jamais — cette attente
        // figeait alors la file entière, coup du moteur compris. À
        // l'échéance : on annule la boucle de lecture (l'itération d'un
        // AsyncStream se termine à l'annulation) et on redémarre l'instance.
        let outcome = await EngineWatchdog.run(deadlineMs: EngineWatchdog.graceMs) { await task.value }
        if case .timedOut = outcome {
            task.cancel()
            await task.value
            _ = await recoverFromSilentEngine()
        }
        hintTask = nil
        await engine?.send(.setoption(id: "MultiPV", value: "1"))
    }

    /// Interrompt une analyse d'indice en cours sans passer par la file
    /// sérielle (`enqueueEngineWork`).
    ///
    /// - important: Le maillon "indice" de la file reste occupé (il
    /// attend `task.value`) tant que le moteur n'a pas répondu à `stop` —
    /// si on demandait cet arrêt *via* la file, la commande resterait
    /// coincée derrière ce même maillon qu'elle doit débloquer
    /// (interblocage). `EngineController` étant un acteur, cet envoi
    /// direct est sûr même en dehors de la file. Tout appelant "en file"
    /// (coup du moteur, alerte gaffe, éval) rappelle de toute façon
    /// `stopHintIfNeeded()` en tête de son propre traitement, qui devient
    /// alors un no-op une fois l'arrêt déjà effectué ici.
    private func interruptHintAnalysisIfNeeded() {
        guard isHintAnalyzing else { return }
        Task { [weak self] in await self?.stopHintIfNeeded() }
    }

    /// À appeler quand l'écran de jeu disparaît (retour, fin de partie…) :
    /// sans cela, une analyse d'indice infinie survivrait à l'écran — la
    /// tâche retient le view model, qui n'est donc jamais libéré, et
    /// Stockfish continuerait de chercher indéfiniment en arrière-plan.
    func handleViewDisappear() {
        interruptHintAnalysisIfNeeded()
        // Libère Stockfish en quittant l'écran, y compris une partie NON
        // terminée (bouton retour) : sans ça le moteur survivait jusqu'à la
        // libération du view model, et enchaîner sur Analyser faisait coexister
        // deux réseaux NNUE de 78 Mo — l'app pouvait être tuée pour dépassement
        // mémoire (Lot 6.A). Le cas « partie terminée » était déjà couvert par
        // le `didSet` d'`outcome` ; celui-ci manquait. Idempotent.
        releaseEngine()
    }

    // MARK: Cycle de vie de l'app (pendule en arrière-plan)

    /// Suspend la pendule quand l'app quitte le premier plan : contre un
    /// moteur local, perdre au temps parce qu'on a répondu à un message
    /// serait absurde. L'état est mémorisé pour ne reprendre au retour
    /// que si la pendule tournait effectivement.
    func handleAppBackgrounded() {
        guard let clock, outcome == nil, clock.isRunning else { return }
        clock.pause()
        clockPausedForBackground = true
    }

    func handleAppForegrounded() {
        guard clockPausedForBackground else { return }
        clockPausedForBackground = false
        guard outcome == nil else { return }
        // Reprise sans `previousMover` : aucun incrément n'est crédité.
        clock?.startTurn(for: board.position.sideToMove)
    }

    // MARK: Finalisation d'un coup

    /// Annonce VoiceOver du coup joué — un utilisateur non voyant ne voit
    /// pas la pièce bouger, il faut lui dire ce que l'adversaire a joué.
    private func announceMove(_ move: Move) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let who = move.piece.color == engineColor ? "Stockfish" : "Vous"
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(who) : \(MoveNarration.describe(san: move.san))"
        )
    }

    private func commit(scratch: Board, move: Move) {
        let previousMover = board.position.sideToMove
        let positionBeforeMove = board.position
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
            AutosaveStore.clearPlay()
            return
        }

        clock?.startTurn(for: board.position.sideToMove, previousMover: previousMover)

        if move.piece.color == userColor {
            checkForBlunderRetroactively(
                before: positionBeforeMove,
                after: scratch.position,
                atMoveCount: moveLog.count
            )
        }

        if board.position.sideToMove == engineColor {
            enqueueEngineWork { [weak self] in await self?.requestEngineMove() }
        } else {
            if settings.showEvalBar {
                enqueueEngineWork { [weak self] in await self?.updateEvalBar() }
            }
            restartHintAnalysisIfWanted()
        }
    }

    /// Relance l'indice sur la file sérielle si l'utilisateur l'avait
    /// activé avant le coup qui vient d'être joué.
    ///
    /// - important: Doit passer par ``enqueueEngineWork`` et non appeler
    /// ``startHintAnalysis()`` directement : quand ce coup vient du moteur,
    /// on est encore dans la pile synchrone de `requestEngineMove()`, donc
    /// `isEngineThinking` n'est remis à `false` (son `defer`) qu'une fois
    /// cette fonction revenue. Appeler `startHintAnalysis()` ici même
    /// verrait donc `isEngineThinking` toujours vrai et échouerait à tort ;
    /// passer par la file garantit qu'on ne s'exécute qu'une fois ce
    /// nettoyage effectué.
    private func restartHintAnalysisIfWanted() {
        guard hintsWanted else { return }
        enqueueEngineWork { [weak self] in self?.startHintAnalysis() }
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

    /// Sur une position de DÉPART (aucun coup joué : reprise d'une
    /// sauvegarde vide, reprise de tous les coups), `board.state` ne voit pas
    /// un mat/pat du camp au trait — d'où le passage par
    /// ``GameOutcome/ofStartingPosition(_:)``. Dès qu'un coup a été joué,
    /// `board.state` est complet et fait autorité.
    private func outcomeIfGameEnded() -> GameOutcome? {
        moveLog.isEmpty
            ? GameOutcome.ofStartingPosition(board.position)
            : GameOutcome.fromBoardState(board.state)
    }

    // MARK: Livre d'ouvertures

    /// Coup de livre pour la position courante, en LAN (même format que
    /// ``applyEngineMove(lan:)`` attend), ou `nil` s'il faut basculer sur
    /// le calcul normal (livre désactivé, position personnalisée, ou
    /// position sortie de l'arbre connu).
    private func bookMoveIfAvailable() -> String? {
        guard settings.bookEnabled, settings.startFEN == nil else { return nil }
        guard let san = OpeningBookEngine.pickNextMove(
            book: OpeningBookLoader.standard,
            sanPath: moveLog.map(\.san),
            width: settings.bookWidth
        ) else { return nil }
        guard let move = Move(san: san, position: board.position) else { return nil }
        return move.lan
    }

    // MARK: Coup moteur

    private func requestEngineMove() async {
        // Le trait peut avoir changé entre la mise en file et l'exécution
        // (ex. reprise de coup pendant la vérification de gaffe) : sans ce
        // garde-fou, le moteur jouerait un coup pour le camp de l'utilisateur.
        guard let engine, outcome == nil, board.position.sideToMove == engineColor else { return }
        await stopHintIfNeeded()

        isEngineThinking = true
        defer { isEngineThinking = false }

        if let bookLAN = bookMoveIfAvailable() {
            // Même délai aléatoire de rythme naturel qu'un coup calculé.
            try? await Task.sleep(nanoseconds: naturalMoveDelayNanos())
            guard outcome == nil else { return }
            applyEngineMove(lan: bookLAN)
            return
        }

        let mover = board.position.sideToMove

        // Recherche sous chien de garde : un moteur planté ne rend jamais
        // son `bestmove`, et cette attente figeait la partie pour toujours
        // (« Stockfish réfléchit » sans fin). À l'échéance : redémarrage
        // automatique de l'instance, puis UNE seconde chance — deux
        // mutismes d'affilée lèvent la bannière « Moteur indisponible ».
        var search = await performMoveSearch(engine: engine)
        if case .timedOut = search {
            guard await recoverFromSilentEngine() else { return }
            search = await performMoveSearch(engine: engine)
        }
        guard case let .finished(result) = search else {
            isEngineUnavailable = true
            return
        }
        let (searchedLAN, finalScoreCp, finalScoreMate) = result

        // Petit délai aléatoire pour un rythme plus naturel.
        try? await Task.sleep(nanoseconds: naturalMoveDelayNanos())

        guard let bestMoveLAN = searchedLAN, outcome == nil else { return }

        if let finalScoreCp {
            recentEngineEvalsCp.append(finalScoreCp)
            if recentEngineEvalsCp.count > 6 { recentEngineEvalsCp.removeFirst() }

            // Barre d'éval : un mat forcé s'affiche "M n", pas "+100.0".
            let moverIsWhite = mover == .white
            if let finalScoreMate {
                currentEvalMate = moverIsWhite ? finalScoreMate : -finalScoreMate
                currentEvalCp = nil
            } else {
                currentEvalCp = moverIsWhite ? finalScoreCp : -finalScoreCp
                currentEvalMate = nil
            }
        }

        applyEngineMove(lan: bestMoveLAN)
        if outcome == nil { maybeEngineResignsOrOffersDraw() }
    }

    /// Une recherche de coup complète — barrière, position, `go`, lecture
    /// jusqu'au `bestmove` — bornée par le chien de garde. Le budget suit
    /// le mode de recherche : `movetime` demandé + marge, ou une borne
    /// large pour les recherches à profondeur fixe (rapides par nature :
    /// si elles dépassent ça, le moteur ne répond plus).
    private func performMoveSearch(
        engine: EngineController
    ) async -> EngineWatchdogOutcome<(lan: String?, cp: Int?, mate: Int?)> {
        await engine.synchronize()
        await engine.send(.position(.fen(board.position.fen)))

        let budgetMs: Int
        if let depth = settings.strength.maxDepth {
            await engine.send(.go(depth: depth))
            budgetMs = 15_000
        } else {
            let movetime = computeMovetime(for: board.position.sideToMove)
            await engine.send(.go(movetime: movetime))
            budgetMs = movetime + EngineWatchdog.graceMs
        }

        return await EngineWatchdog.run(deadlineMs: budgetMs) {
            var bestMoveLAN: String?
            var finalScoreCp: Int?
            var finalScoreMate: Int?

            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    if (info.multipv ?? 1) == 1, let value = EngineScore.moverCentipawns(info) {
                        finalScoreCp = value
                        finalScoreMate = EngineScore.mateInMoves(info)
                    }
                case let .bestmove(move, _):
                    bestMoveLAN = move
                default:
                    break
                }
                if bestMoveLAN != nil { break }
            }
            return (lan: bestMoveLAN, cp: finalScoreCp, mate: finalScoreMate)
        }
    }

    /// Applique le coup rendu par le moteur.
    ///
    /// - important: Tout coup inapplicable — au premier chef `bestmove
    /// (none)`, que Stockfish renvoie sur une position terminée et que
    /// `EngineResponseParser` transmet tel quel — était auparavant un no-op
    /// SILENCIEUX : ni coup, ni fin de partie, ni message, écran figé. On
    /// conclut désormais la partie sur l'état réel du plateau.
    private func applyEngineMove(lan: String) {
        guard lan.count >= 4, lan != "(none)" else {
            endGameIfPositionIsTerminal()
            return
        }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))

        var scratch = board
        guard let move = scratch.move(pieceAt: start, to: end) else {
            endGameIfPositionIsTerminal()
            return
        }
        var finalMove = move

        if case .promotion = scratch.state {
            let kind: Piece.Kind = lan.count == 5
                ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                : .queen
            finalMove = scratch.completePromotion(of: move, to: kind)
        }

        commit(scratch: scratch, move: finalMove)
    }

    /// Pose la fin de partie si la position courante est réellement terminée
    /// (filet de sécurité quand le moteur ne rend aucun coup jouable) ;
    /// no-op sinon — mieux vaut l'ancien statu quo qu'une fin inventée.
    private func endGameIfPositionIsTerminal() {
        guard outcome == nil, let end = outcomeIfGameEnded() else { return }
        outcome = end
        clock?.pause()
        Haptics.gameEnded()
        AutosaveStore.clearPlay()
    }

    /// Petit délai « rythme naturel » avant que le moteur ne joue —
    /// PLAFONNÉ par la pendule : en cadence rapide, un délai cosmétique fixe
    /// grignotait le temps du moteur (à 1+0, ~la moitié). Supprimé sous
    /// 30 s restantes (zeitnot), sinon borné à ~2 % du temps restant.
    private func naturalMoveDelayNanos() -> UInt64 {
        let maxSeconds: Double
        if let clock, clock.control.hasClock {
            let remaining = clock.remaining(for: engineColor)
            if remaining < 30 { return 0 }
            maxSeconds = min(0.7, remaining * 0.02)
        } else {
            maxSeconds = 0.7
        }
        guard maxSeconds > 0.1 else { return 0 }
        let lower = min(0.25, maxSeconds)
        return UInt64(Double.random(in: lower...maxSeconds) * 1_000_000_000)
    }

    private func computeMovetime(for mover: Piece.Color) -> Int {
        Int(Double(baseMovetime(for: mover)) * ThermalMonitor.shared.movetimeFactor)
    }

    /// Budget de réflexion hors considération thermique.
    private func baseMovetime(for mover: Piece.Color) -> Int {
        guard let clock, clock.control.hasClock else { return 900 }
        let remaining = clock.remaining(for: mover)
        let increment = Double(clock.control.incrementSeconds)
        // Budget proportionnel au temps restant (≈1/30e) + une part de
        // l'incrément, borné entre 150 ms et 30 s (jamais plus du quart du
        // temps restant, pour ne jamais flagger sur un coup).
        let base = remaining / 30 + increment * 0.8
        let minimum = 0.15
        let maximum = min(30.0, remaining * 0.25)
        let allocated = min(max(base, minimum), maximum)
        return Int(allocated * 1000)
    }

    /// Heuristique simplifiée : le moteur abandonne s'il s'estime nettement
    /// perdant sur plusieurs coups d'affilée, ou propose nulle si l'éval
    /// reste proche de zéro en finale avec peu de matériel.
    private func maybeEngineResignsOrOffersDraw() {
        let last3 = recentEngineEvalsCp.suffix(3)
        if settings.engineResignationEnabled, last3.count == 3, last3.allSatisfy({ $0 < -800 }) {
            outcome = GameOutcome(winner: userColor, reason: .resignation)
            clock?.pause()
            Haptics.gameEnded()
            AutosaveStore.clearPlay()
            return
        }

        let last6 = recentEngineEvalsCp.suffix(6)
        if !engineHasOfferedDraw, last6.count == 6, last6.allSatisfy({ abs($0) < 30 }), board.position.pieces.count <= 12 {
            engineHasOfferedDraw = true
            pendingDrawOffer = true
        }
    }

    // MARK: Actions utilisateur

    var canTakeback: Bool {
        !settings.timeControl.hasClock && !moveLog.isEmpty && outcome == nil && !isEngineThinking
    }

    func takeback() {
        guard canTakeback, let last = moveLog.last else { return }
        let count = (last.piece.color == engineColor && moveLog.count >= 2) ? 2 : 1
        performTakeback(keeping: moveLog.count - count)
    }

    /// Reprend plusieurs coups d'un coup : ramène la partie à l'état
    /// juste après le coup d'index `moveIndex` (0-based) de
    /// ``sanMoveList``/`moveLog`. `moveIndex == -1` revient à la position
    /// de départ. Nécessite ``PlayGameSettings/multiMoveTakebackEnabled``
    /// — appelé depuis un tap sur un coup antérieur dans la liste.
    func takeback(toMoveIndex moveIndex: Int) {
        guard settings.multiMoveTakebackEnabled, canTakeback else { return }
        guard moveIndex >= -1, moveIndex < moveLog.count - 1 else { return }
        performTakeback(keeping: moveIndex + 1)
    }

    /// Reconstruit la partie en ne gardant que les `count` premiers coups
    /// de `moveLog`, puis relance ce qu'il faut côté moteur — logique
    /// commune à ``takeback()`` (un coup) et ``takeback(toMoveIndex:)``
    /// (plusieurs coups d'un coup).
    private func performTakeback(keeping count: Int) {
        rebuild(moves: Array(moveLog.prefix(count)))
        hintMoves = []
        hintDepth = nil
        interruptHintAnalysisIfNeeded()
        clearSelection()
        persistAutosave()

        if outcome == nil, board.position.sideToMove == engineColor {
            // Cas "reprendre le tout premier coup du moteur" (l'utilisateur
            // joue les noirs) : c'est de nouveau au moteur de jouer, il faut
            // le relancer sinon la partie reste figée.
            enqueueEngineWork { [weak self] in await self?.requestEngineMove() }
        } else {
            if settings.showEvalBar {
                enqueueEngineWork { [weak self] in await self?.updateEvalBar() }
            }
            restartHintAnalysisIfWanted()
        }
    }

    // MARK: Consultation (navigation dans la partie)

    /// Demi-coup actuellement consulté (0 = position de départ,
    /// `moveLog.count` = position vivante). `nil` = on suit le direct. La
    /// consultation est en LECTURE SEULE : le moteur, la pendule et
    /// l'autosauvegarde continuent de vivre sur l'état réel.
    private(set) var reviewPly: Int?
    /// Plateau figé de la position consultée, recalculé à chaque navigation
    /// (jamais dans `body`).
    private var reviewBoard: Board?

    var isReviewing: Bool { reviewPly != nil }
    /// Plateau à AFFICHER (position consultée si en consultation, sinon vivant).
    var displayedBoard: Board { reviewBoard ?? board }
    var displayedLastMove: Move? {
        guard let reviewPly else { return lastMove }
        return reviewPly > 0 ? moveLog[reviewPly - 1] : nil
    }
    var totalPlies: Int { moveLog.count }
    var displayedPly: Int { reviewPly ?? moveLog.count }

    /// Vrai si on peut reprendre la partie depuis la position consultée :
    /// mêmes garde-fous que la reprise de coup (sans pendule, moteur au
    /// repos, partie en cours) et pas déjà sur le dernier coup.
    var canResumeFromReview: Bool {
        guard let reviewPly else { return false }
        return !settings.timeControl.hasClock && outcome == nil && !isEngineThinking && reviewPly < moveLog.count
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
        hintMoves = []
    }

    func reviewPrevious() { review(toPly: displayedPly - 1) }
    func reviewNext() { review(toPly: displayedPly + 1) }
    func reviewToStart() { review(toPly: 0) }

    func reviewToLive() {
        reviewPly = nil
        reviewBoard = nil
        clearSelection()
    }

    /// Reprend la partie depuis la position consultée : ne garde que les
    /// `reviewPly` premiers coups (réutilise `performTakeback`, qui gère
    /// relance moteur / barre d'éval / indice / autosave).
    func resumeFromReview() {
        guard let reviewPly, canResumeFromReview else { return }
        let keep = reviewPly
        reviewToLive()
        performTakeback(keeping: keep)
    }

    /// Rejoue les `plies` premiers coups de `moveLog` sur un plateau neuf
    /// (pur, ne mute pas l'état vivant) — même mécanique de rejeu que
    /// ``rebuild(moves:)``.
    private func boardAfter(plies: Int) -> Board {
        var replayBoard = Board(position: settings.startingPosition)
        for move in moveLog.prefix(plies) {
            guard let made = replayBoard.move(pieceAt: move.start, to: move.end) else { continue }
            if case .promotion = replayBoard.state, let promoted = move.promotedPiece {
                _ = replayBoard.completePromotion(of: made, to: promoted.kind)
            }
        }
        return replayBoard
    }

    func userResigns() {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: engineColor, reason: .resignation)
        clock?.pause()
        Haptics.gameEnded()
        AutosaveStore.clearPlay()
    }

    func acceptDrawOffer() {
        guard outcome == nil else { return }
        pendingDrawOffer = false
        outcome = GameOutcome(winner: nil, reason: .drawByAgreement)
        clock?.pause()
        Haptics.gameEnded()
        AutosaveStore.clearPlay()
    }

    /// Signalé brièvement quand le moteur refuse une nulle proposée par
    /// l'utilisateur (remis à zéro par la vue après affichage).
    var drawOfferDeclinedByEngine = false

    /// L'utilisateur propose nulle au moteur. Accepté si le moteur ne se
    /// voit pas mieux qu'une quasi-égalité sur son dernier coup
    /// (|éval| ≤ 50 cp, `recentEngineEvalsCp` étant du point de vue du
    /// moteur) ; refusé sinon, ou s'il n'a pas encore joué (pas d'éval).
    func offerDrawToEngine() {
        guard outcome == nil, !isEngineThinking else { return }
        guard let lastEval = recentEngineEvalsCp.last, abs(lastEval) <= 50 else {
            drawOfferDeclinedByEngine = true
            return
        }
        outcome = GameOutcome(winner: nil, reason: .drawByAgreement)
        clock?.pause()
        Haptics.gameEnded()
        AutosaveStore.clearPlay()
    }

    func declineDrawOffer() {
        pendingDrawOffer = false
    }

    private func handleFlagFall(_ color: Piece.Color) {
        guard outcome == nil else { return }
        outcome = GameOutcome(winner: color.opposite, reason: .timeout)
        Haptics.gameEnded()
        AutosaveStore.clearPlay()
    }

    // MARK: Autosauvegarde

    private func persistAutosave() {
        guard outcome == nil else {
            AutosaveStore.clearPlay()
            return
        }

        let record = PlayGameAutosave(
            settings: settings,
            resolvedUserColorRaw: userColor.rawValue,
            moveLANs: moveLog.map(\.lan),
            // `remaining(for:)` PRÉCIS et non `whiteRemaining` publié : la
            // valeur publiée n'avance qu'au pas d'affichage (jusqu'à 1 s de
            // retard) — c'est le contrat documenté de `GameClock`, qui
            // réserve les temps précis à la logique et à l'autosauvegarde.
            whiteRemaining: clock?.remaining(for: .white),
            blackRemaining: clock?.remaining(for: .black),
            savedAt: Date()
        )
        AutosaveStore.savePlay(record)
    }

    /// Coups joués, en SAN, pour la liste de coups.
    /// Pièces capturées de part et d'autre + différentiel de matériel,
    /// dérivés de l'état courant (donc automatiquement corrects après une
    /// reprise de coup).
    var capturedMaterial: CapturedMaterial {
        CapturedMaterial.from(moveLog: moveLog, board: board)
    }

    var sanMoveList: [String] {
        moveLog.map(\.san)
    }
}
