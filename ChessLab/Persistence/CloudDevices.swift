import Foundation
import Security

/// « Vos appareils » : chaque appareil dont la synchronisation iCloud est ALLUMÉE dépose une petite fiche
/// dans le magasin clé-valeur iCloud — son type (iPhone, iPad, Mac), sa version de ChessLab, l'heure de sa
/// dernière activité. Les Réglages en font la liste ; l'accueil d'un appareil où la synchro est éteinte s'en
/// sert pour proposer de l'allumer.
///
/// Pourquoi : le retour d'un utilisateur (16/11/2026) — deux appareils, chacun dans son état, et rien pour
/// voir que l'un des deux n'était pas relié. Une liste répond d'un coup d'œil à « mon iPad est-il branché ? ».
///
/// ## Garanties
///
/// - **Synchro éteinte : aucune écriture.** On LIT (pour proposer), on n'écrit jamais. Éteindre la synchro
///   retire sa propre fiche — la seule écriture après extinction, et c'est un effacement.
/// - Une fiche PAR appareil (une clé chacune) : le magasin résout les conflits clé par clé, deux appareils ne
///   peuvent donc pas s'écraser mutuellement.
/// - Aucun nom d'appareil (iOS ne le donne plus sans autorisation spéciale), aucun identifiant matériel :
///   un UUID tiré au hasard, gardé dans le trousseau de CET appareil (``CloudDeviceIdentity``).
struct CloudDeviceRecord: Codable, Equatable, Identifiable {
    var id: String
    /// « iPhone », « iPad » ou « Mac » — identique dans toutes les langues.
    var kind: String
    var appVersion: String
    var lastSeen: Date
    /// L'identifiant matériel (« iPhone12,1 »), traduit à l'affichage par ``DeviceModelName``. Optionnel :
    /// les fiches des versions antérieures n'en ont pas, et un Mac n'en donne pas.
    var model: String? = nil
    /// Le système et sa version (« iOS 18.6 »), utile pour l'entraide. Optionnel, même raison.
    var system: String? = nil
    /// Le nom que l'utilisateur lui a donné (« iPad cuisine »), voir ``CloudDeviceName``.
    var name: String? = nil

    /// Le nom du MODÈLE : « iPhone 11 », « iPad Pro 13″ (M4) »… ou, à défaut (fiche ancienne, modèle trop
    /// récent pour la table), le type.
    var modelName: String {
        model.flatMap { DeviceModelName.name(for: $0) } ?? kind
    }

    /// Le nom à montrer : celui que l'utilisateur a donné, sinon le modèle.
    var displayName: String { name ?? modelName }

    /// Le symbole SF qui le représente.
    var symbol: String {
        switch kind {
        case "iPad": "ipad"
        case "Mac": "laptopcomputer"
        default: "iphone"
        }
    }

    /// Vrai si sa version de ChessLab est plus ANCIENNE que `version`.
    func isOlder(than version: String) -> Bool {
        appVersion.compare(version, options: .numeric) == .orderedAscending
    }
}

/// Qui est CET appareil, pour la liste.
struct CloudDeviceIdentity: Equatable {
    let id: String
    let kind: String
    /// Voir ``CloudDeviceRecord/model``.
    var model: String? = nil
    /// Voir ``CloudDeviceRecord/system``.
    var system: String? = nil
    /// Voir ``CloudDeviceRecord/name``.
    var name: String? = nil

    /// L'identité réelle, relue à chaque fois pour suivre le nom que l'utilisateur donne à l'appareil.
    static var current: CloudDeviceIdentity {
        var identity = hardware
        identity.name = CloudDeviceName.custom
        return identity
    }

    /// Ce qui ne change pas pendant une session. L'UUID vit dans le trousseau, réservé à cet appareil
    /// (`…ThisDeviceOnly`) : il survit à une réinstallation (pas de fiche en double pour le même iPhone),
    /// et ne suit pas une sauvegarde restaurée sur un AUTRE appareil.
    private static let hardware = CloudDeviceIdentity(
        id: KeychainDeviceID.value(), kind: currentKind(),
        model: currentModelIdentifier(), system: currentSystem())

