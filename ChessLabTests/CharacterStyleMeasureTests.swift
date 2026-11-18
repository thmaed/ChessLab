import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// MESURE, pas régression (éteinte par défaut) : ce que le style d'un personnage change aux VRAIS choix de Maia,
/// sur des positions réelles — part du roque quand il est possible, du développement en ouverture, de l'élan
/// vers le roi adverse. Sert à vérifier une retouche de personnage avant/après (17/11/2026 : Milo et Pablo).
///
/// `TEST_RUNNER_CHESSLAB_STYLE_MEASURE=1 xcodebuild test … -only-testing:ChessLabTests/CharacterStyleMeasureTests`
@Suite(.serialized)
@MainActor
struct CharacterStyleMeasureTests {
    private var enabled: Bool { ProcessInfo.processInfo.environment["CHESSLAB_STYLE_MEASURE"] == "1" }

    /// Les réglages AVANT la retouche, pour comparer.
    private static let oldMilo = StyleProfile(weights: [
        .sacrifice: 0.7, .check: 0.3, .towardKing: 0.4, .capture: 0.1, .materialGain: -0.3,
        .equalTrade: -0.5, .queenTrade: -0.8, .tension: 0.3,
    ], strength: 1.2)
    private static let oldPablo = StyleProfile(weights: [
        .check: 0.4, .capture: 0.3, .towardKing: 0.3, .castle: -0.4, .development: -0.1,
    ], strength: 0.6)

    /// Des positions de vraies ouvertures humaines : Maia (sans style) contre elle-même, coups tirés au hasard
    /// selon sa distribution, graine fixe.
    private func positions(_ maia: MaiaOpponent, games: Int, plies: Int) async throws -> [(history: [Position], board: Board, ply: Int)] {
        var seeded = SeededGenerator(seed: 2026)
        var out: [(history: [Position], board: Board, ply: Int)] = []
        for _ in 0..<games {
            var board = Board(position: .standard)
            var history: [Position] = [board.position]
            for ply in 0..<plies {
                let candidates = try await maia.distribution(history: history, board: board, selfElo: 1200, oppoElo: 1200)
                guard !candidates.isEmpty else { break }
                if ply >= 3 { out.append((history, board, ply)) }
                let roll = Double.random(in: 0..<1, using: &seeded)
                var acc = 0.0
                var chosen = candidates[0].move.uci
                for candidate in candidates {
                    acc += candidate.probability
                    if roll < acc { chosen = candidate.move.uci; break }
                }
                let start = Square(String(chosen.prefix(2))), end = Square(String(chosen.dropFirst(2).prefix(2)))
                guard let move = board.move(pieceAt: start, to: end) else { break }
                if case .promotion = board.state { _ = board.completePromotion(of: move, to: .queen) }
                history.append(board.position)
                if history.count > 8 { history.removeFirst() }
            }
        }
        return out
    }

    @Test func measureMiloAndPabloBeforeAndAfter() async throws {
        guard enabled else { return }
        let maia = try #require(MaiaOpponent())
        let sample = try await positions(maia, games: 24, plies: 24)
        let styles: [(String, StyleProfile)] = [
            ("Maia (neutre)", .none),
            ("Lena", OpponentProfile.lea.style),
            ("Milo AVANT", Self.oldMilo), ("Milo APRÈS", OpponentProfile.theo.style),
            ("Sacha", OpponentProfile.sacha.style),
            ("Pablo AVANT", Self.oldPablo), ("Pablo APRÈS", OpponentProfile.pablo.style),
        ]
        var bases: [[MaiaCandidate]] = []
        for p in sample {
            bases.append(try await maia.distribution(history: p.history, board: p.board, selfElo: 1200, oppoElo: 1200))
        }
        print("STYLE|personnage|roque quand possible|développement (≤ coup 12)|vers le roi + pions lancés|échecs")
        for (name, style) in styles {
            var castle = (0.0, 0), dev = (0.0, 0), attack = (0.0, 0), check = (0.0, 0)
            for (index, p) in sample.enumerated() {
                let dist = OpponentStyle.apply(style, to: bases[index], board: p.board)
                var castleMass = 0.0, canCastle = false, devMass = 0.0, attackMass = 0.0, checkMass = 0.0
                for candidate in dist {
                    guard let t = OpponentStyle.traits(of: candidate.move.uci, on: p.board) else { continue }
                    if t.castle { castleMass += candidate.probability; canCastle = true }
                    if t.development { devMass += candidate.probability }
                    if t.towardKing || t.pawnStorm { attackMass += candidate.probability }
                    if t.check { checkMass += candidate.probability }
                }
                if canCastle { castle.0 += castleMass; castle.1 += 1 }
                if p.ply < 24 { dev.0 += devMass; dev.1 += 1 }
                attack.0 += attackMass; attack.1 += 1
                check.0 += checkMass; check.1 += 1
            }
            func pct(_ v: (Double, Int)) -> String { v.1 == 0 ? "—" : String(format: "%.1f %%", 100 * v.0 / Double(v.1)) }
            print("STYLE|\(name)|\(pct(castle))|\(pct(dev))|\(pct(attack))|\(pct(check))")
        }
    }
}

/// SplitMix64 : un tirage reproductible.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
