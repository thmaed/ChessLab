import ChessKit
import CoreGraphics

/// Géométrie d'un échiquier : conversion case ↔ point, et **résolution d'un
/// point vers la case visée**.
///
/// **Espace de coordonnées** : points SwiftUI locaux au plateau, **origine en
/// haut à gauche**, côté = `squareSize × 8`. C'est l'espace nommé `"board"` de
/// ``ChessBoardView``.
///
/// Type valeur pur, sans SwiftUI : la géométrie vivait dans des méthodes
/// **privées d'une `View`**, donc intestable. Même parti pris que
/// ``BoardQuad`` côté scanner — le calcul est ici, les tests numériques
/// exacts dans `BoardGeometryTests`.
///
/// ## Pourquoi un résolveur, et pas un simple découpage
///
/// `Int(point.x / squareSize)` donne une frontière nette **au point près** :
/// sur une case de ~46 pt (iPhone), relâcher 1 pt au-delà du trait joue la
/// case voisine. chess.com et lichess résolvent vers **la case légale la plus
/// proche** — c'est ce que fait ``resolve(point:legalTargets:)``.
struct BoardGeometry: Equatable {
    let squareSize: CGFloat
    /// Couleur affichée en bas du plateau.
    let orientation: Piece.Color

    /// Rayon de rattrapage autour d'une cible légale, en fraction de case.
    ///
    /// La demi-diagonale d'une case vaut `0,707 × s` : **en dessous de cette
    /// valeur, un rayon ne servirait à rien** — il ne couvrirait même pas les
    /// coins de la case visée, déjà retenue telle quelle par l'étape 2 de
    /// ``resolve(point:legalTargets:)``. À `0,85`, on obtient ~18 pt de
    /// rattrapage orthogonal au-delà du bord de la case cible sur une case de
    /// 46 pt, soit la tolérance de type chess.com.
    ///
    /// Ne pas monter vers `1,0` : un relâchement **centré sur une case
    /// adjacente** pourrait alors être capté.
    static let snapRadiusRatio: CGFloat = 0.85

    /// Marge de grâce hors plateau, en fraction de case : un doigt qui dépasse
    /// à peine du bord en visant a1 ou h8 ne doit pas être puni. Au-delà, le
    /// relâchement est une **annulation**.
    static let outsideGraceRatio: CGFloat = 0.5

    /// Écart de distance en deçà duquel deux cibles sont jugées
    /// **indiscernables**, en fraction de case (~7 pt sur iPhone). Mieux vaut
    /// ne rien jouer que deviner — voir la garde d'ambiguïté.
    static let ambiguityRatio: CGFloat = 0.15

    /// Côté du plateau.
    var side: CGFloat { squareSize * 8 }

    // MARK: Case ↔ grille

    func square(row: Int, col: Int) -> Square {
        let file: Int
        let rank: Int
        if orientation == .white {
            file = col
            rank = 7 - row
        } else {
            file = 7 - col
            rank = row
        }
        return Square(rawValue: rank * 8 + file) ?? .a1
    }

    func gridPosition(of square: Square) -> (row: Int, col: Int) {
        let file = square.file.number - 1
        let rank = square.rank.value - 1
        if orientation == .white {
            return (row: 7 - rank, col: file)
        } else {
            return (row: rank, col: 7 - file)
        }
    }

    func centerPoint(of square: Square) -> CGPoint {
        let (row, col) = gridPosition(of: square)
        return CGPoint(
            x: CGFloat(col) * squareSize + squareSize / 2,
            y: CGFloat(row) * squareSize + squareSize / 2
        )
    }

    // MARK: Point → case

    /// Case sous le point, **sans aucun rattrapage**.
    ///
    /// - returns: `nil` si le point sort du plateau au-delà de la marge de
    ///   grâce. C'est le changement clé face à l'ancien
    ///   `min(7, max(0, …))`, qui **bornait** les coordonnées : relâcher loin
    ///   du plateau résolvait sur la case de bord la plus proche et pouvait
    ///   jouer un coup jamais visé.
    func geometricSquare(at point: CGPoint) -> Square? {
        let grace = squareSize * Self.outsideGraceRatio
        guard point.x >= -grace, point.x <= side + grace,
              point.y >= -grace, point.y <= side + grace
        else { return nil }
        // Le bornage subsiste ICI, mais seulement à l'intérieur de la marge de
        // grâce déjà validée : viser a1 en dépassant de 10 pt donne bien a1.
        let col = min(7, max(0, Int(floor(point.x / squareSize))))
        let row = min(7, max(0, Int(floor(point.y / squareSize))))
        return square(row: row, col: col)
    }

    /// Case visée par un relâchement, avec rattrapage vers la cible légale la
    /// plus proche.
    ///
    /// - parameter legalTargets: cases où la pièce tirée peut réellement
    ///   aller. **Doit venir de `board.legalMoves(forPieceAt:)`**, pas de
    ///   `legalTargetSquares` : ce dernier suit la SÉLECTION, or un glissement
    ///   ne sélectionne rien — il serait vide, ou relatif à une autre case.
    ///
    /// - returns: `nil` pour **annuler proprement** : ne rien jouer, conserver
    ///   la sélection, ne rien reprocher au joueur.
    ///
    /// L'ordre compte :
    /// 1. hors plateau au-delà de la marge de grâce → annulation ;
    /// 2. si la case géométrique est elle-même une cible légale, **elle est
    ///    retenue telle quelle** — zéro surprise quand le joueur vise juste,
    ///    le comportement d'avant est préservé au point près ;
    /// 3. sinon, la cible légale dont le centre est le plus proche, dans un
    ///    rayon plafonné ;
    /// 4. si les deux meilleures sont quasi-équidistantes → annulation.
    func resolve(point: CGPoint, legalTargets: [Square]) -> Square? {
        guard let geometric = geometricSquare(at: point) else { return nil }
        if legalTargets.contains(geometric) { return geometric }
        guard !legalTargets.isEmpty else { return nil }

        // Comparaison sur les CARRÉS des distances : pas de `sqrt` dans la
        // boucle, qui tourne à chaque image d'un glissement (au pire 27
        // cibles pour une dame au centre).
        let radiusSquared = pow(squareSize * Self.snapRadiusRatio, 2)
        var best: (square: Square, distanceSquared: CGFloat)?
        var runnerUpDistanceSquared: CGFloat?

        for target in legalTargets {
            let center = centerPoint(of: target)
            let dx = center.x - point.x
            let dy = center.y - point.y
            let distanceSquared = dx * dx + dy * dy
            guard distanceSquared <= radiusSquared else { continue }

            if let current = best, distanceSquared >= current.distanceSquared {
                if runnerUpDistanceSquared == nil || distanceSquared < runnerUpDistanceSquared! {
                    runnerUpDistanceSquared = distanceSquared
                }
            } else {
                runnerUpDistanceSquared = best?.distanceSquared
                best = (target, distanceSquared)
            }
        }

        guard let best else { return nil }

        // Garde d'ambiguïté. Les DEUX seules racines du calcul : l'écart de
        // distances n'est pas l'écart de leurs carrés, et deux `sqrt` par
        // relâchement (pas par image) sont négligeables.
        if let runnerUp = runnerUpDistanceSquared {
            let gap = sqrt(runnerUp) - sqrt(best.distanceSquared)
            if gap < squareSize * Self.ambiguityRatio { return nil }
        }
        return best.square
    }
}
