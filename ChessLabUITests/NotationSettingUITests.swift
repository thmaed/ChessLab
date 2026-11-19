import XCTest

/// La notation des coups (Réglages) : « Automatique » par défaut — elle suit la langue de l'app —, puis le choix
/// de l'utilisateur, MÉMORISÉ d'un lancement à l'autre ; et « Automatique » se retrouve de même.
///
/// Le premier lancement repart d'une préférence EFFACÉE (`-settings.pieceNotation ""`, domaine des arguments) : sur
/// un simulateur déjà servi, il lisait le dernier choix laissé par un autre test et échouait (19/11/2026). Le lancement
/// suivant, sans l'argument, lit bien ce que l'app a enregistré.
@MainActor
final class NotationSettingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchAndOpenNotation(fresh: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        if fresh { app.launchArguments += ["-settings.pieceNotation", ""] }
        app.launch()
        let settings = app.buttons["openSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.tap()
        let auto = app.buttons["notation_auto"]
        XCTAssertTrue(auto.waitForExistence(timeout: 10))
        var swipes = 0
        while !auto.isHittable, swipes < 8 { app.swipeUp(velocity: .slow); swipes += 1 }
        return app
    }

    func testTheNotationIsAutomaticByDefault_thenRemembered() throws {
        // 1. Installation neuve : « Automatique ».
        var app = launchAndOpenNotation(fresh: true)
        XCTAssertTrue(app.buttons["notation_auto"].isSelected, "« Automatique » doit être le choix par défaut")
        XCTAssertFalse(app.buttons["notation_english"].isSelected)

        // 2. Un choix explicite…
        app.buttons["notation_english"].tap()
        XCTAssertTrue(app.buttons["notation_english"].isSelected)
        app.terminate()

        // …retrouvé au lancement suivant.
        app = launchAndOpenNotation()
        XCTAssertTrue(app.buttons["notation_english"].isSelected, "le choix doit être mémorisé")
        XCTAssertFalse(app.buttons["notation_auto"].isSelected)

        // 3. Retour à « Automatique », mémorisé lui aussi.
        app.buttons["notation_auto"].tap()
        app.terminate()
        app = launchAndOpenNotation()
        XCTAssertTrue(app.buttons["notation_auto"].isSelected, "« Automatique » doit être mémorisé aussi")
        XCTAssertFalse(app.buttons["notation_english"].isSelected)
    }
}
