import Foundation

/// La navigation en consultation contre l'ordinateur : par coup COMPLET, et
/// non par demi-coup. Les flèches s'arrêtent toujours sur une position où
/// c'est AU JOUEUR de jouer, si bien que « Reprendre ici » y reprend sa
/// partie — et non celle du moteur (demande du 23/10/2026).
///
/// Pur : seuls comptent le nombre de demi-coups et la parité des positions
/// du joueur (une partie commencée depuis une position où les Noirs ont le
/// trait inverse cette parité).
struct ReviewStepper {
    let totalPlies: Int
    /// Vrai si c'est au joueur de jouer après un nombre PAIR de demi-coups.
    let userMovesOnEvenPlies: Bool

    func isUserPly(_ ply: Int) -> Bool { (ply % 2 == 0) == userMovesOnEvenPlies }

    /// La position du joueur juste avant `ply`, `nil` s'il n'y en a pas.
    func previous(from ply: Int) -> Int? {
        guard ply > 0 else { return nil }
        return stride(from: ply - 1, through: 0, by: -1).first(where: isUserPly)
    }

    /// La position du joueur juste après `ply` — la position vive
    /// (`totalPlies`) s'il n'y en a plus, `nil` si l'on y est déjà.
    func next(from ply: Int) -> Int? {
        guard ply < totalPlies else { return nil }
        return (ply + 1...totalPlies).first(where: isUserPly) ?? totalPlies
    }
}
