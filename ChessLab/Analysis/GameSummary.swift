import ChessKit
import Foundation

/// Le bilan chiffré d'une partie analysée : par joueur, la précision et le
/// décompte de chaque catégorie de coup. Calcul PUR à partir des
/// classifications déjà faites — aucune requête moteur, donc affichable à
/// tout moment, y compris pendant que la classification se complète.
struct GameSummary: Equatable {
    struct Side: Equatable {
        var accuracy: Double?
        var counts: [MoveQuality: Int] = [:]
        /// Nombre de coups déjà classifiés pour ce joueur.
        var classifiedCount: Int = 0

        func count(of quality: MoveQuality) -> Int {
            counts[quality] ?? 0
        }
    }

    var white = Side()
    var black = Side()
    /// Vrai tant que tous les coups de la ligne principale n'ont pas
    /// leur catégorie — le bilan l'affiche pour ne pas faire passer un
    /// décompte partiel pour un décompte définitif.
    var isComplete = false

    func side(for color: Piece.Color) -> Side {
        color == .white ? white : black
    }

    /// Agrège les classifications de la ligne principale. `qualities` est
    /// donné dans l'ordre de la partie (couleur du joueur, catégorie), ce
    /// qui suffit : le bilan ne dépend pas des index de l'arbre.
    static func compute(
        qualities: [(color: Piece.Color, quality: MoveQuality)],
        totalMainLineMoves: Int,
        accuracyByColor: [Piece.Color: Double]
    ) -> GameSummary {
        var summary = GameSummary()
        for (color, quality) in qualities {
            if color == .white {
                summary.white.counts[quality, default: 0] += 1
                summary.white.classifiedCount += 1
            } else {
                summary.black.counts[quality, default: 0] += 1
                summary.black.classifiedCount += 1
            }
        }
        summary.white.accuracy = accuracyByColor[.white]
        summary.black.accuracy = accuracyByColor[.black]
        summary.isComplete = qualities.count >= totalMainLineMoves && totalMainLineMoves > 0
        return summary
    }
}
