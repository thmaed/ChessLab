import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// La campagne d'ORACLE de la couche Chess960 — python-chess fait autorité,
/// le Swift se conforme. Fixtures générées par
/// `tools/opening-generator/gen_chess960_fixtures.py` (graine fixe).
///
/// Trois instruments, du plus simple au plus implacable :
/// 1. les 960 positions de départ, octet pour octet ;
/// 2. 40 parties rejouées coup à coup (UCI roi-prend-tour comme sous
///    `UCI_Chess960`), FEN Shredder comparé après CHAQUE coup — c'est la
///    tenue des droits et l'exécution du roque qu'on éprouve ;
/// 3. perft : 1,2 million de nœuds comptés — une génération de coups fausse
///    ne peut pas donner les bons comptes.
@MainActor
struct Chess960RulesTests {

    private final class BundleToken {}

    private static func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(
            Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json"),
            "fixture \(name).json absente du bundle de test"
        )
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    // MARK: 1. Les 960 départs

    @Test("Les 960 positions de départ sont celles de python-chess")
    func allStartingPositionsMatchTheOracle() throws {
        let expected = try Self.fixture("Fixtures_chess960_starts", as: [String: String].self)
        try #require(expected.count == 960)
        for number in 0..<960 {
            let fen = Chess960Position.startingFEN(number: number)
            #expect(fen == expected[String(number)], "position n° \(number)")
        }
    }

    // MARK: 2. Les parties rejouées

    private struct Playout: Decodable {
        struct PlayedMove: Decodable { let uci: String; let san: String; let fen: String }
        let number: Int
        let startFEN: String
        let moves: [PlayedMove]
    }

    @Test("40 parties de l'oracle se rejouent coup à coup, roques compris")
    func playoutsReplayMoveByMove() throws {
        let games = try Self.fixture("Fixtures_chess960_playouts", as: [Playout].self)
        try #require(games.count == 40)
        var castles = 0
        for playout in games {
            var game = try #require(Chess960Game(fen: playout.startFEN),
                                    "départ n° \(playout.number) illisible")
            #expect(game.shredderFEN == playout.startFEN)
            for (index, move) in playout.moves.enumerated() {
                if move.san.hasPrefix("O-O") { castles += 1 }
                let san = game.apply(uci: move.uci)
                #expect(san == move.san,
                        "partie \(playout.number), coup \(index + 1) (\(move.uci)) : SAN \(san ?? "REFUSÉ") ≠ \(move.san)")
                #expect(game.shredderFEN == move.fen,
                        "partie \(playout.number), coup \(index + 1) (\(move.uci)) : FEN divergent")
                if game.shredderFEN != move.fen { return }   // inutile de dérouler le reste
            }
        }
        #expect(castles >= 40, "le biais vers le roque a disparu des fixtures : \(castles)")
    }

    // MARK: 3. Perft

    private struct PerftEntry: Decodable {
        let name: String
        let fen: String
        let perft: [String: Int]
    }

    private func runPerft(depthLimit: ClosedRange<Int>) throws {
        let entries = try Self.fixture("Fixtures_chess960_perft", as: [PerftEntry].self)
        try #require(entries.count > 30)
        for entry in entries {
            let game = try #require(Chess960Game(fen: entry.fen), "\(entry.name) illisible")
            for (depth, expected) in entry.perft.sorted(by: { $0.key < $1.key })
            where depthLimit.contains(Int(depth)!) {
                let counted = game.perft(depth: Int(depth)!)
                #expect(counted == expected,
                        "\(entry.name) profondeur \(depth) : \(counted) ≠ \(expected) — \(entry.fen)")
                if counted != expected { return }
            }
        }
    }

    /// Le perft de ROUTINE : profondeurs 1-3, ~150 000 nœuds, ~30 s. C'est lui
    /// qui tourne à chaque suite — assez pour attraper toute règle fausse
    /// (c'est la profondeur 3 qui a démasqué le roque-sous-échec du 25/08).
    @Test("Perft : chaque compte de l'oracle est retrouvé (prof. 1-3)")
    func perftMatchesTheOracle() throws {
        try runPerft(depthLimit: 1...3)
    }

    /// La profondeur 4 (1,1 million de nœuds, ~3 min 30) : les interactions
    /// roque × clouage × en passant les plus profondes. Trop lente pour la
    /// suite verte habituelle — à lancer À LA DEMANDE, comme les captures
    /// App Store : `CHESS960_PERFT_FULL=1` dans l'environnement de test.
    @Test("Perft profondeur 4 — campagne complète, à la demande",
          .enabled(if: ProcessInfo.processInfo.environment["CHESS960_PERFT_FULL"] == "1"))
    func perftFullCampaign() throws {
        try runPerft(depthLimit: 4...4)
    }

    // MARK: Cas nommés — lisibles sans fixtures

    /// La 518 EST la partie classique : la couche 960 doit s'y comporter
    /// exactement comme les règles normales, roque e1g1 compris.
    @Test("La position 518 est la partie classique, roque compris")
    func number518IsClassicalChess() throws {
        var game = try #require(Chess960Game(number: 518))
        #expect(game.shredderFEN == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w HAha - 0 1")
        for uci in ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"] {
            #expect(game.apply(uci: uci) != nil, "\(uci) refusé")
        }
        #expect(game.apply(uci: "e1h1") == "O-O", "le roque classique, en dialecte roi-prend-tour")
        #expect(game.shredderFEN.hasPrefix("r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQ1RK1 b ha"))
    }

    /// Un FEN classique (KQkq) est accepté et traduit en colonnes.
    @Test("Les droits KQkq d'un FEN classique sont traduits")
    func classicRightsAreTranslated() throws {
        let game = try #require(Chess960Game(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"))
        #expect(game.shredderFEN == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w HAha - 0 1")
    }
}
