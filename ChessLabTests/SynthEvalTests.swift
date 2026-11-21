import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Évalue un banc de voix synthétiques (21/11/2026) : ce que la reconnaissance de l'iPhone a écrit (`out.jsonl`, rendu par
/// `VoiceSynthBench`) passe par le lecteur de coups ACTUEL et se compare au coup attendu (`index.jsonl`). Pendant de
/// `SynthEvalTest` (Android). Ne fait rien sans le dossier : `TEST_RUNNER_SYNTH_DIR=<dossier> xcodebuild test …`.
/// Écrit `rapport-ios.txt` dans ce dossier.
@Suite struct SynthEvalTests {
    @Test func rapport() throws {
        guard let path = ProcessInfo.processInfo.environment["SYNTH_DIR"],
              FileManager.default.fileExists(atPath: path + "/out-ios.jsonl") else { return }
        func rows(_ name: String) throws -> [[String: Any]] {
            try String(contentsOfFile: path + "/" + name, encoding: .utf8).split(separator: "\n").compactMap {
                (try? JSONSerialization.jsonObject(with: Data($0.utf8))) as? [String: Any]
            }
        }
        var meta: [String: [String: Any]] = [:]
        for row in try rows("index.jsonl") { if let id = row["id"] as? String { meta[id] = row } }

        struct Row { let lang: String, voice: String, text: String, ok: Bool, verdict: String, heard: [String], error: String? }
        var all: [Row] = []
        for r in try rows("out-ios.jsonl") {
            guard let id = r["id"] as? String, let m = meta[id], let lang = m["lang"] as? String,
                  let expected = m["expected"] as? String, let fen = m["fen"] as? String else { continue }
            let heard = (r["transcripts"] as? [String]) ?? []
            let vocabulary = VoiceMoveParser.vocabulary(for: lang)
            var ok = false
            var verdict = ""
            if expected == "undo" {
                ok = heard.contains { VoiceMoveParser.isUndo($0, vocabulary: vocabulary) }
                verdict = ok ? "annule" : "rien"
            } else if let position = Position(fen: fen) {
                let legal = VoiceMoveParser.candidates(in: Board(position: position))
                switch VoiceMoveParser.resolve(transcripts: heard, among: legal, vocabulary: vocabulary) {
                case .move(let c): ok = c.uci == expected; verdict = "joue \(c.uci)"
                case .conflicting: verdict = "hésite"
                case .ambiguous: verdict = "ambigu"
                case .illegal: verdict = "impossible"
                case .notUnderstood: verdict = "incompris"
                }
            }
            let voice = ((m["voice"] as? String) ?? "").components(separatedBy: " (").first ?? ""
            all.append(Row(lang: lang, voice: voice, text: (m["text"] as? String) ?? "", ok: ok, verdict: verdict,
                           heard: heard, error: r["error"] as? String))
        }
        var report = "RAPPORT iOS — \(all.count) enregistrements\n"
        for lang in Set(all.map(\.lang)).sorted() {
            let group = all.filter { $0.lang == lang }
            report += "\n== \(lang) : \(group.filter(\.ok).count) / \(group.count)\n"
            for voice in Set(group.map(\.voice)).sorted() {
                let g = group.filter { $0.voice == voice }
                report += "   \(voice) : \(g.filter(\.ok).count) / \(g.count)\n"
            }
            for text in Set(group.map(\.text)).sorted() {
                let g = group.filter { $0.text == text }
                guard g.contains(where: { !$0.ok }) else { continue }
                report += "   « \(text) » : \(g.filter(\.ok).count) / \(g.count)\n"
                for f in g where !f.ok {
                    report += "        \(f.voice) → \(f.verdict) ← \(f.heard.prefix(3))\(f.error.map { " (\($0))" } ?? "")\n"
                }
            }
        }
        try report.write(toFile: path + "/rapport-ios.txt", atomically: true, encoding: .utf8)
    }
}
