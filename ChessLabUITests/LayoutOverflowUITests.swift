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
        // Mesuré là où la contrainte mord : un écran de 375 pt. Sur iPad la
        // largeur est surabondante, la mesure n'y apprend rien.
        //
        // Ce chemin y est par ailleurs INSTABLE, mesuré : il passe sur iPad
        // Pro 11" et 13", et échoue sur iPad **mini** — les deux taps (a7 puis
        // a8) sont bien synthétisés, mais le sélecteur ne s'ouvre jamais.
        // Cause non déterminée (défaut propre au mini ? simple lenteur ?),
        // consignée dans `PROGRESS.md` comme question ouverte plutôt que
        // laissée en rouge sans diagnostic.
        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: false)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "compact",
            "Mesure faite en classe compacte, où la largeur est contrainte"
        )
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

    /// L'accueil, hors artefact documenté.
    ///
    /// L'exclusion des six tuiles de mode vit désormais dans
    /// ``LayoutProbe/homeModeTileArtifacts`` — source unique, partagée avec le
    /// balayage de diagnostic, qui la documente et l'argumente. Elle ne peut
    /// masquer aucun texte coupé : ``LayoutProbe/neverExcludedTypes`` interdit
    /// d'exclure un `.staticText`, quel que soit son libellé.
    ///
    /// Les deux `accessibilityHidden(true)` de `ModeCard` sont conservés même
    /// s'ils ne changent pas la mesure : ils évitent que VoiceOver annonce un
    /// glyphe décoratif.
    @MainActor
    func testNoOverflowOnHomeScreen() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 10))
        LayoutProbe.assertNoHorizontalOverflow(
            in: app, context: "accueil", ignoring: LayoutProbe.homeModeTileArtifacts
        )
    }

    /// Le garde-fou du garde-fou : prouve que l'exclusion ci-dessus ne porte
    /// que sur la géométrie annoncée des CONTENEURS, et que les textes des
    /// tuiles restent réellement mesurés.
    ///
    /// Sans lui, rien ne distinguerait « le titre tient dans la carte » de
    /// « le titre est exclu par son libellé » — c'est exactement la confusion
    /// qui a fait consigner l'artefact comme un défaut le 15/08.
    @MainActor
    func testHomeTileTextsAreMeasuredNotExcluded() throws {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 10))

        // Le libellé est dans la liste d'exclusion ; le `Text` qui le porte
        // doit malgré tout être inspecté, donc visible du détecteur.
        XCTAssertTrue(
            app.staticTexts["Deux joueurs"].firstMatch.waitForExistence(timeout: 5),
            "le titre de tuile doit être un élément mesurable"
        )

        let window = app.frame
        for label in ["Contre l'ordinateur", "Deux joueurs", "Puzzles", "Analyser"] {
            // TOUTES les occurrences, pas la première : un même libellé est
            // porté par plusieurs éléments de l'arbre d'accessibilité, et
            // exiger l'unicité faisait échouer le test sur un défaut du
            // harnais — pas de l'app.
            let matches = app.staticTexts.matching(identifier: label)
                .allElementsBoundByAccessibilityElement
            XCTAssertFalse(matches.isEmpty, "aucun texte « \(label) » mesurable sur l'accueil")
            for (index, text) in matches.enumerated() {
                let frame = text.frame
                guard frame.width > 0, frame.height > 0 else { continue }
                print(
                    String(
                        format: "TILE-TEXT|%@|#%d|x=[%.1f…%.1f]|fenêtre=[%.1f…%.1f]",
                        label, index, frame.minX, frame.maxX, window.minX, window.maxX
                    )
                )
                XCTAssertLessThanOrEqual(
                    frame.maxX, window.maxX + 0.5,
                    "le texte « \(label) » sort de la fenêtre — un vrai débordement, pas l'artefact du fond"
                )
            }
        }
    }

    @MainActor
    func testNoOverflowOnPlayScreen() throws {
        let app = launchApp()
        try openVsEngineGame(in: app)
        LayoutProbe.assertNoHorizontalOverflow(in: app, context: "Jouer")
    }

    // MARK: Navigation

    /// Trois formes possibles pour le même libellé : `Button` dans la grille
    /// iPhone, `Cell` ou `StaticText` dans la barre latérale iPad. Ne chercher
    /// que le bouton faisait échouer ce test sur iPad — un défaut du harnais,
    /// pas de l'app.
    @MainActor
    private func openVsEngineGame(in app: XCUIApplication) throws {
        let button = app.buttons["Contre l'ordinateur"]
        if button.waitForExistence(timeout: 10) {
            button.tap()
        } else if app.cells["Contre l'ordinateur"].waitForExistence(timeout: 3) {
            app.cells["Contre l'ordinateur"].tap()
        } else if app.staticTexts["Contre l'ordinateur"].waitForExistence(timeout: 3) {
            app.staticTexts["Contre l'ordinateur"].tap()
        } else {
            throw LayoutProbeError.markerMissing("Contre l'ordinateur")
        }
        let start = app.buttons["Commencer"]
        guard start.waitForExistence(timeout: 10) else {
            throw LayoutProbeError.markerMissing("Commencer")
        }
        start.tap()
        _ = app.otherElements["square_a8"].waitForExistence(timeout: 20)
    }

    /// Même chemin que ``AnalysisStepThroughUITests`` : Analyser → Autres
    /// sources → Analyser PGN / FEN.
    @MainActor
    private func openAnalysis(in app: XCUIApplication, fen: String) throws {
        // Même précaution que ci-dessus : bouton sur iPhone, ligne de barre
        // latérale sur iPad.
        let entry = app.buttons["Analyser"]
        if entry.waitForExistence(timeout: 10) {
            entry.tap()
        } else if app.cells["Analyser"].waitForExistence(timeout: 3) {
            app.cells["Analyser"].tap()
        } else if app.staticTexts["Analyser"].waitForExistence(timeout: 3) {
            app.staticTexts["Analyser"].tap()
        } else {
            throw LayoutProbeError.markerMissing("Analyser")
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
