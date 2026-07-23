import XCTest

/// Depuis une position scannée/FEN, on doit pouvoir analyser coup par coup :
/// dérouler la meilleure ligne de Stockfish demi-coup par demi-coup, chaque
/// position proposant le meilleur coup du camp au trait. On pilote le VRAI
/// chemin de l'app et on lit le marqueur `analysisMoveCount`.
final class AnalysisStepThroughUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Régression : rejouer plusieurs demi-coups À LA MAIN fonctionne à chaque
    /// coup, pas seulement au premier (le symptôme rapporté).
    @MainActor
    func testSeveralManualHalfMovesFromAPosition() throws {
        let app = launchInAnalysis(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        let moveCount = app.otherElements["analysisMoveCount"]
        XCTAssertTrue(moveCount.waitForExistence(timeout: 5))
        XCTAssertEqual(moveCount.value as? String, "0")

        play(app, from: "e2", to: "e4")
        XCTAssertEqual(moveCount.value as? String, "1")
        play(app, from: "e7", to: "e5")
        XCTAssertEqual(moveCount.value as? String, "2")
        play(app, from: "g1", to: "f3")
        XCTAssertEqual(moveCount.value as? String, "3")
    }

    /// La fonctionnalité demandée : « Jouer le meilleur coup » déroule la
    /// meilleure ligne, coup par coup, plusieurs demi-coups d'affilée.
    @MainActor
    func testFollowBestLineFromWhiteToMovePosition() throws {
        let app = launchInAnalysis(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        followBestLine(app, halfMoves: 4)
    }

    /// Même chose depuis une position NOIRS au trait — le cas où ChessKit
    /// décale l'index de départ, historiquement fragile.
    @MainActor
    func testFollowBestLineFromBlackToMovePosition() throws {
        let app = launchInAnalysis(fen: "rnbqkbnr/pppppppp/8/8/8/4P3/PPPP1PPP/RNBQKBNR b KQkq - 0 1")
        followBestLine(app, halfMoves: 4)
    }

    // MARK: Helpers

    @MainActor
    private func launchInAnalysis(fen: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-resetPlaySettings"]
        app.launch()

        app.buttons["Analyser"].tap()
        XCTAssertTrue(app.buttons["Autres sources"].waitForExistence(timeout: 5))
        app.buttons["Autres sources"].tap()
        XCTAssertTrue(app.buttons["Position FEN"].waitForExistence(timeout: 5))
        app.buttons["Position FEN"].tap()

        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(fen)
        app.buttons["Lancer l'analyse"].tap()

        XCTAssertTrue(app.otherElements["square_e4"].waitForExistence(timeout: 20),
                      "le plateau doit s'afficher")
        return app
    }

    /// Tape « Jouer le meilleur coup » `halfMoves` fois, en vérifiant que le
    /// compteur de coups s'incrémente à chaque fois.
    @MainActor
    private func followBestLine(_ app: XCUIApplication, halfMoves: Int) {
        let moveCount = app.otherElements["analysisMoveCount"]
        XCTAssertTrue(moveCount.waitForExistence(timeout: 5))
        let best = app.buttons["playBestMove"]
        XCTAssertTrue(best.waitForExistence(timeout: 5))

        for expected in 1...halfMoves {
            // Le bouton s'active dès que l'analyse a produit un meilleur coup.
            XCTAssertTrue(waitUntilEnabled(best, timeout: 15),
                          "le meilleur coup doit être proposé (demi-coup \(expected))")
            best.tap()
            XCTAssertTrue(waitForValue(moveCount, equals: "\(expected)", timeout: 10),
                          "le demi-coup \(expected) doit être joué")
        }
    }

    @MainActor
    private func play(_ app: XCUIApplication, from: String, to: String) {
        let source = app.otherElements["square_\(from)"]
        XCTAssertTrue(source.waitForExistence(timeout: 5), "case \(from) absente")
        source.tap()
        app.otherElements["square_\(to)"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    }

    @MainActor
    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isEnabled { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return element.isEnabled
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, equals value: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.value as? String == value { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return element.value as? String == value
    }
}
