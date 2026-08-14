import XCTest

/// Raccourcis clavier (Lot 4.A) : le prompt demande ← → pour naviguer sur
/// iPad.
///
/// Passe aussi sur iPhone : `typeKey` s'appuie sur le clavier matériel du
/// simulateur, et les raccourcis sont posés sur les boutons de transport,
/// partagés par les deux dispositions. Un iPhone avec clavier branché en
/// profite donc — ce n'est pas voulu, mais ce n'est pas gênant.
///
/// ## Pourquoi ce test avait cessé de passer
///
/// Il attendait un `StaticText` commençant par « Consultation ». Ce bandeau a
/// été **retiré de l'écran Jouer** par la refonte « contrôles simplifiés — une
/// seule rangée » : c'est désormais le bouton « Reprendre ici » qui signale
/// qu'on n'est plus sur la position vive (il n'existe qu'en consultation), et
/// le libellé « Consultation — coup X/Y » ne subsiste que dans *Deux joueurs*.
/// Le test n'avait pas suivi — défaut du test, pas de l'app.
///
/// Il assère maintenant le **comportement** plutôt que le chrome : après deux
/// ←, le plateau doit être revenu à la position de départ. Une refonte
/// d'habillage ne le cassera plus ; une flèche qui cesse de naviguer, si.
final class KeyboardShortcutsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testArrowKeysDriveTheReviewTransport() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        XCTAssertTrue(app.buttons["Contre l'ordinateur"].waitForExistence(timeout: 10))
        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 10))
        app.buttons["Commencer"].tap()

        let e2 = app.otherElements["square_e2"]
        XCTAssertTrue(e2.waitForExistence(timeout: 20))
        e2.tap()
        app.otherElements["square_e4"].tap()

        // Attendre que le coup soit RÉELLEMENT posé avant de reculer : sans
        // ça, on mesurerait une course entre le tap et la flèche.
        let e4 = app.otherElements["square_e4"]
        XCTAssertTrue(
            waitForLabel(e4, "Case e4, pion blanc", timeout: 10),
            "le pion doit d'abord être en e4 (lu : \(e4.label))"
        )

        // ← recule d'un demi-coup. Deux pressions suffisent à revenir au
        // départ, que le moteur ait déjà répondu ou non — reculer au-delà du
        // coup 0 est sans effet.
        app.typeKey(.leftArrow, modifierFlags: [])
        app.typeKey(.leftArrow, modifierFlags: [])

        XCTAssertTrue(
            waitForLabel(e4, "Case e4, vide", timeout: 10),
            "← doit reculer : e4 doit être vide (lu : \(e4.label))"
        )
        XCTAssertEqual(
            e2.label, "Case e2, pion blanc",
            "le pion doit être revenu à sa case de départ"
        )

        // → ramène en avant : le transport marche dans les deux sens.
        app.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue(
            waitForLabel(e4, "Case e4, pion blanc", timeout: 10),
            "→ doit avancer d'un coup (lu : \(e4.label))"
        )
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ expected: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.label == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return element.label == expected
    }
}
