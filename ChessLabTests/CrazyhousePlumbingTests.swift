import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Plomberie Crazyhouse : les deux pièces manquantes entre le moteur et
/// l'app, trouvées par une sonde le 28/08/2026.
///
/// Fairy-Stockfish joue `crazyhouse` nativement (`variant.cpp`, avec un
/// réseau NNUE dédié) et ChessKit accepte les FEN à crochets — il lit même le
/// plateau correctement, il ignore simplement la réserve. Restaient deux
/// trous, invisibles l'un comme l'autre :
///
/// 1. le filtre de coups de ``FairyEngineController/queryPosition(startFEN:uciLog:)``
///    exigeait une première lettre MINUSCULE, ce qui rejetait en silence
///    toutes les poses (`P@e4`) — 33 dans la position sondée, aucune ne
///    parvenait au view model ;
/// 2. rien ne lisait la réserve, pourtant écrite entre crochets dans la FEN.
@Suite(.serialized)
@MainActor
struct CrazyhousePlumbingTests {

    // MARK: Lecture de la réserve

    @Test("La réserve se lit dans la FEN, par camp")
    func pocketIsReadFromFEN() {
        let pocket = FairyEngineController.parsePocket(
            fromFEN: "rnb1kbnr/ppp1pppp/8/3q4/8/8/PPPP1PPP/RNBQKBNR[PPnq] w KQkq - 0 3"
        )
        #expect(pocket[.white]?[.pawn] == 2, "deux pions blancs en main")
        #expect(pocket[.black]?[.knight] == 1, "un cavalier noir en main")
        #expect(pocket[.black]?[.queen] == 1, "une dame noire en main")
        #expect(pocket[.white]?[.knight] == nil, "rien d'autre côté blanc")
    }

    @Test("Une réserve vide, ou pas de crochets du tout, ne donne rien")
    func emptyPocketIsEmpty() {
        #expect(FairyEngineController.parsePocket(
            fromFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR[] w KQkq - 0 1"
        ).isEmpty)
        // Les six autres variantes n'ont pas de crochets : la lecture doit
        // rester muette plutôt que de se tromper.
        #expect(FairyEngineController.parsePocket(
            fromFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        ).isEmpty)
    }

    // MARK: Les poses franchissent le filtre

    /// Le test qui aurait attrapé le défaut : on demande au VRAI moteur une
    /// position où le camp au trait tient un pion en main, et on exige que
    /// les poses arrivent jusqu'ici.
    @Test("Les coups de pose survivent au filtre de queryPosition")
    func dropMovesReachTheViewModel() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let engine = FairyEngineController()
            try #require(await engine.start(variant: "crazyhouse"), "Crazyhouse doit démarrer")

            // 1.e4 d5 2.exd5 Dxd5 : les Blancs tiennent [P], et c'est à eux.
            let query = try #require(
                await engine.queryPosition(
                    startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                    uciLog: ["e2e4", "d7d5", "e4d5", "d8d5"]
                ),
                "le moteur doit répondre à `d`"
            )

            let drops = query.legalMoves.filter { $0.contains("@") }
            #expect(!drops.isEmpty, "aucune pose n'a franchi le filtre — le défaut d'origine")
            #expect(drops.allSatisfy { $0.hasPrefix("P@") }, "seul un pion est en main ici")
            #expect(query.pocket[.white]?[.pawn] == 1, "la réserve doit suivre la FEN")

            // Les coups ordinaires n'ont pas été emportés au passage.
            #expect(query.legalMoves.contains { $0 == "g1f3" }, "Cf3 reste jouable")

            await engine.stop()
        }
    }

    /// Le résumé « Nodes searched: N » ne doit toujours pas passer pour un
    /// coup — c'est ce que la borne de longueur protégeait à l'origine.
    @Test("La ligne de résumé du perft reste écartée")
    func perftSummaryIsStillRejected() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let engine = FairyEngineController()
            try #require(await engine.start(variant: "crazyhouse"))
            let query = try #require(await engine.queryPosition(
                startFEN: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                uciLog: []
            ))
            #expect(query.legalMoves.count == 20, "20 coups au départ, sans résumé parasite")
            #expect(!query.legalMoves.contains { $0.contains("Nodes") })
            await engine.stop()
        }
    }
}

/// Le cycle complet : capturer, tenir la pièce, la poser.
@Suite(.serialized)
@MainActor
struct CrazyhouseGameTests {

    private func game() -> EngineLegalityPlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = PlayerColorChoice.white.rawValue
        settings.showEvalBar = false
        return EngineLegalityPlayViewModel(variant: .crazyhouse, settings: settings)
    }

    @Test("Une capture remplit la réserve, et la pièce se repose")
    func captureFillsPocketAndPieceIsDropped() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))
            try #require(!vm.isEngineUnavailable, "le moteur doit démarrer")

            // 1.e4 d5 2.exd5 : les Blancs capturent un pion.
            for uci in ["e2e4", "d7d5", "e4d5"] {
                await vm.forceMove(uci: uci)
            }
            #expect(vm.userPocket.contains { $0.kind == .pawn && $0.count == 1 },
                    "le pion capturé doit être dans la réserve blanche")
            #expect(vm.sanLog.last == "exd5")

            // Les Noirs reprennent : chacun tient un pion.
            await vm.forceMove(uci: "d8d5")
            #expect(vm.enginePocket.contains { $0.kind == .pawn },
                    "les Noirs tiennent le pion repris")

            // Les Blancs posent leur pion. On choisit une case que le moteur
            // autorise, plutôt que d'en présumer une.
            vm.selectPocketPiece(.pawn)
            #expect(vm.selectedPocketKind == .pawn)
            let target = try #require(vm.legalTargetSquares.first, "aucune case de pose proposée")
            let beforePlies = vm.totalPlies
            await vm.forceMove(uci: "P@" + target.notation)

            #expect(vm.totalPlies == beforePlies + 1, "la pose doit compter comme un coup")
            #expect(vm.sanLog.last?.hasPrefix("P@") == true, "SAN de pose attendu, eu : \(vm.sanLog.last ?? "—")")
            #expect(vm.userPocket.isEmpty, "la réserve blanche doit s'être vidée")
            #expect(vm.displayedBoard.position.piece(at: target)?.kind == .pawn,
                    "le pion posé doit être sur le plateau")

            vm.handleViewDisappear()
        }
    }

    @Test("Choisir une pièce en réserve ne propose que des cases légales")
    func dropTargetsComeFromTheEngine() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = game()
            vm.start()
            try await Task.sleep(for: .seconds(1))
            try #require(!vm.isEngineUnavailable)

            for uci in ["e2e4", "d7d5", "e4d5", "d8d5"] { await vm.forceMove(uci: uci) }
            vm.selectPocketPiece(.pawn)

            #expect(!vm.legalTargetSquares.isEmpty, "des cases de pose doivent être proposées")
            // Règle de Crazyhouse que nous n'écrivons NULLE PART : elle vient
            // du moteur, et doit donc être vraie sans qu'on l'ait codée.
            #expect(vm.legalTargetSquares.allSatisfy { $0.rank.value != 1 && $0.rank.value != 8 },
                    "un pion ne se pose ni en 1re ni en 8e rangée")
            #expect(vm.legalTargetSquares.allSatisfy { vm.displayedBoard.position.piece(at: $0) == nil },
                    "une pose ne va que sur une case vide")

            vm.handleViewDisappear()
        }
    }
}
