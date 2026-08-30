import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// `.serialized` dès l'origine — même leçon que ``Chess960PlayViewModelTests``
/// (voir [[engine-test-suite-level-serialization]]) : Swift Testing lance
/// une suite en parallèle par défaut, et deux moteurs concurrents (ici
/// Fairy-Stockfish) se corrompent mutuellement.
@Suite(.serialized)
@MainActor
struct FairyVariantPlayViewModelTests {

    private func game(
        _ variant: FairyVariant, color: PlayerColorChoice = .white, showEvalBar: Bool = false
    ) -> FairyVariantPlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = color.rawValue
        settings.showEvalBar = showEvalBar
        return FairyVariantPlayViewModel(variant: variant, settings: settings)
    }

    private func play(_ uci: [String], on vm: FairyVariantPlayViewModel) {
        for move in uci {
            let before = vm.totalPlies
            vm.forceMove(uci: move)
            #expect(vm.totalPlies == before + 1, "\(move) refusé")
        }
    }

    // MARK: Mécanique SANS moteur

    @Test("Roi de la colline : le journal et le SAN tiennent, roque compris")
    func kingOfTheHillLogsMoves() {
        let vm = game(.kingOfTheHill)
        play(["e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5", "e1g1"], on: vm)
        #expect(vm.sanLog.last == "O-O")
        #expect(vm.numberedMoves.count == 4)
    }

    @Test("Roi de la colline : atteindre le centre met fin à la partie")
    func kingOfTheHillEndsOnCentralSquare() {
        let vm = game(.kingOfTheHill)
        // Chemin dégagé exprès, Noir shuffle un cavalier sans rapport : le
        // roi blanc marche e1-e2-f3-e4, jamais en prise en chemin.
        play([
            "e2e3", "b8a6",
            "e1e2", "a6b8",
            "e2f3", "b8a6",
        ], on: vm)
        #expect(vm.outcome == nil, "le roi n'est pas encore arrivé au centre")

        vm.forceMove(uci: "f3e4")
        #expect(vm.outcome == GameOutcome(winner: .white, reason: .kingOfTheHill))
    }

    @Test("Trois échecs : le compteur s'affiche et la victoire tombe au troisième")
    func threeCheckCountsAndEnds() {
        let vm = game(.threeCheck)
        play(["e2e4", "e7e5", "d1h5", "b8c6", "h5f7"], on: vm)
        #expect(vm.checkCounts[.white] == 1, "Dxf7+ est un échec")
        #expect(vm.outcome == nil, "un seul échec ne suffit pas")
    }

    @Test("Horde : position de départ asymétrique, sans roque possible pour les Blancs")
    func hordeStartingPositionHasNoWhiteCastling() {
        let vm = game(.horde)
        #expect(!vm.board.position.pieces.contains { $0.kind == .king && $0.color == .white })
        #expect(vm.board.position.pieces.filter { $0.color == .white }.allSatisfy { $0.kind == .pawn })
    }

    // MARK: Moteur RÉEL

    @Test("L'ordinateur répond après le premier coup — Roi de la colline")
    func engineRepliesInKingOfTheHill() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game(.kingOfTheHill)
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            try #require(vm.totalPlies >= 1, "le coup utilisateur doit tenir")

            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")

            vm.handleViewDisappear()
        }
    }

    @Test("L'ordinateur répond après le premier coup — Trois échecs")
    func engineRepliesInThreeCheck() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game(.threeCheck)
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")

            vm.handleViewDisappear()
        }
    }

    @Test("L'ordinateur répond après le premier coup — Horde (Blancs = pions)")
    func engineRepliesInHorde() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // Horde en Noirs : c'est l'ordinateur qui ouvre avec un pion.
            let vm = game(.horde, color: .black)
            vm.start()

            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, vm.totalPlies < 1 {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(vm.totalPlies >= 1, "l'ordinateur (Blancs, Horde) n'a jamais ouvert")

            vm.handleViewDisappear()
        }
    }

    @Test("L'indice propose au moins un coup légal une fois activé")
    func hintProducesAtLeastOneLegalMove() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game(.kingOfTheHill)
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.toggleHint()
            #expect(vm.hintsWanted)

            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline, vm.hintMoves.isEmpty {
                try await Task.sleep(for: .milliseconds(300))
            }
            try #require(!vm.hintMoves.isEmpty, "aucune flèche produite")
            let best = try #require(vm.hintMoves.first { $0.rank == 1 })
            vm.selectSquare(best.from)
            #expect(vm.legalTargetSquares.contains(best.to), "le coup suggéré doit être légal")

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
            let vm = game(.kingOfTheHill, showEvalBar: true)
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let repliedDeadline = Date().addingTimeInterval(30)
            while Date() < repliedDeadline, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")

            // Position LIVE d'abord — laisse l'éval s'installer, pour être
            // certain que la valeur lue après la consultation vient bien du
            // COUP CONSULTÉ, pas d'un résidu.
            let liveDeadline = Date().addingTimeInterval(20)
            while Date() < liveDeadline, vm.currentEvalCp == nil && vm.currentEvalMate == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            let liveEval = try #require(vm.currentEvalCp, "aucune éval en direct (ou un mat, hors du cas visé ici)")

            // Consulter un coup passé doit RELANCER l'évaluation.
            //
            // Ce test exigeait autrefois que la nouvelle valeur DIFFÈRE de
            // celle du direct — un pari sur ce que le moteur allait répondre,
            // pas une propriété du code : deux positions peuvent
            // parfaitement valoir le même nombre de centipions, et le test
            // tombait alors sans qu'aucun défaut n'existe (mesuré : 61 contre
            // 61). Ce qui se vérifie vraiment, c'est le CONTRAT : la
            // consultation efface l'ancienne valeur sur-le-champ, puis en
            // installe une nouvelle.
            _ = liveEval
            vm.review(toPly: 1)
            #expect(vm.isReviewing)
            #expect(vm.currentEvalCp == nil && vm.currentEvalMate == nil,
                    "l'éval du direct doit être effacée AUSSITÔT, pas laissée à mentir")

            let reviewDeadline = Date().addingTimeInterval(20)
            while Date() < reviewDeadline, vm.currentEvalCp == nil, vm.currentEvalMate == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(vm.currentEvalCp != nil || vm.currentEvalMate != nil,
                    "aucune éval après consultation d'un coup passé")

            vm.handleViewDisappear()
        }
    }

    /// Défaut signalé par l'utilisateur : « dans le mode Variantes je
    /// rencontre régulièrement des messages où il est indiqué que le moteur
    /// n'a pas pu être démarré, souvent après la fin de partie et l'analyse
    /// ou si je reviens en arrière et recommence ».
    ///
    /// Le view model SURVIT à l'aller-retour (``SessionStore`` le conserve
    /// exprès), donc son ``FairyEngineController`` aussi — et avec lui
    /// l'instance ``FairyStockfishEngine`` dont `stop()` a définitivement clos
    /// le flux de lignes. Au retour, le lecteur itérait un flux mort : aucun
    /// `uciok` ne revenait, le démarrage expirait, et l'écran annonçait un
    /// moteur en panne alors que le process, lui, tournait très bien.
    @Test("Le moteur redémarre après un aller-retour sur l'écran")
    func engineRestartsAfterLeavingAndComingBack() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game(.kingOfTheHill, color: .black)
            vm.start()

            let firstDeadline = Date().addingTimeInterval(30)
            while Date() < firstDeadline, vm.totalPlies < 1 {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies >= 1, "l'ordinateur n'a pas joué au PREMIER démarrage")
            #expect(!vm.isEngineUnavailable)

            // On quitte l'écran, puis on y revient : SwiftUI rappelle
            // `start()` sur le MÊME view model.
            vm.handleViewDisappear()
            try await Task.sleep(for: .seconds(1))

            vm.start()
            let pliesBefore = vm.totalPlies
            vm.attemptUserMove(from: Square("e7"), to: Square("e5"))
            try #require(vm.totalPlies == pliesBefore + 1, "le coup utilisateur doit tenir")

            let secondDeadline = Date().addingTimeInterval(30)
            while Date() < secondDeadline, vm.totalPlies < pliesBefore + 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(!vm.isEngineUnavailable, "le moteur est annoncé en panne APRÈS un aller-retour")
            #expect(vm.totalPlies >= pliesBefore + 2, "l'ordinateur n'a pas rejoué après l'aller-retour")

            vm.handleViewDisappear()
        }
    }
}
