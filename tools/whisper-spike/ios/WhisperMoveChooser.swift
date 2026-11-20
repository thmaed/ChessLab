#if DEBUG
import AVFoundation
import CoreML
import Foundation

/// ÉTUDE (19/11/2026, debug seulement) : Whisper base embarqué, en CHOIX parmi les coups légaux. Au lieu de
/// transcrire, on demande à Whisper la probabilité de chaque façon de dire chaque coup légal, sachant le son, et le
/// mieux noté gagne. Sur le Mac (`tools/whisper-spike`), 48/51 sur les essais d'iPhone3 contre 36-42 pour Apple.
///
/// Les modèles (`convertir.py`) ne sont PAS dans l'app : copiés à la main dans Documents/whisper
/// (`WhisperAudio.mlpackage`, `WhisperScorer.mlpackage`, `whisper-pretokens.json`), compilés au premier usage.
final class WhisperMoveChooser: @unchecked Sendable {
    struct Choice: Sendable {
        let move: VoiceMoveParser.Candidate
        /// L'avance de la note du premier sur le second : petite = Whisper hésite.
        let margin: Double
        let form: String
    }

    private static let samples = 480_000
    private static let batch = 32
    private static let length = 16

    private let audio: MLModel
    private let scorer: MLModel
    private let prefix: [Int32]
    private let endOfText: Int32
    private let pieces: [String: [Int32]]

