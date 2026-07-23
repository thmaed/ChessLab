import ChessKit
import ChessKitEngine
import Foundation
import Observation
import os
import SwiftData

/// Source à partir de laquelle une session d'analyse démarre.
enum AnalysisSource: Hashable {
    case pgn(String)
    case fen(String)
    case blank
}

/// Une ligne de la liste de coups affichée, reconstruite depuis
/// `game.moves.pgnRepresentation` — `depth` indique le niveau
/// d'indentation (0 = ligne principale, > 0 = variante imbriquée).
struct MoveListRow: Identifiable, Equatable {
    let id: MoveTree.Index
    let depth: Int
    let numberLabel: String?
    let san: String
    let assessmentSuffix: String
    let assessment: Move.Assessment

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.san == rhs.san && lhs.assessmentSuffix == rhs.assessmentSuffix
    }
}

/// Orchestre une session d'analyse : navigation dans l'arbre réel de
/// ``ChessKit/Game`` (variantes incluses), analyse moteur en continu de
/// la position affichée, et classification de fond de la ligne
/// principale par perte de probabilité de gain.
@Observable
@MainActor
final class AnalysisViewModel {

    // MARK: État d'échecs

    private(set) var game: Game
    private(set) var currentIndex: MoveTree.Index
    private(set) var board: Board

    /// Revue d'une partie TERMINÉE (PGN avec des coups) vs analyse d'une
    /// POSITION isolée (FEN, plateau vierge). Les flèches en dépendent : en
    /// revue on affiche le meilleur coup en VERT depuis la classification déjà
    /// calculée (pas de recalcul en naviguant) ; sur une position on garde
    /// l'analyse live et ses flèches grises. Les menaces (rouge) restent dans
    /// les deux cas.
    let isGameReview: Bool

    // MARK: Interaction plateau

    var selectedSquare: Square?
    var legalTargetSquares: [Square] = []
    private(set) var lastMove: Move?
    var pendingPromotion: PendingPromotion?

    // MARK: Moteur — analyse en continu de la position affichée

    private var engine: EngineController?
    /// Vrai si Stockfish n'a pas démarré — voir
    /// ``PlayViewModel/isEngineUnavailable``.
    private(set) var isEngineUnavailable = false
    /// Vrai le temps d'une tentative de reprise — voir
    /// ``PlayViewModel/isRetryingEngine``.
    private(set) var isRetryingEngine = false
    private(set) var isLiveAnalyzing = false
    /// Toutes les lignes rendues par le moteur pour la position affichée
    /// (jusqu'à 3). Ce que l'écran montre en dérive — voir ``displayedArrows``.
    var hintMoves: [HintMove] = []

    /// Ce que les flèches montrent. Trois flèches en permanence, c'était la
    /// solution affichée en continu : illisible, et pédagogiquement à
    /// l'envers puisque plus rien n'invite à chercher. Le défaut ne montre
    /// donc QUE le meilleur coup.
    var arrowMode: ArrowMode {
        get { AppSettings.shared.analysisArrowMode }
        set { AppSettings.shared.analysisArrowMode = newValue }
    }

    /// Les flèches réellement affichées.
    ///
    /// Sémantique explicite, parce que c'est là que l'écran perdait son
    /// lecteur : une flèche verte dit « ce que le camp au trait peut jouer
    /// ICI », une flèche rouge « ce que l'adversaire menace si vous passez ».
    /// Après une erreur, la flèche verte porte donc sur le coup de l'ADVERSAIRE
    /// — d'où l'ajout de la flèche rétrospective, qui montre ce qu'il aurait
    /// fallu jouer à la place du coup fautif.
    var displayedArrows: [HintMove] {
        guard arrowMode != .off else { return [] }

        // REVUE d'une partie : flèches VERTES lues dans la classification déjà
        // calculée (aucun recalcul en naviguant), plus la menace rouge. Pas de
        // flèches grises live — elles ne servent qu'à explorer une position.
        if isGameReview {
            return reviewArrows + [threatMove].compactMap(\.self)
        }

        // ANALYSE d'une position : flèches grises de l'analyse en continu.
        var arrows: [HintMove]
        switch arrowMode {
        case .off: arrows = []
        case .best: arrows = Array(hintMoves.prefix(1))
        case .topThree: arrows = hintMoves
        }
        arrows += [threatMove].compactMap(\.self)
        arrows += [betterMoveArrow].compactMap(\.self)
        return arrows
    }

    /// Flèches vertes de REVUE. Après une faute, la rétrospective (« il fallait
    /// jouer ça ») prime — c'est le point d'apprentissage. Sinon, le meilleur
    /// coup de la position affichée, plus un 2e vert de taille voisine quand un
    /// autre coup est presque aussi bon (« deux coups qui se valent »). Tout est
    /// lu dans ``evalCache`` : rien n'est recalculé en naviguant.
    private var reviewArrows: [HintMove] {
        if let better = betterMoveArrow { return [better] }
        guard let cached = evalCache[currentIndex], let lan = cached.bestLan, lan.count >= 4 else {
            return []
        }
        var arrows = [arrow(fromLan: lan, rank: 1, strength: 1)].compactMap(\.self)
        // 2e flèche : en mode « Trois », dès qu'un 2e coup existe ; en mode
        // « Meilleur », seulement s'il est PROCHE (≤ 4 pts de %), et alors de
        // taille voisine (force d'autant plus grande que l'écart est faible).
        if let secondLan = cached.secondBestLan, let gap = cached.gapToSecondBest,
           arrowMode == .topThree || gap <= 4 {
            let strength = max(0.6, 1 - gap / 12)
            arrows += [arrow(fromLan: secondLan, rank: 2, strength: strength)].compactMap(\.self)
        }
        return arrows
    }

    /// Fabrique une flèche verte de revue depuis un LAN moteur.
    private func arrow(fromLan lan: String, rank: Int, strength: Double) -> HintMove? {
        guard lan.count >= 4 else { return nil }
        return HintMove(
            rank: rank,
            from: Square(String(lan.prefix(2))),
            to: Square(String(lan.dropFirst(2).prefix(2))),
            strength: strength,
            kind: .reviewBest
        )
    }
    private(set) var liveDepth: Int?
    /// Évaluation courante en centipions/mat du point de vue des BLANCS.
    private(set) var currentEvalCp: Int?
    private(set) var currentEvalMate: Int?
    private var liveAnalysisTask: Task<Void, Never>?

    /// File sérielle pour tout ce qui touche au moteur (analyse en continu,
    /// classification de fond) — même discipline que ``PlayViewModel``.
    private var engineQueue: Task<Void, Never> = Task {}

    // MARK: Classification de fond

    private(set) var moveEvaluations: [MoveTree.Index: AnalysisMoveEvaluation] = [:]
    private(set) var isClassifying = false
    private(set) var classificationProgress: (done: Int, total: Int)?
    /// Éval de la position de chaque nœud déjà évalué, point de vue
    /// BLANCS — mise en cache pour ne jamais interroger deux fois le
    /// moteur sur la même position (classification de fond, navigation
    /// lazy dans une variante, ET courbe d'éval partagent ce cache).
    private struct CachedEval {
        /// Probabilité de gain (0...100).
        let winPercent: Double
        /// Éval en pions, bornée ±10 (mat = ±10), pour la courbe.
        let pawns: Double
        /// Meilleur coup du moteur à CETTE position. Gratuit : `rankedEval`
        /// le renvoie déjà et la position parente est de toute façon évaluée
        /// pendant la classification. C'est lui qui alimente la flèche
        /// rétrospective « il fallait jouer ça » et le critère « le coup
        /// joué était le meilleur ».
        var bestLan: String?
        /// Écart (points de % de gain, POV du trait à cette position) entre
        /// le 1er et le 2e choix du moteur — `nil` quand il n'y a pas de 2e
        /// choix. C'est lui qui départage « le meilleur » de « le SEUL bon
        /// coup » (Grand coup / Brillant), et il est gratuit lui aussi : la
        /// classification interroge le moteur en MultiPV=2 à `movetime`
        /// constant, donc pour le même temps de calcul.
        var gapToSecondBest: Double?
        /// 2e meilleur coup (LAN), gratuit lui aussi (MultiPV=2). Sert la 2e
        /// flèche verte de REVUE quand il est presque aussi bon que le premier
        /// (voir ``reviewArrows``). `nil` s'il n'y a pas de 2e choix.
        var secondBestLan: String? = nil
    }
    private var evalCache: [MoveTree.Index: CachedEval] = [:]

