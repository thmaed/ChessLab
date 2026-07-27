import Foundation
import SwiftData

/// Progression PERSONNELLE d'un puzzle de la bibliothèque Lichess, dans un
/// modèle SÉPARÉ et SYNCHRONISÉ via iCloud (store « Games »).
///
/// Pourquoi séparé de ``Puzzle`` : la bibliothèque embarquée (~100 000
/// puzzles, identique sur chaque appareil) reste LOCALE — la pousser dans
/// iCloud l'inondait (CKError 429). Seule cette progression, petite et
/// personnelle (quelques centaines d'entrées), voyage entre les appareils.
///
/// Clé = ``externalID`` (identifiant Lichess du puzzle), stable et identique
/// partout puisque la bibliothèque est embarquée. Les puzzles issus de VOS
/// parties (sans `externalID`) sont locaux par nature — ils ne sont pas
/// mirrorés ici.
///
/// Ce modèle est un MIROIR : ``PuzzleProgressSync`` l'écrit à chaque
/// résolution et le réconcilie dans les ``Puzzle`` locaux (que la file
/// d'attente, la répétition espacée et les stats continuent de lire, sans
/// rien changer à leur logique). Compatible CloudKit : propriétés à valeur
/// par défaut, aucune contrainte unique, aucune relation.
@Model
final class PuzzleProgress {
    var externalID: String = ""
    var successCount: Int = 0
    var failureCount: Int = 0
    var easinessFactor: Double = 2.5
    var intervalDays: Int = 0
    var repetitions: Int = 0
    var dueDate: Date?
    var firstOpenedAt: Date?
    /// Dernière mise à jour — départage les états au moment du merge.
    var updatedAt: Date = Date()

    init(externalID: String) {
        self.externalID = externalID
    }
}
