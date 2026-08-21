import ChessKit
import CStockfishKit
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

    /// LAN du meilleur coup (rang 1) de l'analyse en continu de la position
    /// AFFICHÉE, suffixe de promotion compris (« e7e8q »). Alimente le bouton
    /// « Jouer le meilleur coup » qui déroule la meilleure ligne demi-coup par
    /// demi-coup depuis une position (scan, FEN, éditeur). `nil` tant qu'aucun
    /// coup n'est calculé, et sur une position terminale (mat/pat : pas de pv).
    private(set) var bestLiveMoveLAN: String?

    /// Un coup candidat de l'analyse en continu (jusqu'à 3, rang 1 = meilleur),
    /// prêt pour la LISTE cliquable et les flèches cliquables : on peut jouer
    /// n'importe lequel pour explorer sa variante, pas seulement le meilleur.
    struct Candidate: Identifiable, Equatable {
        let rank: Int
        let from: Square
        let to: Square
        /// LAN complet (promotion comprise) — sert à jouer le coup.
        let lan: String
        /// Notation algébrique du coup dans la position affichée (« Cf3 »).
        let san: String
        /// Évaluation compacte APRÈS ce coup, point de vue des Blancs
        /// (« +0,3 », « −1,2 », « M5 »).
        let eval: String
        var id: Int { rank }
    }

    /// Les coups candidats de la position affichée (analyse en continu, jusqu'à
    /// 3). Vide en revue de partie (les flèches y viennent du cache) et sur une
    /// position terminale.
    private(set) var candidateMoves: [Candidate] = []

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
        /// Variante principale du moteur à cette position (LAN), tronquée à ce
        /// que ``MoveExplainer`` sait lire. Sur la position d'APRÈS un coup,
        /// c'est la RÉFUTATION : ce que l'adversaire va en faire, donc la
        /// matière première du « pourquoi ». Gratuite — `rankedEval` la
        /// renvoie déjà, elle était simplement jetée.
        var pv: [String] = []
        /// Vrai si cette éval vient de la recherche d'AFFINAGE (3M nœuds).
        /// La garde anti-double-paiement en dépend : l'enfant du coup n est
        /// le parent du coup n+1, et quand les deux coups sont limites la
        /// position du milieu était approfondie DEUX fois (mesuré : c'est
        /// l'écart entre le x2,95 du chronométrage et le x2,73 réel).
        var isRefined: Bool = false
    }
    private var evalCache: [MoveTree.Index: CachedEval] = [:]

    // MARK: Persistance de l'analyse (voir ``AnalysisEvalStore``)

    /// Clé disque de la partie en cours de revue — `nil` hors revue.
    private var persistenceKey: String?
    /// Nombre de verdicts déjà sauvés : évite de réécrire un fichier
    /// identique à chaque passage de `handleViewDisappear`.
    private var persistedVerdictCount = 0

    /// Les index de la ligne principale, dans l'ordre (0 = départ).
    private var mainLineIndices: [MoveTree.Index] {
        var indices = [game.startingIndex]
        var idx = game.startingIndex
        while game.moves.hasIndex(after: idx) {
            idx = game.moves.index(after: idx)
            indices.append(idx)
        }
        return indices
    }

    /// Recharge évals et verdicts d'un instantané disque dans les caches.
    private func restore(_ snapshot: AnalysisEvalStore.Snapshot) {
        for (ply, index) in mainLineIndices.enumerated() {
            if let dto = snapshot.evals[ply] {
                evalCache[index] = CachedEval(
                    winPercent: dto.winPercent, pawns: dto.pawns,
                    bestLan: dto.bestLan, gapToSecondBest: dto.gapToSecondBest,
                    secondBestLan: dto.secondBestLan, pv: dto.pv,
                    isRefined: dto.isRefined ?? false
                )
            }
            if ply > 0, let dto = snapshot.verdicts[ply],
               let quality = MoveQuality(rawValue: dto.quality) {
                var explanation: MoveExplanation?
                if let expl = dto.explanation {
                    explanation = MoveExplanation(
                        motif: AnalysisEvalStore.motif(from: expl.motif),
                        materialLoss: expl.materialLoss,
                        refutationSAN: expl.refutationSAN
                    )
                }
                moveEvaluations[index] = AnalysisMoveEvaluation(
                    winPercentAfterMover: dto.winPercentAfterMover,
                    quality: quality,
                    explanation: explanation
                )
            }
        }
        persistedVerdictCount = moveEvaluations.count
    }

    /// Photographie les caches de la ligne principale.
    private func makeSnapshot() -> AnalysisEvalStore.Snapshot {
        var snapshot = AnalysisEvalStore.Snapshot()
        for (ply, index) in mainLineIndices.enumerated() {
            if let cached = evalCache[index] {
                snapshot.evals[ply] = AnalysisEvalStore.PositionEval(
                    winPercent: cached.winPercent, pawns: cached.pawns,
                    bestLan: cached.bestLan, gapToSecondBest: cached.gapToSecondBest,
                    secondBestLan: cached.secondBestLan, pv: cached.pv,
                    isRefined: cached.isRefined
                )
            }
            if ply > 0, let evaluation = moveEvaluations[index] {
                snapshot.verdicts[ply] = AnalysisEvalStore.MoveVerdict(
                    winPercentAfterMover: evaluation.winPercentAfterMover,
                    quality: evaluation.quality.rawValue,
                    explanation: evaluation.explanation.map {
                        AnalysisEvalStore.Explanation(
                            motif: AnalysisEvalStore.motifDTO($0.motif),
                            materialLoss: $0.materialLoss,
                            refutationSAN: $0.refutationSAN
                        )
                    }
                )
            }
        }
        return snapshot
    }

    /// Sauve si de nouveaux verdicts existent depuis la dernière écriture —
    /// y compris une classification PARTIELLE (écran quitté en cours de
    /// route) : au prochain chargement, la revue reprendra où elle en était.
    private func persistAnalysisIfNeeded() {
        guard let key = persistenceKey, moveEvaluations.count > persistedVerdictCount else { return }
        AnalysisEvalStore.save(makeSnapshot(), key: key)
        persistedVerdictCount = moveEvaluations.count
    }

    // MARK: Ouverture (ECO)

    private(set) var openingName: EcoOpening?

    // MARK: Initialisation

    init(source: AnalysisSource) {
        let newGame: Game
        switch source {
        case let .pgn(pgn):
            // PGNLoader et non `Game(pgn:)` brut : le parseur ChessKit refuse
            // des parties légales (prise en passant, roque avec échec…) que la
            // bibliothèque, elle, avait importées via PGNLoader. Le même texte
            // passait donc l'import puis arrivait ICI sur un plateau VIDE —
            // « Aucun coup joué », sans un mot d'erreur (rapport du 17/08).
            // L'entrée de l'analyse doit être au moins aussi robuste que celle
            // de la bibliothèque qui l'alimente.
            newGame = PGNLoader.game(from: pgn) ?? Game()
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
        // Analyse DÉJÀ FAITE ? Le cache disque la restitue entière — évals,
        // verdicts, explications — avant même que le moteur démarre : la
        // partie s'ouvre classifiée, `classifyNode` saute les nœuds connus,
        // et seul l'affinage de la position affichée repart. Demande du
        // 17/08 : « ne pas avoir à refaire les analyses au rechargement ».
        if isGameReview {
            persistenceKey = AnalysisEvalStore.key(for: newGame)
            if let key = persistenceKey, let snapshot = AnalysisEvalStore.load(key: key) {
                restore(snapshot)
            }
        }
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
        let controller = EngineController()

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
        // Une classification interrompue n'est pas perdue : ce qui est déjà
        // classé part sur le disque, la revue reprendra là au prochain
        // chargement.
        persistAnalysisIfNeeded()
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
        // En REVUE, ne PAS relancer d'analyse en continu au retour sur l'écran :
        // le cache suffit, le moteur reste au repos. En exploration, si.
        guard isGameReview else {
            startLiveAnalysis()
            return
        }
        // 🐛 Revue INCOMPLÈTE : la reprendre, sinon plus personne ne la
        // redemandera jamais.
        //
        // Bug rapporté le 14/08/2026 — « analyse ouverte après une partie :
        // ni graphique, ni coups pré-calculés, et *Moteur en attente*
        // affiché », intermittent. `classifyMainLine()` est mis en FILE
        // derrière le démarrage du moteur (~1 s, réseau NNUE de 78 Mo) et son
        // maillon commence par `guard !isTornDown`. Un écran marqué disparu
        // pendant cette seconde-là voyait donc sa classification abandonnée en
        // silence — puis rien ne la relançait : la reprise par `setupEngine()`
        // ci-dessus ne vaut que si le moteur avait été LIBÉRÉ en partant, ce
        // qui n'est pas le cas quand il n'était pas encore créé. Le moteur
        // restant bien vivant, aucune bannière ne prévenait : l'écran affichait
        // « Moteur en attente » pour toujours.
        //
        // Couvre du même coup l'écran quitté EN COURS de revue : la boucle sort
        // sur `isTornDown` et laissait la partie à moitié classée, courbe
        // tronquée, définitivement.
        //
        // Sûr à rappeler : `classifyNode` ignore les nœuds déjà en cache, donc
        // une reprise ne recalcule que ce qui manque. Le test porte sur ce qui
        // MANQUE, pas sur un simple drapeau : c'est la seule question qui
        // compte pour l'utilisateur.
        if isEngineUnavailable || isMainLineFullyClassified {
            showCachedEval(at: currentIndex)
        } else {
            classifyMainLine()
        }
    }

    /// Vrai quand chaque coup de la ligne principale porte son évaluation.
    ///
    /// Volontairement fondé sur les DONNÉES et non sur un drapeau de
    /// progression : un drapeau ment dès que la classification s'interrompt
    /// sans le remettre à zéro, ce qui est précisément le cas ici.
    private var isMainLineFullyClassified: Bool {
        var index = game.startingIndex
        while game.moves.hasIndex(after: index) {
            index = game.moves.index(after: index)
            if moveEvaluations[index] == nil { return false }
        }
        return true
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

    /// Génération de lecture automatique — voir ``startAutoplay()``.
    private var autoplayGeneration = 0

    private func startAutoplay() {
        guard canGoNext else { return }
        autoplayGeneration &+= 1
        let generation = autoplayGeneration
        autoplayTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.canGoNext else { break }
                self.advance()
            }
            // Ne remettre le suivi à zéro que si c'est bien CETTE tâche qui est
            // enregistrée. Sans le jeton, deux appuis rapprochés sur ⏯ (stop
            // puis start avant que l'ancienne tâche ne se réveille de son
            // `Task.sleep`) faisaient annuler par l'ancienne le suivi de la
            // NOUVELLE : `isAutoplaying` repassait à faux alors que la partie
            // continuait de se dérouler, et `stopAutoplay()` n'avait plus rien
            // à annuler — lecture inarrêtable jusqu'à la fin de la ligne.
            guard let self, self.autoplayGeneration == generation else { return }
            self.autoplayTask = nil
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
        // Meilleur coup et candidats valent pour la position AFFICHÉE : une
        // navigation les périme aussitôt, la nouvelle analyse les recalcule.
        bestLiveMoveLAN = nil
        candidateMoves = []
    }

    /// Construit les coups candidats (SAN + éval POV Blancs) depuis les LAN et
    /// scores par rang de l'analyse en continu.
    private func buildCandidates(
        lanByRank: [Int: String], scoreByRank: [Int: Double], mover: Piece.Color
    ) -> [Candidate] {
        (1...3).compactMap { rank -> Candidate? in
            guard let lan = lanByRank[rank], lan.count >= 4,
                  let score = scoreByRank[rank] else { return nil }
            let from = Square(String(lan.prefix(2)))
            let to = Square(String(lan.dropFirst(2).prefix(2)))
            return Candidate(
                rank: rank, from: from, to: to, lan: lan,
                san: sanForLAN(lan) ?? SANFormatter.display("\(from.notation)\(to.notation)"),
                eval: Self.evalLabel(score: score, moverIsWhite: mover == .white)
            )
        }
    }

    /// Notation algébrique d'un coup LAN dans la position AFFICHÉE — `nil` si le
    /// coup n'y est pas jouable (candidat périmé).
    private func sanForLAN(_ lan: String) -> String? {
        guard lan.count >= 4 else { return nil }
        let from = Square(String(lan.prefix(2)))
        let to = Square(String(lan.dropFirst(2).prefix(2)))
        var scratch = board
        guard scratch.canMove(pieceAt: from, to: to),
              let move = scratch.move(pieceAt: from, to: to) else { return nil }
        return move.san
    }

    /// Éval compacte POV Blancs. `scoreByRank` est POV du TRAIT (convention
    /// UCI) et encode un mat en ~±10 000 (voir la boucle live) : on repasse au
    /// point de vue des Blancs puis on formate en pions ou en « M<n> ».
    private static func evalLabel(score: Double, moverIsWhite: Bool) -> String {
        let white = moverIsWhite ? score : -score
        if abs(white) >= 9000 {
            let mateIn = max(1, Int((10_000 - abs(white)).rounded()))
            return white > 0 ? "M\(mateIn)" : "−M\(mateIn)"
        }
        let pawns = white / 100
        let sign = pawns > 0 ? "+" : (pawns < 0 ? "−" : "")
        return "\(sign)\(String(format: "%.1f", abs(pawns)))"
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

    /// POURQUOI le coup affiché était mauvais — la phrase, pas l'étiquette.
    ///
    /// `nil` pour tout coup sain, et pour les fautes dont la réfutation ne dit
    /// rien de nommable : le bandeau coach n'affiche alors pas de seconde
    /// ligne, ce qui est le comportement voulu et non un manque à combler.
    ///
    /// Pas de repli sur les annotations d'un PGN importé, contrairement à
    /// ``lastMoveQuality`` : un « ?? » écrit par quelqu'un d'autre dit qu'il y
    /// a faute, jamais laquelle.
    var lastMoveExplanation: MoveExplanation? {
        moveEvaluations[currentIndex]?.explanation
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

        if isGameReview {
            // REVUE d'une partie : l'analyse a DÉJÀ été calculée (classification
            // de fond). Naviguer ne relance donc RIEN — l'évaluation et les
            // flèches (vertes de revue, rétrospective) sont lues dans le cache,
            // le moteur reste au repos. C'est le « le moteur ne recommence pas
            // à recalculer à chaque coup ». Une position pas encore évaluée
            // (variante jouée, ou coup que la classification n'a pas encore
            // atteint) est classée UNE fois par ``ensureEvaluatedLazily`` —
            // sans jamais rallumer l'analyse en continu.
            showCachedEval(at: currentIndex)
            ensureEvaluatedLazily(at: currentIndex)
        } else {
            // EXPLORATION d'une position (scan, FEN, éditeur) : aucune
            // classification préalable. L'analyse en continu est la SEULE
            // source d'évaluation et de flèches — elle recalcule donc bien la
            // nouvelle position à chaque coup joué, c'est voulu.
            startLiveAnalysis()
        }
    }

    /// Affiche l'évaluation MISE EN CACHE d'une position (revue de partie),
    /// instantanément et sans toucher au moteur. `pawns` est déjà du point de
    /// vue des Blancs, borné ±10 (un mat forcé y vaut ±10, on l'affiche alors
    /// comme un gros avantage plutôt qu'en « M<n> » — détail acceptable en
    /// revue). Ne fait rien si la position n'est pas encore évaluée.
    private func showCachedEval(at index: MoveTree.Index) {
        guard let cached = evalCache[index] else { return }
        currentEvalCp = Int((cached.pawns * 100).rounded())
        currentEvalMate = nil
        liveDepth = nil
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

    // MARK: Dérouler la meilleure ligne (« Jouer le meilleur coup »)

    /// Vrai quand l'analyse en continu tient un meilleur coup JOUABLE sur la
    /// position affichée — condition d'activation du bouton « Jouer le
    /// meilleur coup ». Faux tant que rien n'est calculé et sur une position
    /// terminale (mat/pat), où le moteur ne propose plus de coup.
    var canPlayBestMove: Bool {
        bestMoveSquares != nil
    }

    /// Cases (départ, arrivée) du meilleur coup courant, revalidées contre la
    /// position affichée — `nil` si le LAN est absent, mal formé, ou périmé
    /// (ne correspond plus au trait/à un coup légal).
    private var bestMoveSquares: (from: Square, to: Square)? {
        guard let lan = bestLiveMoveLAN, lan.count >= 4 else { return nil }
        let from = Square(String(lan.prefix(2)))
        let to = Square(String(lan.dropFirst(2).prefix(2)))
        guard board.position.piece(at: from)?.color == board.position.sideToMove,
              board.canMove(pieceAt: from, to: to)
        else { return nil }
        return (from, to)
    }

    /// Joue le meilleur coup du moteur sur la position affichée et avance d'un
    /// demi-coup. L'analyse en continu repart aussitôt sur la nouvelle position
    /// et propose le meilleur coup du camp adverse : tap après tap, on déroule
    /// la meilleure ligne « coup par coup, le meilleur de chaque côté » — ce
    /// qui manquait pour explorer une position scannée/FEN sans rejouer chaque
    /// coup à la main.
    ///
    /// La pièce de promotion est lue DANS le LAN du moteur (5e caractère, dame
    /// par défaut) : c'est le moteur qui choisit, on ne dérange pas
    /// l'utilisateur avec le sélecteur.
    func playBestMove() {
        guard let lan = bestLiveMoveLAN else { return }
        playMove(lan: lan)
    }

    /// Joue un coup candidat (liste ou flèche cliquable) pour explorer sa
    /// variante — même mécanique que « Jouer le meilleur coup », coup au choix.
    func playCandidate(_ candidate: Candidate) {
        playMove(lan: candidate.lan)
    }

    /// Joue un coup désigné par son LAN et avance d'un demi-coup. Revalide
    /// contre la position affichée (candidat périmé ignoré) et gère la
    /// promotion depuis le LAN du moteur (5e caractère, dame par défaut).
    private func playMove(lan: String) {
        stopAutoplay()
        guard lan.count >= 4 else { return }
        let from = Square(String(lan.prefix(2)))
        let to = Square(String(lan.dropFirst(2).prefix(2)))
        guard board.position.piece(at: from)?.color == board.position.sideToMove,
              board.canMove(pieceAt: from, to: to) else { return }

        var scratch = board
        guard let move = scratch.move(pieceAt: from, to: to) else { return }
        clearSelection()

        if case .promotion = scratch.state {
            commit(move: scratch.completePromotion(of: move, to: Self.promotionKind(fromLAN: lan)))
        } else {
            commit(move: move)
        }
    }

    /// Pièce de promotion encodée dans un LAN moteur (« e7e8q » → dame). Dame
    /// par défaut si le suffixe est absent ou non reconnu — le choix quasi
    /// universel, et de toute façon celui du moteur dans l'écrasante majorité.
    private static func promotionKind(fromLAN lan: String) -> Piece.Kind {
        switch lan.dropFirst(4).first {
        case "n": return .knight
        case "b": return .bishop
        case "r": return .rook
        default: return .queen
        }
    }

    // MARK: Analyse en continu (MultiPV = 3) de la position affichée

    /// Contrairement à l'indice du mode Jouer, toujours active dès qu'une
    /// position est affichée — pas de bascule utilisateur, voir le brief
    /// ("Analyse live : éval + barre d'avantage... MultiPV = 3").
    private func startLiveAnalysis() {
        // GARANTIE : en REVUE d'une partie, on ne lance JAMAIS l'analyse en
        // continu (profonde). La revue se contente du cache de la
        // classification ; le moteur reste au repos une fois la passe finie.
        // Ce garde-fou rend IMPOSSIBLE tout départ en « analyse profonde »
        // quand on revoit une partie — quelle que soit la voie d'appel (course
        // de cycle de vie à l'ouverture, reprise après génération de puzzles,
        // etc.). L'analyse en continu ne sert qu'à EXPLORER une position
        // (FEN/scan/éditeur, `isGameReview == false`).
        guard !isGameReview else { return }

        // ⚠️ ORDRE CRITIQUE. Le flux de réponses de ChessKitEngine est à
        // ITÉRATEUR UNIQUE : deux `for await` qui le consomment EN MÊME TEMPS
        // se volent les réponses, et l'un termine l'itérateur sous les pieds
        // de l'autre. On DOIT donc arrêter l'analyse en continu PRÉCÉDENTE —
        // une tâche non structurée qui itère encore le flux — AVANT tout
        // nouveau consommateur, la recherche de MENACE comprise (elle itère
        // le flux elle aussi). L'arrêt était auparavant enfilé DERRIÈRE la
        // menace : celle-ci iterait donc le flux pendant que l'ancienne
        // analyse tournait encore — d'où « le meilleur coup ne se rafraîchit
        // qu'au tout premier demi-coup » (au 1er coup il n'y a pas d'ancienne
        // analyse, moteur frais, donc pas de conflit ; ensuite si).
        enqueueEngineWork { [weak self] in await self?.stopLiveAnalysisIfNeeded() }

        // La menace AVANT l'analyse en continu : cette dernière tourne en
        // recherche bornée qui ne rend la main qu'à sa fin, la menace (200 ms)
        // doit donc passer devant. Elle est maintenant SÉRIALISÉE derrière
        // l'arrêt ci-dessus, plus aucun itérateur concurrent.
        computeThreat()

        enqueueEngineWork { [weak self] in
            // Plus de `stopLiveAnalysisIfNeeded` ici : déjà fait en tête de
            // file, avant la menace. On garde le contrôle `isTornDown` : la
            // menace a pu s'exécuter juste après un `handleViewDisappear`.
            guard let self, let engine = self.engine, !self.isTornDown else { return }

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

                readLoop: for await response in await engine.responseStream {
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
                        // `break readLoop` (labellisé) et non `break` : ce
                        // dernier ne sortait que du `switch`, la boucle
                        // continuait à consommer le flux d'une position périmée.
                        guard self.isLiveAnalyzing, self.board.position.fen == fen else { break readLoop }
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
                            // Le meilleur coup JOUABLE (rang 1), LAN complet
                            // avec promotion — sert « Jouer le meilleur coup ».
                            if rank == 1 { self.bestLiveMoveLAN = firstMove }
                            self.hintMoves = HintMoveBuilder.build(lanByRank: lanByRank, scoreByRank: scoreByRank)
                            self.candidateMoves = self.buildCandidates(lanByRank: lanByRank, scoreByRank: scoreByRank, mover: mover)
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
    /// Vrai entre la mise en FILE d'une classification et son démarrage réel.
    ///
    /// ``isClassifying`` ne suffit pas à empêcher les doublons : il ne passe à
    /// vrai qu'une fois le maillon ARRIVÉ à son tour, soit ~1 s plus tard (le
    /// démarrage du moteur le précède). Pendant cette seconde, un second
    /// `onAppear` — SwiftUI en émet parfois deux — en enfilerait une deuxième,
    /// qui ne recalculerait rien (tout serait en cache) mais ferait clignoter
    /// la barre de progression.
    private var isClassificationPending = false

    private func classifyMainLine() {
        guard !isClassificationPending else { return }
        isClassificationPending = true
        enqueueEngineWork { [weak self] in
            guard let self else { return }
            self.isClassificationPending = false
            guard let engine = self.engine, !self.isTornDown else { return }
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

            // Classification SÉQUENTIELLE, « à la suite » : tous les coups sont
            // classés dans l'ORDRE, du premier au dernier. C'est ce que
            // l'utilisateur attend d'une revue — la passe avance visiblement
            // coup par coup et met tout en cache, puis s'arrête (le moteur ne
            // recalcule plus rien ensuite, voir `afterNavigate`/`startLiveAnalysis`).
            //
            // Le rafraîchissement dérivé est COALESCÉ (un tous les 4 nœuds)
            // plutôt que relancé après chaque nœud, qui rendait la boucle
            // quadratique sur le MainActor.
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
            self.persistAnalysisIfNeeded()
            // Moteur déclaré indisponible en cours de route : inutile de faire
            // quoi que ce soit sur une instance morte — la bannière est levée,
            // « Réessayer » relancera tout.
            guard !self.isTornDown, !self.isEngineUnavailable else { return }
            // Classification TERMINÉE : en REVUE, l'analyse s'ARRÊTE ici. La
            // navigation lira le cache (éval + flèches), le moteur reste au
            // repos — plus de recalcul à chaque coup. On se contente d'afficher
            // l'éval en cache de la position courante. (L'EXPLORATION d'une
            // position sans coups a démarré l'analyse en continu plus haut et
            // n'atteint jamais cette ligne.)
            self.showCachedEval(at: self.currentIndex)
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
            // Montre l'éval fraîchement calculée SANS rallumer l'analyse en
            // continu : en revue, classer une variante ne doit pas remettre le
            // moteur à tourner en boucle sur chaque position.
            self.showCachedEval(at: self.currentIndex)
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
        var before = evalBefore
        var after = evalAfter
        var winPercentBeforeMover = mover == .white ? before.winPercent : 100 - before.winPercent
        var winPercentAfterMover = mover == .white ? after.winPercent : 100 - after.winPercent

        // Affinage AU FIL DE L'EAU : si le verdict hésite, on approfondit ICI,
        // avant d'afficher quoi que ce soit. Le coup ne reçoit donc jamais
        // d'étiquette qu'on lui retirerait ensuite — une classification
        // révisée sous les yeux du lecteur détruirait la confiance qu'on
        // cherche précisément à gagner.
        //
        // En surchauffe, on renonce à l'affinage plutôt qu'à la passe de base :
        // mieux vaut tous les coups classés normalement que la moitié classés
        // finement. Même renoncement en MODE ÉCONOMIE D'ÉNERGIE — mais sans
        // toucher au budget de base, contrairement au chemin thermique : la
        // surchauffe est rare et transitoire, le mode économie est un état
        // banal (activé à 20 % de batterie) où dégrader AUSSI la passe de
        // base se paierait trop souvent. L'affinage est l'essentiel du
        // surcoût de la revue (≈ ×2,2) : c'est lui qu'on sacrifie, les
        // verdicts de base restent pleins.
        //
        // Un coup de THÉORIE sera classé .book, un coup FORCÉ .best, quelle
        // que soit l'éval (voir ``MoveClassifier/classify(_:)``) : affiner
        // leur verdict serait payer jusqu'à 2 × 3M nœuds pour une étiquette
        // qui n'en tient pas compte. Calculés ICI, avant l'affinage, et
        // réutilisés dans l'`Input` plus bas.
        let isBook = EcoOpeningLookup.isInBook(sanPath(to: index), in: EcoOpeningLoader.bookLines)
        let isForced = legalMoveCount(at: parentIndex) == 1

        if !isBook, !isForced,
           !ThermalMonitor.shared.isThrottling,
           !ProcessInfo.processInfo.isLowPowerModeEnabled,
           isBorderline(loss: max(0.0, winPercentBeforeMover - winPercentAfterMover)) {
            // Les closures donnent à la règle d'arrêt la DISTANCE du verdict
            // provisoire à la frontière la plus proche : pendant la recherche
            // du parent, l'éval de l'enfant est celle déjà connue, et
            // réciproquement (rafraîchie si le parent vient d'être affiné).
            let isWhite = mover == .white
            let afterForParent = winPercentAfterMover
            if let deeperBefore = await refinedEval(
                at: parentIndex, engine: engine,
                lossDistance: { whiteWinPercent in
                    let beforeMover = isWhite ? whiteWinPercent : 100 - whiteWinPercent
                    return Self.distanceToNearestThreshold(
                        loss: max(0.0, beforeMover - afterForParent))
                }
            ) {
                before = deeperBefore
                winPercentBeforeMover = mover == .white
                    ? deeperBefore.winPercent : 100 - deeperBefore.winPercent
            }
            // RE-TEST entre les deux affinages : si celui du parent a déjà
            // sorti la perte de la bande d'hésitation, l'enfant n'a plus rien
            // à trancher — on s'épargne au moins son plancher d'1M nœuds. La
            // paire mixte qui en résulte (parent affiné, enfant au budget de
            // base) est déjà un état normal du système : c'est exactement ce
            // que produit la garde anti-double-affinage dans l'autre sens.
            if isBorderline(loss: max(0.0, winPercentBeforeMover - winPercentAfterMover)) {
                let beforeForChild = winPercentBeforeMover
                if let deeperAfter = await refinedEval(
                    at: index, engine: engine,
                    lossDistance: { whiteWinPercent in
                        let afterMover = isWhite ? whiteWinPercent : 100 - whiteWinPercent
                        return Self.distanceToNearestThreshold(
                            loss: max(0.0, beforeForChild - afterMover))
                    }
                ) {
                    after = deeperAfter
                    winPercentAfterMover = mover == .white
                        ? deeperAfter.winPercent : 100 - deeperAfter.winPercent
                }
            }
        }

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
            isBestMove: before.bestLan == move.lan,
            gapToSecondBest: before.gapToSecondBest,
            isBook: isBook,
            isSacrifice: isSacrifice,
            sacrificeImmediatelyRecaptured: MoveClassifier.isImmediatelyRecaptured(move, byNext: nextMove),
            bestMoveWasTactical: bestMoveIsTactical(lan: before.bestLan, at: parentIndex),
            isForced: isForced
        ))

        moveEvaluations[index] = AnalysisMoveEvaluation(
            winPercentAfterMover: winPercentAfterMover,
            quality: quality,
            // Seulement les fautes : un bon coup n'a rien à expliquer, et la
            // variante d'après un bon coup raconte la suite de la partie, pas
            // une punition. `evalAfter.pv` est la réponse du moteur À CE
            // COUP — la réfutation, déjà payée par l'évaluation ci-dessus.
            explanation: quality.isFault
                ? explanation(at: index, refutationLANs: after.pv)
                : nil
        )
        if let assessment = quality.pgnAssessment {
            game.annotate(moveAt: index, assessment: assessment)
        }
        // Rafraîchissement laissé à l'APPELANT : reparcourir tout l'arbre après
        // CHAQUE nœud rendait la classification quadratique sur le MainActor. La
        // boucle de masse (Phase 2) le coalesce ; le nœud isolé
        // (``ensureEvaluatedLazily``) le fait aussitôt.
    }

    /// Le « pourquoi » d'un coup, à partir de la variante que le moteur
    /// enchaîne sur la position d'après.
    ///
    /// Purement local : aucun appel moteur supplémentaire — la variante est
    /// déjà en cache —, donc le coût d'explication d'une revue de quarante
    /// coups est celui de quarante rejeux de douze demi-coups sur un plateau.
    private func explanation(
        at index: MoveTree.Index, refutationLANs: [String]
    ) -> MoveExplanation? {
        guard let position = game.positions[index] else { return nil }
        return MoveExplainer.explain(
            .init(positionAfterMove: position, refutationLANs: refutationLANs)
        )
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
            secondBestLan: rankedDict[2]?.lan,
            // Tronquée à la source : le cache garde une entrée par nœud d'une
            // partie entière, et rien au-delà ne sera jamais lu.
            pv: Array(best.pv.prefix(MoveExplainer.maxPlies))
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
        // Ouverture (théorie) : positions calmes, budget réduit. Sinon, budget
        // ADAPTÉ À L'APPAREIL (``DevicePerformance``) : plus profond sur
        // matériel moderne, plus sobre en bas de gamme. Le moteur recompilé
        // (NEON) atteint ces budgets bien plus vite, ce qui autorise plus de
        // profondeur sans exploser le temps total. La table de hachage persiste
        // d'une position à l'autre (même instance), ce qui amortit encore.
        return inBook ? 80_000 : DevicePerformance.classificationNodeBudget
    }

    // MARK: Affinage des verdicts limites

    /// Demi-largeur de la bande d'incertitude, en points de probabilité de
    /// gain, autour des seuils qui DÉCLENCHENT un signalement.
    ///
    /// Mesuré sur neuf parties de tournoi (887 coups, quatre budgets, ~25
    /// milliards de nœuds) : à 300 000 nœuds, **4,62 %** des coups reçoivent
    /// un verdict qu'un budget 33 fois supérieur contredirait — un coup sur
    /// 22 passe à tort de « signalé » à « non signalé » ou l'inverse.
    ///
    /// Augmenter le budget PARTOUT serait un mauvais calcul : dix fois plus
    /// d'effort ne ramène ce chiffre qu'à 1,69 %. Les erreurs ne sont pas
    /// réparties au hasard, elles se concentrent autour des seuils — dépenser
    /// du calcul sur un coup qui perd 40 points ne sert à rien, c'est une
    /// faute à n'importe quelle profondeur.
    ///
    /// Avec cette bande, 14,9 % des coups sont recalculés. ⚠️ **Correction du
    /// 18/08** : le premier calcul supposait qu'un coup recalculé était
    /// corrigé — faux. Rejoué honnêtement sur les 887 coups : il reste
    /// **1,92 %** de désaccords (sur 4,62 % sans affinage, soit −59 %), dont
    /// 7 où 3M reste en désaccord avec 10M et 4 où 3M INTRODUIT le
    /// désaccord — les budgets intermédiaires ne sont pas monotones. Le coût
    /// mesuré ×2,95 tombe à ×2,73 avec la garde anti-double-affinage, puis
    /// ≈ ×2,2 avec l'arrêt anticipé (voir ``RefinementStopRule``).
    ///
    /// La bande a été choisie sur cette courbe, chronomètre en main :
    ///
    ///     ±1,0 → ×1,96   59 % des erreurs corrigées   il reste 1,92 %
    ///     ±1,5 → ×2,42   73 %                         il reste 1,24 %
    ///     ±2,0 → ×2,95   85 %                         il reste 0,68 %   ← ici
    ///     ±3,0 → ×3,81   93 %                         il reste 0,34 %
    ///
    /// Au-delà de ±2 on paie surtout des recalculs qui confirment le verdict.
    private static let refinementBand = 2.0

    /// Budget de la seconde recherche.
    ///
    /// ⚠️ **Hypothèse réfutée par la mesure (16/08/2026).** On lisait ici que
    /// la seconde recherche, lancée sur la MÊME position sans réinitialiser le
    /// moteur, hériterait de la table de transposition et coûterait donc MOINS
    /// que le rapport des budgets (×10). Chronométré sur les 887 coups des
    /// neuf parties : un coup affiné coûte **×13,1** un coup de base
    /// (3 093 ms contre 236 ms, deux recherches à chaque fois). La table
    /// n'offre aucune remise — la recherche profonde élargit l'arbre et le
    /// débit en nœuds baisse plus vite que la table ne fait gagner.
    ///
    /// Le bilan reste bon (×2,95 au total contre ×11,4 pour tout approfondir),
    /// mais il vaut par le CIBLAGE, pas par une remise qui n'existe pas.
    private static let refinementNodes = 3_000_000

    /// Seuils de signalement — les seuls qui comptent. Franchir la frontière
    /// Excellent/Bon coup ne change rien pour le lecteur : les deux sont bons.
    private static var refinementThresholds: [Double] {
        [
            MoveClassifier.inaccuracyThreshold,
            MoveClassifier.mistakeThreshold,
            MoveClassifier.blunderThreshold,
        ]
    }

    /// Ce verdict est-il trop proche d'une frontière pour être tranché au
    /// budget de base ?
    private func isBorderline(loss: Double) -> Bool {
        Self.refinementThresholds.contains { abs(loss - $0) <= Self.refinementBand }
    }

    /// Distance d'une perte à la frontière de signalement la plus proche —
    /// ce que la règle d'arrêt anticipé compare à sa marge de sécurité.
    static func distanceToNearestThreshold(loss: Double) -> Double {
        refinementThresholds.map { abs(loss - $0) }.min() ?? .infinity
    }

    /// Recalcule une position avec le budget d'affinage, en ÉCRASANT le cache.
    ///
    /// Le cache est mis à jour à dessein : la position vaudra ce verdict-là
    /// pour le reste de la session, et une navigation ultérieure ne doit pas
    /// retomber sur l'évaluation grossière.
    private func refinedEval(
        at index: MoveTree.Index, engine: EngineController,
        lossDistance: @escaping (Double) -> Double
    ) async -> CachedEval? {
        guard let position = game.positions[index] else { return nil }
        if terminalCachedEval(at: index) != nil { return evalCache[index] }
        // DÉJÀ affiné (comme parent du coup précédent, ou l'inverse) : le
        // travail est fait, ne pas le repayer.
        if let cached = evalCache[index], cached.isRefined { return cached }

        // ARRÊT ANTICIPÉ (étude du 18/08) : la recherche de 3M nœuds est
        // arrêtée dès qu'elle a tranché — éval stable sur plusieurs
        // profondeurs ET verdict loin de toute frontière. 47 % des affinages
        // étaient déjà stables à 1M nœuds : autant d'arrêts au tiers du
        // coût, dans le MÊME arbre, sans redémarrage.
        let sideIsWhite = position.sideToMove == .white
        let box = RefinementStopBox()
        // Le plancher suit le même facteur thermique que le budget lui-même.
        box.rule.nodesFloor = max(1, Int(1_000_000 * ThermalMonitor.shared.nodeFactor))

        let ranked = await rankedEval(
            fen: position.fen, engine: engine,
            nodes: Self.refinementNodes,
            // Plafond PROPRE : celui de la passe de base tronquerait la
            // recherche approfondie au point de la rendre inutile — on aurait
            // payé l'attente sans gagner la précision.
            capMs: DevicePerformance.refinementCapMs,
            multipv: 2,
            onDepth: { depth, nodes, cp in
                let mover = EvalConversion.winPercentage(cp: cp)
                let white = sideIsWhite ? mover : 100 - mover
                return box.rule.shouldStop(
                    depth: depth, nodes: nodes,
                    winPercent: white, lossDistance: lossDistance(white)
                )
            }
        )
        guard var refined = makeCachedEval(rankedDict: ranked, sideToMove: position.sideToMove) else {
            return nil
        }
        refined.isRefined = true
        evalCache[index] = refined
        return refined
    }

    /// Boîte de référence pour muter la règle d'arrêt depuis la closure
    /// `@Sendable` de consommation du flux moteur.
    private final class RefinementStopBox: @unchecked Sendable {
        var rule = RefinementStopRule()
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
    /// thread.
    ///
    /// ⚠️ **Correction du 16/08/2026.** Ce commentaire affirmait que ce budget
    /// atteignait « la profondeur 18-20 ». Mesuré sur neuf parties de tournoi
    /// réelles (887 coups), la profondeur médiane est **15**, avec un minimum
    /// de 9 en milieu de partie encombré. La mesure d'origine devait porter
    /// sur des positions favorables. C'est ce qui a motivé l'affinage des
    /// verdicts limites — voir ``refinementBand``. Le plafond `capMs` ne mord donc qu'en régime dégradé, ce qui
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
        nodes: Int = 300_000, capMs: Int = DevicePerformance.classificationCapMs, multipv: Int,
        /// Appelé à chaque `info` scoré de la PV n°1 ; retourner `true`
        /// envoie `stop` — la recherche rend alors son `bestmove` avec l'éval
        /// courante. Sert UNIQUEMENT à l'affinage (arrêt anticipé).
        onDepth: ((_ depth: Int, _ nodes: Int?, _ cp: Int) -> Bool)? = nil
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
            var stopSent = false
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
                    // Arrêt anticipé : un seul `stop`, puis on laisse le
                    // `bestmove` clore la boucle normalement.
                    if !stopSent, rank == 1, let onDepth, let depth = info.depth,
                       onDepth(depth, info.nodes, cp) {
                        stopSent = true
                        await engine.send(.stop)
                    }
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
            PersistenceLog.save(context)
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
    /// La ligne principale réduite à ce que les métriques regardent : qui a
    /// joué, ce que le coup a coûté, et s'il était encore dans la théorie.
    ///
    /// Construite depuis les mêmes `moveEvaluations` que la précision, mais
    /// SANS pondération : la perte brute est la grandeur comparable d'une
    /// partie à l'autre (voir ``GameAnalysisMetrics``).
    func analysisMoveSeries() -> [GameAnalysisMetrics.Move] {
        var moves: [GameAnalysisMetrics.Move] = []
        var idx = game.startingIndex
        while game.moves.hasIndex(after: idx) {
            let parentIdx = idx
            idx = game.moves.index(after: idx)
            guard let evaluation = moveEvaluations[idx], let evalBefore = evalCache[parentIdx] else { continue }
            let mover = idx.color
            let beforeMoverPOV = mover == .white ? evalBefore.winPercent : 100 - evalBefore.winPercent
            moves.append(GameAnalysisMetrics.Move(
                mover: mover,
                loss: max(0, beforeMoverPOV - evaluation.winPercentAfterMover),
                isBook: evaluation.quality == .book,
                winPercentBefore: beforeMoverPOV
            ))
        }
        return moves
    }

    /// Bilan chiffré de la partie, tel qu'il sera persisté. `nil` tant que la
    /// ligne principale n'est pas entièrement classée : des métriques
    /// partielles ne sont pas des métriques, elles sont un mensonge lisible.
    var analysisMetrics: GameAnalysisMetrics? {
        guard isGameReview, isMainLineFullyClassified else { return nil }
        return GameAnalysisMetrics.compute(
            moves: analysisMoveSeries(), accuracyByColor: accuracyByColor
        )
    }

    /// Recopie le bilan dans la partie enregistrée correspondante.
    ///
    /// Le rapprochement se fait par ``AnalysisEvalStore/key(for:)`` — la même
    /// empreinte que le cache disque, donc insensible aux en-têtes PGN. Une
    /// partie ouverte depuis un fichier extérieur n'a pas d'enregistrement :
    /// il n'y a alors rien à écrire, et ce n'est pas une erreur.
    @discardableResult
    func persistMetrics(in context: ModelContext) -> Bool {
        guard let metrics = analysisMetrics, let key = persistenceKey else { return false }
        guard let record = Self.record(matching: key, in: context) else { return false }
        guard record.apply(metrics, key: key) else { return false }
        PersistenceLog.save(context, origin: "analysisMetrics")
        return true
    }

    /// Retrouve la partie enregistrée : par empreinte si elle en porte déjà
    /// une, sinon en la calculant sur les PGN qui n'en ont pas encore (les
    /// parties d'avant ce champ). La recherche par empreinte d'abord évite de
    /// reparser toute la bibliothèque au cas courant.
    private static func record(matching key: String, in context: ModelContext) -> GameRecord? {
        var byKey = FetchDescriptor<GameRecord>(predicate: #Predicate { $0.analysisKey == key })
        byKey.fetchLimit = 1
        if let found = try? context.fetch(byKey).first { return found }

        let unkeyed = FetchDescriptor<GameRecord>(predicate: #Predicate { $0.analysisKey == nil })
        guard let candidates = try? context.fetch(unkeyed) else { return nil }
        return candidates.first { candidate in
            guard let text = candidate.pgn, !text.isEmpty,
                  let parsed = PGNLoader.game(from: text)
            else { return false }
            return AnalysisEvalStore.key(for: parsed) == key
        }
    }

    private func computeAccuracyByColor() -> [Piece.Color: Double] {
        // Deux séries parallèles, l'ordre des coups étant ce qui porte
        // l'information : la précision de chaque coup, et la probabilité de
        // gain POV BLANCS de chaque position — c'est sur cette dernière que
        // se calcule la volatilité, donc le poids des coups.
        //
        // La position de DÉPART ouvre la série : sans elle, le premier coup
        // n'aurait pas de « avant » et sa fenêtre serait décalée d'un cran.
        var whiteWinPercents: [Double] = []
        var movers: [Piece.Color] = []
        var losses: [Double] = []

        var idx = game.startingIndex
        while game.moves.hasIndex(after: idx) {
            let parentIdx = idx
            idx = game.moves.index(after: idx)
            guard let evaluation = moveEvaluations[idx], let evalBefore = evalCache[parentIdx] else { continue }
            if whiteWinPercents.isEmpty { whiteWinPercents.append(evalBefore.winPercent) }

            let mover = idx.color
            let beforeMoverPOV = mover == .white ? evalBefore.winPercent : 100 - evalBefore.winPercent

            whiteWinPercents.append(
                mover == .white ? evaluation.winPercentAfterMover : 100 - evaluation.winPercentAfterMover
            )
            movers.append(mover)
            losses.append(max(0, beforeMoverPOV - evaluation.winPercentAfterMover))
        }

        let weights = AccuracyScore.moveWeights(whiteWinPercents: whiteWinPercents)
        guard weights.count == losses.count else { return [:] }

        var result: [Piece.Color: Double] = [:]
        for color in [Piece.Color.white, .black] {
            let indices = movers.indices.filter { movers[$0] == color }
            guard !indices.isEmpty else { continue }
            result[color] = AccuracyScore.accuracy(
                winPercentLosses: indices.map { losses[$0] },
                weights: indices.map { weights[$0] }
            )
        }
        return result
    }

    // MARK: Courbe d'évaluation

    struct EvalCurvePoint: Identifiable {
        let id: MoveTree.Index
        let ply: Int
        /// POV Blancs, bornée ±10 (mat = ±10).
        let pawns: Double
        /// Qualité du coup menant à ce point (nil tant que la classification
        /// n'est pas passée) — la courbe en tire ses pastilles de moments
        /// critiques.
        var quality: MoveQuality?
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
            points.append(EvalCurvePoint(
                id: idx, ply: ply, pawns: cached.pawns,
                quality: moveEvaluations[idx]?.quality
            ))
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

    /// PGN **rechargeable** : passe par ``PGNExport``, qui ajoute
    /// `[SetUp "1"]` / `[FEN …]` quand la partie ne démarre pas de la position
    /// standard.
    ///
    /// `game.pgn` seul les omet. Pour une session ouverte sur une **FEN**
    /// (scan, éditeur de position, « Position FEN »), le PGN produit rejouait
    /// donc ses coups depuis la position standard une fois rechargé — et cette
    /// valeur alimente à la fois le partage et le `sourceGamePGN` des puzzles
    /// générés, qui héritaient du même défaut.
    var exportedPGN: String { PGNExport.pgn(for: game) }
    var currentFEN: String { board.position.fen }
}
