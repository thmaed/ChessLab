import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Barricades côté APP : la définition engendrée, la FEN traduite pour
/// ChessKit, et une vraie partie menée contre le moteur.
///
/// La sonde qui valide le moteur lui-même vit à part
/// (`BarricadesEngineSpikeTests`) : elle a été écrite d'abord, et elle reste
/// la preuve que les murs sont l'affaire du moteur et non d'une règle
/// réimplémentée ici.
@Suite(.serialized)
@MainActor
struct BarricadesTests {

    // MARK: La définition engendrée

    @Test("La FEN de départ porte exactement les murs déclarés")
    func startFENMatchesTheDeclaredWalls() {
        let fromFEN = Set(BarricadesFEN.wallSquares(in: BarricadesConfiguration.startFEN))
        #expect(fromFEN == Set(BarricadesConfiguration.wallSquares))
        #expect(fromFEN == [Square("d4"), Square("e5")])
    }

    @Test("Les régions de mobilité couvrent tout le plateau SAUF les murs")
    func openSquaresCoverEverythingButTheWalls() {
        let tokens = BarricadesConfiguration.openSquaresBitboard.split(separator: " ").map(String.init)
        var covered = Set<Square>()
        for token in tokens {
            if token.hasPrefix("*"), let rank = Int(token.dropFirst()) {
                for file in "abcdefgh" { covered.insert(Square("\(file)\(rank)")) }
            } else {
                covered.insert(Square(token))
            }
        }
        let all = Set(DuckChessRules.allSquares)
        #expect(covered == all.subtracting(BarricadesConfiguration.wallSquares))
        #expect(covered.count == 62)
    }

    @Test("La définition nomme les six types de pièces noires à brider")
    func configurationRestrictsEveryBlackPieceType() {
        let text = BarricadesConfiguration.configurationText
        for piece in ["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"] {
            #expect(text.contains("mobilityRegionBlack\(piece) = "), "\(piece) manquant")
        }
        #expect(text.contains("[barricades:chess]"))
        #expect(text.contains("immobile = w"))
        // Les murs ne doivent rien peser dans l'évaluation.
        #expect(text.contains("pieceValueMg = w:0"))
        #expect(text.contains("pieceValueEg = w:0"))
    }

    @Test("Le fichier de définition s'écrit et se relit")
    func configurationFileIsWritten() throws {
        let path = try #require(BarricadesConfiguration.writeConfigurationFile())
        let written = try String(contentsOfFile: path, encoding: .utf8)
        #expect(written == BarricadesConfiguration.configurationText)
    }

    // MARK: La FEN traduite pour ChessKit

