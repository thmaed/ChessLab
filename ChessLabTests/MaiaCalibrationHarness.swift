import Foundation
import Testing
@testable import ChessLab

/// Campagne de calibrage d'un personnage Maia contre l'étalon Stockfish
/// bridé (lot 3 du chantier « Adversaires humanisés »).
///
/// Ce n'est PAS un test de régression : il MESURE. Éteint par défaut.
///
/// ```
/// TEST_RUNNER_CHESSLAB_MAIA_CALIBRATION=1 \
/// TEST_RUNNER_MAIA_TIERS=1100,1500,2000 \
/// TEST_RUNNER_MAIA_CONSIGNES=1100,1500,2000   # une liste par palier (« ; » entre paliers) ou une seule liste
/// TEST_RUNNER_MAIA_GAMES=100 \
/// TEST_RUNNER_MAIA_PROFILE=camille \
/// TEST_RUNNER_MAIA_CSV=/chemin/maia-calibration.csv \
/// xcodebuild test … -only-testing:ChessLabTests/MaiaCalibrationHarness
/// ```
///
/// Pour chaque palier N (le niveau que l'app AFFICHERA) et chaque consigne m
/// (l'Elo donné à Maia), une série au Laboratoire : camp A = personnage à la
/// consigne m, avec son filet ; camp B = Stockfish bridé à N. Couleurs
/// alternées, livres éteints, budgets du mode rapide. `LabStats` rend le
/// score, l'écart Elo et son intervalle à 95 %. La consigne qui annule
/// l'écart est la valeur m(N) cherchée.
///
/// Le CSV est réécrit après CHAQUE série : une campagne dure des heures.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["CHESSLAB_MAIA_CALIBRATION"] == "1"))
@MainActor
struct MaiaCalibrationHarness {

    private struct Measurement {
        let profile: String
        let tier: Int
        let consigne: Int
        let games: Int
        let winsA: Int
        let draws: Int
        let winsB: Int
        let score: Double
        let eloDifference: Double?
        let ciLow: Double?
        let ciHigh: Double?
        let averagePlies: Double
        let seconds: TimeInterval

        var csvLine: String {
            func f(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "" }
            return "\(profile),\(tier),\(consigne),\(games),\(winsA),\(draws),\(winsB),"
                + "\(String(format: "%.4f", score)),\(f(eloDifference)),\(f(ciLow)),\(f(ciHigh)),"
                + "\(String(format: "%.1f", averagePlies)),\(Int(seconds))"
        }
    }

    private static let header =
        "profile,tier,consigne,games,winsA,draws,winsB,score,eloDiff,ci95Low,ci95High,averagePlies,seconds"

    @Test func measureProfileAgainstBridledStockfish() async throws {
        let env = ProcessInfo.processInfo.environment
        let profileID = env["MAIA_PROFILE"] ?? OpponentProfile.camille.id
        let profile = try #require(OpponentProfile.named(profileID), "personnage inconnu : \(profileID)")
        let tiers = (env["MAIA_TIERS"] ?? "1100,1500,2000").split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let games = Int(env["MAIA_GAMES"] ?? "") ?? 100
        let csvPath = env["MAIA_CSV"] ?? NSTemporaryDirectory() + "maia-calibration-\(profileID).csv"

        // Consignes : « 1100,1500,2000 » (une par palier, dans l'ordre) ou
        // « 1000,1200;1400,1600;… » (une liste par palier).
        let consigneGroups = (env["MAIA_CONSIGNES"] ?? tiers.map(String.init).joined(separator: ","))
            .split(separator: ";")
            .map { $0.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } }
        func consignes(forTierAt index: Int) -> [Int] {
            if consigneGroups.count == tiers.count, consigneGroups.count > 1 { return consigneGroups[index] }
            if consigneGroups.count == 1, consigneGroups[0].count == tiers.count { return [consigneGroups[0][index]] }
            return consigneGroups.first ?? [tiers[index]]
        }

