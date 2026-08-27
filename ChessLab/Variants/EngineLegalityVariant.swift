import ChessKit
import SwiftUI

/// Une variante où Fairy-Stockfish est l'ARBITRE de légalité — pas seulement
/// un conseiller comme pour ``FairyVariant`` (Roi de la colline/Trois échecs/
/// Horde, lot A). Course des rois, Antéchecs et Atomique changent la
/// LÉGALITÉ elle-même (échec interdit, capture obligatoire, explosions) :
/// ChessKit seul ne suffit plus à en juger.
///
/// Architecture validée le 25/08 avant tout code réel (même discipline que
/// le patch d'espace de noms C++) : `go perft 1` énumère les coups légaux
/// exacts de la position (`FairyEngineController.legalMoves(startFEN:
/// uciLog:)`), et `d` donne le FEN résultant après un coup
/// (`positionAfter(startFEN:uciLog:)`) — y compris les cases vidées par une
/// explosion Atomique, qu'aucune règle ChessKit ne pourrait deviner. Lu dans
/// `position.cpp` (`is_immediate_game_end`) : la fin de partie « capture the
/// flag » de Course des rois implémente déjà la règle officielle du coup de
/// grâce (si les Blancs arrivent en 8e rangée, les Noirs ont EXACTEMENT un
/// coup pour égaliser en y arrivant aussi) — inutile de la reprogrammer,
/// `legalMoves` la reflète déjà (liste vide seulement quand la partie est
/// VRAIMENT finie).
///
/// ChessKit garde un rôle : reconstruire un `Board` d'AFFICHAGE à partir du
/// FEN donné par le moteur, pour le rendu du plateau — jamais pour statuer
/// sur la légalité d'un coup ici.
struct EngineLegalityVariant: Identifiable {
    /// Identifiant STABLE, et valeur EXACTE de `setoption UCI_Variant`.
    let id: String
    /// Texte FRANÇAIS source — même convention que ``FairyVariant`` : une
    /// propriété calculée traduit à CHAQUE lecture, jamais un résultat figé.
    private let displayNameKey: String
    private let shortNameKey: String
    private let taglineKey: String
    /// Accroche raccourcie pour les tuiles des petits iPhone — voir
    /// ``FairyVariant/shortTagline``.
    private let shortTaglineKey: String
    private let rulesKey: String
    let icon: String
    let tint: Color
    let startFEN: String

    var displayName: String { LocalizationController.string(displayNameKey) }
    var shortName: String { LocalizationController.string(shortNameKey) }
    var tagline: String { LocalizationController.string(taglineKey) }
    var shortTagline: String { LocalizationController.string(shortTaglineKey) }
    var rules: String { LocalizationController.string(rulesKey) }

    static let racingKings = EngineLegalityVariant(
        id: "racingkings",
        displayNameKey: "Course des rois",
        shortNameKey: "Course rois",
        taglineKey: "Le premier roi en 8e rangée gagne",
        shortTaglineKey: "Le roi en 8e",
        rulesKey: "Pas de pions, pas de roque. Aucun coup n'a le droit de mettre le roi adverse en échec — sauf s'il gagne la partie sur-le-champ. Le but : amener votre roi sur la 8e rangée avant l'adversaire. Si les Blancs y arrivent les premiers, les Noirs ont EXACTEMENT un coup pour égaliser en y arrivant aussi — sinon les Blancs ont gagné.",
        icon: "flag.checkered",
        tint: Theme.info,
        startFEN: "8/8/8/8/8/8/krbnNBRK/qrbnNBRQ w - - 0 1"
    )

    static let atomic = EngineLegalityVariant(
        id: "atomic",
        displayNameKey: "Atomique",
        shortNameKey: "Atomique",
        taglineKey: "Chaque capture fait exploser les cases voisines",
        shortTaglineKey: "Prises explosives",
        rulesKey: "Toute capture fait exploser la case d'arrivée : la pièce qui capture ET la pièce capturée disparaissent, ainsi que toute pièce SAUF les pions sur les huit cases voisines. La partie se termine dès qu'un roi explose — un coup qui ferait exploser votre PROPRE roi est interdit. Deux rois peuvent se toucher sans risque : aucun ne peut capturer l'autre sans se détruire lui-même.",
        icon: "burst.fill",
        tint: Theme.danger,
        startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )

