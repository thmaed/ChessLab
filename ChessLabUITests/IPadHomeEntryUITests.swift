import XCTest

/// iPad (barre latérale) : choisir un mode remplaçait l'accueil — séance du jour, progression, parties récentes —
/// sans plus aucun chemin pour y revenir (retour du 16/11/2026, sur un iPad Pro 11"). L'entrée « Accueil », en
/// tête de la barre, le rend.
@MainActor
final class IPadHomeEntryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testTheSidebarLeadsBackToTheHomeDashboard() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("barre latérale : iPad seulement") }
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()

        let dashboardTile = app.buttons["mode_play"]
        XCTAssertTrue(dashboardTile.waitForExistence(timeout: 20), "l'accueil s'ouvre sur le tableau de bord")
        let home = app.staticTexts["sidebar_home"]
        XCTAssertTrue(home.waitForExistence(timeout: 10), "l'entrée « Accueil » doit être dans la barre latérale")

        // Un mode choisi dans la barre remplace le tableau de bord…
        let openings = app.staticTexts["sidebar_openings"]
        XCTAssertTrue(openings.waitForExistence(timeout: 5))
        openings.tap()
        XCTAssertTrue(dashboardTile.waitForNonExistence(timeout: 5), "le mode remplace l'accueil")

        // …et « Accueil » le rend.
        home.tap()
        XCTAssertTrue(dashboardTile.waitForExistence(timeout: 5), "« Accueil » doit ramener au tableau de bord")
    }
}
