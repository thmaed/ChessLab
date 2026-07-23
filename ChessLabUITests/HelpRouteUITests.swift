import XCTest

/// L'aide doit être atteignable depuis les Réglages, et décrire les modules.
final class HelpRouteUITests: XCTestCase {

    @MainActor
    func testHelpIsReachableFromSettings() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["openSettings"].waitForExistence(timeout: 5))
        app.buttons["openSettings"].tap()

        // L'entrée est en bas des Réglages.
        let help = app.buttons["openHelp"]
        while !help.isHittable {
            app.swipeUp()
            if !app.staticTexts["Comment ça marche"].exists && !help.exists { break }
        }
        XCTAssertTrue(help.waitForExistence(timeout: 3))
        help.tap()

        // Une carte de module apparaît.
        XCTAssertTrue(
            app.staticTexts["Contre Stockfish"].waitForExistence(timeout: 5),
            "l'aide doit décrire les modules"
        )
    }
}
