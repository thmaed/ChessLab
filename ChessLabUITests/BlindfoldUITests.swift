import XCTest

/// Partie À L'AVEUGLE de bout en bout (17/11/2026) : la carte « À l'aveugle » de l'accueil ouvre le réglage,
/// section cochée ; on choisit « Tout caché » ; le plateau ne dit plus rien de ses pièces ; « Coup d'œil »
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

    func testABlindGameFromTheHomeCardToTheSummary() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()

        let card = app.buttons["mode_blindfold"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "la carte « À l'aveugle » doit être dans « Plus »")
        var tries = 0
        while !card.isHittable, tries < 6 { app.swipeUp(); tries += 1 }
        snapshot(app, "accueil")
        card.tap()

        // Le réglage s'ouvre sur la section, un niveau déjà choisi.
        let allHidden = app.buttons["blindfold-allHidden"]
        XCTAssertTrue(allHidden.waitForExistence(timeout: 10), "la section « À l'aveugle » doit être là")
        tries = 0
        while !allHidden.isHittable, tries < 6 { app.swipeUp(); tries += 1 }
        // Par la carte : l'interrupteur est déjà allumé, un niveau choisi — le dernier joué, « Cases occupées » la
        // toute première fois.
        XCTAssertEqual(app.switches["blindfoldToggle"].value as? String, "1", "par la carte, l'aveugle est déjà choisi")
        allHidden.tap()
        XCTAssertTrue(allHidden.isSelected)
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
