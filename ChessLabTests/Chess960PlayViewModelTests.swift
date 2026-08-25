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
