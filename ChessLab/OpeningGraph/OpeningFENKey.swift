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
        let castling = canonicalCastling(field: fields[2], position: position)
        let ep = canonicalEnPassant(field: fields[3], position: position)
        return "\(fields[0]) \(fields[1]) \(castling) \(ep)"
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

    /// Canonicalise le champ des roques : on ne garde un droit que si le roi ET
    /// la tour concernés sont TOUJOURS sur leur case d'origine.
    ///
    /// - important: ChessKit conserve à tort un droit de roque quand la tour
    ///   concernée est CAPTURÉE sur sa case initiale (ex. …Txa8 : les Noirs
    ///   gardent « q » alors que la tour a8 n'existe plus). `python-chess`, lui,
    ///   retire le droit — d'où une divergence de clé qui casserait la fusion
    ///   des transpositions et la navigation du lecteur. On filtre donc chaque
    ///   droit déjà émis par ChessKit sur la présence réelle des pièces : on ne
    ///   fait que RETIRER un droit fantôme, jamais en accorder un (le filtre est
    ///   borné par le champ ChessKit, qui retire bien les droits quand roi/tour
    ///   se DÉPLACENT). Sémantique alignée sur `board.fen()` de python-chess.
    private static func canonicalCastling(field: String, position: Position) -> String {
        guard field != "-" else { return "-" }
        func present(_ kind: Piece.Kind, _ color: Piece.Color, at squareName: String) -> Bool {
            guard let piece = position.piece(at: Square(squareName)) else { return false }
            return piece.kind == kind && piece.color == color
        }
        let whiteKingHome = present(.king, .white, at: "e1")
        let blackKingHome = present(.king, .black, at: "e8")
        var result = ""
        if field.contains("K"), whiteKingHome, present(.rook, .white, at: "h1") { result += "K" }
        if field.contains("Q"), whiteKingHome, present(.rook, .white, at: "a1") { result += "Q" }
        if field.contains("k"), blackKingHome, present(.rook, .black, at: "h8") { result += "k" }
        if field.contains("q"), blackKingHome, present(.rook, .black, at: "a8") { result += "q" }
        return result.isEmpty ? "-" : result
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
    /// `target`.
    ///
    /// - important: la case e.p. d'une position légitime est TOUJOURS vide (le
    ///   pion preneur s'y déplace) ; et un pion ne l'atteint que par une prise
    ///   DIAGONALE. On exige donc case vide + pion sur une AUTRE colonne, sinon
    ///   un champ e.p. périmé pointant sur une case désormais occupée (ex. juste
    ///   après une prise e.p.) ferait passer une prise normale (…gxf6) pour une
    ///   prise en passant. Sans ces gardes, la clé retiendrait une case e.p.
    ///   fantôme et divergerait de `python-chess` côté générateur.
    private static func hasLegalEnPassant(target: Square, position: Position) -> Bool {
        guard position.piece(at: target) == nil else { return false }
        let board = Board(position: position)
        let mover = position.sideToMove
        for square in Square.allCases {
            guard let piece = position.piece(at: square),
                  piece.color == mover, piece.kind == .pawn,
                  square.file != target.file
            else { continue }
            if board.legalMoves(forPieceAt: square).contains(target) { return true }
        }
        return false
    }
}
