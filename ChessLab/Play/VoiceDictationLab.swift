#if DEBUG
import AVFoundation
import ChessKit
import Speech
import SwiftUI

/// MESURE « coups à la voix » (19/11/2026) — Debug seulement, ouverte depuis les Réglages. Rien ici n'entre dans
/// l'app livrée : on mesure d'abord, on décide ensuite (décision de l'utilisateur).
///
/// Chaque essai : une position réelle (puzzles embarqués), un coup légal à dire, maintenir le micro et le dire.
/// L'enregistrement passe par CINQ reconnaissances, toutes SUR L'APPAREIL, puis par ``VoiceMoveParser`` :
/// - A : reconnaissance classique (SFSpeechRecognizer, hors ligne obligatoire) ;
/// - B : A + les façons de dire les coups légaux en indices (`contextualStrings`) ;
/// - C : A + un vocabulaire d'échecs appris sur l'iPhone (modèle de langue personnalisé) ;
/// - D : le transcripteur d'iOS 26 (SpeechTranscriber) avec les mêmes indices ;
/// - E : la dictée d'iOS 26 (DictationTranscriber) avec le vocabulaire d'échecs.
/// Tout est gardé dans Documents/voice-lab (sons + `trials.jsonl`) pour être relu sur le Mac.
@MainActor
@Observable
final class VoiceDictationLab {
    struct EngineResult: Codable, Sendable {
        let engine: String
        let transcripts: [String]
        let outcome: String
        let correct: Bool
        let millis: Int
    }

    struct Trial: Codable, Sendable {
        let id: String
        let date: Date
        let fen: String
        let target: VoiceMoveParser.Candidate
        let candidates: [VoiceMoveParser.Candidate]
        var results: [EngineResult]
    }

    enum Phase { case idle, recording, analysing }

    static let engines = ["A classique", "B indices", "C vocabulaire", "D iOS 26", "E iOS 26 + vocab."]
    nonisolated static let locale = Locale(identifier: "fr-FR")

    private(set) var phase = Phase.idle
    private(set) var fen = ""
    private(set) var candidates: [VoiceMoveParser.Candidate] = []
    private(set) var target: VoiceMoveParser.Candidate?
    private(set) var trials: [Trial] = []
    private(set) var last: Trial?
    private(set) var status = ""
    private(set) var vocabularyStatus = "vocabulaire : en préparation…"

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var languageModel: SFSpeechLanguageModel.Configuration?
    private let puzzles = LichessPuzzleLoader.standard

    static var directory: URL {
        let url = URL.documentsDirectory.appending(path: "voice-lab", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var journal: URL { directory.appending(path: "trials.jsonl") }

    // MARK: Démarrage

    func start() async {
        loadJournal()
        nextPosition()
        let speech = await Self.requestSpeechAuthorization()
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard speech == .authorized, microphone else {
            status = "Autorisations refusées (micro : \(microphone), reconnaissance : \(speech.rawValue))"
            return
        }
        if SFSpeechRecognizer(locale: Self.locale)?.supportsOnDeviceRecognition != true {
            status = "La reconnaissance hors ligne n'est pas disponible en français sur cet appareil."
        }
        await prepareVocabulary()
        if #available(iOS 26, *) { await installModernAssets() }
    }

    /// HORS de l'acteur principal : iOS rappelle sur une file d'arrière-plan, et une fermeture créée dans une méthode
    /// `@MainActor` hérite de son isolement — Swift 6 arrête alors l'app (plantage du 19/11 sur iPhone3, juste après
    /// l'autorisation).
    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    private func loadJournal() {
        guard let text = try? String(contentsOf: Self.journal, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        trials = text.split(separator: "\n").compactMap { try? decoder.decode(Trial.self, from: Data($0.utf8)) }
    }

    /// Une position de puzzle au hasard, et un coup à dire : on tire d'abord un GENRE de coup (pion, chaque pièce,
    /// roque, prise, promotion) pour que la mesure couvre tout, pas seulement les coups de pion.
    func nextPosition() {
        for _ in 0..<50 {
            guard let entry = puzzles.randomElement(), let position = Position(fen: entry.fen) else { continue }
            var board = Board(position: position)
            // La position APRÈS le coup préparatoire de l'adversaire (convention Lichess), quand il passe.
            if let first = entry.solutionLANs.first, first.count >= 4 {
                _ = board.move(pieceAt: Square(String(first.prefix(2))), to: Square(String(first.dropFirst(2).prefix(2))))
            }
            let legal = VoiceMoveParser.candidates(in: board)
            guard !legal.isEmpty else { continue }
            var families: [String: [VoiceMoveParser.Candidate]] = [:]
            for move in legal {
                let key = move.isCastle ? "roque" : move.promotion != nil ? "promotion"
                    : move.san.contains("x") ? "prise" : String(move.piece)
                families[key, default: []].append(move)
            }
            guard let family = families.keys.randomElement(), let move = families[family]?.randomElement() else { continue }
            fen = board.position.fen
            candidates = legal
            target = move
            last = nil
            return
        }
    }

    // MARK: Enregistrer

    func beginRecording() {
        guard phase == .idle, target != nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = Self.directory.appending(path: "\(UUID().uuidString).caf")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16_000, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
        ]
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings), recorder.record() else {
            status = "Le micro ne démarre pas."
            return
        }
        self.recorder = recorder
        recordingURL = url
        phase = .recording
    }

    func endRecording() {
        guard phase == .recording, let recorder, let url = recordingURL, let target else { return }
        // Un dernier souffle : la fin du mot se perd si l'on coupe pile au relâchement.
        phase = .analysing
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            recorder.stop()
            self.recorder = nil
            await analyse(url: url, target: target)
        }
    }

