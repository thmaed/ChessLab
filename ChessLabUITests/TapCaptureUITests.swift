import XCTest

/// Prendre une pièce ADVERSE au tap-tap — toucher sa pièce, puis la case de la
/// pièce à prendre.
///
/// 🐛 24/10/2026, iPhone XS en iOS 18.7.9 : la seconde frappe était avalée par
/// la pièce adverse (son survol, posé après sa transparence au toucher, la
/// rendait de nouveau touchable). Seul le glisser prenait. Invisible en iOS 26,
/// donc sur nos simulateurs : à lancer sur un appareil iOS 18.
///
/// Le puzzle déterministe 00008 commence justement par une prise : Txe7.
///
/// - important: PAS de `-resetPlaySettings` — ce test tourne sur l'iPhone réel.
@MainActor
final class TapCaptureUITests: XCTestCase {

    func testCapturingByTapTapWorks() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-uiTestDeterministicPuzzles", "-openRoute", "puzzleSession"]
        app.launch()

        let e6 = app.otherElements["square_e6"]
        let e7 = app.otherElements["square_e7"]
        XCTAssertTrue(e6.waitForExistence(timeout: 20))
        XCTAssertTrue(e7.label.lowercased().contains("noir") || e7.label.lowercased().contains("black"),
                      "une tour noire doit attendre en e7 (lu : \(e7.label))")

        e6.tap()
        e7.tap()

        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, !(e6.label.lowercased().contains("vide") || e6.label.lowercased().contains("empty")) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(e6.label.lowercased().contains("vide") || e6.label.lowercased().contains("empty"),
                      "la tour blanche doit avoir quitté e6 (lu : \(e6.label))")
        XCTAssertTrue(e7.label.lowercased().contains("blanc") || e7.label.lowercased().contains("white"),
                      "Txe7 : la tour blanche doit être en e7 (lu : \(e7.label))")
    }
}
