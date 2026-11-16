import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData

/// L'état de la synchronisation, en UN mot pour l'utilisateur — la carte des Réglages n'affiche que lui
/// (plus le détail qui va avec). Résolu par une fonction pure, pour être éprouvé sans iCloud.
enum CloudSyncState: Equatable {
    /// Interrupteur éteint, et rien ne tourne.
    case off
    /// Interrupteur allumé, mais le conteneur SwiftData de ce lancement est local : il faut relancer.
    case startsAfterRestart
    /// Interrupteur éteint, mais CloudKit tourne encore jusqu'au prochain lancement.
    case stopsAfterRestart
    case checkingAccount
    /// Aucun compte iCloud sur l'appareil.
    case noAccount
    /// Compte présent mais iCloud indisponible (vérification en cours côté iOS, restriction…).
    case accountUnavailable
    /// Le dernier échange a échoué ; le message dit pourquoi, en clair.
    case paused(String)
    case syncing
    /// Rien en cours, aucune erreur : le dernier échange réussi, s'il y en a eu un.
    case upToDate(Date?)

    enum Account: Equatable { case unknown, available, signedOut, unavailable }

    static func resolve(enabled: Bool, activeAtLaunch: Bool, account: Account, failure: String?,
                        isExchanging: Bool, lastExchange: Date?) -> CloudSyncState {
        switch (enabled, activeAtLaunch) {
        case (false, false): return .off
        case (false, true): return .stopsAfterRestart
        case (true, false): return .startsAfterRestart
        case (true, true): break
        }
        switch account {
        case .unknown: return .checkingAccount
        case .signedOut: return .noAccount
        case .unavailable: return .accountUnavailable
        case .available: break
        }
        if let failure { return .paused(failure) }
        if isExchanging { return .syncing }
        return .upToDate(lastExchange)
    }
}

/// Ce qu'on sait, RÉELLEMENT, de la synchronisation CloudKit — par opposition à ce qu'on supposait.
///
/// Jusqu'à la 2.3, les Réglages affichaient « Dernière vérification : il y a 2 minutes », qui datait la
/// dernière FUSION LOCALE, pas un échange avec iCloud : la ligne pouvait rassurer pendant que rien ne
/// passait (retour d'un utilisateur, 16/11/2026 : deux appareils, chacun dans son état). SwiftData pilote
/// CloudKit par un `NSPersistentCloudKitContainer` interne, qui annonce chacun de ses échanges
/// (`eventChangedNotification`) : mise en place, réception, envoi, avec l'heure de fin et l'erreur éventuelle.
/// On les écoute, et on n'affiche que cela.
///
/// ## Ce que cette classe ne peut PAS faire
///
/// Forcer CloudKit à aller chercher maintenant. iOS décide du moment (notifications silencieuses, énergie,
/// réseau) ; SwiftData n'expose aucune commande « synchroniser ». ``syncNow(context:)`` fait donc tout ce
/// qui est à portée — fusionner ce qui est arrivé, enregistrer ce qui attend, rafraîchir le magasin clé-valeur
/// — puis REGARDE si un échange a eu lieu, et le dit sans promettre.
@MainActor
@Observable
final class CloudSyncMonitor {
    static let shared = CloudSyncMonitor()

    enum Kind: Equatable { case setup, receive, send }

    struct Failure: Equatable {
        let message: String
        let at: Date
    }

    enum ManualResult: Equatable {
        /// Un échange réussi avec iCloud pendant l'attente.
        case exchanged
        /// Aucun échange pendant l'attente : rien à envoyer ni à recevoir, ou iCloud choisira le moment.
        case nothingSeen
        /// Les réglages et les parties en cours sont à jour, mais le conteneur SwiftData de CE lancement
        /// n'est pas celui que l'interrupteur demande : le reste attend la fermeture et la réouverture.
        case restartNeeded
        case failed(String)
    }

    private(set) var lastReceiveAt: Date?
    private(set) var lastSendAt: Date?
    private(set) var failure: Failure?
    private(set) var isManualSyncRunning = false
    private(set) var manualResult: ManualResult?
    private(set) var account: CloudSyncState.Account = .unknown
    /// Les échanges commencés et pas encore terminés, avec l'heure de leur début.
    private(set) var inFlight: [UUID: Date] = [:]

