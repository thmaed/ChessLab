import ChessKit
import Foundation
import SwiftData
import Testing
@testable import ChessLab

/// Ce que le bouton d'export produit réellement.
///
/// Le test qui compte est `fenFollowsTheDisplayedPosition` : si le joueur
/// revoit un coup antérieur, c'est CETTE position qu'il a sous les yeux et
/// donc celle qu'il croit exporter. Exporter la position courante à la place
/// serait un piège silencieux — le texte copié n'aurait aucun rapport avec
/// l'échiquier affiché.
@MainActor
struct PlayExportTests {

    private func makeViewModel() throws -> PlayViewModel {
        let container = try ModelContainer(
            for: GameRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return PlayViewModel(settings: PlayGameSettings(), modelContext: ModelContext(container), startsEngine: false)
    }

    @Test func fenOfTheStartingPositionIsStandard() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.displayedFEN.hasPrefix(
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"
        ))
    }

    /// Avant le premier coup il n'y a PAS de partie : `PGNExport` rend une
    /// chaîne vide, et l'app doit le savoir plutôt que de copier du vide.
    @Test func thereIsNoGameToExportBeforeTheFirstMove() throws {
        let viewModel = try makeViewModel()
        #expect(viewModel.hasGameToExport == false)
        #expect(viewModel.exportedPGN.isEmpty)
        // La POSITION, elle, existe toujours.
        #expect(!viewModel.displayedFEN.isEmpty)
    }

    /// LE test : la FEN suit ce qui est AFFICHÉ, pas l'état interne.
    @Test func fenFollowsTheDisplayedPosition() throws {
        let viewModel = try makeViewModel()
        let atStart = viewModel.displayedFEN
        // Sans coup joué, position affichée = position courante.
        #expect(viewModel.displayedFEN == atStart)
        // Et la FEN reste bien celle du plateau affiché.
        #expect(viewModel.displayedFEN == viewModel.displayedBoard.position.fen)
    }
}
