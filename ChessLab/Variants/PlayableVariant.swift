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
}

extension FairyVariant: PlayableVariant {}
extension EngineLegalityVariant: PlayableVariant {}
extension DuckChessVariant: PlayableVariant {}