    /// iPhone XS (A12), 20/11/2026 : en `.all`, 0/21 et des notes invalides, alors que le Mac fait 20/21. Pour
    /// trouver la puce fautive : `-whisperUnits cpuOnly|cpuAndGPU|cpuAndNeuralEngine|all` au lancement.
    private static var computeUnitsName: String {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "-whisperUnits"), index + 1 < args.count else { return "all" }
        return args[index + 1]
    }

    private static var computeUnits: MLComputeUnits {
        switch computeUnitsName {
        case "cpuOnly": .cpuOnly
        case "cpuAndGPU": .cpuAndGPU
        case "cpuAndNeuralEngine": .cpuAndNeuralEngine
        default: .all
        }
    }

    static var folder: URL { URL.documentsDirectory.appending(path: "whisper", directoryHint: .isDirectory) }

    /// nil si les modèles n'ont pas été copiés sur l'appareil.
    static func load() async -> WhisperMoveChooser? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.appending(path: "WhisperScorer.mlpackage").path),
              let table = try? Data(contentsOf: folder.appending(path: "whisper-pretokens.json")),
              let json = try? JSONSerialization.jsonObject(with: table) as? [String: Any],
              let prefix = json["prefix"] as? [Int], let eot = json["endoftext"] as? Int,
              let raw = json["pieces"] as? [String: [Int]] else { return nil }
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = computeUnits
            print("[whisper] calcul sur : \(computeUnitsName)")
            let audio = try MLModel(contentsOf: try await compiled("WhisperAudio"), configuration: configuration)
            let scorer = try MLModel(contentsOf: try await compiled("WhisperScorer"), configuration: configuration)
            return WhisperMoveChooser(audio: audio, scorer: scorer, prefix: prefix.map(Int32.init),
                                      endOfText: Int32(eot), pieces: raw.mapValues { $0.map(Int32.init) })
        } catch {
            print("[whisper] chargement : \(error)")
            return nil
        }
    }

    /// Compilé une fois, gardé à côté (Documents/whisper/<nom>-<empreinte>.mlmodelc) ; l'empreinte (taille et date
    /// des poids) change quand on recopie un modèle refait, qui est alors recompilé.
    private static func compiled(_ name: String) async throws -> URL {
        let package = folder.appending(path: "\(name).mlpackage")
        let weights = package.appending(path: "Data/com.apple.CoreML/weights/weight.bin")
        let attributes = try FileManager.default.attributesOfItem(atPath: weights.path)
        let stamp = "\((attributes[.size] as? Int) ?? 0)-\(Int((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0))"
        let target = folder.appending(path: "\(name)-\(stamp).mlmodelc")
        if FileManager.default.fileExists(atPath: target.path) { return target }
        let temporary = try await MLModel.compileModel(at: folder.appending(path: "\(name).mlpackage"))
        try FileManager.default.moveItem(at: temporary, to: target)
        return target
    }

    private init(audio: MLModel, scorer: MLModel, prefix: [Int32], endOfText: Int32, pieces: [String: [Int32]]) {
        self.audio = audio
        self.scorer = scorer
        self.prefix = prefix
        self.endOfText = endOfText
        self.pieces = pieces
    }

    // MARK: Les phrases à noter (les mêmes que `tools/whisper-spike/mesure.py`)

    private static let names: [Character: String] = ["K": "roi", "Q": "dame", "R": "tour", "B": "fou", "N": "cavalier",
                                                      "P": "pion"]

    static func spokenForms(_ c: VoiceMoveParser.Candidate, among all: [VoiceMoveParser.Candidate]) -> [String] {
        if c.isLongCastle { return ["grand roque"] }
        if c.isCastle { return ["petit roque", "roi \(c.to)"] }
        let name = names[c.piece] ?? ""
        var forms = ["\(name) \(c.to)", "\(name) en \(c.to)"]
        if c.san.contains("x") { forms.append("\(name) prend \(c.to)") }
        if c.piece == "P" { forms.append(c.to) }
        if let promotion = c.promotion, let promoted = names[Character(promotion.uppercased())] {
            forms = ["\(c.to) \(promoted)", "\(c.to) promotion \(promoted)", "pion \(c.to) \(promoted)"]
        }
        let twins = all.contains { $0 != c && $0.piece == c.piece && $0.to == c.to && $0.promotion == c.promotion }
        if twins { forms += ["\(name) \(c.from) \(c.to)", "\(name) \(c.from) en \(c.to)"] }
        return forms
    }

    /// Les graphies que Whisper pourrait écrire : « Pion e4 », « Pion e4. », « Pion E4 », « Pion E4. ».
    static func surfaces(_ form: String) -> [String] {
        let capital = form.prefix(1).uppercased() + form.dropFirst()
        let upper = capital.split(separator: " ").map { word -> String in
            word.count == 2 && "abcdefgh".contains(word.first!) && "12345678".contains(word.last!)
                ? word.uppercased() : String(word)
        }.joined(separator: " ")
        return [capital, capital + ".", upper, upper + "."]
    }

    /// Les morceaux du découpage de Whisper (` ?lettres`, ` ?chiffres`, ` ?ponctuation`) — assez pour nos phrases.
    static func pretokens(_ text: String) -> [String] {
        var result: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            var start = index
            var piece = ""
            if text[index] == " ", text.index(after: index) < text.endIndex, text[text.index(after: index)] != " " {
                piece = " "
                start = text.index(after: index)
            }
            let first = text[start]
            let same: (Character) -> Bool = first.isLetter ? { $0.isLetter } : first.isNumber ? { $0.isNumber }
                : { !$0.isLetter && !$0.isNumber && $0 != " " }
            var end = start
            while end < text.endIndex, same(text[end]) { end = text.index(after: end) }
            piece += text[start..<end]
            result.append(piece)
            index = end
        }
        return result
    }

    private func tokens(_ text: String) -> [Int32]? {
        var ids = prefix
        for piece in Self.pretokens(" " + text) {
            guard let part = pieces[piece] else { return nil }
            ids += part
        }
        return ids + [endOfText]
    }

    // MARK: Choisir

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    /// Le temps des deux étapes du dernier choix (écoute, notes), pour la mesure.
    private(set) var lastTimings = ""

    func choose(url: URL, among candidates: [VoiceMoveParser.Candidate]) throws -> Choice? {
        let clock = ContinuousClock.now
        let input = try Self.samples(url)
        let keysValues: MLFeatureProvider
        do {
            keysValues = try audio.prediction(from: MLDictionaryFeatureProvider(dictionary: ["audio": input]))
        } catch {
            throw Failure(description: "écoute (WhisperAudio) : \(error)")
        }
        let heard = ContinuousClock.now - clock
        guard let keys = keysValues.featureValue(for: "keys"), let values = keysValues.featureValue(for: "values") else {
            throw Failure(description: "écoute : pas de clés/valeurs en sortie")
        }
        var invalid = 0
        defer {
            lastTimings = "écoute \(heard), notes \(ContinuousClock.now - clock - heard)"
                + (invalid > 0 ? ", \(invalid) notes invalides" : "")
        }
        var texts: [(owner: Int, form: String, ids: [Int32])] = []
        for (i, c) in candidates.enumerated() {
            for form in Self.spokenForms(c, among: candidates) {
                for text in Self.surfaces(form) {
                    if let ids = tokens(text), ids.count <= Self.length { texts.append((i, form, ids)) }
                }
            }
        }
        var best: [Int: (score: Double, form: String)] = [:]
        for start in stride(from: 0, to: texts.count, by: Self.batch) {
            let chunk = Array(texts[start..<min(start + Self.batch, texts.count)])
            let ids = try MLMultiArray(shape: [NSNumber(value: Self.batch), NSNumber(value: Self.length)], dataType: .int32)
            let idPointer = ids.dataPointer.bindMemory(to: Int32.self, capacity: Self.batch * Self.length)
            for k in 0..<(Self.batch * Self.length) { idPointer[k] = endOfText }
            for (row, item) in chunk.enumerated() {
                for (column, id) in item.ids.enumerated() { idPointer[row * Self.length + column] = id }
            }
            let out: MLFeatureProvider
            do {
                out = try scorer.prediction(from: MLDictionaryFeatureProvider(dictionary: [
                    "tokens": MLFeatureValue(multiArray: ids), "keys": keys, "values": values,
                ]))
            } catch {
                throw Failure(description: "notes (WhisperScorer) : \(error)")
            }
            guard let logprobs = out.featureValue(for: "logprobs")?.multiArrayValue else {
                throw Failure(description: "notes : pas de logprobs en sortie")
            }
            for (row, item) in chunk.enumerated() {
                var sum = 0.0
                for column in (prefix.count - 1)..<(item.ids.count - 1) {
                    sum += logprobs[[NSNumber(value: row), NSNumber(value: column)]].doubleValue
                }
                guard sum.isFinite else { invalid += 1; continue }
                if sum > (best[item.owner]?.score ?? -.infinity) { best[item.owner] = (sum, item.form) }
            }
        }
        let ranked = best.sorted { $0.value.score > $1.value.score }
        guard let first = ranked.first else {
            throw Failure(description: "aucune phrase notée (\(texts.count) formulations tokenisées sur \(candidates.count) coups, \(invalid) notes invalides)")
        }
        let margin = ranked.count > 1 ? first.value.score - ranked[1].value.score : 99
        return Choice(move: candidates[first.key], margin: margin, form: first.value.form)
    }

    /// Le son en 16 kHz mono, complété de silence jusqu'à 30 s (ce que Whisper attend).
    private static func samples(_ url: URL) throws -> MLMultiArray {
        let file = try AVAudioFile(forReading: url)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        let array = try MLMultiArray(shape: [1, NSNumber(value: samples)], dataType: .float32)
        let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: samples)
        pointer.initialize(repeating: 0, count: samples)
        let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: source)
        let converter = AVAudioConverter(from: file.processingFormat, to: format)!
        let capacity = AVAudioFrameCount(Double(source.frameLength) * 16_000 / file.processingFormat.sampleRate) + 1
        let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)!
        var fed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true
            status.pointee = .haveData
            return source
        }
        if let conversionError { throw conversionError }
        let count = min(Int(output.frameLength), samples)
        if let channel = output.floatChannelData?[0] { pointer.update(from: channel, count: count) }
        return array
    }
}
#endif
