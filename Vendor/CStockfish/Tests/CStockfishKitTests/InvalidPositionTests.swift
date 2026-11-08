import CStockfishKit
import XCTest

/// Stockfish 19 quittait le PROCESS sur une commande `position` invalide — donc l'app entière.
/// Constaté le 08/11/2026 : une partie dont les promotions avaient été oubliées laissait un pion
/// sur la première rangée. Le moteur embarqué doit répondre sans mourir.
final class InvalidPositionTests: XCTestCase {

    private var resourcesDir: String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        return url.appendingPathComponent("ChessLab/Resources").path
    }

    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private var all: [String] = []
        func add(_ line: String) { lock.lock(); all.append(line); lock.unlock() }
        func count(prefix: String) -> Int { lock.lock(); defer { lock.unlock() }; return all.filter { $0.hasPrefix(prefix) }.count }
        func lines() -> [String] { lock.lock(); defer { lock.unlock() }; return all }
    }

    private func wait(timeout: TimeInterval, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
    }

    func testAnInvalidPositionNeverKillsTheEngine() async throws {
        let nets = (try? FileManager.default.contentsOfDirectory(atPath: resourcesDir)) ?? []
        try XCTSkipUnless(nets.contains { $0.hasPrefix("nn-") }, "Réseau NNUE introuvable")

        let engine = StockfishEngine()
        engine.start(binaryPath: resourcesDir + "/stockfish")
        defer { engine.stop() }
        let collector = Collector()
        let reader = Task { for await line in engine.lines { collector.add(line) } }
        defer { reader.cancel() }

        engine.send("uci"); engine.send("isready")
        try await wait(timeout: 20) { collector.count(prefix: "readyok") >= 1 }

        // Un pion noir sur la première rangée (g1) : refusé par Stockfish 19.
        engine.send("position fen 8/7R/2p5/3p4/4p1k1/2Pb1r2/3K4/6p1 w - - 0 49")
        engine.send("go depth 1")
        try await wait(timeout: 10) { collector.count(prefix: "bestmove") >= 1 }
        XCTAssertTrue(collector.lines().contains { $0.hasPrefix("info string ERROR") }, "l'erreur doit être dite")
        XCTAssertTrue(collector.lines().contains("bestmove (none)"), "aucune recherche sur une position refusée")

        // Un coup illégal dans la liste : même traitement.
        engine.send("position startpos moves e2e5")
        engine.send("go depth 1")
        try await wait(timeout: 10) { collector.count(prefix: "bestmove") >= 2 }
        XCTAssertEqual(collector.lines().filter { $0 == "bestmove (none)" }.count, 2)

        // Le moteur est TOUJOURS vivant : une position valide donne un vrai coup.
        engine.send("position startpos")
        engine.send("go depth 8")
        try await wait(timeout: 30) { collector.count(prefix: "bestmove") >= 3 }
        let real = collector.lines().last { $0.hasPrefix("bestmove") } ?? ""
        XCTAssertTrue(real.hasPrefix("bestmove ") && real != "bestmove (none)", "le moteur doit rejouer : \(real)")
    }
}
