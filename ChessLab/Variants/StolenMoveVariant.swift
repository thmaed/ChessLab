import ChessKit
import SwiftUI

/// Coup Volé — variante maison (aucun équivalent Fairy-Stockfish : le
/// mécanisme de tour double n'existe dans AUCUN moteur standard). Les
/// règles de base restent celles du jeu classique — plateau, pièces, mat/
/// pat — SEUL le déroulement du tour change :
///
/// 1. Un jeton est gagné tous les `tokenInterval` coups JOUÉS PAR UN CAMP
///    (7e, 14e, 21e… par défaut — réglable 4 à 8, voir ``StolenMoveSettings``).
/// 2. Un seul jeton en stock : en gagner un nouveau efface l'ancien s'il
///    n'a pas été dépensé entre-temps.
/// 3. Un jeton ne peut pas être dépensé si son camp est en échec au moment
///    de jouer.
/// 4. Dépensé : le camp joue un coup, PUIS un second immédiatement — SAUF
///    si le premier met l'adversaire en échec, auquel cas le tour s'arrête
///    là (pas de second coup).
/// 5. Une prise en passant rendue possible par le tout dernier coup adverse
///    reste valable au coup suivant MÊME si un coup du camp qui pourrait
///    prendre s'intercale — cas qui ne peut survenir qu'au premier coup
///    d'un tour à deux coups (voir ``StolenMovePlayViewModel/pendingEnPassantOverride``).
///
/// ChessKit reste l'unique arbitre de légalité pour CHAQUE coup individuel
/// (règles classiques) — le moteur (Stockfish standard, pas Fairy-Stockfish :
/// aucune option UCI de variante n'existe pour ceci) ne sert que de
/// conseiller/adversaire, jamais de source de légalité, ni de gestionnaire
/// du tour double, qui est tenu entièrement par la vue-modèle.
struct StolenMoveVariant: PlayableVariant {
    let id: String
    private let displayNameKey: String
    private let shortNameKey: String
    private let taglineKey: String
    private let rulesKey: String
    let icon: String
    let tint: Color
    let startFEN: String

    var displayName: String { LocalizationController.string(displayNameKey) }
    var shortName: String { LocalizationController.string(shortNameKey) }
    var tagline: String { LocalizationController.string(taglineKey) }
    var rules: String { LocalizationController.string(rulesKey) }

    static let shared = StolenMoveVariant(
        id: "stolenmove",
        displayNameKey: "Coup Volé",
        shortNameKey: "Coup Volé",
        taglineKey: "Un jeton tous les 7 coups pour en jouer deux d'affilée",
        rulesKey: "Les règles sont celles du jeu classique. En plus : tous les 7 coups joués (réglable), vous gagnez un jeton — un seul en stock, le perdre en en gagnant un nouveau sans l'avoir dépensé. En le dépensant (hors échec), vous jouez deux coups d'affilée — sauf si le premier met l'adversaire en échec, auquel cas le tour s'arrête là. Une prise en passant rendue possible par le dernier coup adverse reste valable même si votre premier coup du tour double s'intercale.",
        icon: "bolt.badge.clock.fill",
        tint: Theme.gold,
        startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    )

    static let tokenIntervalRange = 4...8
    static let defaultTokenInterval = 7
}
