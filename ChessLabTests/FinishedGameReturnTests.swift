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

    @Test(
        "Partie finie + analyse + retour : pas de « moteur indisponible »",
        arguments: [
            EngineLegalityVariant.crazyhouse, .atomic, .racingKings,
            .barricades, .randomBarricades,
        ]
    )
    func returningToAFinishedGameDoesNotDeclareTheEngineDead(
        variant: EngineLegalityVariant
    ) async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game(variant)
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

    /// Trois allers-retours d'affilée sur la MÊME partie : une fuite ou une
    /// dégradation par cycle (flux, abonnés, process) se verrait ici, pas au
    /// premier tour.
    @Test("Trois cycles analyse → retour d'affilée tiennent")
    func threeConsecutiveRoundTripsHold() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game(.crazyhouse, showEvalBar: true)
            vm.start()
            try await EngineIntegrationGate.waitUntilReady(vm)
            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let replied = Date().addingTimeInterval(30)
            while Date() < replied, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies >= 2)
            vm.userResigns()

            for cycle in 1...3 {
                try await self.analysisRoundTrip(vm)
                try await Task.sleep(for: .seconds(2))
                #expect(!vm.isEngineUnavailable,
                        "cycle \(cycle) : \(vm.engineUnavailableReason ?? "indisponible")")

                vm.review(toPly: 1)
                let evalDeadline = Date().addingTimeInterval(20)
                while Date() < evalDeadline, vm.currentEvalCp == nil, vm.currentEvalMate == nil {
                    try await Task.sleep(for: .milliseconds(300))
                }
                #expect(vm.currentEvalCp != nil || vm.currentEvalMate != nil,
                        "cycle \(cycle) : l'éval de consultation n'est pas revenue")
                vm.reviewToLive()
            }
            vm.handleViewDisappear()
        }
    }

    /// La même promesse pour l'AUTRE famille Fairy (lot A — ChessKit arbitre,
    /// Fairy-Stockfish conseille) : son `setupEngine` avait la même garde.
    @Test("Roi de la colline fini + analyse + retour : la consultation vit encore")
    func fairyVariantSurvivesTheRoundTrip() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            var settings = FairyVariantSettings()
            settings.colorChoice = PlayerColorChoice.white.rawValue
            settings.eloSliderValue = 1400
            settings.showEvalBar = true
            settings.hintsEnabled = false
            settings.blunderAlertEnabled = false
            let vm = FairyVariantPlayViewModel(variant: .kingOfTheHill, settings: settings)
            vm.start()
            try await Task.sleep(for: .seconds(1))

            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let replied = Date().addingTimeInterval(30)
            while Date() < replied, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")
            vm.userResigns()

            await vm.stopEngineBeforeAnalysis()
            vm.handleViewDisappear()
            try await Task.sleep(for: .milliseconds(400))
            vm.start()
            try await Task.sleep(for: .seconds(2))
            #expect(!vm.isEngineUnavailable, "bandeau au retour sur le lot A")

            vm.review(toPly: 1)
            let evalDeadline = Date().addingTimeInterval(20)
            while Date() < evalDeadline, vm.currentEvalCp == nil, vm.currentEvalMate == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(vm.currentEvalCp != nil || vm.currentEvalMate != nil,
                    "l'éval de consultation doit revenir sur le lot A aussi")

            vm.handleViewDisappear()
        }
    }

    /// L'écran d'ANALYSE lui-même : le quitter puis y revenir. Son moteur est
    /// arrêté au départ ; au retour, `start()` doit le relancer, garder les
    /// pastilles déjà calculées, et redonner une évaluation.
    @Test("Quitter puis rouvrir l'écran d'analyse : le moteur repart, les pastilles restent")
    func reenteringTheAnalysisScreenWorks() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game(.crazyhouse)
            vm.start()
            try await EngineIntegrationGate.waitUntilReady(vm)
            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let replied = Date().addingTimeInterval(30)
            while Date() < replied, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies >= 2)
            vm.userResigns()
            let seed = VariantAnalysisSeed(
                variantID: EngineLegalityVariant.crazyhouse.id,
                variantDisplayName: EngineLegalityVariant.crazyhouse.displayName,
                startFEN: vm.startFEN,
                uciLog: vm.uciLog, sanLog: vm.sanLog, moveLog: vm.moveLog,
                fenLog: vm.fenLog, outcome: vm.outcome
            )
            await vm.stopEngineBeforeAnalysis()

            let analysis = VariantAnalysisViewModel(seed: seed)
            analysis.start()
            let classified = Date().addingTimeInterval(60)
            while Date() < classified, analysis.isClassifying || analysis.moveQuality.isEmpty {
                try await Task.sleep(for: .milliseconds(300))
            }
            try #require(!analysis.moveQuality.isEmpty, "aucune pastille au premier passage")
            let badges = analysis.moveQuality

            // Quitter, revenir.
            analysis.handleViewDisappear()
            try await Task.sleep(for: .milliseconds(400))
            analysis.start()
            try await Task.sleep(for: .seconds(2))
            #expect(!analysis.isEngineUnavailable, "le moteur d'analyse doit repartir")
            #expect(analysis.moveQuality == badges, "les pastilles calculées doivent rester")

            analysis.review(toPly: 1)
            let evalDeadline = Date().addingTimeInterval(20)
            while Date() < evalDeadline, analysis.currentEvalCp == nil, analysis.currentEvalMate == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(analysis.currentEvalCp != nil || analysis.currentEvalMate != nil,
                    "l'évaluation doit revenir au second passage")

            analysis.handleViewDisappear()
        }
    }
}
