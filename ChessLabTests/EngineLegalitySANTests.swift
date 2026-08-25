import ChessKit
import Testing
@testable import ChessLab

/// Tests PURS de ``EngineLegalitySAN`` — aucun moteur, aucun ChessKit
/// `Board.move` : uniquement le FEN AVANT le coup, le coup UCI, et la liste
/// des coups légaux de la position (pour la désambiguïsation).
@Suite
struct EngineLegalitySANTests {

    @Test("Poussée de pion simple")
    func simplePawnPush() {
        let fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        let san = EngineLegalitySAN.build(
            uci: "e2e4", beforeFEN: fen, legalMovesAtPosition: ["e2e4"], isCheck: false, isMate: false
        )
        #expect(san == "e4")
    }

    @Test("Capture de pion")
    func pawnCapture() {
        let fen = "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"
        let san = EngineLegalitySAN.build(
            uci: "e4d5", beforeFEN: fen, legalMovesAtPosition: ["e4d5"], isCheck: false, isMate: false
        )
        #expect(san == "exd5")
    }

    @Test("Deux cavaliers visent la même case : désambiguïsation par colonne")
    func knightDisambiguationByFile() {
        let fen = "4k3/8/8/8/8/2N3N1/8/4K3 w - - 0 1"
        let legal = ["c3e2", "g3e2"]
        let san = EngineLegalitySAN.build(
            uci: "c3e2", beforeFEN: fen, legalMovesAtPosition: legal, isCheck: false, isMate: false
        )
        #expect(san == "Nce2")
    }

    @Test("Promotion sans capture")
    func promotion() {
        // Roi noir sur a8, PAS e8 — sinon le pion "promeut" en capturant le
        // roi et le test se testerait lui-même dans le mur (bug trouvé en
        // écrivant ce test : e8 était occupé par le roi dans la FEN).
        let fen = "k7/4P3/8/8/8/8/8/4K3 w - - 0 1"
        let san = EngineLegalitySAN.build(
            uci: "e7e8q", beforeFEN: fen, legalMovesAtPosition: ["e7e8q"], isCheck: false, isMate: false
        )
        #expect(san == "e8=Q")
    }

    @Test("Suffixe échec")
    func checkSuffix() {
        let fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        let san = EngineLegalitySAN.build(
            uci: "e2e4", beforeFEN: fen, legalMovesAtPosition: ["e2e4"], isCheck: true, isMate: false
        )
        #expect(san == "e4+")
    }

    @Test("Suffixe mat")
    func mateSuffix() {
        let fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        let san = EngineLegalitySAN.build(
            uci: "e2e4", beforeFEN: fen, legalMovesAtPosition: ["e2e4"], isCheck: true, isMate: true
        )
        #expect(san == "e4#")
    }

    @Test("Petit roque")
    func kingsideCastle() {
        let fen = "4k3/8/8/8/8/8/8/4K2R w K - 0 1"
        let san = EngineLegalitySAN.build(
            uci: "e1g1", beforeFEN: fen, legalMovesAtPosition: ["e1g1"], isCheck: false, isMate: false
        )
        #expect(san == "O-O")
    }

    @Test("Grand roque")
    func queensideCastle() {
        let fen = "4k3/8/8/8/8/8/8/R3K3 w Q - 0 1"
        let san = EngineLegalitySAN.build(
            uci: "e1c1", beforeFEN: fen, legalMovesAtPosition: ["e1c1"], isCheck: false, isMate: false
        )
        #expect(san == "O-O-O")
    }
}
