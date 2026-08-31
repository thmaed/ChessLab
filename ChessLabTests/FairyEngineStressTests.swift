import ChessKit
import CFairyStockfishKit
import CStockfishKit
import Foundation
import Testing
@testable import ChessLab

/// La TORTURE du moteur Fairy — les gestes brusques que l'app permet,
/// condensés en trois tests.
///
/// Chaque défaillance du moteur trouvée fin août venait d'un enchaînement
/// que les tests « un scénario, une variante » ne produisaient jamais :
/// navigation rapide entre tuiles, analyse relancée pendant une lecture,
/// deux moteurs vivants en même temps (``SessionStore`` garde les view
/// models d'écrans quittés). Cette suite produit ces enchaînements EXPRÈS,
/// vite et en boucle — si une régression de stabilité revient, c'est ici
/// qu'elle doit devenir rouge, pas une fois sur trente en suite complète.
@Suite(.serialized)
@MainActor
struct FairyEngineStressTests {

    /// Les neuf variantes servies par Fairy-Stockfish, telles que les écrans
    /// les démarrent — `VariantPath` compris pour les barricades, dont la
    /// définition n'existe pas dans le moteur.
    private static var allVariantStarts: [(id: String, path: String?, fen: String)] {
        FairyVariant.all.map { (id: $0.id, path: String?.none, fen: $0.startFEN) }
            + EngineLegalityVariant.all.map { (id: $0.id, path: $0.customDefinitionPath, fen: $0.startFEN) }
    }

    @Test("La tournée des variantes : neuf redémarrages enchaînés, deux fois")
    func rapidVariantSwitching() async {
        await EngineIntegrationGate.shared.withExclusiveAccess {
            let controller = FairyEngineController()
            defer { Task { await controller.stop() } }

            for round in 1...2 {
                for (id, path, fen) in Self.allVariantStarts {
                    let started = await EngineIntegrationGate.patiently {
                        await controller.start(variant: id, variantPath: path)
                    }
                    let failure = await controller.lastStartFailure
                    #expect(started, "tour \(round), \(id) : \(failure ?? "démarrage refusé sans diagnostic")")
                    guard started else { return }

                    let query = await controller.queryPosition(startFEN: fen, uciLog: [])
                    let diagnostic = await controller.lastQueryDiagnostic
                    #expect(
                        query.map { !$0.legalMoves.isEmpty } == true,
                        "tour \(round), \(id) : position de départ sans coups légaux — \(diagnostic ?? "pas de diagnostic")"
                    )
                }
            }
            await controller.stop()
        }
    }

    @Test("Dix lectures annulées en rafale ne tuent ni le flux ni le moteur")
    func cancellationStorm() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let controller = FairyEngineController()
            defer { Task { await controller.stop() } }
            let crazyhouse = EngineLegalityVariant.crazyhouse
            let started = await EngineIntegrationGate.patiently {
                await controller.start(variant: crazyhouse.id, variantPath: nil)
            }
            let failure = await controller.lastStartFailure
            try #require(started, "\(failure ?? "démarrage refusé")")

            // Le geste réel : quitter l'écran (ou le watchdog qui tranche)
            // pendant qu'une requête lit — la tâche lectrice est annulée en
            // plein vol. Dix fois, à des instants variés de la lecture.
            for wave in 1...10 {
                let reader = Task { @MainActor in
                    _ = await controller.queryPosition(startFEN: crazyhouse.startFEN, uciLog: [])
                }
                try? await Task.sleep(nanoseconds: UInt64(wave) * 3_000_000)
                reader.cancel()
                await reader.value
            }

            // Après l'orage : le MÊME contrôleur répond encore, entièrement.
            let query = await controller.queryPosition(startFEN: crazyhouse.startFEN, uciLog: [])
            let diagnostic = await controller.lastQueryDiagnostic
            #expect(
                query?.legalMoves.count == 20,
                "après 10 annulations : \(diagnostic ?? "requête muette, pas de diagnostic")"
            )
            await controller.stop()
        }
    }

    @Test("Le process passe d'un moteur à l'autre sans délai ni reste, six fois")
    func rapidEngineHandoff() async {
        await EngineIntegrationGate.shared.withExclusiveAccess {
            // Le contrat de l'app est UN moteur à la fois : chaque
            // `acquireEngineProcess` exige les DEUX types libres (les shims
            // partagent trop d'état pour cohabiter — constaté, pas supposé).
            // Le geste réel le plus dur n'est donc pas la cohabitation, mais
            // le RELAIS : quitter une partie classique pour une tuile
            // Variantes, revenir, repartir — six passations de process en
            // quelques secondes, sans qu'aucun reste (fil, gRunning, flux)
            // ne fasse échouer la suivante.
            for round in 1...3 {
                let engine = EngineController()
                let standardOK = await EngineIntegrationGate.patiently {
                    await engine.start(coreCount: 1)
                }
                #expect(standardOK, "tour \(round) : relais vers le moteur standard refusé")
                if standardOK {
                    let move = await engine.computeBestMove(
                        fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                        setupCommands: [], movetimeMs: 60, depth: nil
                    )
                    #expect(move != nil, "tour \(round) : le moteur standard n'a pas rendu de coup")
                }
                await engine.stop()

                let controller = FairyEngineController()
                let fairyOK = await EngineIntegrationGate.patiently {
                    await controller.start(variant: "atomic", variantPath: nil)
                }
                let failure = await controller.lastStartFailure
                #expect(fairyOK, "tour \(round) : relais vers Fairy refusé — \(failure ?? "sans diagnostic")")
                if fairyOK {
                    let query = await controller.queryPosition(
                        startFEN: EngineLegalityVariant.atomic.startFEN, uciLog: []
                    )
                    #expect(
                        query.map { !$0.legalMoves.isEmpty } == true,
                        "tour \(round) : le moteur Fairy n'a pas rendu la position"
                    )
                }
                await controller.stop()
            }

            // Personne ne doit rester : ni process pris, ni fil moteur vivant.
            #expect(StockfishEngine.isProcessSettled, "fil Stockfish encore vivant après les relais")
            #expect(FairyStockfishEngine.isProcessSettled, "fil Fairy encore vivant après les relais")
        }
    }
}
