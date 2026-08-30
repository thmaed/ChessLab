import ChessKit

/// La précision par joueur d'une partie de VARIANTE.
///
/// Le calcul lui-même est celui du mode « Contre l'ordinateur »
/// (``AccuracyScore``) : une perte de probabilité de gain par coup, pondérée
/// par ce qui bougeait et ce qui était en jeu. Seule l'entrée change — les
/// écrans d'analyse des variantes tiennent une ligne unique de demi-coups,
/// indexée par un entier, là où le mode classique parcourt un arbre de coups.
///
/// Ce fichier existe pour que les trois écrans de variante ne recopient pas
/// trois fois la même boucle : Chess960, les huit variantes du hub, et le
/// Duck Chess partagent exactement la même forme de données.
///
/// ## Ce que cette précision vaut
///
/// Elle vaut ce que vaut l'évaluation dont elle est tirée, et celle-ci est
/// approximative dans la plupart des variantes — Fairy-Stockfish n'a de
/// réseau dédié que pour quelques-unes, et le Duck Chess est évalué par un
/// Stockfish qui ne voit pas le canard. C'est la même approximation que les
/// pastilles de qualité, déjà affichées à côté : les deux disent la même
/// chose avec la même confiance, ce qui vaut mieux que de n'en montrer
/// qu'une.
enum VariantAccuracy {

    /// - parameter plyCount: nombre de demi-coups joués.
    /// - parameter winPercentWhite: probabilité de gain POV BLANCS à un
    ///   demi-coup donné, `nil` si la position n'a pas encore été évaluée.
    /// - parameter moverAt: le camp qui joue le demi-coup `i + 1`, c'est-à-dire
    ///   le trait de la position `i`.
    static func byColor(
        plyCount: Int,
        winPercentWhite: (Int) -> Double?,
        moverAt: (Int) -> Piece.Color?
    ) -> [Piece.Color: Double] {
        // Trois séries parallèles, l'ordre des coups portant l'information :
        // la probabilité de gain le long de la partie (position de départ
        // COMPRISE — sans elle le premier coup n'aurait pas de « avant »),
        // qui a joué, et ce que le coup a coûté.
        var whiteWinPercents: [Double] = []
        var movers: [Piece.Color] = []
        var losses: [Double] = []

        for ply in 0..<max(0, plyCount) {
            guard let before = winPercentWhite(ply),
                  let after = winPercentWhite(ply + 1),
                  let mover = moverAt(ply)
            else { continue }
            if whiteWinPercents.isEmpty { whiteWinPercents.append(before) }

            let beforeMoverPOV = mover == .white ? before : 100 - before
            let afterMoverPOV = mover == .white ? after : 100 - after
            whiteWinPercents.append(after)
            movers.append(mover)
            losses.append(max(0, beforeMoverPOV - afterMoverPOV))
        }

        let weights = AccuracyScore.moveWeights(whiteWinPercents: whiteWinPercents)
        guard weights.count == losses.count, !losses.isEmpty else { return [:] }

        var result: [Piece.Color: Double] = [:]
        for color in [Piece.Color.white, .black] {
            let indices = movers.indices.filter { movers[$0] == color }
            guard !indices.isEmpty else { continue }
            result[color] = AccuracyScore.accuracy(
                winPercentLosses: indices.map { losses[$0] },
                weights: indices.map { weights[$0] }
            )
        }
        return result
    }
}
