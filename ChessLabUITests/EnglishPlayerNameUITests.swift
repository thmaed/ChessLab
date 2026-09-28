import XCTest

/// L'app EN ANGLAIS, vue par le testeur qui l'a signalée.
///
/// Son premier reproche, le 27/09/2026 : « My name Vous […] even though the
/// system is in English ». Le reste de l'interface était bien traduit — c'est
/// le nom du joueur, stocké en clair, qui restait français. Et il n'y avait
/// aucun moyen d'en changer.
///
/// `-AppleLanguages (en)` force la langue « système » indépendamment du
/// simulateur, comme les outils de capture App Store.
@MainActor
final class EnglishPlayerNameUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Le réglage existe, il est trouvable, et il pilote le nom affiché sur la
    /// plaque de joueur pendant la partie.
    func testTheChosenNameShowsOnThePlayerPlate() throws {
        let app = launchInEnglish()

        openSettings(in: app)
        let field = app.textFields["playerNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "le champ « Your name » doit exister")
        XCTAssertTrue(
            app.staticTexts["YOUR NAME"].exists || app.staticTexts["Your name"].exists,
            "le titre de section doit être traduit"
        )

        field.tap()
        field.typeText("Ron")

        goHome(in: app)
        try startGameVersusComputer(in: app)

        XCTAssertTrue(
            app.staticTexts["Ron"].waitForExistence(timeout: 20),
            "la plaque du joueur doit porter le nom choisi"
        )
        XCTAssertFalse(app.staticTexts["Vous"].exists, "« Vous » n'a rien à faire en anglais")
        // Rien à nettoyer ici : `-resetPlaySettings` efface le nom au
        // lancement suivant, comme il efface déjà la langue.
    }

    /// Sans nom choisi, l'anglais dit « You » — jamais « Vous ».
    func testTheDefaultNameIsTranslated() throws {
        let app = launchInEnglish()
        try startGameVersusComputer(in: app)

        XCTAssertTrue(
            app.staticTexts["You"].waitForExistence(timeout: 20),
            "la plaque du joueur doit dire « You »"
        )
        XCTAssertFalse(app.staticTexts["Vous"].exists)
    }

    // MARK: Chemins

    private func launchInEnglish() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetPlaySettings", "-discoveryTourSeen", "-AppleLanguages", "(en)",
        ]
        app.launch()
        return app
    }

    /// Réglages : bouton de barre d'outils sur iPhone, ligne de barre latérale
    /// sur iPad.
    private func openSettings(in app: XCUIApplication) {
        let toolbarButton = app.buttons["openSettings"]
        if toolbarButton.waitForExistence(timeout: 10) {
            toolbarButton.tap()
            return
        }
        app.staticTexts["Settings"].firstMatch.tap()
    }

    /// Sur iPad il n'y a rien à faire — la barre latérale ne quitte jamais
    /// l'écran. Sur iPhone, Réglages est EMPILÉ : il faut en sortir.
    ///
    /// Et surtout pas « le premier bouton de la barre de navigation » : dans
    /// la colonne de détail d'un iPad, c'est la bascule de barre latérale, et
    /// on la refermait au lieu de revenir.
    private func goHome(in app: XCUIApplication) {
        guard !app.staticTexts["Modes"].exists else { return }
        let back = app.navigationBars.buttons["BackButton"]
        if back.exists, back.isHittable { back.tap() }
    }

    private func startGameVersusComputer(in app: XCUIApplication) throws {
        let entry = app.buttons["Against the computer"]
        if entry.waitForExistence(timeout: 15) {
            entry.tap()
        } else {
            app.staticTexts["Against the computer"].firstMatch.tap()
        }
        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 15), "l'écran de réglages doit s'ouvrir")
        start.tap()
        XCTAssertTrue(
            app.otherElements["square_a8"].waitForExistence(timeout: 30),
            "le plateau doit apparaître"
        )
    }
}
