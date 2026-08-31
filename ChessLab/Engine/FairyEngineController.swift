import CFairyStockfishKit
import ChessKit
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

    /// Les abonnés du flux de réponses — un par LECTURE en cours.
    ///
    /// Il y avait ici UN AsyncStream unique, créé à l'init et partagé par
    /// tous les consommateurs successifs. Or annuler la tâche qui itère un
    /// AsyncStream TERMINE le stream — définitivement. C'est exactement ce
    /// que fait ``EngineWatchdog`` à chaque échéance dépassée : le premier
    /// timeout de la vie du contrôleur tuait donc le flux pour toujours, et
    /// toutes les lectures suivantes (synchronize, éval, indices) se
    /// terminaient à vide, sans erreur. Reproduit le 30/08 : partie finie,
    /// « Analyser » interrompt une éval en vol (timeout → annulation), et au
    /// retour le moteur — pourtant redémarré et VIVANT — semblait muet.
    ///
    /// Chaque accès à ``responseStream`` fabrique désormais SON stream,
    /// alimenté par ``ingest(_:)`` tant qu'il vit ; une annulation ne tue que
    /// lui. Corollaire assumé : un abonné ne reçoit QUE ce qui est émis
    /// après son abonnement — fini le tampon commun où de vieux `readyok`/
    /// `bestmove` attendaient de satisfaire le mauvais lecteur.
    private var responseSubscribers: [UInt64: AsyncStream<EngineResponse>.Continuation] = [:]
    private var nextResponseSubscriberID: UInt64 = 0
    private var readerTask: Task<Void, Never>?
    private var uciOk = false

    private let startTimeoutMs: Int

    /// **Porté de 5 s à 15 s le 29/08**, pour la même raison que
    /// ``captureRawLines(sending:until:timeoutMs:)`` : ce budget ne mesure pas
    /// le démarrage du moteur — `uciok` arrive en millisecondes — mais le
    /// temps que sa réponse met à REMONTER par le MainActor. Sous charge, 5 s
    /// ne suffisaient pas, `didFailToStart` passait à vrai, et l'écran
    /// annonçait « moteur indisponible » alors que le moteur allait bien.
    /// Observé en suite complète ; sur un appareil lent ou déjà sollicité, un
    /// vrai joueur peut le voir aussi. Le cas normal ne coûte rien de plus :
    /// la boucle sort dès `uciok`.
    init(startTimeoutMs: Int = 15000) {
        self.startTimeoutMs = startTimeoutMs
        engine = FairyStockfishEngine()
        EngineInstanceCounter.shared.didCreate()
    }

    deinit {
        engine.stop()
        readerTask?.cancel()
        for continuation in responseSubscribers.values { continuation.finish() }
        EngineInstanceCounter.shared.didRelease()
    }

    var responseStream: AsyncStream<EngineResponse> {
        var continuation: AsyncStream<EngineResponse>.Continuation!
        let stream = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        let id = nextResponseSubscriberID
        nextResponseSubscriberID += 1
        responseSubscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.dropResponseSubscriber(id) }
        }
        return stream
    }

    private func dropResponseSubscriber(_ id: UInt64) {
        responseSubscribers[id] = nil
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
            for continuation in responseSubscribers.values { continuation.yield(response) }
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

    /// Ce que la DERNIÈRE interrogation de position a réellement vu — pour
    /// que l'intermittent « position jamais rendue » (un test au hasard, en
    /// suite complète uniquement, ~1 passe sur 3) se NOMME à sa prochaine
    /// occurrence au lieu de rester une énigme : quelle commande est restée
    /// muette, combien de lignes sont quand même arrivées, et si la tâche
    /// d'attente avait été annulée sous elle.
    private(set) var lastQueryDiagnostic: String?

    /// Pourquoi le dernier `start(variant:)` a échoué — la phase précise :
    /// l'acquisition du process, ou l'attente d'`uciok`.
    private(set) var lastStartFailure: String?

    /// Envoie une commande UCI brute et récolte les lignes reçues jusqu'à ce
    /// qu'une corresponde à `terminator` (incluse), borné à `timeoutMs`.
    /// Un seul appelant à la fois — pas de garde de réentrance : les
    /// méthodes qui l'utilisent (``legalMoves(startFEN:uciLog:)``,
    /// ``positionAfter(startFEN:uciLog:)``) sont toujours attendues
    /// séquentiellement par leur appelant, comme le reste de cet acteur.
    ///
    /// **Budget porté de 4 s à 15 s le 29/08.** Ce n'est pas le temps de
    /// CALCUL du moteur — `d` et `go perft 1` répondent en millisecondes —
    /// mais le temps qu'il faut aux lignes pour remonter jusqu'ici, et ce
    /// chemin passe par le MainActor. Sous la charge d'une suite complète,
    /// 4 s ne suffisaient pas : `queryPosition` rendait `nil`, et l'appelant
    /// en concluait à une panne moteur alors que le moteur allait très bien.
    /// C'était l'échec récurrent de `CrazyhouseGameTests` en suite complète,
    /// vert en isolation à chaque fois. Le budget ne coûte rien quand tout va
    /// bien : la boucle sort dès que la réponse arrive.
    private func captureRawLines(
        sending raw: String, until terminator: @escaping (String) -> Bool, timeoutMs: Int = 15000
    ) async -> [String] {
        guard engine.isRunning else { return [] }
        rawLineBuffer = []
        rawCapturing = true
        defer { rawCapturing = false }
        engine.send(raw)
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while Date() < deadline {
            if rawLineBuffer.contains(where: terminator) { break }
            // `do`/`catch` et NON `try?` : dans une tâche ANNULÉE,
            // `Task.sleep` échoue immédiatement, et `try?` transformait alors
            // cette attente en boucle à vide — quinze secondes de MainActor
            // saturé, à empêcher précisément le lecteur de lignes de livrer
            // ce qu'on attend. La boucle se sabotait elle-même, et le seul
            // symptôme visible était « moteur indisponible ».
            do { try await Task.sleep(nanoseconds: 10_000_000) } catch { break }
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
        /// Pièces EN MAIN, par camp — la réserve du Crazyhouse, lue dans la
        /// section entre crochets de la FEN. Vide pour toutes les autres
        /// variantes, dont la FEN n'en comporte pas.
        let pocket: [Piece.Color: [Piece.Kind: Int]]

        init(
            fen: String, inCheck: Bool, legalMoves: [String],
            pocket: [Piece.Color: [Piece.Kind: Int]] = [:]
        ) {
            self.fen = fen
            self.inCheck = inCheck
            self.legalMoves = legalMoves
            self.pocket = pocket
        }
    }

    /// Lit la réserve d'une FEN Crazyhouse.
    ///
    /// Le moteur écrit les pièces en main entre crochets, juste après le
    /// plateau : `rnb1kbnr/…/RNBQKBNR[Pp] w KQkq - 0 3` — majuscules pour les
    /// Blancs, minuscules pour les Noirs, `[]` quand les deux mains sont
    /// vides. ChessKit ignore cette section (vérifié : il lit le plateau
    /// correctement et n'en dit rien), c'est donc à nous de la relever.
    static func parsePocket(fromFEN fen: String) -> [Piece.Color: [Piece.Kind: Int]] {
        guard let open = fen.firstIndex(of: "["), let close = fen.firstIndex(of: "]"),
              open < close
        else { return [:] }
        var pocket: [Piece.Color: [Piece.Kind: Int]] = [:]
        for character in fen[fen.index(after: open)..<close] {
            let color: Piece.Color = character.isUppercase ? .white : .black
            guard let kind = pieceKind(fromFENCharacter: character) else { continue }
            pocket[color, default: [:]][kind, default: 0] += 1
        }
        return pocket
    }

    /// Lettre FEN d'un type de pièce : « P », « N », « B », « R », « Q », « K ».
    ///
    /// À ne PAS confondre avec `Piece.Kind.rawValue`, qui est la lettre SAN —
    /// celle du pion y est VIDE, puisqu'en notation algébrique un pion ne se
    /// nomme pas. S'en servir pour bâtir une pose donnait le préfixe « @ » au
    /// lieu de « P@ », et aucune case de pose n'était trouvée.
    static func fenLetter(for kind: Piece.Kind) -> String {
        switch kind {
        case .pawn: "P"
        case .knight: "N"
        case .bishop: "B"
        case .rook: "R"
        case .queen: "Q"
        case .king: "K"
        }
    }

    private static func pieceKind(fromFENCharacter character: Character) -> Piece.Kind? {
        switch Character(character.lowercased()) {
        case "p": .pawn
        case "n": .knight
        case "b": .bishop
        case "r": .rook
        case "q": .queen
        case "k": .king
        default: nil
        }
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
        guard let fenLine = dLines.first(where: { $0.hasPrefix("Fen: ") }) else {
            lastQueryDiagnostic = "`d` muet : \(dLines.count) ligne(s) reçue(s) sans « Fen: », "
                + "moteur \(engine.isRunning ? "vivant" : "ARRÊTÉ"), "
                + "tâche \(Task.isCancelled ? "ANNULÉE" : "vivante")"
            return nil
        }
        let fen = String(fenLine.dropFirst("Fen: ".count))
        let inCheck = dLines.first(where: { $0.hasPrefix("Checkers:") })
            .map { $0.trimmingCharacters(in: .whitespaces) != "Checkers:" } ?? false

        let perftLines = await captureRawLines(sending: "go perft 1", until: { $0.hasPrefix("Nodes searched") })
        if !perftLines.contains(where: { $0.hasPrefix("Nodes searched") }) {
            lastQueryDiagnostic = "`go perft 1` muet : \(perftLines.count) ligne(s) sans résumé, "
                + "moteur \(engine.isRunning ? "vivant" : "ARRÊTÉ"), "
                + "tâche \(Task.isCancelled ? "ANNULÉE" : "vivante")"
        } else {
            lastQueryDiagnostic = nil
        }
        let legalMoves = perftLines.compactMap { line -> String? in
            guard let colonIndex = line.firstIndex(of: ":") else { return nil }
            let move = String(line[line.startIndex..<colonIndex])
            return isUCIMove(move) ? move : nil
        }

        return PositionQuery(
            fen: fen, inCheck: inCheck, legalMoves: legalMoves,
            pocket: Self.parsePocket(fromFEN: fen)
        )
    }

    /// Une ligne de `go perft 1` porte-t-elle un coup, ou le résumé final ?
    ///
    /// Deux formes acceptées. Le coup ORDINAIRE, 4 ou 5 caractères tout en
    /// minuscules (`e2e4`, `e7e8q`) — la borne haute écarte la ligne
    /// « Nodes searched: N », qui se glissait sinon dans la liste comme un
    /// faux coup (trouvé en explorant Course des rois : un roi déjà arrivé
    /// donne ZÉRO coup réel, et ce résumé restait seul).
    ///
    /// Et la POSE du Crazyhouse, `P@e4` : une majuscule, une arobase, une
    /// case. Elle était rejetée en silence par le seul test « première lettre
    /// minuscule » — le moteur en émettait 33 dans la position sondée, aucune
    /// n'arrivait jusqu'au view model, et rien ne le signalait.
    private func isUCIMove(_ move: String) -> Bool {
        let characters = Array(move)
        if characters.count == 4, characters[1] == "@" {
            return characters[0].isUppercase && characters[0].isLetter
                && characters[2].isLowercase && characters[3].isNumber
        }
        guard (4...5).contains(characters.count) else { return false }
        return characters[0].isLowercase && characters[0].isLetter
    }

    // MARK: Démarrage

    /// Démarre le moteur, règle `UCI_Variant`, et attend `uciok` — borné à
    /// ~`startTimeoutMs`. `variant` : nom UCI Fairy-Stockfish exact (voir
    /// ``FairyVariant/uciVariantName``, ex. « kingofthehill »).
    ///
    /// - parameter variantPath: chemin d'un fichier de définition de variantes
    ///   à charger AVANT de choisir la variante. C'est la seule façon d'ajouter
    ///   une variante que le moteur ne connaît pas d'origine (voir
    ///   ``BarricadesVariant``) : l'option `VariantPath` relit le fichier et
    ///   reconstruit la liste des variantes acceptées, donc elle doit
    ///   impérativement précéder `UCI_Variant` — dans l'autre ordre, le moteur
    ///   refuse un nom qu'il ne connaît pas encore et reste aux échecs
    ///   ordinaires, sans rien dire.
    @discardableResult
    func start(
        variant: String, variantPath: String? = nil, coreCount: Int? = nil, multipv: Int = 1
    ) async -> Bool {
        uciOk = false
        if !engine.isRunning {
            // NOUVELLE instance, systématiquement — c'est le correctif du
            // défaut « le moteur n'a pas pu être démarré », signalé après une
            // fin de partie suivie de l'analyse, ou après un simple
            // aller-retour sur l'écran.
            //
            // ``FairyStockfishEngine/stop()`` termine son `AsyncStream` de
            // lignes, et un flux terminé l'est POUR TOUJOURS. Le view model,
            // lui, survit à la navigation (``SessionStore`` le conserve
            // exprès), donc son contrôleur et son instance de moteur aussi :
            // au retour, ``startReader()`` itérait un flux mort, plus aucun
            // `uciok` ne remontait, et le démarrage expirait au bout de cinq
            // secondes. L'écran annonçait alors une panne moteur… alors que le
            // process, lui, avait parfaitement démarré — et restait en vie,
            // occupant `isProcessBusy` pour les écrans suivants.
            //
            // ``EngineController`` connaissait déjà ce piège et le contournait
            // dans ``EngineController/restart(coreCount:multipv:setupCommands:)``
            // (« Nouvelle instance : le flux de lignes précédent est clos »),
            // mais ce contrôleur-ci, écrit à part, n'avait pas d'équivalent.
            // C'est pourquoi le moteur standard ne montrait jamais le défaut.
            //
            // `stop()` d'abord : si l'instance sortante avait pris le process
            // et l'a perdu autrement que par un arrêt propre (moteur mort de
            // son côté), la lâcher sans plus rien laisserait `gRunning` à vrai
            // côté C++, et le process resterait occupé pour tout le monde.
            // Sur une instance jamais démarrée, c'est un no-op.
            engine.stop()
            engine = FairyStockfishEngine()
            guard await acquireEngineProcess() else {
                didFailToStart = true
                lastStartFailure = "acquisition du process refusée (8 s) — "
                    + "Stockfish occupé : \(StockfishEngine.isProcessBusy), "
                    + "Fairy occupé : \(FairyStockfishEngine.isProcessBusy)"
                return false
            }
        }
        startReader()

        await sendRaw(.uci)
        var iterationsLeft = max(startTimeoutMs / 20, 1)
        while !uciOk {
            if iterationsLeft <= 0 {
                didFailToStart = true
                lastStartFailure = "uciok jamais reçu (\(startTimeoutMs) ms) — moteur "
                    + (engine.isRunning ? "vivant" : "ARRÊTÉ")
                return false
            }
            iterationsLeft -= 1
            // Voir ``captureRawLines(sending:until:timeoutMs:)`` : avec
            // `try?`, une tâche annulée épuisait ces 750 tours en un clin
            // d'œil et rendait « le moteur n'a pas démarré » — alors qu'il
            // n'avait simplement pas eu une milliseconde pour répondre.
            do { try await Task.sleep(nanoseconds: 20_000_000) } catch { return false }
        }

        let threads = coreCount.map { max($0 - 1, 1) } ?? 1
        await sendRaw(.setoption(id: "Threads", value: "\(threads)"))
        await sendRaw(.setoption(id: "MultiPV", value: "\(multipv)"))
        if let variantPath {
            await sendRaw(.setoption(id: "VariantPath", value: variantPath))
        }
        await sendRaw(.setoption(id: "UCI_Variant", value: variant))
        await sendRaw(.ucinewgame)
        didFailToStart = false
        lastStartFailure = nil
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
        // S'abonner AVANT d'envoyer : `readyok` revient en microsecondes, et
        // un abonné ne reçoit que ce qui suit son abonnement.
        let stream = responseStream
        await sendRaw(.isready)
        let outcome = await EngineWatchdog.run(deadlineMs: timeoutMs) {
            for await response in stream {
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
    /// **Essayé à 30 s le 29/08, revenu à 8 s le jour même.** L'idée était la
    /// même que pour les deux autres budgets de cette famille (`uciok` et le
    /// retour des lignes brutes) : ils bornent des attentes qui dépendent de
    /// l'ordonnanceur, pas du moteur. Mais celui-ci se comporte autrement —
    /// il n'attend pas une RÉPONSE, il attend qu'une ressource se libère, et
    /// une instance précédente qui s'arrête normalement la rend en quelques
    /// dizaines de millisecondes. Mesuré : à 30 s, la suite complète est
    /// passée de 6 minutes à plus de 39 sans jamais finir — trente tests
    /// moteur sérialisés derrière un verrou, chacun capable d'attendre une
    /// demi-minute, s'affament les uns les autres. Les deux autres budgets,
    /// eux, ont bien réglé le défaut (898 tests verts).
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
            // Même piège : annulée, cette boucle brûlait ses 160 tours sans
            // jamais laisser l'instance précédente finir de se libérer.
            do { try await Task.sleep(nanoseconds: 50_000_000) } catch { return false }
        }
    }
}
