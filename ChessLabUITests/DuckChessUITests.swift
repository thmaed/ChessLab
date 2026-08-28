import XCTest

/// Duck Chess de bout en bout : la tuile, la règle, et un tour complet en
/// deux temps — déplacer, puis poser le canard.
final class DuckChessUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPlayOneFullTurn() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["mode_variants"].waitForExistence(timeout: 15))
        app.buttons["mode_variants"].tap()

        let tile = app.buttons["variant_duck"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "la tuile Duck Chess doit exister")
        for _ in 0..<6 where !tile.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        tile.tap()

        let start = app.buttons["duck_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), "l'écran de règle doit proposer de commencer")
        start.tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 10))
        let phase = app.otherElements["duck_phase"]
        XCTAssertTrue(phase.waitForExistence(timeout: 5))
        XCTAssertEqual(phase.value as? String, "move", "on commence par déplacer une pièce")

        // Premier temps : le coup.
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(phase.value as? String, "duck", "le coup joué, le canard reste à poser")

        // Second temps : le canard.
        app.otherElements["square_e5"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        XCTAssertEqual(phase.value as? String, "move", "le tour est clos, l'autre camp joue")

        try? FileManager.default.createDirectory(atPath: "/tmp/cl-duck", withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/cl-duck/partie.png"))

        let count = app.otherElements["duck_moveCount"]
        XCTAssertEqual(Int(count.value as? String ?? ""), 1, "un demi-coup au journal")
    }
}
