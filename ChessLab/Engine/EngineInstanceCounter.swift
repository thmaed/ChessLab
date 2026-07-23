import Foundation
import Observation
import os

/// Miroir observable de ``EngineInstanceCounter``, sur le MainActor.
///
/// Le compteur mute sous verrou depuis n'importe quel contexte — dont un
/// `deinit` hors MainActor — donc SwiftUI n'en sait rien : le marqueur de
/// l'accueil (``HomeView/engineInstanceMarker``) affichait une valeur
/// PÉRIMÉE, et le test de fuite lisait « 1 vivant » là où le moteur avait
/// été libéré (ou l'inverse). Ce miroir, mis à jour à chaque naissance/mort
/// d'instance, redonne au marqueur une valeur fiable et re-rendue.
@MainActor
@Observable
final class EngineInstanceObserver {
    static let shared = EngineInstanceObserver()
    private(set) var alive = 0
    private(set) var created = 0

    fileprivate func update(alive: Int, created: Int) {
        self.alive = alive
        self.created = created
    }
}

/// Compte les ``EngineController`` vivants (Lot 6.A).
///
/// Raison d'être : un contrôleur qui survit à son écran, c'est un Stockfish
/// qui continue de chercher à pleine puissance derrière l'interface — CPU et
/// batterie jusqu'au kill de l'app. Ce projet s'est fait avoir plusieurs fois
/// (bugs n°3 et n°9), et ces fuites sont invisibles : rien ne plante, rien ne
/// s'affiche, l'appareil chauffe.
///
/// Ce compteur ne corrige rien. Il rend la fuite VISIBLE — au log en debug, et
/// surtout vérifiable par un test qui traverse tous les modes et exige zéro
/// instance de retour à l'accueil.
///
/// Actif aussi en release (le coût est un entier atomique par création de
/// moteur, soit quelques-unes par partie), mais seul le log est en DEBUG.
final class EngineInstanceCounter: @unchecked Sendable {
    static let shared = EngineInstanceCounter()

    /// Verrou plutôt qu'acteur : `deinit` ne peut pas `await`, et un compteur
    /// qui ne saurait pas décrémenter depuis un `deinit` ne compterait rien.
    private let lock = OSAllocatedUnfairLock(initialState: State())

    private struct State {
        var alive = 0
        var created = 0
    }

    /// Nombre d'instances actuellement vivantes.
    var aliveCount: Int {
        lock.withLock { $0.alive }
    }

    /// Total créé depuis le lancement — utile pour distinguer « aucun moteur
    /// n'a fui » de « aucun moteur n'a jamais démarré », qui donnent le même
    /// `aliveCount` de zéro.
    var createdCount: Int {
        lock.withLock { $0.created }
    }

    func didCreate() {
        let (alive, created) = lock.withLock { state -> (Int, Int) in
            state.alive += 1
            state.created += 1
            return (state.alive, state.created)
        }
        publish(alive: alive, created: created)
        // ⚠️ JAMAIS `print()` ici : ChessKitEngine détourne `stdout` du
        // processus (`dup2`) pour capturer la sortie de Stockfish. Un `print`
        // se retrouverait injecté dans le flux du moteur, pris pour de l'UCI —
        // sortie corrompue, et l'app pouvait en mourir. `os_log` écrit dans le
        // sous-système unifié, hors de ce tuyau.
        #if DEBUG
        log("+1 → \(alive) instance(s) vivante(s)")
        #endif
    }

    func didRelease() {
        let (alive, created) = lock.withLock { state -> (Int, Int) in
            state.alive -= 1
            return (state.alive, state.created)
        }
        publish(alive: alive, created: created)
        #if DEBUG
        log("−1 → \(alive) instance(s) vivante(s)")
        #endif
    }

    /// Recopie l'état vers le miroir observable, sur le MainActor.
    /// `didRelease` peut être appelé depuis un `deinit` hors MainActor — d'où
    /// le saut asynchrone. Le léger différé est sans importance : le test de
    /// fuite laisse déjà du temps à la libération (elle passe par un `deinit`).
    private func publish(alive: Int, created: Int) {
        Task { @MainActor in
            EngineInstanceObserver.shared.update(alive: alive, created: created)
        }
    }

    #if DEBUG
    private let logger = Logger(subsystem: "ChessLab", category: "engine-instances")
    private func log(_ message: String) { logger.debug("\(message, privacy: .public)") }
    #endif

    /// Remet les compteurs à zéro (tests uniquement).
    func reset() {
        lock.withLock { $0 = State() }
        publish(alive: 0, created: 0)
    }
}
