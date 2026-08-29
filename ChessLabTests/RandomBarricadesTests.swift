import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Barricades ALÉATOIRES : deux murs qui changent de case à chaque demi-coup.
///
/// Deux mécanismes lui sont propres, et aucun des deux ne pouvait être repris
/// de la variante fixe :
///
/// - la position ne se REJOUE pas depuis le départ, le tirage des murs ne
///   figurant dans aucun coup — la vue-modèle enchaîne de position en
///   position ;
/// - `mobilityRegion` étant figé par variante, il ne peut pas suivre des murs
///   mobiles : les prises de mur sont retirées de la liste du moteur.
@Suite(.serialized)
@MainActor
struct RandomBarricadesTests {

    // MARK: Le tirage des murs

    @Test("Trois murs, sur des cases vides des rangées 2 à 7")
    func wallsLandOnEmptySquaresInTheMiddle() throws {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<50 {
            let fen = BarricadesConfiguration.openingPosition(using: &generator)
            let walls = BarricadesFEN.wallSquares(in: fen)
            #expect(walls.count == 3, "il en faut exactement trois : \(fen)")
            #expect(Set(walls).count == 3, "et sur trois cases DIFFÉRENTES")
            for wall in walls {
                #expect((2...7).contains(wall.rank.value), "\(wall.notation) hors des rangées 2 à 7")
            }
            // Aucune pièce écrasée : le plateau garde ses 32 pièces.
            let board = try #require(Position(fen: BarricadesFEN.forChessKit(fen)))
            #expect(board.pieces.count == 32, "un mur s'est posé sur une pièce : \(fen)")
        }
    }

    /// Le cœur de la variante : à CHAQUE coup, deux des trois murs bougent et
    /// le troisième reste — mais ce n'est pas toujours le même qui reste.
    @Test("Deux murs sur trois bougent, et celui qui reste change")
    func twoOfThreeMoveAndTheStayerVaries() throws {
        var generator = SystemRandomNumberGenerator()
        var fen = BarricadesConfiguration.openingPosition(using: &generator)
        var stayers: Set<Square> = []

        for _ in 0..<40 {
            let before = Set(BarricadesFEN.wallSquares(in: fen))
            try #require(before.count == 3)
            fen = try #require(BarricadesConfiguration.relocatingWalls(in: fen, using: &generator))
            let after = Set(BarricadesFEN.wallSquares(in: fen))

            #expect(after.count == 3, "ils s'accumulent ou s'évaporent : \(fen)")
            let kept = before.intersection(after)
            #expect(kept.count == 1, "il doit rester EXACTEMENT un mur en place : \(kept)")
            #expect(after.subtracting(before).count == 2, "les deux autres doivent avoir changé de case")
            stayers.formUnion(kept)
        }
        // Sur quarante coups, le mur épargné ne peut pas être toujours le
        // même : ce serait un mur fixe, et ce n'est pas la règle.
        #expect(stayers.count > 1, "c'est toujours le même mur qui reste — il est donc fixe")
    }

    @Test("Le tirage ne touche ni la première ni la dernière rangée")
    func wallsNeverReachTheBackRanks() throws {
        var generator = SystemRandomNumberGenerator()
        // Un plateau presque vide : le tirage a beaucoup de place, et
        // pourrait déborder si la borne était mal posée.
        let sparse = "4k3/8/8/8/8/8/8/4K3 w - - 0 1"
        for _ in 0..<100 {
            let fen = try #require(BarricadesConfiguration.relocatingWalls(in: sparse, using: &generator))
            for wall in BarricadesFEN.wallSquares(in: fen) {
                #expect(wall.rank.value != 1 && wall.rank.value != 8, "\(wall.notation) sur une rangée de départ")
            }
        }
    }

    @Test("Chaque partie commence sur un tirage différent")
    func everyGameOpensDifferently() {
        let openings = Set(
            (0..<30).map { _ in EngineLegalityVariant.randomBarricades.initialPosition() }
        )
        #expect(openings.count > 1, "toutes les parties commencent au même endroit")
        for fen in openings {
            #expect(BarricadesFEN.wallSquares(in: fen).count == 3)
        }
    }

    // MARK: Les murs ne se prennent pas

