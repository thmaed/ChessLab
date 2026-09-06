import ChessKit
import Foundation

/// Un coup dans le repère de Maia : celui du CAMP AU TRAIT, plateau retourné
/// quand les Noirs jouent (voir ``MaiaEncoder``). `uci` est le coup RÉEL, tel
/// que le plateau l'attend ; `index` est sa case dans le vecteur de 4 352
/// logits du modèle.
struct MaiaMove: Hashable, Sendable {
    /// Coup en notation UCI côté plateau réel (« e7e8q » pour une promotion).
    let uci: String
    /// Indice dans la sortie du modèle (0..<4352).
    let index: Int
}

/// Vocabulaire de sortie de Maia-3 : 4 096 paires de cases (origine × arrivée,
/// cases numérotées rangée par rangée depuis a1) suivies de 256 promotions
/// (colonne d'origine × colonne d'arrivée × dame/tour/fou/cavalier), toujours
/// de la 7e vers la 8e rangée puisque le plateau est retourné pour les Noirs.
///
/// Réplique exacte de `get_all_possible_moves()` et `mirror_move()` du dépôt
/// `CSSLab/maia3` — prouvée par `MaiaFixtureTests`.
enum MaiaMoveTable {
    static let pairCount = 64 * 64
    static let promotionCount = 8 * 8 * 4
    static let vocabularySize = pairCount + promotionCount

    /// Ordre des promotions dans le vocabulaire.
    static let promotionKinds: [Piece.Kind] = [.queen, .rook, .bishop, .knight]

    /// Numéro 0..63 d'une case, rangée par rangée depuis a1 — le repère de
    /// `python-chess`, donc de Maia.
    static func squareIndex(_ square: Square) -> Int {
        (square.rank.value - 1) * 8 + (square.file.number - 1)
    }

    /// La case vue depuis l'autre camp : même colonne, rangée renversée.
    static func mirrored(_ square: Square) -> Square {
        Square(file: square.file, rank: Square.Rank(9 - square.rank.value))
    }

    /// Indice du coup `from → to` (avec promotion éventuelle) dans le repère
    /// du camp au trait. `mirror` vaut vrai quand les Noirs jouent : le coup
    /// réel est d'abord renversé, comme le plateau l'a été.
    ///
    /// Rend `nil` pour une promotion qui ne part pas de la 7e rangée vers la
    /// 8e après renversement — impossible pour un coup légal, gardé par
    /// sécurité.
    static func index(from: Square, to: Square, promotion: Piece.Kind?, mirror: Bool) -> Int? {
        let start = mirror ? mirrored(from) : from
        let end = mirror ? mirrored(to) : to
        if let promotion {
            guard start.rank.value == 7, end.rank.value == 8,
                  let kindIndex = promotionKinds.firstIndex(of: promotion)
            else { return nil }
            let fileFrom = start.file.number - 1
            let fileTo = end.file.number - 1
            return pairCount + (fileFrom * 8 + fileTo) * 4 + kindIndex
        }
        return squareIndex(start) * 64 + squareIndex(end)
    }

    /// Lettre UCI d'une promotion (« q », « r », « b », « n »).
    static func promotionLetter(_ kind: Piece.Kind) -> String {
        switch kind {
        case .queen: "q"
        case .rook: "r"
        case .bishop: "b"
        case .knight: "n"
        default: ""
        }
    }
}

extension Square {
    /// Construit une case depuis sa colonne et sa rangée.
    init(file: File, rank: Rank) {
        self.init(file.rawValue + "\(rank.value)")
    }
}
