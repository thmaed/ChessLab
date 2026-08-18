import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Le point de sauvegarde central et sa bannière (bug18aout §4, arbitré).
@MainActor
struct PersistenceHealthTests {

    @Test func theBannerRisesOnTheSecondConsecutiveFailure() {
        let health = PersistenceHealth()
        #expect(!health.showsBanner)
        health.recordFailure()
        #expect(!health.showsBanner, "un échec isolé peut être un caprice")
        health.recordFailure()
        #expect(health.showsBanner, "deux échecs consécutifs sont un état")
        health.recordSuccess()
        #expect(!health.showsBanner, "un succès remet le compteur à zéro")
    }

    @Test func aDegradedSessionShowsTheBannerImmediately() {
        let health = PersistenceHealth()
        health.isDegradedSession = true
        #expect(health.showsBanner)
    }

    @Test func aRealSaveResetsTheSharedCounter() throws {
        let container = try ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        PersistenceHealth.shared.recordFailure()
        context.insert(GameRecord())
        PersistenceLog.save(context)
        #expect(PersistenceHealth.shared.consecutiveFailures == 0,
                "une sauvegarde réussie efface l'ardoise")
    }
}
