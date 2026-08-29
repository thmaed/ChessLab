import ChessKit
import CStockfishKit
import Foundation
import Testing
@testable import ChessLab

/// Le Duck Chess FACE À L'ORDINATEUR : ce que la partie journalise, ce
/// qu'elle sait défaire, et ce que le moteur en fait.
///
/// `.serialized` — les tests qui démarrent un moteur réel se le partagent
/// (voir ``EngineIntegrationGate``).
@Suite(.serialized)
@MainActor
struct DuckChessEngineTurnTests {

    private func game(
        color: PlayerColorChoice = .white, versusEngine: Bool = true, evalBar: Bool = false
    ) -> DuckChessViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = color.rawValue
        settings.eloSliderValue = 1400
        // Éteinte par défaut ICI : les tests mécaniques n'ont pas besoin de
        // la salve moteur qu'elle déclenche à chaque position — même
        // discipline que les autres suites de variantes.
        settings.showEvalBar = evalBar
        settings.blunderAlertEnabled = false
        return DuckChessViewModel(settings: settings, versusEngine: versusEngine)
    }

    /// Joue un tour COMPLET (coup puis canard) par sélections successives.
    private func playTurn(_ vm: DuckChessViewModel, _ from: String, _ to: String, duck: String) {
        vm.selectSquare(Square(from))
        vm.selectSquare(Square(to))
        vm.selectSquare(Square(duck))
    }

    /// Joue un tour QUELCONQUE mais légal, canard compris.
    ///
    /// Écrire le coup en dur ne marche pas face à l'ordinateur : il pose son
    /// canard là où il gêne le plus, c'est-à-dire précisément sur la case
    /// d'arrivée du coup qu'il vous prête. Un test qui insiste sur `d2d4`
    /// échoue le jour où le canard s'y trouve — ce qui est le comportement
    /// VOULU, pas une panne.
    @discardableResult
    private func playAnyTurn(_ vm: DuckChessViewModel) -> Bool {
        let moves = DuckChessRules.moves(in: vm.position, duck: vm.duckSquare)
        guard let move = moves.first(where: { $0.promotion == nil }) else { return false }
        vm.attemptUserMove(from: move.from, to: move.to)
        guard vm.phase == .placeDuck else { return false }
        guard let square = DuckChessRules.duckTargets(
            in: vm.position, currentDuck: vm.duckSquare
        ).first else { return false }
        vm.selectSquare(square)
        return vm.phase == .movePiece
    }

    /// Attend la fin du tour de l'ordinateur — pas son COUP : `totalPlies`
    /// avance dès le déplacement, alors que le canard reste à poser.
    private func waitForEngineTurn(_ vm: DuckChessViewModel, seconds: Double = 30) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline, vm.sideToMove != vm.userColor || vm.phase == .placeDuck {
            try await Task.sleep(for: .milliseconds(200))
        }
    }

    // MARK: Ce que Stockfish a le droit de voir

    @Test("La position de départ est légale aux yeux des échecs ordinaires")
    func startIsStandardLegal() {
        let start = Position(fen: DuckChessViewModel.startFEN)!
        #expect(DuckChessRules.isStandardLegal(start))
    }

    @Test("Un roi laissé en prise rend la position illégale POUR LE MOTEUR")
    func abandonedKingIsIllegalForTheEngine() {
        // Trait aux Noirs, et la tour blanche e7 attaque le roi noir e8 : les
        // Noirs peuvent le sauver, la position reste légale.
        let defensible = Position(fen: "4k3/4R3/8/8/8/8/8/4K3 b - - 0 1")!
        #expect(DuckChessRules.isStandardLegal(defensible))

        // Trait aux BLANCS, même tour : le roi noir est prenable alors que
        // ce n'est pas à lui de jouer — normal en Duck Chess, illégal aux
        // échecs. Stockfish ne doit jamais recevoir ça.
        let prenable = Position(fen: "4k3/4R3/8/8/8/8/8/4K3 w - - 0 1")!
        #expect(!DuckChessRules.isStandardLegal(prenable))
    }

    @Test("Une position sans roi n'est jamais envoyée au moteur")
    func missingKingIsIllegal() {
        let noBlackKing = Position(fen: "8/4R3/8/8/8/8/8/4K3 b - - 0 1")!
        #expect(!DuckChessRules.isStandardLegal(noBlackKing))
    }

    @Test("Le trait se retourne sans rien déplacer")
    func flippingSideToMoveKeepsThePieces() throws {
        let start = Position(fen: DuckChessViewModel.startFEN)!
        let flipped = try #require(DuckChessEngine.sideToMoveFlipped(start))
        #expect(flipped.sideToMove == .black)
        #expect(flipped.pieces.count == start.pieces.count)
        #expect(flipped.piece(at: Square("e2"))?.kind == .pawn)
    }

    /// Le mot-clé `searchmoves` avale TOUT ce qui le suit (`uci.cpp` :
    /// « Needs to be the last command on the line »). Placé ailleurs qu'en
    /// fin de ligne, il mangeait la limite de temps : la recherche partait
    /// sans budget et seul le chien de garde l'arrêtait, deux secondes plus
    /// tard. Ce test garde l'ordre.
    @Test("`searchmoves` est la DERNIÈRE clause de la commande `go`")
    func searchmovesComesLast() {
        let command = EngineCommand.go(movetime: 400, searchmoves: ["e2e4", "d2d4"])
        #expect(command.uciString == "go movetime 400 searchmoves e2e4 d2d4")

        let byDepth = EngineCommand.go(depth: 6, searchmoves: ["e2e4"])
        #expect(byDepth.uciString == "go depth 6 searchmoves e2e4")

        // Sans liste, la commande ne change pas d'un iota.
        #expect(EngineCommand.go(movetime: 400).uciString == "go movetime 400")
    }

    // MARK: Les journaux

    @Test("Un tour complet remplit les cinq journaux, d'une seule ligne")
    func oneTurnAppendsOneLineEverywhere() {
        let vm = game(versusEngine: false)
        playTurn(vm, "e2", "e4", duck: "e5")

        #expect(vm.sanLog == ["e4@e5"], "la notation porte le coup ET le canard")
        #expect(vm.uciLog == ["e2e4"])
        #expect(vm.moveLog.count == 1)
        #expect(vm.fenLog.count == 2)
        #expect(vm.duckLog == [nil, Square("e5")])
        #expect(vm.enPassantLog == [nil, Square("e3")])
    }

    @Test("La FEN journalisée d'un tour fini a bien changé de trait")
    func loggedFENFlipsSideToMove() throws {
        let vm = game(versusEngine: false)
        vm.selectSquare(Square("e2")); vm.selectSquare(Square("e4"))
        // Coup joué, canard PAS encore posé : le trait ne doit pas avoir bougé.
        #expect(Position(fen: vm.fenLog[1])?.sideToMove == .white)

        vm.selectSquare(Square("e5"))
        let afterTurn = try #require(Position(fen: vm.fenLog[1]))
        #expect(afterTurn.sideToMove == .black, "la pose du canard clôt le tour")
    }

    // MARK: Reprendre un coup

    @Test("Reprendre un coup restitue EXACTEMENT le canard et la prise en passant")
    func takebackRestoresDuckAndEnPassant() {
        let vm = game(versusEngine: false)
        playTurn(vm, "e2", "e4", duck: "h6")
        playTurn(vm, "a7", "a5", duck: "h5")
        playTurn(vm, "e4", "e5", duck: "h4")
        playTurn(vm, "d7", "d5", duck: "h3")

        // La poussée double des Noirs ouvre la prise en passant en d6.
        vm.selectSquare(Square("e5"))
        #expect(vm.legalTargetSquares.contains(Square("d6")), "e5xd6 e.p. doit être offert")

        vm.takeback()
        #expect(vm.duckSquare == Square("h4"), "le canard revient où il était")
        #expect(vm.totalPlies == 3)
        vm.selectSquare(Square("e5"))
        #expect(!vm.legalTargetSquares.contains(Square("d6")), "la prise en passant a disparu avec le coup")
    }

    @Test("Reprendre depuis la consultation, puis annuler, rend la partie intacte")
    func resumeThenUndoRestoresEverything() {
        let vm = game(versusEngine: false)
        playTurn(vm, "e2", "e4", duck: "h6")
        playTurn(vm, "e7", "e5", duck: "h5")
        playTurn(vm, "g1", "f3", duck: "h4")
        let fullSan = vm.sanLog
        let fullFen = vm.fenLog
        let fullDucks = vm.duckLog

        vm.review(toPly: 1)
        #expect(vm.isReviewing)
        #expect(vm.displayedDuck == Square("h6"), "le plateau consulté montre le canard de l'époque")

        vm.resumeFromReview()
        #expect(vm.totalPlies == 1)
        #expect(vm.duckSquare == Square("h6"))
        #expect(vm.resumeUndo?.discardedCount == 2)

        vm.cancelResumeFromReview()
        #expect(vm.sanLog == fullSan)
        #expect(vm.fenLog == fullFen)
        #expect(vm.duckLog == fullDucks)
        #expect(vm.duckSquare == Square("h4"))
    }

    // MARK: La graine d'analyse

    @Test("La graine d'analyse est complète et alignée")
    func analysisSeedIsAligned() {
        let vm = game(versusEngine: false)
        playTurn(vm, "e2", "e4", duck: "h6")
        playTurn(vm, "e7", "e5", duck: "h5")
        let seed = vm.analysisSeed

        #expect(seed.sanLog.count == 2)
        #expect(seed.uciLog.count == 2)
        #expect(seed.moveLog.count == 2)
        #expect(seed.fenLog.count == 3, "une FEN par demi-coup, plus le départ")
        #expect(seed.duckLog.count == seed.fenLog.count)
        #expect(seed.enPassantLog.count == seed.fenLog.count)
        #expect(seed.startFEN == DuckChessViewModel.startFEN)
    }

    @Test("L'écran d'analyse rejoue le canard de chaque demi-coup")
    func analysisReplaysTheDuck() {
        let vm = game(versusEngine: false)
        playTurn(vm, "e2", "e4", duck: "h6")
        playTurn(vm, "e7", "e5", duck: "h5")

        let analysis = DuckChessAnalysisViewModel(seed: vm.analysisSeed)
        #expect(analysis.displayedPly == 0)
        #expect(analysis.displayedDuck == nil, "aucun canard n'est encore posé au départ")

        analysis.review(toPly: 1)
        #expect(analysis.displayedDuck == Square("h6"))
        analysis.review(toPly: 2)
        #expect(analysis.displayedDuck == Square("h5"))
        #expect(analysis.totalPlies == 2)
    }

    @Test("Le PGN exporté porte le canard à côté du coup")
    func exportedPGNCarriesTheDuck() {
        let vm = game(versusEngine: false)
        playTurn(vm, "e2", "e4", duck: "h6")
        #expect(vm.exportedPGN.contains("1. e4@h6"))
    }

    // MARK: L'utilisateur ne joue pas à la place de la machine

    @Test("Face à l'ordinateur, on ne touche pas aux pièces adverses")
    func userCannotMoveForTheEngine() {
        let vm = game(color: .black)   // l'utilisateur a les Noirs
        #expect(vm.engineColor == .white)
        vm.selectSquare(Square("e2"))
        #expect(vm.selectedSquare == nil, "les Blancs sont à l'ordinateur")
        #expect(vm.totalPlies == 0)
    }

    // MARK: Le moteur, pour de vrai

    @Test("L'ordinateur joue un tour ENTIER : son coup, puis son canard")
    func enginePlaysAWholeTurn() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))

            playTurn(vm, "e2", "e4", duck: "h6")
            try #require(vm.totalPlies == 1)

            // On attend la FIN du tour, pas le coup : `totalPlies` passe à 2
            // dès le déplacement, alors que le canard reste à poser. Attendre
            // le mauvais signal, c'est mesurer un tour à moitié joué.
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, vm.totalPlies < 2 || vm.phase == .placeDuck {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")
            #expect(vm.sideToMove == .white, "le canard posé, la main revient au joueur")
            #expect(vm.phase == .movePiece)
            let duck = vm.duckSquare
            #expect(duck != nil && duck != Square("h6"), "le canard a changé de case")
            #expect(vm.sanLog.last?.contains("@") == true, "le tour machine est journalisé en entier")

            vm.handleViewDisappear()
        }
    }

    @Test("La partie passe la main à l'analyse, qui classe la ligne")
    func handoffToAnalysisClassifiesTheGame() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))

            // Deux tours utilisateur, chacun suivi du tour machine complet.
            for _ in 0..<2 {
                try #require(self.playAnyTurn(vm), "le tour utilisateur doit aboutir")
                try await self.waitForEngineTurn(vm)
            }
            try #require(vm.totalPlies >= 3, "il faut une vraie ligne à classer")
            vm.resign(.white)
            let seed = vm.analysisSeed

            // LE passage de relais : un seul processus moteur à la fois.
            await vm.stopEngineBeforeAnalysis()

            let analysis = DuckChessAnalysisViewModel(seed: seed)
            analysis.start()
            let deadline = Date().addingTimeInterval(60)
            while Date() < deadline, analysis.isClassifying || analysis.moveQuality.isEmpty {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(!analysis.isEngineUnavailable, "le moteur d'analyse n'a pas démarré")
            // Pas `== sanLog.count` : un demi-coup dont la position est
            // illégale pour Stockfish reste volontairement sans pastille.
            #expect(!analysis.moveQuality.isEmpty, "la ligne n'a reçu aucune pastille")
            #expect(!analysis.isClassifying, "la passe de classification doit s'achever")

            analysis.review(toPly: 1)
            let evalDeadline = Date().addingTimeInterval(20)
            while Date() < evalDeadline, analysis.currentEvalCp == nil {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(analysis.currentEvalCp != nil, "la barre d'éval doit être renseignée")

            analysis.handleViewDisappear()
        }
    }

    @Test("L'indice propose un coup jouable")
    func hintOffersALegalMove() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.toggleHint()
            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline, vm.hintMoves.isEmpty {
                try await Task.sleep(for: .milliseconds(200))
            }
            let hint = try #require(vm.hintMoves.first, "aucun indice n'est arrivé")
            let legal = DuckChessRules.moves(in: vm.position, duck: vm.duckSquare)
            #expect(legal.contains { $0.from == hint.from && $0.to == hint.to })

            vm.handleViewDisappear()
        }
    }
}
