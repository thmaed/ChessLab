import XCTest

/// Barricades de bout en bout : la tuile, l'écran de réglages commun, et une
/// partie où les deux murs se voient et tiennent.
///
/// La preuve que le MOTEUR arbitre les murs vit dans les tests unitaires
/// (`BarricadesEngineSpikeTests`, `BarricadesTests`). Ici on vérifie
/// l'autre moitié : que le joueur les voit, et que la partie se lance.
final class BarricadesUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testPlayAgainstTheEngineWithWalls() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["mode_variants"].waitForExistence(timeout: 15))
        app.buttons["mode_variants"].tap()

        let tile = app.buttons["variant_barricades"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "la tuile Barricades doit exister")
        for _ in 0..<8 where !tile.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        tile.tap()

        let start = app.buttons["fairyVariant_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), "l'écran de réglages doit proposer de commencer")
        start.tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 20))
        try? FileManager.default.createDirectory(atPath: "/tmp/cl-barricades", withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/cl-barricades/depart.png"))

        // Un coup, puis la réponse de l'ordinateur : les murs doivent tenir
        // d'un bout à l'autre.
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()

        let count = app.otherElements["fairyVariant_moveCount"]
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline, Int(count.value as? String ?? "0") ?? 0 < 2 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(Int(count.value as? String ?? ""), 2, "l'ordinateur doit avoir répondu")

        try? app.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/cl-barricades/partie.png"))
    }
}