    /// iPhone, iPad ou Mac — lu sans `UIDevice` (isolé au fil principal), par le modèle matériel.
    static func currentKind() -> String {
        let info = ProcessInfo.processInfo
        if info.isMacCatalystApp || info.isiOSAppOnMac { return "Mac" }
        return (currentModelIdentifier() ?? "").hasPrefix("iPad") ? "iPad" : "iPhone"
    }

    /// « iPhone12,1 », « iPad16,6 »… (au simulateur : celui de l'appareil simulé). `nil` sur Mac, où
    /// l'identifiant ne désigne pas un modèle que la table connaisse.
    static func currentModelIdentifier() -> String? {
        let info = ProcessInfo.processInfo
        if info.isMacCatalystApp || info.isiOSAppOnMac { return nil }
        if let simulated = info.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulated.isEmpty { return simulated }
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: system.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return machine.isEmpty ? nil : machine
    }

    /// « iOS 18.6 », « iPadOS 26.1 », « macOS 26.1 ». `nil` pour une app iPad sur Mac, qui ne voit qu'une
    /// version d'iOS d'emprunt, trompeuse.
    static func currentSystem() -> String? {
        let info = ProcessInfo.processInfo
        if info.isiOSAppOnMac { return nil }
        let version = info.operatingSystemVersion
        let number = version.patchVersion > 0
            ? "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            : "\(version.majorVersion).\(version.minorVersion)"
        let name = info.isMacCatalystApp ? "macOS" : (currentKind() == "iPad" ? "iPadOS" : "iOS")
        return "\(name) \(number)"
    }
}

/// Le nom que l'utilisateur donne à CET appareil dans « Vos appareils » (« iPad cuisine »), pour s'y
/// retrouver entre deux appareils du même modèle. Sans autorisation particulière d'Apple : c'est lui qui le
/// tape. Gardé sur l'appareil ; publié dans sa fiche, synchro allumée seulement.
enum CloudDeviceName {
    private static let key = "sync.deviceName"
    static let maxLength = 30

    /// `nil` : pas de nom donné (on montre le modèle). Un nom vide ou blanc l'efface.
    static var custom: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            let trimmed = (newValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: key)
            } else {
                UserDefaults.standard.set(String(trimmed.prefix(maxLength)), forKey: key)
            }
        }
    }
}

/// L'UUID de l'appareil, dans le trousseau (repli : `UserDefaults`, si le trousseau refuse).
private enum KeychainDeviceID {
    private static let account = "chesslab.sync.deviceID"

    static func value() -> String {
        if let existing = read() { return existing }
        let fresh = UUID().uuidString
        if !write(fresh) {
            // Trousseau indisponible (rare) : un identifiant local suffit, au prix d'une fiche en double
            // après une réinstallation.
            if let stored = UserDefaults.standard.string(forKey: account) { return stored }
            UserDefaults.standard.set(fresh, forKey: account)
        }
        return fresh
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String) -> Bool {
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}

/// La liste des appareils, dans le magasin clé-valeur. Pure à ses dépendances près, pour être éprouvée
/// avec un magasin factice.
struct CloudDeviceRegistry {
    static let keyPrefix = "device.v1."
    /// Pas plus d'une écriture par tranche de 10 minutes (le magasin limite le débit) — sauf changement de
    /// version, ou demande explicite (« Synchroniser maintenant »).
    static let checkInInterval: TimeInterval = 10 * 60
    /// Au-delà, une fiche n'est plus montrée : appareil vendu, effacé, oublié.
    static let forgetAfter: TimeInterval = 60 * 24 * 3600
    /// Au-delà, un appareil n'est plus une raison de proposer la synchro.
    static let inviteWithin: TimeInterval = 30 * 24 * 3600

