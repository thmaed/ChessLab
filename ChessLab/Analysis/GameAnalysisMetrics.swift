import ChessKit
import Foundation

/// Ce qu'une partie analysée laisse derrière elle, une fois la ligne
/// principale classée : de quoi rouvrir son bilan sans tout recalculer, et de
/// quoi, plus tard, en estimer le niveau.
///
/// ## Pourquoi la perte moyenne BRUTE, en plus de la précision
///
/// La précision affichée est déjà une moyenne de pertes — mais pondérée par la
/// volatilité de la position et écrasée par une exponentielle, deux traitements
/// qui servent la lisibilité d'un pourcentage et non la comparaison entre
/// parties. Pour caler une courbe « perte → Elo » il faut la grandeur non
/// transformée : la perte moyenne de probabilité de gain, en points de
/// pourcentage, tous coups à égalité.
///
/// ## Pourquoi la théorie ne compte pas
///
/// Réciter dix coups de Najdorf ne dit rien du niveau de personne : la perte y
/// est nulle par construction, et l'inclure ferait passer pour fort quiconque
/// connaît une longue ligne. ``classifiedCount`` et ``averageLoss`` excluent
/// donc les coups de livre — qui sont comptés à part, parce qu'un dénominateur
/// qui fond mérite d'être visible.
struct GameAnalysisMetrics: Equatable, Sendable {

    /// Version du BARÈME ayant produit ces chiffres.
    ///
    /// À incrémenter dès que change quoi que ce soit qui déplace les valeurs :
    /// seuils de classification, budget de recherche, formule de précision,
    /// traitement de la théorie. Sans elle, une moyenne glissante mélangerait
    /// des parties mesurées à des aunes différentes — et personne ne le verrait.
    /// Elle va de pair avec `AnalysisEvalStore.engineProfile`, qui joue le même
    /// rôle pour le cache disque : les deux se changent ensemble.
    static let currentVersion = 1

    struct Side: Equatable, Sendable {
        /// Précision affichée (0...100), telle que calculée par ``AccuracyScore``.
        var accuracy: Double?
        /// Perte moyenne de probabilité de gain, en points de pourcentage,
        /// NON pondérée et hors théorie. `nil` si aucun coup ne compte.
        var averageLoss: Double?
        /// Coups pris en compte — hors théorie.
        var classifiedCount: Int
        /// Coups de théorie reconnus, écartés des deux mesures ci-dessus.
        var bookCount: Int
    }

    var white: Side
    var black: Side
    var version: Int = GameAnalysisMetrics.currentVersion

    /// Un coup joué, réduit à ce que les métriques regardent.
    struct Move: Sendable {
        let mover: Piece.Color
        /// Perte de probabilité de gain pour le joueur qui vient de jouer.
        let loss: Double
        let isBook: Bool

        init(mover: Piece.Color, loss: Double, isBook: Bool) {
            self.mover = mover
            self.loss = loss
            self.isBook = isBook
        }
    }

    /// Agrège les coups d'une partie. Fonction pure : ni moteur, ni base, ni
    /// horloge — c'est ce qui la rend vérifiable sur des valeurs écrites à la
    /// main.
    ///
    /// - Parameter accuracyByColor: la précision déjà calculée par le pipeline
    ///   d'analyse. Elle n'est pas recalculée ici : deux formules pour un même
    ///   chiffre finiraient par diverger.
    static func compute(
        moves: [Move],
        accuracyByColor: [Piece.Color: Double]
    ) -> GameAnalysisMetrics {
        func side(_ color: Piece.Color) -> Side {
            let mine = moves.filter { $0.mover == color }
            let scored = mine.filter { !$0.isBook }
            let average = scored.isEmpty
                ? nil
                : scored.reduce(0.0) { $0 + max(0, $1.loss) } / Double(scored.count)
            return Side(
                accuracy: accuracyByColor[color],
                averageLoss: average,
                classifiedCount: scored.count,
                bookCount: mine.count - scored.count
            )
        }
        return GameAnalysisMetrics(white: side(.white), black: side(.black))
    }
}