    private let defaults: UserDefaults
    private var observer: NSObjectProtocol?
    private var accountObserver: NSObjectProtocol?
    static let containerID = "iCloud.com.chesslab.ChessLab"

    private enum Key {
        static let receive = "sync.lastReceiveAt"
        static let send = "sync.lastSendAt"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastReceiveAt = Self.date(defaults, Key.receive)
        lastSendAt = Self.date(defaults, Key.send)
    }

    private static func date(_ defaults: UserDefaults, _ key: String) -> Date? {
        let value = defaults.double(forKey: key)
        return value > 0 ? Date(timeIntervalSince1970: value) : nil
    }

    // MARK: Écoute

    /// Branche l'écoute des événements CloudKit. Idempotent ; sans effet utile si CloudKit est éteint
    /// (aucun événement n'arrive).
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            let id = event.identifier
            let start = event.startDate
            guard let end = event.endDate else {
                // Un échange COMMENCE : « Synchronisation… » jusqu'à sa fin.
                MainActor.assumeIsolated { self?.recordStart(id: id, at: start) }
                return
            }
            let kind: Kind
            switch event.type {
            case .setup: kind = .setup
            case .import: kind = .receive
            case .export: kind = .send
            @unknown default: return
            }
            let succeeded = event.succeeded
            let message = event.error.map { CloudSyncErrorText.describe($0) }
            MainActor.assumeIsolated {
                self?.record(kind: kind, endedAt: end, succeeded: succeeded, errorMessage: message, id: id)
            }
        }
        accountObserver = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Task { await self.refreshAccount() }
            }
        }
        Task { await refreshAccount() }
    }

    /// Relit l'état du compte iCloud de l'appareil.
    func refreshAccount() async {
        do {
            let status = try await CKContainer(identifier: Self.containerID).accountStatus()
            account = switch status {
            case .available: .available
            case .noAccount: .signedOut
            default: .unavailable
            }
        } catch {
            account = .unavailable
        }
    }

    /// L'état à afficher. `enabled` vient de l'interrupteur tel que la vue le voit.
    func state(enabled: Bool, now: Date = Date()) -> CloudSyncState {
        CloudSyncState.resolve(
            enabled: enabled, activeAtLaunch: CloudSyncSettingsStore.activeAtLaunch, account: account,
            failure: failure?.message, isExchanging: isExchanging(now: now), lastExchange: lastExchange)
    }

    /// Le plus récent des échanges réussis, dans un sens ou dans l'autre.
    var lastExchange: Date? { [lastSendAt, lastReceiveAt].compactMap { $0 }.max() }

    /// Un échange est en cours. Garde-fou : un échange dont la fin n'est jamais annoncée cesse de compter au
    /// bout de deux minutes — la carte ne doit pas tourner à vide indéfiniment.
    func isExchanging(now: Date = Date()) -> Bool {
        inFlight.values.contains { now.timeIntervalSince($0) < 120 }
    }

    func recordStart(id: UUID, at start: Date) {
        inFlight[id] = start
    }

    /// Le cœur testable : un échange terminé entre dans l'état affiché.
    func record(kind: Kind, endedAt: Date, succeeded: Bool, errorMessage: String?, id: UUID? = nil) {
        if let id { inFlight[id] = nil }
        if succeeded {
            switch kind {
            case .receive:
                lastReceiveAt = endedAt
                defaults.set(endedAt.timeIntervalSince1970, forKey: Key.receive)
            case .send:
                lastSendAt = endedAt
                defaults.set(endedAt.timeIntervalSince1970, forKey: Key.send)
            case .setup:
                break
            }
            // Un échange réussi lave l'erreur d'avant : on n'affiche pas un problème RÉSOLU.
            if kind != .setup { failure = nil }
        } else if let errorMessage {
            failure = Failure(message: errorMessage, at: endedAt)
        }
    }

    // MARK: Synchronisation manuelle

    /// Le bouton « Synchroniser maintenant ».
    ///
    /// Fait ce qui est à portée (voir l'en-tête), puis attend jusqu'à `patience` secondes qu'un échange
    /// CloudKit se produise, et rapporte ce qu'il a vu — un échange réussi, une erreur, ou rien.
    func syncNow(context: ModelContext, patience: Int = 20) async {
        guard !isManualSyncRunning else { return }
        isManualSyncRunning = true
        manualResult = nil
        defer { isManualSyncRunning = false }

        let started = Date()
        // 0. Le magasin clé-valeur suit l'interrupteur en direct : on s'assure que l'écoute est posée.
        KeyValueSyncSwitch.apply()
        Task { await refreshAccount() }
        CloudDeviceRegistry.live.checkIn(force: true)
        // 1. Les données SwiftData : fusionner ce qui est arrivé, enregistrer ce qui attend (l'envoi
        //    suit l'enregistrement).
        PuzzleProgressSync.reconcile(in: context)
        OpeningProgressSync.reconcile(in: context)
        try? context.save()
        // 2. Les réglages et les parties en cours : le magasin clé-valeur, qu'on peut rafraîchir.
        if SettingsCloudSync.shared.syncNow() {
            AppSettings.shared.reloadSyncedValuesFromDefaults()
        }
        SyncedAutosave.play.publishLocalIfCloudIsEmpty()
        SyncedAutosave.twoPlayer.publishLocalIfCloudIsEmpty()
        NotificationCenter.default.post(name: AutosaveCloud.didChangeRemotely, object: nil)
        // 3. Si le conteneur SwiftData n'est pas celui de l'interrupteur, aucun échange CloudKit n'est à
        //    attendre : le dire, plutôt que patienter 20 s pour conclure « rien de nouveau » à tort.
        if CloudSyncSettingsStore.isEnabled != CloudSyncSettingsStore.activeAtLaunch {
            manualResult = .restartNeeded
            return
        }
        // 4. Regarder si CloudKit a bougé.
        manualResult = await watchForExchange(since: started, patience: patience)
    }

    /// L'interrupteur a bougé : le résultat du dernier appui ne veut plus rien dire.
    func clearManualResult() { manualResult = nil }

    /// Attend jusqu'à `patience` secondes qu'un échange (ou une erreur) se produise après `started`.
    func watchForExchange(since started: Date, patience: Int) async -> ManualResult {
        for _ in 0..<max(1, patience) {
            try? await Task.sleep(for: .seconds(1))
            if let result = outcome(since: started) { return result }
        }
        return .nothingSeen
    }

    /// Ce que l'attente a vu depuis `started`, ou `nil` s'il ne s'est encore rien passé.
    func outcome(since started: Date) -> ManualResult? {
        if let failure, failure.at >= started { return .failed(failure.message) }
        if let lastReceiveAt, lastReceiveAt >= started { return .exchanged }
        if let lastSendAt, lastSendAt >= started { return .exchanged }
        return nil
    }
}

