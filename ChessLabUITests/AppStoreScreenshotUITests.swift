import UIKit
import XCTest

/// Capture des visuels App Store Connect (accueil + partie en cours), sur
/// simulateur, en français ET en anglais. Pas un test de régression : lancé
/// à la demande pour la préparation de soumission, jamais dans la suite
/// verte habituelle.
///
/// `-AppleLanguages` force la langue « système » indépendamment de la
/// locale du Mac hôte : ``AppLanguage/system`` lit `Locale.preferredLanguages`
/// (voir `AppSettings.swift`), donc ce réglage de lancement suffit sans
/// toucher aux réglages in-app.
///
/// Écrit directement sur le disque hôte (le processus de test XCUITest
/// tourne côté Mac, pas dans le bac à sable de l'app) sous
/// `/tmp/cl-appstore-screenshots/<idiom>/<langue>/`.
final class AppStoreScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshotsFrench() throws {
        try capture(appleLanguageCode: "fr", folder: "fr")
    }

    @MainActor
    func testCaptureAppStoreScreenshotsEnglish() throws {
        try capture(appleLanguageCode: "en", folder: "en")
    }

    @MainActor
    private func capture(appleLanguageCode: String, folder: String) throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-resetPlaySettings",
            "-AppleLanguages", "(\(appleLanguageCode))",
            "-AppleLocale", appleLanguageCode == "fr" ? "fr_FR" : "en_US",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["ChessLab"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        save(app.screenshot(), folder: folder, name: "01-accueil")

        let playButtonLabel = appleLanguageCode == "fr" ? "Contre Stockfish" : "Against Stockfish"
        let startButtonLabel = appleLanguageCode == "fr" ? "Commencer" : "Start"
        XCTAssertTrue(app.buttons[playButtonLabel].waitForExistence(timeout: 5))
        app.buttons[playButtonLabel].tap()
        XCTAssertTrue(app.buttons[startButtonLabel].waitForExistence(timeout: 5))
        app.buttons[startButtonLabel].tap()

        XCTAssertTrue(app.otherElements["square_e2"].waitForExistence(timeout: 10))
        app.otherElements["square_e2"].tap()
        app.otherElements["square_e4"].tap()

        let moveCountMarker = app.otherElements["moveCount"]
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, moveCountMarker.value as? String != "2" {
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        save(app.screenshot(), folder: folder, name: "02-partie")
    }

    private func save(_ screenshot: XCUIScreenshot, folder: String, name: String) {
        let idiom = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        let dir = "/tmp/cl-appstore-screenshots/\(idiom)/\(folder)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
