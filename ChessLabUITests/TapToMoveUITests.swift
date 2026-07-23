import XCTest

/// Le tap-tap (clic départ / clic arrivée) doit marcher même quand le doigt
/// tremble un peu.
///
/// Bug signalé le 16/07/2026 : « des fois je suis obligé de dragguer la pièce
/// car le clic départ / clic arrivée ne fonctionne pas ». Cause : le plateau
/// ne considérait un geste comme un tap qu'en dessous de 8 px de
/// déplacement — plus serré que la tolérance d'iOS. Au-delà, il jouait un
/// « glissement » de la case vers ELLE-MÊME : coup illégal, rejeté en
/// silence, et surtout aucune sélection.
///
/// Aucun test ne pouvait l'attraper : `tap()` de XCUITest est au pixel près.
/// Il faut donc simuler le tremblement à la main.
final class TapToMoveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func startGame() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["Contre Stockfish"].waitForExistence(timeout: 5))
        app.buttons["Contre Stockfish"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15))
        return app
    }

    /// Un tap parfait : le cas qui marchait déjà — filet de sécurité.
    @MainActor
    func testACleanTapTapPlaysTheMove() throws {
        let app = startGame()

        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()

        XCTAssertEqual(app.otherElements["square_e4"].label, "Case e4, pion blanc")
        XCTAssertEqual(app.otherElements["square_e2"].label, "Case e2, vide")
    }

    /// Le cas du bug : le doigt bouge de ~10 pt en tapant la pièce — au-delà
    /// de l'ancien seuil de 8 px, mais toujours sur la même case. La pièce
    /// doit être SÉLECTIONNÉE, donc le tap suivant doit jouer le coup.
    @MainActor
    func testAShakyTapStillSelectsThePiece() throws {
        let app = startGame()

        let e2 = app.otherElements["square_e2"]
        let start = e2.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // 10 pt : au-delà de l'ancien seuil, en deçà d'une case (~44 pt), donc
        // le doigt n'a pas quitté e2.
        let shaky = e2.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 10, dy: -10))
        start.press(forDuration: 0.05, thenDragTo: shaky)

        app.otherElements["square_e4"].tap()

        XCTAssertEqual(
            app.otherElements["square_e4"].label, "Case e4, pion blanc",
            "un tap tremblé doit sélectionner la pièce, pas se perdre en glissement vers sa propre case"
        )
    }
}

/// Taper une pièce ADVERSE pour la capturer.
///
/// Bug signalé le 18/07/2026, capture d'écran à l'appui : une sélection reste
/// affichée (case bleue + points de coups légaux + cercle de capture autour du
/// fou adverse), et plus aucun tap ne répond — seul le glisser fonctionne.
///
/// Cause : dans ``ChessBoardView``, une pièce ne reçoit un geste que si elle
/// est déplaçable (``isDraggable``). Une pièce adverse n'en a donc aucun, mais
/// restait TESTABLE AU TOUCHER et se dessine au-dessus de la grille : le tap
/// était avalé par son glyphe et n'atteignait jamais la case. La grille est un
/// frère dans le `ZStack`, pas un ancêtre — un tap non consommé n'est pas
/// transmis, il est perdu.
///
/// Invisible sur un déplacement vers une case VIDE, d'où le « des fois ».
/// Invisible aussi en mode deux joueurs, où `draggableColor` est `nil` et où
/// toutes les pièces sont donc déplaçables — le test doit passer par « Jouer ».
final class TapToCaptureUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTappingAnOpponentPieceCapturesIt() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["Contre Stockfish"].waitForExistence(timeout: 5))
        app.buttons["Contre Stockfish"].tap()

        // Position choisie pour qu'une capture soit disponible AU PREMIER coup
        // des Blancs : e4 prend d5. Sans FEN imposée, la réponse du moteur
        // rendrait le test non déterministe.
        let toggle = app.switches["useCustomFEN"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()

        let field = app.textFields["customFENField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2")

        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 15))

        // Le geste exact du rapport : taper sa pièce, puis taper la pièce à
        // capturer. Avant correction, la seconde frappe ne faisait rien.
        app.otherElements["square_e4"].tap()
        app.otherElements["square_d5"].tap()

        let d5 = app.otherElements["square_d5"]
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, d5.label != "Case d5, pion blanc" {
            usleep(200_000)
        }
        XCTAssertEqual(
            d5.label, "Case d5, pion blanc",
            "taper une pièce adverse doit la capturer, pas avaler le tap"
        )
        XCTAssertEqual(app.otherElements["square_e4"].label, "Case e4, vide")
    }
}
