@preconcurrency import AVFoundation
import Foundation
import Speech

/// Les reconnaissances de la parole, toutes SUR L'APPAREIL — celles retenues par la mesure du 19/11/2026 (51 essais) :
/// le transcripteur d'iOS 26 (le meilleur, « D »), sinon la reconnaissance classique avec les coups légaux en indices
/// (« B »). Le vocabulaire appris (« C », « E ») n'apportait rien : écarté.
enum VoiceRecognizers {
    /// La langue de reconnaissance d'une langue de l'app.
    static func locale(for language: String) -> Locale {
        switch language.prefix(2) {
        case "en": Locale(identifier: "en-US")
        case "es": Locale(identifier: "es-ES")
        case "de": Locale(identifier: "de-DE")
        case "it": Locale(identifier: "it-IT")
        default: Locale(identifier: "fr-FR")
        }
    }

    enum Availability: Equatable, Sendable {
        /// `precise` : le transcripteur d'iOS 26 ; sinon la reconnaissance classique.
        case available(precise: Bool)
        /// Aucune reconnaissance SUR L'APPAREIL dans cette langue : la fonction ne s'offre pas (jamais de réseau).
        case unavailable
    }

    static func availability(language: String) async -> Availability {
        let locale = locale(for: language)
        if #available(iOS 26, *), await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil {
            return .available(precise: true)
        }
        if SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition == true { return .available(precise: false) }
        return .unavailable
    }

    /// Le transcripteur d'iOS 26 a besoin de son modèle de langue, que le SYSTÈME télécharge une fois (comme une voix).
    static func prepare(language: String) async {
        guard #available(iOS 26, *) else { return }
        let transcriber = SpeechTranscriber(locale: locale(for: language), preset: .transcriptionWithAlternatives)
        if let request = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try? await request.downloadAndInstall()
        }
    }

    /// Les transcriptions d'un enregistrement (la meilleure d'abord), par la meilleure reconnaissance disponible.
    static func transcripts(of url: URL, language: String, hints: [String]) async -> [String] {
        let locale = locale(for: language)
        if #available(iOS 26, *), await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil {
            let heard = await transcriber(url: url, locale: locale, hints: hints)
            if !heard.isEmpty { return heard }
        }
        return await classic(url: url, locale: locale, hints: hints, model: nil)
    }

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func claim() -> Bool { lock.withLock { defer { done = true }; return !done } }
    }

    /// Reconnaissance classique, HORS LIGNE obligatoire (`requiresOnDeviceRecognition`).
    nonisolated static func classic(url: URL, locale: Locale, hints: [String]?,
                                    model: SFSpeechLanguageModel.Configuration?) async -> [String] {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else { return [] }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = false
        if let hints { request.contextualStrings = hints }
        if let model { request.customizedLanguageModel = model }
        let once = Once()
        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    if once.claim() { continuation.resume(returning: result.transcriptions.map(\.formattedString)) }
                } else if error != nil {
                    if once.claim() { continuation.resume(returning: []) }
                }
            }
        }
    }

    @available(iOS 26, *)
    nonisolated static func transcriber(url: URL, locale: Locale, hints: [String]) async -> [String] {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcriptionWithAlternatives)
        let context = AnalysisContext()
        context.contextualStrings[.general] = hints
        return await run(module: transcriber, results: transcriber.results, url: url, context: context) { result in
            [String(result.text.characters)] + result.alternatives.map { String($0.characters) }
        }
    }

    /// Fait passer un fichier dans un module d'iOS 26. Une phrase courte donne d'ordinaire UN résultat final ; s'il y
    /// en a plusieurs, on garde leur texte mis bout à bout.
    @available(iOS 26, *)
    nonisolated static func run<Results: AsyncSequence & Sendable>(
        module: any SpeechModule, results: Results, url: URL, context: AnalysisContext,
        texts: @escaping @Sendable (Results.Element) -> [String]
    ) async -> [String] where Results.Element: SpeechModuleResult {
        do {
            let analyzer = SpeechAnalyzer(modules: [module])
            try await analyzer.setContext(context)
            let collector = Task { () -> [[String]] in
                var segments: [[String]] = []
                for try await result in results where result.isFinal { segments.append(texts(result)) }
                return segments
            }
            let file = try AVAudioFile(forReading: url)
            if let end = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: end)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            let segments = try await collector.value
            if segments.count == 1 { return segments[0] }
            return [segments.compactMap(\.first).joined(separator: " ")]
        } catch {
            return []
        }
    }
}

