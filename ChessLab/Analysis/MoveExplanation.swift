import ChessKit

/// Pourquoi un coup était mauvais — en une phrase vraie.
///
/// Le bandeau coach sait dire « e5 — Erreur, −12 % » : il sait donc COMBIEN un
/// coup coûte, et n'a jamais su dire CE QUI le punit. L'utilisateur apprend
/// qu'il a eu tort, pas ce qu'il n'a pas vu, et rejouera le même coup.
///
/// Cette structure porte la réponse, lue sur la **réfutation du moteur** — la
/// variante qu'il enchaîne après le coup joué. Aucun modèle de langage n'entre
/// ici : tout est rejoué sur un plateau, donc rien ne peut être inventé. C'est
/// moins bavard qu'un coach improvisé, et c'est vérifiable.
struct MoveExplanation: Equatable {
    /// Le motif qui punit, quand il est nommable. `nil` est fréquent et normal :
    /// beaucoup de fautes se résument à une perte de matériel sans figure.
    var motif: TacticalMotif?
    /// Matériel net perdu sur la réfutation (en points), du point de vue du
    /// joueur qui vient de jouer. `nil` quand la ligne ne coûte rien de net.
    var materialLoss: Int?
    /// Le premier coup de la réfutation, en SAN anglais (le standard stocké —
    /// la francisation est une affaire d'affichage, voir ``SANFormatter``).
    var refutationSAN: String

    /// La phrase, dans la langue active de l'app.
    ///
    /// Construite à la LECTURE et non à l'analyse : l'explication est mise en
    /// cache pour toute la session, et un changement de langue en cours de
    /// route doit la retraduire — pas la laisser figée dans la langue qui
    /// avait cours au moment du calcul.
    func sentence(notation: PieceNotation) -> String {
        let san = SANFormatter.display(refutationSAN, notation: notation)

        guard let motif else {
            guard let materialLoss else { return "" }
            return LocalizationController.string(
                "%@ : vous perdez %lld points de matériel.", san, materialLoss
            )
        }

        let head: String
        var mentionsCost = true

        switch motif {
        case let .checkmate(inMoves, isBackRank):
            // Le matériel ne veut plus rien dire quand la ligne mate.
            mentionsCost = false
            head = switch (inMoves <= 1, isBackRank) {
            case (true, true): LocalizationController.string("%@ : mat du couloir.", san)
            case (true, false): LocalizationController.string("%@ : et c'est mat.", san)
            case (false, true):
                LocalizationController.string("%@ : mat du couloir en %lld coups.", san, inMoves)
            case (false, false):
                LocalizationController.string("%@ : mat en %lld coups.", san, inMoves)
            }

        case let .hangingPiece(kind, _):
            // Le coût est le nom de la pièce : le répéter en points serait du bruit.
            mentionsCost = false
            head = LocalizationController.string(
                "%@ : votre %@ était en prise.", san, PieceNaming.frenchKindLowercase(kind)
            )

        case let .fork(_, _, targets):
            // Deux cibles nommées suffisent — une fourchette triple se raconte
            // aussi bien par ses deux plus grosses prises.
            let named = targets.prefix(2).map(PieceNaming.frenchKindLowercase)
            head = named.count == 2
                ? LocalizationController.string(
                    "%@ : fourchette sur votre %@ et votre %@.", san, named[0], named[1]
                )
                : LocalizationController.string("%@ : fourchette.", san)

        case .discoveredCheck:
            // La pièce qui démasque n'est PAS nommée : « son fou »/« sa tour »
            // demanderait un accord de genre par pièce, pour un gain nul —
            // la flèche sur le plateau montre déjà laquelle.
            head = LocalizationController.string("%@ : échec à la découverte.", san)

        case let .pin(victim, behind):
            // Tournure NOMINALE (« clouage de votre… ») et non « votre tour est
            // clouée » : le participe s'accorderait en genre avec la pièce, ce
            // qu'un gabarit à trous ne sait pas faire.
            head = LocalizationController.string(
                "%@ : clouage de votre %@ devant votre %@.",
                san, PieceNaming.frenchKindLowercase(victim), PieceNaming.frenchKindLowercase(behind)
            )
        }

        guard mentionsCost, let materialLoss else { return head }
        return head + " " + LocalizationController.string("Vous perdez %lld points.", materialLoss)
    }

    /// Confort côté vue : suit le réglage de notation de l'utilisateur, comme
    /// ``SANFormatter/display(_:)``.
    @MainActor
    var sentence: String {
        sentence(notation: AppSettings.shared.pieceNotation)
    }
}

/// Fabrique l'explication d'un coup à partir de la réfutation du moteur.
///
/// Entièrement PUR : une position, une liste de coups en LAN, et rien d'autre.
/// Aucune requête moteur n'est faite ici — la variante est déjà payée par la
/// classification, qui interroge Stockfish sur la position d'après de toute
/// façon. L'explication est donc **gratuite en temps de calcul** ; c'est ce
/// qui la rend acceptable sur une revue de quarante coups.
enum MoveExplainer {

