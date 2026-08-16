import XCTest

/// La promotion dans *Analyser*, sur TOUTES les classes de taille.
///
/// `LayoutOverflowUITests.testPromotionPickerFitsOnScreen` mesure la largeur du
/// sélecteur et se borne donc à la classe compacte. Ce test-ci ne mesure rien :
/// il vérifie que le sélecteur **s'ouvre**, ce qui est une question
/// fonctionnelle et vaut sur iPad autant que sur iPhone.
///
/// Il existe parce que ce chemin était rouge sur iPad **mini** et vert sur les
/// deux iPad Pro (relevé du 14/08, consigné en « question ouverte » dans
/// `PROGRESS.md`), sans qu'on sache s'il s'agissait d'un vrai défaut ou d'un
/// artefact de test.
final class PromotionUITests: XCTestCase {

    /// Pion blanc en a7, deux rois : la promotion est le seul coup intéressant,
    /// et elle est légale immédiatement.
    private let promotionFEN = "8/P6k/8/8/8/8/7K/8 w - - 0 1"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPromotionPickerOpensInAnalysis() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()
        try openAnalysis(in: app, fen: promotionFEN)

        let from = app.otherElements["square_a7"]
        let to = app.otherElements["square_a8"]
        XCTAssertTrue(from.waitForExistence(timeout: 10), "la case a7 doit exister")
        XCTAssertTrue(to.waitForExistence(timeout: 10), "la case a8 doit exister")
        report(app, from: from, to: to)

        from.tap()
        to.tap()

        let queen = app.buttons["Dame"]
        if !queen.waitForExistence(timeout: 20) {
            // Le sélecteur ne s'est pas ouvert : tracer ce que le plateau
            // montre AVANT d'échouer, pour que le rouge porte un diagnostic.
            report(app, from: from, to: to, prefix: "PROMO-ECHEC")
        }
        XCTAssertTrue(queen.exists, "taper a7 puis a8 doit ouvrir le sélecteur de promotion")
    }

    // MARK: Outils

    @MainActor
    private func report(
        _ app: XCUIApplication, from: XCUIElement, to: XCUIElement, prefix: String = "PROMO-ETAT"
    ) {
        for (name, element) in [("a7", from), ("a8", to)] {
            print(String(
                format: "%@|%@|existe=%@|atteignable=%@|cadre=[%.1f,%.1f %.1fx%.1f]",
                prefix, name,
                element.exists ? "oui" : "non",
                element.isHittable ? "oui" : "non",
                element.frame.minX, element.frame.minY,
                element.frame.width, element.frame.height
            ))
        }
        print("\(prefix)|fenêtre=\(app.frame)")
    }

    @MainActor
    private func openAnalysis(in app: XCUIApplication, fen: String) throws {
        let entry = app.buttons["Analyser"]
        if entry.waitForExistence(timeout: 10) {
            entry.tap()
        } else if app.cells["Analyser"].waitForExistence(timeout: 3) {
            app.cells["Analyser"].tap()
        } else {
            app.staticTexts["Analyser"].tap()
        }
        XCTAssertTrue(app.buttons["Autres sources"].waitForExistence(timeout: 10))
        app.buttons["Autres sources"].tap()
        XCTAssertTrue(app.buttons["Analyser PGN / FEN"].waitForExistence(timeout: 10))
        app.buttons["Analyser PGN / FEN"].tap()

        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(fen)
        app.buttons["Lancer l'analyse"].tap()
        XCTAssertTrue(
            app.otherElements["square_a7"].waitForExistence(timeout: 25),
            "le plateau doit s'afficher"
        )
    }
}
