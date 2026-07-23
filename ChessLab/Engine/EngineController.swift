import ChessKitEngine

/// Enveloppe un `Engine` ChessKitEngine et sérialise les commandes UCI
/// envoyées vers une instance moteur donnée.
///
/// Une instance par partie/analyse active ; la reprise après crash moteur
/// (relancer + repositionner depuis le FEN courant) sera ajoutée à l'étape 1
/// quand le mode Jouer pilotera réellement des parties.
actor EngineController {

    private let engine: Engine

    /// Délai au-delà duquel un démarrage est déclaré perdu.
    ///
    /// Réglable pour une seule raison : sous la charge d'une suite de tests
    /// complète (des dizaines de tests en parallèle), le chargement du réseau
    /// NNUE de 78 Mo dépasse allègrement les 5 s — un test d'intégration
    /// échouait alors qu'il passait seul. Les 5 s restent le comportement de
    /// l'app : c'est un choix produit (au-delà, l'utilisateur mérite un
    /// message), pas une caractéristique de la machine.
    private let startTimeoutMs: Int

    init(type: EngineType = .stockfish, startTimeoutMs: Int = 5000) {
        engine = Engine(type: type)
        self.startTimeoutMs = startTimeoutMs
        EngineInstanceCounter.shared.didCreate()
    }

    deinit {
        // Lot 6.A : rend visible une instance qui aurait survécu à son écran —
        // un Stockfish qui cherche derrière l'interface, invisible et vorace.
        EngineInstanceCounter.shared.didRelease()
    }

    /// Flux des réponses UCI parsées par ChessKitEngine (info, bestmove, etc.).
    var responseStream: AsyncStream<EngineResponse> {
        get async {
            await engine.responseStream ?? AsyncStream { $0.finish() }
        }
    }

    /// Vrai si le dernier ``start(coreCount:multipv:)`` a expiré sans que le
    /// moteur ne devienne opérationnel (NNUE manquant, mémoire…). Les VMs
    /// peuvent l'interroger pour signaler « Moteur indisponible » plutôt que
    /// de rester silencieusement bloquées.
    private(set) var didFailToStart = false

    /// Trace de ce qui a RÉELLEMENT été envoyé au moteur, en DEBUG.
    ///
    /// UCI ne relit jamais une option : `setoption` n'a pas d'accusé de
    /// réception, et le moteur n'annonce à l'ouverture que les valeurs par
    /// DÉFAUT. Impossible, donc, de demander à Stockfish « combien de threads
    /// utilises-tu ? ». Ce qu'on peut vérifier — et qui est tout ce dont on a
    /// besoin — c'est notre moitié du contrat : la bonne commande, avec la
    /// bonne valeur, envoyée à un moteur DÉMARRÉ (`Engine.send` ignore
    /// silencieusement tout ce qui arrive trop tôt).
    #if DEBUG
    private(set) var sentCommands: [EngineCommand] = []
    /// `coreCount` passé au dernier démarrage — la valeur que ChessKitEngine
    /// traduit en `Threads`.
    private(set) var lastStartCoreCount: Int?
    #endif

    /// Démarre le moteur et attend la fin du cycle uci → uciok → isready →
    /// readyok, **borné à ~5 s**. Sans borne, un échec de démarrage (réseau
    /// NNUE absent après un refactor de bundle, mémoire insuffisante)
    /// bloquerait indéfiniment toute la file moteur, sans aucun message.
    /// - Returns: `true` si le moteur tourne, `false` en cas de timeout.
    @discardableResult
    func start(coreCount: Int? = nil, multipv: Int = 1) async -> Bool {
        // Porte dérobée des tests (`-simulateEngineFailure <n>`) : sans elle,
        // la panne moteur — et donc toute la reprise du Lot 2.A — ne serait
        // vérifiable qu'en cassant le bundle à la main. Sans l'argument de
        // lancement, ceci ne fait rien.
        if await EngineStartFailureSimulator.shared.consumeFailure() {
            didFailToStart = true
            return false
        }

        #if DEBUG
        lastStartCoreCount = coreCount
        #endif

        await engine.start(coreCount: coreCount, multipv: multipv)
        // Borne via un compteur d'itérations de 20 ms (pas de dépendance à
        // Foundation.Date ici).
        var iterationsLeft = max(startTimeoutMs / 20, 1)
        while await !engine.isRunning {
            if iterationsLeft <= 0 {
                didFailToStart = true
                return false
            }
            iterationsLeft -= 1
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        didFailToStart = false
        return true
    }

    /// Démarre le moteur avec les réglages avancés de l'utilisateur.
    ///
    /// - parameter threads: nombre de threads VOULU (le prompt : 2 par défaut,
    ///   4 au maximum). Voir ``coreCount(forThreads:)`` pour la traduction.
    /// - parameter hashMB: taille de la table de transposition, en Mo. Elle
    ///   n'était **jamais** envoyée : Stockfish tournait sur son défaut
    ///   interne (16 Mo).
    @discardableResult
    func start(threads: Int, hashMB: Int, multipv: Int = 1) async -> Bool {
        guard await start(coreCount: Self.coreCount(forThreads: threads), multipv: multipv) else {
            return false
        }
        // APRÈS le démarrage, et pas avant : `Engine.send` jette en silence
        // tout ce qui arrive avant que le moteur ne tourne.
        await send(.setoption(id: "Hash", value: "\(hashMB)"))
        return true
    }

    /// Traduit un nombre de threads voulu en `coreCount` ChessKitEngine.
    ///
    /// ⚠️ ChessKitEngine n'envoie pas `Threads = coreCount`, mais
    /// `Threads = max(coreCount − 1, 1)` — il réserve un cœur au système. Pour
    /// obtenir N threads, il faut donc lui en demander N + 1. Passer
    /// simplement `nil` (le défaut) donne **1 seul thread**, ce qui était le
    /// comportement de l'app jusqu'ici, alors que le prompt en demande 2.
    static func coreCount(forThreads threads: Int) -> Int {
        max(threads, 1) + 1
    }

    /// - important: ChessKitEngine **SEGFAULTE** (`EXC_BAD_ACCESS` dans
    /// `EngineMessenger.sendCommand:`) si on lui écrit une commande alors
    /// qu'il n'a jamais démarré, ou qu'il s'est arrêté : le messager
    /// interne n'existe pas encore et le pointeur est déréférencé sans
    /// contrôle. Ce n'est donc PAS un envoi ignoré sans conséquence, comme
    /// on le croyait — c'est la mort du processus. D'où cette garde, seul
    /// endroit où l'app écrit vers le moteur.
    func send(_ command: EngineCommand) async {
        #if DEBUG
        sentCommands.append(command)
        #endif
        guard await engine.isRunning else { return }
        await engine.send(command: command)
    }

    /// Barrière de synchronisation UCI, à appeler AVANT chaque nouvelle
    /// recherche : envoie `isready` et jette toutes les réponses jusqu'au
    /// `readyok`.
    ///
    /// - important: Toute la discipline de l'app (une seule recherche à la
    /// fois, chaque consommateur lit le flux jusqu'à « son » `bestmove`) n'est
    /// correcte que si le flux préserve l'ordre des réponses. Or
    /// ChessKitEngine crée une `Task` NON STRUCTURÉE par ligne UCI reçue, qui
    /// traverse plusieurs `await` avant de `yield` : l'ordre relatif de deux
    /// lignes n'est pas garanti sous rafale (flood d'`info` à profondeur
    /// élevée sur appareil chargé). Un `info` de la recherche PRÉCÉDENTE,
    /// yieldé en retard, pouvait ainsi « fuiter » dans la boucle du
    /// consommateur suivant et lui faire évaluer la mauvaise position (fausse
    /// alerte gaffe, score décalé). Cette barrière — pattern UCI standard —
    /// vide ces traînards avant que la recherche suivante ne commence.
    /// Stockfish répond `readyok` immédiatement, même en pleine recherche.
    ///
    /// Si le moteur ne tourne pas, on rend `false` SANS rien lui envoyer :
    /// écrire dans un moteur non démarré fait segfauter ChessKitEngine
    /// (voir ``send(_:)``) — le commentaire d'origine affirmait ici que
    /// l'envoi serait « ignoré », ce qui était faux et tuait le processus.
    ///
    /// Bornée malgré tout : un moteur PLANTÉ (ni `readyok`, ni fin de flux)
    /// laissait l'appelant suspendu ici pour toujours, avant même sa
    /// recherche — premier maillon de l'écran figé « Stockfish ne répond
    /// plus ». Rend `false` quand le moteur est muet ; l'appelant décide
    /// (le chien de garde de sa propre recherche prendra le relais).
    @discardableResult
    func synchronize(timeoutMs: Int = 5000) async -> Bool {
        guard await engine.isRunning else { return false }
        await engine.send(command: .isready)
        let outcome = await EngineWatchdog.run(deadlineMs: timeoutMs) {
            for await response in await self.responseStream {
                if case .readyok = response { return true }
            }
            return false
        }
        guard case let .finished(ready) = outcome else { return false }
        return ready
    }

    func stop() async {
        await engine.stop()
    }

    /// Relance l'instance après une panne : `stop` → `start` → `ucinewgame` →
    /// ré-émission des réglages du mode appelant. L'appelant repositionne
    /// ensuite le moteur sur son FEN courant en relançant simplement son
    /// opération (le prompt : « redémarrer l'instance et reprendre depuis le
    /// FEN courant »).
    ///
    /// - important: remet à zéro TOUT l'état de lecture du flux. La `Task`
    ///   lectrice consomme le flux de l'ancienne session, qui se termine à
    ///   l'arrêt ; sans l'annuler, plus rien ne lirait la nouvelle session et
    ///   chaque recherche expirerait en silence. Une continuation en attente
    ///   est résolue par `nil` plutôt qu'abandonnée : son appelant resterait
    ///   suspendu pour toujours.
    /// - returns: `false` si le moteur ne repart pas — l'appelant garde alors
    ///   sa bannière « Moteur indisponible ».
    @discardableResult
    func restart(coreCount: Int? = nil, multipv: Int = 1, setupCommands: [EngineCommand] = []) async -> Bool {
        await engine.stop()

        readerTask?.cancel()
        readerTask = nil
        resolve(with: nil)
        staleBestmovesToDiscard = 0
        latestMoverCp = nil

        guard await start(coreCount: coreCount, multipv: multipv) else { return false }

        await engine.send(command: .ucinewgame)
        for command in setupCommands {
            await engine.send(command: command)
        }
        return true
    }

    // MARK: Recherche coup par coup (mode Laboratoire)

    /// Le flux de réponses de ChessKitEngine est un UNIQUE `AsyncStream` à
    /// itérateur unique. On le consomme donc UNE seule fois, via ce lecteur
    /// persistant, plutôt qu'en recréant un `for await` à chaque coup (ce
    /// qui revient à créer plusieurs itérateurs sur le même `AsyncStream` —
    /// non supporté par Swift, source d'éléments perdus voire de crash
    /// intermittent). Chaque appel à ``computeBestMove(...)`` dépose une
    /// continuation que le lecteur réveille au `bestmove` suivant.
    private var readerTask: Task<Void, Never>?
    private var pendingContinuation: CheckedContinuation<(lan: String, moverCp: Int?)?, Never>?
    private var latestMoverCp: Int?
    /// Identifie la requête courante pour qu'un chien de garde tardif ne
    /// résolve pas une continuation déjà remplacée par la suivante.
    private var requestID = 0
    /// Nombre de `bestmove` ATTENDUS mais devenus sans destinataire : une
    /// recherche abandonnée sur borne dure (voir ``hardStopIfPending(_:)``)
    /// finit toujours par en émettre un. Sans ce compteur, il arrivait après
    /// que la requête suivante ait installé sa continuation et la résolvait
    /// avec un coup calculé pour une AUTRE position (et sous les
    /// `setupCommands` de l'autre camp au Laboratoire).
    private var staleBestmovesToDiscard = 0

    /// Calcule le meilleur coup pour une position et renvoie son LAN + le
    /// score (centipions, point de vue du camp au trait ; mat = ±10 000).
    /// Toute la consommation du flux se fait sur l'acteur (hors MainActor).
    /// `nil` si aucun coup n'est obtenu à temps. Garde-fous : `.stop` forcé
    /// si la recherche déborde son budget (le moteur émet alors un bestmove
    /// immédiat), puis borne dure renvoyant `nil` plutôt que de bloquer.
    func computeBestMove(
        fen: String, setupCommands: [EngineCommand], movetimeMs: Int?, depth: Int?
    ) async -> (lan: String, moverCp: Int?)? {
        ensureReader()
        latestMoverCp = nil
        requestID &+= 1
        let id = requestID

        for command in setupCommands {
            await engine.send(command: command)
        }
        await engine.send(command: .position(.fen(fen)))
        if let depth {
            await engine.send(command: .go(depth: depth))
        } else {
            await engine.send(command: .go(movetime: movetimeMs ?? 100))
        }

        let budgetMs = movetimeMs ?? (depth != nil ? 3000 : 200)

        return await withCheckedContinuation { continuation in
            // Réentrance (deux appels qui se recouvrent) : ne JAMAIS écraser
            // une continuation encore en attente sans la résoudre, son
            // appelant resterait suspendu pour toujours.
            if let orphaned = pendingContinuation {
                pendingContinuation = nil
                orphaned.resume(returning: nil)
            }
            pendingContinuation = continuation

            // Chien de garde souple : force une conclusion si ça traîne.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(budgetMs + 2000) * 1_000_000)
                await self?.forceStopIfPending(id)
            }
            // Borne dure : abandonne (nil) plutôt que de figer.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(budgetMs + 6000) * 1_000_000)
                await self?.hardStopIfPending(id)
            }
        }
    }

    /// Démarre (une seule fois) le lecteur unique du flux de réponses.
    private func ensureReader() {
        guard readerTask == nil else { return }
        readerTask = Task { [weak self] in
            guard let self else { return }
            for await response in await self.currentStream() {
                await self.handle(response)
            }
        }
    }

    private func currentStream() async -> AsyncStream<EngineResponse> {
        await engine.responseStream ?? AsyncStream { $0.finish() }
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
            // Reliquat d'une recherche abandonnée sur borne dure : ce coup a
            // été calculé pour une autre position, il ne doit surtout pas
            // résoudre la requête en cours.
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

    /// Réveille la continuation en attente (au plus une fois) avec la valeur.
    private func resolve(with value: (lan: String, moverCp: Int?)?) {
        guard let continuation = pendingContinuation else { return }
        pendingContinuation = nil
        continuation.resume(returning: value)
    }

    /// Borne dure : conclut la requête `id` par `nil` plutôt que de figer
    /// l'appelant, puis arrête la recherche et NOTE que son `bestmove` est à
    /// jeter quand il finira par arriver. Le garde sur `pendingContinuation`
    /// est essentiel : si le `bestmove` était déjà arrivé, la requête est
    /// résolue normalement et il n'y a aucun reliquat à attendre.
    private func hardStopIfPending(_ id: Int) async {
        guard id == requestID, pendingContinuation != nil else { return }
        staleBestmovesToDiscard += 1
        resolve(with: nil)
        await engine.send(command: .stop)
    }

    private func forceStopIfPending(_ id: Int) async {
        guard id == requestID, pendingContinuation != nil else { return }
        await engine.send(command: .stop)
    }
}
