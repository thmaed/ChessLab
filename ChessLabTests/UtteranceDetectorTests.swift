import AVFoundation
import Foundation
import Testing
@testable import ChessLab

/// La découpe des phrases au niveau sonore (19/11/2026) et l'essai ANTICIPÉ (20/11/2026), sur des sons fabriqués :
/// un murmure de fond, une voix. Pendant de `UtteranceDetectorTest.kt`.
struct UtteranceDetectorTests {
    private static let rate = 16_000.0
    /// Des tampons de 100 ms.
    private static let chunk: AVAudioFrameCount = 1_600
    private static let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1,
                                              interleaved: false)!

    private static func buffer(frames: AVAudioFrameCount = chunk, _ sample: (Int) -> Float) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for i in 0..<Int(frames) { buffer.floatChannelData![0][i] = sample(i) }
        return buffer
    }

    /// ≈ -60 dB.
    private static func noise() -> AVAudioPCMBuffer { buffer { _ in Float.random(in: -0.002...0.002) } }
    /// ≈ -15 dB.
    private static func voice() -> AVAudioPCMBuffer { buffer { 0.25 * sin(2 * .pi * 220 * Float($0) / Float(rate)) } }

    private final class Heard: @unchecked Sendable {
        var utterances: [Utterance] = []
        var pauses: [(Utterance, Int)] = []
    }

    private static func detector() -> (UtteranceDetector, Heard) {
        let heard = Heard()
        let detector = UtteranceDetector()
        detector.onUtterance = { heard.utterances.append($0) }
        detector.onPause = { heard.pauses.append(($0, $1)) }
        detector.setEnabled(true)
        return (detector, heard)
    }

    private static func seconds(_ utterance: Utterance) -> Double {
        Double(utterance.buffers.reduce(0) { $0 + Int($1.frameLength) }) / rate
    }

    @Test func aPhraseBetweenTwoSilencesComesWhole() {
        let (d, heard) = Self.detector()
        for _ in 0..<20 { d.ingest(Self.noise()) }
        for _ in 0..<8 { d.ingest(Self.voice()) }
        for _ in 0..<10 { d.ingest(Self.noise()) }
        #expect(heard.utterances.count == 1)
        // La parole (0,8 s), le pré-enregistrement (0,3 s) et le silence de fin (0,7 s), à un tampon près.
        #expect((1.5...2.0).contains(Self.seconds(heard.utterances[0])))
    }

    /// iPhone3, 20/11/2026 : des tampons de 20 ms (comme le micro de l'iPhone) et un bruit de fond qui a des pics.
    /// Jugée tampon par tampon, la phrase ne finissait jamais (6 s à chaque fois) ; lissée, elle finit au silence.
    @Test func aSpikyBackgroundDoesNotKeepThePhraseOpen() {
        let (d, heard) = Self.detector()
        let short: AVAudioFrameCount = 320
        var tick = 0
        func background() -> AVAudioPCMBuffer {
            tick += 1
            let spike: Float = tick % 4 == 0 ? 0.02 : 0.002      // un tampon sur quatre à ≈ -40 dB
            return Self.buffer(frames: short) { _ in Float.random(in: -spike...spike) }
        }
        let voice = Self.buffer(frames: short) { 0.25 * sin(2 * .pi * 220 * Float($0) / Float(Self.rate)) }
        for _ in 0..<100 { d.ingest(background()) }            // 2 s de fond
        for _ in 0..<40 { d.ingest(voice) }                    // 0,8 s de parole
        for _ in 0..<50 { d.ingest(background()) }             // 1 s de fond
        #expect(heard.utterances.count == 1)
        #expect(heard.utterances.first.map(Self.seconds) ?? 0 < 2.2, "finie au silence, pas à la durée maximale")
        #expect(heard.pauses.count == 1, "l'essai anticipé a sa chance")
    }

    @Test func aShortPauseOffersThePhraseEarlyAndAClaimClosesIt() {
        let (d, heard) = Self.detector()
        for _ in 0..<20 { d.ingest(Self.noise()) }
        for _ in 0..<8 { d.ingest(Self.voice()) }
        for _ in 0..<3 { d.ingest(Self.noise()) }
        #expect(heard.pauses.count == 1, "après 0,3 s de silence, la phrase est offerte")
        #expect(heard.utterances.isEmpty)
        #expect(d.claim(heard.pauses[0].1))
        for _ in 0..<10 { d.ingest(Self.noise()) }
        #expect(heard.utterances.isEmpty, "prise à la pause, elle ne revient pas en fin de phrase")
        #expect(!d.claim(heard.pauses[0].1), "on ne la prend qu'une fois")
    }

    @Test func speakingAgainAfterThePauseVoidsTheEarlyTry() {
        let (d, heard) = Self.detector()
        for _ in 0..<20 { d.ingest(Self.noise()) }
        for _ in 0..<6 { d.ingest(Self.voice()) }    // « cavalier »
        for _ in 0..<4 { d.ingest(Self.noise()) }    // on cherche la case
        for _ in 0..<4 { d.ingest(Self.voice()) }    // « f3 »
        #expect(heard.pauses.count == 1)
        #expect(!d.claim(heard.pauses[0].1), "la parole a repris : l'essai est périmé")
        for _ in 0..<10 { d.ingest(Self.noise()) }
        #expect(heard.pauses.count == 2, "une nouvelle pause offre la phrase entière")
        #expect(heard.utterances.count == 1, "non prise, la phrase entière arrive à la fin")
        #expect(Self.seconds(heard.utterances[0]) > 2)
    }

    /// iPhone XS, 20/11/2026 : la phrase finie sans reprise de la parole porte le jeton de sa pause — l'écoute reprend
    /// alors l'essai anticipé au lieu de lancer une seconde reconnaissance en même temps.
    @Test func aPhraseFinishedRightAfterItsPauseCarriesThePauseToken() {
        let (d, heard) = Self.detector()
        for _ in 0..<20 { d.ingest(Self.noise()) }
        for _ in 0..<8 { d.ingest(Self.voice()) }
        for _ in 0..<10 { d.ingest(Self.noise()) }
        #expect(heard.utterances.first?.pauseToken == heard.pauses.first?.1)
        #expect(heard.utterances.first?.pauseToken != nil)

        for _ in 0..<6 { d.ingest(Self.voice()) }
        for _ in 0..<4 { d.ingest(Self.noise()) }
        for _ in 0..<4 { d.ingest(Self.voice()) }    // la parole reprend après la pause
        for _ in 0..<10 { d.ingest(Self.noise()) }
        #expect(heard.utterances.count == 2)
        #expect(heard.utterances[1].pauseToken == heard.pauses.last?.1, "le jeton de la DERNIÈRE pause, pas de la première")
        #expect(heard.utterances[1].pauseToken != heard.pauses[1].1)
    }

    @Test func aPhraseFinishedWithoutClaimCannotBeClaimedAnymore() {
        let (d, heard) = Self.detector()
        for _ in 0..<20 { d.ingest(Self.noise()) }
        for _ in 0..<8 { d.ingest(Self.voice()) }
        for _ in 0..<10 { d.ingest(Self.noise()) }
        #expect(heard.pauses.count == 1)
        #expect(heard.utterances.count == 1)
        #expect(!d.claim(heard.pauses[0].1), "la reconnaissance anticipée arrive trop tard : rien ne se joue deux fois")
    }

    @Test func aBriefNoiseIsNoPhraseNorPause() {
        let (d, heard) = Self.detector()
        for _ in 0..<20 { d.ingest(Self.noise()) }
        for _ in 0..<2 { d.ingest(Self.voice()) }
        for _ in 0..<10 { d.ingest(Self.noise()) }
        #expect(heard.utterances.isEmpty)
        #expect(heard.pauses.isEmpty)
    }
}
