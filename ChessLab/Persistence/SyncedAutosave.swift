import Foundation

/// Ce qui voyage dans le nuage pour une partie EN COURS : la partie elle-même (le JSON que l'appareil garde
/// déjà dans `Documents/`), ou — `game == nil` — une PIERRE TOMBALE : « cette partie est terminée, ou a été
/// remplacée, à telle heure ».
///
/// Pourquoi une pierre tombale plutôt que supprimer la clé : un magasin clé-valeur sait dire « il y a
/// quelque chose », pas « il y avait quelque chose, et c'est fini ». Sans trace datée de la fin, l'appareil
/// qui n'a pas vu la partie se terminer la reproposerait indéfiniment ; avec elle, la règle de fusion est
/// la même dans les deux sens (voir ``AutosaveMerge``).
struct AutosaveEnvelope: Codable, Equatable {
    /// L'instant de l'écriture : le `savedAt` de la partie, ou l'instant de sa fin.
    var at: Date
    var game: Data?
    /// L'appareil qui a écrit (voir ``CloudDeviceIdentity``) — pour dire à l'accueil « dernier coup joué sur
    /// votre iPad ». Optionnels : les enveloppes des premières versions n'en ont pas.
    var deviceID: String? = nil
    var device: String? = nil
    /// Son identifiant matériel (« iPhone12,1 »), pour dire « votre iPhone 11 » plutôt que « votre iPhone ».
    var model: String? = nil
    /// Le nom que l'utilisateur lui a donné dans « Vos appareils » (« iPad cuisine »), s'il y en a un.
    var name: String? = nil
    /// La dernière partie que CET appareil a terminée ou remplacée (son ``AutosaveRecord/gameID``) ; pour une
    /// pierre tombale, la partie qu'elle enterre. Un autre appareil qui l'a encore en cours sait ainsi qu'elle
    /// a été close sciemment, et ne la met pas de côté.
    var endedGameID: String? = nil

    /// « Votre … » : le nom donné, sinon le modèle, sinon le type.
    var originLabel: String? { name ?? model ?? device }

    /// Vrai si cet envoi annonce la fin (ou le remplacement) de `record`.
    func ended<Record: AutosaveRecord>(_ record: Record) -> Bool {
        guard let endedGameID, let id = record.gameID else { return false }
        return endedGameID == id.uuidString
    }
}

/// La règle de fusion, isolée et pure pour être éprouvée sans appareil : **la dernière écriture gagne**.
///
/// Elle repose sur l'horloge des appareils. Deux iPhone et iPad réglés sur l'heure du réseau (le cas
/// courant) se départagent à la seconde près ; un appareil dont l'horloge serait décalée de plusieurs
/// minutes pourrait l'emporter à tort — le prix d'un modèle sans serveur, et sans conséquence grave : au
/// pire, on reprend l'autre partie.
enum AutosaveMerge {
    enum Outcome: Equatable {
        /// Garder la partie de CET appareil (ou l'absence de partie).
        case keepLocal
        /// Une partie plus récente est arrivée d'un autre appareil : la reprendre.
        case adoptRemote(Data)
        /// La partie locale a été terminée (ou remplacée) ailleurs, après son dernier coup : l'oublier.
        case dropLocal
    }

    static func resolve(localSavedAt: Date?, remote: AutosaveEnvelope?) -> Outcome {
        guard let remote else { return .keepLocal }
        if let game = remote.game {
            // Strictement plus récent : à égalité on garde la sienne, pour ne pas réécrire sans raison.
            if let localSavedAt, remote.at <= localSavedAt { return .keepLocal }
            return .adoptRemote(game)
        }
        // Pierre tombale : elle ne vaut que contre une partie locale ANTÉRIEURE à la fin.
        if let localSavedAt, localSavedAt <= remote.at { return .dropLocal }
        return .keepLocal
    }
}

/// Ce que ``SyncedAutosave`` doit savoir d'une partie en cours.
protocol AutosaveRecord: Codable {
    var savedAt: Date { get set }
    /// L'identité de la partie, stable d'un coup à l'autre et d'un appareil à l'autre. `nil` : sauvegarde
    /// d'avant le 16/11/2026.
    var gameID: UUID? { get }
    var moveLANs: [String] { get }
}

