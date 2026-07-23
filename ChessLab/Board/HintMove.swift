import ChessKit

/// Une ligne suggérée par le moteur (indice du mode Jouer, ou flèches
/// MultiPV en continu du mode Analyser), classée par rang (1 = meilleur
/// coup). `strength` (0...1) mesure à quel point ce coup reste proche du
/// meilleur en évaluation ; 1 = aussi bon que le meilleur, valeurs
/// décroissantes vers le seuil d'affichage minimal.
struct HintMove: Identifiable, Equatable {
    /// Nature de la flèche : ce que VOUS pourriez jouer, ou ce que
    /// l'adversaire menace de jouer si vous passiez votre tour (Lot 5.G).
    enum Kind: Equatable {
        case best
        case threat
        /// « Il fallait jouer ça » : le meilleur coup de la position
        /// PRÉCÉDENTE, montré quand le coup joué s'est révélé fautif. Ni un
        /// coup à jouer maintenant, ni une menace — d'où son propre cas.
        case better
        /// Meilleur coup de la position affichée en REVUE d'une partie
        /// terminée : VERT (et non le gris de l'analyse live d'une position),
        /// lu dans la classification déjà calculée. Deux `reviewBest` de taille
        /// voisine quand deux coups se valent.
        case reviewBest
    }

    let rank: Int
    let from: Square
    let to: Square
    let strength: Double
    /// `.best` par défaut : tous les appelants existants suggèrent des coups
    /// à JOUER, seul le mode Analyser produit des menaces.
    var kind: Kind = .best

    /// Identité COMPOSITE (rang + cases), et non le seul rang : plusieurs
    /// flèches peuvent partager le même rang (ex. deux coups qui se valent en
    /// revue d'analyse). Des `id` dupliqués rendaient le `ForEach` de
    /// ``ChessBoardView`` indéfini — avertissement runtime, flèches
    /// manquantes ou mal animées.
    var id: String {
        let kindTag = switch kind {
        case .best: "b"
        case .threat: "t"
        case .better: "x"
        case .reviewBest: "r"
        }
        return "\(rank)-\(from.notation)-\(to.notation)-\(kindTag)"
    }
}

/// Construit les flèches ``HintMove`` à partir des lignes MultiPV connues
/// à l'instant T — partagé entre l'indice du mode Jouer
/// (``PlayViewModel``) et l'analyse en continu du mode Analyser
/// (``AnalysisViewModel``).
enum HintMoveBuilder {
    /// Écart maximal (en centipions) toléré par rapport au meilleur coup
    /// pour qu'une ligne secondaire (rang 2 ou 3) mérite encore sa flèche.
    /// Au-delà, le coup est jugé nettement inférieur et n'est pas suggéré.
    private static let maxGapCp: Double = 120
    /// Réduction de force minimale entre deux rangs consécutifs, même à
    /// évaluation rigoureusement égale : deux flèches ne sont jamais
    /// rendues identiques, l'écart visuel restant néanmoins discret dans
    /// ce cas (voir ``gapStrengthRange`` pour la part liée à l'écart
    /// d'évaluation réel).
    private static let rankStrengthStep: Double = 0.16
    /// Réduction de force additionnelle, proportionnelle à l'écart
    /// d'évaluation avec le meilleur coup (0 au meilleur coup, jusqu'à ce
    /// montant quand l'écart atteint ``maxGapCp``) : des coups très
    /// proches en force n'ont qu'une petite variation de taille, des coups
    /// nettement différents sont visuellement bien distingués.
    private static let gapStrengthRange: Double = 0.55

    /// Seuls les rangs 1 à 3 dont l'évaluation reste proche du meilleur
    /// coup obtiennent une flèche (une position sans bonne alternative
    /// n'affiche donc qu'une ou deux flèches, pas trois), avec une force
    /// (``HintMove/strength``) qui reflète cet écart.
    static func build(lanByRank: [Int: String], scoreByRank: [Int: Double]) -> [HintMove] {
        guard let bestScore = scoreByRank[1], let bestLan = lanByRank[1], bestLan.count >= 4 else {
            return []
        }

        return (1...3).compactMap { r -> HintMove? in
            guard let lan = lanByRank[r], lan.count >= 4, let score = scoreByRank[r] else { return nil }
            let gap = bestScore - score
            guard gap <= maxGapCp else { return nil }

            let gapFactor = min(1, max(0, gap / maxGapCp))
            let strength = max(
                0.12,
                1 - rankStrengthStep * Double(r - 1) - gapStrengthRange * gapFactor
            )
            let start = Square(String(lan.prefix(2)))
            let end = Square(String(lan.dropFirst(2).prefix(2)))
            return HintMove(rank: r, from: start, to: end, strength: strength)
        }
    }
}

/// Ce que les flèches du mode Analyser montrent.
///
/// Trois flèches en permanence, c'était la solution affichée en continu :
/// illisible, et pédagogiquement à l'envers puisque plus rien n'invite à
/// chercher. Le défaut ne montre donc que le meilleur coup ; « Aucune » sert
/// à revoir une partie sans être soufflé, « Trois » reste pour comparer des
/// candidats.
enum ArrowMode: String, CaseIterable, Identifiable {
    case off
    case best
    case topThree

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Aucune flèche"
        case .best: "Meilleur coup"
        case .topThree: "Trois meilleurs coups"
        }
    }

    var systemImage: String {
        switch self {
        case .off: "eye.slash"
        case .best: "arrow.up.right"
        case .topThree: "arrow.up.right.and.arrow.down.left"
        }
    }
}
