import Foundation
import Testing
@testable import ChessLab

/// Fusion des réglages entre appareils, éprouvée sans iCloud : un magasin
/// clé-valeur factice et un domaine `UserDefaults` jetable suffisent à couvrir
/// tout ce qui est décidable sur une seule machine — le reste (deux appareils
/// réels, latence du nuage) relève de la checklist manuelle.
@MainActor
struct SettingsCloudSyncTests {

    /// Magasin clé-valeur en mémoire, qui joue le rôle du nuage.
    private final class FakeStore: KeyValueStoring {
        var values: [String: Any] = [:]
        private(set) var synchronizeCount = 0

        func object(forKey key: String) -> Any? { values[key] }
        func set(_ value: Any?, forKey key: String) { values[key] = value }
        var storedKeys: [String] { Array(values.keys) }
        @discardableResult func synchronize() -> Bool { synchronizeCount += 1; return true }
    }

    /// Domaine `UserDefaults` isolé : chaque test a le sien, rien ne fuit d'un
    /// test à l'autre ni vers les préférences réelles de la machine.
    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: La liste blanche

    @Test("La langue et les sons ne quittent jamais l'appareil")
    func languageAndSoundsAreNeverSynced() {
        for key in SettingsCloudSync.deliberatelyLocalKeys {
            #expect(!SettingsCloudSync.syncedKeys.contains(key),
                    "\(key) doit rester local — décision produit du 20/08/2026")
        }
        #expect(SettingsCloudSync.deliberatelyLocalKeys.contains("settings.appLanguage"))
        #expect(SettingsCloudSync.deliberatelyLocalKeys.contains("settings.soundsEnabled"))
    }

    @Test("Les états de machine ne sont pas synchronisés")
    func machineStateKeysAreNotSynced() {
        // Ces clés disent « où en est CET appareil », pas « ce que l'utilisateur
        // préfère » : les propager ressusciterait des migrations déjà faites ou
        // couperait la synchro partout depuis un seul appareil.
        for key in ["userOpenings.migratedToDatabase", "lichessPuzzleLibrarySeededV4",
                    "container.openFailures", "openingsLastReconcileAt", "cloudKitSyncEnabled"] {
            #expect(!SettingsCloudSync.syncedKeys.contains(key))
        }
    }

    @Test("Une préférence hors liste blanche est ignorée dans les deux sens")
    func unknownKeysAreIgnored() {
        let store = FakeStore()
        let defaults = makeDefaults()
        store.values["settings.appLanguage"] = "english"
        defaults.set("classic", forKey: "settings.boardThemeID")
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        sync.applyRemote(keys: ["settings.appLanguage"])
        #expect(defaults.string(forKey: "settings.appLanguage") == nil,
                "la langue venue du nuage ne doit pas s'appliquer")
    }

    // MARK: Réconciliation de démarrage

    @Test("Au démarrage, le nuage gagne là où il a déjà une valeur")
    func cloudWinsOnKeysItAlreadyHas() {
        let store = FakeStore()
        let defaults = makeDefaults()
        store.values["settings.boardThemeID"] = "walnut"
        defaults.set("classic", forKey: "settings.boardThemeID")
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        let outcome = sync.reconcileAtLaunch()

        #expect(defaults.string(forKey: "settings.boardThemeID") == "walnut")
        #expect(outcome.pulled.contains("settings.boardThemeID"))
    }

    @Test("Au démarrage, l'appareil pousse ce qui manque au nuage")
    func deviceSeedsKeysTheCloudLacks() {
        let store = FakeStore()
        let defaults = makeDefaults()
        defaults.set(3, forKey: "settings.puzzleAttempts")
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        let outcome = sync.reconcileAtLaunch()

        #expect(store.values["settings.puzzleAttempts"] as? Int == 3)
        #expect(outcome.pushed.contains("settings.puzzleAttempts"))
        #expect(outcome.pulled.isEmpty)
    }

    @Test("Le premier appareil d'un compte vierge ne perd aucun réglage")
    func firstDeviceKeepsEverything() {
        let store = FakeStore()
        let defaults = makeDefaults()
        defaults.set("merida", forKey: "settings.pieceSetID")
        defaults.set(false, forKey: "settings.hapticsEnabled")
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        sync.reconcileAtLaunch()

        #expect(defaults.string(forKey: "settings.pieceSetID") == "merida")
        #expect(defaults.object(forKey: "settings.hapticsEnabled") as? Bool == false)
        #expect(store.values["settings.pieceSetID"] as? String == "merida")
    }

    // MARK: Réception d'un changement distant

    @Test("Un changement distant est appliqué et signalé")
    func remoteChangeIsAppliedAndReported() {
        let store = FakeStore()
        let defaults = makeDefaults()
        defaults.set("classic", forKey: "settings.boardThemeID")
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        store.values["settings.boardThemeID"] = "blue"
        let touched = sync.applyRemote(keys: ["settings.boardThemeID"])

        #expect(touched, "l'UI doit être rafraîchie")
        #expect(defaults.string(forKey: "settings.boardThemeID") == "blue")
    }

    @Test("Une valeur distante identique ne déclenche aucun rafraîchissement")
    func identicalRemoteValueIsANoOp() {
        let store = FakeStore()
        let defaults = makeDefaults()
        defaults.set("blue", forKey: "settings.boardThemeID")
        store.values["settings.boardThemeID"] = "blue"
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        #expect(sync.applyRemote(keys: ["settings.boardThemeID"]) == false)
    }

    @Test("Un bloc de réglages de mode voyage entier")
    func modeSettingsTravelAsAWholeBlock() throws {
        let store = FakeStore()
        let defaults = makeDefaults()
        let blob = try JSONEncoder().encode(["eloSliderValue": 1800.0])
        store.values["lastPlayGameSettings"] = blob
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        sync.applyRemote(keys: ["lastPlayGameSettings"])

        #expect(defaults.data(forKey: "lastPlayGameSettings") == blob)
    }

    // MARK: Poussée locale

    @Test("Une préférence changée localement part vers le nuage")
    func localChangeIsPushed() {
        let store = FakeStore()
        let defaults = makeDefaults()
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        defaults.set("contrast", forKey: "settings.boardThemeID")
        let pushed = sync.pushLocalChanges()

        #expect(pushed == ["settings.boardThemeID"])
        #expect(store.values["settings.boardThemeID"] as? String == "contrast")
    }

    @Test("Rien à pousser quand rien n'a changé")
    func nothingToPushWhenNothingChanged() {
        let store = FakeStore()
        let defaults = makeDefaults()
        defaults.set("walnut", forKey: "settings.boardThemeID")
        store.values["settings.boardThemeID"] = "walnut"
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        #expect(sync.pushLocalChanges().isEmpty)
        #expect(store.synchronizeCount == 0, "aucune écriture, donc aucune synchronisation forcée")
    }

    @Test("Appliquer une valeur distante ne la renvoie pas au nuage (anti-boucle)")
    func applyingRemoteDoesNotEcho() {
        let store = FakeStore()
        let defaults = makeDefaults()
        defaults.set("classic", forKey: "settings.boardThemeID")
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        store.values["settings.boardThemeID"] = "walnut"
        sync.applyRemote(keys: ["settings.boardThemeID"])
        // Ce que ferait l'observateur `UserDefaults` juste après l'écriture.
        let pushed = sync.pushLocalChanges()

        #expect(pushed.isEmpty, "local et distant sont désormais identiques : rien à repousser")
        #expect(store.values["settings.boardThemeID"] as? String == "walnut")
    }

    @Test("Deux réconciliations d'affilée sont idempotentes")
    func reconcilingTwiceIsIdempotent() {
        let store = FakeStore()
        let defaults = makeDefaults()
        defaults.set(3, forKey: "settings.puzzleAttempts")
        store.values["settings.boardThemeID"] = "blue"
        let sync = SettingsCloudSync(store: store, defaults: defaults)

        sync.reconcileAtLaunch()
        let second = sync.reconcileAtLaunch()

        #expect(second.pulled.isEmpty)
        #expect(second.pushed.isEmpty)
        #expect(defaults.string(forKey: "settings.boardThemeID") == "blue")
        #expect(store.values["settings.puzzleAttempts"] as? Int == 3)
    }
}
