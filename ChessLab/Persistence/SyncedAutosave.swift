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
/// - Deux parties DIFFÉRENTES commencées sur deux appareils : la plus récemment jouée gagne, l'autre est
///   remplacée. C'est le prix de « reprendre ailleurs » ; l'aide le dit.
struct SyncedAutosave<Record: Codable> {
    let key: String
    let fileURL: () -> URL
    let savedAt: (Record) -> Date
    let store: KeyValueStoring
    let isEnabled: () -> Bool
    /// Cet appareil, pour signer ce qu'il publie (absent dans les tests qui n'en ont pas besoin).
    var identity: CloudDeviceIdentity? = nil
    /// Où retenir de quel AUTRE appareil vient la partie adoptée (voir ``origin()``).
    var originDefaults: UserDefaults? = nil

    private var originKey: String { key + ".origin" }

    /// L'appareil (« iPad », « Mac »…) où a été joué le dernier coup de la partie proposée, s'il ne s'agit
    /// pas de celui-ci. Effacé dès qu'on joue ici.
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
        publish(data, at: savedAt(record))
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL())
        setOrigin(nil)
        guard isEnabled() else { return }
        write(AutosaveEnvelope(at: Date(), game: nil, deviceID: identity?.id, device: identity?.kind))
    }

    // MARK: Lecture

    /// La partie à proposer : la locale, ou une plus récente arrivée d'ailleurs (qui est alors adoptée,
    /// c'est-à-dire écrite dans le fichier local — la reprise la relit comme n'importe quelle autre).
    func load() -> Record? {
        let localData = try? Data(contentsOf: fileURL())
        let local = localData.flatMap { try? JSONDecoder().decode(Record.self, from: $0) }
        guard isEnabled() else { return local }

        let remote = remoteEnvelope()
        switch AutosaveMerge.resolve(localSavedAt: local.map(savedAt), remote: remote) {
        case .keepLocal:
            // Notre partie est PLUS RÉCENTE que ce que le nuage connaît (écrite quand la synchro était
            // éteinte, par exemple) : on la lui apprend, pour que les autres appareils la voient.
            if let local, let localData, let remote, remote.at < savedAt(local) {
                publish(localData, at: savedAt(local))
            }
            return local
        case .dropLocal:
            try? FileManager.default.removeItem(at: fileURL())
            setOrigin(nil)
            return nil
        case let .adoptRemote(data):
            guard let record = try? JSONDecoder().decode(Record.self, from: data) else { return local }
            try? data.write(to: fileURL(), options: .atomic)
            let fromElsewhere = remote?.deviceID != nil && remote?.deviceID != identity?.id
            setOrigin(fromElsewhere ? remote?.device : nil)
            return record
        }
    }

    /// À appeler au lancement, magasin synchronisé : si le nuage ne connaît AUCUNE partie et que l'appareil
    /// en a une, la lui confier — le premier appareil est « fondateur », comme pour les réglages.
    func publishLocalIfCloudIsEmpty() {
        guard isEnabled(), remoteEnvelope() == nil,
              let data = try? Data(contentsOf: fileURL()),
              let record = try? JSONDecoder().decode(Record.self, from: data) else { return }
        publish(data, at: savedAt(record))
    }

    // MARK: Détail

    func remoteEnvelope() -> AutosaveEnvelope? {
        guard let data = store.object(forKey: key) as? Data else { return nil }
        return try? JSONDecoder().decode(AutosaveEnvelope.self, from: data)
    }

    private func publish(_ data: Data, at date: Date) {
        guard isEnabled() else { return }
        write(AutosaveEnvelope(at: date, game: data, deviceID: identity?.id, device: identity?.kind))
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
            savedAt: \.savedAt,
            store: NSUbiquitousKeyValueStore.default,
            isEnabled: { CloudSyncSettingsStore.isEnabled },
            identity: .current,
            originDefaults: .standard)
    }
}

extension SyncedAutosave where Record == TwoPlayerGameAutosave {
    /// Le mode Deux joueurs.
    static var twoPlayer: Self {
        SyncedAutosave(
            key: "autosave.twoplayer.v1",
            fileURL: { AutosaveStore.documentURL("autosave_twoplayer.json") },
            savedAt: \.savedAt,
            store: NSUbiquitousKeyValueStore.default,
            isEnabled: { CloudSyncSettingsStore.isEnabled },
            identity: .current,
            originDefaults: .standard)
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
