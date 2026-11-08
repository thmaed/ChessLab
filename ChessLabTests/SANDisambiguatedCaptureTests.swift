import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Retour de Ron (08/11/2026) : sept parties de son fichier de 1100 puzzles étaient
/// écartées (« le coup Kc8 n'est pas jouable ») alors qu'elles se jouent partout
/// ailleurs. Toutes contenaient une CAPTURE désambiguïsée par la colonne (`Rfxd7+`,
/// `Rcxc7`…) : l'expression de ChessKit qui lit la désambiguïsation exige qu'elle touche
/// la case d'arrivée, le `x` la lui cache, et la première tour trouvée est jouée à la place.
struct SANDisambiguatedCaptureTests {
    /// Partie 365 du fichier de Ron : les deux tours (f7 et d1) peuvent prendre en d7.
    private static let ronFEN = "2bkr3/p2n1RQ1/1r5p/1p6/4q3/P7/1PP4P/1K1R4 b - - 1 24"

    @Test func aFileDisambiguatedCapturePlaysTheRightPiece() throws {
        let position = try #require(Position(fen: "2bkr3/p2n1RQ1/6rp/1p6/4q3/P7/1PP4P/1K1R4 w - - 2 25"))
        let move = try #require(SAN.move("Rfxd7+", in: position))
        #expect(move.start == Square("f7"))
        #expect(move.end == Square("d7"))
        #expect(move.lan == "f7d7")
        // C'est bien une capture, avec son marqueur d'échec.
        if case .capture = move.result {} else { Issue.record("une capture attendue") }
        #expect(move.checkState == .check)
    }

    @Test func theOtherRookStillCapturesWhenItsFileIsNamed() throws {
        let position = try #require(Position(fen: "2bkr3/p2n1RQ1/6rp/1p6/4q3/P7/1PP4P/1K1R4 w - - 2 25"))
        let move = try #require(SAN.move("Rdxd7+", in: position))
        #expect(move.lan == "d1d7")
    }

    @Test func aRankDisambiguatedCaptureKeepsItsPiece() throws {
        // Deux tours sur la colonne a, en a1 et a5 : « R1xa3 » désigne celle de a1.
        let position = try #require(Position(fen: "4k3/8/8/R7/8/p7/8/R3K3 w - - 0 1"))
        #expect(SAN.move("R1xa3", in: position)?.lan == "a1a3")
        #expect(SAN.move("R5xa3", in: position)?.lan == "a5a3")
    }

    @Test func ordinaryMovesAreStillReadByChessKit() throws {
        let position = Position.standard
        #expect(SAN.move("Nf3", in: position)?.lan == "g1f3")
        #expect(SAN.move("e4", in: position)?.lan == "e2e4")
        #expect(SAN.move("Ke2", in: position) == nil)
    }

    @Test func ronsSevenSkippedGamesNowImport() throws {
        let games = [
            ("1kr5/1pBrp3/8/1N1p2p1/3n1q1p/Q4P2/PPP2P1P/1K4R1 b - - 1 24", "24...Rcxc7 25.Qa7+ Kc8 26.Qa8#"),
            ("q1r3k1/2r2pp1/2n1p2p/pR1pPn2/Pp1P4/1P2B3/3Q1PPP/2R1N1K1 b - - 11 29", "29...Ncxd4 30.Rxc7 Rxc7 31.Bxd4 Nxd4 32.Qxd4"),
            (Self.ronFEN, "24...Rg6 25.Rfxd7+ Bxd7 26.Qxd7#"),
            ("8/p7/8/2p3r1/3p2bR/1P1P1k2/P1P4K/6R1 w - - 9 38", "38.Rhxg4 Rh5+ 39.Rh4 Rxh4#"),
            ("r2q1rk1/5ppp/4pb2/pNn5/Pp1Bn3/1P2P3/4NPPP/2RQ1RK1 b - - 10 18", "18...e5 19.Bxc5 Qxd1 20.Rfxd1 Nxc5 21.Rxc5"),
            ("2k2r1r/ppqb2p1/3b3p/2pp4/5NQ1/2NP3P/PPP3P1/R1B2RK1 w - - 1 20", "20.Nfxd5 Bh2+ 21.Kh1 Rxf1#"),
            ("3r3k/ppp2pp1/7p/8/1P3bP1/P1BB1r2/2K4P/3R3R w - - 4 28", "28.Rhf1 Rdxd3 29.Rxd3 Rxf1"),
        ]
        for (fen, moves) in games {
            let text = "[SetUp \"1\"]\n[FEN \"\(fen)\"]\n\n\(moves) *\n"
            let result = PuzzleCollectionImporter.parse(text)
            #expect(result.skipped.isEmpty, "écartée : \(moves) — \(result.skipped)")
            #expect(result.puzzles.count == 1, "\(moves)")
        }
    }

    /// La bibliothèque et l'analyse passent d'abord par `Game(pgn:)`, le lecteur de
    /// ChessKit, qui a le même défaut : la partie ne doit pas être lue de travers.
    @Test func aLibraryGameWithADisambiguatedCaptureReplaysCorrectly() throws {
        let pgn = """
        [Event "Ron"]
        [SetUp "1"]
        [FEN "\(Self.ronFEN)"]

        24...Rg6 25.Rfxd7+ Bxd7 26.Qxd7# *
        """
        let game = try #require(PGNLoader.game(from: pgn))
        let sans = game.moves.indices.filter { $0.variation == MoveTree.Index.mainVariation }
            .sorted { ($0.number, $0.color == .black ? 1 : 0) < ($1.number, $1.color == .black ? 1 : 0) }
            .compactMap { game.moves[$0]?.san }
        #expect(sans == ["Rg6", "Rfxd7+", "Bxd7", "Qxd7#"], "\(sans)")
        #expect(game.positions[game.moves.endIndex]?.fen.hasPrefix("3kr3/p2Q4/6rp/1p6/4q3/P7/1PP4P/1K1R4 ") == true)
    }
}