/// Découpe le flux du micro en PHRASES : un début quand le son monte nettement au-dessus du bruit de fond, une fin
/// après 0,7 s de silence. Tourne sur le fil audio (le rappel du micro) : tout est protégé par un verrou.
/// Une phrase entendue : des copies de tampons que plus personne ne modifie — on peut la confier à un autre fil.
struct Utterance: @unchecked Sendable {
    let buffers: [AVAudioPCMBuffer]
}

final class UtteranceDetector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffers: [AVAudioPCMBuffer] = []
    private var preRoll: [AVAudioPCMBuffer] = []
    private var noiseFloor: Float = -55
    private var loudRun = 0
    private var inSpeech = false
    private var speechSeconds: Double = 0
    private var silenceSeconds: Double = 0
    private var totalSeconds: Double = 0
    private var enabled = false

    /// Une phrase complète, rendue sur le fil audio : à l'appelant de la confier au fil principal.
    var onUtterance: (@Sendable (Utterance) -> Void)?

    static let endSilence: Double = 0.7
    static let minimumSpeech: Double = 0.35
    static let maximumLength: Double = 6
    static let preRollSeconds: Double = 0.3

    func setEnabled(_ on: Bool) {
        lock.withLock {
            enabled = on
            reset()
        }
    }

    private func reset() {
        buffers = []
        preRoll = []
        inSpeech = false
        loudRun = 0
        speechSeconds = 0
        silenceSeconds = 0
        totalSeconds = 0
    }

    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return -120 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += channel[index] * channel[index] }
        let rms = sqrt(sum / Float(buffer.frameLength))
        return 20 * log10(max(rms, 1e-7))
    }

    func ingest(_ buffer: AVAudioPCMBuffer) {
        let seconds = Double(buffer.frameLength) / buffer.format.sampleRate
        let level = Self.level(of: buffer)
        var finished: [AVAudioPCMBuffer]?
        lock.withLock {
            guard enabled, let copy = Self.copy(buffer) else { return }
            if !inSpeech {
                // Le bruit de fond suit lentement ce qu'on entend hors parole.
                noiseFloor = noiseFloor * 0.95 + min(level, noiseFloor + 6) * 0.05
                preRoll.append(copy)
                let maxPreRoll = Int((Self.preRollSeconds / seconds).rounded(.up))
                if preRoll.count > maxPreRoll { preRoll.removeFirst(preRoll.count - maxPreRoll) }
                loudRun = level > max(noiseFloor + 12, -50) ? loudRun + 1 : 0
                if loudRun >= 2 {
                    inSpeech = true
                    buffers = preRoll
                    preRoll = []
                    speechSeconds = 0
                    silenceSeconds = 0
                    totalSeconds = 0
                }
                return
            }
            buffers.append(copy)
            totalSeconds += seconds
            if level > noiseFloor + 6 {
                speechSeconds += seconds
                silenceSeconds = 0
            } else {
                silenceSeconds += seconds
            }
            if silenceSeconds >= Self.endSilence || totalSeconds >= Self.maximumLength {
                // Un bruit bref (le son d'un coup, une porte) n'est pas une phrase.
                if speechSeconds >= Self.minimumSpeech { finished = buffers }
                reset()
            }
        }
        if let finished { onUtterance?(Utterance(buffers: finished)) }
    }

    private static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return nil }
        copy.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        if let source = buffer.floatChannelData, let target = copy.floatChannelData {
            for channel in 0..<channels {
                target[channel].update(from: source[channel], count: Int(buffer.frameLength))
            }
        }
        return copy
    }
}