extension AutosaveRecord {
    /// La MÊME partie — sa suite, ou un état antérieur après une reprise de coup : même identifiant ; à
    /// défaut (sauvegardes d'avant l'identifiant), l'une prolonge l'autre.
    func isSameGame(as other: Self) -> Bool {
        if let mine = gameID, let theirs = other.gameID { return mine == theirs }
        let (short, long) = moveLANs.count <= other.moveLANs.count
            ? (moveLANs, other.moveLANs) : (other.moveLANs, moveLANs)
        return long.starts(with: short)
    }
}

/// Une sauvegarde de partie en cours, locale (fichier JSON) et — si l'utilisateur a allumé la synchronisation
/// iCloud — recopiée dans le magasin clé-valeur iCloud, pour qu'un autre de SES appareils la propose à la
/// reprise.
///
/// ## Pourquoi le magasin clé-valeur, et pas SwiftData/CloudKit
///
/// Une partie tient en quelques ko ; le magasin clé-valeur la porte en quelques secondes, sans type CloudKit
/// à ajouter (et donc sans « Deploy Schema » en production). C'est aussi celui des réglages
/// (``SettingsCloudSync``) : un seul interrupteur, une seule logique.
///
/// ## Garanties
///
/// - **Interrupteur éteint : rien n'est écrit dans le nuage**, jamais. Le magasin clé-valeur, une fois qu'on
///   y écrit, se synchronise tout seul ; l'éteindre doit donc rester un silence complet.
/// - Le fichier local reste la source lue par l'app, et son format n'a pas changé : une version sans cette
///   synchronisation relit le même fichier.
/// - **Une partie n'est jamais perdue en silence.** La suite de la même partie, venue d'un autre appareil,
///   est reprise telle quelle. Une AUTRE partie, plus récente, devient la partie en cours, et celle d'ici
///   est **mise de côté** sur cet appareil (une place : la plus récente des deux reste) — l'accueil la
///   propose à côté (essai sur trois iPhone, 16/11/2026 : une partie lancée sur l'un remplaçait celle d'un
///   autre). Seule exception : la partie que l'utilisateur a lui-même terminée ou remplacée sur un autre
///   appareil — l'enveloppe le dit (``AutosaveEnvelope/endedGameID``), et l'avertissement de « Commencer »
///   l'avait annoncé.
struct SyncedAutosave<Record: AutosaveRecord> {
    let key: String
    let fileURL: () -> URL
    let store: KeyValueStoring
    let isEnabled: () -> Bool
    /// Cet appareil, pour signer ce qu'il publie (absent dans les tests qui n'en ont pas besoin).
    var identity: CloudDeviceIdentity? = nil
    /// Où retenir de quel AUTRE appareil vient la partie adoptée (voir ``origin()``), et la dernière partie
    /// terminée ici.
    var originDefaults: UserDefaults? = nil
    /// La place de la partie mise de côté (locale, jamais publiée). `nil` : pas de mise de côté.
    var asideURL: (() -> URL)? = nil

    private var originKey: String { key + ".origin" }
    private var endedKey: String { key + ".ended" }

    /// L'appareil où a été joué le dernier coup de la partie proposée, s'il ne s'agit pas de celui-ci : le
    /// nom que l'utilisateur lui a donné, sinon son identifiant matériel (« iPhone12,1 »), sinon — d'une
    /// version qui ne donnait ni l'un ni l'autre — son type (« iPad »). À montrer par
    /// ``DeviceModelName/display(_:language:)``. Effacé dès qu'on joue ici.
    func origin() -> String? {
        originDefaults?.string(forKey: originKey)
    }

    private func setOrigin(_ kind: String?) {
        guard let originDefaults else { return }
        if let kind { originDefaults.set(kind, forKey: originKey) } else { originDefaults.removeObject(forKey: originKey) }
    }

    // MARK: Écriture