    static let antichess = EngineLegalityVariant(
        id: "antichess",
        displayNameKey: "Antéchecs",
        shortNameKey: "Antéchecs",
        taglineKey: "Perdez toutes vos pièces — ou restez bloqué — pour gagner",
        shortTaglineKey: "Perdre pour gagner",
        rulesKey: "Le but est INVERSÉ : vous gagnez en perdant toutes vos pièces, ou en étant dans l'incapacité de jouer un coup. Capturer est OBLIGATOIRE dès que c'est possible — s'il existe plusieurs captures, vous choisissez laquelle. Il n'y a ni échec ni mat : le roi se capture comme n'importe quelle pièce, et le roque n'existe pas.",
        icon: "arrow.triangle.swap",
        tint: Theme.rose,
        startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )

    static let all: [EngineLegalityVariant] = [.racingKings, .atomic, .antichess]

    // MARK: Fin de partie

    /// Détecte la fin de partie APRÈS un coup, uniquement à partir de ce que
    /// le moteur rapporte — jamais de règle réimplémentée à la main.
    ///
    /// - parameter fen: position APRÈS le coup (``FairyEngineController/
    ///   positionAfter(startFEN:uciLog:)``).
    /// - parameter legalMovesForNextMover: coups légaux de la position
    ///   ci-dessus, déjà interrogés (``FairyEngineController/
    ///   legalMoves(startFEN:uciLog:)``) — vide seulement si la partie est
    ///   RÉELLEMENT terminée (voir le commentaire de tête sur le coup de
    ///   grâce de Course des rois, déjà reflété ici).
    /// - parameter inCheck: le camp au trait de `fen` est-il en échec —
    ///   ligne `Checkers:` de `d`, non vide. Ignoré hors Atomique (les
    ///   deux autres variantes n'ont pas de notion d'échec qui bloque un
    ///   coup, seulement la légalité déjà filtrée en amont).
    func outcome(afterFEN fen: String, legalMovesForNextMover: [String], inCheck: Bool) -> GameOutcome? {
        guard let position = Position(fen: fen) else { return nil }
        let nextMover = position.sideToMove
        let kings = position.pieces.filter { $0.kind == .king }

        if id == EngineLegalityVariant.atomic.id {
            // L'explosion d'un roi termine la partie qu'il reste ou non des
            // coups légaux ensuite — vérifié EN PREMIER.
            if !kings.contains(where: { $0.color == .white }) {
                return GameOutcome(winner: .black, reason: .atomicKingExploded)
            }
            if !kings.contains(where: { $0.color == .black }) {
                return GameOutcome(winner: .white, reason: .atomicKingExploded)
            }
        }

        guard legalMovesForNextMover.isEmpty else { return nil }

        switch id {
        case EngineLegalityVariant.racingKings.id:
            let rank8 = Set(kings.filter { $0.square.rank == 8 }.map(\.color))
            if rank8.count == 2 { return GameOutcome(winner: nil, reason: .racingKingsDraw) }
            if let winner = rank8.first { return GameOutcome(winner: winner, reason: .racingKingsGoal) }
            // Ni l'une ni l'autre : pat générique, hors course.
            return GameOutcome(winner: nil, reason: .draw(.stalemate))

        case EngineLegalityVariant.antichess.id:
            // Bloqué, plus de coup possible : le camp au trait GAGNE — le but
            // est inversé (perdre ses pièces, ou être immobilisé).
            return GameOutcome(winner: nextMover, reason: .antichessStuck)

        case EngineLegalityVariant.atomic.id:
            // Aucun roi n'a explosé (vérifié plus haut) mais plus de coup
            // légal : mat ou pat au sens classique.
            return inCheck
                ? GameOutcome(winner: nextMover.opposite, reason: .checkmate)
                : GameOutcome(winner: nil, reason: .draw(.stalemate))

        default:
            return nil
        }
    }
}
