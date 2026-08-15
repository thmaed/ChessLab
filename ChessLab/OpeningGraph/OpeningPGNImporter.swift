import ChessKit
import Foundation

/// Convertit un PGN de RÉPERTOIRE (celui d'une étude Lichess, d'un livre saisi,
/// d'un export SCID) en ``OpeningCourse`` — le même graphe indexé par FEN que
/// les cours embarqués.
///
/// Pourquoi c'est court : `ChessKit.PGNParser` sait déjà lire les variantes
/// entre parenthèses et rend un `MoveTree` branchu, et tout l'aval de l'app
/// (FSRS, transpositions, lecteur, entraîneur) est indexé par FEN NORMALISÉE et
/// non par identifiant de cours. Un cours importé y entre donc sans qu'une
/// seule ligne de l'aval change — c'est le pari architectural du graphe qui
/// paie ici.
///
/// PUR : texte → cours (ou erreur). Aucun accès disque, aucun SwiftData, aucune
/// UI — le stockage est le rôle de ``UserOpeningStore``.
enum OpeningPGNImporter {

    enum ImportError: LocalizedError, Equatable {
        case empty
        case unreadable(String)
        case noMoves
        /// Toutes les parties ne partent pas de la même position : un cours n'a
        /// qu'une racine.
        case mixedStartingPositions

        var errorDescription: String? {
            switch self {
            case .empty:
                LocalizationController.string("Aucun texte à importer.")
            case .unreadable(let detail):
                LocalizationController.string("PGN illisible : %@", detail)
            case .noMoves:
                LocalizationController.string("Ce PGN ne contient aucun coup.")
            case .mixedStartingPositions:
                LocalizationController.string("Ce fichier mélange des positions de départ différentes : importez-les séparément.")
            }
        }
    }

    /// Résultat d'un import : le cours, plus ce qu'on a dû écarter (pour le
    /// dire à l'utilisateur au lieu de le taire).
    struct Result {
        let course: OpeningCourse
        /// Parties ignorées faute d'être lisibles ou jouables.
        let skippedGames: Int
        /// Coups ignorés parce qu'illégaux depuis la position atteinte.
        let skippedMoves: Int
    }

    /// - parameters:
    ///   - pgn: le texte brut (une ou plusieurs parties).
    ///   - name: nom du cours affiché dans la liste.
    ///   - side: camp étudié — décide de quel côté l'entraînement interroge.
    ///   - id: identifiant du cours (voir ``UserOpeningStore/newIdentifier()``).
    static func course(
        fromPGN pgn: String, name: String, side: OpeningSide, id: String
    ) throws -> Result {
        let trimmed = pgn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportError.empty }

        // Même prétraitement que tous les autres points d'import de l'app :
        // fins de ligne Windows, BOM, lignes vides multiples, commentaire de
        // tête — autant de cas que `PGNParser` refuse et qu'un copier-coller
        // réel produit constamment.
        let games = PGNSanitizer.splitIntoGames(trimmed).map(PGNSanitizer.sanitize)
        guard !games.isEmpty else { throw ImportError.noMoves }

        var positions: [String: PositionNode] = [:]
        var chapters: [OpeningChapter] = []
        var rootKey: String?
        var skippedGames = 0
        var skippedMoves = 0
        var firstError: String?

        for (offset, text) in games.enumerated() {
            guard let game = try? Game(pgn: text) else {
                skippedGames += 1
                if firstError == nil { firstError = shortDescription(of: text) }
                continue
            }
            guard let start = game.startingPosition else {
                skippedGames += 1
                continue
            }
            let startKey = OpeningFENKey.key(for: start)
            if let rootKey, rootKey != startKey {
                throw ImportError.mixedStartingPositions
            }
            rootKey = startKey

            let outcome = absorb(game: game, startKey: startKey, into: &positions)
            skippedMoves += outcome.skippedMoves
            if outcome.spine.count <= 1 {
                skippedGames += 1
                continue
            }
            chapters.append(OpeningChapter(
                id: "chapter-\(offset + 1)",
                title: LocalizedText(fr: chapterTitle(game, index: offset), en: chapterTitle(game, index: offset)),
                positionFENs: outcome.spine
            ))
        }

        guard let rootKey, positions[rootKey] != nil else {
            throw ImportError.noMoves
        }
        // Un cours sans la moindre arête n'apprend rien : on refuse plutôt que
        // d'ajouter une entrée vide à la liste.
        guard positions.values.contains(where: { !$0.moves.isEmpty }) else {
            if let firstError { throw ImportError.unreadable(firstError) }
            throw ImportError.noMoves
        }

