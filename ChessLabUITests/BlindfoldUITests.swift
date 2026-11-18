import XCTest

/// Partie À L'AVEUGLE de bout en bout (17/11/2026) : dans le réglage « Contre l'ordinateur », on choisit « Tout
/// caché » dans le menu « À l'aveugle » ; le plateau ne dit plus rien de ses pièces ; « Coup d'œil »
/// se compte ; on joue en touchant départ puis arrivée ; un coup impossible le dit ; l'abandon fait
/// réapparaître les pièces et le bilan dit comment la partie a été jouée.
///
/// - important: PAS de `-resetPlaySettings` : le test doit pouvoir tourner sur un iPhone réel.
@MainActor
final class BlindfoldUITests: XCTestCase {

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

    func testABlindGameFromTheSetupToTheSummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()

        // UNE seule porte (décision du 17/11/2026) : « Contre l'ordinateur », section juste sous l'adversaire.
        let play = app.buttons["mode_play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        snapshot(app, "accueil")
        play.tap()

        // La ligne « À l'aveugle » de la carte « Partie » (refonte du 18/11/2026) : « Non » à l'ouverture, un menu.
        XCTAssertTrue(app.buttons["blindfoldMenu"].waitForExistence(timeout: 10),
                      "la ligne « À l'aveugle » doit être dans le réglage")
        XCTAssertTrue(NewGameSetupSteps.value(ofMenu: "blindfoldMenu", app: app).contains("Non"),
                      "« Nouvelle partie » ne s'ouvre jamais à l'aveugle")
        XCTAssertFalse(app.switches["blindfoldVoice"].exists, "la voix n'apparaît qu'à l'aveugle")
        NewGameSetupSteps.pick("Tout caché", inMenu: "blindfoldMenu", app: app)
        XCTAssertTrue(NewGameSetupSteps.value(ofMenu: "blindfoldMenu", app: app).contains("Tout caché"))
        XCTAssertTrue(app.switches["blindfoldVoice"].waitForExistence(timeout: 3), "la voix, à l'aveugle")
        snapshot(app, "reglage")

        app.buttons["Commencer"].tap()
        let replace = app.buttons["Remplacer par une nouvelle partie"]
        if replace.waitForExistence(timeout: 2) { replace.tap() }

        // Le plateau ne dit rien : « Case e2 », pas « pion blanc ».
        XCTAssertTrue(square(app, "e2").waitForExistence(timeout: 20))
        XCTAssertEqual(square(app, "e2").label, "Case e2", "à l'aveugle, une case ne nomme pas sa pièce")
        XCTAssertTrue(app.otherElements["blindPeek"].exists || app.buttons["blindPeek"].exists)
        snapshot(app, "partie")

        // Un coup impossible le dit, sans être joué.
        square(app, "e2").tap()
        square(app, "e5").tap()
        XCTAssertTrue(app.staticTexts["blindNotice"].waitForExistence(timeout: 3), "« Coup impossible »")

        // Un coup juste : départ, puis arrivée.
        square(app, "g1").tap()
        square(app, "f3").tap()
        let lastMove = app.staticTexts["blindLastMove"]
        let answered = NSPredicate(format: "label CONTAINS ' : '")
        expectation(for: answered, evaluatedWith: lastMove)
        waitForExpectations(timeout: 30)
        snapshot(app, "coup-adverse")

        // Coup d'œil : on maintient, le compteur passe à 1.
        let peek = app.descendants(matching: .any)["blindPeek"].firstMatch
        peek.press(forDuration: 1.2)
        XCTAssertEqual(peek.value as? String, "1")

        // Abandon : les pièces reviennent, le bilan dit comment on a joué.
        app.buttons["Abandonner"].tap()
        let confirm = app.buttons.matching(identifier: "Abandonner").element(boundBy: 1)
        if confirm.waitForExistence(timeout: 3) { confirm.tap() } else { app.alerts.buttons["Abandonner"].firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["blindSummary"].waitForExistence(timeout: 10), "le bilan dit « À l'aveugle »")
        XCTAssertTrue(app.staticTexts["blindSummary"].label.contains("Tout caché"))
        XCTAssertTrue(square(app, "e2").label.contains("pion"), "la partie finie, les pièces réapparaissent")
        snapshot(app, "bilan")
    }
}
