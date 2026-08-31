import ChessKit
import CoreGraphics
import Testing
@testable import ChessLab

/// Géométrie du plateau et **résolution d'un relâchement vers une case**.
///
/// Ce que ces tests protègent : le rattrapage vers la case légale la plus
/// proche doit rendre le glisser-déposer tolérant SANS jamais jouer un coup
/// que le joueur n'a pas visé. Les deux exigences tirent en sens opposés, d'où
/// le nombre de cas limites.
///
/// Les XCUITests ne protègent de rien ici : ils tapent au centre exact des
/// cases. C'est la raison d'être de ce fichier.
struct BoardGeometryTests {

    private let s: CGFloat = 46 // case iPhone typique
    private var white: BoardGeometry { BoardGeometry(squareSize: s, orientation: .white) }
    private var black: BoardGeometry { BoardGeometry(squareSize: s, orientation: .black) }

    // MARK: Correspondance case ↔ point

    /// Le centre de chaque case retourne cette case — aux DEUX orientations.
    @Test func everySquareCenterResolvesToItself() {
        for geometry in [white, black] {
            for raw in 0..<64 {
                let square = Square(rawValue: raw)!
                let center = geometry.centerPoint(of: square)
                #expect(
                    geometry.geometricSquare(at: center) == square,
                    "centre de \(square.notation) (orientation \(geometry.orientation))"
                )
            }
        }
    }

    /// Une frontière est nette : juste à l'intérieur / juste à l'extérieur.
    @Test func squareBoundariesAreExact() {
        let geometry = white
        // Frontière verticale entre la colonne 0 (a) et la colonne 1 (b), à x = s.
        let insideA = CGPoint(x: s - 0.01, y: s * 7.5)   // rangée du bas = 1re
        let insideB = CGPoint(x: s + 0.01, y: s * 7.5)
        #expect(geometry.geometricSquare(at: insideA) == Square("a1"))
        #expect(geometry.geometricSquare(at: insideB) == Square("b1"))
    }

    // MARK: Non-régression — viser juste ne doit RIEN changer

    /// Quand la case géométrique **est** une cible légale, elle est retenue,
    /// même si le centre d'une autre cible légale est plus proche du point.
    /// Sans cette étape, le rattrapage introduirait des surprises là où le
    /// joueur visait correctement.
    @Test func geometricSquareWinsWhenItIsLegal() {
        let geometry = white
        let e3 = Square("e3")
        let e4 = Square("e4")
        // Point dans e3, mais collé au bord de e4 : le centre de e4 est plus
        // proche que celui de e3.
        var point = geometry.centerPoint(of: e3)
        point.y -= s * 0.45

        let resolved = geometry.resolve(point: point, legalTargets: [e3, e4])
        #expect(resolved == e3, "la case visée géométriquement prime sur la plus proche")
    }

    // MARK: Rattrapage

    /// Point entre deux cases dont **une seule** est légale → la légale.
    @Test func snapsToTheOnlyLegalNeighbour() {
        let geometry = white
        let e4 = Square("e4")
        // Point dans e5 (illégale ici), juste au-dessus de la frontière e4/e5.
        var point = geometry.centerPoint(of: Square("e5"))
        point.y += s * 0.45

        #expect(geometry.resolve(point: point, legalTargets: [e4]) == e4)
    }

    /// Point plus proche d'une case **illégale** que d'une légale : la légale
    /// gagne quand même, tant qu'elle est dans le rayon.
    @Test func anIllegalSquareNeverStealsTheDrop() {
        let geometry = white
        let d4 = Square("d4")
        // Centre exact de e4, qui n'est PAS une cible légale ici. d4 est à
        // une case de distance (46 pt) — au-delà de 0,85 × s = 39,1 pt.
        let onE4 = geometry.centerPoint(of: Square("e4"))
        #expect(geometry.resolve(point: onE4, legalTargets: [d4]) == nil, "hors rayon → annulation")

        // Décalé vers d4 : la distance tombe sous le rayon, la légale est prise.
        var closer = onE4
        closer.x -= s * 0.35
        #expect(geometry.resolve(point: closer, legalTargets: [d4]) == d4)
    }

    /// Deux cibles légales quasi-équidistantes → annulation. Mieux vaut ne
    /// rien jouer que deviner : c'est ce qui évite de brûler un essai de
    /// puzzle sur un doigt maladroit.
    @Test func ambiguityCancelsRatherThanGuesses() {
        let geometry = white
        let d4 = Square("d4")
        let f4 = Square("f4")
        // Exactement à mi-chemin des deux centres, sur e4 (illégale).
        let middle = geometry.centerPoint(of: Square("e4"))

        #expect(geometry.resolve(point: middle, legalTargets: [d4, f4]) == nil)
    }

    /// Mais une préférence NETTE entre les deux est respectée.
    @Test func aClearWinnerIsStillChosen() {
        let geometry = white
        let d4 = Square("d4")
        let f4 = Square("f4")
        var point = geometry.centerPoint(of: Square("e4"))
        point.x -= s * 0.30 // franchement vers d4

        #expect(geometry.resolve(point: point, legalTargets: [d4, f4]) == d4)
    }

    // MARK: Annulations

    /// Aucune cible légale dans le rayon → annulation.
    @Test func aDropInTheMiddleOfNowhereCancels() {
        let geometry = white
        let a8 = Square("a8")
        let point = geometry.centerPoint(of: Square("h1"))

        #expect(geometry.resolve(point: point, legalTargets: [a8]) == nil)
    }

    /// Une pièce bloquée (aucune cible) ne peut rien jouer.
    @Test func aPieceWithNoLegalTargetCancels() {
        let geometry = white
        let point = geometry.centerPoint(of: Square("e4"))

        #expect(geometry.resolve(point: point, legalTargets: []) == nil)
    }

    /// Hors plateau au-delà de la marge de grâce → annulation.
    @Test func aDropFarOutsideTheBoardCancels() {
        let geometry = white
        let far = CGPoint(x: -3 * s, y: 4 * s)

        #expect(geometry.geometricSquare(at: far) == nil)
        #expect(geometry.resolve(point: far, legalTargets: [Square("a4"), Square("a5")]) == nil)
    }

    /// **Régression du bornage** : un point très éloigné, aligné sur une case
    /// de bord parfaitement légale, ne doit PAS jouer ce coup. C'est
    /// exactement ce que faisait l'ancien `min(7, max(0, …))`.
    @Test func aFarAwayDropAlignedOnALegalEdgeSquareCancels() {
        let geometry = white
        let a4 = Square("a4")
        // Très à gauche du plateau, à la hauteur exacte de a4.
        let far = CGPoint(x: -5 * s, y: geometry.centerPoint(of: a4).y)

        #expect(geometry.resolve(point: far, legalTargets: [a4]) == nil)
    }

    /// Hors plateau **dans** la marge de grâce en visant a1 → la case de bord.
    /// Un doigt qui dépasse à peine ne doit pas être puni.
    @Test func aDropJustOutsideTheBoardStillReachesTheCornerSquare() {
        let geometry = white
        let a1 = Square("a1")
        let center = geometry.centerPoint(of: a1)
        // Sous le bord bas et à gauche du bord gauche, de 0,3 case.
        let justOutside = CGPoint(x: center.x - s * 0.3, y: center.y + s * 0.3)

        #expect(geometry.geometricSquare(at: justOutside) == a1)
        #expect(geometry.resolve(point: justOutside, legalTargets: [a1]) == a1)
    }

    // MARK: Le piège de l'annulation sur la case de départ

    /// Relâcher sur sa case de DÉPART annule — y compris tout près de son
    /// bord, avec une cible légale à une demi-case de là.
    ///
    /// C'est le geste de renoncement. La vue le traite AVANT d'appeler le
    /// résolveur (comparaison sur la case **géométrique**), car le résolveur,
    /// lui, snapperait : e2 n'est pas une cible légale — aucun coup ne va
    /// d'une case à elle-même — donc le rattrapage s'activerait et le centre
    /// de e3 n'est qu'à `0,5 × s`, dans le rayon.
    ///
    /// Ce test fige la raison d'être de cet ordre : il documente que le
    /// résolveur SEUL jouerait le coup.
    @Test func theResolverAloneWouldSnapAwayFromTheOriginSquare() {
        let geometry = white
        let e2 = Square("e2")
        let e3 = Square("e3")
        var point = geometry.centerPoint(of: e2)
        point.y -= s * 0.45 // bord haut de e2, vers e3

        // La case géométrique reste e2 : c'est ce que la vue teste en premier.
        #expect(geometry.geometricSquare(at: point) == e2)
        // Mais le résolveur, lui, snapperait sur e3 — d'où l'ordre dans
        // `onEnded` : case géométrique == départ ⇒ tap, sans appeler ceci.
        #expect(geometry.resolve(point: point, legalTargets: [e3, Square("e4")]) == e3)
    }

    // MARK: Orientation inversée

    /// Toute la géométrie doit tenir plateau retourné.
    @Test func snappingWorksWithBlackAtTheBottom() {
        let geometry = black
        let e4 = Square("e4")
        var point = geometry.centerPoint(of: Square("e5"))
        // Plateau retourné : e4 est SOUS e5 à l'écran, donc on descend en y.
        point.y -= s * 0.45

        #expect(geometry.resolve(point: point, legalTargets: [e4]) == e4)
    }

    // MARK: Le plafond du rattrapage (arbitrage Puzzles)

    /// **Propriété de sûreté** : le résolveur ne rend JAMAIS autre chose
    /// qu'une cible légale de la pièce tirée, ou `nil`.
    ///
    /// C'est ce qui borne le coût du rattrapage dans *Puzzles*, où un coup
    /// légal mais faux consomme un essai : le rattrapage ne peut pas inventer
    /// un coup que la pièce ne pouvait pas jouer, il ne peut que choisir parmi
    /// ceux qu'elle pouvait jouer — donc parmi ceux que le joueur visait.
    ///
    /// Balayage exhaustif au quart de case sur tout le plateau et sa marge,
    /// aux deux orientations : ~1 800 points, là où quelques cas choisis à la
    /// main laisseraient passer un coin non prévu.
    @Test func theResolverOnlyEverReturnsALegalTargetOrNothing() {
        let legalTargets = [Square("d4"), Square("e4"), Square("f6"), Square("a1"), Square("h8")]
        for geometry in [white, black] {
            for stepX in -2...34 {
                for stepY in -2...34 {
                    let point = CGPoint(x: CGFloat(stepX) * s / 4, y: CGFloat(stepY) * s / 4)
                    guard let resolved = geometry.resolve(point: point, legalTargets: legalTargets)
                    else { continue }
                    #expect(
                        legalTargets.contains(resolved),
                        "point (\(point.x), \(point.y)) a produit \(resolved.notation), hors des cibles légales"
                    )
                }
            }
        }
    }

    /// Le rattrapage ne franchit pas une case entière : relâcher au **centre
    /// exact** d'une case, alors qu'une cible légale est sa voisine directe,
    /// annule. Sans ce plafond, viser une case libre jouerait le coup d'à
    /// côté — et brûlerait un essai de puzzle sans que le joueur voie pourquoi.
    @Test func theSnapNeverReachesAcrossAWholeSquare() {
        let geometry = white
        for neighbour in ["d4", "f4", "e3", "e5", "d3", "f5"] {
            let target = Square(neighbour)
            let onE4 = geometry.centerPoint(of: Square("e4"))
            #expect(
                geometry.resolve(point: onE4, legalTargets: [target]) == nil,
                "le centre de e4 ne doit pas atteindre \(neighbour)"
            )
        }
    }

    // MARK: Levée du fantôme

    /// Le fantôme doit s'écarter de la main — des DEUX côtés de la table.
    ///
    /// En mode Table du jeu à deux, les glyphes sont tournés de 180° pour le
    /// joueur d'en face : son « haut » est le bas de l'écran. Un décalage codé
    /// en dur vers le haut de l'écran lui collerait le fantôme sous la main,
    /// c'est-à-dire précisément le défaut que la levée corrige.
    @Test @MainActor func theDragGhostLiftsAwayFromTheHandOnBothSidesOfTheTable() {
        let upright = ChessBoardView.dragLiftOffset(squareSize: s, rotated: false)
        let rotated = ChessBoardView.dragLiftOffset(squareSize: s, rotated: true)

        #expect(upright < 0, "joueur du bas : le fantôme monte à l'écran")
        #expect(rotated > 0, "joueur d'en face : il descend à l'écran")
        #expect(upright == -rotated, "même hauteur de levée pour les deux joueurs")
        // Assez pour dégager la pulpe du doigt (~20 pt), pas au point de
        // paraître détaché de la case visée.
        #expect(abs(upright) > 15 && abs(upright) < s)
    }
}
