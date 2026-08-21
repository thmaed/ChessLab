import ChessKit
import Foundation
import SwiftData

/// Mode de jeu à l'origine d'un ``GameRecord``.
enum GameRecordMode: String, Codable {
    case vsEngine
    case twoHuman
    /// Partie importée depuis un PGN externe (base, export d'un autre outil).
    case imported
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
final class GameRecord: Identifiable {
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

    /// Étiquettes libres posées par l'utilisateur, stockées en une seule
    /// chaîne séparée par des virgules (« ouverture,à revoir »).
    ///
    /// Un `String?` plutôt qu'un `[String]` : c'est le type le plus sûr pour
    /// un store synchronisé CloudKit (aucune transformation d'array à gérer),
    /// dans l'esprit « plat et optionnel » de ce modèle. L'accès se fait par
    /// ``tags`` qui découpe/recolle.
    var tagsCSV: String?

    // MARK: Métriques d'analyse
    //
    // Écrites une fois la ligne principale entièrement classée, pour que le
    // bilan se rouvre sans tout recalculer et que la mesure du niveau ait une
    // matière. Tous optionnels : migration additive, et `nil` veut dire « pas
    // encore analysée », ce qui est l'état de la plupart des parties.

    /// Empreinte canonique de la partie — position de départ et suite des
    /// coups (voir ``AnalysisEvalStore/key(for:)``).
    ///
    /// C'est le seul lien entre une session d'analyse et la partie enregistrée :
    /// l'écran d'analyse ne reçoit qu'un texte PGN, jamais une identité. La clé
    /// porte la partie JOUÉE, pas sa mise en forme — deux PGN aux en-têtes
    /// différents mais aux mêmes coups se retrouvent.
    var analysisKey: String?
    /// Version du barème ayant produit les chiffres ci-dessous
    /// (``GameAnalysisMetrics/currentVersion``). Ne JAMAIS moyenner des
    /// parties de versions différentes.
    var analysisVersion: Int?
    var whiteAccuracy: Double?
    var blackAccuracy: Double?
    /// Perte moyenne de probabilité de gain, hors théorie, non pondérée.
    var whiteAverageLoss: Double?
    var blackAverageLoss: Double?
    /// Coups pris en compte, hors théorie.
    var whiteClassifiedCount: Int?
    var blackClassifiedCount: Int?
    /// Coups de théorie reconnus, par camp.
    var whiteBookCount: Int?
    var blackBookCount: Int?

    init() {}

    /// Recopie les métriques d'une analyse terminée. Rend `true` si quelque
    /// chose a changé — l'appelant n'enregistre que dans ce cas.
    @discardableResult
    func apply(_ metrics: GameAnalysisMetrics, key: String?) -> Bool {
        let unchanged = analysisVersion == metrics.version
            && whiteAccuracy == metrics.white.accuracy
            && blackAccuracy == metrics.black.accuracy
            && whiteAverageLoss == metrics.white.averageLoss
            && blackAverageLoss == metrics.black.averageLoss
            && whiteClassifiedCount == metrics.white.classifiedCount
            && blackClassifiedCount == metrics.black.classifiedCount
            && (key == nil || analysisKey == key)
        guard !unchanged else { return false }

        if let key { analysisKey = key }
        analysisVersion = metrics.version
        whiteAccuracy = metrics.white.accuracy
        blackAccuracy = metrics.black.accuracy
        whiteAverageLoss = metrics.white.averageLoss
        blackAverageLoss = metrics.black.averageLoss
        whiteClassifiedCount = metrics.white.classifiedCount
        blackClassifiedCount = metrics.black.classifiedCount
        whiteBookCount = metrics.white.bookCount
        blackBookCount = metrics.black.bookCount
        return true
    }

    /// Les métriques relues, ou `nil` si la partie n'a jamais été analysée —
    /// ou l'a été sous un barème périmé, auquel cas les chiffres ne valent
    /// plus rien et il faut réanalyser.
    var analysisMetrics: GameAnalysisMetrics? {
        guard analysisVersion == GameAnalysisMetrics.currentVersion else { return nil }
        return GameAnalysisMetrics(
            white: .init(accuracy: whiteAccuracy, averageLoss: whiteAverageLoss,
                         classifiedCount: whiteClassifiedCount ?? 0,
                         bookCount: whiteBookCount ?? 0),
            black: .init(accuracy: blackAccuracy, averageLoss: blackAverageLoss,
                         classifiedCount: blackClassifiedCount ?? 0,
                         bookCount: blackBookCount ?? 0),
            version: GameAnalysisMetrics.currentVersion
        )
    }

    var mode: GameRecordMode {
        GameRecordMode(rawValue: modeRaw ?? "") ?? .vsEngine
    }

    /// Étiquettes normalisées (rognées, sans doublon, ordre conservé). En
    /// écriture : recolle en CSV, `nil` si vide.
    var tags: [String] {
        get {
            (tagsCSV ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            var seen = Set<String>()
            let cleaned = newValue
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            tagsCSV = cleaned.isEmpty ? nil : cleaned.joined(separator: ",")
        }
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
            guard let pgn = record.pgn, !pgn.isEmpty, let game = PGNLoader.game(from: pgn) else { continue }
            record.moveCount = plyCount(of: game)
            changed = true
        }
        if changed { PersistenceLog.save(context) }
    }

    /// Donne son empreinte canonique à chaque partie enregistrée avant
    /// l'existence de ce champ — sans quoi l'analyse ne saurait pas où déposer
    /// son bilan pour les parties déjà en bibliothèque.
    ///
    /// Même patron que ``backfillMoveCounts(in:)`` : une passe, seulement sur
    /// les parties concernées, et on n'enregistre que si quelque chose a
    /// bougé. Un PGN illisible est simplement laissé de côté — il le restera
    /// à la passe suivante, ce qui est sans conséquence.
    @MainActor
    static func backfillAnalysisKeys(in context: ModelContext) {
        let descriptor = FetchDescriptor<GameRecord>(
            predicate: #Predicate { $0.analysisKey == nil }
        )
        guard let pending = try? context.fetch(descriptor), !pending.isEmpty else { return }

        var changed = false
        for record in pending {
            guard let pgn = record.pgn, !pgn.isEmpty, let game = PGNLoader.game(from: pgn),
                  let key = AnalysisEvalStore.key(for: game)
            else { continue }
            record.analysisKey = key
            changed = true
        }
        if changed { PersistenceLog.save(context) }
    }
}
