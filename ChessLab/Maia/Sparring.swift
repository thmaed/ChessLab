import Foundation

/// Mode « Sparring » : le personnage se relâche quand il vous domine et se
/// durcit quand vous le dominez, pour que la partie reste disputée.
///
/// Nommé, choisi avant la partie, désactivé par défaut, écrit dans l'Aide —
/// jamais en cachette (décision du 21/08/2026). Ne touche que la consigne
/// donnée à Maia, dans une bande bornée autour du niveau affiché ; le filet
/// et les seuils restent ceux du niveau.
enum Sparring {
    /// Bande autour du niveau affiché.
    static let maxOffset: Double = 150
    /// Pas par coup du personnage quand le score dépasse le seuil.
    static let step: Double = 25
    /// Score (centipions, point de vue du personnage) au-delà duquel il se
    /// relâche ; en dessous de l'opposé, il se durcit.
    static let thresholdCp = 250

    /// Le décalage après un coup du personnage évalué à `moverCp`.
    static func offset(after moverCp: Int?, current: Double) -> Double {
        guard let cp = moverCp else { return current }
        if cp >= thresholdCp { return max(-maxOffset, current - step) }
        if cp <= -thresholdCp { return min(maxOffset, current + step) }
        // Partie disputée : on revient doucement vers le niveau nominal.
        if current > 0 { return max(0, current - step / 2) }
        if current < 0 { return min(0, current + step / 2) }
        return 0
    }
}
