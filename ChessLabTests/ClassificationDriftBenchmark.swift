import ChessKit
import ChessKitEngine
import Foundation
import os
import Testing
@testable import ChessLab

/// Mesure 3 : **combien de coups changent de catégorie** quand on remplace
/// le budget de recherche `movetime 400` par une limite en NŒUDS.
///
/// C'est le seul chiffre de toute cette étude qui parle d'expérience
/// utilisateur. Les mesures de profondeur disent ce que fait le moteur ;
/// celle-ci dit ce que voit le joueur — « votre coup 23 était une gaffe »
/// devient-il « une imprécision » ?
///
/// L'enjeu n'est pas seulement la justesse. Les seuils de
/// ``MoveClassifier`` ont été calibrés sur des évaluations à 400 ms.
/// Changer le budget déplace la distribution des pertes de probabilité de
/// gain, donc déplace les frontières entre catégories. Et les parties DÉJÀ
/// analysées portent des annotations persistées : si la dérive est forte,
/// deux parties voisines dans la bibliothèque seraient jugées sur deux
/// barèmes différents, sans que rien ne le signale.
///
/// - important: **Désactivé par défaut**, comme
///   ``EngineSearchBudgetBenchmark`` — voir sa documentation pour la façon
///   de l'activer (`CHESSLAB_BENCH=1`, préfixé `TEST_RUNNER_` en ligne de
///   commande) et pour la nécessité de compiler en **Release** : en Debug,
///   Stockfish tourne ~7× moins vite et tous les chiffres sont faux.
struct ClassificationDriftBenchmark {

