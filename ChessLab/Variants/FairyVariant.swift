import ChessKit
import SwiftUI

/// Une variante jouée via Fairy-Stockfish, dont ChessKit reste l'UNIQUE
/// source de vérité pour la légalité des coups — plateau et pièces
/// INCHANGÉS par rapport au jeu classique, contrairement à Chess960 (qui a
/// dû contourner ChessKit pour le roque). Seule la condition de victoire
/// diffère du mat/pat/nulle standard, vérifiée par
/// ``specialOutcome(board:mover:checkCounts:)``. Fairy-Stockfish ne sert
/// donc QUE d'adversaire/conseiller — jamais d'arbitre de légalité.
///
/// Sans réseau NNUE embarqué (décision du 25/08) : éval classique
/// uniquement pour ces trois variantes.
struct FairyVariant: Identifiable {
    /// Identifiant STABLE, et valeur EXACTE de `setoption UCI_Variant`.
    let id: String
    /// Texte FRANÇAIS source, pas encore traduit — même convention que
    /// ``GameOutcome/Reason/reasonText``. Un `static let` figé au premier
    /// accès ne doit JAMAIS stocker le résultat DÉJÀ traduit de
    /// ``LocalizationController/string(_:)`` : un changement de langue en
    /// cours de session ne le retraduirait plus. Les propriétés calculées
    /// ci-dessous appellent la traduction à CHAQUE lecture.
    private let displayNameKey: String
    private let shortNameKey: String
    private let taglineKey: String
    /// Accroche RACCOURCIE, pour les tuiles des petits iPhone : sur un
    /// écran de 375 pt, la tuile n'offre qu'une ligne d'environ 17
    /// caractères, et l'accroche complète s'y coupait en plein mot.
    private let shortTaglineKey: String
    /// Explication complète, affichée à l'ouverture des réglages — pas
    /// seulement l'accroche courte des tuiles (``tagline``).
    private let rulesKey: String
    let icon: String
    let tint: Color
    /// FEN de départ — classique pour la plupart, propre à Horde.
    let startFEN: String

    var displayName: String { LocalizationController.string(displayNameKey) }
    var shortName: String { LocalizationController.string(shortNameKey) }
    var tagline: String { LocalizationController.string(taglineKey) }
    var shortTagline: String { LocalizationController.string(shortTaglineKey) }
    var rules: String { LocalizationController.string(rulesKey) }

    static let kingOfTheHill = FairyVariant(
        id: "kingofthehill",
        displayNameKey: "Roi de la colline",
        shortNameKey: "Roi colline",
        taglineKey: "Amenez votre roi au centre pour gagner",
        shortTaglineKey: "Roi au centre",
        rulesKey: "Les règles sont celles du jeu classique. Vous gagnez aussi IMMÉDIATEMENT si votre roi atteint l'une des quatre cases centrales — d4, e4, d5 ou e5 — quel que soit l'état du reste de l'échiquier, y compris en plein milieu de partie.",
        icon: "mountain.2.fill",
        tint: Theme.gold,
        startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )

    static let threeCheck = FairyVariant(
        id: "3check",
        displayNameKey: "Trois échecs",
        shortNameKey: "3 échecs",
        taglineKey: "Trois échecs infligés valent la partie",
        shortTaglineKey: "Échec trois fois",
        rulesKey: "Les règles sont celles du jeu classique, échec et mat compris. En plus, vous gagnez dès que vous avez mis le roi adverse en échec TROIS FOIS au cours de la partie — chaque échec compte, qu'il soit paré, capturé ou fui au coup suivant.",
        icon: "3.circle.fill",
        tint: Theme.danger,
        startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )

    static let horde = FairyVariant(
        id: "horde",
        displayNameKey: "Horde",
        shortNameKey: "Horde",
        taglineKey: "36 pions contre une armée classique",
        shortTaglineKey: "36 pions",
        rulesKey: "Position asymétrique : les Blancs commencent avec des pions occupant une grande partie de l'échiquier et AUCUNE autre pièce — pas même de roi. Les Noirs ont une armée classique complète, avec ses droits de roque. Les Blancs gagnent en mettant le roi noir échec et mat — un pion promu peut y contribuer. Les Noirs gagnent en capturant la toute dernière pièce blanche.",
        icon: "person.3.fill",
        tint: Theme.teal,
        // FEN d'origine Fairy-Stockfish : les Blancs n'ont AUCUNE pièce hors
        // pions (pas de roi) — seuls les Noirs gardent leurs droits de roque.
        startFEN: "rnbqkbnr/pppppppp/8/1PP2PP1/PPPPPPPP/PPPPPPPP/PPPPPPPP/PPPPPPPP w kq - 0 1"
    )

