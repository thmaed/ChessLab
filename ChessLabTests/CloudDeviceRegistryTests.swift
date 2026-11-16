import Foundation
import Testing
@testable import ChessLab

/// « Vos appareils » et la proposition d'activer la synchro, éprouvés sans iCloud : un magasin clé-valeur
/// factice joue le nuage, chaque « appareil » a son identité et son interrupteur.
struct CloudDeviceRegistryTests {

    private final class FakeStore: KeyValueStoring {
        var values: [String: Any] = [:]
        private(set) var writes = 0
        func object(forKey key: String) -> Any? { values[key] }
        func set(_ value: Any?, forKey key: String) { values[key] = value; writes += 1 }
        var storedKeys: [String] { Array(values.keys) }
        @discardableResult func synchronize() -> Bool { true }
    }

    private final class Switch { var on: Bool; init(_ on: Bool) { self.on = on } }

    private func registry(_ store: FakeStore, id: String, kind: String = "iPhone", version: String = "2.4",
                          enabled: Switch) -> CloudDeviceRegistry {
        CloudDeviceRegistry(store: store, identity: CloudDeviceIdentity(id: id, kind: kind),
                            appVersion: version, isEnabled: { enabled.on })
    }

    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    // MARK: Interrupteur éteint : on lit, on n'écrit pas

    @Test func disabled_neverWrites() {
        let store = FakeStore()
        let phone = registry(store, id: "A", enabled: Switch(false))
        #expect(phone.checkIn(now: now) == false)
        #expect(phone.checkIn(now: now, force: true) == false)
        phone.checkOut()
        #expect(store.writes == 0)
        #expect(store.values.isEmpty)
    }

    @Test func turningSyncOff_removesOnlyOwnRecord() {
        let store = FakeStore()
        let phoneSwitch = Switch(true)
        let phone = registry(store, id: "A", enabled: phoneSwitch)
        let pad = registry(store, id: "B", kind: "iPad", enabled: Switch(true))
        phone.checkIn(now: now)
        pad.checkIn(now: now)
        phoneSwitch.on = false
        phone.checkOut()
        #expect(phone.devices(now: now).map(\.id) == ["B"])
    }

    // MARK: Débit