    private static let logger = Logger(subsystem: "ChessLab", category: "bench")

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["CHESSLAB_BENCH"] == "1"
    }

    /// Budget en nœuds mis à l'épreuve, choisi d'après le relevé
    /// profondeur/temps sur iPhone 17 Pro : ~280 000 nœuds correspondent à
    /// ~600 ms en milieu de partie, tout en rendant la finale quasi
    /// instantanée au lieu de lui faire consommer son quota de temps.
    private static let candidateNodes = 280_000

    /// Une vraie partie, coups en notation longue. Espagnole puis milieu de
    /// partie tranchant : on veut des positions où la classification a
    /// quelque chose à dire, pas une nulle de salon.
    private static let gameLANs = [
        "e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6",
        "e1g1", "f8e7", "f1e1", "b7b5", "a4b3", "d7d6", "c2c3", "e8g8",
        "h2h3", "c6a5", "b3c2", "c7c5", "d2d4", "d8c7", "b1d2", "c5d4",
        "c3d4", "a5c6", "d2b3", "a6a5", "c1e3", "a5a4", "b3c1", "c6b4",
        "c2b1", "b4d3", "b1d3", "c7c1", "d1c1", "e5d4", "f3d4", "c8d7"
    ]

    /// Évaluation d'une position sous un budget donné.
    private struct Eval {
        let winPercentWhite: Double
        let bestLan: String?
        let gapToSecondBest: Double?
    }

    /// Interroge le moteur en MultiPV=2 — comme la classification réelle —
    /// et rend l'évaluation POV BLANCS plus l'écart au 2e choix (POV du
    /// trait, comme ``AnalysisViewModel``).
    private func evaluate(
        engine: EngineController, position: Position, limit: EngineCommand
    ) async -> Eval? {
        await engine.synchronize()
        await engine.send(.setoption(id: "MultiPV", value: "2"))
        try? await Task.sleep(for: .milliseconds(120))
        await engine.synchronize()
        await engine.send(.position(.fen(position.fen)))
        await engine.send(limit)

        let outcome = await EngineWatchdog.run(deadlineMs: 60_000) {
            () -> [Int: (lan: String, cp: Int)] in
            var byRank: [Int: (lan: String, cp: Int)] = [:]
            for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    guard let rank = info.multipv, let first = info.pv?.first else { break }
                    if let cp = info.score?.cp {
                        byRank[rank] = (first, Int(cp))
                    } else if let mate = info.score?.mate {
                        byRank[rank] = (first, mate > 0 ? 10_000 - mate : -10_000 - mate)
                    }
                case .bestmove:
                    return byRank
                default:
                    break
                }
            }
            return byRank
        }

        guard case let .finished(byRank) = outcome, let best = byRank[1] else { return nil }
        let cpWhite = position.sideToMove == .white ? best.cp : -best.cp
        let gap = byRank[2].map {
            EvalConversion.winPercentage(cp: best.cp) - EvalConversion.winPercentage(cp: $0.cp)
        }
        return Eval(
            winPercentWhite: EvalConversion.winPercentage(cp: cpWhite),
            bestLan: best.lan,
            gapToSecondBest: gap
        )
    }

    /// Classe un coup à partir de l'évaluation avant/après, en NEUTRALISANT
    /// tout ce qui ne dépend pas du budget de recherche.
    ///
    /// `isBook`, `isSacrifice` et `isForced` sont identiques sous les deux
    /// réglages — ils ne dépendent pas du moteur. Les laisser à `false`
    /// isole donc exactement l'effet du budget, qui est la question posée.
    /// Ce n'est PAS la classification complète de l'app, et les catégories
    /// « Théorie » ou « Brillant » n'apparaîtront pas ici.
    private func quality(
        before: Eval, after: Eval, moverIsWhite: Bool, playedLan: String
    ) -> MoveQuality {
        let beforeMover = moverIsWhite ? before.winPercentWhite : 100 - before.winPercentWhite
        let afterMover = moverIsWhite ? after.winPercentWhite : 100 - after.winPercentWhite
        return MoveClassifier.classify(MoveClassifier.Input(
            winPercentBefore: beforeMover,
            winPercentAfter: afterMover,
            isBestMove: before.bestLan == playedLan,
            gapToSecondBest: before.gapToSecondBest
        ))
    }

    @Test(.enabled(if: ClassificationDriftBenchmark.isEnabled))
    func driftBetweenTimeAndNodeBudgets() async {
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

        Self.logger.notice("=== derive de classification | movetime 400 contre nodes \(Self.candidateNodes, privacy: .public) ===")
        Self.logger.notice("coup | joue | 400ms | nodes | change")

        // Positions successives de la partie, reconstruites une fois pour
        // toutes : on évalue CHAQUE position sous les deux budgets, puis on
        // classe. Une position sert deux fois (après le coup n, avant le
        // coup n+1) — d'où le cache implicite par le tableau.
        var positions: [Position] = [Position(fen: Position.standard.fen)!]
        var board = Board()
        for lan in Self.gameLANs {
            guard let move = board.move(pieceAt: Square(String(lan.prefix(2))),
                                        to: Square(String(lan.dropFirst(2).prefix(2)))) else { break }
            _ = move
            positions.append(board.position)
        }

        var evalsTime: [Eval?] = []
        var evalsNodes: [Eval?] = []
        for position in positions {
            evalsTime.append(await evaluate(engine: controller, position: position, limit: .go(movetime: 400)))
            evalsNodes.append(await evaluate(engine: controller, position: position, limit: .go(nodes: Self.candidateNodes)))
        }

        var changed = 0
        var compared = 0
        for index in 0..<(positions.count - 1) {
            guard let beforeTime = evalsTime[index], let afterTime = evalsTime[index + 1],
                  let beforeNodes = evalsNodes[index], let afterNodes = evalsNodes[index + 1]
            else { continue }
            let lan = Self.gameLANs[index]
            let moverIsWhite = positions[index].sideToMove == .white

            let qTime = quality(before: beforeTime, after: afterTime, moverIsWhite: moverIsWhite, playedLan: lan)
            let qNodes = quality(before: beforeNodes, after: afterNodes, moverIsWhite: moverIsWhite, playedLan: lan)

            compared += 1
            let differs = qTime != qNodes
            if differs { changed += 1 }
            Self.logger.notice("""
            \(index + 1, privacy: .public) | \(lan, privacy: .public) | \
            \(String(describing: qTime), privacy: .public) | \
            \(String(describing: qNodes), privacy: .public) | \
            \(differs ? "OUI" : "-", privacy: .public)
            """)
        }

        Self.logger.notice("=== BILAN : \(changed, privacy: .public) coups changent de categorie sur \(compared, privacy: .public) ===")
        await controller.stop()
    }
}
