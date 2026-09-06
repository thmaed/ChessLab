import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// La partie contre un personnage, de bout en bout, avec le VRAI modèle
/// Core ML et le VRAI Stockfish (filet) : Maia joue les Blancs, répond au
/// coup du joueur, et le filet ne s'est pas déclaré indisponible.
///
/// `.serialized` et ``EngineIntegrationGate`` : un seul moteur réel à la
/// fois dans tout le process (voir le gate).
@Suite(.serialized)
@MainActor
struct MaiaOpponentIntegrationTests {

    private static func inMemoryContext() throws -> ModelContext {
        let schema = Schema([GameRecord.self, Puzzle.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    @Test("Maia ouvre la partie et répond, sans que le filet se déclare indisponible")
    func camillePlaysBothHerMoves() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            var settings = PlayGameSettings.default
            settings.colorChoice = PlayerColorChoice.black.rawValue
            settings.opponentProfileID = OpponentProfile.maia.id
            settings.eloSliderValue = 1500
            settings.bookEnabled = false   // c'est MAIA qu'on veut voir jouer, pas le livre
            let vm = PlayViewModel(settings: settings, modelContext: try Self.inMemoryContext())
            #expect(vm.opponentProfile == .maia)
            #expect(vm.opponentDisplayName == "Maia")

            // Premier coup des Blancs : Maia + recherche courte de Stockfish.
            var deadline = Date().addingTimeInterval(45)
            while Date() < deadline, vm.moveLog.isEmpty {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(!vm.moveLog.isEmpty, "Maia n'a jamais joué son premier coup")
            #expect(vm.isMaiaOpponentActive, "le modèle doit être chargé et actif")
            #expect(!vm.safetyNetInterventions.contains(.unavailable))
            #expect(vm.moveLog[0].piece.color == .white)

            // Réponse du joueur, puis second coup de Maia.
            vm.attemptUserMove(from: Square("e7"), to: Square("e5"))
            let afterUser = vm.moveLog.count
            try #require(afterUser == 2, "e7e5 doit tenir après n'importe quel premier coup blanc")

            deadline = Date().addingTimeInterval(45)
            while Date() < deadline, vm.moveLog.count < 3 {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(vm.moveLog.count == 3, "Maia n'a pas répondu")
            #expect(vm.moveLog.last?.piece.color == .white)
            #expect(vm.outcome == nil)

            vm.handleViewDisappear()
        }
    }
}
