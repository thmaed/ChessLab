import ChessKit
import Foundation

/// Produit un PGN **complet et rechargeable** pour une partie.
///
/// Deux manques, corrigés ici :
///
/// 1. `ChessKit.Game.pgn` n'émet PAS les tags `[SetUp "1"]` / `[FEN "…"]`
///    quand la partie démarre d'une position non standard : rechargée via
///    `Game(pgn:)`, elle rejouerait ses coups depuis la position STANDARD
///    (positions absurdes). Voir instructions.md §A11.
/// 2. L'app ne renseignait aucune balise : le partage sortait une suite de
///    coups nue, sans joueurs, sans date, sans résultat — pas un PGN au sens
///    du standard, et plusieurs logiciels le refusent. Un testeur l'a signalé
///    le 27/09/2026 (« no pgn tags, no result »). Les appelants passent
///    désormais un ``Metadata`` et l'export porte les sept balises
///    obligatoires (*Seven Tag Roster*).
///
/// Les balises se posent sur une COPIE du `Game` : `PGNParser` les sérialise
/// alors lui-même, dans l'ordre du standard, et ajoute le résultat en fin de
/// mouvement. On n'insère plus de texte à la main dans le PGN — c'était la
/// source d'un défaut de voisinage corrigé en juillet (une troisième section
/// et le fichier devenait illisible).
enum PGNExport {

    /// Les en-têtes d'une partie exportée.
    ///
    /// Tout est optionnel sauf les deux joueurs : une position analysée sans
    /// partie n'a ni date ni résultat à déclarer, et il vaut mieux une balise
    /// absente qu'une balise fausse.
    struct Metadata {
        /// `[Event]` — chez nous le MODE de jeu, dans la langue de l'app,
        /// comme « Live Chess » chez d'autres.
        var event: String
        /// `[Site]` — le nom de l'app. Pas d'URL : rien ne sort de l'appareil.
        var site: String = "ChessLab"
        /// `[Date]`, sérialisée « AAAA.MM.JJ ». `nil` = date inconnue, notée
        /// « ????.??.?? » comme le prévoit le standard — une partie importée
        /// sans date ne doit pas hériter de celle du jour où on l'a relue.
        var date: Date? = Date()
        /// `[Round]` — « - » quand la notion n'a pas de sens, comme le prévoit
        /// le standard.
        var round: String = "-"
        var white: String
        var black: String
        /// `[Result]` — « * » (partie en cours ou inconnue) si `nil`.
        var result: String?
        /// `[Variant]` — Chess960, Horde… ; absent aux échecs orthodoxes.
        var variant: String?

        /// Partie contre le moteur : c'est la couleur de l'utilisateur qui
        /// décide de quel côté son nom se range.
        @MainActor
        static func vsEngine(
            userColor: Piece.Color, engineName: String, result: String?, date: Date = Date()
        ) -> Metadata {
            Metadata(
                event: LocalizationController.string("Contre l'ordinateur"),
                date: date,
                white: userColor == .white ? PlayerName.you : engineName,
                black: userColor == .black ? PlayerName.you : engineName,
                result: result
            )
        }

        /// Partie à deux sur le même appareil : les noms viennent de l'écran
        /// de réglages.
        @MainActor
        static func twoPlayer(
            whiteName: String, blackName: String, result: String?, date: Date = Date()
        ) -> Metadata {
            Metadata(
                event: LocalizationController.string("Deux joueurs"),
                date: date,
                white: whiteName,
                black: blackName,
                result: result
            )
        }
    }

    /// Le PGN à partager, à copier ou à ranger en bibliothèque.
    ///
    /// Sans `metadata`, seuls `[SetUp]`/`[FEN]` sont éventuellement ajoutés —
    /// c'est le contrat d'origine, celui des appelants qui n'ont rien à dire
    /// des joueurs (le Laboratoire écrit ses propres en-têtes, l'analyse
    /// republie un PGN qui porte déjà les siennes).
    static func pgn(for game: Game, metadata: Metadata? = nil) -> String {
        var copy = game
        if let metadata { fill(&copy.tags, from: metadata) }
        declareStartingPosition(of: &copy)
        return copy.pgn
    }

