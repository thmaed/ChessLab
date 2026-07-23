import ChessKit
import Foundation

/// Conversion éval (centipions ou mat) → probabilité de gain, POV Blancs.
/// Sigmoïde type Lichess : à +8 perdre 300cp ne change presque rien, à
/// 0.00 c'est décisif — la classification des coups se fait sur cette
/// échelle, pas sur les centipions bruts (voir ``MoveClassifier``).
enum EvalConversion {
    /// Probabilité de gain des Blancs (0...100) à partir d'une éval en
    /// centipions, POV Blancs (positif = avantage Blancs).
    static func winPercentage(cp: Int) -> Double {
        50 + 50 * (2 / (1 + exp(-0.00368 * Double(cp))) - 1)
    }

    /// Un mat forcé compte comme un avantage extrême (100/0), pas une
    /// simple grande valeur de cp — sinon un mat en 1 et un mat en 20
    /// auraient un score arbitrairement différent selon la profondeur
    /// atteinte par le moteur au moment du calcul.
    static func winPercentage(mate: Int) -> Double {
        mate > 0 ? 100 : 0
    }
}

/// Classe CHAQUE coup joué sur l'échelle complète de ``MoveQuality`` —
/// plus de coup « sans catégorie » : un coup sain est dit sain, pas passé
/// sous silence.
///
/// Toutes les probabilités sont DU POINT DE VUE DU JOUEUR QUI VIENT DE
/// JOUER (inverser `100 - winPercentage(cp:)` pour les Noirs avant
/// d'appeler). Fonction pure : tout ce qui demande le moteur ou le plateau
/// est calculé par l'appelant et passé dans ``Input``.
enum MoveClassifier {
    /// Seuils de PERTE de probabilité de gain (points de %).
    ///
    /// RESSERRÉS le 20/07/2026 (barème choisi par l'utilisateur) : la version
    /// d'origine (10/20/30) était trop indulgente — un coup lâchant jusqu'à
    /// 10 % de probabilité de gain restait un « Bon coup ». L'échelle est
    /// désormais Excellent < 2 %, Bon coup 2-5 %, Imprécision 5-10 %, Erreur
    /// 10-20 %, Gaffe ≥ 20 %. Un coup qui perd 7 % n'est plus félicité mais
    /// signalé comme imprécis.
    static let inaccuracyThreshold = 5.0
    static let mistakeThreshold = 10.0
    static let blunderThreshold = 20.0
    /// En dessous de cette perte, le coup vaut celui du moteur.
    static let excellentThreshold = 2.0
    /// Écart minimal (points de %) avec le 2e choix du moteur pour qu'un
    /// coup soit « le seul bon coup » — condition du Grand coup et du
    /// Brillant.
    static let onlyMoveGapThreshold = 15.0
    /// Au-delà, la position était déjà gagnée : trouver le seul coup qui
    /// garde +9 plutôt que +5 n'est pas un exploit, et une victoire
    /// dilapidée mais pas perdue est une occasion MANQUÉE, pas une gaffe.
    static let clearlyWinningThreshold = 85.0
    /// EXCEPTION au seuil ci-dessus pour le Grand coup : même dans une
    /// position déjà gagnée (≥ 85 %), le coup mérite « Grand coup » si le 2e
    /// choix s'effondre de plus de ça — c'est qu'il y avait un piège, un seul
    /// coup gardait vraiment le gain.
    static let secondBestCollapseThreshold = 30.0

    /// Tout ce que la classification d'un coup doit savoir. Les champs
    /// optionnels sont ceux que le moteur ne fournit pas toujours :
    /// `gapToSecondBest` est `nil` quand il n'existe pas de 2e choix
    /// (position de mat, coup unique).
    struct Input {
        var winPercentBefore: Double
        var winPercentAfter: Double
        /// Le coup joué est-il le premier choix du moteur à la position
        /// parente ?
        var isBestMove = false
        /// Écart (points de %) entre le 1er et le 2e choix du moteur à la
        /// position parente, POV du joueur au trait.
        var gapToSecondBest: Double?
        /// La ligne jouée jusqu'ici est-elle encore dans la théorie (ECO) ?
        var isBook = false
        /// Le coup abandonne-t-il du matériel de façon reprenable ?
        var isSacrifice = false
        /// La pièce sacrifiée est-elle IMMÉDIATEMENT reprise sur sa case
        /// d'arrivée au coup suivant ? Un vrai coup brillant est un sacrifice
        /// que l'adversaire ne peut (ou ne devrait) pas simplement encaisser :
        /// une reprise triviale trahit une simple simplification, pas un
        /// exploit. Calculé par l'appelant en regardant le coup suivant réel.
        var sacrificeImmediatelyRecaptured = false
        /// Le MEILLEUR coup (celui qu'on a raté) était-il une tactique nette —
        /// mat direct ou gain de matériel ? Condition de l'« occasion
        /// manquée » : rater un plan positionnel dans une position gagnée
        /// n'est pas un « Miss », rater un mat ou une pièce en est un.
        var bestMoveWasTactical = false
        /// Seul coup légal : ni mérite, ni faute.
        var isForced = false
    }