    // MARK: Reconnaître

    private func analyse(url: URL, target: VoiceMoveParser.Candidate) async {
        let hints = VoiceMoveParser.spokenForms(of: candidates)
        var results: [EngineResult] = []

        func record(_ engine: String, _ work: () async -> [String]) async {
            let clock = ContinuousClock.now
            let transcripts = await work()
            let millis = Int((ContinuousClock.now - clock).components.attoseconds / 1_000_000_000_000_000)
                + Int((ContinuousClock.now - clock).components.seconds * 1000)
            let outcome = VoiceMoveParser.resolve(transcripts: transcripts, among: candidates)
            let correct: Bool = if case let .move(move) = outcome { move == target } else { false }
            results.append(EngineResult(engine: engine, transcripts: transcripts, outcome: Self.describe(outcome),
                                        correct: correct, millis: millis))
        }

        await record(Self.engines[0]) { await Self.recognizeClassic(url: url, hints: nil, model: nil) }
        await record(Self.engines[1]) { await Self.recognizeClassic(url: url, hints: hints, model: nil) }
        if let languageModel {
            await record(Self.engines[2]) { await Self.recognizeClassic(url: url, hints: nil, model: languageModel) }
        }
        if #available(iOS 26, *) {
            await record(Self.engines[3]) { await Self.recognizeTranscriber(url: url, hints: hints) }
            if let languageModel {
                await record(Self.engines[4]) { await Self.recognizeDictation(url: url, model: languageModel) }
            }
        }

