import XCTest

/// Les quatre poignées du recadrage manuel se traînent au doigt.
///
/// Depuis le 23/10/2026, elles ne portent plus de geste : l'image entière en
/// porte un, qui saisit le coin le plus proche (même principe que le
/// recadrage Android). Placées par `.offset`, les poignées avaient en iOS 18
/// le défaut des pièces de l'échiquier : leurs cadres s'empilaient à
/// l'origine de l'image, où le toucher était avalé.
///
/// Une image SANS échiquier (un avatar) force l'étape de recadrage manuel :
/// la détection échoue et propose un cadre en retrait de 10 %.
@MainActor
final class CropHandleDragUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEveryCropHandleFollowsTheFinger() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings", "-discoveryTourSeen", "-scanTestImage", "avatar_maia"]
        app.launch()

        XCTAssertTrue(app.buttons["Analyser"].waitForExistence(timeout: 5))
        app.buttons["Analyser"].tap()
        XCTAssertTrue(app.buttons["Scanner une position"].waitForExistence(timeout: 5))
        app.buttons["Scanner une position"].tap()

        for name in ["topLeft", "topRight", "bottomRight", "bottomLeft"] {
            let handle = app.otherElements["cropHandle_\(name)"]
            XCTAssertTrue(handle.waitForExistence(timeout: 15), "la poignée \(name) doit s'afficher")
            let before = handle.frame
            // Vers le CENTRE de l'image, pour rester dedans quel que soit le coin.
            let dx: CGFloat = name.hasSuffix("Left") ? 30 : -30
            let dy: CGFloat = name.hasPrefix("top") ? 30 : -30
            let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)))

            let after = handle.frame
            XCTAssertGreaterThan(
                abs(after.midX - before.midX) + abs(after.midY - before.midY), 20,
                "la poignée \(name) doit avoir suivi le doigt — avant \(before), après \(after)"
            )
        }
    }
}
