import XCTest

/// La visite guidée, traversée de bout en bout — la vérification que la
/// checklist du contrat exige : « Suivant » reste atteignable à CHAQUE étape
/// (y compris à la plus grande taille d'accessibilité), la visite se termine,
/// et se rejoue depuis l'Aide.
@MainActor
final class DiscoveryTourUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchInTour(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // Le crochet DEBUG saute l'attente et l'empreinte : l'étape 0
        // s'affiche dès le lancement.
        app.launchArguments = ["-discoveryStep", "0"] + extraArguments
        app.launch()
        return app
    }

    private func walkThroughEntireTour(_ app: XCUIApplication, stepCount: Int = 13) {
        let next = app.buttons["discoveryNext"]
        for stepIndex in 0..<stepCount {
            XCTAssertTrue(
                next.waitForExistence(timeout: 8),
                "étape \(stepIndex + 1) : « Suivant » introuvable"
            )
            // L'écran de l'étape peut encore glisser (la visite pilote la navigation) :
            // on laisse l'animation finir avant de juger le bouton inatteignable.
            let hittable = NSPredicate(format: "isHittable == true")
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: next)], timeout: 5)
            XCTAssertTrue(
                next.isHittable,
                "étape \(stepIndex + 1) : « Suivant » présent mais inatteignable"
            )
            next.tap()
        }
        // Après « Terminer », l'overlay a disparu : la visite ne PEUT pas
        // être inéluctable.
        XCTAssertFalse(next.waitForExistence(timeout: 3), "l'overlay survit à Terminer")
    }

    func testTourTraversesAllStepsAndEnds() {
        walkThroughEntireTour(launchInTour())
    }

    /// Le piège Dynamic Type du contrat : aux tailles d'accessibilité, quatre
    /// lignes en font quinze — seul le corps de carte devient défilant, et
    /// « Suivant » ne sort JAMAIS de l'écran.
    func testTourRemainsUsableAtLargestAccessibilitySize() {
        walkThroughEntireTour(launchInTour(extraArguments: [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]))
    }

    func testSkipEndsAndHelpReplays() {
        let app = launchInTour()
        let next = app.buttons["discoveryNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 8))
        app.buttons["discoverySkip"].tap()
        XCTAssertFalse(next.waitForExistence(timeout: 3), "Passer doit fermer la visite")

        // Le rejeu depuis l'Aide : la demande remonte par notification et
        // l'accueil vide sa pile en relançant.
        app.buttons["openHelpFromHome"].tap()
        let replay = app.buttons["replayDiscoveryTour"]
        // La carte vit en TÊTE de l'Aide : elle doit exister sans un seul
        // défilement — et on attend la fin de la transition de navigation
        // avant d'en juger.
        XCTAssertTrue(
            replay.waitForExistence(timeout: 8),
            "la carte de rejeu doit accueillir en tête de l'Aide"
        )
        XCTAssertTrue(replay.isHittable, "la carte de rejeu doit être atteignable sans défiler")
        replay.tap()
        XCTAssertTrue(next.waitForExistence(timeout: 8), "le rejeu doit rouvrir la visite")
    }

    /// Le court parcours des nouveautés 2.0 (mise à jour depuis la 1.x) : six
    /// étapes, « Suivant » atteignable à chacune, et il se termine.
    func testWhatsNewTourTraversesAllStepsAndEnds() {
        let app = XCUIApplication()
        app.launchArguments = ["-discoveryWhatsNew", "YES"]
        app.launch()
        walkThroughEntireTour(app, stepCount: 6)
    }
}
