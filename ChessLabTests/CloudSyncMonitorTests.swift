import CloudKit
import Foundation
import Testing
@testable import ChessLab

/// Ce que les Réglages affichent des échanges iCloud : l'état déduit des événements CloudKit, éprouvé sans
/// iCloud en lui soufflant des événements à la main.
@MainActor
struct CloudSyncMonitorTests {

    private func makeDefaults() -> UserDefaults {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func at(_ secondsAgo: Double) -> Date { Date(timeIntervalSinceNow: -secondsAgo) }

    @Test func startsEmpty() {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        #expect(monitor.lastSendAt == nil)
        #expect(monitor.lastReceiveAt == nil)
        #expect(monitor.failure == nil)
        #expect(monitor.manualResult == nil)
    }

    @Test func successfulExchanges_areRecordedAndRememberedAcrossLaunches() {
        let defaults = makeDefaults()
        let monitor = CloudSyncMonitor(defaults: defaults)
        let sent = at(30), received = at(10)
        monitor.record(kind: .send, endedAt: sent, succeeded: true, errorMessage: nil)
        monitor.record(kind: .receive, endedAt: received, succeeded: true, errorMessage: nil)
        #expect(monitor.lastSendAt == sent)
        #expect(monitor.lastReceiveAt == received)

        let relaunched = CloudSyncMonitor(defaults: defaults)
        #expect(relaunched.lastSendAt?.timeIntervalSince1970 == sent.timeIntervalSince1970)
        #expect(relaunched.lastReceiveAt?.timeIntervalSince1970 == received.timeIntervalSince1970)
    }

    @Test func aFailure_isShown_thenWashedByTheNextSuccess() {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        monitor.record(kind: .send, endedAt: at(20), succeeded: false, errorMessage: "Le stockage iCloud est plein.")
        #expect(monitor.failure?.message == "Le stockage iCloud est plein.")
        #expect(monitor.lastSendAt == nil)             // un échec n'est pas un envoi
        monitor.record(kind: .send, endedAt: at(5), succeeded: true, errorMessage: nil)
        #expect(monitor.failure == nil)
    }

    @Test func theSetupEvent_neverClaimsAnExchange() {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        monitor.record(kind: .setup, endedAt: at(5), succeeded: true, errorMessage: nil)
        #expect(monitor.lastSendAt == nil)
        #expect(monitor.lastReceiveAt == nil)
    }

    @Test func outcomeSince_readsOnlyWhatHappenedAfterTheTap() {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        let tap = at(10)
        monitor.record(kind: .receive, endedAt: at(60), succeeded: true, errorMessage: nil)   // AVANT le toucher
        #expect(monitor.outcome(since: tap) == nil)
        monitor.record(kind: .send, endedAt: at(3), succeeded: true, errorMessage: nil)
        #expect(monitor.outcome(since: tap) == .exchanged)
        monitor.record(kind: .receive, endedAt: at(1), succeeded: false, errorMessage: "Pas de connexion réseau pour le moment.")
        #expect(monitor.outcome(since: tap) == .failed("Pas de connexion réseau pour le moment."))
    }

    @Test func watching_withNothingHappening_saysSoAfterThePatience() async {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        let result = await monitor.watchForExchange(since: Date(), patience: 1)
        #expect(result == .nothingSeen)
    }

    @Test func watching_seesAnExchangeThatArrivesDuringTheWait() async {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        let started = Date()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            monitor.record(kind: .receive, endedAt: Date(), succeeded: true, errorMessage: nil)
        }
        let result = await monitor.watchForExchange(since: started, patience: 5)
        #expect(result == .exchanged)
    }

    // MARK: Les messages d'erreur

    @Test func anExchangeInFlight_showsAsSyncing_untilItEnds() {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        let id = UUID()
        monitor.recordStart(id: id, at: at(3))
        #expect(monitor.isExchanging())
        monitor.record(kind: .send, endedAt: at(1), succeeded: true, errorMessage: nil, id: id)
        #expect(!monitor.isExchanging())
        #expect(monitor.lastExchange != nil)
    }

    /// Seule une RÉCEPTION réussie déclenche la fusion de ce qui est arrivé (voir ``CloudImportResponder``) :
    /// ni un envoi, ni une mise en place, ni un échec.
    @Test func onlyASuccessfulReceive_announcesArrivedData() {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        var announced = 0
        let token = NotificationCenter.default.addObserver(
            forName: CloudSyncMonitor.didReceive, object: nil, queue: nil
        ) { _ in announced += 1 }
        defer { NotificationCenter.default.removeObserver(token) }

        monitor.record(kind: .send, endedAt: at(5), succeeded: true, errorMessage: nil)
        monitor.record(kind: .setup, endedAt: at(4), succeeded: true, errorMessage: nil)
        monitor.record(kind: .receive, endedAt: at(3), succeeded: false, errorMessage: "réseau")
        #expect(announced == 0)
        monitor.record(kind: .receive, endedAt: at(2), succeeded: true, errorMessage: nil)
        #expect(announced == 1)
    }

    @Test func anExchangeThatNeverEnds_stopsCountingAfterTwoMinutes() {
        let monitor = CloudSyncMonitor(defaults: makeDefaults())
        monitor.recordStart(id: UUID(), at: at(121))
        #expect(!monitor.isExchanging())
    }

    @Test func commonCloudKitErrors_getDistinctReadableMessages() {
        let codes: [CKError.Code] = [.notAuthenticated, .networkUnavailable, .quotaExceeded, .zoneBusy, .accountTemporarilyUnavailable]
        let messages = codes.map { CloudSyncErrorText.describe(code: $0.rawValue) }
        #expect(Set(messages).count == codes.count)
        // Les deux erreurs de réseau, et les trois « occupé », ne se distinguent pas pour l'utilisateur.
        #expect(CloudSyncErrorText.describe(code: CKError.Code.networkFailure.rawValue) == messages[1])
        #expect(CloudSyncErrorText.describe(code: CKError.Code.requestRateLimited.rawValue) == messages[3])
    }

    @Test func anUnknownCode_isStillShownWithItsNumber() {
        #expect(CloudSyncErrorText.describe(code: 98765).contains("98765"))
    }

    @Test func aWrappedCloudKitError_isUnwrapped() {
        let inner = NSError(domain: CKError.errorDomain, code: CKError.Code.quotaExceeded.rawValue)
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 134400, userInfo: [NSUnderlyingErrorKey: inner])
        #expect(CloudSyncErrorText.describe(wrapped) == CloudSyncErrorText.describe(code: CKError.Code.quotaExceeded.rawValue))
    }
}
