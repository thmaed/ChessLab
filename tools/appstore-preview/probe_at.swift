// Sonde des horodatages précis : swift probe_at.swift <in.mov> <outdir> t1 t2 …
import AVFoundation
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else { print("usage: probe_at.swift <in> <outdir> t…"); exit(1) }
let url = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let times = args[3...].compactMap(Double.init)

let semaphore = DispatchSemaphore(value: 0)
Task {
    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = CMTime(seconds: 0.15, preferredTimescale: 600)
    for t in times {
        let cg = try await generator.image(at: CMTime(seconds: t, preferredTimescale: 600)).image
        let rep = NSBitmapImageRep(cgImage: cg)
        try rep.representation(using: .png, properties: [:])!
            .write(to: outDir.appendingPathComponent(String(format: "t%05.1f.png", t)))
    }
    print("OK")
    semaphore.signal()
}
semaphore.wait()
