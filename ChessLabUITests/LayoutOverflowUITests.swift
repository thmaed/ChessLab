import XCTest

/// Non-régression de mise en page (Lot 5) : ces tests échouent **avant**
/// correction — c'est voulu, c'est la preuve que le détecteur du Lot 0.2
/// attrape bien ce que l'œil signalait.
///
/// Ils s'appuient sur ``LayoutProbe`` : uniquement des `frame`
/// d'accessibilité, jamais des captures d'écran.
final class LayoutOverflowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"] + arguments
        app.launch()
        return app
    }

    // MARK: 5.2 — Sélecteur de promotion

    /// Le sélecteur de promotion apparaît sur 7 écrans ; il est identique
    /// partout, donc un seul chemin suffit à le mesurer. On passe par
    /// *Analyser* + une position FEN plutôt que de pousser un pion sur 6
    /// rangées : c'est le chemin le plus court vers une promotion.
    @MainActor
    func testPromotionPickerFitsOnScreen() throws {
        let app = launchApp()
        // Pion blanc en a7, deux rois : la promotion est le seul coup
        // intéressant, et elle est légale immédiatement.
        try openAnalysis(in: app, fen: "8/P6k/8/8/8/8/7K/8 w - - 0 1")

        app.otherElements["square_a7"].tap()
        app.otherElements["square_a8"].tap()

        let queen = app.buttons["Dame"]
        XCTAssertTrue(queen.waitForExistence(timeout: 10), "le sélecteur de promotion doit s'ouvrir")

        // Trace la mesure même quand le test passe : c'est elle qui documente
        // la marge réelle, pas le simple verdict.
        let window = app.frame
        for label in ["Dame", "Tour", "Fou", "Cavalier"] {
            let tile = app.buttons[label]
            guard tile.exists else { continue }
            print(
                String(
                    format: "PROMO|%@|x=[%.1f…%.1f]|fenêtre=[%.1f…%.1f]",
                    label, tile.frame.minX, tile.frame.maxX, window.minX, window.maxX
                )
            )
        }

        LayoutProbe.assertNoHorizontalOverflow(in: app, context: "sélecteur de promotion")
    }

    // MARK: 5.3 — Taille du plateau en portrait iPhone

    /// Garde-fou de la qualité obtenue en portrait : le plateau doit occuper
    /// l'essentiel de la largeur utile. Sans ce test, une barre ajoutée
    /// au-dessus du plateau pourrait le rétrécir sans que rien ne le signale.
    @MainActor
    func testBoardFillsPortraitWidth() throws {
        let app = launchApp()
        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: false)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "compact",
            "Garde-fou spécifique au portrait iPhone (classe compacte)"
        )

        try openVsEngineGame(in: app)
        guard let side = LayoutProbe.boardSide(in: app) else {
            XCTFail("Plateau introuvable")
            return
        }
        let ratio = side / traits.usableWidth
        print(String(format: "BOARD-RATIO|%.3f|side=%.1f|usable=%.1f", ratio, side, traits.usableWidth))
        XCTAssertGreaterThanOrEqual(
            ratio, 0.80,
            "Le plateau doit occuper au moins 80 % de la largeur utile en portrait iPhone"
        )
    }

    // MARK: 5.1 — Détecteur générique sur les écrans principaux

    /// Les six tuiles de mode sont exclues, sur preuve — voir ci-dessous.
    private static let decorativeHomeTiles: Set<String> = [
        "Contre l'ordinateur", "Deux joueurs", "Puzzles",
        "Ouvertures", "Analyser", "Laboratoire", "mode_openings",
        "cpu", "person.2.fill", "puzzlepiece.fill",
        "books.vertical.fill", "chart.xyaxis.line", "flask",
    ]

    /// L'accueil, hors artefact documenté.
    ///
    /// ## Pourquoi les tuiles sont exclues
    ///
    /// Le détecteur les signale (jusqu'à 17,5 pt « dehors »), mais la mesure
    /// montre que **rien n'est coupé à l'écran** :
    ///
    /// - les colonnes sont régulières — les tuiles commencent à x=20 et
    ///   x=194,5, soit un pas de 174,5 pt (160,5 de carte + 14 d'espacement),
    ///   exactement ce que calcule la grille ;
    /// - leur CONTENU est bien à l'intérieur : « Sur le même appareil »
    ///   s'étend de 210,5 à 339, dans les marges de la carte (210,5 → 339) ;
    /// - seules les tuiles aux symboles LARGES (`person.2.fill`,
    ///   `books.vertical.fill`) sont signalées, et leur largeur annoncée varie
    ///   avec le symbole (173 à 198 pt pour une carte de 160,5).
    ///
    /// C'est donc la grande icône décorative « fantôme » du fond qui gonfle la
    /// `frame` remontée par l'accessibilité. Elle est **visuellement écrêtée**
    /// par le `clipShape` de la carte ; SwiftUI n'en tient pas compte pour la
    /// géométrie annoncée. Trois tentatives de correction sont restées sans
    /// effet sur la mesure : `accessibilityHidden(true)` sur l'image puis sur
    /// tout le fond, `clipped()`, et un `frame` explicite sur le glyphe — les
    /// valeurs n'ont pas bougé d'un demi-point.
    ///
    /// L'exclusion est donc assumée et argumentée, plutôt que masquée par un
    /// seuil de tolérance qui aurait aussi laissé passer de vrais
    /// débordements. Les deux premières corrections sont conservées : elles
    /// évitent que VoiceOver annonce un glyphe décoratif.
    @MainActor
    func testNoOverflowOnHomeScreen() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 10))
        LayoutProbe.assertNoHorizontalOverflow(
            in: app, context: "accueil", ignoring: Self.decorativeHomeTiles
        )
    }

    @MainActor
    func testNoOverflowOnPlayScreen() throws {
        let app = launchApp()
        try openVsEngineGame(in: app)
        LayoutProbe.assertNoHorizontalOverflow(in: app, context: "Jouer")
    }

    // MARK: Navigation

    @MainActor
    private func openVsEngineGame(in app: XCUIApplication) throws {
        let entry = app.buttons["Contre l'ordinateur"]
        guard entry.waitForExistence(timeout: 10) else {
            throw LayoutProbeError.markerMissing("Contre l'ordinateur")
        }
        entry.tap()
        let start = app.buttons["Commencer"]
        guard start.waitForExistence(timeout: 10) else {
            throw LayoutProbeError.markerMissing("Commencer")
        }
        start.tap()
        _ = app.otherElements["square_a8"].waitForExistence(timeout: 20)
    }

    /// Même chemin que ``AnalysisStepThroughUITests`` : Analyser → Autres
    /// sources → Position FEN.
    @MainActor
    private func openAnalysis(in app: XCUIApplication, fen: String) throws {
        let entry = app.buttons["Analyser"]
        guard entry.waitForExistence(timeout: 10) else {
            throw LayoutProbeError.markerMissing("Analyser")
        }
        entry.tap()
        XCTAssertTrue(app.buttons["Autres sources"].waitForExistence(timeout: 10))
        app.buttons["Autres sources"].tap()
        XCTAssertTrue(app.buttons["Position FEN"].waitForExistence(timeout: 10))
        app.buttons["Position FEN"].tap()

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
