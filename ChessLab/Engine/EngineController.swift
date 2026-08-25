import CFairyStockfishKit
import CStockfishKit
import Foundation

/// Enveloppe le moteur Stockfish VENDORISÉ (``CStockfishKit``) et sérialise les
/// commandes UCI envoyées à une instance donnée.
///
/// Remplace ChessKitEngine : Stockfish est désormais compilé dans le projet
/// avec les bons flags (NEON/POPCNT/-O3) et piloté par un transport propre —
/// la sortie est parsée sur un thread dédié, plus sur le thread principal. Voir
/// `Vendor/CStockfish`. L'API publique de ce contrôleur est INCHANGÉE : les
/// consommateurs (Analyse, Laboratoire, Jouer) ne bougent pas.
///
/// Un seul moteur par process (Stockfish a un état global).
actor EngineController {

    private var engine: StockfishEngine

    /// Chemin FICTIF dont le DOSSIER (les ressources du bundle) contient les
    /// réseaux `nn-*.nnue` : Stockfish y cherche son réseau, comme un binaire
    /// classique cherche le sien à côté de lui.
    private static var enginePath: String {
        if let resources = Bundle.main.resourcePath {
            return resources + "/stockfish"
        }
        return "stockfish"
    }

    /// Flux des réponses UCI PARSÉES. Alimenté par un lecteur unique qui
    /// consomme les lignes brutes du moteur ; les consommateurs de l'app
    /// l'itèrent tour à tour (une seule recherche à la fois).
    private let parsed: AsyncStream<EngineResponse>
    private let parsedContinuation: AsyncStream<EngineResponse>.Continuation
    private var readerTask: Task<Void, Never>?
    /// Passe à vrai à la réception de `uciok` — le moteur a fini son handshake.
    private var uciOk = false

    private let startTimeoutMs: Int

    init(startTimeoutMs: Int = 5000) {
        self.startTimeoutMs = startTimeoutMs
        engine = StockfishEngine()
        var cont: AsyncStream<EngineResponse>.Continuation!
        parsed = AsyncStream(bufferingPolicy: .unbounded) { cont = $0 }
        parsedContinuation = cont
        EngineInstanceCounter.shared.didCreate()
    }

    deinit {
        // Rendre le process, même si personne n'a appelé `stop()` (chemin
        // d'erreur, écran détruit brutalement). Sans ça : `cstockfish_stop()`
        // jamais appelé → le drapeau global reste vrai → tous les écrans
        // suivants héritent d'un moteur qu'ils ne possèdent pas, jusqu'au kill
        // de l'app. Pire, le thread moteur continuait d'appeler le callback
        // avec un `Unmanaged.passUnretained` vers un objet désalloué —
        // use-after-free hors de toute pile Swift lisible.
        //
        // `stop()` de ``StockfishEngine`` est idempotent et ne coupe le process
        // que si CETTE instance le possède.
        engine.stop()
        readerTask?.cancel()
        moveReaderTask?.cancel()
        EngineInstanceCounter.shared.didRelease()
    }

    /// Flux des réponses UCI parsées (info, bestmove, readyok).
    var responseStream: AsyncStream<EngineResponse> {
        parsed
    }

    private(set) var didFailToStart = false

    #if DEBUG
    private(set) var sentCommands: [EngineCommand] = []
    /// `coreCount` passé au dernier démarrage — traduit en `Threads`.
    private(set) var lastStartCoreCount: Int?
    #endif

    // MARK: Lecteur unique

    /// Démarre (ou redémarre) le lecteur qui transforme les LIGNES brutes du
    /// moteur en réponses parsées, et note le `uciok` du handshake.
    private func startReader() {
        readerTask?.cancel()
        let stream = engine.lines
        readerTask = Task { [weak self] in
            for await line in stream {
                await self?.ingest(line)
            }
        }
    }

    private func ingest(_ line: String) {
        if line == "uciok" { uciOk = true }
        if let response = EngineResponse(rawValue: line) {
            parsedContinuation.yield(response)
        }
    }

    // MARK: Démarrage

    /// Démarre le moteur et attend la fin du handshake `uci → uciok`, borné à
    /// ~`startTimeoutMs`. Traduit `coreCount` en `Threads` avec la MÊME formule
    /// qu'auparavant (`max(coreCount − 1, 1)`, `nil` → 1 thread) : les
    /// consommateurs et leurs tests restent valides.
    @discardableResult
    func start(coreCount: Int? = nil, multipv: Int = 1) async -> Bool {
        if await EngineStartFailureSimulator.shared.consumeFailure() {
            didFailToStart = true
            return false
        }
        #if DEBUG
        lastStartCoreCount = coreCount
        #endif

        uciOk = false
        if !engine.isRunning {
            // Le process moteur est UNIQUE (Stockfish a un état statique). Il
            // peut encore appartenir à l'écran précédent : les libérations sont
            // asynchrones et personne ne les attend — `PlayViewModel` fait
            // `Task { await engine.stop() }` en partant, pendant que l'écran
            // suivant construit déjà son contrôleur.
            //
            // On ATTEND donc sa libération, au lieu de l'ancien comportement où
            // `cstockfish_start` sortait en silence : l'instance se croyait
            // démarrée, ne recevait aucune ligne (le callback pointait toujours
            // la précédente), échouait sur le délai de 5 s avec une bannière
            // « Moteur indisponible » indiscernable d'une panne NNUE — et
            // envoyait quand même ses commandes dans le moteur de l'autre écran.
            guard await acquireEngineProcess() else {
                didFailToStart = true
                return false
            }
        }
        startReader()

        await sendRaw(.uci)
        var iterationsLeft = max(startTimeoutMs / 20, 1)
        while !uciOk {
            if iterationsLeft <= 0 {
                didFailToStart = true
                return false
            }
            iterationsLeft -= 1
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let threads = coreCount.map { max($0 - 1, 1) } ?? 1
        await sendRaw(.setoption(id: "Threads", value: "\(threads)"))
        await sendRaw(.setoption(id: "MultiPV", value: "\(multipv)"))
        await sendRaw(.ucinewgame)
        didFailToStart = false
        return true
    }

    /// Démarre avec les réglages avancés de l'utilisateur (threads + Hash).
    @discardableResult
    func start(threads: Int, hashMB: Int, multipv: Int = 1) async -> Bool {
        guard await start(coreCount: Self.coreCount(forThreads: threads), multipv: multipv) else {
            return false
        }
        await send(.setoption(id: "Hash", value: "\(hashMB)"))
        return true
    }

    /// Traduit un nombre de threads voulu en `coreCount`.
    ///
    /// Conserve la convention historique (`coreCount = threads + 1`, retraduit
    /// en `Threads = max(coreCount − 1, 1)`) pour ne toucher à aucun appelant.
    static func coreCount(forThreads threads: Int) -> Int {
        max(threads, 1) + 1
    }

    // MARK: Envoi

    /// Envoi UCI depuis l'app. Garde : n'écrit qu'à un moteur démarré.
    func send(_ command: EngineCommand) async {
        #if DEBUG
        sentCommands.append(command)
        #endif
        guard engine.isRunning else { return }
        engine.send(command.uciString)
    }

    /// Envoi interne (handshake) : ne trace pas dans `sentCommands` et
    /// n'exige pas d'être passé par la garde publique.
    private func sendRaw(_ command: EngineCommand) async {
        guard engine.isRunning else { return }
        engine.send(command.uciString)
    }

    /// Barrière de synchronisation UCI : `isready` puis on jette tout jusqu'au
    /// `readyok`. Bornée : un moteur muet rend `false`.
    @discardableResult
    func synchronize(timeoutMs: Int = 5000) async -> Bool {
        guard engine.isRunning else { return false }
        // `responseStream` est un `AsyncStream` à **consommateur unique**.
        // Deux tâches suspendues dans `next()` sur le même flux ne se « volent »
        // pas des réponses comme le disaient les commentaires de l'app : la
        // bibliothèque standard lève un `fatalError` (« attempt to await next()
        // on more than one task »). C'est un crash immédiat, pas une
        // dégradation.
        //
        // L'invariant reposait entièrement sur la discipline d'une file
        // sérielle, plus quelques appels HORS file. On le rend au moins
        // vérifiable : le lecteur permanent du Laboratoire est un consommateur
        // à lui seul, donc `synchronize()` ne doit jamais être appelé pendant
        // qu'il vit.
        assert(
            moveReaderTask == nil,
            "synchronize() consomme responseStream alors que le lecteur de coups le consomme déjà : deux `next()` concurrents = fatalError du stdlib"
        )
        await sendRaw(.isready)
        let outcome = await EngineWatchdog.run(deadlineMs: timeoutMs) {
            for await response in self.responseStream {
                if case .readyok = response { return true }
            }
            return false
        }
        guard case let .finished(ready) = outcome else { return false }
        return ready
    }

    func stop() async {
        engine.stop()
        readerTask?.cancel()
        readerTask = nil
        // Le lecteur du Laboratoire aussi : c'est LUI qui faisait fuiter le
        // contrôleur. `ensureMoveReader` crée une tâche qui itère le flux parsé
        // sans fin ; tant qu'elle vit, elle retient l'instance, donc `deinit`
        // n'arrive jamais et `EngineInstanceCounter.didRelease()` non plus —
        // une instance « vivante » de plus à chaque passage au Laboratoire, et
        // pour toujours.
        moveReaderTask?.cancel()
        moveReaderTask = nil
    }

    /// Attend que le process moteur se libère, puis le prend.
    ///
    /// Borné : au-delà, mieux vaut une bannière honnête qu'une attente sans
    /// fin. Le cas normal se résout en quelques dizaines de millisecondes (le
    /// temps du `quit` + join de l'écran précédent).
    ///
    /// Vérifie ``FairyStockfishEngine/isProcessBusy`` (l'AUTRE type de
    /// moteur) ET ``StockfishEngine/isProcessBusy`` (le SIEN) — pas
    /// seulement l'autre. `handleViewDisappear()` arrête un moteur via une
    /// tâche DÉTACHÉE, jamais attendue (correct : `.onDisappear` ne peut pas
    /// `await`). `std::cin`/`std::cout`, eux, sont des flux GLOBAUX AU
    /// PROCESS que Stockfish ET Fairy-Stockfish redirigent chacun à leur
    /// tour — si l'un démarre pendant que l'autre achève sa démolition en
    /// tâche de fond, sa redirection écrase celle du nouveau venu EN PLEIN
    /// MILIEU, qui n'entend plus jamais rien. Découvert le 25/08 en changeant
    /// de variante (Chess960/normal ↔ Fairy-Stockfish) : un défaut réel, pas
    /// seulement un artefact de test.
    ///
    /// **Complété le 25/08 (soir)** : le garde-fou ne couvrait que l'AUTRE
    /// type de moteur — deux écrans successifs du MÊME type (par exemple
    /// Roi de la colline puis Course des rois, tous deux Fairy-Stockfish)
    /// pouvaient courir l'un contre l'autre exactement pareil, puisque
    /// `FairyStockfishEngine.start(binaryPath:)` n'attend jamais tout seul
    /// que l'instance précédente ait fini de s'arrêter. Signalé par
    /// l'utilisateur : « Course des rois... moteur indisponible » —
    /// reproductible en changeant vite de variante Fairy-Stockfish.
    ///
    /// **Budget doublé le 25/08 (nuit)** : observé en suite COMPLÈTE (tests +
    /// interface, ~45 min) — un moteur précédent a mis plus de 4 s à libérer
    /// `isProcessBusy` sous charge système lourde, faisant échouer ce garde
    /// alors que rien n'était réellement bloqué, juste lent. Le cas normal
    /// reste des dizaines de ms ; ce budget ne coûte donc rien au cas normal,
    /// seulement au cas déjà dégradé — cohérent avec l'hypothèse (jamais
    /// confirmée autrement) derrière le signalement initial de l'utilisateur.
    private func acquireEngineProcess(timeoutMs: Int = 8000) async -> Bool {
        var attemptsLeft = max(timeoutMs / 50, 1)
        while true {
            if !FairyStockfishEngine.isProcessBusy, !StockfishEngine.isProcessBusy,
               engine.start(binaryPath: Self.enginePath)
            {
                return true
            }
            guard attemptsLeft > 0 else { return false }
            attemptsLeft -= 1
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    /// Relance l'instance après une panne : `stop` → nouvelle instance →
    /// `start` → `ucinewgame` → ré-émission des réglages de l'appelant.
    @discardableResult
    func restart(coreCount: Int? = nil, multipv: Int = 1, setupCommands: [EngineCommand] = []) async -> Bool {
        engine.stop()
        readerTask?.cancel()
        readerTask = nil
        moveReaderTask?.cancel()
        moveReaderTask = nil
        resolve(with: nil)
        staleBestmovesToDiscard = 0
        latestMoverCp = nil

        // Nouvelle instance : le flux de lignes précédent est clos.
        engine = StockfishEngine()

        guard await start(coreCount: coreCount, multipv: multipv) else { return false }
        for command in setupCommands {
            await send(command)
        }
        return true
    }

    // MARK: Recherche coup par coup (mode Laboratoire)

    private var pendingContinuation: CheckedContinuation<(lan: String, moverCp: Int?)?, Never>?
    private var latestMoverCp: Int?
    private var requestID = 0
    private var staleBestmovesToDiscard = 0
    /// Lecteur de la recherche coup par coup (Laboratoire) : consomme le flux
    /// parsé et réveille la continuation au `bestmove`.
    private var moveReaderTask: Task<Void, Never>?

    func computeBestMove(
        fen: String, setupCommands: [EngineCommand], movetimeMs: Int?, depth: Int?
    ) async -> (lan: String, moverCp: Int?)? {
        guard engine.isRunning else { return nil }
        ensureMoveReader()
        latestMoverCp = nil
        requestID &+= 1
        let id = requestID

        for command in setupCommands {
            await send(command)
        }
        await send(.position(.fen(fen)))
        if let depth {
            await send(.go(depth: depth))
        } else {
            await send(.go(movetime: movetimeMs ?? 100))
        }

        let budgetMs = movetimeMs ?? (depth != nil ? 3000 : 200)

        return await withCheckedContinuation { continuation in
            if let orphaned = pendingContinuation {
                pendingContinuation = nil
                // Invalider AUSSI la recherche abandonnée (comme le fait
                // `hardStopIfPending`) : sans ce compteur, son `bestmove`
                // tardif — calculé pour la position PRÉCÉDENTE — venait
                // résoudre la nouvelle continuation. Illégal, la partie du
                // Laboratoire s'interrompait sans explication ; légal, il
                // passait pour le bon coup.
                staleBestmovesToDiscard += 1
                orphaned.resume(returning: nil)
            }
            pendingContinuation = continuation

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(budgetMs + 2000) * 1_000_000)
                await self?.forceStopIfPending(id)
            }
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(budgetMs + 6000) * 1_000_000)
                await self?.hardStopIfPending(id)
            }
        }
    }

    private func ensureMoveReader() {
        guard moveReaderTask == nil else { return }
        moveReaderTask = Task { [weak self] in
            guard let stream = await self?.responseStream else { return }
            // `self` repris FAIBLEMENT à chaque tour, jamais capturé fort pour
            // la durée de la boucle : sinon la tâche retient le contrôleur, le
            // contrôleur retient la tâche, et le cycle survit à l'écran.
            for await response in stream {
                guard let self else { return }
                await self.handle(response)
            }
        }
    }

    private func handle(_ response: EngineResponse) {
        switch response {
        case let .info(info):
            if (info.multipv ?? 1) == 1 {
                if let mate = info.score?.mate {
                    latestMoverCp = mate > 0 ? 10_000 : -10_000
                } else if let cp = info.score?.cp {
                    latestMoverCp = Int(cp)
                }
            }
        case let .bestmove(move, _):
            if staleBestmovesToDiscard > 0 {
                staleBestmovesToDiscard -= 1
                latestMoverCp = nil
                return
            }
            resolve(with: (move, latestMoverCp))
        default:
            break
        }
    }

    private func resolve(with value: (lan: String, moverCp: Int?)?) {
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil
        continuation.resume(returning: value)
    }

    private func hardStopIfPending(_ id: Int) async {
        guard id == requestID, pendingContinuation != nil else { return }
        staleBestmovesToDiscard += 1
        resolve(with: nil)
        await send(.stop)
    }

    private func forceStopIfPending(_ id: Int) async {
        guard id == requestID, pendingContinuation != nil else { return }
        await send(.stop)
    }
}