    // MARK: Ouverture (ECO)

    private(set) var openingName: EcoOpening?

    // MARK: Initialisation

    init(source: AnalysisSource) {
        let newGame: Game
        switch source {
        case let .pgn(pgn):
            newGame = (try? Game(pgn: pgn)) ?? Game()
        case let .fen(fen):
            newGame = Position(fen: fen).map { Game(startingWith: $0) } ?? Game()
        case .blank:
            newGame = Game()
        }

        let startIndex = newGame.startingIndex
        game = newGame
        currentIndex = startIndex
        board = Board(position: newGame.positions[startIndex] ?? .standard)
        // Revue = un PGN qui contient effectivement des coups à revoir. Une FEN,
        // un plateau vierge ou un PGN vide sont des analyses de POSITION.
        isGameReview = {
            if case .pgn = source { return newGame.moves.hasIndex(after: startIndex) }
            return false
        }()
        refreshDerivedData()

        enqueueEngineWork { [weak self] in await self?.setupEngine() }
    }

    private func setupEngine() async {
        guard await startEngine() else { return }

        // Ne PAS démarrer l'analyse en continu ici : `startLiveAnalysis()`
        // met en file un travail qui attend la fin de sa propre recherche
        // `go infinite` (sans fin tant que rien ne l'arrête), donc tout ce
        // qui serait mis en file ensuite — ici `classifyMainLine()` —
        // resterait bloqué derrière indéfiniment (même piège de
        // concurrence que celui déjà documenté pour
        // `PlayViewModel.interruptHintAnalysisIfNeeded()`). `classifyMainLine()`
        // démarre elle-même l'analyse en continu une fois terminée (y
        // compris s'il n'y a aucun coup à classifier).
        classifyMainLine()
    }

    /// Crée une instance et la démarre.
    ///
    /// Échec de démarrage (réseau NNUE absent, mémoire…) : sans cet état,
    /// l'écran restait muet — ni éval, ni flèches, ni classification, sans la
    /// moindre explication (voir ``PlayViewModel/startEngine()``).
    private func startEngine() async -> Bool {
        let controller = EngineController(type: .stockfish)

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
        return true
    }

    /// Reprise après panne moteur (bouton « Réessayer » de la bannière).
    ///
    /// Repasse par la classification, qui relance elle-même l'analyse en
    /// continu — reprendre par `startLiveAnalysis()` bloquerait la file
    /// derrière un `go infinite` (piège documenté dans ``setupEngine()``).
    func retryEngine() {
        guard !isRetryingEngine else { return }
        isRetryingEngine = true
        enqueueEngineWork { [weak self] in await self?.recoverEngine() }
    }

    private func recoverEngine() async {
        defer { isRetryingEngine = false }
        guard !isTornDown else { return }

        if let engine {
            guard await restartWithSessionSettings(engine) else {
                self.engine = nil
                isEngineUnavailable = true
                return
            }
            isEngineUnavailable = false
        } else {
            guard await startEngine() else { return }
        }

        classifyMainLine()
    }

    // MARK: Chien de garde moteur

    private static let watchdogLogger = Logger(subsystem: "ChessLab", category: "engine-watchdog")

    /// Vrai quand la DERNIÈRE requête moteur a expiré sans réponse : le
    /// moteur est tenu pour planté et doit être redémarré par le maillon
    /// de file en cours (voir ``classifyMainLine()``).
    private var engineWentSilent = false