    let store: KeyValueStoring
    let identity: CloudDeviceIdentity
    let appVersion: String
    let isEnabled: () -> Bool

    static var live: CloudDeviceRegistry {
        CloudDeviceRegistry(
            store: NSUbiquitousKeyValueStore.default,
            identity: .current,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            isEnabled: { CloudSyncSettingsStore.isEnabled })
    }

    private var ownKey: String { Self.keyPrefix + identity.id }

    // MARK: Écriture (synchro allumée seulement)

    /// « Je suis là » : dépose ou rafraîchit la fiche de cet appareil. Rend `true` si elle a été écrite.
    @discardableResult
    func checkIn(now: Date = Date(), force: Bool = false) -> Bool {
        guard isEnabled() else { return false }
        // Une fiche à jour (même version de ChessLab, même modèle, même système) n'est réécrite qu'au-delà
        // de l'intervalle ; une mise à jour d'iOS ou de l'app se voit tout de suite.
        if !force, let mine = record(forKey: ownKey), mine.appVersion == appVersion, mine.kind == identity.kind,
           mine.model == identity.model, mine.system == identity.system, mine.name == identity.name,
           now.timeIntervalSince(mine.lastSeen) < Self.checkInInterval {
            return false
        }
        let record = CloudDeviceRecord(id: identity.id, kind: identity.kind, appVersion: appVersion, lastSeen: now,
                                       model: identity.model, system: identity.system, name: identity.name)
        guard let data = try? JSONEncoder().encode(record) else { return false }
        store.set(data, forKey: ownKey)
        store.synchronize()
        return true
    }

    /// Synchro éteinte : retirer sa fiche, pour que les autres appareils ne nous croient plus reliés. Sans
    /// effet s'il n'y en a pas (un appareil qui n'a jamais synchronisé n'écrit RIEN).
    func checkOut() {
        guard !isEnabled(), store.object(forKey: ownKey) != nil else { return }
        store.removeObject(forKey: ownKey)
        store.synchronize()
    }

    // MARK: Lecture (toujours permise)

    /// Les appareils reliés : celui-ci d'abord, puis du plus récemment actif au plus ancien.
    func devices(now: Date = Date()) -> [CloudDeviceRecord] {
        let all = store.storedKeys
            .filter { $0.hasPrefix(Self.keyPrefix) }
            .compactMap(record(forKey:))
            .filter { $0.id == identity.id || now.timeIntervalSince($0.lastSeen) < Self.forgetAfter }
        return all.sorted { a, b in
            if (a.id == identity.id) != (b.id == identity.id) { return a.id == identity.id }
            return a.lastSeen > b.lastSeen
        }
    }

    func otherDevices(now: Date = Date()) -> [CloudDeviceRecord] {
        devices(now: now).filter { $0.id != identity.id }
    }

    /// L'appareil au nom duquel proposer la synchro, ou `nil` : synchro éteinte ici, un AUTRE appareil
    /// actif ces 30 derniers jours, et que l'utilisateur n'a pas déjà décliné.
    func invitation(dismissed: Set<String>, now: Date = Date()) -> CloudDeviceRecord? {
        guard !isEnabled() else { return nil }
        return otherDevices(now: now).first {
            !dismissed.contains($0.id) && now.timeIntervalSince($0.lastSeen) < Self.inviteWithin
        }
    }

    private func record(forKey key: String) -> CloudDeviceRecord? {
        guard let data = store.object(forKey: key) as? Data else { return nil }
        return try? JSONDecoder().decode(CloudDeviceRecord.self, from: data)
    }
}

/// Le branchement de la liste dans l'app : écoute des changements (en LECTURE, même synchro éteinte — c'est
/// ce qui permet de proposer), et mémoire des propositions déclinées.
enum CloudDevices {
    /// Postée sur le fil principal quand une fiche d'appareil change (ici ou ailleurs).
    static let didChange = Notification.Name("chesslab.cloudDevicesDidChange")

