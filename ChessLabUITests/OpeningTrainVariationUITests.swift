import XCTest

/// « S'entraîner » depuis le lecteur travaille la variante AFFICHÉE (demande
/// d'Olivier, 01/11/2026), pas seulement la ligne principale. Pendant Android :
/// `TrainVariationTest.kt`.
///
/// Parcours de l'utilisateur : ouvrir l'Italienne, choisir un coup dans l'index
/// des lignes, toucher le chapeau, jouer. Les coups du fil sont lus par leur
/// notation SAN (« Nf6 »), indépendante de la langue.
@MainActor
final class OpeningTrainVariationUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-settings.appLanguage", "french"]
        app.launch()
        return app
    }

    private func openItalianReader(_ app: XCUIApplication) {
        let tile = app.buttons["mode_openings"]
        var scrolls = 0
        while !(tile.exists && tile.isHittable) && scrolls < 12 { app.swipeUp(); scrolls += 1 }
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        let entry = app.buttons["opening_italian-game"]
        scrolls = 0
        while !(entry.exists && entry.isHittable) && scrolls < 15 { app.swipeUp(); scrolls += 1 }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.buttons["openingIndex_close"].waitForExistence(timeout: 10))
    }

    /// Choisit un coup de l'index (le lecteur s'y place), ou referme l'index
    /// pour rester à la racine, puis touche le chapeau d'étudiant.
    private func train(_ app: XCUIApplication, fromIndexMove id: String?) {
        if let id {
            let chip = app.buttons[id]
            var scrolls = 0
            while !(chip.exists && chip.isHittable) && scrolls < 20 { app.swipeUp(); scrolls += 1 }
            XCTAssertTrue(chip.waitForExistence(timeout: 10), "coup \(id) introuvable dans l'index")
            chip.tap()
        } else {
            app.buttons["openingIndex_close"].tap()
        }
        let hat = app.buttons["opening_train"]
        XCTAssertTrue(hat.waitForExistence(timeout: 10))
        hat.tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15)
                      || app.buttons["square_e2"].waitForExistence(timeout: 5), "le plateau d'entraînement doit s'afficher")
    }

    private func square(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let other = app.otherElements["square_\(name)"]
        return other.exists ? other : app.buttons["square_\(name)"]
    }

    private func play(_ app: XCUIApplication, _ from: String, _ to: String) {
        square(app, from).tap()
        square(app, to).tap()
    }

    /// Le texte de la pastille `index` du fil, quand elle existe.
    private func trailLabel(_ app: XCUIApplication, _ index: Int, timeout: TimeInterval = 10) -> String? {
        let chip = app.staticTexts["train_move_\(index)"]
        return chip.waitForExistence(timeout: timeout) ? chip.label : nil
    }

    /// Attend que la pastille `index` du fil porte ce libellé (la riposte
    /// adverse arrive après un court délai).
    private func awaitTrail(_ app: XCUIApplication, _ index: Int, _ expected: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        let chip = app.staticTexts["train_move_\(index)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "pastille \(index) absente", file: file, line: line)
        let predicate = NSPredicate(format: "label == %@", expected)
        let result = XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: chip)], timeout: 15)
        XCTAssertEqual(result, .completed, "pastille \(index) : « \(chip.label) » au lieu de « \(expected) »",
                       file: file, line: line)
    }

    /// 1.e4 e5 2.Nf3 Nc6 3.Bc4 : les trois coups des Blancs, les ripostes viennent seules.
    private func playItalianOpening(_ app: XCUIApplication) {
        play(app, "e2", "e4"); awaitTrail(app, 1, "e5")
        play(app, "g1", "f3"); awaitTrail(app, 3, "Nc6")
        play(app, "f1", "c4")
    }

    func testFromTheRootTheOpponentFollowsTheMainLine() {
        let app = launch()
        openItalianReader(app)
        train(app, fromIndexMove: nil)
        playItalianOpening(app)
        awaitTrail(app, 5, "Bc5")                         // la principale
    }

    func testTheOpponentFollowsTheDisplayedVariation() {
        let app = launch()
        openItalianReader(app)
        train(app, fromIndexMove: "openingIndex_move_6_g8f6")   // 3…Nf6, deux cavaliers
        playItalianOpening(app)
        awaitTrail(app, 5, "Nf6")                         // et non Bc5
    }

    func testTheTrainingExpectsTheDisplayedVariationFromThePlayer() {
        let app = launch()
        openItalianReader(app)
        train(app, fromIndexMove: "openingIndex_move_7_b2b4")   // le gambit Evans
        playItalianOpening(app)
        awaitTrail(app, 5, "Bc5")
        play(app, "b2", "b4")                             // le coup de la variante : juste, sans question
        awaitTrail(app, 7, "Bxb4")
        XCTAssertFalse(app.staticTexts["train_variationMessage"].exists)
    }

    func testPlayingTheMainLineDuringAVariationOffersToStay() {
        let app = launch()
        openItalianReader(app)
        train(app, fromIndexMove: "openingIndex_move_7_b2b4")
        playItalianOpening(app)
        awaitTrail(app, 5, "Bc5")
        play(app, "c2", "c3")                             // la principale, alors qu'on travaille Evans

        let message = app.staticTexts["train_variationMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertTrue(message.label.contains("autre variante"), "message : \(message.label)")
        XCTAssertTrue(app.buttons["train_keepMain"].label.contains("ma ligne"))
        app.buttons["train_keepMain"].tap()
        awaitTrail(app, 6, "4. b4")                      // le coup travaillé, pas c3
    }

    func testWithoutAVariationTheUsualMessageStays() {
        let app = launch()
        openItalianReader(app)
        train(app, fromIndexMove: nil)
        playItalianOpening(app)
        awaitTrail(app, 5, "Bc5")
        play(app, "b2", "b4")                             // Evans, mais on n'a rien demandé de tel

        let message = app.staticTexts["train_variationMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 10))
        XCTAssertTrue(message.label.contains("ligne principale"), "message : \(message.label)")
        XCTAssertTrue(app.buttons["train_keepMain"].label.contains("principale"))
    }
}
