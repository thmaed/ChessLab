import ChessKit
import Foundation

/// Un coup de personnage, arbitré : Maia propose, le filet dispose.
///
/// Partagé par le mode Jouer (`PlayViewModel`) et le Laboratoire
/// (`LabViewModel`) pour que le personnage calibré au Laboratoire soit
/// EXACTEMENT celui qui joue dans l'app — même filet, mêmes seuils.
enum MaiaTurnResolver {

    /// Ce qu'une recherche courte de Stockfish plein pot a rendu.
    struct QuickSearch: Sendable {
        let lan: String?
        /// Score du camp au trait, en centipions (mat = ±10 000).
        let cp: Int?
        /// Mat en N pour le camp au trait (négatif : il se fait mater).
        let mate: Int?
    }

    enum Decision: Equatable, Sendable {
        /// Le coup de Maia, tel quel.
        case play(String)
        /// Le coup de Stockfish à la place, et pourquoi.
        case override(String, SafetyNetReason)
        /// Finale technique : l'appelant doit lancer une recherche BRIDÉE au
        /// niveau du personnage et jouer son résultat (`.endgame`).
        case searchBridled
    }

    static func resolve(
        maiaUCI: String, quick: QuickSearch?, level: Int, pieceCount: Int,
        policy: SafetyNetPolicy, board: Board
    ) -> Decision {
        guard let quick else { return .play(maiaUCI) }
        if let best = quick.lan, SafetyNet.overridesForMate(policy: policy, level: level, mateInMoves: quick.mate) {
            return .override(best, .mate)
        }
        if SafetyNet.overridesEndgame(policy: policy, level: level, pieceCount: pieceCount) {
            return .searchBridled
        }
        if let best = quick.lan, let state = state(after: maiaUCI, on: board),
           SafetyNet.overridesRepetition(policy: policy, stateAfterMove: state, moverCp: quick.cp) {
            return .override(best, .repetition)
        }
        return .play(maiaUCI)
    }

    /// État du plateau APRÈS `lan`, sans toucher à `board`.
    static func state(after lan: String, on board: Board) -> Board.State? {
        guard lan.count >= 4 else { return nil }
        var scratch = board
        let from = Square(String(lan.prefix(2)))
        let to = Square(String(lan.dropFirst(2).prefix(2)))
        guard let made = scratch.move(pieceAt: from, to: to) else { return nil }
        if case .promotion = scratch.state {
            let kind = lan.count == 5 ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen) : .queen
            scratch.completePromotion(of: made, to: kind)
        }
        return scratch.state
    }
}
