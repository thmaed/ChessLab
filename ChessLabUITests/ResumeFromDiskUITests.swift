import XCTest

/// Reprendre une partie dont l'autosauvegarde est DÉJÀ sur le disque (copiée de l'iPhone d'un joueur,
/// 27/10/2026 : l'app plantait à chaque reprise, dans Stockfish). Sans `-resetPlaySettings`, qui effacerait
/// l'autosauvegarde : le test est inerte tant qu'aucun fichier n'a été posé.
@MainActor
final class ResumeFromDiskUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    func testResumingAnAutosavedGameDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-discoveryTourSeen"]
        app.launch()
        let resume = app.buttons["resumeGame"]
        try XCTSkipUnless(resume.waitForExistence(timeout: 10), "aucune autosauvegarde sur ce simulateur")
        resume.tap()
        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 20))
        // Laisse le moteur recevoir sa position : c'est là que ça plantait.
        RunLoop.current.run(until: Date().addingTimeInterval(15))
        XCTAssertEqual(app.state, .runningForeground, "l'app ne doit pas être tombée")
        XCTAssertTrue(app.otherElements["square_e4"].exists)
    }
}