        let trial = Trial(id: url.deletingPathExtension().lastPathComponent, date: .now, fen: fen, target: target,
                          candidates: candidates, results: results)
        trials.append(trial)
        last = trial
        append(trial)
        phase = .idle
    }

    private func append(_ trial: Trial) {
        guard let data = try? JSONEncoder().encode(trial) else { return }
        let line = data + Data("\n".utf8)
        if let handle = try? FileHandle(forWritingTo: Self.journal) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: Self.journal)
        }
    }

    /// Le dernier essai ne compte pas (on s'est trompé de coup, on a toussé) : retiré du journal.
    func discardLast() {
        guard let last, trials.last?.id == last.id else { return }
        trials.removeLast()
        self.last = nil
        let encoder = JSONEncoder()
        let text = trials.compactMap { try? encoder.encode($0) }.map { String(decoding: $0, as: UTF8.self) }
            .joined(separator: "\n")
        try? Data((text.isEmpty ? "" : text + "\n").utf8).write(to: Self.journal)
    }

    static func describe(_ outcome: VoiceMoveParser.Outcome) -> String {
        switch outcome {
        case let .move(move): move.san
        case let .ambiguous(moves): "ambigu : " + moves.map(\.san).joined(separator: ", ")
        case .illegal: "coup impossible"
        case .notUnderstood: "pas compris"
        }
    }

    /// Le score d'un moteur : coups justes / essais où il a tourné.
    func score(_ engine: String) -> (correct: Int, total: Int) {
        let runs = trials.compactMap { $0.results.first { $0.engine == engine } }
        return (runs.filter(\.correct).count, runs.count)
    }

    // MARK: Les cinq reconnaissances

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func claim() -> Bool { lock.withLock { defer { done = true }; return !done } }
    }

    nonisolated static func recognizeClassic(url: URL, hints: [String]?,
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
    nonisolated static func recognizeTranscriber(url: URL, hints: [String]) async -> [String] {
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcriptionWithAlternatives)
        let context = AnalysisContext()
        context.contextualStrings[.general] = hints
        return await run(module: transcriber, results: transcriber.results, url: url, context: context) { result in
            [String(result.text.characters)] + result.alternatives.map { String($0.characters) }
        }
    }

    @available(iOS 26, *)
    nonisolated static func recognizeDictation(url: URL, model: SFSpeechLanguageModel.Configuration) async -> [String] {
        let dictation = DictationTranscriber(
            locale: locale, contentHints: [.shortForm, .customizedLanguage(modelConfiguration: model)],
            transcriptionOptions: [], reportingOptions: [.alternativeTranscriptions], attributeOptions: [])
        return await run(module: dictation, results: dictation.results, url: url, context: AnalysisContext()) { result in
            [String(result.text.characters)] + result.alternatives.map { String($0.characters) }
        }
    }

    /// Fait passer le fichier dans un module d'iOS 26. Une phrase courte donne d'ordinaire UN résultat final ; s'il y
    /// en a plusieurs, on garde leur texte mis bout à bout.
    @available(iOS 26, *)
    nonisolated private static func run<Results: AsyncSequence & Sendable>(
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

    // MARK: Préparer

    /// Le vocabulaire d'échecs : des gabarits de phrases (« cavalier en f 3 »…) compilés en modèle SUR l'iPhone.
    private func prepareVocabulary() async {
        let dir = Self.directory
        let asset = dir.appending(path: "chess-fr.bin")
        let configuration = SFSpeechLanguageModel.Configuration(
            languageModel: dir.appending(path: "chess-fr.lm"), vocabulary: dir.appending(path: "chess-fr.vocab"))
        do {
            try await Self.exportVocabulary(to: asset)
            try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: asset, configuration: configuration)
            languageModel = configuration
            vocabularyStatus = "vocabulaire : prêt"
        } catch {
            vocabularyStatus = "vocabulaire : échec (\(error.localizedDescription))"
        }
    }

    nonisolated private static func exportVocabulary(to asset: URL) async throws {
        let data = SFCustomLanguageModelData(locale: locale, identifier: "com.chesslab.voicelab", version: "1") {
            SFCustomLanguageModelData.PhraseCountsFromTemplates(classes: [
                "piece": ["roi", "dame", "tour", "fou", "cavalier", "pion"],
                "file": ["a", "b", "c", "d", "e", "f", "g", "h"],
                "rank": ["1", "2", "3", "4", "5", "6", "7", "8"],
            ]) {
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template("<piece> <file><rank>", count: 4000)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template("<piece> en <file><rank>", count: 3000)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template("<piece> prend <file><rank>", count: 2000)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template("<piece> prend en <file><rank>", count: 1000)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template("<file><rank>", count: 3000)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template("<piece> <file> <file><rank>", count: 500)
                SFCustomLanguageModelData.TemplatePhraseCountGenerator.Template("<file><rank> <piece>", count: 300)
            }
            SFCustomLanguageModelData.PhraseCount(phrase: "petit roque", count: 800)
            SFCustomLanguageModelData.PhraseCount(phrase: "grand roque", count: 500)
        }
        try await data.export(to: asset)
    }

    /// Les modèles d'iOS 26 se téléchargent par le SYSTÈME (comme une voix) ; sans eux, D et E ne rendent rien.
    @available(iOS 26, *)
    private func installModernAssets() async {
        let modules: [any SpeechModule] = [
            SpeechTranscriber(locale: Self.locale, preset: .transcriptionWithAlternatives),
            DictationTranscriber(locale: Self.locale, preset: .shortDictation),
        ]
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                status = "Téléchargement des modèles iOS 26…"
                try await request.downloadAndInstall()
            }
            status = ""
        } catch {
            status = "Modèles iOS 26 indisponibles (\(error.localizedDescription))"
        }
    }
}

