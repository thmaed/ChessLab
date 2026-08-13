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
        return inserting(
            tags: ["[SetUp \"1\"]", "[FEN \"\(start.fen)\"]"],
            into: raw
        )
    }

    /// Insère des tags **dans la section de tags** du PGN, et non devant tout.
    ///
    /// L'ancienne version préfixait `"[SetUp…]\n[FEN…]\n\n" + raw`. C'était
    /// correct **uniquement parce que** les parties de l'app n'ont aujourd'hui
    /// aucun tag (`game.tags` n'est jamais renseigné) : `raw` commence donc par
    /// le movetext. Le jour où un tag existe — nom des joueurs, `Result`,
    /// `Date`, ou simplement un PGN importé — le préfixe créait une
    /// **troisième section** (tags ajoutés, ligne vide, tags d'origine, ligne
    /// vide, movetext) et `PGNParser` levait `.tooManyLineBreaks` : le PGN
    /// exporté devenait irrécupérable.
    ///
    /// Un PGN est fait d'au plus deux sections séparées par une ligne vide :
    /// les tags, puis le movetext. On repère la première ligne vide ; s'il y a
    /// bien une section de tags avant elle, les nouveaux tags s'y ajoutent.
    private static func inserting(tags: [String], into raw: String) -> String {
        let lines = raw.components(separatedBy: "\n")
        let hasTagSection = lines.first?.hasPrefix("[") == true

        guard hasTagSection,
              let blankIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
        else {
            // Pas de section de tags : le PGN commence par le movetext, on en
            // crée une.
            return tags.joined(separator: "\n") + "\n\n" + raw
        }

        var merged = lines
        merged.insert(contentsOf: tags, at: blankIndex)
        return merged.joined(separator: "\n")
    }
}
