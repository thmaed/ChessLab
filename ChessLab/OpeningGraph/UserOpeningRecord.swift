import Foundation
import SwiftData

/// Un répertoire PERSONNEL, synchronisé.
///
/// ## Pourquoi un blob et non un graphe modélisé
///
/// Le cours est rangé tel quel, en JSON encodé (`payload`), plutôt qu'éclaté
/// en une centaine d'enregistrements « position ». Trois raisons :
///
/// 1. **Le fichier EST déjà le répertoire.** C'est le format de partage, celui
///    qu'on exporte et qu'on importe. Le dupliquer en modèle relationnel
///    créerait deux vérités à tenir d'accord.
/// 2. **Un répertoire s'édite d'un bloc, par une seule personne.** Éclater le
///    graphe multiplierait la surface de conflit CloudKit sans rien apporter :
///    personne n'édite la même variante depuis deux appareils à la fois.
/// 3. **La progression, elle, reste granulaire** (``OpeningPositionProgress``,
///    une entrée par position). C'est LÀ que les conflits comptent, et c'est
///    déjà traité — la mémorisation est attachée aux positions, jamais aux
///    fichiers.
///
/// Contraintes CloudKit respectées comme pour les autres modèles synchronisés :
/// toutes les propriétés ont une valeur par défaut, aucune contrainte unique,
/// aucune relation. `updatedAt` départage au merge — la version la plus récente
/// fait foi.
@Model
final class UserOpeningRecord {
    /// Identifiant du cours (`user-…`), stable d'un appareil à l'autre.
    var id: String = ""
    /// Recopié hors du blob pour lister sans tout décoder.
    var name: String = ""
    /// Dernière modification — résolution de conflit multi-appareils.
    var updatedAt: Date = Date()
    /// Le cours complet, encodé au format d'échange.
    var payload: Data = Data()

    init(id: String, name: String, payload: Data, updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.payload = payload
        self.updatedAt = updatedAt
    }

    /// Cours décodé, ou `nil` si le blob est illisible — même discipline
    /// défensive que le chargeur des cours embarqués : une entrée abîmée est
    /// ignorée, jamais fatale.
    var course: OpeningCourse? {
        try? OpeningCourseLoader.decodeCourse(from: payload)
    }
}