    private static let dismissedKey = "sync.invitationDismissed"
    nonisolated(unsafe) private static var observer: NSObjectProtocol?

    @MainActor
    static func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil, queue: .main
        ) { notification in
            let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            guard changed?.contains(where: { $0.hasPrefix(CloudDeviceRegistry.keyPrefix) }) ?? true else { return }
            NotificationCenter.default.post(name: didChange, object: nil)
        }
    }

    /// Les appareils au nom desquels l'utilisateur a déjà répondu « Pas maintenant ».
    static var dismissed: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? [])
    }

    static func dismissInvitation(from device: CloudDeviceRecord) {
        UserDefaults.standard.set(Array(dismissed.union([device.id])), forKey: dismissedKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}

#if DEBUG && targetEnvironment(simulator)
/// Crochet de test (simulateur, Debug) : `-fakeSyncDevice` dépose la fiche d'un iPad fictif, pour voir la
/// proposition de l'accueil et la liste des appareils sans second appareil. Sans l'argument, la fiche est
/// retirée si elle traîne.
enum DebugSyncDevice {
    static let id = "debug-ipad"

    static func apply(arguments: [String] = CommandLine.arguments) {
        let store = NSUbiquitousKeyValueStore.default
        let key = CloudDeviceRegistry.keyPrefix + id
        if arguments.contains("-fakeSyncDevice") {
            let record = CloudDeviceRecord(id: id, kind: "iPad", appVersion: "2.3",
                                           lastSeen: Date(timeIntervalSinceNow: -240),
                                           model: "iPad16,6", system: "iPadOS 26.1")
            store.set(try? JSONEncoder().encode(record), forKey: key)
        } else if store.object(forKey: key) != nil {
            store.removeObject(forKey: key)
        }
    }

    /// Crochets de test de la partie en cours, joués par l'« iPad » fictif dès qu'une partie Jouer d'au
    /// moins deux coups a été publiée ici :
    /// - `-fakeRemoteTakeback` : il reprend les deux derniers demi-coups de la MÊME partie (bandeau de
    ///   l'échiquier ; l'utilisateur a de nouveau le trait, rien ne bouge ensuite) ;
    /// - `-fakeRemoteOtherGame` : il commence une AUTRE partie (mise de côté à l'accueil).
    /// Une seule fois par lancement.
    @MainActor private static var fakeRemoteStarted = false

    @MainActor
    static func startFakeRemoteActivity(arguments: [String] = CommandLine.arguments) {
        let takeback = arguments.contains("-fakeRemoteTakeback")
        guard takeback || arguments.contains("-fakeRemoteOtherGame"), !fakeRemoteStarted else { return }
        fakeRemoteStarted = true
        Task { @MainActor in
            while true {
                try? await Task.sleep(for: .seconds(2))
                let autosave = SyncedAutosave.play
                guard CloudSyncSettingsStore.isEnabled,
                      let data = try? Data(contentsOf: AutosaveStore.documentURL("autosave_play.json")),
                      let local = try? JSONDecoder().decode(PlayGameAutosave.self, from: data),
                      local.moveLANs.count >= 2,
                      autosave.remoteEnvelope()?.deviceID == CloudDeviceIdentity.current.id else { continue }
                var remote = local
                remote.savedAt = Date()
                if takeback {
                    remote.moveLANs.removeLast(2)
                } else {
                    remote.gameID = UUID()
                    remote.moveLANs = ["d2d4", "d7d5"]
                }
                let envelope = AutosaveEnvelope(at: remote.savedAt, game: try? JSONEncoder().encode(remote),
                                                deviceID: id, device: "iPad", model: "iPad16,6")
                NSUbiquitousKeyValueStore.default.set(try? JSONEncoder().encode(envelope), forKey: autosave.key)
                NotificationCenter.default.post(name: AutosaveCloud.didChangeRemotely, object: nil)
                return
            }
        }
    }
}
#endif
