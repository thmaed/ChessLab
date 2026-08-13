import UIKit
import XCTest

/// Relevé des traits de mise en page (Lot 0.1) — ce test ne juge rien, il
/// **mesure** : classes de taille, taille de fenêtre et encoches, en portrait
/// puis en paysage, sur l'appareil où il tourne.
///
/// Chaque relevé est imprimé sous la forme `TRAITS|appareil|orientation|…`,
/// récupérable dans la sortie `xcodebuild` pour construire le tableau de
/// `PROGRESS.md`. On mesure au lieu de supposer : l'hypothèse « les iPhone
/// Plus / Pro Max passent en `horizontalSizeClass == .regular` en paysage »
/// conditionne tout le diagnostic du Lot 1, elle ne peut pas rester une
/// croyance.
final class LayoutTraitsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// Nom de l'appareil simulé — pour étiqueter le relevé.
    private var deviceName: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.name
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()
        return app
    }

    /// Portrait ET paysage dans le même test : relancer l'app entre les deux
    /// coûterait deux fois le temps de démarrage, et la rotation est de toute
    /// façon le geste qu'on veut observer.
    @MainActor
    func testReportSizeClasses() throws {
        let device = deviceName
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()

        let portrait = try LayoutProbe.traits(in: app, waitingForLandscape: false)
        print(portrait.logLine(device: device, orientation: "portrait"))
        XCTAssertFalse(portrait.isLandscape, "L'app devrait démarrer en portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = try LayoutProbe.traits(in: app, waitingForLandscape: true)
        print(landscape.logLine(device: device, orientation: "paysage"))

        // Le verrou portrait (Lot 2) rendra ce relevé identique au précédent
        // sur iPhone : c'est une mesure, pas une exigence — on l'imprime.
        print("TRAITS-ROTATION|\(device)|effective=\(landscape.isLandscape)")

        XCUIDevice.shared.orientation = .portrait
    }

    /// Taille du plateau en portrait — le garde-fou de qualité du portrait
    /// iPhone (Lot 5.3) a besoin de connaître le ratio réellement obtenu
    /// avant de fixer un seuil.
    @MainActor
    func testReportBoardGeometry() throws {
        let device = deviceName
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        let traits = try LayoutProbe.traits(in: app, waitingForLandscape: false)

        try openVsEngineGame(in: app)

        guard let rect = LayoutProbe.boardRect(in: app) else {
            XCTFail("Plateau introuvable (square_a8 / square_h1)")
            return
        }
        let side = min(rect.width, rect.height)
        let ratioToWidth = side / traits.usableWidth
        let ratioToMinSide = side / min(traits.size.width, traits.size.height)
        print(
            String(
                format: "BOARD|%@|portrait|side=%.1f|window=%.1fx%.1f|usableWidth=%.1f|ratioWidth=%.3f|ratioMin=%.3f",
                device, side, traits.size.width, traits.size.height,
                traits.usableWidth, ratioToWidth, ratioToMinSide
            )
        )
    }

    /// Inventaire des débordements sur l'accueil et sur l'écran de partie :
    /// diagnostic pur, imprimé et non assertif — les tests de non-régression
    /// (Lot 5) viendront ensuite, une fois les corrections faites.
    @MainActor
    func testReportOverflowsOnMainScreens() throws {
        let device = deviceName
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        _ = app.staticTexts["ChessLab"].waitForExistence(timeout: 10)

        report(LayoutProbe.horizontalOverflows(in: app), screen: "accueil", device: device)

        try openVsEngineGame(in: app)
        report(LayoutProbe.horizontalOverflows(in: app), screen: "jouer", device: device)
    }

    @MainActor
    private func report(_ overflows: [LayoutProbe.Overflow], screen: String, device: String) {
        if overflows.isEmpty {
            print("OVERFLOW|\(device)|\(screen)|aucun")
            return
        }
        for overflow in overflows {
            print("OVERFLOW|\(device)|\(screen)|\(overflow)")
        }
    }

    // MARK: Navigation

    /// Ouvre une partie contre l'ordinateur, quelle que soit l'ossature.
    ///
    /// Le libellé est le même dans les deux, mais **pas le type d'élément** :
    /// la grille de modes (compact) expose un `Button`, la barre latérale
    /// (regular) une ligne de `List` qu'XCUITest remonte en `staticText` — un
    /// relevé sur iPad Pro 11" est tombé faute de chercher les trois formes.
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
        _ = app.otherElements["square_a8"].waitForExistence(timeout: 15)
    }
}
