import XCTest
@testable import CStockfishKit

/// Fume-test du moteur vendorisé : un vrai cycle UCI de bout en bout.
/// Les réseaux NNUE sont cherchés dans le dossier `ChessLab/Resources` du
/// dépôt (dérivé de `#filePath`), là où l'app les livre.
final class EngineSmokeTests: XCTestCase {

    /// Jalons UCI observés, protégés par un verrou : la tâche lectrice écrit,
    /// le fil de test lit (Swift 6 interdit de partager des `var` locales).
    private final class Milestones: @unchecked Sendable {
        private let lock = NSLock()
        private var _uciOk = false
        private var _readyOk = false
        private var _bestMove: String?

        func note(_ line: String) {
            lock.lock(); defer { lock.unlock() }
            if line == "uciok" { _uciOk = true }
            if line == "readyok" { _readyOk = true }
            if line.hasPrefix("bestmove") { _bestMove = line }
        }
        var uciOk: Bool { lock.lock(); defer { lock.unlock() }; return _uciOk }
        var readyOk: Bool { lock.lock(); defer { lock.unlock() }; return _readyOk }
        var bestMove: String? { lock.lock(); defer { lock.unlock() }; return _bestMove }
    }

    /// Dossier des ressources de l'app (contient nn-*.nnue), depuis ce fichier.
    private var resourcesDir: String {
        // .../Vendor/CStockfish/Tests/CStockfishKitTests/EngineSmokeTests.swift
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() } // → racine du dépôt
        return url.appendingPathComponent("ChessLab/Resources").path
    }

    func testFullUCICycleProducesABestMove() async throws {
        let netExists = FileManager.default.fileExists(
            atPath: resourcesDir + "/nn-1c0000000000.nnue"
        )
        try XCTSkipUnless(netExists, "Réseau NNUE introuvable dans \(resourcesDir)")

        let engine = StockfishEngine()
        engine.start(binaryPath: resourcesDir + "/stockfish")
        defer { engine.stop() }

        let milestones = Milestones()
        let reader = Task {
            for await line in engine.lines {
                milestones.note(line)
                if line.hasPrefix("bestmove") { break }
            }
        }

        engine.send("uci")
        try await waitUntil(timeout: 10) { milestones.uciOk }
        XCTAssertTrue(milestones.uciOk, "uciok jamais reçu")

        engine.send("isready")
        try await waitUntil(timeout: 20) { milestones.readyOk } // chargement du net de 78 Mo
        XCTAssertTrue(milestones.readyOk, "readyok jamais reçu")

        engine.send("position startpos")
        engine.send("go depth 10")
        try await waitUntil(timeout: 30) { milestones.bestMove != nil }
        reader.cancel()

        let move = try XCTUnwrap(milestones.bestMove, "bestmove jamais reçu")
        // Format « bestmove e2e4 [ponder …] » : un coup LAN plausible.
        let token = move.split(separator: " ").dropFirst().first.map(String.init)
        XCTAssertNotNil(token)
        XCTAssertGreaterThanOrEqual(token?.count ?? 0, 4, "coup LAN attendu, reçu \(move)")
    }

    /// Attend qu'une condition devienne vraie, en sondant, borné par `timeout`.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
