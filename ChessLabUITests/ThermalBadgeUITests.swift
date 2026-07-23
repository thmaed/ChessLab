import XCTest

/// Bandeau de surchauffe (Lot 2.C du final-1407).
///
/// L'état thermique est injecté par `-simulateThermalState` : faire chauffer
/// un simulateur pour de vrai n'est pas une option, et sans injection ce
/// bandeau ne serait jamais vu avant qu'un utilisateur ne le rencontre.
final class ThermalBadgeUITests: XCTestCase {

    /// Le bandeau est un élément d'accessibilité COMBINÉ : il apparaît donc
    /// comme un texte, pas dans `otherElements` malgré son identifiant.
    private static let badgeLabel = "Appareil chaud — moteur bridé"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(thermalState: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-simulateThermalState", thermalState]
        app.launch()

        XCTAssertTrue(app.buttons["Contre Stockfish"].waitForExistence(timeout: 5))
        app.buttons["Contre Stockfish"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    func testAHotDeviceIsAnnouncedOnThePlayScreen() throws {
        let app = launch(thermalState: "serious")

        XCTAssertTrue(
            app.staticTexts[Self.badgeLabel].waitForExistence(timeout: 5),
            "la réduction doit être dite, sinon le moteur faiblit sans explication"
        )
    }

    /// `fair` est l'état normal d'un appareil qui calcule : rien ne doit
    /// s'afficher, sans quoi le bandeau serait là en permanence.
    @MainActor
    func testAWarmButHealthyDeviceShowsNothing() throws {
        let app = launch(thermalState: "fair")

        XCTAssertFalse(app.staticTexts[Self.badgeLabel].exists)
    }
}
