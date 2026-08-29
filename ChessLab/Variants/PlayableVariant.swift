import SwiftUI

/// Ce qu'un écran de réglages a besoin de savoir sur une variante — sans se
/// soucier de QUI arbitre sa légalité. ``FairyVariant`` (lot A : ChessKit
/// reste l'arbitre) et ``EngineLegalityVariant`` (lot B : Fairy-Stockfish
/// devient l'arbitre) partagent ce protocole pour réutiliser
/// ``FairyVariantSetupView`` tel quel — leurs vues-modèles de PARTIE, elles,
/// restent volontairement séparées : la mécanique d'application d'un coup y
/// diffère bien trop pour qu'une abstraction commune vaille son coût.
protocol PlayableVariant {
    var id: String { get }
    var displayName: String { get }
    var rules: String { get }
    var icon: String { get }
    var tint: Color { get }
    /// La variante se joue-t-elle aussi à DEUX sur le même appareil ?
    ///
    /// Faux par défaut, et ce n'est pas une limite technique : les autres
    /// variantes du hub tirent leur intérêt du niveau de l'adversaire, alors
    /// que le Duck Chess est un jeu de salon — poser le canard sous le nez de
    /// l'autre fait la moitié du sel, et une machine ne rend pas ça.
    var supportsTwoPlayers: Bool { get }
}

extension PlayableVariant {
    var supportsTwoPlayers: Bool { false }
}

extension FairyVariant: PlayableVariant {}
extension EngineLegalityVariant: PlayableVariant {}
extension DuckChessVariant: PlayableVariant {
    var supportsTwoPlayers: Bool { true }
}
