import XCTest

/// La méthode Woodpecker de bout en bout : créer un programme depuis l'écran
/// de choix, le jouer, le retrouver, l'arrêter.
///
/// - important: PAS de `-resetPlaySettings`, comme ``PuzzleFiltersUITests`` :
///   ce test doit pouvoir tourner sur un iPhone réel.
@MainActor
final class WoodpeckerUITests: XCTestCase {

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Fait défiler l'écran de choix jusqu'à l'élément (la carte est sous les
    /// filtres).
    private func scrollTo(_ target: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !target.isHittable, tries < 8 {
            app.swipeUp()
            tries += 1
        }
    }

    func testCreatePlayResumeAndStopAProgramme() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-openRoute", "puzzles"]
        app.launch()

        let card = element(app, "woodpeckerCard")
        XCTAssertTrue(card.waitForExistence(timeout: 15))

        // Un programme laissé par un essai précédent : on l'arrête d'abord.
        let leftover = element(app, "woodpeckerArchive")
        if leftover.exists {
            scrollTo(leftover, in: app)
            leftover.tap()
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'programme'")).firstMatch.tap()
        }

        let create = element(app, "woodpeckerCreate")
        scrollTo(create, in: app)
        // 25 : le plus petit lot.
        app.segmentedControls.buttons["25"].tap()
        create.tap()

        // L'écran de résolution, en mode programme : chrono et rang dans le lot.
        XCTAssertTrue(element(app, "woodpeckerClock").waitForExistence(timeout: 15), "le chrono du cycle doit s'afficher")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1/25'")).firstMatch.waitForExistence(timeout: 5),
            "le rang dans le lot doit s'afficher"
        )
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "woodpecker-resolution"
        shot.lifetime = .keepAlways
        add(shot)

        // Retour : la carte propose de REPRENDRE ce programme.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let resume = element(app, "woodpeckerResume")
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "le programme en cours doit être proposé")

        // Et on l'arrête : la carte revient à la création.
        let archive = element(app, "woodpeckerArchive")
        scrollTo(archive, in: app)
        archive.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'programme'")).firstMatch.tap()
        XCTAssertTrue(element(app, "woodpeckerCreate").waitForExistence(timeout: 5))
    }
}
