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
            engine.start(binaryPath: Self.enginePath)
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
    }

    /// Relance l'instance après une panne : `stop` → nouvelle instance →
    /// `start` → `ucinewgame` → ré-émission des réglages de l'appelant.
    @discardableResult
    func restart(coreCount: Int? = nil, multipv: Int = 1, setupCommands: [EngineCommand] = []) async -> Bool {
        engine.stop()
        readerTask?.cancel()
        readerTask = nil
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
            guard let self else { return }
            for await response in await self.responseStream {
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
