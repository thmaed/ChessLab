import XCTest

/// L'interrupteur « Limite de temps » : éteint par défaut, les cadences ne
/// s'affichent qu'une fois allumé.
@MainActor
final class TimeLimitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCadencesAppearOnlyWhenTheLimitIsOn() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()

        app.buttons["Contre l'ordinateur"].tap()
        let toggle = app.switches["timeLimitToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Blitz"].exists, "Limite éteinte : aucune famille de cadence")

        toggle.tap()
        XCTAssertTrue(app.buttons["Blitz"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Bullet"].exists)

        toggle.tap()
        XCTAssertFalse(app.buttons["Blitz"].waitForExistence(timeout: 1))
    }
}