    // MARK: PGN assemblés à la main (variantes)

    /// Les lignes de balises d'un PGN qu'on assemble SOI-MÊME.
    ///
    /// Les variantes n'ont pas de `ChessKit.Game` à sérialiser — le canard, le
    /// coup volé et les variantes Fairy-Stockfish sortent du modèle de
    /// ChessKit —, elles construisent donc leur texte ligne à ligne. Elles
    /// déclaraient jusqu'ici l'événement, la variante et le résultat, mais ni
    /// les joueurs ni la date : le même manque que dans les modes ordinaires,
    /// signalé par un testeur le 27/09/2026.
    ///
    /// Ordre du standard : les sept balises obligatoires d'abord, puis ce qui
    /// décrit la variante et sa position de départ.
    static func tagLines(
        event: String, white: String, black: String, result: String?,
        variant: String? = nil, startFEN: String? = nil, date: Date = Date()
    ) -> [String] {
        var lines = [
            tag("Event", event),
            tag("Site", "ChessLab"),
            tag("Date", pgnDate(date)),
            tag("Round", "-"),
            tag("White", white),
            tag("Black", black),
            tag("Result", result ?? "*"),
        ]
        if let variant { lines.append(tag("Variant", variant)) }
        if let startFEN {
            lines.append(tag("SetUp", "1"))
            lines.append(tag("FEN", startFEN))
        }
        return lines
    }

    private static func tag(_ name: String, _ value: String) -> String {
        "[\(name) \"\(sanitized(value))\"]"
    }

    // MARK: Détails

    /// Ne remplit QUE ce qui manque : un PGN importé garde ses en-têtes
    /// d'origine (le vrai tournoi, les vrais joueurs), on ne les écrase pas
    /// avec les nôtres.
    private static func fill(_ tags: inout Game.Tags, from metadata: Metadata) {
        func set(_ value: String, into keyPath: WritableKeyPath<Game.Tags, String>) {
            let current = tags[keyPath: keyPath].trimmingCharacters(in: .whitespaces)
            guard current.isEmpty || current == "?" else { return }
            tags[keyPath: keyPath] = sanitized(value)
        }
        set(metadata.event, into: \.event)
        set(metadata.site, into: \.site)
        set(metadata.date.map(Self.pgnDate) ?? "????.??.??", into: \.date)
        set(metadata.round, into: \.round)
        set(metadata.white, into: \.white)
        set(metadata.black, into: \.black)
        // Toujours une balise Result, même sans résultat connu : « * » est la
        // valeur que le standard prévoit pour ça, et son absence est
        // exactement ce que le testeur voyait.
        set(metadata.result ?? "*", into: \.result)
        if let variant = metadata.variant, tags.other["Variant"] == nil {
            tags.other["Variant"] = sanitized(variant)
        }
    }

    /// Déclare la position de départ quand elle n'est pas la position
    /// standard — sans quoi le PGN rejouerait ses coups depuis une autre
    /// position.
    private static func declareStartingPosition(of game: inout Game) {
        guard
            let start = game.positions[game.startingIndex],
            start.fen != Position.standard.fen,
            game.tags.fen.trimmingCharacters(in: .whitespaces).isEmpty
        else { return }
        game.tags.fen = start.fen
        game.tags.setUp = "1"
    }

    /// Une valeur de balise ne peut porter ni guillemet (il la fermerait), ni
    /// crochet, ni saut de ligne : le fichier deviendrait illisible pour tout
    /// le monde, y compris pour nous au rechargement.
    private static func sanitized(_ value: String) -> String {
        value
            .replacingOccurrences(of: "[\\r\\n\\t]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[\"\\[\\]]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// « AAAA.MM.JJ » — le format du standard, invariant de la locale (un
    /// calendrier grégorien et des chiffres arabes, où qu'on se trouve).
    static func pgnDate(_ date: Date) -> String {
        let parts = Calendar(identifier: .gregorian)
            .dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
            return "????.??.??"
        }
        return String(format: "%04d.%02d.%02d", year, month, day)
    }
}
