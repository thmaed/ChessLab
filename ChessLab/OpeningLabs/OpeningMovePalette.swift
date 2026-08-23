import ChessKit
import SwiftUI

/// La couleur d'un coup, partagée par les FLÈCHES du plateau et par les
/// pastilles des listes — c'est ce lien qui rend l'écran lisible : on voit une
/// flèche bleue sur l'échiquier, on trouve la ligne bleue en dessous.
///
/// Reprend la convention déjà en place dans le lecteur d'ouvertures existant
/// (vert = coup recommandé, famille de bleus pour les variantes, rouge pour
/// les pièges, orange pour les imprécisions), extraite ici pour que l'index
/// des lignes et le lecteur Labs en parlent le même langage.
enum OpeningMovePalette {

    /// Famille de teintes PROCHES (bleu clair → indigo) pour les variantes
    /// « neutres » : assez distinctes les unes des autres pour qu'on suive une
    /// flèche, assez proches pour qu'on lise « ce sont des alternatives » et
    /// non « ce sont quatre statuts différents ».
    static let variations: [Color] = [
        Color(red: 0.353, green: 0.651, blue: 1.000),   // #5AA6FF bleu clair
        Color(red: 0.294, green: 0.518, blue: 0.949),   // #4B84F2 bleu
        Color(red: 0.290, green: 0.388, blue: 0.878),   // #4A63E0 bleu-indigo
        Color(red: 0.294, green: 0.310, blue: 0.788),   // #4B4FC9 indigo
    ]

    /// Un coup jouable et SA couleur.
    struct Colored: Identifiable {
        let edge: MoveEdge
        let color: Color
        /// Rang dans la liste (0 = coup recommandé).
        let rank: Int
        var id: String { edge.uci }
        var isRecommended: Bool { rank == 0 }
    }

    /// Colore une liste de coups déjà TRIÉE (recommandé en tête).
    static func colorize(_ edges: [MoveEdge]) -> [Colored] {
        var neutral = 0
        return edges.enumerated().map { index, edge in
            let color: Color
            if index == 0 {
                color = Theme.accent
            } else if edge.role == .trap {
                color = Theme.danger
            } else if edge.role == .inaccuracy {
                color = Theme.warning
            } else {
                color = variations[neutral % variations.count]
                neutral += 1
            }
            return Colored(edge: edge, color: color, rank: index)
        }
    }

    /// Une flèche par coup, teintée comme sa pastille. Le coup recommandé est
    /// plus épais et posé au-dessus (rang 1 = dessiné en dernier).
    static func arrows(for moves: [Colored]) -> [HintMove] {
        moves.compactMap { item in
            let uci = item.edge.uci
            guard uci.count >= 4 else { return nil }
            return HintMove(
                rank: item.isRecommended ? 1 : 2,
                from: Square(String(uci.prefix(2))),
                to: Square(String(uci.dropFirst(2).prefix(2))),
                strength: item.isRecommended ? 1.0 : 0.45,
                tint: item.color
            )
        }
    }

    /// Teinte d'un rôle, pour les étiquettes (« Piège », « Imprécision »).
    static func roleTint(_ role: MoveRole) -> Color? {
        switch role {
        case .trap: Theme.danger
        case .inaccuracy: Theme.warning
        case .refutation: Theme.violet
        case .mainLine, .sideline: nil
        }
    }

    static func roleLabel(_ role: MoveRole) -> LocalizedStringKey? {
        switch role {
        case .trap: "Piège"
        case .inaccuracy: "Imprécision"
        case .refutation: "Réfutation"
        case .mainLine, .sideline: nil
        }
    }
}
