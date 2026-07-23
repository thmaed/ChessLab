import XCTest

/// Raccourcis clavier (Lot 4.A) : le prompt demande ← → pour naviguer sur
/// iPad.
///
/// Passe aussi sur iPhone : `typeKey` s'appuie sur le clavier matériel du
/// simulateur, et les raccourcis sont posés sur les boutons de transport,
/// partagés par les deux dispositions. Un iPhone avec clavier branché en
/// profite donc — ce n'est pas voulu, mais ce n'est pas gênant.
final class KeyboardShortcutsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testArrowKeysDriveTheReviewTransport() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["Contre Stockfish"].waitForExistence(timeout: 5))
        app.buttons["Contre Stockfish"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()

        let e2 = app.otherElements["square_e2"]
        XCTAssertTrue(e2.waitForExistence(timeout: 15))
        e2.tap()
        app.otherElements["square_e4"].tap()

        // ← revient d'un coup : la consultation démarre, et elle le DIT.
        app.typeKey(.leftArrow, modifierFlags: [])

        let reviewing = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Consultation'")
        ).firstMatch
        XCTAssertTrue(
            reviewing.waitForExistence(timeout: 5),
            "← doit reculer d'un coup"
        )
    }
}