    static func classify(_ input: Input) -> MoveQuality {
        // La théorie d'abord : tant qu'on récite, l'éval ne juge personne.
        if input.isBook { return .book }
        // Un coup unique est trivialement le meilleur — et ne sera jamais
        // « brillant » : on ne sacrifie pas ce qu'on est forcé de donner.
        if input.isForced { return .best }

        let loss = input.winPercentBefore - input.winPercentAfter

        if loss >= inaccuracyThreshold {
            // Occasion manquée : position déjà gagnée dilapidée SANS être
            // perdue, ET la perte vient d'avoir raté une TACTIQUE nette (mat
            // ou gain de matériel) — pas d'une simple dérive positionnelle.
            // Sans cette dernière condition, tout relâchement d'une position
            // gagnée devenait un « Miss » ; on le réserve au mat/gain manqué.
            if input.winPercentBefore >= clearlyWinningThreshold,
               input.winPercentAfter >= 50,
               input.bestMoveWasTactical {
                return .miss
            }
            switch loss {
            case blunderThreshold...: return .blunder
            case mistakeThreshold...: return .mistake
            default: return .inaccuracy
            }
        }

        if input.isBestMove {
            let gap = input.gapToSecondBest ?? 0
            // « Le seul bon coup » : écart ≥ 15 % avec le 2e choix, ET soit la
            // position n'était pas encore gagnée, SOIT — même gagnée — le 2e
            // choix s'effondre (> 30 %), signe qu'un seul coup gardait le gain.
            let isOnlyGoodMove = gap >= onlyMoveGapThreshold
                && (input.winPercentBefore < clearlyWinningThreshold || gap >= secondBestCollapseThreshold)

            // Brillant : le seul bon coup, ET un sacrifice RÉEL (pas repris
            // trivialement au coup suivant), ET la position reste au moins
            // égale — le sacrifice spéculatif perdant n'est pas salué.
            if isOnlyGoodMove,
               input.isSacrifice,
               !input.sacrificeImmediatelyRecaptured,
               input.winPercentAfter >= 50 {
                return .brilliant
            }
            // Grand coup : le seul bon coup (sans le sacrifice caractéristique
            // du brillant).
            if isOnlyGoodMove {
                return .great
            }
            return .best
        }

        return loss < excellentThreshold ? .excellent : .good
    }

    /// Vrai si la pièce arrivée en `move.end` est REPRISE sur cette même case
    /// par le coup suivant réellement joué. « Trivialement repris » = l'adversaire
    /// n'a eu qu'à encaisser sur place au coup d'après ; le sacrifice n'était
    /// donc pas la ressource unique et spectaculaire d'un coup brillant, mais
    /// une simple simplification. On ne juge pas la valeur du reprenant : la
    /// simple reprise immédiate suffit à disqualifier le « brillant ».
    static func isImmediatelyRecaptured(_ move: Move, byNext next: Move?) -> Bool {
        guard let next, next.end == move.end else { return false }
        if case .capture = next.result { return true }
        return false
    }

    /// Un coup "sacrifie" s'il abandonne une valeur nette significative
    /// (≥ 2 points, environ 2 pions) à une pièce adverse qui peut
    /// reprendre sur la case d'arrivée à moindre coût — approximation
    /// volontaire sans recherche en profondeur (pas de vérification que
    /// la reprise soit vraiment le meilleur coup adverse, juste qu'elle
    /// existe et serait rentable).
    static func involvesSacrifice(move: Move, boardAfterMove: Board) -> Bool {
        let moverValue = pieceValue(move.piece.kind)
        let gainedValue: Int
        switch move.result {
        case let .capture(captured): gainedValue = pieceValue(captured.kind)
        default: gainedValue = 0
        }

        guard moverValue - gainedValue >= 2 else { return false }

        let cheapestAttackerValue = boardAfterMove.position.pieces
            .filter { $0.color == move.piece.color.opposite }
            .filter { boardAfterMove.canMove(pieceAt: $0.square, to: move.end) }
            .map { pieceValue($0.kind) }
            .min()

        guard let cheapestAttackerValue else { return false }
        return cheapestAttackerValue <= moverValue
    }
}

/// Précision globale (%) d'un joueur sur une partie, dérivée de la
/// moyenne des pertes de probabilité de gain sur ses coups — formule
/// inspirée de celle popularisée par Lichess (non spécifiée telle quelle
/// dans le brief, choix documenté ici) : une perte moyenne nulle donne
/// 100%, une perte moyenne importante fait chuter le score de façon non
/// linéaire (les grosses gaffes isolées punissent plus qu'elles ne
/// devraient en moyenne simple).
enum AccuracyScore {
    static func accuracy(averageWinPercentLoss: Double) -> Double {
        guard averageWinPercentLoss > 0 else { return 100 }
        let raw = 103.1668 * exp(-0.04354 * averageWinPercentLoss) - 3.1669
        return min(100, max(0, raw))
    }
}
