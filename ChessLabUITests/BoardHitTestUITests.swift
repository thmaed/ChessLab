import XCTest

/// Le plateau RÉPOND-IL au doigt ? — aux tailles de texte réelles, pas
/// seulement à celle par défaut.
///
/// Origine : sur un iPhone 11 physique, aucune pièce ne répondait, ni au tap ni
/// au glisser, et sur TOUS les écrans. Un plateau inerte en bloc n'est pas un
/// problème de geste : en SwiftUI, une vue dessinée HORS des limites de son
/// parent s'affiche normalement (rien n'est rogné par défaut) mais ne reçoit
/// aucun toucher. Il suffit que le contenu au-dessus du plateau grandisse — ce
/// que fait Dynamic Type — pour le pousser dehors sans que rien ne se voie.
///
/// Toute la suite tournait jusqu'ici à la taille par défaut, sur des
/// simulateurs iOS 26 ; l'appareil de l'utilisateur est en iOS 18 avec SA
/// taille de texte. D'où ce test, qui vérifie la seule chose qui compte
/// vraiment : `isHittable`.
@MainActor
final class BoardHitTestUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func launchApp(contentSize: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    /// Ouvre une partie contre le moteur — même chemin que
    /// ``LayoutOverflowUITests``, robuste au bouton/cellule/texte selon iPhone
    /// ou iPad.
    @MainActor
    private func openVsEngineGame(in app: XCUIApplication) throws {
        for candidate in [
            app.buttons["Contre l'ordinateur"],
            app.cells["Contre l'ordinateur"],
            app.staticTexts["Contre l'ordinateur"],
        ] {
            guard candidate.waitForExistence(timeout: 6) else { continue }
            for _ in 0..<4 {
                if candidate.isHittable { candidate.tap(); break }
                app.swipeUp()
            }
            break
        }
        let start = app.buttons["Commencer"]
        guard start.waitForExistence(timeout: 10) else {
            XCTFail("le bouton « Commencer » doit apparaître")
            return
        }
        for _ in 0..<4 where !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(
            app.otherElements["square_a8"].waitForExistence(timeout: 25),
            "le plateau doit s'afficher"
        )
    }

    /// LE test : une case du plateau doit être ATTEIGNABLE au doigt.
    ///
    /// `exists` ne suffit pas et c'est tout le sujet — une case hors des limites
    /// de son parent existe dans l'arbre d'accessibilité, s'affiche à l'écran,
    /// et n'est pas touchable. C'est exactement ce que décrit l'utilisateur.
    @MainActor
    private func assertBoardIsUsable(contentSize: String?, tag: String) throws {
        let app = launchApp(contentSize: contentSize)
        try openVsEngineGame(in: app)

        let window = app.frame
        for name in ["square_e2", "square_d2", "square_e7"] {
            let square = app.otherElements[name]
            XCTAssertTrue(square.exists, "[\(tag)] \(name) doit exister")
            let frame = square.frame
            print(String(
                format: "HITTEST|%@|%@|hittable=%@|y=[%.1f…%.1f]|fenêtre=[%.1f…%.1f]",
                tag, name, square.isHittable ? "oui" : "NON",
                frame.minY, frame.maxY, window.minY, window.maxY
            ))
            XCTAssertTrue(
                square.isHittable,
                "[\(tag)] \(name) est affichée mais INJOIGNABLE au doigt — "
                    + "le plateau est probablement hors des limites de son parent"
            )
        }

        // Et le tap doit réellement SÉLECTIONNER : une case joignable qui
        // n'allume aucun coup légal serait tout aussi inutilisable.
        app.otherElements["square_e2"].tap()
        XCTAssertTrue(
            app.otherElements["square_e4"].waitForExistence(timeout: 3),
            "[\(tag)] le plateau doit rester cohérent après un tap"
        )
    }

    @MainActor
    func testBoardIsHittableAtDefaultSize() throws {
        try assertBoardIsUsable(contentSize: nil, tag: "L")
    }

    @MainActor
    func testBoardIsHittableAtAX3() throws {
        try assertBoardIsUsable(contentSize: "UICTContentSizeCategoryAccessibilityL", tag: "AX3")
    }

    @MainActor
    func testBoardIsHittableAtAX5() throws {
        try assertBoardIsUsable(contentSize: "UICTContentSizeCategoryAccessibilityXXXL", tag: "AX5")
    }

    /// Tailles NON accessibles mais plus grandes que le défaut : le réglage le
    /// plus courant sur un téléphone personnel, et celui que personne ne teste.
    @MainActor
    func testBoardIsHittableAtLargeSizes() throws {
        try assertBoardIsUsable(contentSize: "UICTContentSizeCategoryXL", tag: "XL")
        try assertBoardIsUsable(contentSize: "UICTContentSizeCategoryXXXL", tag: "XXXL")
    }
}
