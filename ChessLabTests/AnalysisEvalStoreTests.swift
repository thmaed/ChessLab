import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Le cache d'analyses persistées : ce que le moteur a calculé une fois ne se
/// recalcule plus (demande du 17/08).
struct AnalysisEvalStoreTests {

    private func makeGame(headers: String = "") throws -> Game {
        let pgn = headers + "\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 *"
        return try #require(PGNLoader.game(from: pgn))
    }

    @Test func theKeyIsTheGameNotItsText() throws {
        let bare = try makeGame()
        let dressed = try makeGame(headers: "[Event \"Club\"]\n[White \"Nils\"]\n[Black \"Thierry\"]\n[Result \"*\"]\n")
        let other = try #require(PGNLoader.game(from: "1. d4 d5 *"))

        let key1 = try #require(AnalysisEvalStore.key(for: bare))
        let key2 = try #require(AnalysisEvalStore.key(for: dressed))
        let key3 = try #require(AnalysisEvalStore.key(for: other))

        #expect(key1 == key2, "mêmes coups, autres en-têtes : même analyse")
        #expect(key1 != key3, "autre partie, autre clé")
    }

    @Test func aSnapshotRoundTripsThroughDisk() throws {
        let key = "test-roundtrip-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(at: AnalysisEvalStore.fileURL(for: key)) }

        var snapshot = AnalysisEvalStore.Snapshot()
        snapshot.evals[0] = .init(winPercent: 52, pawns: 0.3, bestLan: "e2e4",
                                  gapToSecondBest: 1.5, secondBestLan: "d2d4", pv: ["e2e4", "e7e5"])
        snapshot.verdicts[1] = .init(
            winPercentAfterMover: 43, quality: MoveQuality.blunder.rawValue,
            explanation: .init(
                motif: AnalysisEvalStore.motifDTO(.fork(by: .knight, on: Square("d5"), targets: [.queen, .rook])),
                materialLoss: 5, refutationSAN: "Nd5"
            )
        )
        AnalysisEvalStore.save(snapshot, key: key)

        let loaded = try #require(AnalysisEvalStore.load(key: key))
        #expect(loaded.evals[0]?.bestLan == "e2e4")
        #expect(loaded.evals[0]?.pv == ["e2e4", "e7e5"])
        #expect(loaded.verdicts[1]?.quality == MoveQuality.blunder.rawValue)
        let motif = AnalysisEvalStore.motif(from: loaded.verdicts[1]?.explanation?.motif)
        #expect(motif == .fork(by: .knight, on: Square("d5"), targets: [.queen, .rook]))
    }

    /// Changer de moteur ou de barème invalide le cache : mieux vaut
    /// réanalyser que mélanger deux vérités.
    @Test func aForeignProfileInvalidatesTheSnapshot() throws {
        let key = "test-profile-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(at: AnalysisEvalStore.fileURL(for: key)) }

        var snapshot = AnalysisEvalStore.Snapshot()
        snapshot.profile = "SF99/autre-monde"
        snapshot.evals[0] = .init(winPercent: 50, pawns: 0)
        AnalysisEvalStore.save(snapshot, key: key)

        #expect(AnalysisEvalStore.load(key: key) == nil)
    }

    @Test func everyMotifSurvivesTheBridge() {
        let motifs: [TacticalMotif] = [
            .checkmate(inMoves: 2, isBackRank: true),
            .hangingPiece(kind: .queen, on: Square("h5")),
            .fork(by: .knight, on: Square("c7"), targets: [.king, .rook]),
            .discoveredCheck(by: .bishop),
            .pin(victim: .knight, behind: .queen),
        ]
        for motif in motifs {
            let bridged = AnalysisEvalStore.motif(from: AnalysisEvalStore.motifDTO(motif))
            #expect(bridged == motif, "\(motif)")
        }
    }
}