    @Test("Les coups qui prennent un mur sont retirés de la liste du moteur")
    func wallCapturesAreRemoved() {
        let fen = "4k3/8/8/3W4/8/8/8/3RK3 w - - 0 1"
        let fromEngine = ["d1d2", "d1d3", "d1d4", "d1d5", "e1e2", "d1c1"]
        let kept = EngineLegalityVariant.randomBarricades.removingWallCaptures(from: fromEngine, in: fen)
        #expect(!kept.contains("d1d5"), "d5 porte un mur")
        #expect(kept.contains("d1d4"))
        #expect(kept.count == fromEngine.count - 1)
    }

    @Test("La variante FIXE ne filtre rien : son moteur s'en charge déjà")
    func staticVariantDoesNotFilter() {
        let moves = ["d1d4", "e1e2"]
        #expect(EngineLegalityVariant.barricades.removingWallCaptures(
            from: moves, in: BarricadesConfiguration.startFEN
        ) == moves)
    }

    @Test("Une seule variante réécrit sa position à chaque coup")
    func onlyTheRandomVariantRewrites() {
        for variant in EngineLegalityVariant.all {
            let expected = variant.id == EngineLegalityVariant.randomBarricades.id
            #expect(variant.rewritesPositionEachMove == expected, "\(variant.id)")
        }
    }

    // MARK: Une vraie partie

    private func game() -> EngineLegalityPlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = PlayerColorChoice.white.rawValue
        settings.eloSliderValue = 1400
        settings.showEvalBar = false
        settings.blunderAlertEnabled = false
        return EngineLegalityPlayViewModel(variant: .randomBarricades, settings: settings)
    }

    /// Un coup légal QUELCONQUE de la position courante.
    ///
    /// Écrire `e2e4` en dur ne marche pas ici : les murs tombent au hasard, et
    /// l'un d'eux peut parfaitement occuper e3 ou e4 dès l'ouverture. Un test
    /// qui insiste échoue sur le comportement VOULU.
    private func anyLegalMove(_ vm: EngineLegalityPlayViewModel) -> (from: Square, to: Square)? {
        for square in DuckChessRules.allSquares {
            vm.selectSquare(square)
            if let target = vm.legalTargetSquares.first {
                return (square, target)
            }
        }
        return nil
    }

    /// Joue un coup utilisateur puis attend la réponse de l'ordinateur.
    private func playOneExchange(_ vm: EngineLegalityPlayViewModel) async throws {
        let move = try #require(self.anyLegalMove(vm), "aucun coup légal à l'ouverture")
        vm.attemptUserMove(from: move.from, to: move.to)
        let deadline = Date().addingTimeInterval(40)
        while Date() < deadline, vm.totalPlies < 2 {
            try await Task.sleep(for: .milliseconds(200))
        }
        try #require(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")
    }

    @Test("Les murs bougent d'un coup à l'autre, et la partie suit")
    func wallsMoveBetweenPlies() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game()
            vm.start()
            try await EngineIntegrationGate.waitUntilReady(vm)

            let opening = Set(vm.displayedBlockedSquares)
            #expect(opening.count == 3, "la partie s'ouvre déjà murée, trois fois")
            #expect(vm.displayedBoard.position.pieces.count == 32, "les murs ne sont pas des pièces")

            // Aucun coup proposé nulle part ne se pose sur un mur.
            for square in DuckChessRules.allSquares {
                vm.selectSquare(square)
                for target in vm.legalTargetSquares {
                    #expect(!opening.contains(target), "\(target.notation) porte un mur")
                }
            }

            try await self.playOneExchange(vm)

            // Deux murs à chaque demi-coup journalisé, et ils ne restent pas
            // en place d'un bout à l'autre.
            var seen: Set<Set<Square>> = []
            for fen in vm.fenLog {
                let walls = Set(BarricadesFEN.wallSquares(in: fen))
                #expect(walls.count == 3, "trois murs attendus dans \(fen)")
                seen.insert(walls)
            }
            #expect(seen.count > 1, "les murs n'ont pas bougé de la partie")

            vm.handleViewDisappear()
        }
    }

    @Test("Reprendre un coup restitue les murs de l'époque")
    func takebackRestoresTheWallsOfThatPly() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game()
            vm.start()
            try await EngineIntegrationGate.waitUntilReady(vm)

            try await self.playOneExchange(vm)
            let wallsAtPly1 = Set(BarricadesFEN.wallSquares(in: vm.fenLog[1]))

            vm.review(toPly: 1)
            #expect(Set(vm.displayedBlockedSquares) == wallsAtPly1,
                    "la consultation doit montrer les murs de ce coup-là")

            vm.handleViewDisappear()
        }
    }
}
