import ChessKit
import Foundation

/// Normalisation canonique d'une FEN en CLÉ de graphe/progression.
///
/// RÈGLE ARCHITECTURALE FONDAMENTALE du module : la progression de
/// l'utilisateur est indexée par cette clé, jamais par identifiant d'ouverture
/// ni index de coup. Conséquence directe : régénérer/corriger/approfondir les
/// arbres pendant des années ne détruit jamais le travail de mémorisation —
/// une position déjà apprise reste apprise même si l'arbre qui la contient est
/// reconstruit.
///
/// La clé retient les 4 premiers champs FEN (placement, trait, roques, prise
/// en passant) et JETTE les compteurs (demi-coups, coups) : deux ordres de
/// coups menant à la même position doivent produire la même clé (fusion des
/// transpositions).
///
/// - important: Le champ « en passant » est CANONICALISÉ — conservé seulement
///   si une prise en passant est réellement légale dans la position, sinon
///   « - ». ChessKit émet toujours la case e.p. après un double-pas, qu'un
///   preneur existe ou non ; sans cette canonicalisation, une même position
///   atteinte par deux chemins (l'un laissant une case e.p. sans preneur)
///   ne fusionnerait pas. Cette sémantique est alignée sur `python-chess`
///   (`board.fen()`) côté générateur, pour que les clés coïncident des deux
///   côtés.
enum OpeningFENKey {

    /// Clé canonique d'une position ChessKit.
    static func key(for position: Position) -> String {
        let fields = position.fen.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 4 else { return position.fen }
        let ep = canonicalEnPassant(field: fields[3], position: position)
        return "\(fields[0]) \(fields[1]) \(fields[2]) \(ep)"
    }

    /// Normalise une FEN quelconque (4 à 6 champs) en clé canonique, ou `nil`
    /// si la FEN est invalide (illisible par ChessKit).
    static func normalize(_ fen: String) -> String? {
        guard let position = position(from: fen) else { return nil }
        return key(for: position)
    }

    /// Parse une FEN de 4 à 6 champs — les compteurs manquants sont complétés
    /// (« 0 1 ») pour satisfaire le parseur ChessKit qui exige 6 champs.
    ///
    /// Rejette (`nil`) une FEN qui ne décrit pas une vraie position d'échecs :
    /// le parseur de ChessKit est TRÈS permissif (il transforme une chaîne
    /// quelconque à 6 jetons en échiquier vide sans erreur), donc on exige au
    /// minimum la présence des deux rois — ce qui suffit à écarter le bruit et
    /// à rendre significatif le contrôle `invalidFEN` du validateur.
    static func position(from fen: String) -> Position? {
        let fieldCount = fen.split(separator: " ", omittingEmptySubsequences: false).count
        let padded: String
        switch fieldCount {
        case 4: padded = fen + " 0 1"
        case 5: padded = fen + " 1"
        default: padded = fen
        }
        guard let position = Position(fen: padded) else { return nil }
        let hasWhiteKing = position.pieces.contains { $0.kind == .king && $0.color == .white }
        let hasBlackKing = position.pieces.contains { $0.kind == .king && $0.color == .black }
        guard hasWhiteKing, hasBlackKing else { return nil }
        return position
    }

    /// Retourne le champ e.p. tel quel s'il correspond à une prise réellement
    /// légale, sinon « - ».
    private static func canonicalEnPassant(field: String, position: Position) -> String {
        guard field != "-", field.count == 2,
              hasLegalEnPassant(target: Square(field), position: position)
        else {
            return "-"
        }
        return field
    }

    /// Vrai si un pion du camp au trait peut légalement capturer en passant sur
    /// `target`. On s'appuie sur la génération de coups légaux publique de
    /// ChessKit (qui inclut bien la prise en passant) : une case e.p. figure
    /// dans les cibles légales d'un pion uniquement en tant que prise e.p. (la
    /// case est vide et un pion ne s'y déplace pas autrement).
    private static func hasLegalEnPassant(target: Square, position: Position) -> Bool {
        let board = Board(position: position)
        let mover = position.sideToMove
        for square in Square.allCases {
            guard let piece = position.piece(at: square),
                  piece.color == mover, piece.kind == .pawn
            else { continue }
            if board.legalMoves(forPieceAt: square).contains(target) { return true }
        }
        return false
    }
}
