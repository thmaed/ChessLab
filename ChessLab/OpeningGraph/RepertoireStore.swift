import Foundation
import SwiftData

/// Répertoire PERSONNEL : les ouvertures que l'utilisateur marque comme siennes,
/// pour prioriser les révisions. Fin accès CRUD sur ``RepertoireMembership``
/// (modèle synchronisé, store « Games »).
@MainActor
enum RepertoireStore {

    /// Identifiants des cours marqués au répertoire.
    static func memberIDs(in context: ModelContext) -> Set<String> {
        let all = (try? context.fetch(FetchDescriptor<RepertoireMembership>())) ?? []
        return Set(all.map(\.courseID))
    }

    static func isMember(_ courseID: String, in context: ModelContext) -> Bool {
        membership(courseID: courseID, in: context) != nil
    }

    static func membership(courseID: String, in context: ModelContext) -> RepertoireMembership? {
        var descriptor = FetchDescriptor<RepertoireMembership>(
            predicate: #Predicate { $0.courseID == courseID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Ajoute (si absent) ou retire (si présent) l'ouverture du répertoire.
    /// Retourne l'état résultant (`true` = désormais au répertoire).
    @discardableResult
    static func toggle(courseID: String, side: OpeningSide, in context: ModelContext) -> Bool {
        if let existing = membership(courseID: courseID, in: context) {
            context.delete(existing)
            PersistenceLog.save(context)
            return false
        }
        context.insert(RepertoireMembership(courseID: courseID, sideRaw: side.rawValue, isFavorite: true))
        PersistenceLog.save(context)
        return true
    }
}