    func save(_ record: Record) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: fileURL(), options: .atomic)
        setOrigin(nil)
        publish(data, at: record.savedAt)
    }

    /// La partie est terminée, ou remplacée par une nouvelle : le fichier disparaît, et le nuage reçoit une
    /// pierre tombale qui NOMME cette partie — elle ne vaudra que contre elle.
    func clear() {
        if let originDefaults {
            if let ended = localRecord()?.gameID {
                originDefaults.set(ended.uuidString, forKey: endedKey)
            } else if localRecord() != nil {
                originDefaults.removeObject(forKey: endedKey)
            }
        }
        try? FileManager.default.removeItem(at: fileURL())
        setOrigin(nil)
        guard isEnabled() else { return }
        write(envelope(at: Date(), game: nil))
    }

    // MARK: Lecture

    /// La partie à proposer : la locale, ou une plus récente arrivée d'ailleurs (qui est alors adoptée,
    /// c'est-à-dire écrite dans le fichier local — la reprise la relit comme n'importe quelle autre). Si
    /// celle qui arrive est une AUTRE partie, la locale est mise de côté (voir les garanties).
    func load() -> Record? {
        let localData = try? Data(contentsOf: fileURL())
        let local = localData.flatMap { try? JSONDecoder().decode(Record.self, from: $0) }
        guard isEnabled() else { return local }

        let remote = remoteEnvelope()
        switch AutosaveMerge.resolve(localSavedAt: local?.savedAt, remote: remote) {
        case .keepLocal:
            // Notre partie est PLUS RÉCENTE que ce que le nuage connaît (écrite quand la synchro était
            // éteinte, par exemple) : on la lui apprend, pour que les autres appareils la voient.
            if let local, let localData, let remote, remote.at < local.savedAt {
                publish(localData, at: local.savedAt)
            }
            return local
        case .dropLocal:
            // La pierre tombale nomme la partie terminée : si c'en est une AUTRE, la nôtre n'a rien à craindre.
            if let local, let mine = local.gameID?.uuidString, let ended = remote?.endedGameID, ended != mine {
                return local
            }
            try? FileManager.default.removeItem(at: fileURL())
            setOrigin(nil)
            return nil
        case let .adoptRemote(data):
            guard let record = try? JSONDecoder().decode(Record.self, from: data) else { return local }
            if let local, !local.isSameGame(as: record), remote?.ended(local) != true {
                setAside(local)
            }
            try? data.write(to: fileURL(), options: .atomic)
            let fromElsewhere = remote?.deviceID != nil && remote?.deviceID != identity?.id
            setOrigin(fromElsewhere ? remote?.originLabel : nil)
            return record
        }
    }

    /// À appeler au lancement, magasin synchronisé : si le nuage ne connaît AUCUNE partie et que l'appareil
    /// en a une, la lui confier — le premier appareil est « fondateur », comme pour les réglages.
    func publishLocalIfCloudIsEmpty() {
        guard isEnabled(), remoteEnvelope() == nil,
              let data = try? Data(contentsOf: fileURL()),
              let record = try? JSONDecoder().decode(Record.self, from: data) else { return }
        publish(data, at: record.savedAt)
    }

    // MARK: Mise de côté

    /// La partie mise de côté sur cet appareil, s'il y en a une — et si ce n'est pas, entre-temps, devenue la
    /// partie en cours elle-même (reprise ailleurs puis revenue) : la place se libère alors d'elle-même.
    func aside() -> Record? {
        guard let asideURL, let data = try? Data(contentsOf: asideURL()),
              let record = try? JSONDecoder().decode(Record.self, from: data) else { return nil }
        if let current = localRecord(), current.isSameGame(as: record) {
            try? FileManager.default.removeItem(at: asideURL())
            return nil
        }
        return record
    }

    /// Reprendre la partie mise de côté : elle redevient la partie en cours (ici et, synchro allumée, sur
    /// les autres appareils — où celle qu'elle remplace est à son tour mise de côté), et la partie en cours
    /// prend sa place de côté. Un échange : rien ne se perd. Rend la partie reprise.
    func resumeAside(now: Date = Date()) -> Record? {
        guard let asideURL, var resumed = aside() else { return nil }
        if let current = localRecord(), let data = try? JSONEncoder().encode(current) {
            try? data.write(to: asideURL(), options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: asideURL())
        }
        // Touchée maintenant : sans quoi la partie remplacée, plus récente, la chasserait au prochain
        // rapprochement.
        resumed.savedAt = now
        save(resumed)
        return resumed
    }

    /// « Oublier » la partie mise de côté.
    func discardAside() {
        guard let asideURL else { return }
        try? FileManager.default.removeItem(at: asideURL())
    }

    private func setAside(_ record: Record) {
        guard let asideURL else { return }
        // Une seule place : la plus récente des deux reste.
        if let existing = aside(), existing.savedAt > record.savedAt { return }
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: asideURL(), options: .atomic)
    }

    // MARK: Détail

    func remoteEnvelope() -> AutosaveEnvelope? {
        guard let data = store.object(forKey: key) as? Data else { return nil }
        return try? JSONDecoder().decode(AutosaveEnvelope.self, from: data)
    }

    /// La partie que porte le nuage, si elle vient d'un AUTRE appareil — pour le bandeau « cette partie a
    /// avancé sur votre … » de l'échiquier ouvert.
    func remoteGameFromElsewhere() -> (record: Record, origin: String?)? {
        guard isEnabled(), let remote = remoteEnvelope(), let data = remote.game,
              remote.deviceID != nil, remote.deviceID != identity?.id,
              let record = try? JSONDecoder().decode(Record.self, from: data) else { return nil }
        return (record, remote.originLabel)
    }

    private func localRecord() -> Record? {
        guard let data = try? Data(contentsOf: fileURL()) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    private func envelope(at date: Date, game: Data?) -> AutosaveEnvelope {
        AutosaveEnvelope(at: date, game: game, deviceID: identity?.id, device: identity?.kind,
                         model: identity?.model, name: identity?.name,
                         endedGameID: originDefaults?.string(forKey: endedKey))
    }

    private func publish(_ data: Data, at date: Date) {
        guard isEnabled() else { return }
        write(envelope(at: date, game: data))
    }

    private func write(_ envelope: AutosaveEnvelope) {
        guard let encoded = try? JSONEncoder().encode(envelope) else { return }
        store.set(encoded, forKey: key)
        store.synchronize()
    }
}

