import XCTest

/// Le chemin utilisateur du mode « Personnage » : la bascule sur l'écran
/// Nouvelle partie, la carte de Camille, et son prénom à la place
/// d'« Ordinateur » sur l'écran de jeu.
@MainActor
final class MaiaOpponentUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCharacterModeShowsMaiaAndStartsAGame() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        // Installation vierge à chaque run : la visite guidée démarre une
        // seconde après l'accueil et son voile avale les taps. On la passe.
        if app.buttons["Passer"].waitForExistence(timeout: 3) {
            app.buttons["Passer"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        }

        // Le mode Stockfish (à droite, plus le défaut) : capture pour relecture.
        let stockfish = app.segmentedControls.buttons["Stockfish"].exists ? app.segmentedControls.buttons["Stockfish"] : app.buttons["Stockfish"]
        XCTAssertTrue(stockfish.waitForExistence(timeout: 5), "la bascule « Stockfish » doit exister")
        var stockfishScrolls = 0
        while !stockfish.isHittable, stockfishScrolls < 6 { app.swipeDown(); RunLoop.current.run(until: Date().addingTimeInterval(0.3)); stockfishScrolls += 1 }
        stockfish.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let eloShot = XCUIScreen.main.screenshot().pngRepresentation
        let eloPath = NSTemporaryDirectory() + "elo-mode.png"
        try? eloShot.write(to: URL(fileURLWithPath: eloPath))
        print("UIDBG elo screenshot:", eloPath)

        // La bascule Niveau Elo / Personnage : un contrôle segmenté.
        let segment = app.segmentedControls.buttons["Personnage"].exists
            ? app.segmentedControls.buttons["Personnage"]
            : app.buttons["Personnage"]
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "la bascule « Personnage » doit exister")
        // L'écran peut être défilé (visite guidée, mémoire de position) : on
        // ramène la bascule à l'écran avant de la toucher, sinon le tap tombe
        // hors de la fenêtre et « Niveau Elo » reste sélectionné.
        var scrolls = 0
        while !segment.isHittable, scrolls < 6 {
            app.swipeDown()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            scrolls += 1
        }
        segment.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let card = app.descendants(matching: .any).matching(identifier: "opponentCard_maia").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3), "la carte de Maia doit apparaître")
        XCTAssertTrue(card.label.contains("Maia"))
        // La galerie : choisir Milo, la carte suit.
        let theo = app.descendants(matching: .any).matching(identifier: "opponentTile_theo").firstMatch
        XCTAssertTrue(theo.waitForExistence(timeout: 3), "la vignette de Milo doit exister")
        var tries = 0
        while !theo.isHittable, tries < 4 { app.swipeUp(); RunLoop.current.run(until: Date().addingTimeInterval(0.3)); tries += 1 }
        theo.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        let theoCard = app.descendants(matching: .any).matching(identifier: "opponentCard_theo").firstMatch
        XCTAssertTrue(theoCard.waitForExistence(timeout: 3), "la carte de Milo doit apparaître")
        let shot = XCUIScreen.main.screenshot().pngRepresentation
        let path = NSTemporaryDirectory() + "maia-gallery.png"
        try? shot.write(to: URL(fileURLWithPath: path))
        print("UIDBG gallery screenshot:", path)
        // La suite du parcours se joue contre Milo : son prénom doit
        // remplacer « Ordinateur » sur l'écran de jeu.

        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Milo"].waitForExistence(timeout: 5), "le prénom remplace « Ordinateur »")
        XCTAssertFalse(app.staticTexts["Ordinateur"].exists)

        // Un coup du joueur : l'écran reste vivant pendant que Camille répond.
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(6))
        XCTAssertTrue(app.staticTexts["Milo"].exists)
        XCTAssertTrue(app.buttons["Abandonner"].exists)
    }
}
