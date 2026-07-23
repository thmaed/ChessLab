import AVFoundation

/// Joue de courts sons de plateau **générés par synthèse** (aucun fichier
/// audio embarqué, donc aucune question de licence — cf. README).
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Event {
        case move, capture, castle, check
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [Event: AVAudioPCMBuffer] = [:]
    private let sampleRate: Double = 44100
    private let format: AVAudioFormat
    private var isReady = false

    private init() {
        // Format explicite et unique pour la connexion ET les buffers :
        // un mismatch entre les deux fait planter `scheduleBuffer` (NSException
        // non interceptable côté Swift).
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        for event: Event in [.move, .capture, .castle, .check] {
            buffers[event] = makeBuffer(for: event)
        }

        do {
            try engine.start()
            isReady = true
        } catch {
            isReady = false
        }
    }

    func play(_ event: Event) {
        guard AppSettings.shared.soundsEnabled else { return }
        guard isReady, let buffer = buffers[event] else { return }
        if !engine.isRunning {
            guard (try? engine.start()) != nil else { return }
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private func makeBuffer(for event: Event) -> AVAudioPCMBuffer? {
        let frequencies: [Double]
        let duration: Double

        switch event {
        case .move:
            frequencies = [880]
            duration = 0.07
        case .capture:
            frequencies = [660, 990]
            duration = 0.09
        case .castle:
            frequencies = [523, 659, 784]
            duration = 0.14
        case .check:
            frequencies = [988, 1318]
            duration = 0.16
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount
        let channel = buffer.floatChannelData![0]

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let envelope = exp(-t * 18) // enveloppe percussive
            let sample = frequencies.reduce(0.0) { $0 + sin(2 * .pi * $1 * t) } / Double(frequencies.count)
            channel[frame] = Float(sample * envelope * 0.5)
        }

        return buffer
    }
}