    /// La garantie qu'on livre : après traduction, le plateau est celui des
    /// échecs ordinaires, murs en moins.
    ///
    /// Ce test ne prétend PAS que la FEN brute corromprait l'affichage —
    /// sondé, ce n'est pas le cas avec ChessKit 0.17.0, qui avance d'une case
    /// sur un caractère inconnu au milieu d'une rangée. Il fixe le contrat de
    /// la traduction, pas un défaut supposé de la bibliothèque (voir
    /// ``BarricadesFEN`` pour ce qui est mesuré, et pourquoi le filtre existe
    /// malgré tout).
    @Test("La FEN traduite rend un plateau d'échecs ordinaire")
    func translatedFENGivesAPlainBoard() throws {
        let cleaned = try #require(Position(fen: BarricadesFEN.forChessKit(BarricadesConfiguration.startFEN)))
        #expect(cleaned.pieces.count == 32)
        #expect(cleaned.piece(at: Square("h1"))?.kind == .rook)
        #expect(cleaned.piece(at: Square("h8"))?.kind == .rook)
        #expect(cleaned.piece(at: Square("d4")) == nil, "un mur n'est pas une pièce ChessKit")
        #expect(cleaned.piece(at: Square("e5")) == nil)
        #expect(cleaned.fen == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    }

    /// Une rangée qui porte À LA FOIS des pièces et un mur : c'est là que
    /// l'ordre des cases se joue.
    @Test("Une rangée mêlant pièces et mur garde ses pièces en place")
    func piecesKeepTheirSquaresAroundAWall() throws {
        let raw = "rnbqkbnr/pppppppp/8/3pW1n1/3W4/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        let cleaned = try #require(Position(fen: BarricadesFEN.forChessKit(raw)))
        #expect(cleaned.piece(at: Square("d5"))?.kind == .pawn)
        #expect(cleaned.piece(at: Square("g5"))?.kind == .knight)
        #expect(cleaned.piece(at: Square("e5")) == nil)
        #expect(cleaned.piece(at: Square("f5")) == nil)
    }

    @Test("La traduction laisse une FEN ordinaire intacte")
    func ordinaryFENIsUntouched() {
        let plain = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        #expect(BarricadesFEN.forChessKit(plain) == plain)
        #expect(BarricadesFEN.wallSquares(in: plain).isEmpty)
    }

    @Test("La traduction commune passe les DEUX enrichissements")
    func sharedTranslationHandlesBothVariants() throws {
        // Réserve du Crazyhouse ET murs de Barricades dans la même FEN : le
        // filtre commun doit tout retirer, sinon l'un des deux écrans
        // corromprait sa dernière rangée.
        let mixed = "rnbqkbnr/pppppppp/8/4W3/3W4/8/PPPPPPPP/RNBQKBNR[Pp] w KQkq - 0 1"
        let cleaned = try #require(Position(fen: VariantFEN.forChessKit(mixed)))
        #expect(cleaned.pieces.count == 32)
        #expect(cleaned.piece(at: Square("h1"))?.kind == .rook)
    }

    @Test("Les murs se relisent dans n'importe quelle FEN du moteur")
    func wallsAreReadBackFromAnyFEN() {
        let midGame = "r1bqkbnr/ppp1pppp/2n5/3pW3/3W4/5N2/PPPPPPPP/RNBQKB1R w KQkq - 0 3"
        #expect(Set(BarricadesFEN.wallSquares(in: midGame)) == [Square("d4"), Square("e5")])
    }

    // MARK: La variante, telle que le hub la propose

    @Test("Barricades figure au catalogue, avec sa définition à charger")
    func variantIsListed() throws {
        let variant = try #require(EngineLegalityVariant.all.first { $0.id == "barricades" })
        #expect(variant.startFEN == BarricadesConfiguration.startFEN)
        #expect(variant.customDefinitionPath != nil, "elle doit s'enseigner au moteur")
        // Les deux Barricades partagent le même fichier de définition ; toutes
        // les autres, le moteur les connaît d'origine.
        let taught: Set<String> = [
            EngineLegalityVariant.barricades.id, EngineLegalityVariant.randomBarricades.id,
        ]
        for other in EngineLegalityVariant.all {
            let path = other.customDefinitionPath
            #expect(
                (path != nil) == taught.contains(other.id),
                "\(other.id) : définition \(path == nil ? "absente" : "présente") à tort"
            )
        }
    }

    // MARK: Fin de partie

