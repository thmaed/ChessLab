import XCTest

/// Le chantier « pourquoi » ajoute une SECONDE ligne au bandeau coach. C'est
/// exactement le genre d'ajout qui a déjà fait passer ce bandeau sous le bord
/// de l'écran une fois (colonne gauche de l'iPad en paysage, qui n'est pas
/// dans un `ScrollView` — voir `PROGRESS.md`).
///
/// Ces tests mesurent donc deux choses à la fois : que la phrase est bien là,
/// et qu'elle n'a rien poussé dehors. Mesures faites sur les `frame`
/// d'accessibilité, jamais sur des captures — en paysage le simulateur rend
/// une image tournée dans un cadre resté portrait (piège documenté).
final class CoachExplanationUITests: XCTestCase {

    /// Mat du berger : la partie complète la plus courte qui contienne une
    /// vraie gaffe. `3...Nf6??` permet `4.Qxf7#`, donc la réfutation du moteur
    /// est un mat en un — le cas le moins ambigu qui soit pour l'explicateur.
    private let scholarsMate = "1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7#"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTheCoachExplainsABlunderAndStaysOnScreen() throws {
        let app = launchOnTheBlunder()

        let explanation = app.descendants(matching: .any)
            .matching(identifier: "coachExplanation").firstMatch
        XCTAssertTrue(
            explanation.waitForExistence(timeout: 90),
            "une gaffe doit être expliquée, pas seulement étiquetée"
        )
        // La phrase EXACTE dépend du moteur ; ce qui doit tenir, c'est qu'il y
        // en ait une et qu'elle dise quelque chose.
        XCTAssertFalse(explanation.label.isEmpty, "l'explication ne doit pas être vide")
        print("EXPLICATION|\(explanation.label)")

        assertCoachBarFitsOnScreen(in: app, context: "portrait")
    }

    /// Le cas qui a déjà cassé : colonne gauche de l'iPad en paysage, sans
    /// défilement possible. `ViewThatFits` doit y retomber sur la barre d'une
    /// ligne plutôt que déborder — le test n'exige donc PAS la phrase ici,
    /// il exige que rien ne sorte de l'écran.
    @MainActor
    func testTheCoachBarStaysOnScreenInLandscape() throws {
        let app = launchOnTheBlunder()

        // La condition de saut vient AVANT l'attente du bandeau, et l'ordre
        // compte. Sur iPhone ce test ne mesure rien — il se saute — mais il
        // attendait d'abord jusqu'à 90 s l'apparition du bandeau, uniquement
        // pour le jeter. Le 16/08 cette attente a fini par expirer alors que
        // les cinq classes tournaient d'affilée : le bandeau met ~5 s seul et
        // avait dépassé 90 s sous charge. Un échec rouge pour une mesure qui
        // n'aurait de toute façon pas eu lieu.
        //
        // Aucune couverture n'est perdue : l'existence du bandeau en portrait
        // est vérifiée par ``testTheCoachExplainsABlunderAndStaysOnScreen``,
        // qui tourne sur le même appareil.
        let traits = try LayoutProbe.traits(in: app)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "regular",
            "L'iPhone est verrouillé en portrait : la mesure paysage n'a de sens que sur iPad"
        )

        let coachBar = app.descendants(matching: .any).matching(identifier: "coachBar").firstMatch
        XCTAssertTrue(coachBar.waitForExistence(timeout: 90), "le bandeau coach doit exister")

        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscape = try LayoutProbe.traits(in: app, waitingForLandscape: true)
        try XCTSkipUnless(landscape.isLandscape, "la rotation n'a pas été appliquée")

        assertCoachBarFitsOnScreen(in: app, context: "paysage")
        LayoutProbe.assertNoHorizontalOverflow(in: app, context: "bandeau coach en paysage")
    }

    // MARK: Outils

    /// Le bandeau doit tenir dans la fenêtre, verticalement comme
    /// horizontalement. La mesure est tracée même quand le test passe : c'est
    /// elle qui documente la marge réelle, pas le verdict.
    @MainActor
    private func assertCoachBarFitsOnScreen(in app: XCUIApplication, context: String) {
        let coachBar = app.descendants(matching: .any).matching(identifier: "coachBar").firstMatch
        XCTAssertTrue(coachBar.exists, "le bandeau coach doit être à l'écran (\(context))")
        let bar = coachBar.frame
        let window = app.frame

        print(String(
            format: "COACH|%@|y=[%.1f…%.1f]|hauteur=%.1f|fenêtre=[%.1f…%.1f]",
            context, bar.minY, bar.maxY, bar.height, window.minY, window.maxY
        ))

        // 0,5 pt de tolérance : les arrondis de rendu, comme dans ``LayoutProbe``.
        XCTAssertLessThanOrEqual(
            bar.maxY, window.maxY + 0.5,
            "le bandeau coach passe sous le bord de l'écran (\(context))"
        )
        XCTAssertGreaterThanOrEqual(
            bar.minY, window.minY - 0.5,
            "le bandeau coach dépasse par le haut (\(context))"
        )
    }

    /// Importe le mat du berger, puis se place sur la gaffe `3...Nf6`.
    @MainActor
    private func launchOnTheBlunder() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        // Bouton sur iPhone, ligne de barre latérale sur iPad.
        let entry = app.buttons["Analyser"]
        if entry.waitForExistence(timeout: 10) {
            entry.tap()
        } else if app.cells["Analyser"].waitForExistence(timeout: 3) {
            app.cells["Analyser"].tap()
        } else {
            app.staticTexts["Analyser"].tap()
        }

        XCTAssertTrue(app.buttons["Autres sources"].waitForExistence(timeout: 10))
        app.buttons["Autres sources"].tap()
        XCTAssertTrue(app.buttons["Analyser PGN / FEN"].waitForExistence(timeout: 10))
        app.buttons["Analyser PGN / FEN"].tap()

        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(scholarsMate)
        app.buttons["Lancer l'analyse"].tap()
        XCTAssertTrue(
            app.otherElements["square_e4"].waitForExistence(timeout: 25),
            "le plateau doit s'afficher"
        )

        // La pastille du ruban de coups porte le SAN francisé, suivi du suffixe
        // d'annotation une fois le coup classé (« Cf6 » puis « Cf6?? ») : on
        // vise donc par PRÉFIXE, ce qui rend le test indépendant du verdict
        // exact du moteur.
        let chip = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Cf6")
        ).firstMatch
        XCTAssertTrue(
            chip.waitForExistence(timeout: 60),
            "le coup 3...Cf6 doit apparaître dans le ruban de coups"
        )
        chip.tap()
        return app
    }
}
