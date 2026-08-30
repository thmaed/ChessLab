import CStockfishKit
import Foundation
import Testing
@testable import ChessLab

/// Le flux de réponses du contrôleur Fairy survit à ses consommateurs.
///
/// Née sonde jetable le 30/08, gardée en non-régression : c'est elle qui a
/// isolé le défaut au niveau du CONTRÔLEUR. L'ancien flux unique, partagé
/// par tous les consommateurs successifs, mourait POUR TOUJOURS à la
/// première annulation d'une lecture — or ``EngineWatchdog`` annule le
/// perdant de chaque course. Un seul timeout, et synchronize/éval/indices
/// se terminaient à vide sans erreur pour le reste de la session.
@Suite(.serialized)
@MainActor
struct FairyResponseStreamTests {

    private func askCp(_ engine: FairyEngineController, fen: String) async -> Int? {
        await engine.synchronize()
        let stream = await engine.responseStream
        await engine.send(.position(.fen(fen)))
        await engine.send(.go(movetime: 220))
        let outcome = await EngineWatchdog.run(deadlineMs: 3000) { () -> Int? in
            for await response in stream {
                switch response {
                case let .info(info):
                    if let cp = info.score?.cp { return Int(cp) }
                case .bestmove:
                    return nil
                default: break
                }
            }
            return nil
        }
        guard case let .finished(cp) = outcome else { return nil }
        return cp
    }

    @Test("Une lecture ANNULÉE ne tue pas le flux des lectures suivantes")
    func aCancelledReaderDoesNotKillTheStream() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let engine = FairyEngineController()
            let fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"
            try #require(await engine.start(variant: "crazyhouse"))

            // L'ARME DU CRIME, reproduite exprès : une course perdue — le
            // chien de garde expire et ANNULE la lecture en attente. Avec le
            // flux unique d'avant, tout ce qui suit se terminait à vide.
            let doomed = await EngineWatchdog.run(deadlineMs: 30) { [engine] () -> Bool in
                for await _ in await engine.responseStream { }
                return true
            }
            guard case .timedOut = doomed else {
                Issue.record("la course devait expirer pour reproduire l'annulation")
                await engine.stop()
                return
            }

            // Le moteur va bien, et le flux doit le prouver.
            #expect(await engine.synchronize(), "synchronize doit survivre à l'annulation d'un tiers")
            #expect(await self.askCp(engine, fen: fen) != nil, "l'évaluation doit encore remonter")

            await engine.stop()
        }
    }

    @Test("Le flux survit aussi à un arrêt/redémarrage complet")
    func theStreamSurvivesARestart() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let engine = FairyEngineController()
            let fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"

            try #require(await engine.start(variant: "crazyhouse"))
            #expect(await self.askCp(engine, fen: fen) != nil)

            await engine.stop()
            try await Task.sleep(for: .milliseconds(300))

            try #require(await engine.start(variant: "crazyhouse"), "redémarrage refusé")
            #expect(await self.askCp(engine, fen: fen) != nil, "l'évaluation doit revenir après redémarrage")

            await engine.stop()
        }
    }
}
