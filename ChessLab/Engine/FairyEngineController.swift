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
        if rawCapturing { rawLineBuffer.append(line) }
    }

    // MARK: Capture de lignes BRUTES — `go perft`/`d`, hors du dialecte
    // `EngineCommand`/`EngineResponse` (Lot B des variantes : Fairy-Stockfish
    // devient l'arbitre de LÉGALITÉ, pas seulement un conseiller — voir
    // ``EngineLegalityVariant``. `EngineCommand` ne modélise que le sous-
    // dialecte déjà utilisé par le Laboratoire/le jeu normal ; l'étendre pour
    // deux commandes de diagnostic aurait touché un fichier PARTAGÉ avec
    // ``EngineController`` pour un besoin propre à Fairy-Stockfish.

    private var rawCapturing = false
    private var rawLineBuffer: [String] = []

    /// Envoie une commande UCI brute et récolte les lignes reçues jusqu'à ce
    /// qu'une corresponde à `terminator` (incluse), borné à `timeoutMs`.
    /// Un seul appelant à la fois — pas de garde de réentrance : les
    /// méthodes qui l'utilisent (``legalMoves(startFEN:uciLog:)``,
    /// ``positionAfter(startFEN:uciLog:)``) sont toujours attendues
    /// séquentiellement par leur appelant, comme le reste de cet acteur.
    private func captureRawLines(
        sending raw: String, until terminator: @escaping (String) -> Bool, timeoutMs: Int = 4000
    ) async -> [String] {
        guard engine.isRunning else { return [] }
        rawLineBuffer = []
        rawCapturing = true
        defer { rawCapturing = false }
        engine.send(raw)
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while Date() < deadline {
            if rawLineBuffer.contains(where: terminator) { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return rawLineBuffer
    }

    /// Positionne l'engin sur `startFEN` + `uciLog`, puis énumère les coups
    /// légaux via `go perft 1` — Fairy-Stockfish devient ainsi l'ARBITRE de
    /// légalité (pas ChessKit) pour les variantes où la légalité elle-même
    /// change (Course des rois, Antéchecs, Atomique). Format d'une ligne de
    /// coup : `e2e4: 1` ; le compteur ne sert à rien ici, seul le préfixe
    /// avant `:` est retenu. Liste VIDE : aucun coup légal — mat, pat, ou
    /// (Antéchecs) plus aucune pièce, selon la variante.
    struct PositionQuery {
        let fen: String
        let inCheck: Bool
        let legalMoves: [String]
    }

    /// Positionne l'engin sur `startFEN` + `uciLog`, puis interroge `d`
    /// (FEN résultant + échec) et `go perft 1` (coups légaux exacts) — une
    /// seule commande `position`, envoyée une fois. `nil` : `d` sans FEN
    /// dans le délai (position non trouvée).
    ///
    /// Le FEN de `d` est la seule source fiable de l'état du plateau pour
    /// l'Atomique (une capture y fait exploser des cases que ChessKit ne
    /// peut pas deviner tout seul) ; les coups légaux de `go perft 1` sont
    /// l'ARBITRE de légalité pour Course des rois/Antéchecs/Atomique — voir
    /// ``EngineLegalityVariant``.
    func queryPosition(startFEN: String, uciLog: [String]) async -> PositionQuery? {
        let positionCmd = uciLog.isEmpty
            ? "position fen \(startFEN)"
            : "position fen \(startFEN) moves \(uciLog.joined(separator: " "))"
        engine.send(positionCmd)

        let dLines = await captureRawLines(sending: "d", until: { $0.hasPrefix("Checkers:") })
        guard let fenLine = dLines.first(where: { $0.hasPrefix("Fen: ") }) else { return nil }
        let fen = String(fenLine.dropFirst("Fen: ".count))
        let inCheck = dLines.first(where: { $0.hasPrefix("Checkers:") })
            .map { $0.trimmingCharacters(in: .whitespaces) != "Checkers:" } ?? false

        let perftLines = await captureRawLines(sending: "go perft 1", until: { $0.hasPrefix("Nodes searched") })
        let legalMoves = perftLines.compactMap { line -> String? in
            guard let colonIndex = line.firstIndex(of: ":") else { return nil }
            let move = String(line[line.startIndex..<colonIndex])
            // Une ligne de coup fait 4-5 caractères ("e2e4", "e7e8q") ; la
            // ligne de résumé « Nodes searched: N » en a bien plus — sans
            // cette borne haute, elle se glissait dans la liste comme un
            // faux coup (trouvé en explorant Course des rois : un roi déjà
            // arrivé donne ZÉRO coup réel, et "Nodes searched" restait seul).
            guard (4...5).contains(move.count), move.first!.isLowercase, move.first!.isLetter
            else { return nil }
            return move
        }

        return PositionQuery(fen: fen, inCheck: inCheck, legalMoves: legalMoves)
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

    /// Vérifie ``StockfishEngine/isProcessBusy`` (l'AUTRE type de moteur) ET
    /// ``FairyStockfishEngine/isProcessBusy`` (le SIEN) — voir le
    /// commentaire symétrique sur
    /// ``EngineController/acquireEngineProcess(timeoutMs:)``, qui documente
    /// le défaut réel (pas seulement un artefact de test) trouvé le 25/08,
    /// et son complément du soir même : deux écrans de variantes
    /// Fairy-Stockfish successifs (ex. Roi de la colline → Course des rois)
    /// couraient l'un contre l'autre exactement pareil, le garde initial ne
    /// couvrant que l'AUTRE type de moteur — signalé par l'utilisateur
    /// (« Course des rois... moteur indisponible »).
    ///
    /// **Budget doublé le 25/08 (nuit)** : voir le commentaire symétrique sur
    /// ``EngineController/acquireEngineProcess(timeoutMs:)`` — observé en
    /// suite de tests COMPLÈTE, un moteur précédent lent à libérer
    /// `isProcessBusy` sous charge système faisait échouer ce garde pour un
    /// simple ralentissement, pas un vrai blocage.
    private func acquireEngineProcess(timeoutMs: Int = 8000) async -> Bool {
        var attemptsLeft = max(timeoutMs / 50, 1)
        while true {
            if !StockfishEngine.isProcessBusy, !FairyStockfishEngine.isProcessBusy,
               engine.start(binaryPath: Self.enginePath)
            {
                return true
            }
            guard attemptsLeft > 0 else { return false }
            attemptsLeft -= 1
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
