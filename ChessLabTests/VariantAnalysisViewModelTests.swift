import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// `.serialized` — même leçon que ``Chess960AnalysisViewModelTests``
/// (voir [[engine-test-suite-level-serialization]]).
@Suite(.serialized)
@MainActor
struct VariantAnalysisViewModelTests {

    /// Construit une graine (``VariantAnalysisSeed``) en jouant des coups
    /// FORCÉS sur une partie Roi de la colline — ChessKit reste l'arbitre
    /// (lot A), donc aucun moteur n'est nécessaire pour CETTE construction,
    /// seulement pour l'analyse elle-même le cas échéant.
    private func fairySeed(_ variant: FairyVariant = .kingOfTheHill, moves: [String]) -> VariantAnalysisSeed {
        let vm = FairyVariantPlayViewModel(variant: variant, settings: FairyVariantSettings())
        for uci in moves { vm.forceMove(uci: uci) }
        return VariantAnalysisSeed(
            variantID: variant.id, variantDisplayName: variant.displayName, startFEN: variant.startFEN,
            uciLog: vm.uciLog, sanLog: vm.sanLog, moveLog: vm.moveLog, fenLog: vm.fenLog, outcome: vm.outcome
        )
    }

    @Test("Se construit depuis une graine, position et journal identiques")
    func buildsFromASeed() {
        let seed = fairySeed(moves: ["e2e4", "e7e5", "g1f3", "b8c6"])
        let vm = VariantAnalysisViewModel(seed: seed)
        #expect(vm.sanLog == ["e4", "e5", "Nf3", "Nc6"])
        #expect(vm.totalPlies == 4)
        #expect(vm.displayedPly == 0, "s'ouvre sur le DÉBUT de la partie, comme Chess960")
    }

    @Test("La navigation lit fenLog directement — aucun rejeu nécessaire")
    func navigationReadsFenLogDirectly() {
        let seed = fairySeed(moves: ["e2e4", "e7e5", "g1f3", "b8c6"])
        let vm = VariantAnalysisViewModel(seed: seed)

        vm.review(toPly: 0)
        #expect(vm.displayedFEN == FairyVariant.kingOfTheHill.startFEN)

        vm.review(toPly: 4)
        #expect(vm.displayedFEN == seed.fenLog[4])

        let last = try? #require(vm.displayedLastMove)
        #expect(last?.start == Square("b8") && last?.end == Square("c6"))
    }

    @Test("Roi de la colline : le coup final gagnant garde son FEN et son issue")
    func kingOfTheHillTerminalPositionCarriesOutcome() {
        // e2e3 e7e5 e1e2 puis Re4 (Roi de la colline) — chemin dégagé, comme
        // ``FairyVariantPlayViewModelTests/kingOfTheHillEndsOnCentralSquare``.
        let seed = fairySeed(moves: ["e2e3", "b8a6", "e1e2", "a6b8", "e2f3", "b8a6", "f3e4"])
        #expect(seed.outcome == GameOutcome(winner: .white, reason: .kingOfTheHill))
        let vm = VariantAnalysisViewModel(seed: seed)
        vm.review(toPly: vm.totalPlies)
        #expect(vm.displayedBoard.position.piece(at: Square("e4"))?.kind == .king)
    }

    @Test("L'analyse produit une évaluation et au moins une flèche")
    func analysisProducesAnEvalAndAtLeastOneArrow() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let seed = fairySeed(moves: ["e2e4", "e7e5", "g1f3"])
            let vm = VariantAnalysisViewModel(seed: seed)
            vm.start()

            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline, vm.currentEvalCp == nil && vm.currentEvalMate == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(vm.currentEvalCp != nil || vm.currentEvalMate != nil, "aucune évaluation produite")
            #expect(!vm.hintMoves.isEmpty, "aucune flèche produite")

