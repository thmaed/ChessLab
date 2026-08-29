/// Traduction d'une FEN de moteur vers une FEN que ChessKit lit CORRECTEMENT.
///
/// ## Le piège
///
/// Fairy-Stockfish enrichit la FEN du Crazyhouse de deux façons que ChessKit
/// ne connaît pas :
///
/// - la RÉSERVE, entre crochets après le plateau — `…/RNBQKBNR[Pp] w …` ;
/// - un `~` après une pièce PROMUE, qui redeviendra un pion si on la capture
///   — `rnbQ~kbnr/…`.
///
/// ChessKit accepte ces chaînes sans broncher, et c'est exactement le
/// problème : son parseur avance d'une colonne à chaque caractère qui n'est
/// pas un chiffre, et `Square.File` PLAFONNE au-delà de la colonne h. Les
/// caractères en trop viennent donc s'empiler sur la dernière case de la
/// rangée, en la masquant. Mesuré :
///
///     rnbqkbnr/…/RNBQKBNR[Pp] w KQkq - 0 1
///       piece(at: h1)  →  pion NOIR          (la tour blanche est masquée)
///       pieces.count   →  34                 (au lieu de 32)
///       position.fen   →  …/RNBQKBNp         (la tour a disparu)
///
/// Une première sonde avait conclu à tort que « ChessKit accepte les FEN à
/// crochets » : elle vérifiait une case au MILIEU du plateau, seule zone
/// épargnée. La corruption est en fin de dernière rangée.
///
/// ## La règle
///
/// Tout ce qui part vers ChessKit passe par ``forChessKit(_:)``. Tout ce qui
/// part vers le MOTEUR garde la FEN brute — c'est elle qui porte la réserve,
/// sans laquelle le moteur ne reposerait jamais ce qu'il a capturé.
enum CrazyhouseFEN {

    /// Retire la réserve et les marques de promotion : le plateau seul, tel
    /// que ChessKit sait le lire.
    static func forChessKit(_ fen: String) -> String {
        var result = ""
        var insidePocket = false
        for character in fen {
            switch character {
            case "[": insidePocket = true
            case "]": insidePocket = false
            case "~": break                      // marque de promotion
            default: if !insidePocket { result.append(character) }
            }
        }
        return result
    }
}

/// La FEN telle que ChessKit doit la recevoir, d'où qu'elle vienne.
///
/// Deux variantes enrichissent la FEN du moteur de caractères que ChessKit ne
/// connaît pas — la réserve et les marques de promotion du Crazyhouse, la
/// lettre du mur de Barricades — et les DEUX corrompent la dernière rangée de
/// la même façon (voir ``CrazyhouseFEN``). Les écrans de variantes passent
/// donc par ici plutôt que d'appeler l'un ou l'autre nettoyage et d'oublier le
/// second le jour où une troisième variante arrivera.
enum VariantFEN {
    static func forChessKit(_ fen: String) -> String {
        BarricadesFEN.forChessKit(CrazyhouseFEN.forChessKit(fen))
    }
}
