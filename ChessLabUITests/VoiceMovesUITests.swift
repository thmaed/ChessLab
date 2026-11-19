import XCTest

/// COUPS À LA VOIX (19/11/2026) : la ligne « Coups à la voix » de la carte « Partie », dans Nouvelle partie. Le
/// micro lui-même ne se teste pas ici (pas de voix dans un test) : la logique de partie est couverte par
/// `VoiceMovesGameTests`, la lecture des phrases par `VoiceMoveParserTests` (dont 51 essais réels).
///
/// - important: PAS de `-resetPlaySettings` : le test doit pouvoir tourner sur un iPhone réel.
@MainActor
final class VoiceMovesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheVoiceMovesRowIsInTheGameCard() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()
        let play = app.buttons["mode_play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        play.tap()

        let toggle = app.switches["voiceMoves"]
        var tries = 0
        while !toggle.exists, tries < 6 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "« Coups à la voix » doit être dans la carte « Partie »")
        XCTAssertEqual(toggle.value as? String, "0",
                       "Nouvelle partie s'ouvre TOUJOURS voix éteinte, même allumée la fois d'avant (19/11/2026)")
        // Un appareil sans reconnaissance SUR L'APPAREIL dans la langue (simulateur, par exemple) grise l'interrupteur
        // et le dit ; sinon l'interrupteur est utilisable.
        if !toggle.isEnabled {
            XCTAssertTrue(app.staticTexts["voiceMovesNote"].exists, "un interrupteur grisé doit dire pourquoi")
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "coups-a-la-voix"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
