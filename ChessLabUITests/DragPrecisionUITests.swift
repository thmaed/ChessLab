import XCTest

/// Précision du glisser-déposer, **de bout en bout dans l'app**.
///
/// `BoardGeometryTests` couvre le calcul ; ce fichier couvre le câblage : que
/// le résolveur soit bien branché sur le geste, avec les bonnes cibles
/// légales, et que l'ordre des branches de `onEnded` tienne dans une vraie
/// vue. Une erreur de câblage laisse la suite unitaire entièrement verte.
///
/// Tous les points de relâchement sont calculés à partir de la **taille de
/// case mesurée** (`frame.height` d'une case), jamais en points en dur : le
/// plateau n'a pas la même taille sur iPhone, iPad et Mac.
@MainActor
final class DragPrecisionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func startGame(fen: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["Contre l'ordinateur"].waitForExistence(timeout: 5))
        app.buttons["Contre l'ordinateur"].tap()

        if let fen {
            let toggle = app.switches["useCustomFEN"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            toggle.tap()
            let field = app.textFields["customFENField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(fen)
        }

        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func square(_ notation: String, in app: XCUIApplication) -> XCUIElement {
        app.otherElements["square_\(notation)"]
    }

    @MainActor
    private func center(_ notation: String, in app: XCUIApplication) -> XCUICoordinate {
        square(notation, in: app).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    /// Attend qu'une case porte le libellé voulu : le coup part par un chemin
    /// asynchrone (moteur, animation), un `XCTAssertEqual` immédiat mesurerait
    /// l'ordonnancement, pas le comportement.
    @MainActor
    private func waitForLabel(_ expected: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label == expected { return true }
            usleep(150_000)
        }
        return element.label == expected
    }

    // MARK: Le rattrapage — la raison d'être du chantier

    /// Relâcher **à côté** de la case visée joue quand même le coup.
    ///
    /// Le doigt finit dans e5, qui n'est pas une cible légale du pion e2 ; le
    /// centre de e4 est à 0,6 case, sous le rayon de rattrapage (0,85). Avant
    /// ce chantier, le découpage strict donnait e5 : coup illégal, rien joué,
    /// et un joueur qui recommence sans comprendre.
    @MainActor
    func testADropJustPastTheTargetSquareStillPlaysTheMove() throws {
        let app = startGame()
        let s = square("e4", in: app).frame.height
        XCTAssertGreaterThan(s, 0, "taille de case mesurable")

        // 0,6 case au-dessus du centre de e4 : géométriquement dans e5, mais
        // dans le rayon de e4 — et hors de celui de e3 (1,6 case).
        let drop = center("e4", in: app).withOffset(CGVector(dx: 0, dy: -0.6 * s))
        center("e2", in: app).press(forDuration: 0.05, thenDragTo: drop)

        XCTAssertTrue(
            waitForLabel("Case e4, pion blanc", on: square("e4", in: app)),
            "un relâchement à 0,6 case du centre doit être rattrapé sur e4"
        )
        XCTAssertEqual(square("e2", in: app).label, "Case e2, vide")
    }

    // MARK: Les annulations — la règle produit « rien joué, rien reproché »

    /// Relâcher **loin du plateau** ne joue rien.
    ///
    /// Régression du bornage : l'ancien `min(7, max(0, …))` ramenait un point
    /// hors plateau sur la case de bord la plus proche et pouvait jouer un
    /// coup jamais visé. Ici on sort par le bas de **une case pleine** sous le
    /// bord — le double de la marge de grâce, et assez près pour rester dans
    /// la fenêtre sur tous les gabarits.
    @MainActor
    func testADropFarOffTheBoardPlaysNothing() throws {
        let app = startGame()
        let s = square("e2", in: app).frame.height

        // e2 est à 1,5 case du bord bas : +2,5 cases ⇒ 1 case SOUS le plateau.
        let outside = center("e2", in: app).withOffset(CGVector(dx: 0, dy: 2.5 * s))
        center("e2", in: app).press(forDuration: 0.05, thenDragTo: outside)

        XCTAssertEqual(
            square("e2", in: app).label, "Case e2, pion blanc",
            "relâcher hors du plateau doit annuler, pas jouer la case de bord la plus proche"
        )
        XCTAssertEqual(square("e3", in: app).label, "Case e3, vide")
        XCTAssertEqual(square("e4", in: app).label, "Case e4, vide")
    }

    /// Relâcher **là où aucune cible légale n'est proche** ne joue rien.
    ///
    /// e6 est à deux cases de e4, très au-delà du rayon : le rattrapage ne
    /// doit pas « tirer » le coup de si loin. C'est ce qui empêche un rayon
    /// généreux de devenir un devin.
    @MainActor
    func testADropWithNoLegalTargetNearbyPlaysNothing() throws {
        let app = startGame()

        center("e2", in: app).press(forDuration: 0.05, thenDragTo: center("e6", in: app))

        XCTAssertEqual(square("e2", in: app).label, "Case e2, pion blanc")
        XCTAssertEqual(square("e4", in: app).label, "Case e4, vide")
        XCTAssertEqual(square("e3", in: app).label, "Case e3, vide")
    }

    /// Relâcher **sur sa propre case** après un vrai déplacement du doigt
    /// annule ET laisse la pièce sélectionnée : le joueur enchaîne au tap.
    ///
    /// Le piège que ce test fige : sans la comparaison sur la case
    /// *géométrique*, le résolveur serait appelé, e2 ne serait pas une cible
    /// légale (aucun coup ne va d'une case à elle-même), le rattrapage
    /// s'activerait, et le centre de e3 n'est qu'à une demi-case — le geste de
    /// renoncement jouerait un coup.
    ///
    /// Distinct de `TapToMoveUITests` : là-bas le doigt bouge de 10 pt, sous
    /// la tolérance de tap. Ici il bouge de 0,4 case (≈ 18 pt sur iPhone),
    /// **au-delà** — c'est l'autre branche.
    @MainActor
    func testADropBackOnTheOriginSquareCancelsAndKeepsTheSelection() throws {
        let app = startGame()
        let s = square("e2", in: app).frame.height

        // 0,4 case : au-delà de la tolérance de tap (12 pt), en deçà de la
        // demi-case — le doigt n'a donc pas quitté e2.
        let stillInsideE2 = center("e2", in: app).withOffset(CGVector(dx: 0, dy: -0.4 * s))
        center("e2", in: app).press(forDuration: 0.05, thenDragTo: stillInsideE2)

        XCTAssertEqual(
            square("e3", in: app).label, "Case e3, vide",
            "renoncer sur sa case de départ ne doit RIEN jouer"
        )
        XCTAssertEqual(square("e2", in: app).label, "Case e2, pion blanc")

        // La sélection a survécu : un simple tap sur e4 joue le coup.
        square("e4", in: app).tap()
        XCTAssertTrue(
            waitForLabel("Case e4, pion blanc", on: square("e4", in: app)),
            "l'annulation doit conserver la sélection, pas la vider"
        )
    }

    // MARK: Promotion

    /// Le choix de promotion s'ouvre aussi quand le coup arrive **par
    /// glissement rattrapé** — le chemin du drag a changé, pas la promotion.
    @MainActor
    func testADraggedPromotionStillOpensThePicker() throws {
        // Roi noir en h8, PAS en e8 : un pion ne capture pas devant lui, il
        // serait bloqué et e8 ne figurerait dans aucune cible légale — le test
        // échouerait sans rien dire de l'app.
        let app = startGame(fen: "7k/4P3/8/8/8/8/8/4K3 w - - 0 1")
        // Garde-fou : si la saisie du FEN cessait de fonctionner, l'échec
        // pointerait ici plutôt que sur l'absence de choix de promotion.
        XCTAssertEqual(
            square("e7", in: app).label, "Case e7, pion blanc",
            "position personnalisée non appliquée"
        )
        let s = square("e8", in: app).frame.height

        // Relâchement volontairement imprécis : 0,7 case au-dessus du centre de
        // e8, donc 0,2 case HORS plateau — dans la marge de grâce, qui doit
        // rendre e8 malgré le débordement.
        let drop = center("e8", in: app).withOffset(CGVector(dx: 0, dy: -0.7 * s))
        center("e7", in: app).press(forDuration: 0.05, thenDragTo: drop)

        // On interroge une TUILE, pas l'identifiant `promotionPicker` de la
        // carte : mesuré, `app.otherElements["promotionPicker"]` ne matche
        // jamais — l'identifiant est posé sur un conteneur que SwiftUI
        // n'expose pas comme élément d'accessibilité à part entière. C'est
        // aussi par les tuiles que `LayoutOverflowUITests` procède.
        XCTAssertTrue(
            app.buttons["Dame"].waitForExistence(timeout: 10),
            "un pion glissé sur la 8e doit ouvrir le choix de promotion"
        )
    }
}