    static let all: [FairyVariant] = [.kingOfTheHill, .threeCheck, .horde]

    // MARK: Condition de victoire propre à la variante

    private static let hillSquares: Set<Square> = [
        Square("d4"), Square("e4"), Square("d5"), Square("e5"),
    ]

    /// Le camp qui n'a QUE des pions au départ, à Horde — toujours les
    /// Blancs dans ``startFEN``. Perdre toutes ses pièces (donc tous ses
    /// pions, puisqu'il n'a que ça) fait perdre la partie.
    static let hordeSide: Piece.Color = .white

    /// Condition de victoire SPÉCIFIQUE à cette variante, évaluée APRÈS un
    /// coup — en complément de ``GameOutcome/fromBoardState(_:)`` (mat/pat/
    /// nulle standard), que l'appelant vérifie EN PREMIER : un mat reste un
    /// mat même sur la colline.
    ///
    /// - parameter board: position APRÈS le coup.
    /// - parameter mover: camp qui vient de jouer.
    /// - parameter checkCounts: échecs infligés par chaque camp depuis le
    ///   début de la partie (Trois échecs seulement — ignoré sinon).
    func specialOutcome(
        board: Board, mover: Piece.Color, checkCounts: [Piece.Color: Int]
    ) -> GameOutcome? {
        switch id {
        case FairyVariant.kingOfTheHill.id:
            guard let kingSquare = board.position.pieces
                .first(where: { $0.kind == .king && $0.color == mover })?.square,
                Self.hillSquares.contains(kingSquare)
            else { return nil }
            return GameOutcome(winner: mover, reason: .kingOfTheHill)

        case FairyVariant.threeCheck.id:
            guard (checkCounts[mover] ?? 0) >= 3 else { return nil }
            return GameOutcome(winner: mover, reason: .threeChecksDelivered)

        case FairyVariant.horde.id:
            let hordeSide = Self.hordeSide
            guard mover != hordeSide,
                  !board.position.pieces.contains(where: { $0.color == hordeSide })
            else { return nil }
            return GameOutcome(winner: mover, reason: .hordeExtinction)

        default:
            return nil
        }
    }

    /// Nombre d'échecs infligés par chaque camp depuis le début — rejoué
    /// depuis le journal UCI plutôt que suivi de façon incrémentale : robuste
    /// à la consultation/reprise, comme le reste de l'état dérivé de l'app.
    /// Coûteux O(coups²) en théorie, négligeable en pratique (parties de
    /// quelques dizaines de coups).
    static func checkCounts(startFEN: String, uciLog: [String]) -> [Piece.Color: Int] {
        guard let position = Position(fen: startFEN) else { return [:] }
        var board = Board(position: position)
        var counts: [Piece.Color: Int] = [.white: 0, .black: 0]
        for uci in uciLog {
            let mover = board.position.sideToMove
            guard Self.apply(uci: uci, to: &board) != nil else { break }
            if case .check = board.state {
                counts[mover, default: 0] += 1
            }
        }
        return counts
    }

    /// Applique un coup en notation UCI/LAN au plateau — même idiome que
    /// partout ailleurs dans le projet (``LabViewModel/apply(lan:)`` et
    /// consorts) : promotion en dame par défaut, sauf lettre finale. Interne
    /// (pas privée) : ``FairyVariantPlayViewModel`` la réutilise.
    static func apply(uci: String, to board: inout Board) -> Move? {
        guard uci.count >= 4 else { return nil }
        let start = Square(String(uci.prefix(2)))
        let end = Square(String(uci.dropFirst(2).prefix(2)))
        guard let move = board.move(pieceAt: start, to: end) else { return nil }
        if case .promotion = board.state {
            let kind: Piece.Kind = uci.count == 5
                ? (Piece.Kind(rawValue: String(uci.suffix(1)).uppercased()) ?? .queen)
                : .queen
            return board.completePromotion(of: move, to: kind)
        }
        return move
    }
}

