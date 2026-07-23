import ChessKit
import Foundation
import SwiftData

/// Mode de jeu à l'origine d'un ``GameRecord``.
enum GameRecordMode: String, Codable {
    case vsEngine
    case twoHuman
}

/// Une partie terminée, conservée en bibliothèque. Modèle volontairement
/// plat et compatible CloudKit dès le départ : toutes les propriétés sont
/// optionnelles ou ont une valeur par défaut, aucun `@Attribute(.unique)`,
/// aucune relation — voir PROGRESS.md pour la note sur l'activation
/// (différée) de la synchronisation iCloud réelle.
///
/// Rien ne relit encore ce modèle (la bibliothèque/parcours de parties
/// arrive avec le mode Analyser, étape 3) : on se contente de persister
/// dès maintenant pour que cette étape future ait de vraies données.
@Model
final class GameRecord {
    var id: UUID = UUID()
    var modeRaw: String? = GameRecordMode.vsEngine.rawValue
    /// Partie complète (coups + résultat) au format PGN.
    var pgn: String? = ""
    /// Texte façon PGN ("1-0", "0-1", "1/2-1/2").
    var resultRaw: String?
    /// ``GameOutcome/Reason/storageLabel``.
    var outcomeReasonRaw: String?
    var whiteName: String?
    var blackName: String?
    /// `nil` pour une partie deux humains.
    var engineColorRaw: String?
    var engineEloApprox: Int?
    var playedAt: Date? = Date()
    /// Nombre de demi-coups de la ligne principale — même unité que le
    /// « coup(s) joué(s) » de la bannière de reprise.
    ///
    /// STOCKÉ plutôt que dérivé du PGN à l'affichage : la bibliothèque peut
    /// contenir des centaines de parties, et reparser chaque PGN à chaque
    /// rendu de ligne serait absurde. Optionnel — donc migration SwiftData
    /// additive et sans risque — et `nil` pour les parties enregistrées avant
    /// ce champ ; ``GameRecord/backfillMoveCounts(in:)`` les rattrape.
    var moveCount: Int?

    init() {}

    var mode: GameRecordMode {
        GameRecordMode(rawValue: modeRaw ?? "") ?? .vsEngine
    }

    /// Compte les demi-coups de la ligne principale d'une partie.
    static func plyCount(of game: Game) -> Int {
        var count = 0
        var index = game.startingIndex
        while game.moves.hasIndex(after: index) {
            index = game.moves.index(after: index)
            count += 1
        }
        return count
    }

    /// Renseigne `moveCount` des parties enregistrées AVANT l'existence du
    /// champ, en reparsant leur PGN une seule fois.
    ///
    /// Sinon toute la bibliothèque existante afficherait un blanc jusqu'à ce
    /// que l'utilisateur rejoue — pour une donnée qui est bel et bien dans le
    /// PGN. On ne sauvegarde que si quelque chose a changé, et un PGN
    /// illisible est simplement laissé de côté (jamais de crash sur une vieille
    /// partie).
    @MainActor
    static func backfillMoveCounts(in context: ModelContext) {
        let descriptor = FetchDescriptor<GameRecord>(
            predicate: #Predicate { $0.moveCount == nil }
        )
        guard let pending = try? context.fetch(descriptor), !pending.isEmpty else { return }

        var changed = false
        for record in pending {
            guard let pgn = record.pgn, !pgn.isEmpty, let game = try? Game(pgn: pgn) else { continue }
            record.moveCount = plyCount(of: game)
            changed = true
        }
        if changed { try? context.save() }
    }
}
