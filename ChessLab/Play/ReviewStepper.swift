import ChessKit
import Foundation

/// La navigation en consultation contre l'ordinateur : par coup COMPLET, et
/// non par demi-coup. Les flèches s'arrêtent toujours sur une position où
/// c'est AU JOUEUR de jouer, si bien que « Reprendre ici » y reprend sa
/// partie — et non celle du moteur (demande du 23/10/2026, étendue aux
/// variantes contre l'ordinateur le 24/10).
///
/// Pur. Trois façons de dire quelles positions sont celles du joueur :
/// - la PARITÉ, quand les coups alternent toujours (jeu classique, Chess960) ;
/// - le camp au trait inscrit dans la FEN de chaque position (variantes) ;
/// - la couleur de qui JOUE le coup suivant, quand les coups n'alternent pas
///   toujours : au milieu d'un tour double du Coup Volé, la FEN donne le
///   trait à l'adversaire alors que le même camp rejoue.
struct ReviewStepper {
    let totalPlies: Int
    private let userPly: (Int) -> Bool

    init(totalPlies: Int, isUserPly: @escaping (Int) -> Bool) {
        self.totalPlies = totalPlies
        self.userPly = isUserPly
    }

    /// `userMovesOnEvenPlies` : vrai si c'est au joueur de jouer après un
    /// nombre PAIR de demi-coups.
    init(totalPlies: Int, userMovesOnEvenPlies: Bool) {
        self.init(totalPlies: totalPlies) { ($0 % 2 == 0) == userMovesOnEvenPlies }
    }

    /// À partir du journal des positions (FEN) de la partie : une position du
    /// joueur est une position où il a le trait.
    init(totalPlies: Int, fenLog: [String], userColor: Piece.Color) {
        self.init(totalPlies: totalPlies) { ply in
            ply < fenLog.count && Self.sideToMove(fen: fenLog[ply]) == userColor
        }
    }

    /// À partir de la couleur de qui a joué chaque coup : la position avant le
    /// coup `p` est au joueur si c'est lui qui l'a joué.
    init(moverColors: [Piece.Color], userColor: Piece.Color) {
        self.init(totalPlies: moverColors.count) { ply in
            ply < moverColors.count && moverColors[ply] == userColor
        }
    }

    func isUserPly(_ ply: Int) -> Bool { userPly(ply) }

    /// La position du joueur juste avant `ply`, `nil` s'il n'y en a pas.
    func previous(from ply: Int) -> Int? {
        guard ply > 0 else { return nil }
        return stride(from: ply - 1, through: 0, by: -1).first(where: userPly)
    }

    /// La position du joueur juste après `ply` — la position vive
    /// (`totalPlies`) s'il n'y en a plus, `nil` si l'on y est déjà.
    func next(from ply: Int) -> Int? {
        guard ply < totalPlies else { return nil }
        return (ply + 1...totalPlies).first(where: userPly) ?? totalPlies
    }

    /// Le camp au trait d'une FEN (2e champ), y compris d'une FEN de variante.
    static func sideToMove(fen: String) -> Piece.Color? {
        let fields = fen.split(separator: " ")
        guard fields.count >= 2 else { return nil }
        switch fields[1] {
        case "w": return .white
        case "b": return .black
        default: return nil
        }
    }
}