/// L'écran de mesure : le coup à dire, le micro à maintenir, ce que chaque reconnaissance a entendu, les scores.
struct VoiceDictationLabView: View {
    @State private var lab = VoiceDictationLab()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    scores
                    if let target = lab.target { targetCard(target) }
                    microphone
                    if let last = lab.last { lastTrial(last) }
                    Text(verbatim: lab.vocabularyStatus).font(.caption).foregroundStyle(Theme.textTertiary)
                    if !lab.status.isEmpty {
                        Text(verbatim: lab.status).font(.caption).foregroundStyle(Theme.warning)
                    }
                }
                .padding(20)
            }
            .appBackground()
            .navigationTitle(Text(verbatim: "Mesure de la dictée"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(verbatim: "Fermer") }
                }
            }
        }
        .task { await lab.start() }
    }

    private var scores: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "\(lab.trials.count) essais").font(.headline).foregroundStyle(Theme.textPrimary)
            ForEach(VoiceDictationLab.engines, id: \.self) { engine in
                let score = lab.score(engine)
                HStack {
                    Text(verbatim: engine)
                    Spacer()
                    Text(verbatim: score.total == 0 ? "—"
                         : "\(score.correct)/\(score.total) · \(score.correct * 100 / score.total) %")
                        .monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    private func targetCard(_ target: VoiceMoveParser.Candidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "Dites, à votre façon :").font(.subheadline).foregroundStyle(Theme.textSecondary)
            Text(verbatim: MoveNarration.describe(san: target.san))
                .font(.title.weight(.bold)).foregroundStyle(Theme.textPrimary)
            Text(verbatim: "\(SANFormatter.display(target.san)) · \(lab.candidates.count) coups légaux")
                .font(.footnote).foregroundStyle(Theme.textTertiary)
            HStack {
                Button { lab.nextPosition() } label: { Text(verbatim: "Autre coup") }
                Spacer()
                if lab.last != nil {
                    Button(role: .destructive) { lab.discardLast() } label: { Text(verbatim: "Ne pas compter le dernier") }
                }
            }
            .font(.subheadline)
        }
        .cardStyle()
    }

    private var microphone: some View {
        let recording = lab.phase == .recording
        return VStack(spacing: 8) {
            Image(systemName: lab.phase == .analysing ? "hourglass" : "mic.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 110, height: 110)
                .background(Circle().fill(recording ? Theme.danger : Theme.accent))
                .scaleEffect(recording ? 1.1 : 1)
                .animation(.snappy, value: recording)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: 200, perform: {}, onPressingChanged: { pressing in
                    if pressing { lab.beginRecording() } else { lab.endRecording() }
                })
            Text(verbatim: phaseText)
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var phaseText: String {
        switch lab.phase {
        case .idle: "Maintenir pour parler"
        case .recording: "Je vous écoute…"
        case .analysing: "Analyse…"
        }
    }

    private func lastTrial(_ trial: VoiceDictationLab.Trial) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(trial.results, id: \.engine) { result in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: result.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.correct ? Theme.accent : Theme.danger)
                        Text(verbatim: result.engine).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(verbatim: "\(result.millis) ms").font(.caption).monospacedDigit()
                    }
                    Text(verbatim: "« \(result.transcripts.first ?? "—") » → \(result.outcome)")
                        .font(.footnote)
                    if result.transcripts.count > 1 {
                        Text(verbatim: "aussi : " + result.transcripts.dropFirst().prefix(4).joined(separator: " | "))
                            .font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
                .foregroundStyle(Theme.textPrimary)
            }
        }
        .cardStyle()
    }
}
#endif
