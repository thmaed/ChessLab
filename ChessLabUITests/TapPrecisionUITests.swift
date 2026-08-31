import XCTest

/// Précision du **tap-tap**, côté case d'ARRIVÉE.
///
/// Signalé en usage réel le 14/08/2026 : « ça coince des fois, j'ai de la
/// peine à cliquer sur la case d'arrivée — le déplacement (glisser) fonctionne
/// bien ».
///
/// Asymétrie soupçonnée, à confirmer par ces tests :
///
/// - la case de DÉPART porte une pièce, donc un `DragGesture(minimumDistance: 0)`
///   avec un repli de tap à 12 pt : un doigt qui tremble est rattrapé, et
///   au-delà le geste devient un glissement qui joue quand même le coup ;
/// - la case d'ARRIVÉE, elle, est une case NUE de la grille, qui n'a qu'un
///   `onTapGesture`. Celui-ci s'annule dès quelques points de dérive, et
///   **rien ne le rattrape** : le tap est simplement perdu.
///
/// S'y ajoute que le rattrapage vers la case légale la plus proche, ajouté au
/// glissement, ne s'applique PAS au tap : viser 2 pt à côté ne joue rien.
///
/// `tap()` de XCUITest étant au pixel près, il faut simuler la dérive à la
/// main — comme le fait déjà `TapToMoveUITests` pour la case de départ.
@MainActor
final class TapPrecisionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func startGame() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["Contre l'ordinateur"].waitForExistence(timeout: 5))
        app.buttons["Contre l'ordinateur"].tap()
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

    @MainActor
    private func waitForLabel(_ expected: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label == expected { return true }
            usleep(150_000)
        }
        return element.label == expected
    }

    /// **Le symptôme.** Le doigt dérive de 0,3 case en tapant l'arrivée — il
    /// reste LARGEMENT dans e4, mais au-delà de la tolérance d'un tap.
    @MainActor
    func testAShakyTapOnTheDestinationSquareStillPlaysTheMove() throws {
        let app = startGame()
        let s = square("e4", in: app).frame.height

        square("e2", in: app).tap() // sélection : ce chemin-là marche déjà

        let start = center("e4", in: app)
        let drifted = start.withOffset(CGVector(dx: 0, dy: -0.3 * s))
        start.press(forDuration: 0.05, thenDragTo: drifted)

        XCTAssertTrue(
            waitForLabel("Case e4, pion blanc", on: square("e4", in: app)),
            "un tap tremblé sur la case d'arrivée doit jouer le coup, pas se perdre"
        )
    }

    /// Le tap doit bénéficier du **même rattrapage** que le glissement :
    /// relâcher juste au-delà du bord de la case visée joue quand même le coup.
    /// Sans quoi le tap-tap est plus exigeant que le glisser — exactement ce
    /// que décrit le rapport.
    @MainActor
    func testATapJustPastTheDestinationSquareStillPlaysTheMove() throws {
        let app = startGame()
        let s = square("e4", in: app).frame.height

        square("e2", in: app).tap()

        // 0,6 case au-dessus du centre de e4 : géométriquement dans e5, mais
        // dans le rayon de rattrapage de e4 (0,85) — et hors de celui de e3
        // (1,6). Cas déjà couvert côté glisser par `DragPrecisionUITests`.
        center("e4", in: app).withOffset(CGVector(dx: 0, dy: -0.6 * s)).tap()

        XCTAssertTrue(
            waitForLabel("Case e4, pion blanc", on: square("e4", in: app)),
            "le tap-tap ne doit pas être plus exigeant que le glisser-déposer"
        )
    }

    /// Filet de sécurité : un tap PROPRE doit continuer de marcher, et un tap
    /// franchement ailleurs ne doit rien jouer.
    @MainActor
    func testACleanTapStillPlaysAndAFarTapDoesNot() throws {
        let app = startGame()

        square("e2", in: app).tap()
        square("a6", in: app).tap() // loin de toute cible : désélection

        XCTAssertEqual(square("e2", in: app).label, "Case e2, pion blanc")
        XCTAssertEqual(square("e4", in: app).label, "Case e4, vide")

        square("e2", in: app).tap()
        square("e4", in: app).tap()

        XCTAssertTrue(
            waitForLabel("Case e4, pion blanc", on: square("e4", in: app)),
            "le tap-tap exact doit rester intact"
        )
    }
}
