import ChessKit
import Testing
@testable import ChessLab

/// Vérifie qu'une partie démarrée depuis un FEN personnalisé (mode Jouer
/// « à partir d'ici », Laboratoire) survit à un aller-retour PGN — sinon
/// la réouverture depuis la bibliothèque rejouerait les coups depuis la
/// position STANDARD (positions absurdes). Voir instructions.md §A11.
struct FENStartRoundTripTests {

    @Test func customStartPositionSurvivesPGNRoundTrip() throws {
        // Position quelconque non standard : finale roi + pion.
        let fen = "8/8/8/4k3/8/8/4P3/4K3 w - - 0 1"
        let start = try #require(Position(fen: fen))

        var game = Game(startingWith: start)
        // Un coup pour que le movetext ne soit pas vide.
        var board = Board(position: start)
        let move = board.move(pieceAt: Square("e2"), to: Square("e4"))
        let unwrappedMove = try #require(move)
        _ = game.make(move: unwrappedMove, from: game.startingIndex)

        // `PGNExport.pgn` injecte les tags [SetUp]/[FEN] absents de
        // `game.pgn` — sans lui, la partie recharge en position standard.
        let pgn = PGNExport.pgn(for: game)
        let reloaded = try Game(pgn: pgn)

        // La position de départ rechargée doit être celle du FEN, PAS la
        // position standard.
        let reloadedStart = try #require(reloaded.positions[reloaded.startingIndex])
        #expect(reloadedStart.fen == start.fen)
        #expect(reloadedStart.fen != Position.standard.fen)
    }
}
