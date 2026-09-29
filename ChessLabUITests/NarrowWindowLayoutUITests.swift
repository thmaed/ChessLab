import XCTest

/// L'app dans une fenêtre ÉTROITE mais de classe « regular ».
///
/// C'est le cas que le testeur a fini par isoler (28/09/2026) : sur un iPad
/// 13 pouces, il ne s'agissait ni de la barre latérale ni du paysage, mais du
/// **redimensionnement de la fenêtre** pour partager l'écran avec une autre
/// app. Or un iPad de 13 pouces garde la classe `regular` bien après que la
/// fenêtre a cessé d'être large : l'app y montre encore barre latérale +
/// détail, dans une place où l'iPhone montrerait une seule colonne.
///
/// La fenêtre partagée elle-même ne se pilote pas depuis XCUITest (limite
/// documentée dans ``SkeletonOverride``). On mesure donc la fenêtre `regular`
/// la plus étroite qu'on puisse obtenir en plein écran — l'iPad mini en
/// portrait, 744 pt — pour savoir jusqu'où la disposition iPad tient vraiment.
@MainActor
final class NarrowWindowLayoutUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// Le plateau d'une partie tient-il dans la fenêtre, et quelle part en
    /// occupe-t-il ? Relevé imprimé même quand le test passe.
    func testTheBoardFitsInTheNarrowestRegularWindow() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()

        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: false)
        print(traits.logLine(device: device, orientation: "portrait"))

        try startGameVersusComputer(in: app)

        if let board = LayoutProbe.boardRect(in: app) {
            print(
                String(
                    format: "PLATEAU|%@|classe=%@|fenêtre=%.0f|plateau=[%.1f…%.1f] côté=%.1f (%.0f %% de la fenêtre)",
                    device, traits.horizontalSizeClass, traits.usableWidth,
                    board.minX, board.maxX, board.width,
                    board.width / traits.usableWidth * 100
                )
            )
        } else {
            XCTFail("Plateau introuvable")
        }

        LayoutProbe.assertNoHorizontalOverflow(
            in: app,
            context: "partie contre l'ordinateur, fenêtre de \(Int(traits.usableWidth)) pt",
            ignoring: ["AdditionalDimmingOverlay"]
        )
    }

    /// En PAYSAGE, les deux colonnes se partagent la largeur. Relevé : ce que
    /// l'échiquier obtient réellement face au panneau.
    func testTheBoardAndThePanelShareTheWidthInLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()

        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: true)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "regular", "Deux colonnes : iPad seulement"
        )

        try startGameVersusComputer(in: app)
        guard let board = LayoutProbe.boardRect(in: app) else {
            XCTFail("Plateau introuvable")
            return
        }
        print(
            String(
                format: "PAYSAGE|%@|fenêtre=%.0f|plateau=[%.1f…%.1f] côté=%.1f (%.0f %% de la fenêtre)",
                device, traits.usableWidth, board.minX, board.maxX, board.width,
                board.width / traits.usableWidth * 100
            )
        )
        LayoutProbe.assertNoHorizontalOverflow(
            in: app, context: "partie en paysage", ignoring: ["AdditionalDimmingOverlay"]
        )
    }

    /// Le même écran, **barre latérale repliée** : la colonne devient aussi
    /// large que la fenêtre, et bien moins haute qu'elle n'est large en
    /// proportion. C'est le seul cas de « colonne courte » qu'un simulateur
    /// plein écran sache produire — celui du testeur, en fenêtre partagée, ne
    /// se pilote pas depuis XCUITest.
    func testAShortColumnGivesTheBoardTheRoomTheListWasTaking() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen"]
        app.launch()

        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: false)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "regular",
            "Barre latérale + détail : iPad seulement"
        )

        try startGameVersusComputer(in: app)
        guard let withSidebar = LayoutProbe.boardRect(in: app) else {
            XCTFail("Plateau introuvable")
            return
        }

        let toggle = app.buttons["Masquer la barre latérale"]
        try XCTSkipUnless(toggle.waitForExistence(timeout: 5), "bascule introuvable")
        toggle.tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))

        guard let folded = LayoutProbe.boardRect(in: app) else {
            XCTFail("Plateau introuvable après repli")
            return
        }
        print(
            String(
                format: "COLONNE|%@|fenêtre=%.0f|barre ouverte=%.1f|barre repliée=%.1f (+%.0f %%)",
                device, traits.usableWidth, withSidebar.width, folded.width,
                (folded.width / withSidebar.width - 1) * 100
            )
        )

        XCTAssertGreaterThan(
            folded.width, withSidebar.width,
            "replier la barre doit profiter à l'échiquier"
        )

        // La liste des coups n'a pas disparu : elle a changé de place. Sans
        // cette vérification, on aurait pu la retirer sans rien offrir à la
        // place, ce qui serait une perte, pas un gain.
        let movesButton = app.buttons["Coups joués"]
        XCTAssertTrue(
            movesButton.waitForExistence(timeout: 5),
            "le bouton « Coups joués » doit prendre le relais de la liste"
        )
        movesButton.tap()
        XCTAssertTrue(
            app.navigationBars["Coups"].waitForExistence(timeout: 5),
            "il doit ouvrir la feuille des coups"
        )
        app.buttons["Fermer"].tap()
        LayoutProbe.assertNoHorizontalOverflow(
            in: app, context: "partie, barre latérale repliée",
            ignoring: ["AdditionalDimmingOverlay"]
        )
    }

    private var device: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "?"
    }

    private func startGameVersusComputer(in app: XCUIApplication) throws {
        let entry = app.buttons["Contre l'ordinateur"]
        if entry.waitForExistence(timeout: 15) {
            entry.tap()
        } else {
            app.staticTexts["Contre l'ordinateur"].firstMatch.tap()
        }
        let start = app.buttons["Commencer"]
        XCTAssertTrue(start.waitForExistence(timeout: 15), "l'écran de réglages doit s'ouvrir")
        start.tap()
        XCTAssertTrue(
            app.otherElements["square_a8"].waitForExistence(timeout: 30), "le plateau doit apparaître"
        )
    }
}
