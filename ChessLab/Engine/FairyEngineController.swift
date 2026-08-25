import CFairyStockfishKit
// `EngineCommand`/`EngineResponse` sont définis dans `CStockfishKit`
// (`UCIProtocol.swift`) — un parseur UCI pur, sans rien de spécifique à
// Stockfish (vérifié : Fairy-Stockfish parle EXACTEMENT le même dialecte
// `info`/`bestmove`/`readyok`). Réutilisé tel quel plutôt que dupliqué.
import CStockfishKit
import Foundation

/// Enveloppe Fairy-Stockfish (``CFairyStockfishKit``) — même contrat que
/// ``EngineController``, en plus léger : pas de lecteur permanent façon
/// Laboratoire (``EngineController/computeBestMove``), qu'aucune variante à
/// ce jour n'utilise. Dupliqué plutôt que rendu générique : toucher
/// `EngineController` — déjà réglé fin, déjà couvert par des mois de
/// correctifs — pour une poignée de variantes aurait été le risque le
/// moins raisonnable des deux (même arbitrage que l'indice Chess960 du
/// 25/08).
///
/// **Un seul moteur — Stockfish OU Fairy-Stockfish — par process** : les deux
/// se disputent les mêmes flux globaux `std::cin`/`std::cout` (voir le
/// commentaire de vendoring dans `Vendor/CFairyStockfish/Package.swift`).
/// La discipline déjà en place (un moteur par écran, arrêté avant le
/// suivant) suffit — aucune garde supplémentaire nécessaire ici.
actor FairyEngineController {

    private var engine: FairyStockfishEngine

    private static var enginePath: String {
        if let resources = Bundle.main.resourcePath {
            return resources + "/fairystockfish"
        }
        return "fairystockfish"
    }

    private let parsed: AsyncStream<EngineResponse>
    private let parsedContinuation: AsyncStream<EngineResponse>.Continuation
    private var readerTask: Task<Void, Never>?
    private var uciOk = false

    private let startTimeoutMs: Int

    init(startTimeoutMs: Int = 5000) {
        self.startTimeoutMs = startTimeoutMs
        engine = FairyStockfishEngine()
        var cont: AsyncStream<EngineResponse>.Continuation!
        parsed = AsyncStream(bufferingPolicy: .unbounded) { cont = $0 }
        parsedContinuation = cont
        EngineInstanceCounter.shared.didCreate()
    }

    deinit {
        engine.stop()
        readerTask?.cancel()
        EngineInstanceCounter.shared.didRelease()
    }

    var responseStream: AsyncStream<EngineResponse> {
        parsed
    }

    private(set) var didFailToStart = false

    // MARK: Lecteur unique

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

    /// Démarre le moteur, règle `UCI_Variant`, et attend `uciok` — borné à
    /// ~`startTimeoutMs`. `variant` : nom UCI Fairy-Stockfish exact (voir
    /// ``FairyVariant/uciVariantName``, ex. « kingofthehill »).
    @discardableResult
    func start(variant: String, coreCount: Int? = nil, multipv: Int = 1) async -> Bool {
        uciOk = false
        if !engine.isRunning {
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
        await sendRaw(.setoption(id: "UCI_Variant", value: variant))
        await sendRaw(.ucinewgame)
        didFailToStart = false
        return true
    }

    // MARK: Envoi

    func send(_ command: EngineCommand) async {
        guard engine.isRunning else { return }
        engine.send(command.uciString)
    }

    private func sendRaw(_ command: EngineCommand) async {
        guard engine.isRunning else { return }
        engine.send(command.uciString)
    }

    /// Barrière de synchronisation UCI — même contrat que
    /// ``EngineController/synchronize(timeoutMs:)``. Pas de garde contre un
    /// second consommateur : cette variante-ci n'a pas de lecteur permanent.
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

    /// Vérifie AUSSI ``StockfishEngine/isProcessBusy`` — voir le commentaire
    /// symétrique sur ``EngineController/acquireEngineProcess(timeoutMs:)``,
    /// qui documente le défaut réel (pas seulement un artefact de test)
    /// trouvé le 25/08.
    private func acquireEngineProcess(timeoutMs: Int = 4000) async -> Bool {
        var attemptsLeft = max(timeoutMs / 50, 1)
        while true {
            if !StockfishEngine.isProcessBusy, engine.start(binaryPath: Self.enginePath) {
                return true
            }
            guard attemptsLeft > 0 else { return false }
            attemptsLeft -= 1
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
