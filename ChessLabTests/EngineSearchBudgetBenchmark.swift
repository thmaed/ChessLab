import ChessKitEngine
import Foundation
import os
import Testing
@testable import ChessLab

/// Harnais de MESURE du budget de recherche utilisé par la classification
/// des coups — pas un test de comportement.
///
/// Il ne vérifie rien et ne peut donc pas échouer : il produit un tableau.
/// La question à laquelle il répond : `movetime: 400` (le réglage actuel de
/// ``AnalysisViewModel/rankedEval(fen:engine:movetime:multipv:)``) atteint
/// QUELLE profondeur, et le plafond envisagé de 700 ms serait-il rare ou
/// permanent ?
///
/// - important: **Désactivé par défaut.** La suite complète tourne en ~170 s
///   et ce harnais ajouterait plusieurs minutes de recherches moteur pour
///   zéro assertion. Il s'active par variable d'environnement :
///   ```
///   CHESSLAB_BENCH=1 xcodebuild test \
///     -only-testing:ChessLabTests/EngineSearchBudgetBenchmark ...
///   ```
///
/// - important: **À exécuter sur un APPAREIL RÉEL.** Le simulateur tourne
///   sur le CPU du Mac, facilement 3 à 5× plus rapide qu'un iPhone sur cette
///   charge. Calibrer une profondeur cible sur des chiffres de simulateur
///   garantirait que les vrais appareils tapent le plafond de temps en
///   permanence — exactement le défaut qu'on cherche à éviter. Les chiffres
///   du simulateur servent à valider le harnais, jamais à régler l'app.
/// - important: `.serialized` n'est PAS une précaution de confort. Swift
///   Testing exécute les tests d'une suite en PARALLÈLE par défaut, et
///   chaque test d'ici démarre son propre Stockfish. Or ChessKitEngine
///   détourne `stdout` comme canal UCI : c'est une ressource GLOBALE au
///   processus. Deux moteurs simultanés se corrompent mutuellement et font
///   planter le runner — constaté, pas supposé.
@Suite(.serialized)
struct EngineSearchBudgetBenchmark {