extension SyncedAutosave where Record == PlayGameAutosave {
    /// Le mode Jouer (contre l'ordinateur).
    static var play: Self {
        SyncedAutosave(
            key: "autosave.play.v1",
            fileURL: { AutosaveStore.documentURL("autosave_play.json") },
            store: NSUbiquitousKeyValueStore.default,
            isEnabled: { CloudSyncSettingsStore.isEnabled },
            identity: .current,
            originDefaults: .standard,
            asideURL: { AutosaveStore.documentURL("autosave_play_aside.json") })
    }
}

extension SyncedAutosave where Record == TwoPlayerGameAutosave {
    /// Le mode Deux joueurs.
    static var twoPlayer: Self {
        SyncedAutosave(
            key: "autosave.twoplayer.v1",
            fileURL: { AutosaveStore.documentURL("autosave_twoplayer.json") },
            store: NSUbiquitousKeyValueStore.default,
            isEnabled: { CloudSyncSettingsStore.isEnabled },
            identity: .current,
            originDefaults: .standard,
            asideURL: { AutosaveStore.documentURL("autosave_twoplayer_aside.json") })
    }
}

/// Les clés des parties en cours dans le magasin clé-valeur, et la nouvelle d'un changement venu d'ailleurs.
enum AutosaveCloud {
    static let keys = ["autosave.play.v1", "autosave.twoplayer.v1"]
    /// Postée (sur le fil principal) quand un autre appareil a modifié une partie en cours : l'accueil
    /// relit alors la reprise.
    static let didChangeRemotely = Notification.Name("chesslab.autosaveDidChangeRemotely")

    nonisolated(unsafe) private static var observer: NSObjectProtocol?

    /// Débranche l'écoute (synchro éteinte en cours de session). Idempotent.
    @MainActor
    static func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    /// Quand la synchro est allumée (au lancement, ou à la bascule de l'interrupteur) : confie au nuage les parties qu'il ne connaît pas, puis
    /// écoute les changements des autres appareils. Idempotent.
    @MainActor
    static func start() {
        guard CloudSyncSettingsStore.isEnabled, observer == nil else { return }
        NSUbiquitousKeyValueStore.default.synchronize()
        SyncedAutosave.play.publishLocalIfCloudIsEmpty()
        SyncedAutosave.twoPlayer.publishLocalIfCloudIsEmpty()
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil, queue: .main
        ) { notification in
            let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? keys
            guard changed.contains(where: keys.contains) else { return }
            NotificationCenter.default.post(name: didChangeRemotely, object: nil)
        }
    }
}
