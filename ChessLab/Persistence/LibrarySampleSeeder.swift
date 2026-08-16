import Foundation
import SwiftData

/// Peuple la bibliothèque d'un échantillon couvrant les QUATRE issues —
/// victoire des Blancs, victoire des Noirs, nulle, partie inachevée.
///
/// Activé par l'argument de lancement `-seedLibrarySample`, même parti pris
/// que ``LayoutTraitsProbe`` et ``SkeletonOverride`` : sans lui, un écran dont
/// l'apparence dépend des données ne se vérifie qu'en jouant des parties à la
/// main, autrement dit jamais. Les pastilles de résultat, en particulier, ne
/// se jugent qu'avec les quatre cas côte à côte.
///
/// **Tout ce fichier est compilé sous `#if DEBUG`** : rien n'existe dans le
/// binaire livré.
enum LibrarySampleSeeder {

    #if DEBUG
    static var isRequested: Bool {
        CommandLine.arguments.contains("-seedLibrarySample")
    }

    /// Quatre parties minimales — le contenu importe peu, ce sont les
    /// RÉSULTATS qu'on vient regarder.
    private static let samples: [(white: String, black: String, result: String)] = [
        ("Jorel, Martin", "Gauthey, Nils", "1-0"),
        ("Gauthey, Nils", "George", "0-1"),
        ("Ranieri, Pierpaolo", "Gauthey, Nils", "1/2-1/2"),
        ("Ungureanu, Emil", "Gauthey, Nils", "*"),
    ]

    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard isRequested else { return }
        // Idempotent : relancer l'app ne doit pas empiler des doublons.
        let existing = (try? context.fetch(FetchDescriptor<GameRecord>())) ?? []
        guard !existing.contains(where: { $0.whiteName == samples[0].white }) else { return }

        for (index, sample) in samples.enumerated() {
            let pgn = """
            [Event "Échantillon"]
            [White "\(sample.white)"]
            [Black "\(sample.black)"]
            [Result "\(sample.result)"]

            1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 \(sample.result)
            """
            let record = GameRecord()
            record.modeRaw = GameRecordMode.imported.rawValue
            record.pgn = pgn
            record.whiteName = sample.white
            record.blackName = sample.black
            record.resultRaw = sample.result == "*" ? nil : sample.result
            record.playedAt = Date().addingTimeInterval(TimeInterval(-index * 86_400))
            record.moveCount = 6
            context.insert(record)
        }
        try? context.save()
    }
    #else
    @MainActor
    static func seedIfRequested(in context: ModelContext) {}
    #endif
}