/// Un message clair pour les échecs de CloudKit — pas un code. Les erreurs arrivent enveloppées
/// (`NSCocoaErrorDomain` avec la vraie erreur CloudKit en « sous-jacente ») : on la déballe.
enum CloudSyncErrorText {
    static func describe(_ error: Error) -> String {
        var current: NSError? = error as NSError
        while let candidate = current {
            if candidate.domain == CKError.errorDomain {
                return describe(code: candidate.code)
            }
            current = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return LocalizationController.string("Erreur iCloud inattendue.")
    }

    static func describe(code: Int) -> String {
        switch CKError.Code(rawValue: code) {
        case .notAuthenticated, .badContainer, .permissionFailure:
            return LocalizationController.string("Aucun compte iCloud n'est connecté sur cet appareil.")
        case .networkUnavailable, .networkFailure:
            return LocalizationController.string("Pas de connexion réseau pour le moment.")
        case .quotaExceeded:
            return LocalizationController.string("Le stockage iCloud est plein.")
        case .requestRateLimited, .zoneBusy, .serviceUnavailable:
            return LocalizationController.string("iCloud est occupé ; nouvel essai automatique.")
        case .accountTemporarilyUnavailable:
            return LocalizationController.string("iCloud est momentanément indisponible.")
        default:
            return LocalizationController.string("Erreur iCloud (code %lld).", code)
        }
    }
}
