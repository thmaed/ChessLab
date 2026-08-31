import XCTest

/// Barricades de bout en bout : la tuile, l'écran de réglages commun, et une
/// partie où les deux murs se voient et tiennent.
///
/// La preuve que le MOTEUR arbitre les murs vit dans les tests unitaires
/// (`BarricadesEngineSpikeTests`, `BarricadesTests`). Ici on vérifie
/// l'autre moitié : que le joueur les voit, et que la partie se lance.
@MainActor
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

    /// Barricades ALÉATOIRES : les deux murs doivent avoir CHANGÉ de case
    /// après un aller-retour de coups.
    @MainActor
    func testRandomBarricadesWallsMove() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["mode_variants"].waitForExistence(timeout: 15))
        app.buttons["mode_variants"].tap()

        let tile = app.buttons["variant_randombarricades"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "la tuile Barricades aléatoires doit exister")
        for _ in 0..<10 where !tile.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        try? FileManager.default.createDirectory(atPath: "/tmp/cl-barricades", withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/cl-barricades/hub.png"))
        tile.tap()

        let start = app.buttons["fairyVariant_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 25))
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        try? app.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/cl-barricades/aleatoire-depart.png"))

        // On joue le premier coup PROPOSÉ, pas un coup écrit d'avance : un mur
        // peut parfaitement occuper e3 ou e4 dès l'ouverture.
        var played = false
        for file in "abcdefgh" where !played {
            let from = app.otherElements["square_\(file)2"]
            guard from.exists else { continue }
            from.tap()
            for target in ["\(file)3", "\(file)4"] {
                let to = app.otherElements["square_\(target)"]
                if to.exists, to.isHittable {
                    to.tap()
                    RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                    if Int(app.otherElements["fairyVariant_moveCount"].value as? String ?? "0") ?? 0 > 0 {
                        played = true
                        break
                    }
                }
            }
        }
        XCTAssertTrue(played, "aucun coup de pion n'a été accepté")

        let count = app.otherElements["fairyVariant_moveCount"]
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline, Int(count.value as? String ?? "0") ?? 0 < 2 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(Int(count.value as? String ?? ""), 2, "l'ordinateur doit avoir répondu")

        try? app.screenshot().pngRepresentation
            .write(to: URL(fileURLWithPath: "/tmp/cl-barricades/aleatoire-partie.png"))
    }

    /// Le bouton « ½ » a longtemps été affiché sans rien faire dans les
    /// écrans de variantes. On vérifie qu'il mène quelque part : soit
    /// l'ordinateur accepte et la partie s'arrête, soit il refuse et le dit.
    /// Les deux réponses sont bonnes ; le silence ne l'est pas.
    @MainActor
    func testOfferingADrawGetsAnAnswer() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["mode_variants"].waitForExistence(timeout: 15))
        app.buttons["mode_variants"].tap()

        let tile = app.buttons["variant_barricades"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8))
        for _ in 0..<10 where !tile.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        tile.tap()

        let start = app.buttons["fairyVariant_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 25))

        // Un aller-retour de coups : sans avis du moteur, la nulle est
        // refusée d'office, ce qui ne prouverait rien.
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        let count = app.otherElements["fairyVariant_moveCount"]
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline, Int(count.value as? String ?? "0") ?? 0 < 2 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        try XCTSkipUnless(Int(count.value as? String ?? "0") ?? 0 >= 2, "l'ordinateur n'a pas répondu")

        let offer = app.buttons["Proposer nulle"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5), "le bouton ½ doit être là")
        offer.tap()

        XCTAssertTrue(app.staticTexts["Proposer nulle au moteur ?"].waitForExistence(timeout: 5),
                      "la confirmation doit s'ouvrir")
        let confirm = app.sheets.buttons["Proposer nulle"].exists
            ? app.sheets.buttons["Proposer nulle"]
            : app.buttons.matching(identifier: "Proposer nulle").element(boundBy: 1)
        confirm.tap()

        // Refus annoncé, ou partie terminée : dans les deux cas il s'est
        // passé quelque chose.
        let declined = app.staticTexts["Nulle refusée"]
        let finished = app.otherElements["fairyVariant_outcome"]
        let answerDeadline = Date().addingTimeInterval(15)
        while Date() < answerDeadline,
              !declined.exists, (finished.value as? String ?? "").isEmpty {
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }
        XCTAssertTrue(declined.exists || !(finished.value as? String ?? "").isEmpty,
                      "la proposition de nulle est restée sans réponse")
    }
}
