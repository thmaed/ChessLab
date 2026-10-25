import XCTest

/// C8 : la fin de partie montre la courbe du matériel, sans moteur.
@MainActor
final class GameOverMaterialCurveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// L'offre d'analyse automatique vit sur l'écran de fin de partie (plus d'alerte
    /// au démarrage), tant que le choix n'est pas fait.
    func testResignedGameOffersAutomaticAnalysisOnce() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-autoAnalysisUndecided"]
        app.launch()
        // Aucune alerte au démarrage.
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 5))
        try playTwoMovesAndResign(app)
        let offer = app.otherElements["autoAnalysisOffer"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10), "l'offre d'analyse automatique doit apparaître")
        app.buttons["autoAnalysisOfferNo"].tap()
        XCTAssertFalse(offer.waitForExistence(timeout: 2), "refusée, elle disparaît")
    }

    func testResignedGameShowsMaterialCurve() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()
        try playTwoMovesAndResign(app)
        XCTAssertTrue(app.otherElements["gameOverMaterialCurve"].waitForExistence(timeout: 10))
        // Sans `-autoAnalysisUndecided`, l'analyse est éteinte : pas d'offre.
        XCTAssertFalse(app.otherElements["autoAnalysisOffer"].exists)
    }

    private func playTwoMovesAndResign(_ app: XCUIApplication) throws {

        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()

        let marker = app.otherElements["moveCount"]
        func play(_ from: String, _ to: String, thenCount count: String) {
            XCTAssertTrue(app.otherElements["square_\(from)"].waitForExistence(timeout: 15))
            app.otherElements["square_\(from)"].tap()
            app.otherElements["square_\(to)"].tap()
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, marker.value as? String != count {
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            }
        }
        play("e2", "e4", thenCount: "2")
        play("d2", "d4", thenCount: "4")

        app.buttons["Abandonner"].tap()
        XCTAssertTrue(app.staticTexts["Abandonner la partie ?"].waitForExistence(timeout: 5))
        let confirm = app.sheets.buttons["Abandonner"].exists
            ? app.sheets.buttons["Abandonner"]
            : app.buttons.matching(identifier: "Abandonner").element(boundBy: 1)
        confirm.tap()
    }
}
