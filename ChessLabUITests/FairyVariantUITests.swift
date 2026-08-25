import XCTest

/// Roi de la colline / Trois échecs / Horde (Fairy-Stockfish, lot A) — le
/// hub affiche les trois tuiles, et une partie se lance et se joue.
final class FairyVariantUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openVariantsHub(_ app: XCUIApplication) {
        app.launch()
        _ = app.buttons["mode_variants"].waitForExistence(timeout: 5)
        app.buttons["mode_variants"].tap()
    }

    /// Les sept tuiles (Chess960 + les trois variantes du lot A + les trois
    /// du lot B, où Fairy-Stockfish arbitre la légalité — voir
    /// ``EngineLegalityVariant``) doivent toutes exister — la vérification
    /// la plus simple qu'aucune ne s'est perdue en route depuis la grille.
    @MainActor
    func testHubShowsAllSevenVariantTiles() throws {
        let app = XCUIApplication()
        openVariantsHub(app)

        for identifier in [
            "variant_chess960", "variant_kingofthehill", "variant_3check", "variant_horde",
            "variant_racingkings", "variant_atomic", "variant_antichess",
        ] {
            XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 5), "\(identifier) doit être présente sur la grille")
        }
    }

    /// Bout en bout : tuile → réglages → partie → un coup joué.
    @MainActor
    func testKingOfTheHillStartsAndAcceptsAMove() throws {
        let app = XCUIApplication()
        openVariantsHub(app)

        _ = app.buttons["variant_kingofthehill"].waitForExistence(timeout: 5)
        app.buttons["variant_kingofthehill"].tap()

        _ = app.buttons["fairyVariant_start"].waitForExistence(timeout: 5)
        app.buttons["fairyVariant_start"].tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 10))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()

        let moveCount = app.otherElements["fairyVariant_moveCount"]
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, Int(moveCount.value as? String ?? "") ?? 0 < 1 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertGreaterThanOrEqual(Int(moveCount.value as? String ?? "") ?? 0, 1, "le coup joué doit tenir")
    }
}
