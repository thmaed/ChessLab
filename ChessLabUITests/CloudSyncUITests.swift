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

    /// Éteinte → « Désactivée » ; allumée → la base change SANS quitter l'app (écran de passage, retour
    /// aux Réglages), plus de « dernière étape : relancer » ; éteinte de nouveau → « Désactivée ».
    func testSettingsCard_switchesWithoutRestart() throws {
        let app = launch()
        openSettings(app)
        var toggle = app.switches["syncToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        scrollTo(toggle, in: app)
        XCTAssertTrue(app.staticTexts["Désactivée"].exists, "l'état doit dire « Désactivée »")
        snapshot(app, "reglages-eteinte")

        toggle.switches.firstMatch.tap()
        // Retour aux Réglages, sur la nouvelle base : la liste des appareils, et pas de relancement demandé.
        XCTAssertTrue(app.staticTexts["Cet appareil"].waitForExistence(timeout: 15),
                      "après l'échange, les Réglages doivent montrer « Vos appareils »")
        scrollTo(app.staticTexts["Cet appareil"], in: app)
        XCTAssertFalse(app.staticTexts["Dernière étape : relancer ChessLab"].exists,
                       "la base a changé à chaud : plus rien à relancer")
        XCTAssertFalse(app.otherElements["syncRestartBanner"].exists)
        snapshot(app, "reglages-allumee-sans-relancer")

        toggle = app.switches["syncToggle"]
        scrollTo(toggle, in: app)
        toggle.switches.firstMatch.tap()
        let off = app.staticTexts["Désactivée"]
        let deadline = Date().addingTimeInterval(15)
        while !off.exists, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            if app.switches["syncToggle"].exists, !app.switches["syncToggle"].isHittable { app.swipeUp(velocity: .slow) }
        }
        XCTAssertTrue(off.exists, "éteinte de nouveau : « Désactivée », sans relancement")
        XCTAssertFalse(app.staticTexts["Dernière étape : relancer ChessLab"].exists)
    }

    /// Un autre appareil synchronise : l'accueil le propose ; « Activer » change la base sans quitter l'app
    /// et mène aux Réglages, où l'iPad fictif est listé avec son modèle et son système.
    func testHomeInvitation_switchesWithoutRestart() throws {
        let app = launch(["-fakeSyncDevice"])
        let card = app.otherElements["syncInvitationCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "la proposition doit apparaître à l'accueil")
        // L'iPad fictif porte un modèle (iPad16,6) : on le nomme, pas seulement « iPad ».
        XCTAssertTrue(app.staticTexts["Votre iPad Pro 13″ (M4) synchronise déjà ChessLab"].exists)
        snapshot(app, "accueil-proposition")

        app.buttons["syncInvitationAccept"].tap()
        let pad = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "iPad Pro 13″ (M4)")).firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: 15), "après l'échange, les Réglages listent l'iPad")
        scrollTo(pad, in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "iPadOS 26.1")).firstMatch.exists,
                      "la version du système de l'iPad doit être affichée")
        XCTAssertFalse(app.staticTexts["Dernière étape : relancer ChessLab"].exists)
        snapshot(app, "reglages-appareils")

        // À l'accueil : ni proposition, ni rappel de relancement. Sur iPhone on y revient par la flèche ; sur
        // iPad, les Réglages occupent la colonne de détail et l'accueil reste à côté.
        if UIDevice.current.userInterfaceIdiom == .phone {
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["openSettings"].waitForExistence(timeout: 10))
        }
        XCTAssertFalse(card.exists)
        XCTAssertFalse(app.buttons["syncRestartReminder"].exists)
    }

    /// Allume la synchro dans les Réglages, puis revient à l'accueil.
    private func enableSyncAndGoHome(_ app: XCUIApplication) {
        openSettings(app)
        let toggle = app.switches["syncToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        scrollTo(toggle, in: app)
        toggle.switches.firstMatch.tap()
        // La base change (écran de passage), puis les Réglages reviennent.
        XCTAssertTrue(app.staticTexts["Cet appareil"].waitForExistence(timeout: 15))
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func waitForMoveCount(_ expected: String, in app: XCUIApplication, timeout: TimeInterval = 15) {
        let moveCount = app.otherElements["moveCount"]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, moveCount.value as? String != expected {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertEqual(moveCount.value as? String, expected)
    }

    /// Contre l'ordinateur : 1.e4, et la réponse du moteur.
    private func startGameAndPlayE4(_ app: XCUIApplication) {
        app.buttons["Contre l'ordinateur"].tap()
        XCTAssertTrue(app.buttons["Commencer"].waitForExistence(timeout: 5))
        app.buttons["Commencer"].tap()
        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 20))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()
        waitForMoveCount("2", in: app)
    }

    /// Synchro allumée, la partie en cours est la MÊME sur tous les appareils : l'avertissement de
    /// « Commencer » le dit (essai sur trois iPhone, 16/11/2026 : une partie lancée sur l'un a remplacé celle
    /// d'un autre, et l'avertissement ne parlait que de « la partie en cours »).
    func testNewGameWarning_mentionsAllDevices_whenSyncIsOn() throws {
        let app = launch()
        enableSyncAndGoHome(app)
        startGameAndPlayE4(app)

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

    /// L'« iPad » reprend deux demi-coups de la MÊME partie pendant que l'échiquier est ouvert ici : un
    /// bandeau le dit, et « Rattraper » rouvre la partie telle qu'elle est là-bas.
    func testRemoteTakeback_bannerOffersToCatchUp() throws {
        let app = launch(["-fakeRemoteTakeback"])
        enableSyncAndGoHome(app)
        startGameAndPlayE4(app)

        let banner = app.otherElements["remoteAdvanceBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 15), "le bandeau doit apparaître sur l'échiquier")
        XCTAssertTrue(app.staticTexts["Cette partie a continué sur votre iPad Pro 13″ (M4)"].exists)
        RunLoop.current.run(until: Date().addingTimeInterval(1))   // fin de l'animation d'entrée
        XCTAssertTrue(app.buttons["remoteAdvanceCatchUp"].isHittable, "« Rattraper » doit être touchable")
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.isHittable, "le bandeau ne doit pas couvrir la barre")
        snapshot(app, "echiquier-bandeau")
        app.buttons["remoteAdvanceCatchUp"].tap()
        // Rouverte telle que l'iPad la porte : plus aucun coup, et le bandeau est parti.
        waitForMoveCount("0", in: app)
        XCTAssertFalse(app.otherElements["remoteAdvanceBanner"].exists)
    }

    /// L'« iPad » commence une AUTRE partie : elle devient la partie en cours, et la nôtre est mise de côté
    /// au lieu d'être perdue. La reprendre l'échange avec l'autre.
    func testOtherGameFromElsewhere_setsOursAside_andResumingSwaps() throws {
        let app = launch(["-fakeRemoteOtherGame"])
        enableSyncAndGoHome(app)
        startGameAndPlayE4(app)
        app.navigationBars.buttons.firstMatch.tap()

        let aside = app.buttons["resumeAsideGame"]
        XCTAssertTrue(aside.waitForExistence(timeout: 15), "notre partie doit être mise de côté, pas perdue")
        XCTAssertTrue(app.staticTexts["Dernier coup joué sur votre iPad Pro 13″ (M4)"].exists)
        snapshot(app, "accueil-mise-de-cote")
        aside.tap()
        // C'est bien la nôtre : ses deux demi-coups.
        waitForMoveCount("2", in: app)
        app.navigationBars.buttons.firstMatch.tap()
        // Et celle de l'iPad a pris sa place de côté.
        XCTAssertTrue(app.buttons["resumeAsideGame"].waitForExistence(timeout: 10))
    }

    /// « Vos appareils » : on peut nommer cet appareil, le nom remplace le modèle dans la liste.
    func testRenameThisDevice() throws {
        let app = launch()
        openSettings(app)
        let toggle = app.switches["syncToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        scrollTo(toggle, in: app)
        toggle.switches.firstMatch.tap()
        let rename = app.buttons["renameThisDevice"]
        XCTAssertTrue(rename.waitForExistence(timeout: 15))
        scrollTo(rename, in: app)
        rename.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Téléphone de test")
        app.alerts.buttons["Enregistrer"].tap()
        XCTAssertTrue(app.staticTexts["Téléphone de test"].waitForExistence(timeout: 5))
        snapshot(app, "reglages-appareil-renomme")
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
