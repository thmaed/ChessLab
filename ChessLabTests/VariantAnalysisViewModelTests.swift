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
        var settings = FairyVariantSettings()
        // `showEvalBar` est maintenant activé par défaut en production —
        // sans ce `false` explicite, chaque `forceMove` ci-dessous
        // enfilerait une salve moteur sur un `EngineController` jamais
        // démarré, gaspillant jusqu'à ~8 s (le sursis d'``EngineWatchdog``)
        // par coup utilisateur, dans une construction censée être PURE.
        // Trouvé le 26/08/2026 après un blocage en suite complète.
        settings.showEvalBar = false
        let vm = FairyVariantPlayViewModel(variant: variant, settings: settings)
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

        let last = vm.displayedLastMove
        #expect(last?.start == Square("b8") && last?.end == Square("c6"))
    }

    /// Construit une graine sur une variante du lot B (Fairy-Stockfish
    /// arbitre) — contrairement au lot A, même poser une position de test
    /// est TOUJOURS un aller-retour moteur réel ; appeler SANS
    /// ``EngineIntegrationGate`` planterait la suite.
    private func engineLegalitySeed(_ variant: EngineLegalityVariant, moves: [String]) async throws -> VariantAnalysisSeed {
        var settings = FairyVariantSettings()
        // Pas besoin de la barre d'éval (maintenant activée par défaut en
        // production) pour construire une graine de test — évite une salve
        // moteur superflue à chaque coup forcé.
        settings.showEvalBar = false
        let vm = EngineLegalityPlayViewModel(variant: variant, settings: settings)
        vm.start()
        let deadline = Date().addingTimeInterval(600)
        while Date() < deadline, !vm.isPositionReady, !vm.isEngineUnavailable {
            try await Task.sleep(for: .milliseconds(200))
        }
        try #require(vm.isPositionReady, "la position initiale n'a jamais été prête")
        for uci in moves { await vm.forceMove(uci: uci) }
        return VariantAnalysisSeed(
            variantID: variant.id, variantDisplayName: variant.displayName, startFEN: variant.startFEN,
            uciLog: vm.uciLog, sanLog: vm.sanLog, moveLog: vm.moveLog, fenLog: vm.fenLog, outcome: vm.outcome
        )
    }

    @Test("Atomique : la dernière position (roi explosé) ne redemande jamais le moteur, même avant la fin de la classification")
    func atomicTerminalPositionNeverQueriesTheLiveEngine() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // 1.e4 e5 2.Nf3 Nc6 3.Bc4 Nf6 4.Ng5 d5 5.exd5 Nxd5 6.Nxf7 — Nxf7
            // fait exploser tout le voisinage 3x3 de f7, y compris le roi
            // noir en e8 : partie terminée, plus AUCUN roi noir sur l'échiquier.
            let seed = try await engineLegalitySeed(.atomic, moves: [
                "e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "g8f6",
                "f3g5", "d7d5", "e4d5", "f6d5", "g5f7",
            ])
            #expect(seed.outcome == GameOutcome(winner: .white, reason: .atomicKingExploded))

            let vm = VariantAnalysisViewModel(seed: seed)
            // Navigue jusqu'à la toute dernière position IMMÉDIATEMENT après
            // la construction — AVANT que la passe de classification lancée
            // par `init` n'ait eu la moindre chance d'atteindre cette même
            // position elle-même. Si `showCurrentCachedEvalOrRefresh()`
            // n'avait pas le même garde-fou que `rankedEval(at:)`, ceci
            // enverrait la position sans roi noir directement à Fairy-
            // Stockfish via `refreshAnalysis()` — signalé par l'utilisateur
            // comme une « plantée du moteur à la fin de l'atomique ».
            vm.review(toPly: vm.totalPlies)

            #expect(vm.displayedBoard.position.pieces.contains { $0.kind == .king && $0.color == .black } == false)
            #expect(vm.currentEvalMate == nil, "un résultat certain se code en centipawns extrêmes, pas en mat")
            #expect(vm.currentEvalCp == EngineScore.mateCentipawns, "l'éval doit refléter la victoire blanche connue, immédiatement")

            vm.handleViewDisappear()
        }
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