        print("▶ Calibrage de \(profile.firstName) : paliers \(tiers), \(games) parties par série → \(csvPath)")
        var measurements: [Measurement] = []

        for (index, tier) in tiers.enumerated() {
            for consigne in consignes(forTierAt: index) {
                let started = Date()
                let completed = try await playSeries(profile: profile, consigne: consigne, tier: tier, count: games)
                let stats = LabStats(results: completed.map(\.labResult), plyCounts: completed.map(\.plyCount))
                let ci = stats.elo95ConfidenceInterval
                let measurement = Measurement(
                    profile: profileID, tier: tier, consigne: consigne, games: stats.games,
                    winsA: stats.winsA, draws: stats.draws, winsB: stats.winsB, score: stats.score,
                    eloDifference: stats.eloDifference, ciLow: ci?.low, ciHigh: ci?.high,
                    averagePlies: stats.averagePlies, seconds: Date().timeIntervalSince(started)
                )
                measurements.append(measurement)
                Self.write(measurements, to: csvPath)
                // Les parties elles-mêmes, pour relire ce que Maia a joué.
                let pgnPath = csvPath.replacingOccurrences(of: ".csv", with: "") + "-\(tier)-\(consigne).pgn"
                try? completed.map(\.pgn).joined(separator: "\n\n").write(toFile: pgnPath, atomically: true, encoding: .utf8)
                let elo = measurement.eloDifference.map { String(format: "%+.0f", $0) } ?? "∞"
                print("  palier \(tier), consigne \(consigne) : \(stats.winsA)/\(stats.draws)/\(stats.winsB) "
                      + "score \(String(format: "%.1f", stats.scorePercent)) % → écart \(elo) Elo "
                      + "(\(Int(measurement.seconds)) s, \(String(format: "%.0f", stats.averagePlies)) demi-coups)")
            }
        }

        print("▶ Terminé : \(measurements.count) série(s) → \(csvPath)")
        #expect(!measurements.isEmpty && measurements.allSatisfy { $0.games > 0 }, "une série n'a produit aucune partie")
    }

    /// Une série complète au Laboratoire, puis ses parties.
    private func playSeries(profile: OpponentProfile, consigne: Int, tier: Int, count: Int) async throws -> [LabCompletedGame] {
        var settings = LabGameSettings.default
        settings.sideAOpponentProfileID = profile.id
        // Le camp A affiche le NIVEAU N (seuils du filet, bridage en finale)
        // et reçoit la CONSIGNE m : c'est exactement ce que fera l'app.
        settings.sideAEloSlider = Double(tier)
        settings.sideAMaiaTargetElo = Double(consigne)
        settings.sideBOpponentProfileID = nil
        settings.sideBEloSlider = Double(tier)
        settings.sideABookEnabled = false
        settings.sideBBookEnabled = false
        settings.gameCount = count
        settings.alternateColors = true
        // 300 ms et non 150 : plus près du budget du mode Jouer (900 ms sans
        // pendule), à un coût de campagne encore tenable ; un moteur bridé
        // est de toute façon peu sensible au temps.
        settings.movetimeMs = 300
        settings.liveVisualization = false
        settings.keepAwakeSetting = false

        let viewModel = LabViewModel(settings: settings, idleTimerGuard: IdleTimerGuard(apply: { _ in }))
        viewModel.start()
        let budget = TimeInterval(count) * 180 + 120
        let deadline = Date().addingTimeInterval(budget)
        while viewModel.isRunning, Date() < deadline {
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        viewModel.cancel()
        try await Task.sleep(nanoseconds: 1_500_000_000)
        if viewModel.completed.count < count {
            print("    ⚠ palier \(tier) / consigne \(consigne) : \(viewModel.completed.count)/\(count) parties")
        }
        return viewModel.completed
    }

    private static func write(_ measurements: [Measurement], to path: String) {
        let body = ([header] + measurements.map(\.csvLine)).joined(separator: "\n") + "\n"
        try? body.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
