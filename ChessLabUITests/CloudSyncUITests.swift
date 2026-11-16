import XCTest

/// La synchronisation iCloud telle que l'utilisateur la voit (refonte du 16/11/2026) : un état en un mot,
/// les gestes de relancement, la proposition à l'accueil quand un autre appareil synchronise déjà.
///
/// Le simulateur n'a pas de compte iCloud : on éprouve ce qui ne dépend pas d'un vrai échange. L'« iPad »
/// est une fiche fictive (`-fakeSyncDevice`, simulateur et Debug seulement).
@MainActor
final class CloudSyncUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-AppleLanguages", "(fr)"] + extra
        app.launch()
        return app
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openSettings(_ app: XCUIApplication) {
        let toolbarButton = app.buttons["openSettings"]
        if toolbarButton.waitForExistence(timeout: 10) { toolbarButton.tap(); return }
        app.staticTexts["Réglages"].firstMatch.tap()
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while !element.isHittable, tries < 12 { app.swipeUp(velocity: .slow); tries += 1 }
    }

    /// Éteinte → « Désactivée » ; allumée → la dernière étape et ses gestes, sans relancer pour rien
    /// le reste ; éteinte de nouveau → retour à « Désactivée ».
    func testSettingsCard_saysWhereThingsStand() throws {
        let app = launch()
        openSettings(app)
        let toggle = app.switches["syncToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        scrollTo(toggle, in: app)
        XCTAssertTrue(app.staticTexts["Désactivée"].exists, "l'état doit dire « Désactivée »")
        snapshot(app, "reglages-eteinte")

        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.otherElements["syncRestartBanner"].waitForExistence(timeout: 5)
                      || app.staticTexts["Dernière étape : relancer ChessLab"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts["Cet appareil"].waitForExistence(timeout: 5),
                      "la liste « Vos appareils » doit montrer cet appareil dès l'activation")
        scrollTo(app.staticTexts["Cet appareil"], in: app)
        snapshot(app, "reglages-derniere-etape")

        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Désactivée"].waitForExistence(timeout: 5))
    }

    /// Un autre appareil synchronise : l'accueil le propose ; « Activer » mène aux gestes, puis un rappel
    /// reste à l'accueil tant que l'app n'a pas été relancée.
    func testHomeInvitation_leadsToTheRestartSteps() throws {
        let app = launch(["-fakeSyncDevice"])
        let card = app.otherElements["syncInvitationCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "la proposition doit apparaître à l'accueil")
        // L'iPad fictif porte un modèle (iPad16,6) : on le nomme, pas seulement « iPad ».
        XCTAssertTrue(app.staticTexts["Votre iPad Pro 13″ (M4) synchronise déjà ChessLab"].exists)
        snapshot(app, "accueil-proposition")

        app.buttons["syncInvitationAccept"].tap()
        XCTAssertTrue(app.buttons["syncRestartSheetOK"].waitForExistence(timeout: 5))
        snapshot(app, "accueil-feuille-relancer")
        app.buttons["syncRestartSheetOK"].tap()

        XCTAssertTrue(app.buttons["syncRestartReminder"].waitForExistence(timeout: 5),
                      "le rappel doit rester à l'accueil tant que l'app n'est pas relancée")
        XCTAssertFalse(card.exists)
        snapshot(app, "accueil-rappel")

        // Les Réglages listent l'iPad fictif — son modèle, son système — avec sa version plus ancienne
        // signalée.
        openSettings(app)
        let pad = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "iPad Pro 13″ (M4)")).firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: 10))
        scrollTo(pad, in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "iPadOS 26.1")).firstMatch.exists,
                      "la version du système de l'iPad doit être affichée")
        snapshot(app, "reglages-appareils")
    }

    /// Synchro allumée, la partie en cours est la MÊME sur tous les appareils : l'avertissement de
    /// « Commencer » le dit (essai sur trois iPhone, 16/11/2026 : une partie lancée sur l'un a remplacé celle
    /// d'un autre, et l'avertissement ne parlait que de « la partie en cours »).
    func testNewGameWarning_mentionsAllDevices_whenSyncIsOn() throws {
        let app = launch()
        openSettings(app)
        let toggle = app.switches["syncToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        scrollTo(toggle, in: app)
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Cet appareil"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 20))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        let moveCount = app.otherElements["moveCount"]
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, moveCount.value as? String != "2" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(moveCount.value as? String, "2")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["resumeGame"].waitForExistence(timeout: 5))
        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()
        let alert = app.alerts["Une partie est en cours"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "sur tous vos appareils"))
            .firstMatch.exists, "l'avertissement doit dire que la partie disparaîtra de tous les appareils")
        snapshot(app, "nouvelle-partie-avertissement")
        alert.buttons["Annuler"].tap()
    }

    /// « Pas maintenant » : la proposition disparaît et ne revient pas au lancement suivant.
    func testHomeInvitation_notNow_isRemembered() throws {
        var app = launch(["-fakeSyncDevice"])
        XCTAssertTrue(app.otherElements["syncInvitationCard"].waitForExistence(timeout: 15))
        app.buttons["syncInvitationDismiss"].tap()
        XCTAssertFalse(app.otherElements["syncInvitationCard"].waitForExistence(timeout: 2))
        app.terminate()

        app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)", "-fakeSyncDevice"]
        app.launch()
        XCTAssertTrue(app.buttons["openSettings"].waitForExistence(timeout: 15)
                      || app.staticTexts["Modes"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.otherElements["syncInvitationCard"].waitForExistence(timeout: 3),
                       "une proposition déclinée ne revient pas")
    }
}
