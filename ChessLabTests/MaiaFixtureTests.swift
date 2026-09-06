import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Les fixtures `Fixtures_maia3.json` sont GÉNÉRÉES par l'implémentation de
/// référence de Maia-3 (`tools/maia3-spike/make_fixtures.py`) : pour 56
/// positions (Blancs et Noirs, historiques courts et longs, roques, prises en
/// passant, promotions, finales), l'encodage attendu bit à bit, le nombre de
/// coups légaux, les cinq coups les plus probables et l'issue humaine prédite.
///
/// Trois vérités en découlent, dans l'ordre où elles se prouvent :
///  1. l'encodeur Swift produit EXACTEMENT le tenseur du code Python ;
///  2. l'énumération des coups légaux et leur projection dans le vocabulaire
///     de Maia sont celles du masque de référence ;
///  3. le modèle Core ML (fp16) rend la même distribution que le modèle
///     PyTorch (fp32), à la précision près.
private final class MaiaFixtureBundleToken {}

struct MaiaFixtureCase: Decodable {
    struct Top: Decodable {
        let uci: String
        let p: Double
    }

    let startFEN: String
    let moves: [String]
    let selfElo: Int
    let oppoElo: Int
    let tokens: [String]
    let legalCount: Int
    let top: [Top]
    /// `[gain, nulle, défaite]` du camp au trait.
    let wdl: [Double]

    var label: String { "\(startFEN) + \(moves.count) coups @\(selfElo)/\(oppoElo)" }
}

struct MaiaFixtureFile: Decodable {
    let model: String
    let history: Int
    let cases: [MaiaFixtureCase]
}

enum MaiaFixtures {
    static let file: MaiaFixtureFile? = {
        guard let url = Bundle(for: MaiaFixtureBundleToken.self).url(forResource: "Fixtures_maia3", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(MaiaFixtureFile.self, from: data)
    }()

    static var cases: [MaiaFixtureCase] { file?.cases ?? [] }

    /// Rejoue les coups UCI depuis le FEN de départ, comme le fait
    /// `PlayViewModel.applyEngineMove` : `Board.move` puis promotion.
    static func replay(_ fixture: MaiaFixtureCase) -> (board: Board, history: [Position])? {
        guard let start = Position(fen: fixture.startFEN) else { return nil }
        var board = Board(position: start)
        var history = [board.position]
        for uci in fixture.moves {
            let from = Square(String(uci.prefix(2)))
            let to = Square(String(uci.dropFirst(2).prefix(2)))
            guard let move = board.move(pieceAt: from, to: to) else { return nil }
            if case .promotion = board.state {
                let kind = uci.count == 5
                    ? (Piece.Kind(rawValue: String(uci.suffix(1)).uppercased()) ?? .queen)
                    : .queen
                board.completePromotion(of: move, to: kind)
            }
            history.append(board.position)
        }
        return (board, history)
    }
}

@Suite struct MaiaMoveTableTests {

    @Test func vocabularyHasTheReferenceSize() {
        #expect(MaiaMoveTable.vocabularySize == 4352)
    }

    @Test func pairIndexFollowsRankMajorNumbering() {
        // e2 = 12, e4 = 28 dans python-chess → 12 × 64 + 28.
        #expect(MaiaMoveTable.index(from: Square("e2"), to: Square("e4"), promotion: nil, mirror: false) == 796)
        // Le même coup vu des Noirs (e7e5 réel) se renverse en e2e4.
        #expect(MaiaMoveTable.index(from: Square("e7"), to: Square("e5"), promotion: nil, mirror: true) == 796)
    }

    @Test func promotionIndexFollowsFilePairs() {
        // a7a8q = 4096 + (0 × 8 + 0) × 4 + 0 ; h7g8n = 4096 + (7 × 8 + 6) × 4 + 3.
        #expect(MaiaMoveTable.index(from: Square("a7"), to: Square("a8"), promotion: .queen, mirror: false) == 4096)
        #expect(MaiaMoveTable.index(from: Square("h7"), to: Square("g8"), promotion: .knight, mirror: false) == 4096 + 62 * 4 + 3)
        // Promotion noire réelle (a2a1r) → a7a8r après renversement.
        #expect(MaiaMoveTable.index(from: Square("a2"), to: Square("a1"), promotion: .rook, mirror: true) == 4097)
        // Une « promotion » qui ne part pas de la 7e est refusée.
        #expect(MaiaMoveTable.index(from: Square("a6"), to: Square("a7"), promotion: .queen, mirror: false) == nil)
    }
}

@Suite(.enabled(if: MaiaFixtures.file != nil, "Fixtures_maia3.json absent du bundle de tests"))
struct MaiaEncoderFixtureTests {

    @Test func fixturesAreLoaded() {
        #expect(MaiaFixtures.cases.count >= 50)
        #expect(MaiaFixtures.file?.history == MaiaEncoder.historyLength)
    }

    @Test func tokensMatchTheReferenceBitForBit() throws {
        for fixture in MaiaFixtures.cases {
            let replayed = try #require(MaiaFixtures.replay(fixture), "rejeu impossible : \(fixture.label)")
            let tensor = MaiaEncoder.tokens(history: replayed.history)
            for square in 0..<64 {
                let row = MaiaEncoder.hexRow(tensor, square: square)
                #expect(row == fixture.tokens[square], "case \(square) de \(fixture.label)")
            }
        }
    }

