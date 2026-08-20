// Extrait trois images (début / milieu / fin) d'une vidéo vers PNG, pour
// contrôler visuellement une preview sans lecteur vidéo ni ffmpeg :
//
//   swift probe_frames.swift <in.mov> <dossier_sortie>
import AVFoundation
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: swift probe_frames.swift <in.mov> <outdir>"); exit(1) }
let url = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let semaphore = DispatchSemaphore(value: 0)
Task {
    let asset = AVURLAsset(url: url)
    let duration = CMTimeGetSeconds(try await asset.load(.duration))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)
    for (name, t) in [("debut", 0.1), ("milieu", duration / 2), ("fin", max(0, duration - 0.3))] {
        let cg = try await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)).image
        let rep = NSBitmapImageRep(cgImage: cg)
        let png = rep.representation(using: .png, properties: [:])!
        try png.write(to: outDir.appendingPathComponent("\(name).png"))
    }
    print("OK — 3 images dans \(outDir.path) (durée source : \(String(format: "%.1f", duration)) s)")
    semaphore.signal()
}
semaphore.wait()
