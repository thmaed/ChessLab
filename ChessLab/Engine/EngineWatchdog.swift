import Foundation

/// Issue d'une opération moteur surveillée : elle a rendu sa valeur, ou
/// l'échéance est tombée avant — auquel cas le moteur est considéré MUET
/// (planté, gelé, flux cassé) et l'appelant doit le redémarrer.
enum EngineWatchdogOutcome<T: Sendable>: Sendable {
    case finished(T)
    case timedOut
}

/// Chien de garde des attentes moteur.
///
/// Toute la discipline de l'app repose sur « chaque consommateur lit le
/// flux jusqu'à SON `bestmove` ». Quand Stockfish se fige, ce `bestmove`
/// n'arrive jamais : la boucle de lecture attend pour toujours, la file
/// sérielle du mode reste bloquée derrière elle, et l'écran est mort sans
/// le moindre message. Ce type borne ces attentes : l'opération est mise
/// en course contre une échéance, et la première arrivée gagne.
///
/// L'annulation suffit à conclure le perdant : l'itération d'un
/// `AsyncStream` se termine à l'annulation de sa tâche, il n'y a donc pas
/// de lecteur fantôme qui resterait accroché au flux. Si le moteur n'était
/// que LENT (pas mort), son `bestmove` tardif arrivera sans consommateur —
/// c'est exactement ce que la barrière `synchronize()` évacue avant chaque
/// nouvelle recherche.
enum EngineWatchdog {
    /// Marge accordée AU-DELÀ du budget de recherche demandé avant de
    /// déclarer le moteur muet. Large à dessein : un appareil chargé ou en
    /// surchauffe peut légitimement étirer un `movetime` — un faux
    /// positif redémarrerait un moteur sain en pleine partie.
    static let graceMs = 8000

    /// Fait courir `operation` contre une échéance de `deadlineMs`.
    ///
    /// `operation` hérite du contexte d'acteur de l'appelant (MainActor
    /// pour les view models, l'acteur moteur pour `EngineController`) :
    /// les boucles de lecture existantes s'y glissent sans réécriture.
    static func run<T: Sendable>(
        deadlineMs: Int,
        @_inheritActorContext operation: @escaping @Sendable () async -> T
    ) async -> EngineWatchdogOutcome<T> {
        await withTaskGroup(of: EngineWatchdogOutcome<T>.self) { group in
            group.addTask { .finished(await operation()) }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(max(deadlineMs, 1)) * 1_000_000)
                return .timedOut
            }
            // La première arrivée fait foi ; l'autre tâche est annulée —
            // ce qui termine proprement une lecture de flux en attente.
            let first = await group.next() ?? .timedOut
            group.cancelAll()
            return first
        }
    }
}