/// L'ÉCOUTE À MON TOUR (décision du 19/11/2026) : le micro s'ouvre seul quand c'est au joueur de jouer et que l'app
/// ne parle pas ; chaque phrase entendue est reconnue SUR L'APPAREIL et rendue en transcriptions. Rien n'est gardé :
/// la phrase vit dans un fichier temporaire le temps de la reconnaître, puis il est effacé.
@MainActor
@Observable
final class VoiceMoveListener {
    enum Status: Equatable {
        case starting
        /// Le micro est prêt et attend une phrase.
        case listening
        /// Une phrase vient d'être entendue, la reconnaissance tourne.
        case recognizing
        /// Ce n'est pas au joueur (ou l'app parle) : le micro n'écoute pas.
        case waiting
        /// Mise en pause par le joueur (une conversation autour de la table).
        case paused
        case denied
        case unavailable
    }

    /// Vrai tant que le micro tourne : la voix de l'app et ses sons ne doivent pas rendre la session audio ambiante.
    static private(set) var isCapturing = false

    private(set) var status: Status = .starting
    var isPaused = false {
        didSet { refresh() }
    }

    private let language: String
    private let engine = AVAudioEngine()
    private let detector = UtteranceDetector()
    private var wantsToListen = false
    private var hints: [String] = []
    private var running = false
    private var recognizing = false
    private var watchVoice: Task<Void, Never>?
    /// Les transcriptions d'une phrase, à confronter à la position.
    var onTranscripts: (([String]) -> Void)?

    init(language: String = LocalizationController.activeLanguageCode) {
        self.language = language
    }

    /// Micro et reconnaissance vocale : demandés en allumant le réglage, revérifiés à l'ouverture de la partie.
    static func requestPermissions() async -> Bool {
        let speech = await requestSpeechAuthorization()
        let microphone = await AVAudioApplication.requestRecordPermission()
        return speech == .authorized && microphone
    }

    /// Autorisations, modèle de langue, micro. Appelé une fois, à l'ouverture de la partie.
    func start() async {
        guard !running else { return }
        guard await Self.requestPermissions() else { status = .denied; return }
        guard case .available = await VoiceRecognizers.availability(language: language) else {
            status = .unavailable
            return
        }
        await VoiceRecognizers.prepare(language: language)

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try session.setActive(true)
        } catch {
            status = .unavailable
            return
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { status = .unavailable; return }
        let detector = detector
        detector.onUtterance = { [weak self] utterance in
            Task { @MainActor in await self?.recognize(utterance) }
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in detector.ingest(buffer) }
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            status = .unavailable
            return
        }
        running = true
        Self.isCapturing = true
        // La voix de l'app (coup adverse, « coup impossible ») ne doit pas s'entendre elle-même.
        watchVoice = Task { [weak self] in
            var wasSpeaking = false
            while !Task.isCancelled {
                let speaking = BlindfoldVoice.shared.isSpeaking
                if speaking != wasSpeaking {
                    wasSpeaking = speaking
                    self?.refresh()
                }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        refresh()
    }

    func stop() {
        watchVoice?.cancel()
        detector.setEnabled(false)
        if running {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            running = false
        }
        Self.isCapturing = false
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    /// C'est au joueur de jouer (ou plus) ; `hints` : les façons de dire les coups légaux, pour la reconnaissance.
    func setTurn(isMine: Bool, hints: [String]) {
        wantsToListen = isMine
        self.hints = hints
        refresh()
    }

    private func refresh() {
        guard running else { return }
        let listening = wantsToListen && !isPaused && !recognizing && !BlindfoldVoice.shared.isSpeaking
        detector.setEnabled(listening)
        status = isPaused ? .paused : recognizing ? .recognizing : listening ? .listening : .waiting
    }

    private func recognize(_ utterance: Utterance) async {
        let buffers = utterance.buffers
        guard let format = buffers.first?.format else { return }
        guard running, wantsToListen, !isPaused else { return }
        recognizing = true
        refresh()
        let url = FileManager.default.temporaryDirectory.appending(path: "voice-move-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            for buffer in buffers { try file.write(from: buffer) }
        } catch {
            recognizing = false
            refresh()
            return
        }
        let transcripts = await VoiceRecognizers.transcripts(of: url, language: language, hints: hints)
        recognizing = false
        if !transcripts.isEmpty { onTranscripts?(transcripts) }
        refresh()
    }

    /// HORS de l'acteur principal : iOS rappelle sur une file d'arrière-plan (plantage du 19/11 sinon).
    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }
}
