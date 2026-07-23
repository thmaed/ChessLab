import ChessKit

/// Produit un PGN **rechargeable** pour une partie.
///
/// `ChessKit.Game.pgn` n'émet PAS les tags `[SetUp "1"]` / `[FEN "…"]`
/// quand la partie démarre d'une position non standard : rechargée via
/// `Game(pgn:)`, elle rejouerait ses coups depuis la position STANDARD
/// (positions absurdes). On ajoute donc ces tags explicitement pour toute
/// position de départ personnalisée — mode Jouer « à partir d'ici »,
/// Laboratoire à FEN, etc. Voir instructions.md §A11.
enum PGNExport {
    static func pgn(for game: Game) -> String {
        let raw = game.pgn
        guard
            let start = game.positions[game.startingIndex],
            start.fen != Position.standard.fen,
            !raw.contains("[FEN ") // tags déjà présents : ne pas dupliquer
        else {
            return raw
        }
        return "[SetUp \"1\"]\n[FEN \"\(start.fen)\"]\n\n" + raw
    }
}
