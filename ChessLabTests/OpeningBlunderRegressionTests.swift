import Testing
@testable import ChessLab

/// Verrou sur les quinze gaffes corrigées le 15/08/2026.
///
/// Un testeur classé a trouvé, dans la version installée, des coups que la base
/// donnait pour bons et qui perdaient une pièce ou une tour. La correction vit
/// dans `tools/opening-generator/content/*.py`, hors de la cible iOS : rien ne
/// l'empêchait de disparaître au prochain `author.py`. Ce test lit le BUNDLE et
/// exige, position par position, que le bon coup soit là et que la gaffe n'y
/// soit plus.
///
/// L'audit moteur (`tools/opening-generator/audit.py`) reste le garde-fou
/// général — il rejoue les 3 000 arêtes sous Stockfish, ce qu'aucun test
/// unitaire ne peut faire. Celui-ci ne couvre que les cas déjà payés, mais il
/// tourne à chaque `xcodebuild test`, sans moteur ni réseau.
struct OpeningBlunderRegressionTests {

    /// (cours, position, coup attendu, gaffe d'origine). Les clés sont les FEN
    /// normalisées du graphe — mêmes clés que la progression FSRS.
    static let corrections: [(course: String, fen: String, expected: String, blunder: String)] = [
        // …Dxa1+ : la tour a1 est en prise et RIEN ne la défend (capture d'écran du testeur).
        ("englund-gambit", "r1b1k1nr/pppp1ppp/2n5/4P3/8/2N2N2/PqPQPPPP/R3KB1R b KQkq -", "Qxa1+", "Qb4"),
        // Contre 5.Cc3 on reprend f4, pas b2 : …Dxb2 laisse les Blancs nettement mieux.
        ("englund-gambit", "r1b1kbnr/pppp1ppp/2n5/4P3/1q3B2/2N2N2/PPP1PPPP/R2QKB1R b KQkq -", "Qxf4", "Qxb2"),
        // …Cd5 perdait la pièce sur Cg5 puis Fxd5 (capture d'écran du testeur).
        ("blackmar-diemer", "r2q1rk1/ppp1ppbp/2n2np1/8/2BP2bQ/2N1BN2/PPP3PP/R4RK1 b - -", "e6", "Nd5"),
        // …Cxd5 perdait une pièce : le fou d7 bouche la colonne d, la dame ne défend pas d5.
        ("scandinavian", "rn1qkb1r/p1pbpppp/5n2/1p1P4/8/1B6/PPPP1PPP/RNBQK1NR b KQkq -", "Bg4", "Nxd5"),
        ("caro-kann", "rnbqk1nr/pp3ppp/2p1p3/8/3PP3/P1P5/2P3PP/R1BQKBNR b KQkq -", "Qh4+", "e5"),
        ("anti-sicilians", "r1bqkb1r/1p3ppp/p1nppn2/8/2B1P3/2N2N2/PP2QPPP/R1BR2K1 b kq -", "Qc7", "Be7"),
        ("kings-indian", "r1bq1rk1/pp3pbp/3p1np1/2nPp3/4P1P1/2N1BP2/PP1QN2P/R3KB1R b KQ -", "Bxg4", "a5"),
        ("bogo-indian", "rnbq1rk1/1pp2ppp/3ppn2/p7/1bPP4/5NP1/PP1BPPBP/RN1Q1RK1 b - -", "Bd7", "Nbd7"),
        // Le sacrifice grec, raison d'être du Colle — De2 le laissait passer.
        ("colle-system", "r1b2rk1/ppqn1ppp/2n1p3/2bpP3/8/2PB1N2/PP1N1PPP/R1BQ1RK1 w - -", "Bxh7+", "Qe2"),
        // f4 AVANT Cd2 : l'autre ordre perd d4 sur …Cxe5.
        ("colle-system", "r1b2rk1/ppq2ppp/2nbpn2/2ppN3/3P4/1P1BP3/PBP2PPP/RN1Q1RK1 w - -", "f4", "Nd2"),
        ("london-system", "r2q1rk1/pb3ppp/1pnbpn2/2ppN3/3P1P2/2PBP1B1/PP1N2PP/R2QK2R b KQ -", "Ne7", "Ne4"),
        // a3 ferme a2 AVANT Tb1 : dans l'autre ordre la dame noire s'échappe.
        ("london-system", "r1b1kb1r/pp1ppppp/n4n2/1Np5/3P1B2/4P3/PqP2PPP/R2QKBNR w KQkq -", "a3", "Rb1"),
        // 10.Cf1 tout de suite perdait e5 sur …Cdxe5, la dame c7 appuyant la prise.
        ("kings-indian-attack", "r1b2rk1/ppqnbppp/2n1p3/2ppP3/8/3P1NP1/PPPN1PBP/R1BQR1K1 w - -", "Qe2", "Nf1"),
        ("sicilian-classical", "r1bqk2r/pp2ppb1/2np3p/6p1/3NP1n1/2N3BP/PPP2PP1/R2QKB1R b KQkq -", "Bxd4", "Nge5"),
        // …b5 perdait la tour a8 après Fxf6 gxf6 puis e5.
        ("sicilian-scheveningen", "r1bq1rk1/pp2bppp/3ppn2/8/3BPP2/2N2Q2/PPP3PP/2KR1B1R b - -", "Qa5", "b5"),
    ]