    private static let logger = Logger(subsystem: "ChessLab", category: "bench")

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["CHESSLAB_BENCH"] == "1"
    }

    /// Positions couvrant les régimes qui se comportent DIFFÉREMMENT face à
    /// une limite de temps. C'est tout l'enjeu de la mesure : une finale
    /// atteint la profondeur 20 en quelques dizaines de millisecondes, un
    /// milieu de partie chargé n'y arrive jamais dans le budget — et c'est
    /// dans le second cas que se trouvent les gaffes que l'analyse existe
    /// pour détecter.
    private static let positions: [(name: String, fen: String)] = [
        ("ouverture", "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"),
        ("milieu calme", "r1bq1rk1/pp2bppp/2n1pn2/2pp4/3P1B2/2PBPN2/PP1N1PPP/R2Q1RK1 w - - 0 9"),
        ("milieu TACTIQUE", "r2q1rk1/pp1bbppp/2np1n2/4p3/2B1P3/2NP1N2/PPP1QPPP/R1B2RK1 w - - 4 10"),
        ("finale tours", "8/5pk1/6p1/8/8/1R6/5PPP/6K1 w - - 0 40")
    ]

    /// Ce qu'une recherche a réellement produit.
    private struct Sample {
        var depth = 0
        var seldepth = 0
        var nodes = 0
        /// Temps rapporté par le moteur (`info time`).
        var timeMs = 0
        /// Temps réel mesuré côté app, montre en main. On ne se contente
        /// PAS de `info time` : un premier relevé a montré une recherche
        /// `movetime 700` rendue en 406 ms avec une profondeur inférieure à
        /// celle du run à 400 ms — incohérence qui ne pouvait se voir qu'en
        /// comparant les deux horloges.
        var wallMs = 0
    }

    /// Lance UNE recherche et relève ce que le moteur a atteint.
    ///
    /// On ne retient que les `info` de la ligne principale (`multipv == 1`) :
    /// en MultiPV=2 la profondeur est rapportée par ligne, et mélanger les
    /// deux ferait osciller la valeur.
    private func measure(
        engine: EngineController, fen: String, multipv: Int, limit: EngineCommand
    ) async -> Sample {
        // Deux barrières plutôt qu'une, et une pause entre les deux : le
        // premier relevé a produit une recherche `movetime 700` terminée en
        // 406 ms, signe qu'un `bestmove` TARDIF de la recherche précédente
        // clôturait la boucle de lecture en avance. `synchronize()` seul ne
        // suffit pas quand `MultiPV` change entre deux mesures — le moteur
        // continue d'émettre pendant qu'on reconfigure.
        await engine.synchronize()
        await engine.send(.setoption(id: "MultiPV", value: "\(multipv)"))
        try? await Task.sleep(for: .milliseconds(150))
        await engine.synchronize()
        await engine.send(.position(.fen(fen)))

        let clock = ContinuousClock()
        let start = clock.now
        await engine.send(limit)

        var sample = Sample()
        // Généreux : on mesure justement des recherches dont on ignore la
        // durée (`go depth 20` peut être long sur position chargée).
        let outcome = await EngineWatchdog.run(deadlineMs: 120_000) { () -> Sample in
            var current = Sample()
            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    guard (info.multipv ?? 1) == 1 else { break }
                    if let depth = info.depth { current.depth = max(current.depth, depth) }
                    if let seldepth = info.seldepth { current.seldepth = max(current.seldepth, seldepth) }
                    if let nodes = info.nodes { current.nodes = max(current.nodes, nodes) }
                    if let time = info.time { current.timeMs = max(current.timeMs, time) }
                case .bestmove:
                    return current
                default:
                    break
                }
            }
            return current
        }
        if case let .finished(value) = outcome { sample = value }
        sample.wallMs = Int((clock.now - start) / .milliseconds(1))
        return sample
    }

    /// Mesure 1 et 2 : profondeur atteinte à 400 ms (réglage actuel), à
    /// 700 ms (plafond envisagé), et temps nécessaire pour atteindre
    /// réellement la profondeur 20 — le tout en MultiPV=2, comme la
    /// classification.
    @Test(.enabled(if: EngineSearchBudgetBenchmark.isEnabled))
    func depthReachedPerTimeBudget() async {
        let controller = EngineController(type: .stockfish)
        let started = await controller.start(
            threads: ThermalMonitor.shared.threads(preferred: AppSettings.recommendedEngineThreads),
            hashMB: AppSettings.engineHashMB,
            multipv: 2
        )
        guard started else {
            Self.logger.error("moteur non démarré — mesure impossible")
            return
        }
        // `ThermalMonitor.state` est isolé sur le MainActor : on le lit AVANT
        // de le passer à `os_log`, dont l'argument est une autoclosure
        // nonisolated.
        let thermalBefore = await MainActor.run { String(describing: ThermalMonitor.shared.state) }
        Self.logger.notice("=== budget de recherche | etat thermique: \(thermalBefore, privacy: .public) ===")
        Self.logger.notice("position | limite | depth | seldepth | nodes | moteur(ms) | reel(ms)")

        // Rodage jeté : la première recherche remplit la table de hachage et
        // les caches, elle n'est représentative de rien.
        _ = await measure(
            engine: controller, fen: Self.positions[0].fen, multipv: 2, limit: .go(movetime: 400)
        )

        for position in Self.positions {
            for (label, limit) in [
                ("movetime 400", EngineCommand.go(movetime: 400)),
                ("movetime 700", EngineCommand.go(movetime: 700)),
                ("depth 20", EngineCommand.go(depth: 20))
            ] {
                let sample = await measure(
                    engine: controller, fen: position.fen, multipv: 2, limit: limit
                )
                Self.logger.notice("""
                \(position.name, privacy: .public) | \(label, privacy: .public) | \
                \(sample.depth, privacy: .public) | \(sample.seldepth, privacy: .public) | \
                \(sample.nodes, privacy: .public) | \(sample.timeMs, privacy: .public) | \
                \(sample.wallMs, privacy: .public)
                """)
            }
        }

        // Relu en FIN de série : l'écart avec l'état de départ est un
        // résultat en soi — 40 à 80 recherches d'affilée, c'est exactement
        // ce qui fait chauffer un appareil et déclenche la réduction de
        // budget de `ThermalMonitor`.
        let thermalAfter = await MainActor.run { String(describing: ThermalMonitor.shared.state) }
        Self.logger.notice("=== fin | etat thermique: \(thermalAfter, privacy: .public) ===")
        await controller.stop()
    }

    @Test(.enabled(if: EngineSearchBudgetBenchmark.isEnabled))
    func singleThreadAloneDoesNotStall() async {
        let controller = EngineController(type: .stockfish)
        guard await controller.start(
            threads: 1, hashMB: AppSettings.engineHashMB, multipv: 2
        ) else {
            Self.logger.error("moteur non démarré (1 thread)")
            return
        }
        Self.logger.notice("=== 1 thread SEUL | nodes 300000 ===")
        Self.logger.notice("position | depth | nodes | reel(ms)")
        for position in Self.positions {
            let sample = await measure(
                engine: controller, fen: position.fen, multipv: 2,
                limit: .go(nodes: 300_000)
            )
            Self.logger.notice("""
            \(position.name, privacy: .public) | \(sample.depth, privacy: .public) | \
            \(sample.nodes, privacy: .public) | \(sample.wallMs, privacy: .public)
            """)
        }
        Self.logger.notice("=== 1 thread SEUL : fin ===")
        await controller.stop()
    }

}
