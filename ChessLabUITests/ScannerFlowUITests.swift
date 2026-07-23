import XCTest

/// Parcours de bout en bout du scanner — **critère d'acceptation de l'étape
/// 7** : « capture reconnue, corrigée, puis jouée ».
///
/// L'image traverse tout le pipeline réel (détection, redressement, découpe,
/// classification) ; seule son ORIGINE est injectée par
/// `-scanTestImage`, les sélecteurs système étant hors process et donc hors
/// de portée de XCUITest.
///
/// Test déterministe : aucun moteur n'est sollicité avant la position finale,
/// et la vérification porte sur le contenu du plateau, pas sur un coup joué.
final class ScannerFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Position de l'image de test (`ScanTestImage.syntheticFEN`) : après
    /// 1. e4 c5.
    @MainActor
    func testScannedPositionIsConfirmedThenPlayed() throws {
        // « realistic » : capture de téléphone PORTRAIT, plateau pleine
        // largeur collé aux bords, interface autour — le cas utilisateur qui
        // avait mis le cadrage automatique en défaut.
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-scanTestImage", "realistic"]
        app.launch()

        XCTAssertTrue(app.buttons["Analyser"].waitForExistence(timeout: 5))
        app.buttons["Analyser"].tap()
        XCTAssertTrue(app.buttons["Scanner une position"].waitForExistence(timeout: 5))
        app.buttons["Scanner une position"].tap()

        // Cadrage AUTOMATIQUE : l'image de test est injectée à l'apparition,
        // le motif de damier est détecté, et le scanner enchaîne directement
        // sur la confirmation — plus d'étape de recadrage manuel pour une
        // capture nette.
        let e4 = app.otherElements["square_e4"]
        XCTAssertTrue(e4.waitForExistence(timeout: 15), "l'écran de confirmation devrait s'afficher automatiquement")

        // La position lue est la bonne : pion blanc en e4, pion noir en c5,
        // e2 et c7 vidées de leurs pions.
        XCTAssertEqual(e4.label, "e4, pion blanc")
        XCTAssertEqual(app.otherElements["square_c5"].label, "c5, pion noir")
        XCTAssertEqual(app.otherElements["square_e2"].label, "e2, case vide")
        XCTAssertEqual(app.otherElements["square_c7"].label, "c7, case vide")

        // Correction manuelle possible (le fallback du prompt) : poser une
        // dame blanche en d4, puis l'effacer.
        app.buttons["dame blanche"].tap()
        app.otherElements["square_d4"].tap()
        XCTAssertEqual(app.otherElements["square_d4"].label, "d4, dame blanche")
        app.otherElements["square_d4"].tap()
        XCTAssertEqual(app.otherElements["square_d4"].label, "d4, case vide")

        // Jouer : la partie démarre sur la position scannée. Le bouton n'est
        // actif que si la lecture est légale — la vérification la plus utile
        // du test, celle qui a révélé que la reconnaissance réelle ne lisait
        // que les pions.
        let playButton = app.buttons["Jouer cette position"]
        XCTAssertTrue(playButton.isEnabled, "la position lue devrait être valide, donc jouable")
        playButton.tap()

        // ⚠️ Le libellé du plateau de JEU (« Case e4, … ») diffère de celui de
        // l'éditeur (« e4, … »), et c'est ce qui rend cette vérification
        // concluante : l'écran de confirmation reste dans la hiérarchie
        // derrière la partie poussée, et `square_e4` y répond encore. Attendre
        // le libellé de l'éditeur, c'était se prouver qu'on n'avait pas
        // changé d'écran.
        let playedE4 = app.otherElements["square_e4"]
        XCTAssertTrue(playedE4.waitForExistence(timeout: 10))
        expectEventually(playedE4, toHaveLabel: "Case e4, pion blanc", "la partie devrait démarrer sur la position scannée")
        XCTAssertEqual(app.otherElements["square_c5"].label, "Case c5, pion noir")
    }

    /// Le temps que la partie soit poussée, `square_xx` peut encore désigner
    /// l'écran précédent : on attend le libellé de la partie.
    @MainActor
    private func expectEventually(
        _ element: XCUIElement, toHaveLabel label: String, _ message: String,
        timeout: TimeInterval = 10
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, element.label != label {
            usleep(200_000)
        }
        XCTAssertEqual(element.label, label, message)
    }

}
