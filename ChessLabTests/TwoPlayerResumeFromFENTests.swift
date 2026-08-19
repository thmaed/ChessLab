import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Non-régression de la revue du 19/08 : depuis que « Changer de mode »
/// peut démarrer une partie à deux sur une position REPRISE (`startFEN`),
/// TOUT le cycle de vie du mode doit repartir de cette position — la
/// reprise d'autosauvegarde rejouait les coups depuis la position
/// STANDARD et déclarait la sauvegarde irrécupérable (ou pire : la
/// restaurait sur le mauvais échiquier).
@MainActor
struct TwoPlayerResumeFromFENTests {

    private static func inMemoryContext() throws -> ModelContext {
        let schema = Schema([GameRecord.self, Puzzle.self])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        return ModelContext(container)
    }

    /// La Lucena, trait aux Blancs — une position qu'aucun rejeu depuis la
    /// position standard ne peut produire.
    private static let lucenaFEN = "1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1"

    private func settingsFromLucena() -> TwoPlayerGameSettings {
        var settings = TwoPlayerGameSettings.default
        settings.startFEN = Self.lucenaFEN
        return settings
    }

    @Test func aNewGameStartsFromTheCarriedPosition() throws {
        let vm = TwoPlayerViewModel(settings: settingsFromLucena(), modelContext: try Self.inMemoryContext())
        #expect(vm.board.position.piece(at: Square("b7"))?.kind == .pawn)
        #expect(vm.board.position.sideToMove == .white)
    }

    @Test func resumingAnAutosaveReplaysFromTheCarriedPosition() throws {
        // 1.Rd1+ (coup légal DEPUIS la Lucena, illégal depuis la position
        // standard : c1d1 y serait un coup de dame blanche inexistante).
        let autosave = TwoPlayerGameAutosave(
            settings: settingsFromLucena(),
            moveLANs: ["c1d1"],
            whiteRemaining: nil, blackRemaining: nil,
            savedAt: Date()
        )

        let vm = TwoPlayerViewModel(resuming: autosave, modelContext: try Self.inMemoryContext())

        #expect(vm != nil, "la reprise doit réussir depuis la position portée par les réglages")
        #expect(vm?.moveLog.count == 1)
        #expect(vm?.board.position.piece(at: Square("d1"))?.kind == .rook)
        #expect(vm?.board.position.sideToMove == .black)
    }

    /// Le rejeu PARTIEL (navigation dans l'historique puis reprise depuis la
    /// position consultée) doit lui aussi repartir de la position portée.
    @Test func rebuildingAfterHistoryNavigationKeepsTheCarriedPosition() throws {
        let vm = TwoPlayerViewModel(settings: settingsFromLucena(), modelContext: try Self.inMemoryContext())
        vm.attemptUserMove(from: Square("c1"), to: Square("d1"))  // 1.Rd1+
        vm.attemptUserMove(from: Square("a2"), to: Square("d2"))  // 1…Rd2 (coupe l'échec)
        #expect(vm.moveLog.count == 2)

        // Reculer d'un coup puis reprendre la partie d'ici : le coup noir
        // est abandonné, la tour blanche doit être en d1 — pas en c1, et
        // surtout pas sur un échiquier standard.
        vm.reviewPrevious()
        vm.resumeFromReview()

        #expect(vm.moveLog.count == 1)
        #expect(vm.board.position.piece(at: Square("d1"))?.kind == .rook)
        #expect(vm.board.position.piece(at: Square("b7"))?.kind == .pawn)
    }
}
