import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Revenir sur une partie FINIE après l'avoir analysée.
///
/// Le scénario exact du signalement du 30/08, sur le Crazyhouse : mat,
/// « Analyser » — qui ARRÊTE le moteur de la partie, un seul process à la
/// fois —, puis retour en arrière. L'écran rappelle `start()`, où deux gardes
/// se contredisaient : `setupEngine()` sautait le redémarrage (partie finie),
/// pendant qu'`initializePosition()` interrogeait quand même le moteur —
/// arrêté — et concluait « moteur indisponible ». DÉTERMINISTE, donc pas une
/// course : le correctif d'août (instance neuve dans `start(variant:)`)
/// couvrait le retour en COURS de partie, celui-ci restait.
@Suite(.serialized)
@MainActor
struct FinishedGameReturnTests {

    private func game(
        _ variant: EngineLegalityVariant, showEvalBar: Bool = false
    ) -> EngineLegalityPlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = PlayerColorChoice.white.rawValue
        settings.eloSliderValue = 1400
        settings.showEvalBar = showEvalBar
        settings.hintsEnabled = false
        settings.blunderAlertEnabled = false
        return EngineLegalityPlayViewModel(variant: variant, settings: settings)
    }

    /// Le trajet complet de l'utilisateur, tel que les écrans le produisent.
    private func analysisRoundTrip(_ vm: EngineLegalityPlayViewModel) async throws {
        await vm.stopEngineBeforeAnalysis()             // le bouton « Analyser »
        vm.handleViewDisappear()                        // l'écran de partie se démonte
        try await Task.sleep(for: .milliseconds(400))   // l'arrêt détaché aboutit
        vm.start()                                      // retour : `.onAppear`
    }

    @Test("Crazyhouse fini + analyse + retour : pas de « moteur indisponible »")
    func returningToAFinishedGameDoesNotDeclareTheEngineDead() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game(.crazyhouse)
            vm.start()
            try await EngineIntegrationGate.waitUntilReady(vm)
            vm.userResigns()
            try #require(vm.outcome != nil)
            let finalFEN = vm.displayedFEN

            try await self.analysisRoundTrip(vm)

            // PAS une boucle sur `isPositionReady` : il est resté vrai de la
            // première session (rien ne le remet à faux au départ), et la
            // première version de ce test sortait donc AVANT que la file
            // moteur n'ait déclaré la panne — vert pour de mauvaises raisons.
            // On laisse la file dérouler, puis on regarde ce qu'elle a dit.
            try await Task.sleep(for: .seconds(3))
            #expect(!vm.isEngineUnavailable,
                    "bandeau au retour — raison : \(vm.engineUnavailableReason ?? "aucune")")
            #expect(vm.isPositionReady, "l'écran doit se recaler tout seul")
            #expect(vm.outcome != nil, "la partie doit RESTER finie")
            #expect(vm.displayedFEN == finalFEN, "le plateau ne doit pas bouger")

            vm.handleViewDisappear()
        }
    }

    /// La partie de la promesse qui exige un moteur VRAIMENT reparti : au
    /// retour, consulter un coup doit encore rafraîchir la barre d'éval.
    @Test("Au retour, la consultation retrouve sa barre d'évaluation")
    func reviewEvalWorksAfterTheRoundTrip() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game(.crazyhouse, showEvalBar: true)
            vm.start()
            try await EngineIntegrationGate.waitUntilReady(vm)

            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let replied = Date().addingTimeInterval(30)
            while Date() < replied, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies >= 2, "il faut des coups à consulter")
            vm.userResigns()

            try await self.analysisRoundTrip(vm)
            let ready = Date().addingTimeInterval(15)
            while Date() < ready, !vm.isPositionReady, !vm.isEngineUnavailable {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(!vm.isEngineUnavailable,
                         Comment(rawValue: vm.engineUnavailableReason ?? "indisponible sans raison"))

            vm.review(toPly: 1)
            let evalDeadline = Date().addingTimeInterval(20)
            while Date() < evalDeadline, vm.currentEvalCp == nil, vm.currentEvalMate == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(vm.currentEvalCp != nil || vm.currentEvalMate != nil,
                    "le moteur doit être reparti pour évaluer le coup consulté")

            vm.handleViewDisappear()
        }
    }
}