        let course = OpeningCourse(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces).isEmpty
                ? LocalizationController.string("Répertoire importé") : name,
            side: side,
            rootFEN: rootKey,
            chapters: chapters.isEmpty ? nil : chapters,
            positions: positions
        )
        return Result(course: course, skippedGames: skippedGames, skippedMoves: skippedMoves)
    }

    // MARK: Parcours de l'arbre

    private struct Absorbed {
        /// Positions de la ligne PRINCIPALE, dans l'ordre — sert de sommaire au
        /// chapitre.
        var spine: [String]
        var skippedMoves: Int
    }

    /// Verse un `Game` dans le graphe partagé : un nœud par position atteinte,
    /// une arête par coup. Les positions communes à plusieurs parties (ou à
    /// plusieurs variantes) FUSIONNENT d'elles-mêmes, puisque la clé est la FEN
    /// normalisée — c'est ce qui transforme un empilement d'arbres PGN en un
    /// vrai graphe de répertoire.
    private static func absorb(
        game: Game, startKey: String, into positions: inout [String: PositionNode]
    ) -> Absorbed {
        ensure(startKey, in: &positions)
        var skipped = 0

        // L'ordre de parcours n'a AUCUNE importance : chaque arête se calcule
        // depuis `game.positions`, qui connaît déjà la position de chaque
        // index, et les nœuds se créent à la demande. Pas de tri à justifier,
        // donc pas de tri à se tromper.
        for index in game.moves.indices {
            guard
                let move = game.moves[index],
                let childPosition = game.positions[index]
            else {
                skipped += 1
                continue
            }
            let history = game.moves.history(for: index)
            let parentIndex = history.dropLast().last
            let parentKey = parentIndex
                .flatMap { game.positions[$0] }
                .map(OpeningFENKey.key(for:)) ?? startKey
            let childKey = OpeningFENKey.key(for: childPosition)

            // Garde-fou AVANT de créer quoi que ce soit : on ne fabrique jamais
            // une arête que le validateur rejetterait, ni le nœud orphelin qui
            // irait avec. Un PGN bricolé à la main peut contenir un coup que
            // ChessKit tokenise sans qu'il rejoue.
            guard OpeningCourseValidator.resultingKey(afterUCI: move.lan, from: parentKey) == childKey else {
                skipped += 1
                continue
            }

            ensure(parentKey, in: &positions)
            ensure(childKey, in: &positions)

            let text = comment(of: move)
            append(
                MoveEdge(
                    san: move.san,
                    uci: move.lan,
                    toFEN: childKey,
                    role: role(for: move, isMainLine: index.variation == MoveTree.Index.mainVariation),
                    comment: text,
                    // Le commentaire vient de l'utilisateur lui-même : il est
                    // validé par construction. La règle « jamais de brouillon
                    // affiché comme définitif » vise le contenu GÉNÉRÉ, pas ce
                    // que l'auteur a écrit de sa main.
                    commentStatus: text == nil ? nil : .validated
                ),
                to: parentKey,
                in: &positions
            )
        }

        // Le sommaire du chapitre = la LIGNE PRINCIPALE, c'est-à-dire la chaîne
        // de parents du dernier coup de la variation principale. On la lit à
        // l'arbre plutôt que de l'accumuler en chemin : une variante insérée
        // avant sa ligne mère fausserait l'accumulation.
        let mainLine = game.moves.history(for: game.moves.endIndex)
        let spine = [startKey] + mainLine.compactMap { index in
            game.positions[index].map(OpeningFENKey.key(for:))
        }.filter { positions[$0] != nil }

        return Absorbed(spine: spine, skippedMoves: skipped)
    }

    private static func ensure(_ key: String, in positions: inout [String: PositionNode]) {
        if positions[key] == nil { positions[key] = PositionNode(fen: key) }
    }

    /// Ajoute l'arête si le même coup n'est pas déjà présent — la fusion des
    /// transpositions fait qu'on repasse forcément sur des arêtes déjà connues.
    private static func append(
        _ edge: MoveEdge, to key: String, in positions: inout [String: PositionNode]
    ) {
        guard var node = positions[key] else { return }
        var moves = node.moves
        guard !moves.contains(where: { $0.uci == edge.uci }) else { return }
        moves.append(edge)
        node = PositionNode(
            fen: node.fen, ecoName: node.ecoName, plan: node.plan,
            keySquares: node.keySquares, moves: moves
        )
        positions[key] = node
    }

    /// Le PGN porte déjà le jugement de l'auteur (`?`, `?!`, `!`) : on le
    /// traduit en rôle, pour que le lecteur affiche la pastille « Piège » ou
    /// « Imprécision » sans qu'il ait à ressaisir quoi que ce soit.
    private static func role(for move: Move, isMainLine: Bool) -> MoveRole {
        switch move.assessment {
        case .blunder, .mistake: .trap
        case .dubious: .inaccuracy
        default: isMainLine ? .mainLine : .sideline
        }
    }

    /// Commentaire PGN, dans la langue de celui qui l'a écrit : on le place
    /// dans les DEUX champs plutôt que de deviner laquelle. ``LocalizedText``
    /// se rabat de toute façon sur l'autre langue quand l'une manque.
    private static func comment(of move: Move) -> LocalizedText? {
        let text = move.comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return LocalizedText(fr: text, en: text)
    }

    private static func chapterTitle(_ game: Game, index: Int) -> String {
        // Une étude Lichess exportée met le nom du chapitre dans `Event` ; un
        // fichier de parties y met le nom du tournoi. Les deux valent mieux
        // qu'un numéro, sauf quand c'est le « ? » des PGN sans métadonnées.
        let event = game.tags.event.trimmingCharacters(in: .whitespaces)
        if !event.isEmpty, event != "?" { return event }
        return LocalizationController.string("Chapitre %d", index + 1)
    }

    private static func shortDescription(of pgn: String) -> String {
        String(pgn.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
    }
}
