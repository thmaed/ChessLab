import Foundation
import Testing
@testable import ChessLab

/// La partie en cours qui suit l'utilisateur d'un appareil à l'autre, éprouvée SANS iCloud : un magasin
/// clé-valeur factice joue le nuage, un fichier temporaire joue le `Documents/` de chaque appareil. Deux
/// appareils = deux fichiers, UN magasin partagé.
@MainActor
struct SyncedAutosaveTests {

    private struct FakeGame: Codable, Equatable, AutosaveRecord {
        var moves: [String]
        var savedAt: Date
        var gameID: UUID? = nil
        var moveLANs: [String] { moves }
    }

    private final class FakeStore: KeyValueStoring {
        var values: [String: Any] = [:]
        private(set) var synchronizeCount = 0
        func object(forKey key: String) -> Any? { values[key] }
        func set(_ value: Any?, forKey key: String) { values[key] = value }
        var storedKeys: [String] { Array(values.keys) }
        @discardableResult func synchronize() -> Bool { synchronizeCount += 1; return true }
    }

    /// Un « appareil » : son fichier, son interrupteur, le nuage commun.
    private final class Device {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("autosave-\(UUID().uuidString).json")
        let legacyAsideURL = FileManager.default.temporaryDirectory.appendingPathComponent("aside-\(UUID().uuidString).json")
        var enabled = true
        let defaults: UserDefaults
        private let suite = UUID().uuidString
        let autosave: () -> SyncedAutosave<FakeGame>
        init(store: KeyValueStoring, kind: String = "iPhone", model: String? = nil, name: String? = nil) {
            var holder: Device?
            let defaults = UserDefaults(suiteName: suite)!
            self.defaults = defaults
            let identity = CloudDeviceIdentity(id: UUID().uuidString, kind: kind, model: model, name: name)
            autosave = {
                SyncedAutosave(key: "test.autosave", fileURL: { holder!.url },
                               store: store, isEnabled: { holder!.enabled },
                               identity: identity, originDefaults: defaults,
                               legacyAsideURL: { holder!.legacyAsideURL })
            }
            holder = self
        }
        deinit {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: legacyAsideURL)
            defaults.removePersistentDomain(forName: suite)
        }
        var hasFile: Bool { FileManager.default.fileExists(atPath: url.path) }
    }

    private func at(_ secondsAgo: Double) -> Date { Date(timeIntervalSinceNow: -secondsAgo) }
    private func game(_ moves: [String], _ savedAt: Date, id: UUID? = nil) -> FakeGame {
        FakeGame(moves: moves, savedAt: savedAt, gameID: id)
    }

    // MARK: La règle de fusion

    @Test func withoutRemote_keepLocal() {
        #expect(AutosaveMerge.resolve(localSavedAt: at(10), remote: nil) == .keepLocal)
        #expect(AutosaveMerge.resolve(localSavedAt: nil, remote: nil) == .keepLocal)
    }

    @Test func newerRemoteGame_isAdopted_olderOrEqual_isNot() {
        let data = Data([1, 2, 3])
        #expect(AutosaveMerge.resolve(localSavedAt: at(10), remote: .init(at: at(5), game: data)) == .adoptRemote(data))
        #expect(AutosaveMerge.resolve(localSavedAt: nil, remote: .init(at: at(5), game: data)) == .adoptRemote(data))
        #expect(AutosaveMerge.resolve(localSavedAt: at(5), remote: .init(at: at(10), game: data)) == .keepLocal)
        let same = at(7)
        #expect(AutosaveMerge.resolve(localSavedAt: same, remote: .init(at: same, game: data)) == .keepLocal)
    }

    @Test func tombstone_dropsOnlyAnOlderLocalGame() {
        // La partie s'est terminée ailleurs APRÈS le dernier coup d'ici : on l'oublie.
        #expect(AutosaveMerge.resolve(localSavedAt: at(10), remote: .init(at: at(5), game: nil)) == .dropLocal)
        // Un coup joué ICI après la fin de l'autre partie : c'est une nouvelle partie, on la garde.
        #expect(AutosaveMerge.resolve(localSavedAt: at(1), remote: .init(at: at(5), game: nil)) == .keepLocal)
        // Rien à oublier.
        #expect(AutosaveMerge.resolve(localSavedAt: nil, remote: .init(at: at(5), game: nil)) == .keepLocal)
    }

    // MARK: Interrupteur éteint : silence complet

    @Test func disabled_neverTouchesTheCloud() {
        let store = FakeStore()
        let device = Device(store: store)
        device.enabled = false
        device.autosave().save(game(["e2e4"], at(5)))
        device.autosave().clear()
        _ = device.autosave().load()
        device.autosave().publishLocalIfCloudIsEmpty()
        #expect(store.values.isEmpty)
        #expect(store.synchronizeCount == 0)
    }

    @Test func disabled_ignoresWhateverTheCloudHolds() {
        let store = FakeStore()
        let other = Device(store: store), mine = Device(store: store)
        other.autosave().save(game(["d2d4"], at(5)))
        mine.enabled = false
        #expect(mine.autosave().load() == nil)
    }

    // MARK: Un appareil

    @Test func save_writesTheFileAndPublishesWhenEnabled() throws {
        let store = FakeStore()
        let device = Device(store: store)
        let g = game(["e2e4", "e7e5"], at(5))
        device.autosave().save(g)
        #expect(device.hasFile)
        let envelope = try #require(device.autosave().remoteEnvelope())
        #expect(envelope.at == g.savedAt)
        #expect(try JSONDecoder().decode(FakeGame.self, from: #require(envelope.game)) == g)
        #expect(device.autosave().load() == g)
    }

    @Test func clear_removesTheFileAndLeavesATombstone() throws {
        let store = FakeStore()
        let device = Device(store: store)
        device.autosave().save(game(["e2e4"], at(5)))
        device.autosave().clear()
        #expect(!device.hasFile)
        let envelope = try #require(device.autosave().remoteEnvelope())
        #expect(envelope.game == nil)
        #expect(device.autosave().load() == nil)
    }

    // MARK: Deux appareils

    @Test func aGameStartedOnOneDevice_resumesOnTheOther() {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        let g = game(["e2e4", "e7e5", "g1f3"], at(30))
        ipad.autosave().save(g)
        #expect(iphone.autosave().load() == g)
        #expect(iphone.hasFile)            // adoptée : la reprise la relit comme n'importe quelle autre
    }

    @Test func continuingOnTheOtherDevice_movesTheGameBack() {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        ipad.autosave().save(game(["e2e4"], at(60)))
        _ = iphone.autosave().load()
        let longer = game(["e2e4", "e7e5"], at(30))
        iphone.autosave().save(longer)
        #expect(ipad.autosave().load() == longer)
    }

    @Test func aGameFinishedOnOneDevice_disappearsFromTheOther() {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        ipad.autosave().save(game(["e2e4"], at(60)))
        _ = iphone.autosave().load()
        iphone.autosave().clear()                     // la partie se termine sur l'iPhone
        #expect(ipad.autosave().load() == nil)
        #expect(!ipad.hasFile)
    }

    @Test func aNewGameAfterTheEnd_isNotKilledByTheOldTombstone() {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        iphone.autosave().clear()                     // pierre tombale à « maintenant »
        let fresh = game(["d2d4"], Date().addingTimeInterval(5))   // un coup joué APRÈS
        ipad.autosave().save(fresh)
        #expect(iphone.autosave().load() == fresh)
    }

    @Test func twoDifferentGames_theMostRecentlyPlayedWins() {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        let older = game(["e2e4"], at(120)), newer = game(["d2d4", "d7d5"], at(20))
        // Chacun a la sienne, avant que la synchro ne les voie.
        ipad.autosave().save(older)
        iphone.autosave().save(newer)
        #expect(ipad.autosave().load() == newer)
        #expect(iphone.autosave().load() == newer)
        // …et celle de l'iPad est REMPLACÉE : plus de « mise de côté » (retirée le 21/11/2026, l'échange à chaque
        // tap de la bande d'accueil déroutait l'utilisateur).
        #expect(ipad.autosave().load() == newer, "elle ne revient pas au rapprochement suivant")
    }

    // MARK: Position de passage (contre l'ordinateur, 17/11/2026)

    @Test func aPassingPosition_staysOnTheDevice_untilFlushed() throws {
        let store = FakeStore()
        let phone = Device(store: store)
        let id = UUID()
        phone.autosave().save(game(["e2e4", "e7e5"], at(60), id: id))            // après la réponse : envoyée
        let afterReply = try #require(phone.autosave().remoteEnvelope())
        phone.autosave().save(game(["e2e4", "e7e5", "g1f3"], at(30), id: id), publish: false)  // le coup du joueur
        #expect(try #require(phone.autosave().remoteEnvelope()) == afterReply, "la position de passage ne voyage pas")
        #expect(phone.hasFile)
        // On quitte l'échiquier : elle part.
        phone.autosave().flushToCloud()
        #expect(try #require(phone.autosave().remoteEnvelope()).at > afterReply.at)
    }

    @Test func flushingNeverOverwritesANewerGameFromElsewhere() throws {
        let store = FakeStore()
        let phone = Device(store: store), pad = Device(store: store)
        let id = UUID()
        phone.autosave().save(game(["e2e4"], at(120), id: id), publish: false)
        let newer = game(["d2d4", "d7d5"], at(10), id: UUID())
        pad.autosave().save(newer)
        phone.autosave().flushToCloud()
        #expect(try #require(phone.autosave().remoteEnvelope()).at == newer.savedAt, "la partie plus récente de l'iPad reste")
    }

    @Test func flushingDoesNothingWhenSyncIsOff() {
        let store = FakeStore()
        let phone = Device(store: store)
        phone.enabled = false
        phone.autosave().save(game(["e2e4"], at(5)))
        phone.autosave().flushToCloud()
        #expect(store.values.isEmpty)
    }

    // MARK: Plus de mise de côté (retirée le 21/11/2026)

    @Test func theSameGameAfterATakeback_isAdopted() {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        let id = UUID()
        ipad.autosave().save(game(["e2e4", "e7e5", "g1f3"], at(60), id: id))
        _ = iphone.autosave().load()
        // Sur l'iPhone : reprise du dernier coup, puis un autre — la ligne n'est plus un prolongement.
        let otherLine = game(["e2e4", "e7e5", "f1c4"], at(20), id: id)
        iphone.autosave().save(otherLine)
        #expect(ipad.autosave().load() == otherLine)
    }

    @Test func aDifferentGameEndedElsewhere_leavesOursAlone() {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        let mine = game(["e2e4"], at(120), id: UUID())
        ipad.enabled = false
        ipad.autosave().save(mine)                    // jouée synchro éteinte : le nuage ne la connaît pas
        ipad.enabled = true
        iphone.autosave().save(game(["d2d4"], at(60), id: UUID()))
        iphone.autosave().clear()                     // l'iPhone termine SA partie
        #expect(ipad.autosave().load() == mine)
        #expect(ipad.hasFile)
    }

    /// « Remplacer par une nouvelle partie » sur un appareil : la partie remplacée ne ressurgit pas sur l'autre.
    @Test func anExplicitReplacement_replacesTheOtherDevicesGame() {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        ipad.autosave().save(game(["e2e4"], at(120), id: UUID()))
        _ = iphone.autosave().load()
        iphone.autosave().clear()
        let fresh = game(["c2c4"], at(10), id: UUID())
        iphone.autosave().save(fresh)
        #expect(ipad.autosave().load() == fresh)
    }

    /// Une AUTRE partie, plus récente, venue d'un autre appareil REMPLACE la nôtre — sans copie gardée ailleurs.
    @Test func anotherNewerGameReplacesOurs_andNothingIsKept() throws {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        ipad.autosave().save(game(["e2e4"], at(120), id: UUID()))
        let theirs = game(["d2d4"], at(30), id: UUID())
        iphone.autosave().save(theirs)
        #expect(ipad.autosave().load() == theirs)
        #expect(!FileManager.default.fileExists(atPath: ipad.legacyAsideURL.path), "aucune partie gardée de côté")
    }

    /// Une partie « mise de côté » par une VERSION PRÉCÉDENTE ne reste pas sur l'appareil : sa place est vidée.
    @Test func aLegacyAsideFileIsErasedOnLoad() throws {
        let store = FakeStore()
        let ipad = Device(store: store)
        try Data("{}".utf8).write(to: ipad.legacyAsideURL)
        _ = ipad.autosave().load()
        #expect(!FileManager.default.fileExists(atPath: ipad.legacyAsideURL.path))
    }

    @Test func savesFromBeforeTheIdentifier_areMatchedByTheirMoves() {
        let legacy = game(["e2e4", "e7e5"], at(60))
        #expect(legacy.isSameGame(as: game(["e2e4", "e7e5", "g1f3"], at(30))))
        #expect(game(["e2e4", "e7e5", "g1f3"], at(30)).isSameGame(as: legacy))
        #expect(!legacy.isSameGame(as: game(["d2d4"], at(30))))
        // Deux identifiants : seuls eux comptent.
        #expect(!game(["e2e4"], at(60), id: UUID()).isSameGame(as: game(["e2e4"], at(60), id: UUID())))
    }

    // MARK: Premier lancement avec la synchro

    @Test func aLocalGameNewerThanTheCloud_isTaughtToTheCloud() throws {
        let store = FakeStore()
        let ipad = Device(store: store), iphone = Device(store: store)
        ipad.autosave().save(game(["e2e4"], at(300)))
        // L'iPhone a joué plus tard avec la synchro éteinte, puis l'allume.
        iphone.enabled = false
        let later = game(["d2d4"], at(10))
        iphone.autosave().save(later)
        iphone.enabled = true
        #expect(iphone.autosave().load() == later)
        #expect(try #require(iphone.autosave().remoteEnvelope()).at == later.savedAt)
        #expect(ipad.autosave().load() == later)
    }

    @Test func publishLocalIfCloudIsEmpty_onlyFoundsAnEmptyCloud() throws {
        let store = FakeStore()
        let first = Device(store: store), second = Device(store: store)
        first.enabled = false
        first.autosave().save(game(["e2e4"], at(50)))
        first.enabled = true
        first.autosave().publishLocalIfCloudIsEmpty()
        #expect(store.values["test.autosave"] != nil)

        // Un nuage déjà garni n'est pas écrasé par un appareil qui rejoint.
        let before = try #require(second.autosave().remoteEnvelope())
        second.enabled = false
        second.autosave().save(game(["a2a3"], at(1)))
        second.enabled = true
        second.autosave().publishLocalIfCloudIsEmpty()
        #expect(try #require(second.autosave().remoteEnvelope()) == before)
    }

    // MARK: Les vraies clés

    @Test func theRealStoresUseDistinctKeysListedForRemoteNotification() {
        let keys = [SyncedAutosave.play.key, SyncedAutosave.twoPlayer.key]
        #expect(Set(keys).count == 2)
        #expect(Set(keys) == Set(AutosaveCloud.keys))
    }

    // MARK: D'où vient la partie

    @Test func adoptedGame_remembersTheOtherDevice_untilAMoveIsPlayedHere() {
        let store = FakeStore()
        let pad = Device(store: store, kind: "iPad")
        let phone = Device(store: store, kind: "iPhone")
        pad.autosave().save(game(["e2e4", "e7e5"], at(30)))
        #expect(phone.autosave().load()?.moves == ["e2e4", "e7e5"])
        #expect(phone.autosave().origin() == "iPad")
        // Un coup joué ICI : la partie est désormais « d'ici ».
        phone.autosave().save(game(["e2e4", "e7e5", "g1f3"], at(10)))
        #expect(phone.autosave().origin() == nil)
        // Et c'est l'iPad qui la voit venir de l'iPhone.
        _ = pad.autosave().load()
        #expect(pad.autosave().origin() == "iPhone")
    }

    /// Deux iPhone : « votre iPhone » ne disait rien (essai sur trois iPhone, 16/11/2026). Le modèle voyage
    /// avec la partie, et l'accueil le nomme.
    @Test func twoIPhones_theOriginNamesTheModel() {
        let store = FakeStore()
        let eleven = Device(store: store, kind: "iPhone", model: "iPhone12,1")
        let duo = Device(store: store, kind: "iPhone", model: "iPhone19,4")
        eleven.autosave().save(game(["e2e4"], at(20)))
        _ = duo.autosave().load()
        #expect(duo.autosave().origin() == "iPhone12,1")
        #expect(duo.autosave().origin().map { DeviceModelName.display($0, language: "fr") } == "iPhone 11")
    }

    @Test func aNamedDevice_isNamedInTheOrigin() {
        let store = FakeStore()
        let pad = Device(store: store, kind: "iPad", model: "iPad16,6", name: "iPad du salon")
        let phone = Device(store: store)
        pad.autosave().save(game(["e2e4"], at(20)))
        _ = phone.autosave().load()
        #expect(phone.autosave().origin().map { DeviceModelName.display($0, language: "fr") } == "iPad du salon")
    }

    @Test func ownGame_hasNoOrigin() {
        let store = FakeStore()
        let phone = Device(store: store)
        phone.autosave().save(game(["d2d4"], at(5)))
        _ = phone.autosave().load()
        #expect(phone.autosave().origin() == nil)
    }

    @Test func envelopesFromEarlierVersions_stillDecode_withoutOrigin() throws {
        let store = FakeStore()
        let old = AutosaveEnvelope(at: at(5), game: try JSONEncoder().encode(game(["c2c4"], at(5))))
        // Format des premières enveloppes : pas de champ d'appareil.
        let json = try JSONEncoder().encode(old)
        #expect(String(decoding: json, as: UTF8.self).contains("device") == false)
        store.values["test.autosave"] = json
        let phone = Device(store: store)
        #expect(phone.autosave().load()?.moves == ["c2c4"])
        #expect(phone.autosave().origin() == nil)
    }
}