    /// Relance l'instance avec les réglages de session — threads et table
    /// de hachage compris : `restart` sans `coreCount` repartirait sur UN
    /// seul thread et 16 Mo, un moteur affaibli en silence.
    private func restartWithSessionSettings(_ engine: EngineController) async -> Bool {
        await engine.restart(
            coreCount: EngineController.coreCount(
                forThreads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads)
            ),
            multipv: 1,
            setupCommands: [.setoption(id: "Hash", value: "\(AppSettings.engineHashMB)")]
        )
    }

    /// Redémarrage d'office après détection d'un moteur muet — la version
    /// automatique du bouton « Réessayer » de la bannière.
    private func restartSilentEngine(_ engine: EngineController) async -> Bool {
        engineWentSilent = false
        Self.watchdogLogger.warning("Moteur muet à l'échéance : redémarrage automatique (analyse)")
        let restarted = await restartWithSessionSettings(engine)
        isEngineUnavailable = !restarted
        return restarted
    }

    // MARK: File moteur

    private func enqueueEngineWork(_ work: @escaping () async -> Void) {
        let previous = engineQueue
        engineQueue = Task {
            _ = await previous.value
            await work()
        }
    }

    /// Vrai entre la disparition de l'écran et son éventuel retour.
    ///
    /// Arrêter l'analyse en continu ne suffisait pas : la classification de
    /// fond (40-80 requêtes moteur, ~1 min sur une longue partie) n'était pas
    /// annulée, la file retenant `self` fortement. Elle continuait donc sur un
    /// écran mort PUIS appelait `startLiveAnalysis()` — un `go infinite`
    /// démarré APRÈS la disparition, que plus rien n'arrêterait jamais : VM +
    /// Stockfish retenus définitivement, CPU et batterie consommés jusqu'au
    /// kill de l'app. Ce drapeau est vérifié en tête de chaque maillon de file
    /// ET dans la boucle de classification.
    private var isTornDown = false

    /// Vrai après une libération moteur sur disparition d'écran : signale à
    /// ``handleViewAppear()`` qu'il doit relancer ``setupEngine()`` (nouvelle
    /// instance) plutôt que simplement reprendre l'analyse en continu sur
    /// une instance déjà là.
    private var wasEngineReleasedOnDisappear = false

    /// À appeler quand l'écran d'analyse disparaît : sans cela, une
    /// analyse infinie survivrait à l'écran (même piège que le mode
    /// Jouer, voir ``PlayViewModel/handleViewDisappear()``).
    ///
    /// - important: Libère aussi le PROCESS Stockfish lui-même, pas
    /// seulement sa recherche en cours. "Jouer à partir d'ici" empile un
    /// nouvel écran moteur (Jouer) PAR-DESSUS celui-ci sans le dépiler — sans
    /// cette libération, l'instance d'Analyse (et son réseau NNUE de 78 Mo)
    /// restait vivante tant que l'écran n'était pas dépilé, pendant qu'une
    /// SECONDE instance démarrait pour la partie : deux réseaux NNUE
    /// coexistants, au risque d'un kill mémoire — exactement le bug déjà
    /// trouvé et corrigé côté Jouer (Lot 6.A, voir
    /// ``PlayViewModel/releaseEngine()``), mais jamais traité dans ce sens.
    /// L'arrêt de la recherche infinie DOIT être attendu avant de couper le
    /// process : lui couper le flux pendant qu'une tâche l'itère encore
    /// laisserait cette tâche suspendue pour toujours (le flux vidé ne
    /// `finish()` pas tout seul, voir ``stopLiveAnalysisIfNeeded()``).
    ///
    /// - important: L'arrêt du process réunit DEUX exigences contradictoires
    /// en apparence :
    ///
    /// 1. **Sérialisé** — il passe par la FILE moteur (``enqueueEngineWork``),
    ///    jamais directement. La classification de fond (``classifyMainLine()``)
    ///    tient la file et envoie des commandes UCI en rafale ; couper le
    ///    moteur pendant qu'un maillon lui écrit encore libère le messager
    ///    interne de ChessKitEngine sous ses pieds — EXC_BAD_ACCESS dans
    ///    `EngineMessenger.sendCommand:` (segfault 0x50). `isTornDown` fait
    ///    sortir la boucle de classification ; enfilé derrière elle, l'arrêt
    ///    ne coupe le moteur qu'une fois le dernier envoi terminé.
    ///
    /// 2. **Indépendant du view model** — la clôture enfilée capture le moteur
    ///    FORTEMENT (le moteur, pas `self`). À la sortie d'écran, le view model
    ///    est libéré presque aussitôt ; une capture faible le trouverait déjà
    ///    nil et `stop()` ne serait JAMAIS appelé, le réseau NNUE de 78 Mo
    ///    survivant jusqu'à la libération paresseuse de ChessKitEngine —
    ///    exactement le piège documenté côté Jouer
    ///    (``PlayViewModel/releaseEngine()``). La `Task` non structurée de la
    ///    file tourne jusqu'au bout même sans plus personne pour la retenir.
    func handleViewDisappear() {
        isTornDown = true
        // Sans ça, la lecture continuerait de dérouler la partie derrière
        // l'écran disparu, en relançant une analyse à chaque coup.
        stopAutoplay()
        Task { [weak self] in
            guard let self else { return }
            // Stoppe la recherche live (tâche hors file, bornée) et attend son
            // lecteur AVANT de toucher au moteur : un `go` en vol tient encore
            // le flux.
            await self.stopLiveAnalysisIfNeeded()
            guard let engine = self.engine else { return }
            // Détache le moteur du VM puis enfile son arrêt, capturé FORTEMENT
            // (voir le point 2 ci-dessus).
            self.engine = nil
            self.wasEngineReleasedOnDisappear = true
            self.enqueueEngineWork { await engine.stop() }
        }
    }

    /// Pendant symétrique de ``handleViewDisappear()`` : au retour sur
    /// l'écran (après "Jouer à partir d'ici" par ex.), le moteur — libéré à
    /// la disparition — doit être relancé depuis zéro (``setupEngine()``),
    /// sinon éval et flèches restaient figées jusqu'à la prochaine
    /// navigation dans les coups. No-op au tout premier affichage (`engine`
    /// encore nil mais rien n'a encore été libéré, c'est
    /// `setupEngine`/`classifyMainLine` de l'``init`` qui lance la première
    /// analyse) et pendant la classification de fond (elle relance
    /// elle-même l'analyse une fois terminée).
    func handleViewAppear() {
        isTornDown = false
        if wasEngineReleasedOnDisappear {
            wasEngineReleasedOnDisappear = false
            enqueueEngineWork { [weak self] in await self?.setupEngine() }
            return
        }
        guard engine != nil, !isClassifying, !isLiveAnalyzing, liveAnalysisTask == nil else { return }
        startLiveAnalysis()
    }

    // MARK: Navigation dans l'arbre

    var canGoNext: Bool { game.moves.hasIndex(after: currentIndex) }
    var canGoPrevious: Bool { game.moves.hasIndex(before: currentIndex) }

    // Toute navigation MANUELLE arrête la lecture automatique (le prompt :
    // « stop à la fin ou à toute interaction »). La lecture, elle, passe par
    // `advance()` — sinon elle s'arrêterait toute seule au premier coup.

    func goToNext() {
        stopAutoplay()
        advance()
    }

    private func advance() {
        guard canGoNext else { return }
        currentIndex = game.moves.index(after: currentIndex)
        afterNavigate()
    }

    func goToPrevious() {
        stopAutoplay()
        guard canGoPrevious else { return }
        currentIndex = game.moves.index(before: currentIndex)
        afterNavigate()
    }

    func goToStart() {
        stopAutoplay()
        currentIndex = game.startingIndex
        afterNavigate()
    }

    func goTo(index: MoveTree.Index) {
        stopAutoplay()
        guard game.positions[index] != nil else { return }
        currentIndex = index
        afterNavigate()
    }

    // MARK: Lecture automatique (Lot 5.A)

    /// Tâche de lecture ; `nil` = à l'arrêt. C'est elle qui fait foi, pas un
    /// booléen à part : deux sources de vérité pour « ça joue ou pas » finiraient
    /// par diverger.
    private var autoplayTask: Task<Void, Never>?

    var isAutoplaying: Bool { autoplayTask != nil }

    /// Un coup par seconde (le prompt). S'arrête à la fin de la ligne.
    func toggleAutoplay() {
        if isAutoplaying {
            stopAutoplay()
        } else {
            startAutoplay()
        }
    }

    private func startAutoplay() {
        guard canGoNext else { return }
        autoplayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.canGoNext else { break }
                self.advance()
            }
            self?.autoplayTask = nil
        }
    }

    func stopAutoplay() {
        autoplayTask?.cancel()
        autoplayTask = nil
    }

    /// Efface la menace en même temps que les flèches de coups : une menace
    /// qui survivrait à un changement de position désignerait un coup calculé
    /// pour une autre.
    private func clearArrows() {
        hintMoves = []
        threatMove = nil
    }

    /// « Il fallait jouer ça » : le meilleur coup de la position PRÉCÉDENTE,
    /// affiché quand le coup qui mène ici est fautif.
    ///
    /// C'est le chaînon qui manquait. Les flèches vertes portent sur la
    /// position AFFICHÉE, donc sur le camp au trait : juste après une gaffe,
    /// elles montrent ce que l'ADVERSAIRE va pouvoir jouer — utile, mais ce
    /// n'est pas la question qu'on se pose en revoyant sa propre erreur.
    var betterMoveArrow: HintMove? {
        guard let quality = lastMoveQuality, quality.isFault,
              game.moves.hasIndex(before: currentIndex)
        else { return nil }

        let parentIndex = game.moves.index(before: currentIndex)
        guard let lan = evalCache[parentIndex]?.bestLan, lan.count >= 4 else { return nil }
        // Le coup RÉELLEMENT joué n'a pas besoin d'être re-fléché.
        guard lan != game.moves[currentIndex]?.lan else { return nil }

        return HintMove(
            rank: 1,
            from: Square(String(lan.prefix(2))),
            to: Square(String(lan.dropFirst(2).prefix(2))),
            strength: 1,
            kind: .better
        )
    }

    /// Qualité du coup qui mène à la position affichée — la pastille du
    /// plateau, le bandeau coach et la flèche rétrospective en dépendent.
    /// Tant que notre classification n'est pas passée, les annotations NAG
    /// d'un PGN importé servent de repli.
    var lastMoveQuality: MoveQuality? {
        if let quality = moveEvaluations[currentIndex]?.quality { return quality }
        guard let assessment = game.moves[currentIndex]?.assessment else { return nil }
        return MoveQuality(assessment)
    }

    /// Case où poser la pastille : l'arrivée du coup joué.
    var qualityBadge: (square: Square, quality: MoveQuality)? {
        guard let quality = lastMoveQuality, let move = lastMove else { return nil }
        return (move.end, quality)
    }

    /// Variation de probabilité de gain du coup affiché, POINT DE VUE DU
    /// JOUEUR qui l'a joué et en POINTS de % (signé) : positif = le coup a
    /// AMÉLIORÉ ses chances, négatif = il les a DÉGRADÉES. Même quantité que
    /// celle qui sert à classer le coup et à calculer la précision (voir
    /// ``computeAccuracyByColor``), donc cohérente avec la pastille. `nil`
    /// tant que le coup n'est pas encore évalué ou en position de départ.
    var lastMoveWinDelta: Double? {
        guard game.moves.hasIndex(before: currentIndex),
              let after = moveEvaluations[currentIndex]?.winPercentAfterMover
        else { return nil }
        let parentIndex = game.moves.index(before: currentIndex)
        guard let evalBefore = evalCache[parentIndex] else { return nil }
        let mover = currentIndex.color
        let beforeMoverPOV = mover == .white ? evalBefore.winPercent : 100 - evalBefore.winPercent
        return after - beforeMoverPOV
    }

    private func afterNavigate() {
        syncBoard()
        // SYNCHRONE, avant toute mise en file. `startLiveAnalysis` vide bien
        // `hintMoves`, mais seulement quand son travail s'exécute — or il doit
        // d'abord attendre l'arrêt du `go infinite` précédent. Pendant cet
        // intervalle, les flèches de la position PRÉCÉDENTE restaient
        // affichées sur la nouvelle : c'est le « les flèches restent tout le
        // temps affichées » du rapport. `clearArrows()` existait depuis le
        // début pour ça et n'était appelé nulle part.
        clearArrows()
        startLiveAnalysis()
        ensureEvaluatedLazily(at: currentIndex)
    }

    // MARK: Menace de l'adversaire (Lot 5.G)

    /// Flèche rouge : ce que l'adversaire jouerait si on lui laissait la
    /// main. Vide quand la question n'a pas de sens (voir ``ThreatPosition``).
    private(set) var threatMove: HintMove?

    /// Courte recherche (200 ms, le prompt) sur la position avec le trait
    /// passé à l'adversaire.
    private func computeThreat() {
        threatMove = nil
        guard let threatFEN = ThreatPosition.fenWithSideToMoveFlipped(board.position.fen) else { return }

        enqueueEngineWork { [weak self] in
            guard let self, let engine = self.engine, !self.isTornDown else { return }
            // La position affichée a pu changer entre la mise en file et
            // l'exécution : une menace calculée pour une AUTRE position serait
            // pire que pas de menace du tout.
            let expectedIndex = self.currentIndex

            await engine.synchronize()
            await engine.send(.setoption(id: "MultiPV", value: "1"))
            await engine.send(.position(.fen(threatFEN)))
            await engine.send(.go(movetime: 200))

            let outcome = await EngineWatchdog.run(deadlineMs: 200 + EngineWatchdog.graceMs) {
                for await response in await engine.responseStream {
                    guard case let .bestmove(lan, _) = response else { continue }
                    guard !self.isTornDown, self.currentIndex == expectedIndex, lan.count >= 4 else { return }
                    self.threatMove = HintMove(
                        rank: 1,
                        from: Square(String(lan.prefix(2))),
                        to: Square(String(lan.dropFirst(2).prefix(2))),
                        strength: 1,
                        kind: .threat
                    )
                    return
                }
            }
            // Pas de menace affichée cette fois — mais un moteur remis sur
            // pied pour l'analyse en continu qui suit dans la file.
            if case .timedOut = outcome {
                _ = await self.restartSilentEngine(engine)
            }
        }
    }

    private func syncBoard() {
        guard let position = game.positions[currentIndex] else { return }
        board = Board(position: position)
        selectedSquare = nil
        legalTargetSquares = []
        lastMove = currentIndex == game.startingIndex ? nil : game.moves[currentIndex]
        openingName = EcoOpeningLookup.openingName(for: sanPath(to: currentIndex), in: EcoOpeningLoader.standard)
        refreshDerivedData()
    }

    /// Reconstruit la ligne SAN depuis le début jusqu'à `index`, en
    /// suivant la branche réellement empruntée (variante ou principale).
    private func sanPath(to index: MoveTree.Index) -> [String] {
        var path: [String] = []
        var idx = index
        while idx != game.startingIndex {
            if let san = game.moves[idx]?.san {
                path.append(san)
            }
            guard game.moves.hasIndex(before: idx) else { break }
            idx = game.moves.index(before: idx)
        }
        return path.reversed()
    }

    // MARK: Interaction utilisateur — sélection et coup (tap-tap / drag & drop)

    func selectSquare(_ square: Square) {
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

    /// - important: Garde de couleur indispensable — voir
    /// ``PlayViewModel/attemptUserMove(from:to:)`` : sans lui, un drag sur une
    /// pièce du camp qui n'a pas le trait enregistre un coup hors-tour dans
    /// l'arbre de variantes et rend le PGN exporté irrejouable.
    func attemptMove(from start: Square, to end: Square) {
        guard
            start != end,
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

        commit(move: move)
    }

    func completePromotion(to kind: Piece.Kind) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil

        var scratch = pending.scratch
        let move = scratch.completePromotion(of: pending.move, to: kind)
        commit(move: move)
    }

    func cancelPromotion() {
        pendingPromotion = nil
    }

    /// Joue `move` depuis `currentIndex` : rejoint la ligne existante si
    /// c'est déjà le coup suivant connu, sinon crée une nouvelle variante
    /// (comportement natif de `Game.make(move:from:)`).
    private func commit(move: Move) {
        currentIndex = game.make(move: move, from: currentIndex)
        afterNavigate()
    }

    // MARK: Analyse en continu (MultiPV = 3) de la position affichée

    /// Contrairement à l'indice du mode Jouer, toujours active dès qu'une
    /// position est affichée — pas de bascule utilisateur, voir le brief
    /// ("Analyse live : éval + barre d'avantage... MultiPV = 3").
    private func startLiveAnalysis() {
        // La menace AVANT l'analyse en continu, et ce n'est pas un détail :
        // l'analyse en continu tourne en `go infinite`, qui ne se termine
        // jamais tout seul. Enfilée derrière elle, la recherche de menace
        // attendrait une fin qui ne vient pas (même interblocage que celui
        // documenté dans `setupEngine`). Devant, elle dure 200 ms et rend la
        // main.
        //
        // Ici plutôt que dans `afterNavigate` : l'analyse en continu démarre
        // aussi à l'ouverture de l'écran et au retour dessus, sans qu'on ait
        // navigué. La menace ne s'affichait donc jamais tant qu'on n'avait pas
        // changé de coup (vu à la capture).
        computeThreat()

        enqueueEngineWork { [weak self] in
            guard let self, let engine = self.engine, !self.isTornDown else { return }
            await self.stopLiveAnalysisIfNeeded()
            // L'écran a pu disparaître pendant l'attente ci-dessus — ou même
            // avant que ce maillon ne démarre, auquel cas le `stop` HORS file
            // de `handleViewDisappear` s'est exécuté AVANT lui et n'a rien
            // arrêté. Sans ce second contrôle, on lancerait ici une analyse
            // infinie orpheline que plus rien n'arrêterait.
            guard !self.isTornDown else { return }

            let fen = self.board.position.fen
            let mover = self.board.position.sideToMove
            self.isLiveAnalyzing = true
            self.hintMoves = []
            self.liveDepth = nil

            let task = Task {
                await engine.synchronize()
                await engine.send(.setoption(id: "MultiPV", value: "3"))
                await engine.send(.position(.fen(fen)))
                // Bornée en PROFONDEUR plutôt que `go infinite` : ce dernier ne
                // s'arrêtait jamais tout seul (cœurs à 100 % tant que la
                // position restait affichée). Au plafond, l'éval et les flèches
                // n'évoluent plus à l'œil ; le moteur passe en idle, la boucle
                // reçoit son `.bestmove` de fin naturellement (elle le traite
                // déjà comme terminaison), et la navigation relance une
                // recherche neuve. `movetime` en filet de sécurité contre une
                // position pathologique qui n'atteindrait jamais la profondeur.
                await engine.send(.go(
                    depth: ThermalMonitor.shared.liveDepth(preferred: AppSettings.liveAnalysisDepth),
                    movetime: 8000
                ))

                if !self.isLiveAnalyzing {
                    await engine.send(.stop)
                }

                var lanByRank: [Int: String] = [:]
                var scoreByRank: [Int: Double] = [:]

                for await response in await engine.responseStream {
                    switch response {
                    case let .info(info):
                        // `isLiveAnalyzing` est un drapeau PARTAGÉ du view
                        // model, pas propre à cette tâche : dès que la
                        // navigation relance une analyse, il repasse à
                        // `true` et les réponses TARDIVES de la position
                        // précédente — encore en vol sur le flux —
                        // franchissaient de nouveau cette garde pour
                        // réécrire les flèches. D'où un « e2-e4 » affiché en
                        // plein milieu de partie, coup pourtant impossible.
                        // `clearArrows()` n'y pouvait rien : il nettoie
                        // AVANT, et c'est après qu'on resalissait.
                        //
                        // Même discipline que ``computeThreat()`` : la
                        // position analysée par CETTE tâche est capturée, et
                        // rien n'est écrit si l'écran en montre une autre.
                        guard self.isLiveAnalyzing, self.board.position.fen == fen else { break }
                        if let depth = info.depth {
                            self.liveDepth = depth
                        }
                        if (info.multipv ?? 1) == 1 {
                            if let mate = info.score?.mate {
                                self.currentEvalMate = mover == .white ? mate : -mate
                                self.currentEvalCp = nil
                            } else if let cp = info.score?.cp {
                                self.currentEvalCp = mover == .white ? Int(cp) : -Int(cp)
                                self.currentEvalMate = nil
                            }
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
                        self.isLiveAnalyzing = false
                        return
                    default:
                        break
                    }
                }
                self.isLiveAnalyzing = false
            }

            // NE PAS attendre `task` ici : c'est la cause racine du
            // blocage constaté ("rien ne se passe, Stockfish cherche à
            // l'infini") — `task` ne se termine que sur réception de
            // `.bestmove`, c'est-à-dire seulement après un `.stop`
            // explicite (voir `stopLiveAnalysisIfNeeded()`). Si ce travail
            // en file attendait `task.value` avant de rendre la main, la
            // file moteur entière resterait bloquée derrière une
            // recherche `go infinite` qui ne s'arrête jamais toute seule
            // — plus aucun travail suivant (navigation, classification,
            // génération de puzzles…) ne pourrait alors s'exécuter, y
            // compris celui qui est censé envoyer ce `.stop`. `task`
            // continue de tourner en tâche de fond, suivie via
            // `liveAnalysisTask`, et sera interrompue par le PROCHAIN
            // travail mis en file (qui appelle `stopLiveAnalysisIfNeeded()`
            // en premier).
            self.liveAnalysisTask = task
        }
    }

    /// Même discipline de consommateur unique du flux que
    /// ``PlayViewModel/stopHintIfNeeded()`` — voir sa documentation pour
    /// le piège de concurrence évité.
    private func stopLiveAnalysisIfNeeded() async {
        if isLiveAnalyzing {
            isLiveAnalyzing = false
            await engine?.send(.stop)
        }
        guard let task = liveAnalysisTask else { return }
        // Attente elle-même bornée : le `bestmove` de clôture vient du
        // moteur, et un moteur planté ne l'enverra jamais — c'était LE
        // point de gel de tout l'écran d'analyse (chaque navigation passe
        // ici).
        //
        // `task` est une tâche NON STRUCTURÉE : l'annulation du chien de
        // garde ne l'atteint pas, et `await task.value` (non `throws`) ne
        // rend pas la main à l'annulation. Sans ce relais explicite,
        // `withTaskGroup` — qui attend tous ses enfants avant de rendre la
        // main — resterait suspendu ici POUR TOUJOURS malgré l'échéance
        // tombée : le gel qu'on prétend supprimer. Le relais annule la
        // boucle de lecture, dont l'itération d'`AsyncStream` se termine à
        // l'annulation ; `task.value` rend alors la main.
        let outcome = await EngineWatchdog.run(deadlineMs: EngineWatchdog.graceMs) {
            await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
        }
        if case .timedOut = outcome, let engine {
            _ = await restartSilentEngine(engine)
        }
        liveAnalysisTask = nil
        await engine?.send(.setoption(id: "MultiPV", value: "1"))
    }

    // MARK: Classification (perte de probabilité de gain)

    /// Classifie la ligne principale importée en tâche de fond : icônes
    /// de classification + précision par joueur (voir
    /// ``accuracyByColor``). Les variantes ne sont classifiées qu'à la
    /// volée, dès qu'on y navigue (``ensureEvaluatedLazily``).
    private func classifyMainLine() {
        enqueueEngineWork { [weak self] in
            guard let self, let engine = self.engine, !self.isTornDown else { return }
            await self.stopLiveAnalysisIfNeeded()
            guard !self.isTornDown else { return }

            var mainLineIndices: [MoveTree.Index] = [self.game.startingIndex]
            var idx = self.game.startingIndex
            while self.game.moves.hasIndex(after: idx) {
                idx = self.game.moves.index(after: idx)
                mainLineIndices.append(idx)
            }
            let movesToClassify = Array(mainLineIndices.dropFirst())
            guard !movesToClassify.isEmpty else {
                // Rien à classifier (position vierge/FEN sans historique) :
                // c'est ici que l'analyse en continu doit démarrer, faute
                // de quoi une session FEN/vierge n'aurait jamais ni éval ni
                // flèches d'indice.
                self.startLiveAnalysis()
                return
            }

            self.isClassifying = true
            self.classificationProgress = (done: 0, total: movesToClassify.count)

            // Moteur PARTAGÉ, threads inchangés (le pool de moteurs mono-thread
            // décrit dans tune-analysis.md n'est PAS réalisable avec
            // ChessKitEngine : chaque instance détourne le `stdout`/`stdin`
            // GLOBAL du processus via `dup2`, donc deux moteurs qui cherchent
            // en même temps se corrompent — voir le compte-rendu. On garde donc
            // le comportement de classification existant, avec le seul gain sûr
            // de la tâche 2 : le rafraîchissement dérivé est COALESCÉ ici plutôt
            // que relancé après chaque nœud (il rendait la boucle quadratique
            // sur le MainActor).
            for (done, index) in movesToClassify.enumerated() {
                // Écran quitté en cours de route : on abandonne la
                // classification restante plutôt que de continuer à faire
                // chercher Stockfish pour un écran que plus personne ne regarde.
                if self.isTornDown { break }
                await self.classifyNode(index, engine: engine)

                // Moteur muet pendant ce nœud : redémarrage automatique, puis
                // UNE seconde chance sur le MÊME nœud. Deux mutismes d'affilée
                // lèvent la bannière — « Réessayer » reprendra là où ça s'est
                // arrêté (les nœuds déjà classés sont en cache).
                if self.engineWentSilent {
                    guard await self.restartSilentEngine(engine) else { break }
                    await self.classifyNode(index, engine: engine)
                    if self.engineWentSilent {
                        self.isEngineUnavailable = true
                        break
                    }
                }
                if done % 4 == 3 { self.refreshDerivedData() }
                self.classificationProgress = (done: done + 1, total: movesToClassify.count)
            }

            self.isClassifying = false
            self.classificationProgress = nil
            self.refreshDerivedData()
            // Moteur déclaré indisponible en cours de route : inutile de lancer
            // une analyse en continu sur une instance morte — la bannière est
            // levée, « Réessayer » relancera tout.
            guard !self.isTornDown, !self.isEngineUnavailable else { return }
            self.startLiveAnalysis()
        }
    }

    /// Classifie un nœud isolé dès qu'on y navigue pour la première fois
    /// (variante explorée, ou coup joué par l'utilisateur) — pas de
    /// classification eager de variantes entières, voir PROGRESS.md.
    private func ensureEvaluatedLazily(at index: MoveTree.Index) {
        guard index != game.startingIndex, moveEvaluations[index] == nil else { return }
        enqueueEngineWork { [weak self] in
            guard let self, let engine = self.engine, !self.isTornDown else { return }
            await self.stopLiveAnalysisIfNeeded()
            guard !self.isTornDown else { return }
            await self.classifyNode(index, engine: engine)
            // Même politique que la classification de fond : un
            // redémarrage, une seconde chance, puis la bannière.
            if self.engineWentSilent {
                guard await self.restartSilentEngine(engine) else { return }
                await self.classifyNode(index, engine: engine)
                if self.engineWentSilent {
                    self.isEngineUnavailable = true
                    return
                }
            }
            // Nœud isolé (action utilisateur) : rafraîchir AUSSITÔT — plus de
            // refresh dans `classifyNode` (voir tâche 2 / la boucle Phase 2).
            self.refreshDerivedData()
            self.startLiveAnalysis()
        }
    }

    /// Suppose que `MultiPV` est déjà réglé à 2 en entrée (voir
    /// ``classifyMainLine()``) : le 2e choix du moteur fait partie des
    /// données de classification, pas d'une vérification à part.
    private func classifyNode(_ index: MoveTree.Index, engine: EngineController) async {
        guard moveEvaluations[index] == nil else { return }
        guard index != game.startingIndex, game.moves.hasIndex(before: index) else { return }
        let parentIndex = game.moves.index(before: index)
        guard let move = game.moves[index] else { return }

        guard
            let evalBefore = await evaluatePosition(at: parentIndex, engine: engine),
            let evalAfter = await evaluatePosition(at: index, engine: engine)
        else { return }

        let mover = index.color
        let winPercentBeforeMover = mover == .white ? evalBefore.winPercent : 100 - evalBefore.winPercent
        let winPercentAfterMover = mover == .white ? evalAfter.winPercent : 100 - evalAfter.winPercent

        let isSacrifice = boardAt(index)
            .map { MoveClassifier.involvesSacrifice(move: move, boardAfterMove: $0) } ?? false

        // Coup suivant réellement joué (la réponse de l'adversaire) : sert à
        // voir si un sacrifice a été immédiatement repris sur place.
        let nextMove = game.moves.hasIndex(after: index)
            ? game.moves[game.moves.index(after: index)]
            : nil

        let quality = MoveClassifier.classify(MoveClassifier.Input(
            winPercentBefore: winPercentBeforeMover,
            winPercentAfter: winPercentAfterMover,
            // `gapToSecondBest` est déjà POV du trait à la position
            // parente, c'est-à-dire POV du joueur de CE coup.
            isBestMove: evalBefore.bestLan == move.lan,
            gapToSecondBest: evalBefore.gapToSecondBest,
            isBook: EcoOpeningLookup.isInBook(sanPath(to: index), in: EcoOpeningLoader.bookLines),
            isSacrifice: isSacrifice,
            sacrificeImmediatelyRecaptured: MoveClassifier.isImmediatelyRecaptured(move, byNext: nextMove),
            bestMoveWasTactical: bestMoveIsTactical(lan: evalBefore.bestLan, at: parentIndex),
            isForced: legalMoveCount(at: parentIndex) == 1
        ))

        moveEvaluations[index] = AnalysisMoveEvaluation(winPercentAfterMover: winPercentAfterMover, quality: quality)
        if let assessment = quality.pgnAssessment {
            game.annotate(moveAt: index, assessment: assessment)
        }
        // Rafraîchissement laissé à l'APPELANT : reparcourir tout l'arbre après
        // CHAQUE nœud rendait la classification quadratique sur le MainActor. La
        // boucle de masse (Phase 2) le coalesce ; le nœud isolé
        // (``ensureEvaluatedLazily``) le fait aussitôt.
    }

    /// Le meilleur coup disponible (celui qu'on a pu RATER) est-il une
    /// tactique nette — capture de matériel ou mat direct ? Sert à qualifier
    /// l'« occasion manquée » : dans une position déjà gagnée, rater un mat ou
    /// une pièce est un « Miss », relâcher positionnellement n'en est pas un.
    ///
    /// Approximation ASSUMÉE : une capture n'est pas forcément un gain NET
    /// après échanges (pas de recherche en profondeur ici), mais dans le
    /// contexte d'une occasion manquée — la ligne principale du moteur, sur
    /// une position gagnante — une capture ou un mat distingue bien la tactique
    /// ratée du simple flottement. Le mat couvre le cas « mat direct ».
    private func bestMoveIsTactical(lan: String?, at parentIndex: MoveTree.Index) -> Bool {
        guard let lan, lan.count >= 4, let parentPosition = game.positions[parentIndex] else { return false }
        let to = Square(String(lan.dropFirst(2).prefix(2)))
        // Capture : la case d'arrivée du meilleur coup porte une pièce adverse.
        let capturesMaterial = parentPosition.pieces.contains {
            $0.square == to && $0.color == parentPosition.sideToMove.opposite
        }
        if capturesMaterial { return true }
        // Mat direct : jouer le meilleur coup mène à un échec et mat.
        let from = Square(String(lan.prefix(2)))
        var scratch = Board(position: parentPosition)
        guard scratch.move(pieceAt: from, to: to) != nil else { return false }
        if case .checkmate = scratch.state { return true }
        return false
    }

    /// Nombre de coups légaux du camp au trait — 1 = coup forcé, qui ne
    /// mérite ni éloge ni blâme.
    private func legalMoveCount(at index: MoveTree.Index) -> Int {
        guard let position = game.positions[index] else { return 0 }
        let board = Board(position: position)
        return position.pieces
            .filter { $0.color == position.sideToMove }
            .reduce(0) { $0 + board.legalMoves(forPieceAt: $1.square).count }
    }

    private func boardAt(_ index: MoveTree.Index) -> Board? {
        guard let position = game.positions[index] else { return nil }
        return Board(position: position)
    }

    /// Éval CERTAINE d'une position terminale (mat/pat), sans requête moteur —
    /// Stockfish ne renvoie ni pv ni cp sur un `bestmove (none)`, ce qui
    /// laissait le coup de mat sans classification et la courbe tronquée d'un
    /// point. Rend `nil` si la position n'est pas terminale (ou absente).
    ///
    /// Pur : partagé par le chemin de pool (Phase 1) et le chemin interactif
    /// (``evaluatePosition``), pour que la logique reste UNIQUE — pas de
    /// divergence de verdict entre les deux.
    private func terminalCachedEval(at index: MoveTree.Index) -> CachedEval? {
        guard let position = game.positions[index] else { return nil }
        switch Board(position: position).state {
        case let .checkmate(matedColor):
            return CachedEval(
                winPercent: matedColor == .white ? 0 : 100,
                pawns: matedColor == .white ? -10 : 10,
                bestLan: nil,
                gapToSecondBest: nil
            )
        case .draw:
            return CachedEval(winPercent: 50, pawns: 0, bestLan: nil, gapToSecondBest: nil)
        default:
            return nil
        }
    }

    /// Convertit un résultat de recherche classée en ``CachedEval`` — la
    /// conversion cp → probabilité de gain / pions / meilleur coup / écart au
    /// 2e choix. Pur, partagé pool ↔ interactif (voir ``terminalCachedEval``).
    /// `nil` si le rang 1 manque (moteur muet).
    private func makeCachedEval(
        rankedDict: [Int: (lan: String, pv: [String], cp: Int)], sideToMove: Piece.Color
    ) -> CachedEval? {
        guard let best = rankedDict[1] else { return nil }
        let cp = best.cp
        // POV BLANCS pour les deux échelles, quel que soit le trait (le score
        // UCI est toujours du point de vue du trait à la position interrogée).
        let cpWhite = sideToMove == .white ? cp : -cp
        // L'écart au 2e choix, lui, reste POV du TRAIT : c'est le joueur qui
        // choisit son coup ici qui est jugé dessus.
        let gap = rankedDict[2].map {
            EvalConversion.winPercentage(cp: cp) - EvalConversion.winPercentage(cp: $0.cp)
        }
        return CachedEval(
            winPercent: EvalConversion.winPercentage(cp: cpWhite),
            pawns: min(10, max(-10, Double(cpWhite) / 100)),
            bestLan: best.lan,
            gapToSecondBest: gap,
            secondBestLan: rankedDict[2]?.lan
        )
    }

    /// Budget de nœuds de BASE pour une position (tâche 3 : réduit dans
    /// l'ouverture). SANS le facteur thermique — chaque chemin de recherche
    /// l'applique lui-même (``rankedEval`` en interne ; le worker de pool
    /// explicitement), pour ne jamais le compter deux fois.
    ///
    /// Ouverture (théorie/livre) : positions calmes et connues, éval ≈ 0.
    /// Inutile d'y mettre le budget d'un milieu de partie tendu — et les coups
    /// de livre ne sont de toute façon pas blâmés (classés « théorie »).
    private func baseNodeBudget(at index: MoveTree.Index) -> Int {
        let inBook = EcoOpeningLookup.isInBook(sanPath(to: index), in: EcoOpeningLoader.bookLines)
        return inBook ? 80_000 : 300_000
    }

    private func evaluatePosition(at index: MoveTree.Index, engine: EngineController) async -> CachedEval? {
        if let cached = evalCache[index] { return cached }
        guard let position = game.positions[index] else { return nil }

        if let terminal = terminalCachedEval(at: index) {
            evalCache[index] = terminal
            return terminal
        }

        // MultiPV=2 : le 2e choix gratuit, voir ``CachedEval/gapToSecondBest``.
        // Budget conscient de l'ouverture ; `rankedEval` applique le thermique.
        let ranked = await rankedEval(
            fen: position.fen, engine: engine, nodes: baseNodeBudget(at: index), multipv: 2
        )
        guard let cached = makeCachedEval(rankedDict: ranked, sideToMove: position.sideToMove) else {
            return nil
        }
        evalCache[index] = cached
        return cached
    }

    /// Requête moteur ponctuelle (mouvement unique, pas `infinite`).
    /// Retourne, par rang, le LAN du meilleur coup de cette ligne, sa
    /// variante principale complète (utilisée comme solution de puzzle,
    /// voir ``generatePuzzles(in:)``) et son éval en centipions (POV du
    /// trait à la position interrogée).
    ///
    /// ## Budget en NŒUDS, et non en temps
    ///
    /// Le réglage d'origine était `movetime: 400`. Mesuré sur iPhone 17 Pro
    /// en Release, MultiPV=2, il atteignait la profondeur **11 à 13** en
    /// milieu de partie — loin des 18-20 visés par Lichess ou chess.com, et
    /// sous le seuil où la détection de gaffes devient fiable.
    ///
    /// Surtout, un budget en TEMPS rend la classification irreproductible :
    /// la profondeur atteinte dépend de l'appareil, de sa charge et de sa
    /// température. La même partie analysée deux fois pouvait rendre deux
    /// verdicts différents — pénible pour une fonction pédagogique dont
    /// l'utilisateur retient « mon coup 23 était une gaffe », et
    /// invérifiable de son côté.
    ///
    /// Le temps fixe gaspillait par ailleurs : une finale atteignait la
    /// profondeur 20 en **109 ms** mais consommait quand même ses 400 ms.
    /// Le budget en nœuds mesure le TRAVAIL utile — et il s'adapte tout
    /// seul, le débit en nœuds/seconde baissant quand la position se
    /// complique.
    ///
    /// Relevé à `nodes 300000` (iPhone 17 Pro, Release) : ~600-750 ms en
    /// milieu de partie à 4 threads, 229 ms sur finale, ~2,4 s à 1 seul
    /// thread. Le plafond `capMs` ne mord donc qu'en régime dégradé, ce qui
    /// est exactement son rôle : on accepte d'y perdre la reproductibilité
    /// plutôt que de laisser une analyse s'éterniser.
    ///
    /// - note: Le déterminisme n'est pas absolu — la recherche
    ///   multi-threads explore dans un ordre qui dépend de l'entrelacement.
    ///   Mais ce résidu est sans commune mesure avec la dépendance à la
    ///   vitesse de l'appareil, qui disparaît.
    ///
    /// La génération de puzzles demande une recherche plus profonde pour
    /// une séquence solution fiable, d'où son budget propre.
    ///
    /// `MultiPV` est réglé ICI, à chaque appel, et non par l'appelant :
    /// après un redémarrage automatique du moteur (voir
    /// ``restartSilentEngine(_:)``), une valeur posée en début de boucle
    /// serait silencieusement retombée à 1 — plus d'écart au 2e choix,
    /// plus de Grand coup, sans que rien ne le signale.
    private func rankedEval(
        fen: String, engine: EngineController,
        nodes: Int = 300_000, capMs: Int = 1_500, multipv: Int
    ) async -> [Int: (lan: String, pv: [String], cp: Int)] {
        // Barrière AVANT la recherche : jette les `info` en retard de la
        // recherche précédente, qui fausseraient ce classement — voir
        // ``EngineController/synchronize()``.
        await engine.synchronize()
        await engine.send(.setoption(id: "MultiPV", value: "\(multipv)"))
        await engine.send(.position(.fen(fen)))
        // Surchauffe : moitié moins de TRAVAIL par position, pas moitié
        // moins de temps — voir ``ThermalMonitor/nodeFactor``. La
        // classification d'une longue partie, c'est 40 à 80 recherches
        // d'affilée : exactement ce qui fait chauffer l'appareil (Lot 2.C).
        let adjustedNodes = max(1, Int(Double(nodes) * ThermalMonitor.shared.nodeFactor))
        // Les deux limites ensemble : UCI s'arrête à la première atteinte.
        await engine.send(.go(nodes: adjustedNodes, movetime: capMs))

        let outcome = await EngineWatchdog.run(deadlineMs: capMs + EngineWatchdog.graceMs) {
            var result: [Int: (lan: String, pv: [String], cp: Int)] = [:]
            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    guard let rank = info.multipv, let pv = info.pv, let firstMove = pv.first else { break }
                    let cp: Int
                    if let mate = info.score?.mate {
                        cp = mate > 0 ? 10_000 : -10_000
                    } else if let scoreCp = info.score?.cp {
                        cp = Int(scoreCp)
                    } else {
                        break
                    }
                    result[rank] = (lan: firstMove, pv: pv, cp: cp)
                case .bestmove:
                    return result
                default:
                    break
                }
            }
            return result
        }

        switch outcome {
        case let .finished(result):
            return result
        case .timedOut:
            // Le moteur n'a rien rendu à l'échéance : il est tenu pour
            // planté. Le signaler suffit — c'est le maillon de file en
            // cours qui décide du redémarrage (voir ``classifyMainLine()``),
            // pas une requête isolée.
            engineWentSilent = true
            return [:]
        }
    }

    // MARK: Puzzles

    /// Génère un puzzle pour chaque coup classé imprécision/erreur/gaffe
    /// de la ligne principale, avec le filtre de netteté du brief (écart
    /// PV1–PV2 > 150 centipions — pas un écart de probabilité de gain
    /// comme ``MoveClassifier/isBrilliant``, le brief spécifie
    /// explicitement des centipions ici). Recherche volontairement plus
    /// profonde qu'à la classification (celle-ci ne visait qu'une
    /// estimation rapide, ici il faut une séquence solution fiable).
    /// Passe par la file sérielle moteur comme le reste de la classe —
    /// `withCheckedContinuation` fait le pont entre cette file (qui ne
    /// retourne rien) et l'appelant, qui a besoin du nombre de puzzles
    /// créés pour informer l'utilisateur.
    ///
    /// - important: L'arrêt de l'analyse en continu se fait ICI, HORS
    /// file (comme ``handleViewDisappear()``), PAS via le
    /// `stopLiveAnalysisIfNeeded()` interne à
    /// ``performPuzzleGeneration(in:)``. L'analyse en continu tourne en
    /// `go infinite`, qui ne s'arrête jamais tout seul : si on se
    /// contentait d'`enqueueEngineWork` directement, la nouvelle tâche
    /// attendrait indéfiniment que la tâche PRÉCÉDENTE (l'analyse
    /// infinie) se termine d'elle-même avant même de pouvoir commencer à
    /// s'exécuter — donc avant de pouvoir envoyer le `stop` qui la
    /// terminerait. Interblocage classique, même piège documenté pour
    /// `PlayViewModel.interruptHintAnalysisIfNeeded()`.
    @discardableResult
    func generatePuzzles(in context: ModelContext) async -> Int {
        await stopLiveAnalysisIfNeeded()
        return await withCheckedContinuation { continuation in
            enqueueEngineWork { [weak self] in
                let count = await self?.performPuzzleGeneration(in: context) ?? 0
                continuation.resume(returning: count)
            }
        }
    }

    private func performPuzzleGeneration(in context: ModelContext) async -> Int {
        guard let engine else { return 0 }
        await stopLiveAnalysisIfNeeded()

        let sourcePGN = exportedPGN
        // L'occasion manquée est un candidat de choix : par définition, il
        // existait un coup nettement meilleur à retrouver.
        let candidateIndices = moveEvaluations
            .filter { [.mistake, .miss, .blunder].contains($0.value.quality) }
            .keys

        var created = 0
        for index in candidateIndices {
            guard game.moves.hasIndex(before: index), let move = game.moves[index] else { continue }
            let parentIndex = game.moves.index(before: index)
            guard let parentPosition = game.positions[parentIndex] else { continue }

            // Budget TRIPLE de celui de la classification (900 000 nœuds
            // contre 300 000), dans le même rapport que l'ancien 1 200 ms
            // contre 400 ms : la séquence solution d'un puzzle doit être
            // sûre sur plusieurs coups, pas seulement le premier. Plafond
            // relevé en proportion, sinon il mordrait avant les nœuds et
            // ramènerait le budget réel à celui de la classification.
            let ranked = await rankedEval(
                fen: parentPosition.fen, engine: engine,
                nodes: 900_000, capMs: 4_500, multipv: 2
            )
            // Moteur muet : on le remet sur pied et on passe ce candidat —
            // un puzzle de moins vaut mieux qu'une génération figée.
            if engineWentSilent {
                guard await restartSilentEngine(engine) else { break }
                continue
            }
            guard let best = ranked[1], let second = ranked[2], best.cp - second.cp > 150 else {
                continue
            }

            // Tronque la PV en une solution courte et nette plutôt que
            // d'exiger 10 demi-coups exacts (queue de PV peu fiable, coup
            // gagnant alternatif compté faux) — voir instructions.md §G7.
            let solutionLANs = PuzzleSolutionTrimmer.trim(pv: best.pv, startFEN: parentPosition.fen)
            guard !solutionLANs.isEmpty else { continue }
            let puzzle = Puzzle()
            puzzle.fen = parentPosition.fen
            puzzle.playedMoveSAN = move.san
            puzzle.solutionLANs = solutionLANs
            puzzle.themeRaw = PuzzleThemeDetector.detect(startFEN: parentPosition.fen, solutionLANs: solutionLANs).rawValue
            puzzle.phaseRaw = GamePhaseClassifier.classify(fen: parentPosition.fen).rawValue
            puzzle.sourceGamePGN = sourcePGN
            puzzle.sourceRaw = PuzzleSource.ownGames.rawValue
            context.insert(puzzle)
            created += 1
        }

        if created > 0 {
            try? context.save()
        }
        if !isEngineUnavailable {
            startLiveAnalysis()
        }
        return created
    }

    // MARK: Données dérivées (matérialisées)

    /// Liste de coups, précision et courbe d'éval sont STOCKÉES et
    /// rafraîchies uniquement quand leurs sources changent (navigation,
    /// coup joué, nœud classifié) — pas des propriétés calculées lues
    /// dans `body` : pendant l'analyse en continu, `liveDepth`/`hintMoves`
    /// changent plusieurs fois par seconde et chaque tick recomposait
    /// l'écran ENTIER, reparcourant tout le `pgnRepresentation` à chaque
    /// fois — écran pâteux sur une longue partie (même famille de
    /// problème que le `@Query` de la file de puzzles, voir PROGRESS.md).
    private(set) var moveListRows: [MoveListRow] = []
    private(set) var accuracyByColor: [Piece.Color: Double] = [:]
    private(set) var evalCurvePoints: [EvalCurvePoint] = []

    private func refreshDerivedData() {
        moveListRows = computeMoveListRows()
        accuracyByColor = computeAccuracyByColor()
        evalCurvePoints = computeEvalCurvePoints()
    }

    // MARK: Précision par joueur

    /// Précision (%) par joueur, dérivée des coups déjà classifiés de la
    /// ligne principale (voir ``AccuracyScore``). Se complète
    /// progressivement pendant la classification de fond.
    private func computeAccuracyByColor() -> [Piece.Color: Double] {
        var lossesByColor: [Piece.Color: [Double]] = [:]
        var idx = game.startingIndex
        while game.moves.hasIndex(after: idx) {
            let parentIdx = idx
            idx = game.moves.index(after: idx)
            guard let evaluation = moveEvaluations[idx] else { continue }
            guard let evalBefore = evalCache[parentIdx] else { continue }
            let mover = idx.color
            let beforeMoverPOV = mover == .white ? evalBefore.winPercent : 100 - evalBefore.winPercent
            let loss = max(0, beforeMoverPOV - evaluation.winPercentAfterMover)
            lossesByColor[mover, default: []].append(loss)
        }
        return lossesByColor.compactMapValues { losses in
            guard !losses.isEmpty else { return nil }
            let average = losses.reduce(0, +) / Double(losses.count)
            return AccuracyScore.accuracy(averageWinPercentLoss: average)
        }
    }

    // MARK: Courbe d'évaluation

    struct EvalCurvePoint: Identifiable {
        let id: MoveTree.Index
        let ply: Int
        /// POV Blancs, bornée ±10 (mat = ±10).
        let pawns: Double
    }

    /// Ply de la position affichée, pour situer le curseur sur la courbe.
    var currentPly: Int? {
        evalCurvePoints.first { $0.id == currentIndex }?.ply
    }

    /// Points de la ligne principale déjà évalués (voir ``evalCache``) —
    /// s'arrête au premier nœud pas encore classifié : la courbe se
    /// complète progressivement pendant la classification de fond,
    /// plutôt que d'attendre qu'elle soit terminée.
    private func computeEvalCurvePoints() -> [EvalCurvePoint] {
        var points: [EvalCurvePoint] = []
        if let start = evalCache[game.startingIndex] {
            points.append(EvalCurvePoint(id: game.startingIndex, ply: 0, pawns: start.pawns))
        }

        var idx = game.startingIndex
        var ply = 0
        while game.moves.hasIndex(after: idx) {
            idx = game.moves.index(after: idx)
            ply += 1
            guard let cached = evalCache[idx] else { break }
            points.append(EvalCurvePoint(id: idx, ply: ply, pawns: cached.pawns))
        }
        return points
    }

    // MARK: Liste de coups (affichage, variantes imbriquées)

    /// Reconstruit la liste de coups affichée depuis
    /// `game.moves.pgnRepresentation` (seule source de vérité pour la
    /// nidification des variantes, `Node` n'étant pas public — voir
    /// PROGRESS.md).
    private func computeMoveListRows() -> [MoveListRow] {
        var rows: [MoveListRow] = []
        var depth = 0
        var pendingNumberLabel: String?

        for element in game.moves.pgnRepresentation {
            switch element {
            case let .whiteNumber(n):
                pendingNumberLabel = "\(n)."
            case let .blackNumber(n):
                pendingNumberLabel = "\(n)…"
            case let .move(move, index):
                let suffix = move.assessment == .null ? "" : move.assessment.notation
                rows.append(MoveListRow(
                    id: index, depth: depth, numberLabel: pendingNumberLabel,
                    san: move.san, assessmentSuffix: suffix, assessment: move.assessment
                ))
                pendingNumberLabel = nil
            case .positionAssessment:
                break
            case .variationStart:
                depth += 1
            case .variationEnd:
                depth -= 1
            }
        }
        return rows
    }

    // MARK: Bilan de la partie

    /// Bilan par joueur, agrégé sur la ligne principale — calculé à la
    /// demande (ouverture de la feuille de bilan), pas matérialisé : la
    /// marche de l'arbre est triviale comparée à ce que `refreshDerivedData`
    /// fait déjà.
    var gameSummary: GameSummary {
        var qualities: [(color: Piece.Color, quality: MoveQuality)] = []
        var total = 0
        var idx = game.startingIndex
        while game.moves.hasIndex(after: idx) {
            idx = game.moves.index(after: idx)
            total += 1
            if let quality = moveEvaluations[idx]?.quality {
                qualities.append((color: idx.color, quality: quality))
            }
        }
        return GameSummary.compute(
            qualities: qualities,
            totalMainLineMoves: total,
            accuracyByColor: accuracyByColor
        )
    }

    /// Noms des joueurs depuis les en-têtes PGN quand la partie en a
    /// (partie jouée contre Stockfish, PGN importé) — « Blancs »/« Noirs »
    /// sinon.
    var whitePlayerName: String {
        let name = game.tags.white.trimmingCharacters(in: .whitespaces)
        return name.isEmpty || name == "?" ? LocalizationController.string("Blancs") : name
    }

    var blackPlayerName: String {
        let name = game.tags.black.trimmingCharacters(in: .whitespaces)
        return name.isEmpty || name == "?" ? LocalizationController.string("Noirs") : name
    }

    // MARK: Export / "Jouer à partir d'ici"

    var exportedPGN: String { game.pgn }
    var currentFEN: String { board.position.fen }
}
