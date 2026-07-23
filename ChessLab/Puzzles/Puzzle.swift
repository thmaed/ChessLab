import Foundation
import SwiftData

/// Thème tactique d'un puzzle. Pour un puzzle issu de vos parties,
/// heuristique simple et best effort (voir ``PuzzleThemeDetector``) ;
/// pour un puzzle de la bibliothèque Lichess, thème déjà fourni et
/// vérifié par la communauté (voir ``LichessPuzzleLoader``). `.tactic`
/// est le repli générique quand rien de plus spécifique n'est détecté.
enum PuzzleTheme: String, Codable, CaseIterable {
    case checkmate
    case hangingPiece
    case fork
    case pin
    case skewer
    case discoveredAttack
    case sacrifice
    case tactic

    var label: String {
        switch self {
        case .checkmate: "Mat"
        case .hangingPiece: "Pièce en prise"
        case .fork: "Fourchette"
        case .pin: "Clouage"
        case .skewer: "Enfilade"
        case .discoveredAttack: "Attaque à la découverte"
        case .sacrifice: "Sacrifice"
        case .tactic: "Tactique"
        }
    }

    /// Sert à distinguer visuellement les groupes de la file "dus" une
    /// fois regroupés par thème (voir ``PuzzleQueueView``) — purement
    /// décoratif, aucune signification au-delà du thème lui-même.
    var icon: String {
        switch self {
        case .checkmate: "flag.checkered"
        case .hangingPiece: "exclamationmark.triangle.fill"
        case .fork: "arrow.triangle.branch"
        case .pin: "pin.fill"
        case .skewer: "arrow.left.and.right"
        case .discoveredAttack: "eye.fill"
        case .sacrifice: "flame.fill"
        case .tactic: "puzzlepiece.fill"
        }
    }
}

/// Provenance d'un puzzle : détecté dans une de vos parties analysées,
/// ou issu de la bibliothèque Lichess embarquée (voir
/// ``LichessPuzzleLoader``).
enum PuzzleSource: String, Codable {
    case ownGames
    case lichess
}

/// Un puzzle généré depuis une gaffe/erreur détectée en mode Analyser.
/// Modèle volontairement plat et compatible CloudKit dès le départ, même
/// discipline que ``GameRecord`` : propriétés optionnelles ou valeurs
/// par défaut, aucune contrainte unique, aucune relation.
///
/// - important: `sourceGamePGN` stocke le PGN COMPLET de la partie
/// d'origine (pas un identifiant vers un ``GameRecord``) : les points
/// d'entrée actuels de ``AnalysisSource`` (PGN collé, FEN, bibliothèque…)
/// ne font pas tous correspondre un `GameRecord.id` récupérable au
/// moment de l'analyse, alors que le texte PGN, lui, est toujours
/// disponible — "voir dans la partie d'origine" réimporte directement ce
/// texte plutôt que de chercher une correspondance.
@Model
final class Puzzle {
    var id: UUID = UUID()
    /// Position juste avant le coup fautif (c'est à ce joueur de trouver
    /// mieux).
    var fen: String? = ""
    /// Le coup réellement joué dans la partie (le mauvais), en SAN.
    var playedMoveSAN: String?
    /// Séquence forcée complète attendue, en LAN, en alternant
    /// solution/riposte adverse — `solutionLANs[0]` est le coup à
    /// trouver.
    var solutionLANs: [String]? = []
    var themeRaw: String?
    /// Phase de partie (``GamePhase``) calculée UNE FOIS depuis le FEN,
    /// au préchargement/à la création — stockée pour que le filtre par
    /// phase soit une simple comparaison de chaîne dans un `#Predicate`,
    /// pas une classification de ~50 000 FEN à chaque tap de pastille
    /// (voir ``PuzzleSessionDrawer``). `nil` pour un puzzle créé avant ce
    /// champ (rattrapé par ``PuzzleLibrarySeeder``).
    var phaseRaw: String?
    /// `nil` pour un puzzle issu de vos parties (voir `sourceGamePGN`),
    /// une partie n'a pas de note de difficulté a priori. Fourni par
    /// Lichess pour les puzzles de la bibliothèque embarquée.
    var rating: Int?
    /// `nil` pour un puzzle de la bibliothèque Lichess — pas de partie
    /// d'origine à afficher (voir `PuzzleSolveView`, bouton "Voir dans
    /// la partie d'origine" masqué si `nil`).
    var sourceGamePGN: String?
    var sourceRaw: String?
    /// Identifiant Lichess (`PuzzleId`) pour un puzzle de la
    /// bibliothèque embarquée — `nil` pour une gaffe issue de vos
    /// parties. Sert de clé naturelle pour un réamorçage idempotent de
    /// la bibliothèque (voir ``PuzzleLibrarySeeder``), indépendant du
    /// marqueur `UserDefaults`.
    var externalID: String?
    /// Date de la toute première présentation de ce puzzle à
    /// l'utilisateur (écran de résolution réellement ouvert, pas
    /// seulement listé) — `nil` tant qu'il n'a jamais été ouvert. Sert à
    /// donner la priorité aux puzzles inédits dans la file "dus" avant
    /// de répéter un puzzle déjà vu (voir ``PuzzleQueueView``).
    var firstOpenedAt: Date?
    var createdAt: Date? = Date()

    // MARK: Répétition espacée (SM-2 simplifié, voir ``SpacedRepetition``)

    var easinessFactor: Double? = 2.5
    var intervalDays: Int? = 0
    var repetitions: Int? = 0
    var dueDate: Date? = Date()
    var successCount: Int? = 0
    var failureCount: Int? = 0

    init() {}

    var theme: PuzzleTheme {
        PuzzleTheme(rawValue: themeRaw ?? "") ?? .tactic
    }

    /// `.ownGames` par défaut (les puzzles existants avant l'ajout de ce
    /// champ n'ont pas de `sourceRaw` — tous issus de parties perso à
    /// l'époque).
    var source: PuzzleSource {
        PuzzleSource(rawValue: sourceRaw ?? "") ?? .ownGames
    }

    /// Lit `phaseRaw` (stockée, filtrable en base) et ne retombe sur la
    /// classification du FEN que pour un enregistrement d'avant ce champ
    /// pas encore rattrapé par le seeder.
    var phase: GamePhase {
        if let phaseRaw, let stored = GamePhase(rawValue: phaseRaw) {
            return stored
        }
        return GamePhaseClassifier.classify(fen: fen ?? "")
    }

    var difficultyTier: DifficultyTier? {
        DifficultyTier.tier(forRating: rating)
    }
}
