import CFairyStockfishKit
import CStockfishKit
import Foundation

/// Verrou global : UN SEUL test à la fois touche un moteur réel — Stockfish
/// OU Fairy-Stockfish — quelle que soit la SUITE qui le contient.
///
/// `.serialized` sur une suite ne protège qu'À L'INTÉRIEUR d'elle-même :
/// Swift Testing lance des suites DIFFÉRENTES en parallèle par défaut, et
/// `std::cin`/`std::cout` sont des ressources GLOBALES AU PROCESS — un seul
/// moteur, quel qu'il soit, peut les détourner à la fois (voir `shim.cpp` de
/// `CStockfish` ET `CFairyStockfish`, qui documentent tous deux ce contrat).
///
/// Découvert le 25/08 en ajoutant Fairy-Stockfish : les suites Chess960 et
/// Analyse (Stockfish) se corrompaient DÉJÀ entre elles ([[engine-test-suite-level-serialization]]),
/// et l'ajout de `FairyVariantPlayViewModelTests` (Fairy-Stockfish) a rendu
/// la collision systématique dès que les trois couraient dans la même
/// invocation — jusqu'à des échecs francs (aucune classification obtenue en
/// 60 s), pas seulement des données corrompues.
///
/// **Tout `@Test` qui démarre un moteur réel (`engine.start()` sur
/// `EngineController` OU `FairyEngineController`) doit envelopper son corps
/// dans ``withExclusiveAccess(_:)``.**
///
/// `@MainActor`, PAS un `actor` à part : tous les appelants (des `struct`
/// `@MainActor` — chaque suite de tests) vivent déjà sur le MainActor. Un
/// `actor` séparé forcerait la fermeture `body` à traverser une frontière
/// d'isolation — `FairyVariantPlayViewModel` etc. n'étant pas `Sendable`,
/// Swift 6 refusait de compiler (« sending value of non-Sendable type…
/// risks causing data races »). Rester sur le MÊME acteur élimine le
/// problème à la racine : plus de frontière à traverser.
@MainActor
final class EngineIntegrationGate {
    static let shared = EngineIntegrationGate()
    private init() {}

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func acquire() async {
        if !isLocked {
            isLocked = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func release() {
        if waiters.isEmpty {
            isLocked = false
        } else {
            waiters.removeFirst().resume()
        }
    }

    /// `handleViewDisappear()` (l'API réelle, appelée depuis `.onDisappear`,
    /// qui ne peut pas `await`) arrête le moteur via un `Task { await
    /// engine.stop() }` DÉTACHÉ, jamais attendu — correct pour l'app (ne pas
    /// bloquer l'UI), mais un vrai piège ici : le corps du test peut rendre
    /// la main AVANT que `cstockfish_stop()`/`cfairystockfish_stop()` n'ait
    /// fini de restaurer `std::cin`/`std::cout`. Relâcher le verrou À CE
    /// moment-là laissait le test SUIVANT démarrer un AUTRE moteur pendant
    /// que celui d'avant achevait sa démolition en tâche de fond — la
    /// redirection de flux de l'un écrasait celle de l'autre EN COURS DE
    /// ROUTE. Découvert le 25/08 : deux suites (Stockfish + Fairy-Stockfish)
    /// ensemble suffisaient à le déclencher, même chacune correctement
    /// enveloppée par ce verrou.
    ///
    /// Le correctif : ATTENDRE, après le corps du test, que les DEUX moteurs
    /// se déclarent réellement inactifs (`isProcessBusy` — l'état C++ lui-même,
    /// pas une supposition sur le timing) avant de relâcher le verrou.
    ///
    /// **Budget doublé le 25/08 (nuit)** : un budget qui abandonne
    /// silencieusement défait tout l'intérêt de cette attente — observé en
    /// suite COMPLÈTE (tests + interface) : `racingKingsEngineReplies()` a
    /// échoué avec `isEngineUnavailable`, cohérent avec un verrou relâché
    /// trop tôt pendant que l'ancien moteur finissait encore sa démolition
    /// sous charge système lourde. Aligné sur
    /// ``EngineController/acquireEngineProcess(timeoutMs:)``, doublé au même
    /// moment pour la même raison.
    private func waitForBothEnginesToGoIdle(timeoutMs: Int = 10000) async {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while Date() < deadline,
              StockfishEngine.isProcessBusy || FairyStockfishEngine.isProcessBusy {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func withExclusiveAccess<T>(_ body: () async throws -> T) async rethrows -> T {
        await acquire()
        do {
            let value = try await body()
            await waitForBothEnginesToGoIdle()
            release()
            return value
        } catch {
            await waitForBothEnginesToGoIdle()
            release()
            throw error
        }
    }
}
