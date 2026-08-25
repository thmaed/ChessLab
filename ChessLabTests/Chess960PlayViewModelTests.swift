import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// La mécanique de partie du mode Chess960 — tout ce qui vit SANS moteur :
/// journal de coups, fins de partie (dont la répétition, qui n'appartient
/// qu'au view model — le compteur de ChessKit ne survit pas à un roque),
/// consultation, « Reprendre ici » avec ses gardes du 24/08, export PGN.
@MainActor
struct Chess960PlayViewModelTests {

    /// Partie sur la position classique (518) : les coups s'écrivent en clair.
    /// `start()` n'est jamais appelé — aucun moteur ne démarre, le view model
    /// reste purement mécanique. L'utilisateur joue les DEUX camps via
    /// `commit`, ce que permet le journal UCI.
    private func classicalGame() -> Chess960PlayViewModel {
        var settings = Chess960Settings()
        settings.positionNumber = 518
        return Chess960PlayViewModel(settings: settings)
    }

    /// Joue une suite d'UCI en court-circuitant le tour moteur (le moteur
    /// n'étant pas démarré, `enqueueEngineWork` s'exécute dans le vide).
    private func play(_ uci: [String], on vm: Chess960PlayViewModel) {
        for move in uci {
            let before = vm.totalPlies
            vm.forceMove(uci: move)
            #expect(vm.totalPlies == before + 1, "\(move) refusé")
        }
    }

