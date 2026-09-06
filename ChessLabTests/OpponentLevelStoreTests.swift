import Foundation
import Testing
@testable import ChessLab

/// Chaque personnage garde son niveau, et la clé voyage par iCloud.
@Suite @MainActor struct OpponentLevelStoreTests {

    private func freshDefaults() -> UserDefaults {
        let name = "OpponentLevelStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func levelsAreRememberedPerCharacter() {
        let defaults = freshDefaults()
        #expect(OpponentLevelStore.level(for: "pablo", defaults: defaults) == nil)
        OpponentLevelStore.save(level: 1000, for: "pablo", defaults: defaults)
        OpponentLevelStore.save(level: 1800, for: "nadia", defaults: defaults)
        OpponentLevelStore.save(level: 1050, for: "pablo", defaults: defaults)
        #expect(OpponentLevelStore.level(for: "pablo", defaults: defaults) == 1050)
        #expect(OpponentLevelStore.level(for: "nadia", defaults: defaults) == 1800)
        #expect(OpponentLevelStore.level(for: "marc", defaults: defaults) == nil)
    }

    @Test func theKeyIsSynchronised() {
        #expect(SettingsCloudSync.syncedKeys.contains(OpponentLevelStore.key))
    }
}
