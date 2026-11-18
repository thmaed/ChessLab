import Foundation

/// Les quatre CARACTÉRISTIQUES d'un personnage, de 1 à 5, montrées en jauges à la place de sa phrase (demande de
/// l'utilisateur, 17/11/2026). Choisies le même jour : Attaque, Solidité, Échanges, Imprévisible — la « vitesse »
/// a été écartée (ce n'est que le délai d'affichage du coup, rien de la façon de jouer).
///
/// Rien d'inventé : chaque note se lit dans les réglages qui FONT jouer le personnage — les poids de son style
/// (``StyleProfile``) et sa température de tirage. Maia, sans style, est au milieu partout : c'est l'étalon.
struct OpponentTraits: Equatable {
    /// Cherche le roi adverse : échecs, pièces vers le roi, pions lancés, sacrifices.
    let attack: Int
    /// Roque, développe, évite les pions faibles et les sacrifices.
    let solidity: Int
    /// Aime échanger — les dames surtout — et ramasser le matériel ; 1 = évite les échanges.
    let trades: Int
    /// S'écarte du coup le plus humain : la température du tirage (au-delà de 1, plus erratique qu'un humain moyen).
    let unpredictability: Int

    init(_ profile: OpponentProfile) {
        let raw = Self.raw(profile)
        let scale = Self.scale
        attack = Self.centered(raw.attack, maxAbs: scale.attack)
        solidity = Self.centered(raw.solidity, maxAbs: scale.solidity)
        trades = Self.centered(raw.trades, maxAbs: scale.trades)
        unpredictability = switch profile.temperature {
        case ..<0.85: 1
        case ..<0.95: 2
        case ..<1.05: 3
        case ..<1.3: 4
        default: 5
        }
    }

    private struct Raw { var attack, solidity, trades: Double }

    private static func raw(_ profile: OpponentProfile) -> Raw {
        let w = profile.style.weights
        func weight(_ trait: StyleTrait) -> Double { w[trait] ?? 0 }
        return Raw(
            attack: weight(.check) + weight(.towardKing) + weight(.pawnStorm) + weight(.sacrifice),
            solidity: weight(.castle) + weight(.development) - weight(.weakPawn) - 0.5 * weight(.sacrifice),
            trades: weight(.equalTrade) + weight(.queenTrade) + 0.5 * weight(.materialGain)
        )
    }

    /// Le plus grand écart de toute la galerie, par caractéristique : les notes se lisent les unes par rapport
    /// aux autres.
    private static let scale: Raw = {
        let all = OpponentProfile.all.map(raw)
        return Raw(attack: all.map { abs($0.attack) }.max() ?? 0,
                   solidity: all.map { abs($0.solidity) }.max() ?? 0,
                   trades: all.map { abs($0.trades) }.max() ?? 0)
    }()

    /// 3 = neutre ; ±2 au plus loin observé dans la galerie.
    private static func centered(_ raw: Double, maxAbs: Double) -> Int {
        guard maxAbs > 0 else { return 3 }
        return min(5, max(1, Int((3 + 2 * raw / maxAbs).rounded())))
    }
}