    @Test("Le journal tient SAN et UCI en parallèle, roque compris")
    func logsKeepSANAndUCIInStep() {
        let vm = classicalGame()
        play(["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "e1h1"], on: vm)
        #expect(vm.sanLog.last == "O-O")
        #expect(vm.numberedMoves.count == 4)
        #expect(vm.numberedMoves[3].white == "O-O")
    }

    @Test("La nulle par répétition est vue par le view model")
    func repetitionDrawIsDetected() {
        let vm = classicalGame()
        // Navette cavaliers : la position initiale revient deux fois — sa
        // troisième occurrence (la position de départ comptant pour une).
        play(["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1"], on: vm)
        #expect(vm.outcome == nil, "deux occurrences seulement : pas encore nulle")
        vm.forceMove(uci: "f6g8")
        #expect(vm.outcome == GameOutcome(winner: nil, reason: .draw(.repetition)))
    }

    @Test("Reprendre ici agit, s'annule, et respecte les gardes du 24/08")
    func resumeHereFollowsThe24AugustPattern() {
        let vm = classicalGame()
        play(["e2e4", "e7e5", "g1f3", "b8c6", "f1c4"], on: vm)

        vm.review(toPly: 2)
        #expect(vm.canResumeFromReview)
        vm.resumeFromReview()
        #expect(vm.totalPlies == 2)
        #expect(vm.resumeUndo?.discardedCount == 3)

        vm.cancelResumeFromReview()
        #expect(vm.totalPlies == 5, "l'annulation rend les coups écartés")
        #expect(vm.sanLog.last == "Bc4")
        #expect(vm.resumeUndo == nil)

        // Le garde : une partie finie ne se ressuscite pas.
        vm.review(toPly: 2)
        vm.resumeFromReview()
        vm.userResigns()
        #expect(vm.outcome != nil)
        vm.cancelResumeFromReview()
        #expect(vm.outcome != nil, "l'abandon survit à l'annulation")
        #expect(vm.totalPlies == 2)
    }

    @Test("La reprise de coup retire la paire moteur+joueur")
    func takebackRemovesThePair() {
        let vm = classicalGame()   // utilisateur = blancs, moteur = noirs
        play(["e2e4", "e7e5", "g1f3"], on: vm)
        #expect(vm.canTakeback)
        vm.takeback()
        // Le dernier coup est BLANC (utilisateur) : un seul demi-coup retiré.
        #expect(vm.totalPlies == 2)
        vm.forceMove(uci: "g1f3")
        vm.forceMove(uci: "b8c6")
        // Le dernier coup est NOIR (moteur) : la paire est retirée.
        vm.takeback()
        #expect(vm.totalPlies == 2)
    }

    @Test("Le PGN exporté porte les tags de la variante")
    func pgnCarriesVariantTags() {
        let vm = classicalGame()
        play(["e2e4", "e7e5"], on: vm)
        let pgn = vm.exportedPGN
        #expect(pgn.contains("[Variant \"Chess960\"]"))
        #expect(pgn.contains("[SetUp \"1\"]"))
        #expect(pgn.contains("[FEN \"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w HAha - 0 1\"]"))
        #expect(pgn.contains("1. e4 e5"))
    }

    // MARK: Régression du 25/08 — moteur RÉEL

    /// LE test qui aurait attrapé le défaut signalé : « après le premier
    /// coup blanc, l'ordinateur ne joue jamais, l'app freeze ».
    ///
    /// Cause : ``Chess960PlayViewModel/updateEvalBar()`` appelait
    /// `EngineController.computeBestMove`, l'API à LECTEUR PERMANENT réservée
    /// au Laboratoire. Elle démarre une tâche de fond qui consomme
    /// `responseStream` pour toujours ; ``requestEngineMove`` lit ce même
    /// flux à la main, comme partout ailleurs — deux lecteurs sur un flux à
    /// consommateur unique. Dès que la barre d'éval s'affiche une fois avant
    /// le premier coup moteur (le cas où l'utilisateur joue les blancs :
    /// `start()` l'affiche AVANT tout coup), le `synchronize()` du coup
    /// moteur suivant heurte l'assertion qui garde cette discipline.
    ///
    /// Ce test utilise le moteur RÉEL (pas `forceMove`) : c'est précisément
    /// la communication moteur qui était en cause, un test purement
    /// mécanique ne pouvait pas la voir — comme les 6 tests ci-dessus, tous
    /// verts, n'ont rien vu.
    // Marge LARGE et pas resserrée : ce test démarre un vrai Stockfish, et
    // quand la suite complète tourne, les bancs d'essai moteur (Classification
    // Drift, Engine Search Budget) monopolisent le même process partagé — même
    // constat, même remède que ``GameClockStartTests`` (voir son commentaire).
    // Ce que ce test attrape n'a de toute façon pas besoin de délai précis :
    // le défaut qu'il vise fait TRAPPER le process (assertion), pas juste
    // traîner — un faux positif par lenteur serait bien pire qu'une marge
    // généreuse.
    @Test("Avec la barre d'éval activée, l'ordinateur répond après le premier coup")
    func engineRepliesAfterFirstMoveWithEvalBarEnabled() async throws {
        var settings = Chess960Settings()
        settings.positionNumber = 518
        settings.showEvalBar = true
        let vm = Chess960PlayViewModel(settings: settings)
        vm.start()

        // Laisser le moteur démarrer et afficher l'éval initiale — c'est
        // CE geste qui empoisonnait l'instance avant le correctif.
        try await Task.sleep(for: .seconds(3))

        vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
        try #require(vm.totalPlies >= 1, "le coup utilisateur doit tenir")

        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline, vm.totalPlies < 2 {
            try await Task.sleep(for: .milliseconds(200))
        }
        #expect(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu — moteur gelé")

        vm.handleViewDisappear()
    }

    @Test("Le dernier coup se surligne, roque compris — sur la case RÉELLE du roi")
    func lastMoveHighlightsTheKingsRealDestination() {
        let vm = classicalGame()
        play(["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"], on: vm)

        // Coup ordinaire : les cases affichées sont celles de l'UCI.
        var last = try! #require(vm.displayedLastMove)
        #expect(last.start == Square("f8") && last.end == Square("c5"),
                "dernier coup joué : Fc5 (par les noirs, depuis f8)")

        // Roque : l'UCI moteur (dialecte roi-prend-tour) dit e1h1, mais la
        // case AFFICHÉE doit être g1 — celle où le roi atterrit vraiment —
        // pas h1, où se tenait la tour.
        play(["e1h1"], on: vm)
        last = try! #require(vm.displayedLastMove)
        #expect(last.start == Square("e1"))
        #expect(last.end == Square("g1"), "pas h1 (la tour) : g1, la case RÉELLE du roi")
    }

    @Test("La surbrillance suit la consultation, pas seulement le direct")
    func lastMoveFollowsReviewNotJustLiveGame() {
        let vm = classicalGame()
        play(["e2e4", "e7e5", "g1f3"], on: vm)

        vm.review(toPly: 1)
        let reviewed = try! #require(vm.displayedLastMove)
        #expect(reviewed.start == Square("e2") && reviewed.end == Square("e4"),
                "en consultation du 1er coup, c'est LUI qu'on surligne, pas le dernier joué")

        vm.review(toPly: 0)
        #expect(vm.displayedLastMove == nil, "position de départ : rien à surligner")
    }

    @Test("Le geste de roque du roi expose les cases des tours")
    func kingTargetsIncludeOwnRooks() {
        var settings = Chess960Settings()
        settings.positionNumber = 518
        let vm = Chess960PlayViewModel(settings: settings)
        play(["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"], on: vm)
        vm.selectSquare(Square("e1"))
        #expect(vm.legalTargetSquares.contains(Square("h1")),
                "la tour h1 doit être une cible : c'est le geste roi-prend-tour")
    }
}
