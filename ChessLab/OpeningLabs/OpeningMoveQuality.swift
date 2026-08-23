import ChessKit
import Foundation

/// Juge un coup de l'index sur l'échelle de ``MoveQuality``, à partir des
/// évaluations moteur PRÉ-CALCULÉES du sidecar Labs.
///
/// ## Pourquoi rejuger des coups de théorie
///
/// Un cours d'ouverture montre la ligne principale ET ce qu'il ne faut pas
/// jouer : pièges, imprécisions, réfutations. L'index alignait jusqu'ici des
/// pastilles de RÔLE (ce que l'auteur a voulu montrer) ; il manquait le
/// verdict OBJECTIF — combien coûte réellement ce coup. Les deux blocs
/// `engine` du sidecar (position avant, position après) le donnent sans qu'un
/// moteur ait à tourner sur l'appareil.
///
/// ## Ce qui est AFFICHÉ, et rien d'autre
///
/// Cinq catégories seulement (``displayed``) : gaffe, erreur, imprécision,
/// occasion manquée, coup brillant. Un index où chaque coup porterait une
/// pastille (« bon coup », « excellent », « théorie »…) ne montrerait plus
/// rien : c'est le DÉCROCHAGE qu'on cherche du regard, et l'exploit. Tout le
/// reste vaut `nil`.
///
/// ## Le piège du « c'est de la théorie »
///
/// ``MoveClassifier`` renvoie `.book` dès que `isBook` est vrai — et dans un
/// cours d'ouverture, TOUT est de la théorie. On ne le lui dit donc pas : ici,
/// on veut précisément le jugement du moteur sur des coups que le livre
/// mentionne, y compris ceux qu'il mentionne pour les condamner.
enum OpeningMoveQuality {

    /// Les seules catégories que l'index dessine.
    static let displayed: Set<MoveQuality> = [.brilliant, .miss, .inaccuracy, .mistake, .blunder]

    /// Tout ce dont le jugement a besoin, résolu par l'appelant.
    struct Context {
        /// Clé FEN de la position AVANT le coup.
        let fromFEN: String
        /// Clé FEN de la position APRÈS le coup.
        let toFEN: String
        let uci: String
        /// Coup RÉELLEMENT joué ensuite dans cette ligne, s'il y en a un —
        /// sert à savoir si un sacrifice est trivialement repris.
        let nextUCI: String?
    }

    /// Verdict affichable d'un coup, ou `nil` : donnée manquante, ou catégorie
    /// qui n'a pas sa place dans l'index.
    static func classify(_ context: Context, sidecar: OpeningLabsSidecar) -> MoveQuality? {
        guard
            let before = sidecar.data(at: context.fromFEN)?.engine, !before.isEmpty,
            let after = sidecar.data(at: context.toFEN)?.engine.first,
            let position = OpeningFENKey.position(from: context.fromFEN)
        else {
            return nil
        }

        let mover = position.sideToMove
        let winBefore = winPercent(before[0], for: mover)
        let winAfter = winPercent(after, for: mover)

        var input = MoveClassifier.Input(
            winPercentBefore: winBefore,
            winPercentAfter: winAfter,
            isBestMove: before[0].uci == context.uci
        )
        if before.count > 1 {
            input.gapToSecondBest = winBefore - winPercent(before[1], for: mover)
        }
        // Le meilleur coup était-il une TACTIQUE nette (mat ou prise) ?
        // Condition de l'« occasion manquée » : rater un plan positionnel n'en
        // est pas une, rater un mat ou une pièce en est une. Approximation
        // assumée sur la notation du coup, faute d'une recherche ici.
        input.bestMoveWasTactical = before[0].mate != nil || before[0].san.contains("x")

        let board = Board(position: position)
        if let applied = OpeningExplorerViewModel.apply(uci: context.uci, to: board) {
            input.isSacrifice = MoveClassifier.involvesSacrifice(
                move: applied.move, boardAfterMove: applied.board
            )
            if input.isSacrifice, let nextUCI = context.nextUCI,
               let next = OpeningExplorerViewModel.apply(uci: nextUCI, to: applied.board) {
                input.sacrificeImmediatelyRecaptured = MoveClassifier.isImmediatelyRecaptured(
                    applied.move, byNext: next.move
                )
            }
        }

        let quality = MoveClassifier.classify(input)
        return displayed.contains(quality) ? quality : nil
    }

    /// Probabilité de gain d'une ligne moteur, DU POINT DE VUE du camp donné.
    ///
    /// Le sidecar est toujours au point de vue des BLANCS (une seule
    /// convention dans toute l'app) ; ``MoveClassifier`` attend, lui, le point
    /// de vue du joueur qui vient de jouer. C'est ici, et nulle part ailleurs,
    /// que le signe s'inverse.
    private static func winPercent(_ line: LabsEngineLine, for color: Piece.Color) -> Double {
        let white: Double
        if let mate = line.mate {
            white = EvalConversion.winPercentage(mate: mate)
        } else {
            white = EvalConversion.winPercentage(cp: line.cp ?? 0)
        }
        return color == .white ? white : 100 - white
    }
}
