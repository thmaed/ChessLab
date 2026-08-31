import XCTest

/// Captures de revue pour Crazyhouse — outil, pas test de non-régression.
/// Dépose dans `/tmp/cl-crazyhouse/`.
@MainActor
final class CrazyhouseTourUITests: XCTestCase {

    @MainActor
    func testCaptureCrazyhouse() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["mode_variants"].waitForExistence(timeout: 15))
        app.buttons["mode_variants"].tap()
        settle(1.0)
        app.swipeUp()
        settle(0.6)
        save(app, "01-hub")

        let tile = app.buttons["variant_crazyhouse"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "la tuile Crazyhouse doit exister")
        for _ in 0..<4 where !tile.isHittable { app.swipeUp(); settle(0.4) }
        tile.tap()
        settle(1.2)
        save(app, "02-reglages")

        let start = app.buttons["fairyVariant_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15))
        settle(1.5)
        save(app, "03-partie")

        // On pousse les pions centraux jusqu'à ce qu'une capture survienne :
        // c'est elle qui remplit la réserve, et donc fait apparaître la bande.
        // Les réponses de l'ordinateur n'étant pas prévisibles, on joue
        // plusieurs coups et on s'arrête dès qu'une réserve existe.
        // d4-d5 en fin de liste : au contact des pions noirs de c6/e6, il
        // provoque presque à coup sûr une prise, donc une réserve.
        let pushes = [("e2", "e4"), ("d2", "d4"), ("g1", "f3"), ("b1", "c3"),
                      ("f1", "c4"), ("d4", "d5"), ("e4", "e5"), ("c4", "f7")]
        for (from, to) in pushes {
            tapSquare(app, from); tapSquare(app, to)
            settle(3.5)
            if app.otherElements["pocket_user"].exists || app.otherElements["pocket_engine"].exists {
                break
            }
        }
        settle(1.0)
        save(app, "04-reserve")
        print("CZ|reserve joueur visible|\(app.otherElements["pocket_user"].exists)")
        print("CZ|reserve adverse visible|\(app.otherElements["pocket_engine"].exists)")
    }

    @MainActor private func settle(_ s: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(s))
    }
    @MainActor private func tapSquare(_ app: XCUIApplication, _ name: String) {
        let sq = app.otherElements["square_\(name)"]
        if sq.waitForExistence(timeout: 5) { sq.tap() }
    }
    @MainActor private func save(_ app: XCUIApplication, _ name: String) {
        let dir = "/tmp/cl-crazyhouse"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        print("CZ|\(name)|ok")
    }
}
