import XCTest

/// L'aide doit être atteignable depuis les Réglages, et décrire les modules.
@MainActor
final class HelpRouteUITests: XCTestCase {

    /// Depuis la 1.4, l'aide a aussi un bouton coloré sur l'accueil — c'est le
    /// chemin que prendra quiconque cherche comment importer ou partager un
    /// répertoire, et personne ne va chercher un mode d'emploi dans les
    /// Réglages.
    @MainActor
    func testHelpIsReachableFromHomeToolbar() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        let help = app.buttons["openHelpFromHome"]
        XCTAssertTrue(help.waitForExistence(timeout: 10), "l'accueil doit porter un bouton d'aide")
        help.tap()

        XCTAssertTrue(
            app.staticTexts["Vos répertoires et le partage"].waitForExistence(timeout: 10),
            "l'aide doit expliquer l'import et le partage des répertoires"
        )
    }

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
            app.staticTexts["Contre l'ordinateur"].waitForExistence(timeout: 5),
            "l'aide doit décrire les modules"
        )
    }
}
