import UIKit

/// Empêche la mise en veille pendant une série de laboratoire (Lot 2.D).
///
/// Une série de 20 parties dure plusieurs minutes sans le moindre contact avec
/// l'écran : l'appareil s'endort, iOS suspend l'app, et la série s'arrête au
/// milieu. C'est le seul écran de l'app qui travaille sans qu'on le touche.
///
/// **Ne JAMAIS laisser fuiter `isIdleTimerDisabled = true`** : ce serait un
/// appareil qui ne s'endort plus, longtemps après avoir quitté l'app — le
/// genre de bug qu'on attribue à autre chose et qui vide une batterie. D'où le
/// `deinit` : même si un chemin d'annulation oubliait de désactiver le garde,
/// la libération de la série le fait. On ne se repose pas sur la discipline
/// des appelants pour une ressource globale.
@MainActor
final class IdleTimerGuard {
    private(set) var isActive = false

    /// Injectable : `UIApplication.shared` est un état GLOBAL, qu'un test ne
    /// peut ni lire sans effet de bord ni remettre proprement.
    private let apply: (Bool) -> Void

    init(apply: @escaping (Bool) -> Void = IdleTimerGuard.systemDefault()) {
        self.apply = apply
    }

    /// Le blocage de veille, par plateforme.
    ///
    /// Sur Mac (Catalyst), `isIdleTimerDisabled` existe mais ne fait RIEN : la
    /// veille système se retient par une « activité » `ProcessInfo`, qui rend
    /// un jeton qu'il faut garder pour pouvoir la relâcher — d'où la petite
    /// boîte, une fermeture `(Bool) -> Void` ne pouvant pas porter d'état.
    /// Sans ça, une série de laboratoire s'interromprait sur Mac exactement
    /// comme elle le faisait sur iPhone avant le lot 2.D.
    private static func systemDefault() -> (Bool) -> Void {
        #if targetEnvironment(macCatalyst)
        final class Held { var token: NSObjectProtocol? }
        let held = Held()
        return { active in
            if active {
                guard held.token == nil else { return }
                held.token = ProcessInfo.processInfo.beginActivity(
                    options: .idleSystemSleepDisabled,
                    reason: "Série de parties du laboratoire"
                )
            } else if let token = held.token {
                ProcessInfo.processInfo.endActivity(token)
                held.token = nil
            }
        }
        #else
        return { UIApplication.shared.isIdleTimerDisabled = $0 }
        #endif
    }

    func enable() {
        guard !isActive else { return }
        isActive = true
        apply(true)
    }

    func disable() {
        guard isActive else { return }
        isActive = false
        apply(false)
    }

    deinit {
        // Pas de saut d'acteur ici : `isIdleTimerDisabled` doit revenir à
        // `false` MAINTENANT, pas au prochain tour de boucle. `deinit` d'un
        // objet `@MainActor` s'exécute déjà sur le fil principal en pratique,
        // et un `Task { }` risquerait de ne jamais s'exécuter si l'app se
        // termine dans la foulée.
        if isActive {
            MainActor.assumeIsolated { apply(false) }
        }
    }
}
