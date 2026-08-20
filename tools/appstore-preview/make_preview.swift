// Post-traitement d'un enregistrement simulateur vers une « app preview »
// App Store Connect, sans dépendance (AVFoundation seul, pas de ffmpeg) :
//
//   swift make_preview.swift <in.mov> <out.mov> <largeur> <hauteur> <début_s> <durée_s> [<début2_s> <durée2_s> ...] [vitesse]
//
// Plusieurs paires <début durée> mettent bout à bout autant de segments de la
// source : utile pour couper un temps mort au milieu d'une prise (choisir des
// bornes sur un écran statique identique, le raccord est alors invisible).
//
// `vitesse` (optionnel, défaut 1.0, reconnu quand le nombre d'arguments après
// la hauteur est impair) : time-remap léger — 1.3 rend 38 s de parcours en
// 29,2 s de preview sans amputer le scénario ; rester ≤ 1.4, au-delà la
// navigation devient visiblement accélérée.
//
// - redimensionne (et rogne au besoin) vers la résolution EXACTE demandée
//   (886×1920 pour l'iPhone 6,9", 1200×1600 pour l'iPad 13") ;
// - plafonne à 30 i/s (App Store Connect refuse au-delà) ;
// - découpe la fenêtre [début, début+durée] (previews : 15-30 s) ;
// - ajoute une piste audio SILENCIEUSE (stéréo AAC) : App Store Connect
//   attend une piste audio, un enregistrement simulateur n'en a pas ;
// - exporte en H.264 QuickTime (.mov), le format accepté.
import AVFoundation
import Foundation

let args = CommandLine.arguments
guard args.count >= 7, let width = Int(args[3]), let height = Int(args[4]) else {
    print("usage: swift make_preview.swift <in.mov> <out.mov> <w> <h> <start_s> <dur_s> [<start2_s> <dur2_s> ...] [speed]")
    exit(1)
}
var tail = args[5...].compactMap(Double.init)
guard tail.count == args.count - 5 else {
    print("ERREUR : arguments temporels non numériques")
    exit(1)
}
let speed = tail.count % 2 == 1 ? tail.removeLast() : 1.0
let segments: [(start: Double, duration: Double)] = stride(from: 0, to: tail.count, by: 2)
    .map { (tail[$0], tail[$0 + 1]) }
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: outURL)

let semaphore = DispatchSemaphore(value: 0)

func fail(_ message: String) -> Never {
    print("ERREUR : \(message)")
    exit(2)
}

Task {
    let asset = AVURLAsset(url: inURL)
    guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
        fail("pas de piste vidéo dans \(inURL.path)")
    }
    let naturalSize = try await videoTrack.load(.naturalSize)
    let assetDuration = try await asset.load(.duration)
    let sourceSeconds = CMTimeGetSeconds(assetDuration)

    // Fenêtres temporelles, insérées bout à bout dans l'ordre donné.
    let composition = AVMutableComposition()
    guard let compositionVideo = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
    ) else { fail("piste vidéo de composition impossible") }
    var cursor = CMTime.zero
    var clippedDuration = 0.0
    for segment in segments {
        guard sourceSeconds > segment.start + 1 else {
            fail("source trop courte (\(sourceSeconds) s) pour un début à \(segment.start) s")
        }
        let clipped = min(segment.duration, sourceSeconds - segment.start)
        let range = CMTimeRange(
            start: CMTime(seconds: segment.start, preferredTimescale: 600),
            duration: CMTime(seconds: clipped, preferredTimescale: 600)
        )
        try compositionVideo.insertTimeRange(range, of: videoTrack, at: cursor)
        cursor = CMTimeAdd(cursor, range.duration)
        clippedDuration += clipped
    }
    let finalDuration = CMTime(seconds: clippedDuration / speed, preferredTimescale: 600)
    if speed != 1.0 {
        compositionVideo.scaleTimeRange(
            CMTimeRange(start: .zero, duration: cursor), toDuration: finalDuration)
    }

    // Piste audio SILENCIEUSE : PCM zéro écrit dans un CAF temporaire, puis
    // inséré comme piste de composition (l'export l'encodera en AAC).
    let silenceURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("cl-silence.caf")
    try? FileManager.default.removeItem(at: silenceURL)
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    let silenceFile = try AVAudioFile(forWriting: silenceURL, settings: format.settings)
    let frames = AVAudioFrameCount(44100 * (clippedDuration / speed))
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames  // les tampons sont nés remplis de zéros
    try silenceFile.write(from: buffer)
    let silenceAsset = AVURLAsset(url: silenceURL)
    if let silenceTrack = try await silenceAsset.loadTracks(withMediaType: .audio).first,
       let compositionAudio = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
       ) {
        let silenceDuration = try await silenceAsset.load(.duration)
        try compositionAudio.insertTimeRange(
            CMTimeRange(start: .zero, duration: min(silenceDuration, finalDuration)),
            of: silenceTrack, at: .zero
        )
    }

    // Mise à l'échelle vers la résolution CIBLE exacte : échelle sur la
    // largeur, rognage vertical symétrique du dépassement (les rapports
    // simulateur/preview diffèrent de quelques pixels au plus).
    let target = CGSize(width: CGFloat(width), height: CGFloat(height))
    let scale = target.width / naturalSize.width
    let scaledHeight = naturalSize.height * scale
    let yOffset = (target.height - scaledHeight) / 2  // négatif = rognage haut/bas

    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideo)
    layerInstruction.setTransform(
        CGAffineTransform(scaleX: scale, y: scale).concatenating(
            CGAffineTransform(translationX: 0, y: yOffset)),
        at: .zero
    )
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: finalDuration)
    instruction.layerInstructions = [layerInstruction]

    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = target
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)  // plafond App Store
    videoComposition.instructions = [instruction]

    guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        fail("session d'export impossible")
    }
    export.videoComposition = videoComposition
    export.outputURL = outURL
    export.outputFileType = .mov
    await export.export()
    if let error = export.error { fail("export : \(error.localizedDescription)") }

    // Contrôle final : dimensions et durée de ce qu'on vient d'écrire.
    let checkAsset = AVURLAsset(url: outURL)
    let checkTrack = try await checkAsset.loadTracks(withMediaType: .video).first!
    let checkSize = try await checkTrack.load(.naturalSize)
    let checkDuration = CMTimeGetSeconds(try await checkAsset.load(.duration))
    let audioCount = try await checkAsset.loadTracks(withMediaType: .audio).count
    print(String(format: "OK %@ — %.0f×%.0f, %.1f s, piste(s) audio : %d",
                 outURL.lastPathComponent, checkSize.width, checkSize.height, checkDuration, audioCount))
    semaphore.signal()
}

semaphore.wait()
