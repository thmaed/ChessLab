import ChessKit
import Foundation

/// Construit la position « et si je passais mon tour ? » — celle qui révèle
/// la MENACE de l'adversaire (Lot 5.G, demandé par le prompt).
///
/// Pur et testable : c'est du texte FEN, pas du moteur.
enum ThreatPosition {

    /// Rend le FEN de la même position, trait donné à l'adversaire.
    ///
    /// - returns: `nil` quand la position obtenue n'a pas de sens :
    ///   - le camp qui reçoit le trait laisserait un roi en PRISE (l'autre roi
    ///     est en échec) — passer son tour est alors impossible, et Stockfish
    ///     répondrait n'importe quoi sur une position illégale ;
    ///   - le FEN d'entrée est illisible.
    ///
    ///   Le prompt interdit d'envoyer un FEN illégal au moteur : c'est
    ///   ``FENValidator`` qui tranche, la même autorité que partout ailleurs.
    static func fenWithSideToMoveFlipped(_ fen: String) -> String? {
        let fields = fen.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard fields.count == 6 else { return nil }

        var flipped = fields
        flipped[1] = fields[1] == "w" ? "b" : "w"
        // La case en passant est un DROIT du camp au trait, valable pour ce
        // seul coup : la garder après avoir passé la main produirait un FEN
        // incohérent (et un coup en passant fantôme).
        flipped[3] = "-"

        let candidate = flipped.joined(separator: " ")
        guard FENValidator.isLegal(candidate) else { return nil }
        return candidate
    }
}
