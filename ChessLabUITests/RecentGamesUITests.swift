import XCTest

/// Analyse d'une partie récente en un tap depuis l'accueil.
///
/// Le parcours attendu par l'utilisateur : jouer une partie, la retrouver sur
/// l'accueil, et ouvrir son analyse directement — sans passer par
/// Analyser → Bibliothèque → partie.
final class RecentGamesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAFinishedGameIsAnalysableFromHome() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        // Jouer un coup puis abandonner pour enregistrer la partie.
        app.buttons["Contre Stockfish"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(2))

        XCTAssertTrue(app.buttons["Abandonner"].waitForExistence(timeout: 5))
        app.buttons["Abandonner"].tap()
        // Attendre que le dialogue de confirmation s'ouvre, puis confirmer.
        XCTAssertTrue(app.staticTexts["Abandonner la partie ?"].waitForExistence(timeout: 5))
        let confirm = app.sheets.buttons["Abandonner"].exists
            ? app.sheets.buttons["Abandonner"]
            : app.buttons.matching(identifier: "Abandonner").element(boundBy: 1)
        confirm.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(2))

        // Retour à l'accueil.
        while app.navigationBars.buttons.firstMatch.exists, !app.buttons["Contre Stockfish"].exists {
            app.navigationBars.buttons.firstMatch.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }

        // La partie apparaît dans « Parties récentes » (l'en-tête est en
        // capitales via textCase : on repère la LIGNE de partie, pas le titre).
        let gameRow = app.buttons["Analyser la partie"].firstMatch
        var tries = 0
        while !gameRow.exists, tries < 8 {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            tries += 1
        }
        XCTAssertTrue(gameRow.exists, "la partie jouée doit apparaître dans les parties récentes")

        // Un tap sur la partie ouvre son analyse.
        gameRow.tap()
        XCTAssertTrue(
            app.otherElements["square_e4"].waitForExistence(timeout: 10),
            "taper une partie récente doit ouvrir son analyse"
        )
        // L'analyse s'ouvre sur la partie (position de départ : le pion est
        // encore en e2, la partie se parcourt ensuite coup par coup).
        XCTAssertEqual(app.otherElements["square_e2"].label, "Case e2, pion blanc")
    }
}
