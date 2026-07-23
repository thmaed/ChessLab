import ChessKit
import Testing
@testable import ChessLab

/// Position de menace (Lot 5.G du final-1407) : « et si je passais mon
/// tour ? ». Le prompt demande une flèche rouge pour ce que l'adversaire
/// menace de jouer.
struct ThreatPositionTests {

    @Test func theSideToMoveIsHandedOver() throws {
        let flipped = try #require(ThreatPosition.fenWithSideToMoveFlipped(
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"
        ))

        #expect(flipped.split(separator: " ")[1] == "w")
        // Le reste ne bouge pas : c'est la MÊME position, vue par l'autre.
        #expect(flipped.split(separator: " ")[0] == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR")
        #expect(flipped.split(separator: " ")[2] == "KQkq")
    }

    /// La case en passant est un droit du camp au trait, valable pour ce seul
    /// coup : la garder après avoir passé la main donnerait une prise en
    /// passant fantôme.
    @Test func theEnPassantRightIsDropped() throws {
        let flipped = try #require(ThreatPosition.fenWithSideToMoveFlipped(
            "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2"
        ))

        #expect(flipped.split(separator: " ")[3] == "-")
        #expect(flipped.split(separator: " ")[1] == "b")
    }

    /// **Le cas qui compte.** Si l'adversaire est en ÉCHEC, lui passer la main
    /// laisserait un roi en prise : la position est illégale, et Stockfish
    /// répondrait n'importe quoi. Pas de menace à afficher — le prompt
    /// interdit d'envoyer un FEN illégal au moteur.
    @Test func noThreatWhenTheOtherKingIsInCheck() {
        // Fou b5 → c6 → d7 → e8 : les Noirs sont en échec, et c'est à eux de
        // jouer (position parfaitement légale). Leur retirer le trait
        // laisserait leur roi en prise pendant que les Blancs rejouent :
        // illégal, et Stockfish répondrait n'importe quoi.
        let blackInCheck = "rnbqkbnr/ppp2ppp/8/1B1pp3/8/8/PPPPPPPP/RN1QKBNR b KQkq - 0 1"
        #expect(FENValidator.isLegal(blackInCheck), "la position de départ, elle, est légale")

        #expect(ThreatPosition.fenWithSideToMoveFlipped(blackInCheck) == nil)
    }

    @Test func anUnreadableFENYieldsNoThreat() {
        #expect(ThreatPosition.fenWithSideToMoveFlipped("n'importe quoi") == nil)
        #expect(ThreatPosition.fenWithSideToMoveFlipped("") == nil)
        #expect(ThreatPosition.fenWithSideToMoveFlipped("8/8/8/8/8/8/8/8 w - - 0 1") == nil, "un plateau sans roi n'est pas une position")
    }

    /// Le FEN produit doit être relisible par ChessKit : c'est lui qui part au
    /// moteur.
    @Test func theProducedFENIsAValidPosition() throws {
        let flipped = try #require(ThreatPosition.fenWithSideToMoveFlipped(
            "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 0 1"
        ))

        #expect(Position(fen: flipped) != nil)
        #expect(FENValidator.isLegal(flipped))
    }
}
