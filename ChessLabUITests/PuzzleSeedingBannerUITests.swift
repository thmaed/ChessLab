import XCTest

/// Le bandeau « Préparation de la bibliothèque de puzzles… » : retour du 16/11/2026 sur iPad, une roulette plus
/// de la moitié du temps avant que la barre ne parte. Désormais la barre est là DÈS que le bandeau paraît, et elle
/// avance — y compris pendant la relecture d'une bibliothèque existante (une mise à jour, simulée ici par le
/// crochet de débogage `-reseedPuzzles`).
@MainActor
final class PuzzleSeedingBannerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheBarIsThereFromTheStart_andMoves() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen", "-AppleLanguages", "(fr)", "-reseedPuzzles"]
        app.launch()

        let title = app.staticTexts["Préparation de la bibliothèque de puzzles…"]
        XCTAssertTrue(title.waitForExistence(timeout: 90), "le bandeau doit paraître")
        let bar = app.progressIndicators["seedingProgress"]
        XCTAssertTrue(bar.exists, "la barre doit être là dès l'apparition du bandeau, sans roulette")
        let first = percent(bar)

        // Elle avance (le crochet ralentit les insertions d'une seconde par lot pour qu'on la voie).
        var latest = first
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, bar.exists, latest <= first {
            RunLoop.current.run(until: Date().addingTimeInterval(1))
            if bar.exists { latest = percent(bar) }
        }
        XCTAssertGreaterThan(latest, first, "la barre doit avancer (\(first) % → \(latest) %)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "bandeau-preparation"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// « 42 % » → 42.
    private func percent(_ bar: XCUIElement) -> Int {
        let digits = (bar.value as? String ?? "").filter(\.isNumber)
        return Int(digits) ?? 0
    }
}