    @Test func checkIn_isThrottled_unlessForcedOrVersionChanged() {
        let store = FakeStore()
        let on = Switch(true)
        #expect(registry(store, id: "A", enabled: on).checkIn(now: now))
        #expect(!registry(store, id: "A", enabled: on).checkIn(now: now.addingTimeInterval(60)))
        #expect(registry(store, id: "A", enabled: on).checkIn(now: now.addingTimeInterval(60), force: true))
        #expect(registry(store, id: "A", version: "2.5", enabled: on).checkIn(now: now.addingTimeInterval(120)))
        #expect(registry(store, id: "A", version: "2.5", enabled: on)
            .checkIn(now: now.addingTimeInterval(120 + CloudDeviceRegistry.checkInInterval)))
    }

    // MARK: La liste

    @Test func devices_listThisOneFirst_thenMostRecent_andForgetTheVeryOld() {
        let store = FakeStore()
        let on = Switch(true)
        registry(store, id: "OLD", kind: "iPad", enabled: on)
            .checkIn(now: now.addingTimeInterval(-CloudDeviceRegistry.forgetAfter - 60))
        registry(store, id: "MAC", kind: "Mac", enabled: on).checkIn(now: now.addingTimeInterval(-3600))
        registry(store, id: "PAD", kind: "iPad", enabled: on).checkIn(now: now.addingTimeInterval(-60))
        let phone = registry(store, id: "ME", enabled: on)
        phone.checkIn(now: now.addingTimeInterval(-7200))
        #expect(phone.devices(now: now).map(\.id) == ["ME", "PAD", "MAC"])
        #expect(phone.otherDevices(now: now).map(\.kind) == ["iPad", "Mac"])
    }

    @Test func unreadableRecords_areIgnored() {
        let store = FakeStore()
        store.values[CloudDeviceRegistry.keyPrefix + "X"] = Data("not json".utf8)
        store.values["settings.boardThemeID"] = "classic"
        #expect(registry(store, id: "A", enabled: Switch(true)).devices(now: now).isEmpty)
    }

    @Test func olderVersions_areFlagged() {
        let record = CloudDeviceRecord(id: "B", kind: "iPad", appVersion: "2.3", lastSeen: now)
        #expect(record.isOlder(than: "2.4"))
        #expect(record.isOlder(than: "2.3.1"))
        #expect(!record.isOlder(than: "2.3"))
        #expect(CloudDeviceRecord(id: "B", kind: "iPad", appVersion: "2.10", lastSeen: now).isOlder(than: "2.9") == false)
    }

    // MARK: Modèle et système

    @Test func checkIn_publishesModelAndSystem_andRewritesWhenTheSystemChanges() {
        let store = FakeStore()
        let on = Switch(true)
        func eleven(_ system: String) -> CloudDeviceRegistry {
            CloudDeviceRegistry(store: store,
                                identity: CloudDeviceIdentity(id: "A", kind: "iPhone", model: "iPhone12,1", system: system),
                                appVersion: "2.4", isEnabled: { on.on })
        }
        #expect(eleven("iOS 18.5").checkIn(now: now))
        let mine = eleven("iOS 18.5").devices(now: now).first
        #expect(mine?.model == "iPhone12,1")
        #expect(mine?.system == "iOS 18.5")
        #expect(mine?.displayName == "iPhone 11")
        // Même système, une minute plus tard : rien à écrire. Une mise à jour d'iOS : tout de suite.
        #expect(!eleven("iOS 18.5").checkIn(now: now.addingTimeInterval(60)))
        #expect(eleven("iOS 18.6").checkIn(now: now.addingTimeInterval(60)))
        #expect(eleven("iOS 18.6").devices(now: now).first?.system == "iOS 18.6")
    }

    /// Les fiches déposées par la version précédente (sans modèle ni système) se lisent encore, et se nomment
    /// par leur type.
    @Test func recordsFromEarlierVersions_decode_andFallBackToTheKind() throws {
        let store = FakeStore()
        store.values[CloudDeviceRegistry.keyPrefix + "OLD"] = Data(
            #"{"id":"OLD","kind":"iPad","appVersion":"2.3","lastSeen":\#(now.timeIntervalSinceReferenceDate)}"#.utf8)
        let old = try #require(registry(store, id: "A", enabled: Switch(true)).otherDevices(now: now).first)
        #expect(old.model == nil)
        #expect(old.system == nil)
        #expect(old.displayName == "iPad")
    }

    // MARK: La proposition

    @Test func invitation_onlyWhenOffHere_andOnElsewhere() {
        let store = FakeStore()
        registry(store, id: "PAD", kind: "iPad", enabled: Switch(true)).checkIn(now: now.addingTimeInterval(-600))
        let phoneSwitch = Switch(false)
        let phone = registry(store, id: "ME", enabled: phoneSwitch)
        #expect(phone.invitation(dismissed: [], now: now)?.kind == "iPad")
        // Déjà déclinée pour cet appareil : on ne la repose pas.
        #expect(phone.invitation(dismissed: ["PAD"], now: now) == nil)
        // Synchro allumée ici : plus rien à proposer.
        phoneSwitch.on = true
        #expect(phone.invitation(dismissed: [], now: now) == nil)
    }

    @Test func invitation_ignoresDevicesSilentForAMonth_andThisDevice() {
        let store = FakeStore()
        registry(store, id: "PAD", kind: "iPad", enabled: Switch(true))
            .checkIn(now: now.addingTimeInterval(-CloudDeviceRegistry.inviteWithin - 60))
        // Une fiche à SON nom (synchro éteinte depuis, fiche pas encore retirée) ne compte pas.
        registry(store, id: "ME", enabled: Switch(true)).checkIn(now: now)
        #expect(registry(store, id: "ME", enabled: Switch(false)).invitation(dismissed: [], now: now) == nil)
    }
}

/// L'état affiché en un mot : la table de décision complète.
struct CloudSyncStateTests {
    private let last = Date(timeIntervalSince1970: 1_000)

    private func resolve(enabled: Bool = true, active: Bool = true, account: CloudSyncState.Account = .available,
                         failure: String? = nil, exchanging: Bool = false, last: Date? = nil) -> CloudSyncState {
        CloudSyncState.resolve(enabled: enabled, activeAtLaunch: active, account: account, failure: failure,
                               isExchanging: exchanging, lastExchange: last)
    }

    @Test func switchAndLaunchDisagreeing_comesFirst() {
        #expect(resolve(enabled: false, active: false) == .off)
        #expect(resolve(enabled: true, active: false, account: .signedOut) == .startsAfterRestart)
        #expect(resolve(enabled: false, active: true, failure: "x") == .stopsAfterRestart)
    }

    @Test func accountProblems_beforeExchangeState() {
        #expect(resolve(account: .unknown) == .checkingAccount)
        #expect(resolve(account: .signedOut, failure: "x") == .noAccount)
        #expect(resolve(account: .unavailable, exchanging: true) == .accountUnavailable)
    }

    @Test func failure_thenSyncing_thenUpToDate() {
        #expect(resolve(failure: "Pas de réseau", exchanging: true) == .paused("Pas de réseau"))
        #expect(resolve(exchanging: true, last: last) == .syncing)
        #expect(resolve(last: last) == .upToDate(last))
        #expect(resolve() == .upToDate(nil))
    }
}