    @Test(arguments: corrections)
    func correctedMoveIsBundledAndBlunderIsGone(_ item: (course: String, fen: String, expected: String, blunder: String)) throws {
        let course = try #require(
            OpeningCourseLoader.course(id: item.course),
            "cours embarqué introuvable : \(item.course)"
        )
        let node = try #require(
            course.positions[item.fen],
            "position absente du graphe \(item.course) : \(item.fen)"
        )
        let sans = node.moves.map(\.san)
        #expect(sans.contains(item.expected),
                "\(item.course) : le coup corrigé « \(item.expected) » a disparu (présents : \(sans))")
        #expect(!sans.contains(item.blunder),
                "\(item.course) : la gaffe « \(item.blunder) » est revenue")
    }

    /// Les fautes qu'on montre EXPRÈS portent leur rôle : sans lui, l'app les
    /// affiche comme des coups ordinaires, sans la pastille « Piège », et le
    /// lecteur croit qu'on lui recommande de perdre une tour.
    @Test func deliberateMistakesAreTaggedAsTraps() throws {
        let tagged: [(course: String, fen: String, san: String)] = [
            // Englund : 6.Fc3?? se met sur la diagonale de sa propre tour a1.
            ("englund-gambit", "r1b1kbnr/pppp1ppp/2n5/4P3/8/5N2/PqPBPPPP/RN1QKB1R w KQkq -", "Bc3"),
            // Albin, piège de Lasker : 6.Fxb4?? laisse filer le pion e3.
            ("albin-countergambit", "rnbqk1nr/ppp2ppp/8/4P3/1bP5/4p3/PP1B1PPP/RN1QKBNR w KQkq -", "Bxb4"),
            // Stafford : 6.Cc3?? — le réflexe naturel, mais seul 6.Fe2 tient.
            ("stafford-gambit", "r1bqk2r/ppp2ppp/2p2n2/2b5/4P3/3P4/PPP2PPP/RNBQKB1R w KQkq -", "Nc3"),
        ]
        for item in tagged {
            let course = try #require(OpeningCourseLoader.course(id: item.course))
            let node = try #require(course.positions[item.fen],
                                    "position absente : \(item.course) \(item.fen)")
            let edge = try #require(node.moves.first { $0.san == item.san },
                                    "arête absente : \(item.course) \(item.san)")
            #expect(edge.role == .trap,
                    "\(item.course) \(item.san) doit rester annoté « piège » (rôle : \(String(describing: edge.role)))")
        }
    }
}
