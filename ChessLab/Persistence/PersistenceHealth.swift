import Foundation
import OSLog
import Observation
import SwiftData

/// Santé de la persistance : le compteur d'échecs d'enregistrement et l'état
/// « session sans base » — ce que la bannière de l'accueil lit.
///
/// Arbitré le 18/08 (bug18aout §4) : vingt-et-un « try? save » silencieux
/// avalaient leurs erreurs — un disque plein passait inaperçu, l'utilisateur
/// croyait sa partie enregistrée. Désormais chaque sauvegarde passe par
/// ``PersistenceLog/save(_:origin:)`` : tentée pareil, journalisée en cas
/// d'échec, et la bannière se lève à partir du DEUXIÈME échec consécutif —
/// un échec isolé peut être un caprice, deux sont un état.
@Observable
@MainActor
final class PersistenceHealth {
    static let shared = PersistenceHealth()

    private(set) var consecutiveFailures = 0
    /// Vrai quand le conteneur n'a pas pu s'ouvrir et que la session tourne
    /// en mémoire (bug18aout §3) : rien ne sera enregistré, il faut le dire.
    var isDegradedSession = false

    var showsBanner: Bool { consecutiveFailures >= 2 || isDegradedSession }

    func recordSuccess() { consecutiveFailures = 0 }
    func recordFailure() { consecutiveFailures += 1 }
}

/// Le point de sauvegarde UNIQUE : même geste qu'avant (meilleur effort,
/// jamais bloquant), plus la mémoire de ce qui s'est passé.
enum PersistenceLog {
    private static let logger = Logger(subsystem: "com.chesslab.ChessLab", category: "persistence")

    @MainActor
    static func save(_ context: ModelContext, origin: String = #fileID) {
        do {
            try context.save()
            PersistenceHealth.shared.recordSuccess()
        } catch {
            logger.error("Échec d'enregistrement depuis \(origin, privacy: .public) : \(error, privacy: .public)")
            PersistenceHealth.shared.recordFailure()
        }
    }

    /// Variante pour le travail de FOND (seeder de puzzles) : même journal,
    /// mais le succès ne REMET PAS le compteur à zéro — un lot de fond qui
    /// passe ne dit rien de la santé des enregistrements que l'utilisateur
    /// attend, et masquerait un vrai problème en cours.
    static func saveInBackground(_ context: ModelContext, origin: String = #fileID) {
        do {
            try context.save()
        } catch {
            logger.error("Échec d'enregistrement (fond) depuis \(origin, privacy: .public) : \(error, privacy: .public)")
            Task { @MainActor in PersistenceHealth.shared.recordFailure() }
        }
    }
}

/// Posé UNE fois au démarrage, avant tout MainActor : le conteneur est-il
/// retombé en mémoire ? (`ChessLabApp.makeContainer` est statique et
/// synchrone, la bannière ne peut pas être prévenue directement.)
enum SessionDegradation {
    nonisolated(unsafe) static var isInMemory = false
}
