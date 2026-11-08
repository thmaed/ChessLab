import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Une partie JOUÉE dans l'app (126 demi-coups, 08/11/2026) qui faisait quitter l'app à l'analyse.
///
/// Elle contient « Rbxd4 » (capture désambiguïsée : ChessKit la lit de travers, donc le chargeur
/// reconstruit la partie coup par coup) ET deux promotions (« g1=Q », « e1=Q+ »). La
/// reconstruction oubliait les promotions : le pion restait sur la dernière rangée, et Stockfish 19
/// refuse une telle position en quittant le process.
struct PGNLoaderPromotionTests {
    private static let pgn = """
[Event "Contre l'ordinateur"]
[Site "ChessLab"]
[Date "2026.09.30"]
[Round "-"]
[White "Pablo"]
[Black "Thierry"]
[Result "0-1"]

1. d4 d5 2. Bf4 e6 3. Qd3 Nc6 4. Qg3 Bd6 5. e3 Bxf4 6. Qxf4 Qd6 7. Qxd6 cxd6 8. Bb5 Nf6 9. Bxc6+ bxc6 10. Nd2 Ba6 11. Nb3 Ne4 12. Nd2 O-O 13. Nxe4 dxe4 14. Ne2 d5 15. Ng3 f5 16. a4 Rab8 17. b3 Rb4 18. f4 exf3 19. gxf3 g6 20. O-O-O f4 21. exf4 Rxf4 22. Rdf1 h5 23. Rf2 Rbxd4 24. Rd1 h4 25. Rxd4 Rxd4 26. Nh1 Rf4 27. h3 e5 28. Kd2 Kg7 29. Kd1 Kf6 30. b4 Rxb4 31. c3 Rxa4 32. Rb2 Ra1+ 33. Kd2 Rxh1 34. Rb8 Rxh3 35. Rf8+ Ke6 36. Ra8 Rxf3 37. Rxa7 Be2 38. Rc7 Bf1 39. Ra7 h3 40. Rh7 e4 41. Ke1 Bd3 42. Kd2 g5 43. Ke1 g4 44. Kd2 g3 45. Rxh3 g2 46. Rh6+ Kf5 47. Rh5+ Kg4 48. Rh7 g1=Q 49. Rg7+ Kf4 50. Rxg1 Rg3 51. Rf1+ Rf3 52. Rh1 c5 53. Rh4+ Kf5 54. Rh5+ Kf4 55. Kc1 e3 56. Kd1 e2+ 57. Ke1 Rf1+ 58. Kd2 e1=Q+ 59. Kxd3 Qe3+ 60. Kc2 Rc1+ 61. Kb3 Qxc3+ 62. Ka4 Rb1 63. Rxd5 Qa1# 0-1
"""

    @Test func aReloadedGameKeepsItsPromotedPieces() throws {
        let game = try #require(PGNLoader.game(from: Self.pgn))
        var index = game.startingIndex
        var plies = 0
        var fens: [String] = []
        while true {
            if let position = game.positions[index] { fens.append(position.fen) }
            guard game.moves.hasIndex(after: index) else { break }
            index = game.moves.index(after: index)
            plies += 1
        }
        #expect(plies == 126)
        for (ply, fen) in fens.enumerated() {
            let ranks = fen.split(separator: " ")[0].split(separator: "/")
            #expect(!ranks.first!.contains("P") && !ranks.first!.contains("p"), "pion sur la 8e rangée, demi-coup \(ply) : \(fen)")
            #expect(!ranks.last!.contains("P") && !ranks.last!.contains("p"), "pion sur la 1re rangée, demi-coup \(ply) : \(fen)")
        }
        // Les deux dames promues sont bien là, et la position finale est celle de la partie.
        #expect(fens[96].hasPrefix("8/7R/2p5/3p4/4p1k1/2Pb1r2/3K4/6q1 "), "g1=Q : \(fens[96])")
        #expect(fens.last?.hasPrefix("8/8/8/2pR4/K4k2/8/8/qr6 ") == true, "\(fens.last ?? "")")
    }

    /// Les annotations d'un PGN commenté (« ! », « ? », « !? ») collées à une capture désambiguïsée ne
    /// doivent pas faire tronquer la partie : le chargeur compare chaque coup à sa lecture corrigée.
    @Test func anAnnotatedDisambiguatedCaptureStillLoadsInFull() throws {
        let annotated = Self.pgn
            .replacingOccurrences(of: "Rbxd4", with: "Rbxd4!")
            .replacingOccurrences(of: "g1=Q", with: "g1=Q?!")
            .replacingOccurrences(of: " Rxd4 Rxd4", with: " Rxd4! Rxd4?")
        #expect(annotated != Self.pgn)
        let game = try #require(PGNLoader.game(from: annotated))
        var index = game.startingIndex
        var plies = 0
        while game.moves.hasIndex(after: index) { index = game.moves.index(after: index); plies += 1 }
        #expect(plies == 126, "partie tronquée à \(plies) demi-coups")
        #expect(game.positions[index]?.fen.hasPrefix("8/8/8/2pR4/K4k2/8/8/qr6 ") == true)
    }
}
