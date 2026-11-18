import XCTest

/// Le chemin utilisateur du mode « Personnage » : la bande de portraits de l'écran Nouvelle partie (Stockfish tout
/// à gauche, Maia à l'ouverture), la carte de Milo, et son prénom à la place d'« Ordinateur » sur l'écran de jeu.
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

        // La bande de portraits (refonte du 18/11/2026) : Stockfish tout à gauche, Maia choisie à l'ouverture.
        let maiaCard = app.descendants(matching: .any).matching(identifier: "opponentCard_maia").firstMatch
        XCTAssertTrue(maiaCard.waitForExistence(timeout: 5), "Maia est l'adversaire à l'ouverture")
        XCTAssertTrue(maiaCard.label.contains("Maia"))

        NewGameSetupSteps.chooseOpponent("stockfish", app: app)
        let stockfishCard = app.descendants(matching: .any).matching(identifier: "opponentCard_stockfish").firstMatch
        XCTAssertTrue(stockfishCard.waitForExistence(timeout: 3), "toucher Stockfish le choisit")
        let eloShot = XCUIScreen.main.screenshot().pngRepresentation
        let eloPath = NSTemporaryDirectory() + "elo-mode.png"
        try? eloShot.write(to: URL(fileURLWithPath: eloPath))
        print("UIDBG elo screenshot:", eloPath)

        // Un personnage plus loin dans la bande : Milo ; sa carte suit.
        NewGameSetupSteps.chooseOpponent("theo", app: app)
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
