import UIKit
import XCTest

/// Lot 2 — l'iPhone reste en portrait, l'iPad garde ses quatre orientations.
///
/// Le paysage iPhone n'était adapté nulle part : `verticalSizeClass` n'est lu
/// dans aucun fichier du projet, et les seuls `GeometryReader` qui comparent
/// largeur et hauteur sont enfermés dans des branches
/// `horizontalSizeClass == .regular`, inatteignables sur iPhone standard. Le
/// verrou fait disparaître la classe de bugs en attendant un vrai layout
/// paysage.
///
/// Le test s'appuie sur les `frame` — jamais sur une capture d'écran : en
/// paysage le simulateur rend l'app tournée à 90° dans un cadre resté
/// portrait (piège documenté dans `PROGRESS.md`).
@MainActor
final class OrientationLockUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()
        return app
    }

    /// Sur iPhone, demander le paysage ne doit rien changer : la fenêtre
    /// reste plus haute que large.
    @MainActor
    func testIPhoneStaysPortraitAfterRotationRequest() throws {
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .phone,
            "Verrou spécifique à l'iPhone — l'iPad garde ses quatre orientations"
        )

        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        let before = try LayoutProbe.traits(in: app, waitingForLandscape: false)
        XCTAssertFalse(before.isLandscape)

        XCUIDevice.shared.orientation = .landscapeLeft
        // Laisser au système le temps d'appliquer (ou de refuser) la rotation.
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        let after = try LayoutProbe.traits(in: app)

        XCTAssertFalse(
            after.isLandscape,
            "l'app doit rester en portrait malgré la demande de rotation (mesuré : \(after.raw))"
        )
        XCTAssertEqual(
            after.size, before.size,
            "la fenêtre ne doit pas changer de dimensions"
        )

        XCUIDevice.shared.orientation = .portrait
    }

    /// Sur iPad, au contraire, la rotation DOIT fonctionner : l'app supporte
    /// le multitâche (pas de `UIRequiresFullScreen`) et Split View l'exige.
    @MainActor
    func testIPadStillRotates() throws {
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "Contrôle réservé à l'iPad"
        )

        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        let portrait = try LayoutProbe.traits(in: app, waitingForLandscape: false)
        XCTAssertFalse(portrait.isLandscape)

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = try LayoutProbe.traits(in: app, waitingForLandscape: true)
        XCTAssertTrue(
            landscape.isLandscape,
            "l'iPad doit continuer de tourner (mesuré : \(landscape.raw))"
        )

        XCUIDevice.shared.orientation = .portrait
    }
}