    /// Au-delà, la ligne ne raconte plus la faute mais la partie qui suit. Six
    /// coups couvrent largement une tactique.
    static let maxPlies = 12

    /// En deçà, la « perte » relève du bruit d'horizon : une variante coupée à
    /// une profondeur arbitraire peut montrer un pion d'écart qui n'existe pas.
    /// Même seuil que ``MoveClassifier/involvesSacrifice(move:boardAfterMove:)``,
    /// et pour la même raison.
    static let minimumMaterialLoss = 2

    struct Input {
        /// Position APRÈS le coup à expliquer — l'adversaire est au trait.
        var positionAfterMove: Position
        /// Variante principale du moteur à cette position, en LAN. Son premier
        /// élément est la réponse de l'adversaire : la punition.
        var refutationLANs: [String]
    }

    /// `nil` quand la ligne ne dit rien d'exploitable : ni mat, ni motif, ni
    /// perte matérielle nette. Mieux vaut se taire que meubler.
    static func explain(_ input: Input) -> MoveExplanation? {
        var board = Board(position: input.positionAfterMove)
        let mover = input.positionAfterMove.sideToMove.opposite
        let startingBalance = materialBalance(of: board.position, from: mover)

        var plies: [Move] = []
        /// Bilan matériel après chaque demi-coup, et si la position y est
        /// « calme » — c'est-à-dire si rien ne peut reprendre sur la case
        /// d'arrivée. Lire le matériel au milieu d'un échange donnerait un
        /// chiffre faux dans un sens ou dans l'autre.
        var balances: [(value: Int, isQuiet: Bool)] = []
        var boardAfterFirstPly: Board?
        var mateInMoves: Int?

        for lan in input.refutationLANs.prefix(maxPlies) {
            guard let move = apply(lan: lan, to: &board) else { break }
            plies.append(move)
            balances.append((
                value: materialBalance(of: board.position, from: mover),
                isQuiet: !canRecapture(on: move.end, in: board)
            ))
            if plies.count == 1 { boardAfterFirstPly = board }

            if case let .checkmate(matedColor) = board.state {
                // L'adversaire joue en premier dans la réfutation : il mate donc
                // aux demi-coups impairs (1, 3, 5…), soit (n + 1) / 2 coups.
                if matedColor == mover { mateInMoves = (plies.count + 1) / 2 }
                break
            }
        }

        guard let firstPly = plies.first, let boardAfterFirstPly else { return nil }

        let motif: TacticalMotif? = if let mateInMoves {
            .checkmate(
                inMoves: mateInMoves,
                isBackRank: TacticalMotifDetector.isBackRankMate(of: mover, board: board)
            )
        } else {
            TacticalMotifDetector.detect(punishing: firstPly, boardAfter: boardAfterFirstPly)
        }

        // Le verdict matériel se lit au dernier point CALME de la ligne. Sans
        // ça, une variante tronquée juste après une prise (limite de
        // profondeur ou fin de PV) annoncerait une perte de dame que la reprise
        // du demi-coup suivant aurait effacée.
        let settled = balances.last(where: \.isQuiet) ?? balances.last
        let loss = settled.map { startingBalance - $0.value }
        let materialLoss = (loss ?? 0) >= minimumMaterialLoss ? loss : nil

        guard motif != nil || materialLoss != nil else { return nil }
        return MoveExplanation(motif: motif, materialLoss: materialLoss, refutationSAN: firstPly.san)
    }

    // MARK: Utilitaires

    /// Bilan matériel du point de vue de `color` (positif = il a plus de bois).
    private static func materialBalance(of position: Position, from color: Piece.Color) -> Int {
        position.pieces.reduce(0) { total, piece in
            total + (piece.color == color ? pieceValue(piece.kind) : -pieceValue(piece.kind))
        }
    }

    /// Un camp peut-il reprendre sur `square` ? La case porte la pièce qui vient
    /// d'arriver, donc tout coup vers elle est une prise.
    private static func canRecapture(on square: Square, in board: Board) -> Bool {
        board.position.pieces
            .filter { $0.color == board.position.sideToMove }
            .contains { board.canMove(pieceAt: $0.square, to: square) }
    }

    /// Applique un coup en LAN (« e2e4 », « e7e8q »), promotion comprise, et
    /// rend le coup obtenu. Même logique que ``PuzzleSolutionTrimmer``.
    private static func apply(lan: String, to board: inout Board) -> Move? {
        guard lan.count >= 4 else { return nil }
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        guard let move = board.move(pieceAt: start, to: end) else { return nil }
        if case .promotion = board.state {
            let kind: Piece.Kind = lan.count == 5
                ? (Piece.Kind(rawValue: String(lan.suffix(1)).uppercased()) ?? .queen)
                : .queen
            return board.completePromotion(of: move, to: kind)
        }
        return move
    }
}
