#if DEBUG
import ChessKit
import Foundation
import UIKit

/// BANC DE VOIX SYNTHÉTIQUES (21/11/2026) — DÉBOGAGE SEULEMENT. Pendant de `VoiceSynthBatchActivity` (Android) : fait
/// passer par la reconnaissance SUR L'APPAREIL (celle que l'app choisit : transcripteur d'iOS 26, sinon la classique)
/// des enregistrements fabriqués par `tools/voix-synthese/generer.py`, avec les mêmes indices que le jeu, et écrit ce que
/// le moteur a entendu. Les tests `SynthEvalTests` le comparent ensuite au coup attendu.
///
/// Entrée : `Documents/synth/index.jsonl` + `Documents/synth/wav/<id>.wav`. Sortie : `Documents/synth/out.jsonl`, une ligne
/// par enregistrement, puis le fichier `done`. Lancé avec l'argument `-synthBench` (voir `tools/voix-synthese/mesurer-ios.sh`) ;
/// l'iPhone doit être DÉVERROUILLÉ (la reconnaissance veut l'app au premier plan).
enum VoiceSynthBench {
    static var isRequested: Bool { CommandLine.arguments.contains("-synthBench") }

    @MainActor static func keepAwake() { UIApplication.shared.isIdleTimerDisabled = true }

    static func run() async {
        // Une série dure une demi-heure sans qu'on touche l'écran : sans cela l'iPhone s'endort et la reconnaissance se fige.
        await keepAwake()
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appending(path: "synth")
        let outURL = dir.appending(path: "out.jsonl")
        try? FileManager.default.removeItem(at: dir.appending(path: "done"))
        FileManager.default.createFile(atPath: outURL.path, contents: Data())
        guard await VoiceMoveListener.requestPermissions(),
              let text = try? String(contentsOf: dir.appending(path: "index.jsonl"), encoding: .utf8),
              let handle = try? FileHandle(forWritingTo: outURL) else {
            try? "refusé".write(to: dir.appending(path: "done"), atomically: true, encoding: .utf8)
            return
        }
        defer { try? handle.close() }
        let rows = text.split(separator: "\n").compactMap { line -> [String: Any]? in
            (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
        }
        // Les modèles des langues du banc : ce que fait l'app à l'allumage du réglage (téléchargement du transcripteur d'iOS 26).
        for language in Set(rows.compactMap { $0["lang"] as? String }).sorted() { await VoiceRecognizers.prepare(language: language) }
        for (position, row) in rows.enumerated() {
            guard let id = row["id"] as? String, let language = row["lang"] as? String, let fen = row["fen"] as? String else { continue }
            let vocabulary = VoiceMoveParser.vocabulary(for: language)
            var hints: [String] = []
            if let pos = Position(fen: fen) {
                hints = VoiceMoveParser.spokenForms(of: VoiceMoveParser.candidates(in: Board(position: pos)), vocabulary: vocabulary)
            }
            let url = dir.appending(path: "wav/\(id).wav")
            let heard = await VoiceRecognizers.transcripts(of: url, language: language, hints: hints)
            let line: [String: Any] = ["id": id, "transcripts": heard.transcripts,
                                       "error": heard.transcripts.isEmpty ? (heard.dictationOff ? "dictée coupée" : "rien") : NSNull()]
            if let data = try? JSONSerialization.data(withJSONObject: line), let newline = "\n".data(using: .utf8) {
                handle.write(data); handle.write(newline)
            }
            print("[synth] \(position + 1)/\(rows.count) \(language) → \(heard.transcripts.first ?? "—")")
        }
        try? "ok".write(to: dir.appending(path: "done"), atomically: true, encoding: .utf8)
    }
}
#endif
