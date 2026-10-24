import XCTest

/// A5 / C7 : la « Séance du jour » en tête de l'accueil ouvre l'écran des
/// étapes, qui propose toujours la finale du jour.
@MainActor
final class DailySessionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTheHomeCardOpensTheDailySession() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()

        let card = app.buttons["dailySessionCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "la carte « Séance du jour » doit être en tête de l'accueil")
        card.tap()

        XCTAssertTrue(app.otherElements["dailySessionScreen"].waitForExistence(timeout: 10)
            || app.staticTexts["Séance du jour"].waitForExistence(timeout: 5),
            "l'écran de la séance doit s'ouvrir")
        XCTAssertTrue(
            app.buttons["dailyStep_endgame"].waitForExistence(timeout: 10),
            "la finale du jour est toujours proposée")
        XCTAssertTrue(app.buttons["dailyStep_openings"].exists)
    }
}
