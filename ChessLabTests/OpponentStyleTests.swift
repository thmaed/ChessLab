import ChessKit
import Testing
@testable import ChessLab

/// Les traits de coup : reconnaissance ET non-reconnaissance, sur des
/// positions où la réponse est connue. Puis la repondération, bornée.
@Suite struct OpponentStyleTests {

    private func board(_ fen: String) -> Board { Board(position: Position(fen: fen)!) }

    @Test func aQuietOpeningMoveHasNoTacticalTraits() throws {
        let traits = try #require(OpponentStyle.traits(of: "e2e4", on: Board(position: .standard)))
        #expect(!traits.check && !traits.capture && !traits.sacrifice && !traits.castle)
        #expect(!traits.development, "un pion n'est pas une pièce mineure")
        #expect(traits.weakPawnDelta == 0)
    }

    @Test func aKnightLeavingItsHomeSquareIsDevelopment() throws {
        let traits = try #require(OpponentStyle.traits(of: "g1f3", on: Board(position: .standard)))
        #expect(traits.development)
        #expect(traits.mobilityDelta > 0, "le cavalier gagne des cases en sortant")
    }

    @Test func scholarsMateIsACheckingCapture() throws {
        let position = board("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")
        let traits = try #require(OpponentStyle.traits(of: "h5f7", on: position))
        #expect(traits.check && traits.capture)
        #expect(traits.capturedValue == 1 && traits.movedValue == 9)
        // Mat : l'adversaire n'a aucun coup, donc aucun attaquant — pas un sacrifice.
        #expect(!traits.sacrifice)
    }

    @Test func theGreekGiftIsASacrificeTowardTheKing() throws {
        let position = board("r1bq1rk1/ppp1bppp/2n1p3/3pP3/3P4/2PB1N2/P1P2PPP/R1BQK2R w KQ - 0 9")
        let traits = try #require(OpponentStyle.traits(of: "d3h7", on: position))
        #expect(traits.check && traits.capture)
        #expect(traits.sacrifice, "le fou peut être pris par le roi : un sacrifice")
        #expect(traits.towardKing)
    }

    @Test func castlingIsRecognisedAndNothingElse() throws {
        let position = board("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
        let traits = try #require(OpponentStyle.traits(of: "e1g1", on: position))
        #expect(traits.castle)
        #expect(!traits.capture && !traits.check && !traits.sacrifice)
    }

    @Test func weakPawnsCountIsolatedAndDoubledPawns() {
        // a2 b2 : voisins ; d2 isolé ; f2 isolé ; h2 isolé.
        #expect(OpponentStyle.weakPawns(in: Position(fen: "8/8/8/8/8/8/PP1P1P1P/8 w - - 0 1")!, of: .white) == 3)
        // c2 c3 doublés (et isolés) : 2 isolés + 1 doublé.
        #expect(OpponentStyle.weakPawns(in: Position(fen: "8/8/8/8/8/2P5/2P5/8 w - - 0 1")!, of: .white) == 3)
        #expect(OpponentStyle.weakPawns(in: .standard, of: .black) == 0)
    }

    @Test func aPawnStormIsAPawnOnTheEnemyKingsWing() throws {
        // Roi noir roqué à g8, pion blanc g4 → g5 : assaut ; a4 → a5 : non.
        let position = board("r1bq1rk1/ppp2ppp/2np1n2/2b1p3/P3P1P1/2NP1N2/1PP2P1P/R1BQKB1R w KQ - 0 8")
        let storm = try #require(OpponentStyle.traits(of: "g4g5", on: position))
        #expect(storm.pawnStorm)
        let quiet = try #require(OpponentStyle.traits(of: "a4a5", on: position))
        #expect(!quiet.pawnStorm)
    }

    @Test func styleReweightsTheDistributionWithinItsBound() {
        let position = board("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")
        let legal = MaiaLegalMoves.moves(in: position)
        let mate = legal.first { $0.uci == "h5f7" }!
        let quiet = legal.first { $0.uci == "b1c3" }!
        let candidates = [MaiaCandidate(move: quiet, probability: 0.6), MaiaCandidate(move: mate, probability: 0.4)]

        let aggressive = StyleProfile(weights: [.check: 1, .capture: 1], strength: 1)
        let reweighted = OpponentStyle.apply(aggressive, to: candidates, board: position)
        let mateProbability = reweighted.first { $0.move.uci == "h5f7" }!.probability
        // Facteur e^1 ≈ 2,72 sur 0,4 contre 0,6 : 1,087 / (0,6 + 1,087).
        #expect(abs(mateProbability - 0.644) < 0.01)
        #expect(abs(reweighted.reduce(0) { $0 + $1.probability } - 1) < 1e-9)
        #expect(reweighted.first?.move.uci == "h5f7", "retrié par probabilité")

        // Borné : des poids énormes ne dépassent pas e^strength.
        let extreme = StyleProfile(weights: [.check: 50, .capture: 50], strength: 1)
        let bounded = OpponentStyle.apply(extreme, to: candidates, board: position)
        #expect(abs(bounded.first { $0.move.uci == "h5f7" }!.probability - mateProbability) < 1e-9)

        // Style neutre : distribution inchangée.
        #expect(OpponentStyle.apply(.none, to: candidates, board: position) == candidates)
    }

    @Test func moodFollowsTheScore() {
        let marc = OpponentProfile.marc
        #expect(marc.mood(lastMoverCp: nil).temperature == marc.temperature)
        #expect(marc.mood(lastMoverCp: 350).temperature == 0.7, "Marc se calme quand il mène")
        #expect(marc.mood(lastMoverCp: -350).temperature == marc.temperature)
        let ines = OpponentProfile.ines
        #expect(ines.mood(lastMoverCp: -300).style.weights[.sacrifice, default: 0] > ines.style.weights[.sacrifice, default: 0],
                "Inès s'anime quand elle perd")
    }
}
