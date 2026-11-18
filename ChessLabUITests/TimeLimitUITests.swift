import XCTest

/// La ligne « Cadence » (refonte du 18/11/2026) : « Sans limite » par défaut ; son menu propose les cadences par
/// famille, et la ligne affiche ensuite la cadence choisie ; « Sans limite » la retire.
@MainActor
final class TimeLimitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheCadenceRowShowsWhatTheMenuPicked() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()

        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["cadenceMenu"].waitForExistence(timeout: 10))
        XCTAssertTrue(NewGameSetupSteps.value(ofMenu: "cadenceMenu", app: app).contains("Sans limite"),
                      "pas de pendule par défaut")

        NewGameSetupSteps.pick("3+2", inMenu: "cadenceMenu", app: app)
        XCTAssertTrue(NewGameSetupSteps.value(ofMenu: "cadenceMenu", app: app).contains("3+2"))

        NewGameSetupSteps.pick("Sans limite", inMenu: "cadenceMenu", app: app)
        XCTAssertTrue(NewGameSetupSteps.value(ofMenu: "cadenceMenu", app: app).contains("Sans limite"))
    }
}