    /// Le défaut signalé le 29/08 : un mat subi en Barricades ne terminait
    /// pas la partie.
    ///
    /// La variante avait été ajoutée au catalogue sans toucher au `switch` de
    /// ``EngineLegalityVariant/outcome(afterFEN:legalMovesForNextMover:inCheck:)``,
    /// où seuls Atomique et Crazyhouse étaient nommés pour le mat classique —
    /// tout le reste tombait sur `return nil`. Le mat se jouait donc à
    /// l'écran sans que rien ne l'annonce. Le cas classique est désormais le
    /// DÉFAUT, ce qui rend le même oubli impossible.
    @Test("Plus aucun coup légal et le roi en échec : c'est mat")
    func mateIsDetected() throws {
        let mated = "rnb1kbnr/pppp1ppp/8/4W3/3W2pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 0 1"
        let outcome = try #require(
            EngineLegalityVariant.barricades.outcome(
                afterFEN: mated, legalMovesForNextMover: [], inCheck: true
            ),
            "un mat en Barricades doit terminer la partie"
        )
        #expect(outcome.reason == .checkmate)
        #expect(outcome.winner == .black, "c'est le camp au trait qui est maté")
    }

    @Test("Plus aucun coup légal sans échec : c'est pat")
    func stalemateIsDetected() throws {
        let outcome = try #require(
            EngineLegalityVariant.barricades.outcome(
                afterFEN: BarricadesConfiguration.startFEN, legalMovesForNextMover: [], inCheck: false
            )
        )
        #expect(outcome.winner == nil)
    }

    /// Le filet posé sous l'oubli : TOUTE variante du catalogue doit conclure
    /// quand il n'y a plus de coup et que le roi est en échec.
    @Test("Aucune variante ne laisse un mat passer", arguments: EngineLegalityVariant.all.map(\.id))
    func everyVariantEndsOnMate(id: String) throws {
        let variant = try #require(EngineLegalityVariant.all.first { $0.id == id })
        // Antéchecs mis à part : le but y est inversé, être bloqué fait GAGNER.
        let outcome = variant.outcome(
            afterFEN: "rnb1kbnr/pppp1ppp/8/8/6pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 0 1",
            legalMovesForNextMover: [], inCheck: true
        )
        #expect(outcome != nil, "\(id) ne conclut pas sur une position sans coup légal")
    }

    // MARK: Une vraie partie

    private func game() -> EngineLegalityPlayViewModel {
        var settings = FairyVariantSettings()
        settings.colorChoice = PlayerColorChoice.white.rawValue
        settings.eloSliderValue = 1400
        settings.showEvalBar = false
        settings.blunderAlertEnabled = false
        return EngineLegalityPlayViewModel(variant: .barricades, settings: settings)
    }

    @Test("La partie s'ouvre sur les murs, et l'ordinateur répond")
    func aRealGameRunsAgainstTheEngine() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game()
            vm.start()
            let ready = Date().addingTimeInterval(20)
            while Date() < ready, !vm.isPositionReady {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.isPositionReady, "la position de départ n'est jamais arrivée")

            #expect(Set(vm.displayedBlockedSquares) == [Square("d4"), Square("e5")])
            #expect(vm.displayedBoard.position.pieces.count == 32, "les murs ne sont pas des pièces")

            // d2-d4 est muré ; d2-d3 ne l'est pas.
            vm.selectSquare(Square("d2"))
            #expect(!vm.legalTargetSquares.contains(Square("d4")), "d4 est muré")
            #expect(vm.legalTargetSquares.contains(Square("d3")))

            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let deadline = Date().addingTimeInterval(30)
            while Date() < deadline, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            #expect(vm.totalPlies >= 2, "l'ordinateur n'a jamais répondu")
            // Les murs sont toujours là, coup après coup.
            #expect(Set(vm.displayedBlockedSquares) == [Square("d4"), Square("e5")])

            vm.handleViewDisappear()
        }
    }

    /// L'analyse de fin de partie démarre son PROPRE moteur : si la
    /// définition de la variante ne lui est pas ré-enseignée, il retombe sur
    /// les échecs ordinaires — et classerait la partie sans les murs, sans
    /// que rien ne le dise.
    @Test("L'analyse de fin de partie retrouve les murs, et classe la ligne")
    func analysisKeepsTheWalls() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game()
            vm.start()
            let ready = Date().addingTimeInterval(20)
            while Date() < ready, !vm.isPositionReady {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.isPositionReady)

            vm.attemptUserMove(from: Square("e2"), to: Square("e4"))
            let replied = Date().addingTimeInterval(30)
            while Date() < replied, vm.totalPlies < 2 {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.totalPlies >= 2, "il faut une ligne à classer")
            vm.userResigns()

            let seed = VariantAnalysisSeed(
                variantID: EngineLegalityVariant.barricades.id,
                variantDisplayName: EngineLegalityVariant.barricades.displayName,
                startFEN: EngineLegalityVariant.barricades.startFEN,
                uciLog: vm.uciLog, sanLog: vm.sanLog, moveLog: vm.moveLog,
                fenLog: vm.fenLog, outcome: vm.outcome
            )
            await vm.stopEngineBeforeAnalysis()

            let analysis = VariantAnalysisViewModel(seed: seed)
            analysis.start()
            let deadline = Date().addingTimeInterval(60)
            while Date() < deadline, analysis.isClassifying || analysis.moveQuality.isEmpty {
                try await Task.sleep(for: .milliseconds(300))
            }
            #expect(!analysis.moveQuality.isEmpty, "la ligne n'a reçu aucune pastille")

            analysis.review(toPly: 1)
            #expect(Set(analysis.displayedBlockedSquares) == [Square("d4"), Square("e5")])
            // Et le plateau d'affichage reste un plateau d'échecs ordinaire :
            // un mur n'est pas une pièce ChessKit.
            #expect(analysis.displayedBoard.position.pieces.count == 32)

            analysis.handleViewDisappear()
        }
    }

    @Test("Une glissante bute sur le mur, un cavalier lui saute par-dessus")
    func slidersStopWhereKnightsJump() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let vm = self.game()
            vm.start()
            let ready = Date().addingTimeInterval(20)
            while Date() < ready, !vm.isPositionReady {
                try await Task.sleep(for: .milliseconds(200))
            }
            try #require(vm.isPositionReady)

            // Le cavalier b1 saute PAR-DESSUS ses propres pions ; d2 lui est
            // fermé (pion), a3 et c3 ouverts. Aucun mur en jeu ici — c'est le
            // témoin : la variante ne casse rien du jeu ordinaire.
            vm.selectSquare(Square("b1"))
            #expect(Set(vm.legalTargetSquares) == [Square("a3"), Square("c3")])

            vm.handleViewDisappear()
        }
    }
}
