import XCTest

/// Le niveau « Cases occupées en gris » (18/11/2026) : on le choisit dans le menu « À l'aveugle », et le plateau
/// ne dit plus que « occupée » — ni le camp, ni la pièce — pour les pièces blanches comme pour les noires.
///
/// - important: PAS de `-resetPlaySettings` : le test doit pouvoir tourner sur un iPhone réel.
@MainActor
final class BlindfoldGreyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func square(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.otherElements["square_\(name)"]
    }

    func testGreyDiscsSayOnlyOccupied() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()

        let play = app.buttons["mode_play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        play.tap()

        NewGameSetupSteps.pick("Cases occupées en gris", inMenu: "blindfoldMenu", app: app)
        snapshot(app, "reglage-gris")

        app.buttons["Commencer"].tap()
        let replace = app.buttons["Remplacer par une nouvelle partie"]
        if replace.waitForExistence(timeout: 2) { replace.tap() }

        XCTAssertTrue(square(app, "e2").waitForExistence(timeout: 20))
        XCTAssertEqual(square(app, "e2").label, "Case e2, occupée", "ni le camp ni la pièce")
        XCTAssertEqual(square(app, "e7").label, "Case e7, occupée", "les noires pareil : rien ne les distingue")
        XCTAssertEqual(square(app, "e4").label, "Case e4", "une case vide reste muette")
        snapshot(app, "partie-gris")

        // On rend la main propre : abandon, pour ne pas laisser de partie en cours aux autres tests.
        app.buttons["Abandonner"].tap()
        let confirm = app.buttons.matching(identifier: "Abandonner").element(boundBy: 1)
        if confirm.waitForExistence(timeout: 3) { confirm.tap() } else { app.alerts.buttons["Abandonner"].firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["blindSummary"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["blindSummary"].label.contains("Cases occupées en gris"))
    }
}
