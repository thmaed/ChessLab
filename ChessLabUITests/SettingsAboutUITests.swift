import XCTest

/// Réglages : la section « Ouvertures » ne faisait que répéter ce que l'onglet montre (retour du 16/11/2026) —
/// elle a disparu ; le crédit des données d'ouvertures (« Sources des données ») vit désormais dans « À propos »,
/// avec les licences, et mène toujours à sa page.
@MainActor
final class SettingsAboutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAboutHoldsLicencesAndDataSources_andTheOpeningsSectionIsGone() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-AppleLanguages", "(fr)"]
        app.launch()
        let settings = app.buttons["openSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.tap()

        let sources = app.buttons["openSources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 10))
        var swipes = 0
        while !sources.isHittable, swipes < 15 { app.swipeUp(velocity: .slow); swipes += 1 }
        XCTAssertTrue(app.buttons["openLicenses"].isHittable, "« Licences » reste dans « À propos »")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Explore, apprends et entraîne"))
                        .firstMatch.exists, "la section « Ouvertures » a disparu")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "reglages-a-propos"
        attachment.lifetime = .keepAlways
        add(attachment)

        sources.tap()
        XCTAssertTrue(app.navigationBars["Sources"].waitForExistence(timeout: 10), "le lien mène à la page des sources")
    }
}