            vm.handleViewDisappear()
        }
    }

    @Test("La classification couvre toute la ligne")
    func classificationCoversTheWholeMainLine() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let seed = fairySeed(moves: ["e2e4", "e7e5", "g1f3", "b8c6"])
            let vm = VariantAnalysisViewModel(seed: seed)
            vm.start()

            let deadline = Date().addingTimeInterval(60)
            while Date() < deadline, vm.moveQuality.count < vm.totalPlies {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(vm.moveQuality.count == vm.totalPlies)

            vm.handleViewDisappear()
        }
    }

    /// 1.e4 g6 2.Dh5?? — même hang de dame que
    /// ``Chess960AnalysisViewModelTests/aHangingQueenIsClassifiedAsAFault``.
    @Test("Une dame hors-jeu se classe en faute")
    func aHangingQueenIsClassifiedAsAFault() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let seed = fairySeed(moves: ["e2e4", "g7g6", "d1h5"])
            let vm = VariantAnalysisViewModel(seed: seed)
            vm.start()

            let deadline = Date().addingTimeInterval(60)
            while Date() < deadline, vm.moveQuality[3] == nil {
                try await Task.sleep(for: .milliseconds(300))
            }
            let quality = try #require(vm.moveQuality[3])
            #expect(quality.isFault, "Dh5?? doit être signalé comme une faute (\(quality))")

            vm.handleViewDisappear()
        }
    }

    @Test("La classification se met en cache entre deux ouvertures")
    func classificationIsCachedAcrossOpenings() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let seed = fairySeed(moves: ["e2e4", "e7e5"])
            let key = try #require(AnalysisEvalStore.key(startFEN: seed.startFEN, lans: seed.uciLog, variantID: seed.variantID))
            defer { try? FileManager.default.removeItem(at: AnalysisEvalStore.fileURL(for: key)) }

            let first = VariantAnalysisViewModel(seed: seed)
            first.start()
            let firstDeadline = Date().addingTimeInterval(60)
            while Date() < firstDeadline, first.moveQuality.count < first.totalPlies {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(first.moveQuality.count == first.totalPlies)
            first.handleViewDisappear()

            let second = VariantAnalysisViewModel(seed: seed)
            second.start()
            let cacheDeadline = Date().addingTimeInterval(5)
            while Date() < cacheDeadline, second.moveQuality.count < second.totalPlies {
                try await Task.sleep(for: .milliseconds(100))
            }
            #expect(second.moveQuality.count == second.totalPlies, "le cache doit fournir la classification quasi instantanément")
            #expect(second.moveQuality == first.moveQuality)

            second.handleViewDisappear()
        }
    }

    /// Un cache CROISÉ entre deux variantes qui partagent la même position de
    /// départ standard (Roi de la colline et Trois échecs) ne doit PAS se
    /// mélanger — voir le commentaire de tête d'``AnalysisEvalStore/key(startFEN:lans:variantID:)``.
    @Test("Le cache ne se confond pas entre deux variantes à départ identique")
    func cacheDoesNotCollideAcrossVariantsWithTheSameStart() {
        let kingOfHillKey = AnalysisEvalStore.key(
            startFEN: FairyVariant.kingOfTheHill.startFEN, lans: ["e2e4", "e7e5"], variantID: FairyVariant.kingOfTheHill.id
        )
        let threeCheckKey = AnalysisEvalStore.key(
            startFEN: FairyVariant.threeCheck.startFEN, lans: ["e2e4", "e7e5"], variantID: FairyVariant.threeCheck.id
        )
        #expect(kingOfHillKey != threeCheckKey)
    }

    @Test("L'export porte les tags de la variante")
    func exportCarriesVariantTags() {
        let seed = fairySeed(moves: ["e2e4", "e7e5"])
        let vm = VariantAnalysisViewModel(seed: seed)
        let pgn = vm.exportedPGN
        #expect(pgn.contains("[Variant \"kingofthehill\"]"))
        #expect(pgn.contains("1. e4 e5"))
    }
}
