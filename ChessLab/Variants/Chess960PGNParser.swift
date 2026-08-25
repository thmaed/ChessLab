import ChessKit
import Foundation

/// Décode un PGN Chess960 en une suite de coups rejouables, sur le même
/// principe que ``PGNLoader`` mais pour ``Chess960Game`` : ChessKit ne
/// comprend ni la position de départ (il ne lit jamais les tags
/// `[FEN]`/`[SetUp]`), ni le roque 960 (roi/tours câblés en dur sur
/// e1/e8/a1/h1) — voir le commentaire de tête de ``Chess960Game`` pour le
/// détail de cette incompatibilité.
///
/// ## La méthode
///
/// Pas de parseur SAN maison : pour chaque jeton du texte de coups, on
/// ESSAIE tour à tour chaque coup LÉGAL de ``Chess960Game`` (l'oracle prouvé
/// par perft) et on retient celui dont le SAN produit correspond
/// EXACTEMENT. Coûteux en apparence (une vingtaine à une quarantaine
/// d'essais par coup), négligeable en pratique — cet écran ne rejoue une
/// partie qu'une fois, pas en boucle chaude.
enum Chess960PGNParser {

    struct ParsedGame {
        let startFEN: String
        let tags: Game.Tags
        /// Un couple par coup : le SAN affiché, l'UCI qui le rejoue.
        let moves: [(san: String, uci: String)]
    }

    /// `nil` si le PGN n'a pas de position de départ Chess960 explicite
    /// (`[FEN ...]` + `[SetUp "1"]`) — sans elle, rien à rejouer de fiable.
    static func parse(_ pgn: String) -> ParsedGame? {
        guard let startFEN = fen(of: pgn) else { return nil }
        let tokens = PGNLoader.movetext(of: pgn)
        var game = Chess960Game(fen: startFEN)
        guard game != nil else { return nil }

        var moves: [(san: String, uci: String)] = []
        for token in tokens {
            guard let (san, uci) = matchingLegalMove(for: token, in: game!) else {
                // Même discipline que `PGNLoader.reconstruct` : on s'arrête
                // au premier coup illisible plutôt que de deviner — une
                // partie tronquée reste honnête, une partie mal rejouée ne
                // l'est pas.
                break
            }
            _ = game!.apply(uci: uci)
            moves.append((san, uci))
        }
        return ParsedGame(startFEN: startFEN, tags: PGNLoader.tags(of: pgn), moves: moves)
    }

    /// Essaie chaque coup légal, retient celui dont le SAN produit par
    /// ``Chess960Game`` correspond au jeton — annotations d'échec/mat
    /// comprises, puisque `apply` les ajoute déjà.
    private static func matchingLegalMove(for token: String, in game: Chess960Game) -> (san: String, uci: String)? {
        for move in game.legalMoves() {
            var trial = game
            let uci = trial.uciFor(move)
            guard let san = trial.apply(move) else { continue }
            if san == token { return (san, uci) }
        }
        return nil
    }

    /// Le champ FEN d'un tag `[FEN "..."]`, uniquement si le PGN se déclare
    /// `[SetUp "1"]` — un PGN sans cette paire n'a pas de position de départ
    /// à honorer (partie classique standard, hors du périmètre de ce module).
    private static func fen(of pgn: String) -> String? {
        var setUp = false
        var fen: String?
        for line in pgn.split(separator: "\n") where line.hasPrefix("[") {
            guard let space = line.firstIndex(of: " "),
                  let open = line.firstIndex(of: "\""),
                  let close = line.lastIndex(of: "\""), open < close
            else { continue }
            let key = String(line[line.index(after: line.startIndex)..<space])
            let value = String(line[line.index(after: open)..<close])
            if key == "SetUp", value == "1" { setUp = true }
            if key == "FEN" { fen = value }
        }
        return setUp ? fen : nil
    }
}
