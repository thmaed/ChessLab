import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// `.serialized` — même leçon que les autres suites de variantes (voir
/// [[engine-test-suite-level-serialization]]).
@Suite(.serialized)
@MainActor
struct StolenMovePlayViewModelTests {

    private func game(color: PlayerColorChoice = .white, tokenInterval: Int = 7) -> StolenMovePlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = color.rawValue
        settings.stolenMoveTokenInterval = tokenInterval
        return StolenMovePlayViewModel(settings: settings)
    }

    /// Sept coups blancs, sept coups noirs — chacun touche une case/pièce
    /// DIFFÉRENTE (jamais deux fois la même position) pour ne pas déclencher
    /// une nulle par répétition. Se termine sur le TRAIT DES BLANCS (14
    /// demi-coups joués) : le jeton gagné au 7e coup blanc n'est dépensable
    /// qu'à leur coup SUIVANT, une fois les Noirs aussi passés par leur 7e.
    private let sevenWhiteMoves = ["g1f3", "b1c3", "a2a3", "h2h3", "a3a4", "h3h4", "f3e5"]
    private let sevenBlackMoves = ["b8c6", "g8f6", "a7a6", "h7h6", "a6a5", "h6h5", "d7d6"]

    private func playSevenWhiteMoves(on vm: StolenMovePlayViewModel) {
        for i in 0..<7 {
            vm.forceMove(uci: sevenWhiteMoves[i])
            vm.forceMove(uci: sevenBlackMoves[i])
        }
    }

    @Test("Un jeton apparaît au 7e coup d'un camp, pas avant")
    func tokenGrantedAtSeventhMove() {
        let vm = game()
        for i in 0..<6 {
            vm.forceMove(uci: sevenWhiteMoves[i])
            #expect((vm.tokens[.white] ?? 0) == 0, "pas de jeton avant le 7e coup")
            vm.forceMove(uci: sevenBlackMoves[i])
        }
        vm.forceMove(uci: sevenWhiteMoves[6])
        #expect((vm.tokens[.white] ?? 0) == 1, "le 7e coup doit accorder un jeton")
        #expect(vm.movesPlayedByColor[.white] == 7)
    }

    @Test("Réglage de l'intervalle : 4 coups suffisent si configuré ainsi")
    func customTokenInterval() {
        let vm = game(tokenInterval: 4)
        vm.forceMove(uci: "g1f3")
        vm.forceMove(uci: "b8c6")
        vm.forceMove(uci: "b1c3")
        vm.forceMove(uci: "g8f6")
        vm.forceMove(uci: "a2a3")
        vm.forceMove(uci: "a7a6")
        #expect((vm.tokens[.white] ?? 0) == 0)
        vm.forceMove(uci: "h2h3")
        #expect((vm.tokens[.white] ?? 0) == 1, "4 coups configurés doivent suffire")
    }

    @Test("Dépenser le jeton fait jouer deux coups d'affilée au même camp")
    func spendingTokenGrantsASecondMove() {
        let vm = game()
        playSevenWhiteMoves(on: vm)
        #expect((vm.tokens[.white] ?? 0) == 1)
        let plyBefore = vm.totalPlies

        vm.wantsToSpendToken = true
        vm.forceMove(uci: "b2b3") // ne met pas échec — le tour continue

        #expect(vm.totalPlies == plyBefore + 1)
        #expect(vm.awaitingSecondMoveBy == .white, "toujours au trait des Blancs")
        #expect(vm.effectiveMover == .white)
        #expect((vm.tokens[.white] ?? 0) == 0, "le jeton est dépensé")

        vm.forceMove(uci: "d2d3")
        #expect(vm.totalPlies == plyBefore + 2)
        #expect(vm.awaitingSecondMoveBy == nil, "le tour double est terminé")
        #expect(vm.effectiveMover == .black, "le trait passe enfin aux Noirs")
    }

    @Test("Un premier coup qui met échec arrête le tour double avant le second")
    func checkOnFirstMoveEndsTheDoubleTurnEarly() {
        let vm = game(tokenInterval: 4)
        vm.forceMove(uci: "e2e4")
        vm.forceMove(uci: "a7a6")
        vm.forceMove(uci: "b1c3")
        vm.forceMove(uci: "a6a5")
        vm.forceMove(uci: "g1f3")
        vm.forceMove(uci: "a5a4")
        vm.forceMove(uci: "f1c4") // 4e coup blanc -> jeton (Fc4, ne met pas échec)
        vm.forceMove(uci: "h7h6")
        #expect((vm.tokens[.white] ?? 0) == 1)

        vm.wantsToSpendToken = true
        vm.forceMove(uci: "c4f7") // Fxf7+ : échec direct, pion noir toujours en f7
        #expect(vm.awaitingSecondMoveBy == nil, "le tour s'arrête après le premier coup, qui met échec")
        #expect(vm.effectiveMover == .black, "le trait passe aux Noirs malgré le jeton dépensé")
    }

    @Test("Impossible de dépenser un jeton en étant soi-même en échec")
    func cannotSpendTokenWhileInCheck() {
        let vm = game(tokenInterval: 4)
        vm.forceMove(uci: "e2e4")
        vm.forceMove(uci: "a7a6")
        vm.forceMove(uci: "b1c3")
        vm.forceMove(uci: "a6a5")
        vm.forceMove(uci: "g1f3")
        vm.forceMove(uci: "h7h6")
        vm.forceMove(uci: "f1c4")
        vm.forceMove(uci: "h6h5") // 4e coup noir -> jeton noir
        #expect((vm.tokens[.black] ?? 0) == 1, "les Noirs doivent avoir un jeton après leur 4e coup")

        vm.forceMove(uci: "c4f7") // Fxf7+ : échec direct sur les Noirs
        var isBlackInCheck = false
        if case .check(let color) = vm.board.state, color == .black { isBlackInCheck = true }
        #expect(isBlackInCheck, "les Noirs doivent être en échec ici")

        vm.wantsToSpendToken = true
        // Kxf7 pare l'échec — le jeton ne peut pas être dépensé, quel que
        // soit le nombre en stock : la garde porte sur l'ÉTAT avant coup.
        vm.forceMove(uci: "e8f7")
        #expect(vm.awaitingSecondMoveBy == nil, "aucun tour double : le camp était en échec avant de jouer")
    }

    @Test("Un second coup de tour double explosé se voit dans le journal")
    func secondMoveAppearsInMoveLog() {
        let vm = game()
        playSevenWhiteMoves(on: vm)
        vm.wantsToSpendToken = true
        vm.forceMove(uci: "b2b3")
        vm.forceMove(uci: "d2d3")
        #expect(vm.sanLog.count == vm.totalPlies)
        #expect(vm.moveLog.count == vm.totalPlies)
        #expect(vm.fenLog.count == vm.totalPlies + 1)
    }

    @Test("La reprise retire uniquement le dernier coup, pas tout le tour double")
    func takebackRemovesOnlyTheLastMove() {
        let vm = game()
        playSevenWhiteMoves(on: vm)
        vm.wantsToSpendToken = true
        vm.forceMove(uci: "b2b3")
        vm.forceMove(uci: "d2d3")
        let plyAfterDoubleTurn = vm.totalPlies

        #expect(vm.canTakeback)
        vm.takeback()
        #expect(vm.totalPlies == plyAfterDoubleTurn - 1, "un seul coup retiré")
        #expect(vm.awaitingSecondMoveBy == .white, "de retour au second coup en attente")
        #expect(vm.effectiveMover == .white)
    }

    @Test("L'export porte le marqueur [jeton] sur le premier coup d'un tour double")
    func exportMarksTheTokenMove() {
        let vm = game()
        playSevenWhiteMoves(on: vm)
        vm.wantsToSpendToken = true
        vm.forceMove(uci: "b2b3")
        vm.forceMove(uci: "d2d3")
        #expect(vm.exportedPGN.contains("[jeton]"))
        #expect(vm.exportedPGN.contains("[Variant \"stolenmove\"]"))
    }

    // MARK: Prise en passant qui survit à un coup intercalé (règle 5)

    @Test("La prise en passant reste valable au second coup d'un tour double")
    func enPassantSurvivesTheInterposedFirstMove() {
        let vm = game(color: .black, tokenInterval: 4)
        vm.forceMove(uci: "e2e4")   // Blancs 1
        vm.forceMove(uci: "b7b5")   // Noirs 1 — pion noir en route vers b4
        vm.forceMove(uci: "b1c3")   // Blancs 2
        vm.forceMove(uci: "b5b4")   // Noirs 2 — pion noir en b4, prêt pour plus tard
        vm.forceMove(uci: "g1f3")   // Blancs 3
        vm.forceMove(uci: "g8f6")   // Noirs 3
        vm.forceMove(uci: "h2h3")   // Blancs 4
        vm.forceMove(uci: "h7h6")   // Noirs 4 -> jeton noir accordé ICI
        #expect((vm.tokens[.black] ?? 0) == 1, "les Noirs doivent avoir un jeton après leur 4e coup")

        vm.forceMove(uci: "a2a4")   // Blancs 5 — pousse de deux cases juste avant le tour double noir : b4xa3 en passant devient possible
        #expect(vm.effectiveMover == .black)

        vm.wantsToSpendToken = true
        vm.forceMove(uci: "h6h5")   // Noirs, 1er coup du tour double : PAS la prise en passant — un coup s'intercale
        #expect(vm.awaitingSecondMoveBy == .black, "le premier coup ne met pas échec, le tour double continue")

        // Second coup : la prise en passant b4xa3 doit ENCORE être légale,
        // via le chemin d'interaction public (mêmes gardes que l'utilisateur).
        vm.selectSquare(Square("b4"))
        #expect(vm.legalTargetSquares.contains(Square("a3")), "b4xa3 en passant doit rester jouable au second coup")

        vm.attemptUserMove(from: Square("b4"), to: Square("a3"))
        #expect(vm.awaitingSecondMoveBy == nil, "le tour double se termine après le second coup")
        #expect(vm.board.position.piece(at: Square("a4")) == nil, "le pion blanc pris en passant doit avoir disparu")
    }

    // MARK: Moteur RÉEL

    @Test("L'ordinateur répond après le premier coup")
    func engineRepliesAfterFirstMove() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
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

    @Test("L'ordinateur dépense automatiquement son jeton et joue deux coups d'affilée")
    func engineAutomaticallySpendsItsToken() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game(tokenInterval: 4) // Blancs = utilisateur, Noirs = ordinateur
            vm.start() // TOUJOURS avant le premier coup : un `forceMove` plus
            // tôt enfilerait une requête moteur avant que le moteur ne soit
            // démarré — voir le même piège documenté dans
            // FairyVariantPlayViewModelTests.
            try await Task.sleep(for: .seconds(1))

            // Cinq coups blancs sûrs (mêmes cases que ``sevenWhiteMoves``) —
            // les Noirs répondent RÉELLEMENT via le moteur à chaque fois, ce
            // qui les amène à leur 4e coup (jeton gagné) puis à leur 5e, où
            // ils doivent enchaîner deux coups d'affilée.
            let whiteMoves = ["g1f3", "b1c3", "a2a3", "h2h3", "a3a4"]
            for (index, uci) in whiteMoves.enumerated() {
                let plyBefore = vm.totalPlies
                vm.forceMove(uci: uci)
                try #require(vm.totalPlies == plyBefore + 1, "le coup blanc n°\(index + 1) doit tenir")

                let expectedReplies = index < 4 ? 1 : 2 // le 5e coup rend la main à un moteur qui a un jeton
                let deadline = Date().addingTimeInterval(30)
                while Date() < deadline, vm.totalPlies < plyBefore + 1 + expectedReplies {
                    try await Task.sleep(for: .milliseconds(200))
                }
                #expect(
                    vm.totalPlies >= plyBefore + 1 + expectedReplies,
                    "réponse(s) noire(s) manquante(s) après le coup blanc n°\(index + 1)"
                )
            }

            #expect((vm.tokens[.black] ?? 0) == 0, "le jeton noir doit avoir été dépensé")
            #expect(vm.awaitingSecondMoveBy == nil, "le tour double machine doit être bouclé")

            vm.handleViewDisappear()
        }
    }
}
