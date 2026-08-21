import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Harnais de la campagne de calibrage « perte moyenne → Elo » (chantier C.1).
///
/// Ce n'est PAS un test de régression : il ne vérifie rien, il MESURE. Il reste
/// donc éteint par défaut et ne s'allume que sur variable d'environnement, comme
/// les bancs d'essai moteur déjà présents dans cette cible.
///
/// ```
/// TEST_RUNNER_CHESSLAB_CALIBRATION=1 \
/// TEST_RUNNER_CALIBRATION_TIERS=1100,1700,2300,2900 \
/// TEST_RUNNER_CALIBRATION_GAMES=10 \
/// xcodebuild test -project ChessLab.xcodeproj -scheme ChessLab \
///   -destination '…' -only-testing:ChessLabTests/EloCalibrationHarness
/// ```
///
/// ## Ce qu'il fait, et pourquoi dans cet ordre
///
/// Pour chaque palier : une série moteur-contre-moteur au Laboratoire **par
/// valeur de curseur**, jamais en pilotant `UCI_Elo` à la main — sous 1320 le
/// curseur commande `Skill Level` et la profondeur, et calibrer autrement
/// mentirait sur tout le bas de l'échelle (piège n° 1 du plan, tranché le
/// 20/08). `LabGameSettings` construit le même `EngineStrength` que le mode
/// Jouer : le Laboratoire EST le produit.
///
/// Puis chaque partie repasse dans le pipeline d'analyse **de production**,
/// budgets et seuils inchangés. C'est la condition de validité du calibrage :
/// une courbe ajustée sur des chiffres produits autrement ne décrirait pas ce
/// que l'app affichera.
///
/// ## Le point dur : un seul Stockfish à la fois
///
/// Le moteur est vendorisé et le process n'en accepte qu'un. Série et analyse
/// ne peuvent donc pas se chevaucher : on arrête la série, on attend que le
/// moteur soit vraiment relâché, et seulement ensuite on analyse. Tout ce
/// fichier est `.serialized` pour la même raison.
///
/// ## Écriture incrémentale
///
/// Le CSV est réécrit après CHAQUE partie analysée. Une campagne complète dure
/// des heures ; perdre huit heures de mesure sur un plantage de la dernière
/// partie serait absurde.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["CHESSLAB_CALIBRATION"] == "1"))
@MainActor
struct EloCalibrationHarness {

    /// Une ligne de mesure : un CAMP d'une partie jouée à un palier connu.
    private struct Measurement {
        let tier: Int
        let side: String
        let averageLoss: Double
        let classifiedCount: Int
        let bookCount: Int
        let accuracy: Double?
        let version: Int
        /// Perte moyenne restreinte aux positions ENCORE INDÉCISES. Le pilote
        /// du 21/08 a montré que la moyenne sur toute la partie ne sépare pas
        /// 1100 de 1700 : les longues phases techniques, où aucun coup ne
        /// coûte rien, noient le signal.
        let balancedLoss: Double?
        let balancedCount: Int
        /// Part des coups qui coûtent plus de 5 points — le seuil d'imprécision
        /// du barème. Une proportion résiste à la dilution là où une moyenne y
        /// cède.
        let faultRate: Double

        var csvLine: String {
            let accuracyText = accuracy.map { String(format: "%.2f", $0) } ?? ""
            let balancedText = balancedLoss.map { String(format: "%.4f", $0) } ?? ""
            return "\(tier),\(tier),\(side),\(String(format: "%.4f", averageLoss)),"
                + "\(classifiedCount),\(bookCount),\(accuracyText),\(version),"
                + "\(balancedText),\(balancedCount),\(String(format: "%.4f", faultRate))"
        }
    }

    private static let header =
        "tier,elo,side,averageLoss,classifiedCount,bookCount,accuracy,version,"
        + "balancedLoss,balancedCount,faultRate"

    /// Bornes de la zone « encore indécise » : au-delà, la partie est jouée et
    /// les coups ne disent plus grand-chose du niveau.
    private static let balancedRange: ClosedRange<Double> = 15...85
    /// Seuil d'imprécision du barème de classification.
    private static let faultThreshold: Double = 5

    /// Dossier sur le disque de l'HÔTE : un chemin absolu sort du conteneur du
    /// simulateur, même patron que les captures App Store. Sur appareil réel
    /// l'écriture échouerait — ce harnais n'a rien à y faire.
    private static let outputDirectory = "/tmp/cl-elo-calibration"

    private static func environmentValue(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }

    /// Paliers demandés, ou le jeu complet du protocole.
    private static var tiers: [Int] {
        guard let raw = environmentValue("CALIBRATION_TIERS") else {
            return [800, 1100, 1400, 1700, 2000, 2300, 2600, 2900]
        }
        return raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static var gamesPerTier: Int {
        environmentValue("CALIBRATION_GAMES").flatMap(Int.init) ?? 30
    }

    @Test("Campagne de calibrage : séries au Laboratoire puis analyse de production")
    func runCalibrationCampaign() async throws {
        let tiers = Self.tiers
        let gamesPerTier = Self.gamesPerTier
        try FileManager.default.createDirectory(
            atPath: Self.outputDirectory, withIntermediateDirectories: true
        )
        let csvPath = "\(Self.outputDirectory)/measures.csv"
        var measurements: [Measurement] = []
        var skipped = 0

        print("▶ Calibrage : \(tiers.count) palier(s) × \(gamesPerTier) partie(s) → \(csvPath)")

        for tier in tiers {
            let started = Date()
            let games = try await playSeries(atTier: tier, count: gamesPerTier)
            print("  · palier \(tier) : \(games.count) partie(s) en "
                  + String(format: "%.0f s", Date().timeIntervalSince(started)))

            for (index, game) in games.enumerated() {
                guard let analysed = await analyse(pgn: game.pgn) else {
                    skipped += 1
                    print("    ! partie \(index + 1) : analyse incomplète, écartée")
                    continue
                }
                let metrics = analysed.metrics
                for (side, name, colour) in [(metrics.white, "white", Piece.Color.white),
                                             (metrics.black, "black", Piece.Color.black)] {
                    // Le garde-fou du produit s'applique dès la mesure : une
                    // partie qui ne serait pas estimée en production n'a pas à
                    // servir à caler la courbe qui l'estimera.
                    guard let loss = side.averageLoss, side.classifiedCount >= 15 else {
                        skipped += 1
                        continue
                    }
                    let scored = analysed.moves.filter { $0.mover == colour && !$0.isBook }
                    let balanced = scored.filter { Self.balancedRange.contains($0.winPercentBefore) }
                    let faults = scored.filter { $0.loss > Self.faultThreshold }
                    measurements.append(Measurement(
                        tier: tier, side: name, averageLoss: loss,
                        classifiedCount: side.classifiedCount, bookCount: side.bookCount,
                        accuracy: side.accuracy, version: metrics.version,
                        balancedLoss: balanced.isEmpty
                            ? nil
                            : balanced.reduce(0.0) { $0 + $1.loss } / Double(balanced.count),
                        balancedCount: balanced.count,
                        faultRate: scored.isEmpty ? 0 : Double(faults.count) / Double(scored.count)
                    ))
                }
                Self.write(measurements, to: csvPath)
            }
        }

        print("▶ Terminé : \(measurements.count) mesure(s), \(skipped) écartée(s) → \(csvPath)")
        print("  Ajustement : python3 tools/elo-calibration/fit_curve.py \(csvPath)")

        // Le harnais ne juge pas la courbe — mais une campagne qui ne produit
        // rien est un échec, et doit se voir comme tel.
        #expect(!measurements.isEmpty, "aucune mesure exploitable : la campagne n'a rien produit")
    }

    // MARK: Série

    /// Fait jouer une série complète à un palier, puis rend les parties.
    private func playSeries(atTier tier: Int, count: Int) async throws -> [LabCompletedGame] {
        var settings = LabGameSettings.default
        settings.sideAEloSlider = Double(tier)
        settings.sideBEloSlider = Double(tier)
        settings.gameCount = count
        settings.alternateColors = true
        // Rien à regarder : l'animation coûte 90 ms par demi-coup, soit des
        // minutes par palier pour un harnais qui n'affiche rien.
        settings.liveVisualization = false
        settings.keepAwakeSetting = false

        let viewModel = LabViewModel(settings: settings, idleTimerGuard: IdleTimerGuard(apply: { _ in }))
        viewModel.start()

        // `isFinished` ne suffit pas : moteur qui refuse de démarrer ou budget
        // d'essais épuisé sortent de la boucle sans le poser. C'est `isRunning`
        // qui dit que la série a rendu la main, quelle qu'en soit la raison.
        let budget = TimeInterval(count) * 90 + 120
        await wait(upTo: budget) { !viewModel.isRunning }
        viewModel.cancel()
        // Le moteur se libère dans une tâche non structurée : l'analyse qui
        // suit échouerait à en obtenir un si on enchaînait tout de suite.
        try await Task.sleep(nanoseconds: 1_500_000_000)

        if viewModel.completed.count < count {
            print("    ⚠ palier \(tier) : \(viewModel.completed.count)/\(count) parties "
                  + "(série interrompue — moteur indisponible, ou budget d'essais épuisé)")
        }
        return viewModel.completed
    }

    // MARK: Analyse

    /// Repasse une partie dans le pipeline de production et rend son bilan.
    /// `nil` si la classification n'a pas pu aller au bout — mieux vaut une
    /// partie écartée qu'une mesure partielle qui fausserait un palier.
    private func analyse(pgn: String) async -> (metrics: GameAnalysisMetrics, moves: [GameAnalysisMetrics.Move])? {
        let viewModel = AnalysisViewModel(source: .pgn(pgn))
        defer {
            viewModel.handleViewDisappear()
        }
        // Construire le view model suffit à lancer la classification : l'init
        // enfile `setupEngine()`, qui enchaîne sur `classifyMainLine()`.
        // `analysisMetrics` ne devient non nul qu'une fois la ligne principale
        // ENTIÈREMENT classée — c'est le seul signal fiable ici, `isClassifying`
        // restant faux pendant la seconde de démarrage du moteur.
        await wait(upTo: 600) { viewModel.analysisMetrics != nil || viewModel.isEngineUnavailable }
        let metrics = viewModel.analysisMetrics
        let moves = viewModel.analysisMoveSeries()
        viewModel.handleViewDisappear()
        try? await Task.sleep(nanoseconds: 800_000_000)
        guard let metrics else { return nil }
        return (metrics, moves)
    }

    // MARK: Outillage

    private func wait(upTo seconds: TimeInterval, until condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private static func write(_ measurements: [Measurement], to path: String) {
        let body = ([header] + measurements.map(\.csvLine)).joined(separator: "\n") + "\n"
        try? body.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
