import ChessKit
import Testing
@testable import ChessLab

/// Retrouver un coup dans une phrase dite (étude « coups à la voix », 19/11/2026) — comparée aux seuls coups légaux.
struct VoiceMoveParserTests {

    private func candidates(_ fen: String? = nil, after lans: [String] = []) -> [VoiceMoveParser.Candidate] {
        var board = Board(position: fen.flatMap { Position(fen: $0) } ?? .standard)
        for lan in lans {
            board.move(pieceAt: Square(String(lan.prefix(2))), to: Square(String(lan.suffix(2))))
        }
        return VoiceMoveParser.candidates(in: board)
    }

    private func uci(_ text: String, _ legal: [VoiceMoveParser.Candidate]) -> String? {
        if case let .move(move) = VoiceMoveParser.resolve(transcripts: [text], among: legal) { return move.uci }
        return nil
    }

    @Test func theStartingPositionHasTwentyMoves() {
        #expect(candidates().count == 20)
    }

    @Test(arguments: [
        ("e4", "e2e4"), ("E4", "e2e4"), ("pion e4", "e2e4"), ("Pion en e 4", "e2e4"), ("euh 4", "e2e4"),
        ("Cavalier f3", "g1f3"), ("cavalier en F3.", "g1f3"), ("Cavalier effe trois", "g1f3"), ("Cf3", "g1f3"),
        ("c'est 4", "c2c4"), ("dé 4", "d2d4"), ("Cavalier c3", "b1c3"), ("f3", "f2f3"),
    ])
    func movesFromTheStart(text: String, expected: String) {
        #expect(uci(text, candidates()) == expected, "« \(text) »")
    }

    @Test func aMoveThatNoPieceCanMakeIsImpossible() {
        #expect(VoiceMoveParser.resolve(transcripts: ["fou c4"], among: candidates()) == .illegal)
        #expect(VoiceMoveParser.resolve(transcripts: ["bonjour"], among: candidates()) == .notUnderstood)
    }

    @Test func castling() {
        let italian = candidates(after: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"])
        #expect(uci("petit roque", italian) == "e1g1")
        #expect(VoiceMoveParser.resolve(transcripts: ["grand roque"], among: italian) == .illegal)
        #expect(uci("roque", italian) == "e1g1")
    }

    @Test func twoKnightsForOneSquareAskWhichOne() {
        // Cavaliers b1 et f3, d2 libre.
        let legal = candidates("4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1")
        guard case let .ambiguous(moves) = VoiceMoveParser.resolve(transcripts: ["cavalier d2"], among: legal) else {
            Issue.record("deux cavaliers peuvent aller en d2")
            return
        }
        #expect(Set(moves.map(\.uci)) == ["b1d2", "f3d2"])
        #expect(uci("cavalier b d2", legal) == "b1d2")
        #expect(uci("cavalier f3 d2", legal) == "f3d2")
    }

    @Test func promotionToTheQueenUnlessAnotherPieceIsNamed() {
        let legal = candidates("8/P7/8/8/8/8/8/k6K w - - 0 1")
        #expect(uci("a8", legal) == "a7a8q")
        #expect(uci("a8 dame", legal) == "a7a8q")
        #expect(uci("a8 cavalier", legal) == "a7a8n")
        #expect(uci("pion a8 promotion tour", legal) == "a7a8r")
    }

    @Test func aMisheardLetterThatRhymesIsRescuedWhenOnlyOneMoveFits() {
        // Un seul pion, en d2 : « bé 4 » n'existe pas, « dé 4 » si.
        let legal = candidates("4k3/8/8/8/8/8/3P4/4K3 w - - 0 1")
        #expect(uci("bé 4", legal) == "d2d4")
        #expect(VoiceMoveParser.resolve(transcripts: ["bé 4"], among: legal, confusions: false) == .illegal)
    }

    @Test func theFirstTranscriptThatGivesAMoveWins() {
        #expect(VoiceMoveParser.resolve(transcripts: ["bonjour", "cavalier f3"], among: candidates())
                == .move(.init(uci: "g1f3", san: "Nf3")))
    }

    @Test func spokenFormsCoverTheUsualWays() {
        let forms = VoiceMoveParser.spokenForms(of: candidates())
        #expect(forms.contains("cavalier f3"))
        #expect(forms.contains("pion en e4"))
        #expect(forms.contains("e4"))
    }
}
