import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Reprendre une partie à un coup passé.
///
/// Le défaut signalé le 29/08 : « quand je reviens en arrière pour reprendre
/// la partie plus tôt, le jeu joue à toute vitesse plein de coups ». La cause
/// était dans la chaîne moteur — la troncature remettait la position COURANTE
/// tout en gardant TOUS les coups à rejouer par-dessus, si bien que le moteur
/// se voyait demander de rejouer, depuis une position qui les contenait déjà,
/// les coups qui l'avaient produite.
@Suite(.serialized)
@MainActor
struct VariantResumeTests {

    private func game(_ variant: EngineLegalityVariant) -> EngineLegalityPlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = PlayerColorChoice.white.rawValue
        settings.eloSliderValue = 1400
        settings.showEvalBar = false
        settings.hintsEnabled = false
        settings.blunderAlertEnabled = false
        return EngineLegalityPlayViewModel(variant: variant, settings: settings)
    }

    /// Joue quatre demi-coups (deux échanges) et rend la vue-modèle.
    private func playedGame(_ variant: EngineLegalityVariant) async throws -> EngineLegalityPlayViewModel {
        let vm = game(variant)
        vm.start()
        try await EngineIntegrationGate.waitUntilReady(vm)
        for _ in 0..<2 {
            let target = vm.totalPlies
            guard let move = anyLegalMove(vm) else { break }
            vm.attemptUserMove(from: move.from, to: move.to)
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, vm.totalPlies < target + 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
        }
        return vm
    }

    private func anyLegalMove(_ vm: EngineLegalityPlayViewModel) -> (from: Square, to: Square)? {
        for square in DuckChessRules.allSquares {
            vm.selectSquare(square)
            if let target = vm.legalTargetSquares.first { return (square, target) }
        }
        return nil
    }

    @Test(
        "Reprendre un coup passé ne relance pas la partie en accéléré",
        arguments: [EngineLegalityVariant.crazyhouse, .barricades, .randomBarricades]
    )
    func resumingDoesNotReplayTheGame(variant: EngineLegalityVariant) async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = try await self.playedGame(variant)
            try #require(vm.totalPlies >= 4, "il faut une partie à reprendre : \(vm.totalPlies)")

            let target = 2
            let expectedFEN = vm.fenLog[target]
            vm.review(toPly: target)
            try #require(vm.isReviewing)
            try #require(vm.canResumeFromReview, "la reprise doit être offerte")
            vm.resumeFromReview()

            // Laisser toute latitude à un éventuel emballement : c'est
            // précisément ce qu'on veut voir NE PAS arriver.
            let deadline = Date().addingTimeInterval(12)
            while Date() < deadline, !vm.isPositionReady {
                try await Task.sleep(for: .milliseconds(200))
            }
            try await Task.sleep(for: .seconds(3))

            #expect(vm.totalPlies == target, "la partie est repartie toute seule : \(vm.totalPlies) demi-coups")
            #expect(vm.fenLog.count == target + 1)
            #expect(vm.displayedFEN == VariantFEN.forChessKit(expectedFEN),
                    "le plateau ne montre pas la position reprise")
            #expect(vm.outcome == nil)

            vm.handleViewDisappear()
        }
    }

    /// Le miroir, et c'est LUI qui attrape le défaut : avec la chaîne mal
    /// recalée, la partie ne repart pas — vérifié en remettant la version
    /// fautive, le coup utilisateur passe mais l'ordinateur ne répond jamais
    /// (3 demi-coups au lieu de 4). Le moteur se voit demander de rejouer,
    /// depuis une position qui les contient déjà, les coups qui l'ont
    /// produite : il les ignore, et la position qu'il rend n'a plus de
    /// rapport avec celle de l'écran — d'où aussi bien un enchaînement de
    /// coups en rafale qu'un blocage, selon ce qui subsiste du trait.
    @Test("Après une reprise, la partie repart normalement, un coup à la fois")
    func theGameStillWorksAfterResuming() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = try await self.playedGame(.barricades)
            try #require(vm.totalPlies >= 4)

            vm.review(toPly: 2)
            vm.resumeFromReview()
            let ready = Date().addingTimeInterval(12)
            while Date() < ready, !vm.isPositionReady {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies == 2)

            let move = try #require(self.anyLegalMove(vm), "plus aucun coup légal après la reprise")
            vm.attemptUserMove(from: move.from, to: move.to)
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, vm.totalPlies < 4 {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(vm.totalPlies == 4, "un coup utilisateur, une réponse — pas plus : \(vm.totalPlies)")

            vm.handleViewDisappear()
        }
    }
}
