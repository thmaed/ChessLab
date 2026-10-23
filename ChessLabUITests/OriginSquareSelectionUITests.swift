import XCTest

/// La pièce posée sur la case d'ORIGINE du plateau — le coin haut-gauche, h1
/// quand on joue les Noirs — doit se sélectionner comme les autres.
///
/// Signalé le 22/10/2026 par un joueur, partie aux Noirs contre Maia : « ma
/// dame en h1 est soudainement impossible à sélectionner », même après
/// relance. Les pièces étaient placées par `.offset` : dessinées sur leur case
/// mais MISES EN PAGE à l'origine du plateau, où leurs cadres s'empilaient.
/// Voir ``ChessBoardView/piecesLayer(squareSize:)``.
///
/// ⚠️ Le défaut tient à iOS 18 : sur nos simulateurs iOS 26, ce test passe
/// même SANS le correctif. Il ne prouve quelque chose que sur un appareil
/// iOS 18 — l'iPhone XS (18.7.9) : rouge avant correction (le tap sur h1 est
/// avalé, rien ne se sélectionne), vert après, le 23/10/2026.
///
///     xcodebuild test -scheme ChessLab -destination 'platform=iOS,id=<UDID du XS>' \
///       -only-testing:ChessLabUITests/OriginSquareSelectionUITests
@MainActor
final class OriginSquareSelectionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBlackQueenOnH1MovesByTapTap() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-openRoute", "blackQueenOnOrigin"]
        app.launch()

        let h1 = app.otherElements["square_h1"]
        XCTAssertTrue(h1.waitForExistence(timeout: 25), "la partie reprise doit s'afficher")
        XCTAssertTrue(h1.label.contains("dame"), "la dame noire doit être en h1 — \(h1.label)")

        // Plateau retourné : h1 est bien le coin haut-gauche, celui où
        // s'empilaient les cadres. Sinon le test ne vise plus le bon défaut.
        let a8 = app.otherElements["square_a8"]
        XCTAssertGreaterThan(a8.frame.minX, h1.frame.minX)
        XCTAssertGreaterThan(a8.frame.minY, h1.frame.minY)

        // h4 : libre, et qu'aucune pièce blanche n'attaque — la réponse de
        // Maia ne peut donc pas effacer la preuve.
        h1.tap()
        app.otherElements["square_h4"].tap()

        let h4 = app.otherElements["square_h4"]
        let moved = NSPredicate(format: "label CONTAINS 'dame'")
        expectation(for: moved, evaluatedWith: h4)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(h1.label, "Case h1, vide")
    }
}
