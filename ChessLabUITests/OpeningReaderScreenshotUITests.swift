import XCTest

/// Capture d'écrans du flux d'ouvertures EN ANGLAIS, pour vérifier la
/// localisation (aucune chaîne française résiduelle) : liste, lecteur au
/// départ, et fin de ligne (« End of the line »).
final class OpeningReaderScreenshotUITests: XCTestCase {

    func testOpeningReaderInEnglish() {
        let app = XCUIApplication()
        app.launchArguments += ["-settings.appLanguage", "english"]
        app.launch()

        // Accueil → Ouvertures (identifiant, indépendant de la langue)
        let openings = app.buttons["mode_openings"]
        XCTAssertTrue(openings.waitForExistence(timeout: 10))
        openings.tap()
        capture(app, "01-list-en")

        // Ouvre la Partie italienne. La liste est triée alphabétiquement, donc
        // l'entrée peut être sous la ligne de flottaison : on défile jusqu'à elle.
        //
        // On défile AVANT d'exiger son existence : la liste est paresseuse, et
        // sur un écran court (iPhone 11 et plus petits) la cellule n'est même
        // pas construite au départ — `waitForExistence` échouait donc avant
        // que la moindre boucle de défilement n'ait eu lieu.
        let italian = app.buttons["opening_italian-game"]
        var scrolls = 0
        while !(italian.exists && italian.isHittable) && scrolls < 12 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(italian.waitForExistence(timeout: 10))
        italian.tap()
        capture(app, "02-reader-start-en")

        // Avance jusqu'à la fin de la ligne principale
        let next = app.buttons["reader_next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        var guardCount = 0
        while next.isEnabled && guardCount < 40 {
            next.tap()
            guardCount += 1
        }
        capture(app, "03-reader-end-en")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
