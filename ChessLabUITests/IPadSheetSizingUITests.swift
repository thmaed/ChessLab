import XCTest

/// Lot 4.5 — la taille des feuilles modales sur iPad.
///
/// Une `.sheet` sans consigne s'ouvre en **form sheet** (~540×620) sur iPad.
/// C'est trop petit pour deux écrans que l'app y présente : l'éditeur de
/// position, dont le plateau est plafonné à 460 pt et qui cachait donc son
/// bouton de validation sous le pli, et le scanner, dont le recadrage à quatre
/// poignées est le geste le moins adapté à une petite fenêtre.
///
/// Contrairement au reste du Lot 4, ce n'est pas une affaire de goût : « le
/// bouton est-il visible sans défiler » se tranche à la mesure.
///
/// Les mesures sont imprimées même quand le test passe — c'est la marge réelle
/// qui documente, pas le verdict.
@MainActor
final class IPadSheetSizingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPositionEditorValidationButtonIsVisibleWhenTheSheetOpens() throws {
        let app = try launchOnIPad()

        try openVsComputer(in: app)
        NewGameSetupSteps.pick("Ouvrir l'éditeur", inMenu: "startMenu", app: app)

        // Le bouton de sortie de l'éditeur, en mode « picker » : c'est LUI qui
        // n'était jamais visible à l'ouverture.
        let validate = app.buttons["Utiliser cette position"]
        XCTAssertTrue(validate.waitForExistence(timeout: 10), "le bouton de validation doit exister")

        print(String(
            format: "FEUILLE|éditeur|bouton y=[%.1f…%.1f]|atteignable=%@|fenêtre=[%.1f…%.1f]",
            validate.frame.minY, validate.frame.maxY,
            validate.isHittable ? "oui" : "non",
            app.frame.minY, app.frame.maxY
        ))

        // « Visible sans défiler » = XCUITest peut le taper là où il est.
        XCTAssertTrue(
            validate.isHittable,
            "à l'ouverture de l'éditeur, « Utiliser cette position » doit être visible sans défiler"
        )
    }

    @MainActor
    func testScannerCropControlsFitInTheSheet() throws {
        let app = try launchOnIPad()

        try openVsComputer(in: app)
        NewGameSetupSteps.pick("Scanner", inMenu: "startMenu", app: app)

        // Le scanner s'ouvre sur son écran de choix de source ; ce qu'on
        // mesure ici, c'est la FEUILLE, pas le pipeline de reconnaissance.
        // « Annuler » est le seul élément garanti présent à toutes les étapes.
        let cancel = app.buttons["Annuler"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 15), "le scanner doit s'ouvrir")

        print(String(
            format: "FEUILLE|scanner|annuler x=%.1f y=%.1f|fenêtre=%.0fx%.0f",
            cancel.frame.maxX, cancel.frame.minY, app.frame.width, app.frame.height
        ))

        // C'est la HAUTEUR qui distingue les deux feuilles, pas la largeur : sur
        // un iPad mini en portrait, la form sheet par défaut fait déjà 540 pt
        // de large sur 744, donc plus de la moitié — un seuil en largeur ne
        // prouverait rien (mesuré : le test passait aussi SANS le correctif).
        //
        // Une form sheet fait ~620 pt de haut et se CENTRE : sur un écran de
        // 1133 pt elle commence donc vers 250 (mesuré : 250,5). Une feuille
        // « page » démarre près du bord haut (mesuré : 56,0).
        XCTAssertLessThan(
            cancel.frame.minY, app.frame.height * 0.12,
            "la feuille du scanner doit occuper la hauteur de l'écran, pas se centrer en petit"
        )
    }

    // MARK: Outils

    /// Sur iPad l'ossature est une `NavigationSplitView` : le mode est une
    /// LIGNE de barre latérale, pas un bouton de la grille d'accueil.
    @MainActor
    private func openVsComputer(in app: XCUIApplication) throws {
        for candidate in [
            app.buttons["Contre l'ordinateur"],
            app.cells["Contre l'ordinateur"],
            app.staticTexts["Contre l'ordinateur"]
        ] where candidate.waitForExistence(timeout: 5) {
            candidate.tap()
            return
        }
        throw LayoutProbeError.markerMissing("Contre l'ordinateur")
    }

    @MainActor
    private func launchOnIPad() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        let traits = try LayoutProbe.traits(in: app)
        try XCTSkipUnless(
            traits.horizontalSizeClass == "regular",
            "La form sheet n'existe que sur iPad ; sur iPhone une feuille est déjà pleine largeur"
        )
        return app
    }
}
