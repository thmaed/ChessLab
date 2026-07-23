import ChessKitEngine
import Testing
@testable import ChessLab

/// Chien de garde des attentes moteur : c'est lui qui transforme
/// « Stockfish ne répond plus, écran figé pour toujours » en « détecté,
/// redémarré, la partie continue ».
struct EngineWatchdogTests {

    @Test func aFastOperationFinishesWithItsValue() async {
        let outcome: EngineWatchdogOutcome<Int> = await EngineWatchdog.run(deadlineMs: 5000) { 42 }
        guard case let .finished(value) = outcome else {
            Issue.record("une opération rapide ne doit pas expirer")
            return
        }
        #expect(value == 42)
    }

    /// Le cœur du dispositif : une attente qui ne rend jamais la main est
    /// conclue à l'échéance — et VITE, pas au bout des 30 s de
    /// l'opération. La borne temporelle prouve aussi que l'annulation de
    /// l'opération perdante est effective : `withTaskGroup` attend tous
    /// ses enfants avant de rendre la main, donc si l'annulation ne
    /// terminait pas l'opération, ce test entier durerait 30 s.
    @Test func aSilentOperationTimesOutQuicklyAndIsCancelled() async {
        let clock = ContinuousClock()
        let start = clock.now

        let outcome: EngineWatchdogOutcome<Int> = await EngineWatchdog.run(deadlineMs: 150) {
            try? await Task.sleep(for: .seconds(30))
            return 1
        }

        let elapsed = clock.now - start
        guard case .timedOut = outcome else {
            Issue.record("une opération muette doit expirer")
            return
        }
        #expect(elapsed < .seconds(10), "l'échéance doit tomber en ~150 ms, pas au bout des 30 s de l'opération")
    }

    /// Le piège du chien de garde : attendre une tâche NON STRUCTURÉE.
    /// `withTaskGroup` attend tous ses enfants avant de rendre la main, et
    /// `await task.value` (non `throws`) ignore l'annulation — l'échéance
    /// tombait donc dans le vide et l'attente durait pour toujours. C'est
    /// la forme exacte de `stopLiveAnalysisIfNeeded()`. Le relais
    /// d'annulation est ce qui rend ce test rapide au lieu d'infini.
    @Test func waitingOnAnUnstructuredTaskStillHonoursTheDeadline() async {
        let neverEnding = Task { try? await Task.sleep(for: .seconds(3600)) }
        let clock = ContinuousClock()
        let start = clock.now

        let outcome: EngineWatchdogOutcome<Void> = await EngineWatchdog.run(deadlineMs: 150) {
            await withTaskCancellationHandler {
                await neverEnding.value
            } onCancel: {
                neverEnding.cancel()
            }
        }

        guard case .timedOut = outcome else {
            Issue.record("l'attente d'une tâche non structurée muette doit expirer")
            return
        }
        #expect(clock.now - start < .seconds(10))
    }

    /// Un moteur jamais démarré a un flux vide : la barrière doit rendre
    /// `false` immédiatement (flux terminé, pas d'échéance à attendre) —
    /// c'est le contrat qui permet aux appelants d'ignorer le retour sans
    /// risquer un blocage.
    @Test func synchronizeOnANeverStartedEngineReturnsFalse() async {
        let controller = EngineController(type: .stockfish)
        let clock = ContinuousClock()
        let start = clock.now

        let ready = await controller.synchronize(timeoutMs: 2000)

        #expect(!ready)
        #expect(clock.now - start < .seconds(10))
        await controller.stop()
    }
}
