import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// `.serialized` — même leçon que ``FairyVariantPlayViewModelTests`` (voir
/// [[engine-test-suite-level-serialization]]). Ici, TOUT test touche le
/// moteur réel : contrairement au lot A, ``EngineLegalityPlayViewModel``
/// n'a pas de chemin « mécanique » sans moteur — appliquer un coup, même
/// pour poser une position de test, est TOUJOURS un aller-retour Fairy-
/// Stockfish (voir le commentaire de tête de la vue-modèle).
@Suite(.serialized)
@MainActor
struct EngineLegalityPlayViewModelTests {

    private func game(
        _ variant: EngineLegalityVariant, color: PlayerColorChoice = .white, showEvalBar: Bool = false,
        blunderAlertEnabled: Bool = true
    ) -> EngineLegalityPlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = color.rawValue
        settings.showEvalBar = showEvalBar
        settings.blunderAlertEnabled = blunderAlertEnabled
        return EngineLegalityPlayViewModel(variant: variant, settings: settings)
    }

    // 600 s, pas 20 : voir [[engine-test-suite-level-serialization]] — une
    // suite lancée SEULE prend une fraction de seconde à devenir prête, mais
    // la suite complète (790+ tests, moteurs réels concurrents entre suites
    // même chacune `.serialized`) peut saturer le MainActor bien au-delà
    // d'une marge optimiste, et la marge nécessaire CROÎT avec la taille de
    // la suite (60 s, puis 278 s, puis 406 s observés au fil des ajouts) —
    // même classe que `GameClockStartTests` (120 s → 300 s), pas une
    // régression réelle. 0 échec en isolation à chaque mesure (4/4 en ~4 s).
    /// Déléguée à ``EngineIntegrationGate/waitUntilReady(_:timeout:sourceLocation:)``
    /// depuis le 29/08 : les suites Crazyhouse avaient besoin de la même
    /// attente, et deux copies d'un compte à rebours moteur sont deux façons
    /// de diverger.
    private func waitReady(_ vm: EngineLegalityPlayViewModel, timeout: TimeInterval = 600) async throws {
        try await EngineIntegrationGate.waitUntilReady(vm, timeout: timeout)
    }

    @Test("Course des rois : position de départ, l'ordinateur répond après le premier coup")
    func racingKingsEngineReplies() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game(.racingKings)
            vm.start()
            try await waitReady(vm)

            // e1 = cavalier blanc dans cette position de départ (voir
            // ``EngineLegalityVariant/racingKings``) — un coup d'ouverture
            // quelconque suffit, seul compte que l'ordinateur réponde ensuite.
            // `attemptUserMove`, PAS `forceMove` : ce dernier n'enchaîne plus
            // sur la réponse moteur (voir son commentaire de tête).
            vm.attemptUserMove(from: Square("e1"), to: Square("f3"))
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")

            vm.handleViewDisappear()
        }
    }

    @Test("Atomique : une capture fait exploser la case d'arrivée")
    func atomicExplosion() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game(.atomic)
            vm.start()
            try await waitReady(vm)

            await vm.forceMove(uci: "e2e4")
            await vm.forceMove(uci: "d7d5")
            await vm.forceMove(uci: "e4d5")

            #expect(vm.board.position.piece(at: Square("d5")) == nil, "la case capturée doit être vide après l'explosion")
            #expect(vm.board.position.piece(at: Square("e4")) == nil, "la pièce capturante doit avoir explosé aussi")
            #expect(vm.totalPlies == 3)

            vm.handleViewDisappear()
        }
    }

    @Test("Antéchecs : la capture est obligatoire — les autres coups sont refusés")
    func antichessForcedCapture() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // Blancs = l'utilisateur — SEUL choix qui évite la course avec le
            // premier coup automatique de l'ordinateur : si l'utilisateur
            // avait été les Noirs, `initializePosition()` aurait fait jouer
            // l'ordinateur (Blancs, trait de départ) DANS `start()`, en
            // parallèle des coups forcés ci-dessous — trouvé en traçant les
            // FEN reçus, deux "e2e4" strictement identiques dans le journal.
            //
            // Après 1.e4 d5, c'est aux BLANCS de jouer avec une capture
            // disponible (exd5) : en Antéchecs, dès qu'une capture existe,
            // TOUT AUTRE coup devient illégal — donc le cavalier g1 ne doit
            // plus rien pouvoir jouer.
            let vm = game(.antichess, color: .white)
            vm.start()
            try await waitReady(vm)

            await vm.forceMove(uci: "e2e4")
            await vm.forceMove(uci: "d7d5")
            try await waitReady(vm)

            vm.selectSquare(Square("e4"))
            #expect(vm.legalTargetSquares.contains(Square("d5")), "le pion doit pouvoir reprendre en d5")

            vm.selectSquare(Square("g1"))
            #expect(vm.legalTargetSquares.isEmpty, "un coup sans capture ne doit proposer AUCUNE case : la capture est obligatoire ailleurs")

            vm.handleViewDisappear()
        }
    }

    @Test("La consultation d'un coup passé met à jour la barre d'éval")
    func reviewRefreshesTheEvalBar() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game(.atomic, showEvalBar: true)
            vm.start()
            try await waitReady(vm)

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
            let liveEval = try #require(vm.currentEvalCp, "aucune éval en direct")

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
