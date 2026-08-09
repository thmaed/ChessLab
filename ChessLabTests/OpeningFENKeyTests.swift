import ChessKit
import Testing
@testable import ChessLab

/// La clé de graphe/progression : la donnée la plus sensible du module. Ces
/// tests protègent la fusion des transpositions et la canonicalisation de la
/// prise en passant.
struct OpeningFENKeyTests {

    private static let startKey = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"

    @Test func normalizeDropsClocksFromTheStartingPosition() {
        #expect(OpeningFENKey.normalize("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") == Self.startKey)
    }

    @Test func keyForStandardPositionMatches() {
        #expect(OpeningFENKey.key(for: .standard) == Self.startKey)
    }

    @Test func invalidFENReturnsNil() {
        #expect(OpeningFENKey.normalize("ceci n'est pas une FEN") == nil)
    }

    /// LE test qui protège la fusion des transpositions : 1.Cf3 d5 2.d4 et
    /// 1.d4 d5 2.Cf3 atteignent la MÊME position mais avec un compteur de
    /// demi-coups différent — les FEN brutes diffèrent, les clés doivent
    /// coïncider.
    @Test func transpositionsMergeToTheSameKey() {
        var a = Board(position: .standard)
        _ = a.move(pieceAt: Square("g1"), to: Square("f3"))
        _ = a.move(pieceAt: Square("d7"), to: Square("d5"))
        _ = a.move(pieceAt: Square("d2"), to: Square("d4"))

        var b = Board(position: .standard)
        _ = b.move(pieceAt: Square("d2"), to: Square("d4"))
        _ = b.move(pieceAt: Square("d7"), to: Square("d5"))
        _ = b.move(pieceAt: Square("g1"), to: Square("f3"))

        #expect(a.position.fen != b.position.fen) // compteurs différents
        #expect(OpeningFENKey.key(for: a.position) == OpeningFENKey.key(for: b.position))
    }

    /// Case e.p. CONSERVÉE quand une prise en passant est réellement légale :
    /// 1.e4 c5 2.e5 d5 — le pion blanc e5 peut prendre exd6 e.p.
    @Test func enPassantKeptWhenCaptureIsLegal() {
        var board = Board(position: .standard)
        _ = board.move(pieceAt: Square("e2"), to: Square("e4"))
        _ = board.move(pieceAt: Square("c7"), to: Square("c5"))
        _ = board.move(pieceAt: Square("e4"), to: Square("e5"))
        _ = board.move(pieceAt: Square("d7"), to: Square("d5"))

        let key = OpeningFENKey.key(for: board.position)
        #expect(key.hasSuffix(" d6"))
    }

    /// Case e.p. RETIRÉE quand aucun preneur n'existe : après 1.e4, la case e3
    /// est « en passant » côté ChessKit mais aucun pion noir ne peut prendre.
    @Test func enPassantDroppedWhenNoCapturerExists() {
        var board = Board(position: .standard)
        _ = board.move(pieceAt: Square("e2"), to: Square("e4"))

        let key = OpeningFENKey.key(for: board.position)
        #expect(!key.contains("e3"))
        #expect(key.hasSuffix(" -"))
    }
}
