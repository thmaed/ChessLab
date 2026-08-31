import XCTest

/// Course des rois / Antéchecs / Atomique (Fairy-Stockfish arbitre, lot B)
/// — bout en bout : tuile → réglages → partie → un coup joué. Les tuiles
/// elles-mêmes sont couvertes par ``FairyVariantUITests/
/// testHubShowsAllSevenVariantTiles()``, qui liste les deux lots ensemble.
@MainActor
final class EngineLegalityUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAtomicStartsAndAcceptsAMove() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.buttons["mode_variants"].waitForExistence(timeout: 5)
        app.buttons["mode_variants"].tap()

        _ = app.buttons["variant_atomic"].waitForExistence(timeout: 5)
        app.buttons["variant_atomic"].tap()

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
