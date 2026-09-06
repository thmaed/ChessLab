import ChessKit
import Foundation

/// Pourquoi Stockfish a remplacé (ou suppléé) le coup de Maia.
enum SafetyNetReason: String, Codable, Hashable, Sendable {
    /// Mat en un ou deux disponible, niveau suffisant pour le voir.
    case mate
    /// Finale à peu de pièces : Stockfish bridé au niveau du personnage.
    case endgame
    /// Le coup de Maia répétait ou laissait filer les cinquante coups en
    /// position gagnée.
    case repetition
    /// Le modèle n'a pas répondu : Stockfish bridé pour le reste de la partie.
    case unavailable
}

/// Le filet derrière Maia : QUATRE cas, bornés et écrits dans l'Aide, et
/// rien d'autre. Décisions pures, testées sur cas choisis ; l'exécution
/// (recherches Stockfish) vit dans `PlayViewModel`.
enum SafetyNet {

    /// Seuil de gain à partir duquel « répéter » est une faute et non un
    /// choix — un demi-pion ne suffit pas, deux pions oui.
    static let winningThresholdCp = 200

    /// Un mat en `mateInMoves` coups pour le camp au trait (valeur positive)
    /// est joué par Stockfish si le personnage est censé le voir.
    static func overridesForMate(policy: SafetyNetPolicy, level: Int, mateInMoves: Int?) -> Bool {
        guard let mate = mateInMoves, mate > 0, mate <= 2,
              let fromLevel = policy.mateFromLevel, level >= fromLevel
        else { return false }
        return true
    }

    /// Finale technique : à `endgamePieceLimit` pièces ou moins (rois
    /// compris), Stockfish bridé remplace Maia dès le niveau prévu.
    static func overridesEndgame(policy: SafetyNetPolicy, level: Int, pieceCount: Int) -> Bool {
        guard let fromLevel = policy.endgameFromLevel, level >= fromLevel else { return false }
        return pieceCount <= policy.endgamePieceLimit
    }

    /// Le coup de Maia conclurait la partie par répétition ou cinquante
    /// coups alors que le camp au trait est nettement gagnant.
    static func overridesRepetition(policy: SafetyNetPolicy, stateAfterMove: Board.State, moverCp: Int?) -> Bool {
        guard policy.avoidsRepetitionWhenWinning, let cp = moverCp, cp >= winningThresholdCp else { return false }
        if case let .draw(reason) = stateAfterMove {
            return reason == .repetition || reason == .fiftyMoves
        }
        return false
    }
}
