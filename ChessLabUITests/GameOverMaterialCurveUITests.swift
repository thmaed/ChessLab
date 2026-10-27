import XCTest

/// C8 : la fin de partie montre la courbe du matériel, sans moteur.
@MainActor
final class GameOverMaterialCurveUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testResignedGameShowsMaterialCurve() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()
        try playTwoMovesAndResign(app)
        XCTAssertTrue(app.otherElements["gameOverMaterialCurve"].waitForExistence(timeout: 10))
        attachScreenshot(app, "fin-de-partie")
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

    /// Le panneau de fin de partie, aux grandes tailles de texte : les bandeaux d'aide ne doivent pas
    /// repousser les boutons hors de l'écran (vérifié aussi sur iOS 18).
    func testGameOverPanelStaysUsableAtLargeTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen",
                                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        try playTwoMovesAndResign(app)
        XCTAssertTrue(app.otherElements["gameOverMaterialCurve"].waitForExistence(timeout: 10)
                      || app.buttons["Analyser"].waitForExistence(timeout: 10))
        attachScreenshot(app, "fin-de-partie-AXL")
        let analyze = app.buttons["Analyser"]
        XCTAssertTrue(analyze.exists)
        XCTAssertTrue(analyze.isHittable, "« Analyser » doit rester atteignable sous le bandeau d'aide")
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
