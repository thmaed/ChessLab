import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// La mécanique de partie du mode Chess960 — tout ce qui vit SANS moteur :
/// journal de coups, fins de partie (dont la répétition, qui n'appartient
/// qu'au view model — le compteur de ChessKit ne survit pas à un roque),
/// consultation, « Reprendre ici » avec ses gardes du 24/08, export PGN.
/// `.serialized` — PAS une précaution de confort, voir
/// ``EngineSearchBudgetBenchmark`` : Swift Testing exécute les tests d'une
/// suite en PARALLÈLE par défaut, et chaque test au moteur réel démarre son
/// propre Stockfish ; `stdout`, le canal UCI, est une ressource GLOBALE au
/// processus — deux moteurs concurrents se corrompent mutuellement. Constaté
/// ici même le 25/08 : les trois tests au moteur réel de cette suite (le gel
/// du 25/08, l'indice, l'alerte gaffe) échouaient TOUS quand Swift Testing
/// les lançait en parallèle, alors que chacun passe seul.
@Suite(.serialized)
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
        try await EngineIntegrationGate.shared.withExclusiveAccess {
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

    // MARK: Indice et alerte gaffe — moteur RÉEL (25/08)

    /// L'indice doit produire au moins une flèche vers un coup réellement
    /// légal — moteur réel, rejoint la famille de fragilité déjà documentée
    /// (contention de la suite complète, voir
    /// ``engineRepliesAfterFirstMoveWithEvalBarEnabled``).
    @Test("L'indice propose au moins un coup légal une fois activé")
    func hintProducesAtLeastOneLegalMove() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            var settings = Chess960Settings()
            settings.positionNumber = 518
            let vm = Chess960PlayViewModel(settings: settings)
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.toggleHint()
            #expect(vm.hintsWanted)

            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline, vm.hintMoves.isEmpty {
                try await Task.sleep(for: .milliseconds(300))
            }
            try #require(!vm.hintMoves.isEmpty, "aucune flèche produite — indice gelé ou muet")
            let best = try #require(vm.hintMoves.first { $0.rank == 1 })

            // Le coup suggéré doit être LÉGAL : le sélectionner doit l'exposer
            // parmi les cases cibles.
            vm.selectSquare(best.from)
            #expect(vm.legalTargetSquares.contains(best.to), "le coup suggéré doit être légal")

            vm.handleViewDisappear()
        }
    }

    /// L'alerte gaffe : 1.e4 g6 2.Dh5?? — la dame se pose sur une case
    /// attaquée EN DIAGONALE par le pion g6 (gxh5 la gagne pour un pion),
    /// un des hangs de dame les plus connus, mécaniquement certain.
    @Test("L'alerte gaffe se déclenche sur une dame hors-jeu")
    func blunderAlertFiresOnAHangingQueen() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            var settings = Chess960Settings()
            settings.positionNumber = 518
            let vm = Chess960PlayViewModel(settings: settings)
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.forceMove(uci: "e2e4")
            vm.forceMove(uci: "g7g6")
            // Laisser la tâche moteur périmée — déclenchée par la transition vers
            // les noirs après e2e4, avant que g7g6 (forcé juste après, SANS
            // attente) n'ait eu la moindre chance d'être vue — DÉCOUVRIR qu'elle
            // n'a plus lieu d'être : son garde (« c'est TOUJOURS aux noirs de
            // jouer ? ») ne s'exécute qu'à SON tour sur la file sérielle, et sans
            // ce répit, il tombe sur l'état final (après Dh5) plutôt que sur
            // l'état intermédiaire (après g6) qui l'aurait neutralisé. Un test
            // purement synchrone ratait cette fenêtre entièrement.
            // La file sérielle doit d'abord vider TASK A (la vérification de
            // gaffe, harmless, sur e2e4 lui-même — deux sondes moteur à ~300 ms
            // chacune) avant que TASK B (la tâche moteur périmée) n'atteigne son
            // propre garde. Marge large, mesurée insuffisante à 500 ms.
            try await Task.sleep(for: .seconds(3))
            vm.forceMove(uci: "d1h5")   // Dh5?? — gxh5 gagne la dame

            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline, vm.pendingBlunderWarning == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(vm.pendingBlunderWarning != nil, "aucune alerte sur une dame qui se fait prendre gratuitement")

            vm.handleViewDisappear()
        }
    }

    @Test("La consultation d'un coup passé met à jour la barre d'éval")
    func reviewRefreshesTheEvalBar() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // `start()` D'ABORD, PUIS le coup — jamais l'inverse : un
            // `forceMove` avant `start()` enfile quand même une tentative de
            // coup moteur (c'est au tour des Noirs après 1.e4), qui échoue
            // au bout du délai de garde puisque rien ne tourne encore —
            // consommant plusieurs secondes de file sérielle en pure perte
            // avant même que `start()` n'ait sa chance.
            var settings = Chess960Settings()
            settings.positionNumber = 518
            settings.showEvalBar = true
            let vm = Chess960PlayViewModel(settings: settings)
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let repliedDeadline = Date().addingTimeInterval(30)
            while Date() < repliedDeadline, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")

            let liveDeadline = Date().addingTimeInterval(20)
            while Date() < liveDeadline, vm.currentEvalCp == nil && vm.currentEvalMate == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            let liveEval = try #require(vm.currentEvalCp, "aucune éval en direct (ou un mat, hors du cas visé ici)")

            // 1.e4, Noirs pas encore répondu : une position TACTIQUEMENT
            // différente de « après 1.e4 e5 2.Cf3 Cc6 » — si la consultation
            // ne redéclenchait rien, l'éval resterait EXACTEMENT celle du
            // direct, jamais recalculée.
            vm.review(toPly: 1)
            #expect(vm.isReviewing)

            let reviewDeadline = Date().addingTimeInterval(20)
            while Date() < reviewDeadline, vm.currentEvalCp == liveEval {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(vm.currentEvalCp != nil, "aucune éval après consultation d'un coup passé")
            #expect(vm.currentEvalCp != liveEval, "l'éval doit refléter la position CONSULTÉE, pas être un résidu du direct")

            vm.handleViewDisappear()
        }
    }
}