    @Test func legalMoveCountsMatchTheReferenceMask() throws {
        for fixture in MaiaFixtures.cases {
            let replayed = try #require(MaiaFixtures.replay(fixture))
            let legal = MaiaLegalMoves.moves(in: replayed.board)
            #expect(legal.count == fixture.legalCount, "\(fixture.label)")
            // Aucun doublon d'indice : deux coups légaux ne partagent jamais
            // une case du vocabulaire.
            #expect(Set(legal.map(\.index)).count == legal.count, "\(fixture.label)")
            let ucis = Set(legal.map(\.uci))
            for top in fixture.top {
                #expect(ucis.contains(top.uci), "\(top.uci) attendu légal dans \(fixture.label)")
            }
        }
    }
}

@Suite(.serialized, .enabled(if: MaiaFixtures.file != nil, "Fixtures_maia3.json absent du bundle de tests"))
struct MaiaModelFixtureTests {

    /// fp16 côté Core ML contre fp32 côté référence : les probabilités
    /// s'écartent de quelques centièmes au plus (0,0034 mesuré sur le 5M,
    /// 0,027 sur le 23M, dont les couches plus larges accumulent davantage
    /// en fp16), et deux coups quasi ex æquo peuvent s'inverser.
    private static let probabilityTolerance = 0.04
    private static let tieTolerance = 0.05

    @Test func coreMLMatchesTheReferenceDistribution() async throws {
        let model = try #require(MaiaModel(bundle: .main), "\(MaiaModel.modelResourceName) absent du bundle de l'app")
        var swaps = 0
        for fixture in MaiaFixtures.cases {
            let replayed = try #require(MaiaFixtures.replay(fixture))
            let tokens = MaiaEncoder.tokens(history: replayed.history)
            let prediction = try await model.predict(
                tokens: tokens, selfElo: Double(fixture.selfElo), oppoElo: Double(fixture.oppoElo)
            )
            let legal = MaiaLegalMoves.moves(in: replayed.board)
            let candidates = MaiaPolicy.candidates(logits: prediction.moveLogits, legal: legal)
            let byUCI = Dictionary(uniqueKeysWithValues: candidates.map { ($0.move.uci, $0.probability) })

            for top in fixture.top {
                let probability = try #require(byUCI[top.uci], "\(top.uci) absent dans \(fixture.label)")
                #expect(abs(probability - top.p) < Self.probabilityTolerance,
                        "\(top.uci) : \(probability) vs \(top.p) dans \(fixture.label)")
            }

            let expectedFirst = fixture.top[0]
            let actualFirst = try #require(candidates.first)
            if actualFirst.move.uci != expectedFirst.uci {
                let nearTie = fixture.top.count > 1 && expectedFirst.p - fixture.top[1].p < Self.tieTolerance
                    && actualFirst.move.uci == fixture.top[1].uci
                #expect(nearTie, "top-1 \(actualFirst.move.uci) ≠ \(expectedFirst.uci) dans \(fixture.label)")
                swaps += 1
            }

            #expect(abs(prediction.win - fixture.wdl[0]) < Self.probabilityTolerance, "gain, \(fixture.label)")
            #expect(abs(prediction.draw - fixture.wdl[1]) < Self.probabilityTolerance, "nulle, \(fixture.label)")
            #expect(abs(prediction.loss - fixture.wdl[2]) < Self.probabilityTolerance, "défaite, \(fixture.label)")
        }
        // Quelques inversions de quasi ex æquo sont normales ; une avalanche
        // signalerait un modèle mal converti.
        #expect(swaps <= 3, "\(swaps) inversions de top-1")
    }

    @Test func samplingRespectsTemperatureAndTopP() async throws {
        let model = try #require(MaiaModel(bundle: .main))
        let fixture = try #require(MaiaFixtures.cases.first)
        let replayed = try #require(MaiaFixtures.replay(fixture))
        let prediction = try await model.predict(tokens: MaiaEncoder.tokens(history: replayed.history), selfElo: 1500, oppoElo: 1500)
        let candidates = MaiaPolicy.candidates(logits: prediction.moveLogits, legal: MaiaLegalMoves.moves(in: replayed.board))

        var generator = SystemRandomNumberGenerator()
        // Température nulle : toujours le premier.
        for _ in 0..<20 {
            #expect(MaiaPolicy.sample(candidates, temperature: 0, using: &generator)?.move == candidates[0].move)
        }
        // Top-p très serré : jamais au-delà des premiers coups.
        let head = Set(candidates.prefix(2).map(\.move))
        for _ in 0..<50 {
            let pick = try #require(MaiaPolicy.sample(candidates, temperature: 1, topP: 0.5, using: &generator))
            #expect(head.contains(pick.move))
        }
    }
}

private extension MaiaEncoder {
    /// Les 96 bits d'historique d'une case, en hexadécimal (24 caractères,
    /// colonne 0 en poids fort) — le format des fixtures de référence.
    static func hexRow(_ tensor: [Float], square: Int) -> String {
        var hex = ""
        let base = square * featuresPerSquare
        for nibble in 0..<24 {
            var value = 0
            for bit in 0..<4 {
                value = value << 1 | (tensor[base + nibble * 4 + bit] > 0.5 ? 1 : 0)
            }
            hex += String(value, radix: 16)
        }
        return hex
    }
}
