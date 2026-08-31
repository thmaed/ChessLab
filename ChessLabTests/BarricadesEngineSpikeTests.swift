import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Sonde : Fairy-Stockfish sait-il jouer Barricades tel qu'on veut le définir ?
///
/// La variante demande deux cases INFRANCHISSABLES et INCAPTURABLES (d4 et e5).
/// Le moteur vendorisé (version 14) n'a AUCUNE notion de case-mur : ni
/// `wallingRule`, ni `*` dans son parseur de FEN, rien dans `position.h`. Il a
/// en revanche tout ce qu'il faut pour en fabriquer une :
///
/// - le type de pièce `immobile`, qui n'a aucun coup (betza vide) ;
/// - `mobilityRegion<Couleur><Pièce>`, qui restreint les cases d'ARRIVÉE d'un
///   type de pièce — et donc interdit d'y capturer quoi que ce soit ;
/// - `pieceValueMg`/`pieceValueEg`, pour que les deux murs ne pèsent rien dans
///   l'évaluation.
///
/// Les deux murs sont BLANCS : les Blancs ne peuvent donc pas les prendre (on
/// ne capture pas ses propres pièces), et il suffit de restreindre les six
/// types de pièces NOIRES pour que personne ne le puisse. Le blocage des
/// pièces glissantes, lui, ne vient pas de `mobilityRegion` (qui n'est qu'un
/// masque d'arrivée, appliqué APRÈS le calcul des attaques — vérifié dans
/// `position.h`, `board_bb(c, pt)`) mais de l'occupation : un mur est une
/// pièce, donc il arrête une ligne comme n'importe quelle autre.
///
/// Cette suite valide chacun de ces points AVANT qu'une ligne d'interface ne
/// soit écrite. `.serialized` : elle démarre un moteur réel.
@Suite(.serialized)
@MainActor
struct BarricadesEngineSpikeTests {

    /// Toutes les cases SAUF d4 et e5, dans la syntaxe des bitboards du
    /// moteur (`*n` = rangée entière, sinon une case à la fois).
    private static let openSquares =
        "*1 *2 *3 a4 b4 c4 e4 f4 g4 h4 a5 b5 c5 d5 f5 g5 h5 *6 *7 *8"

    private static let ini = """
    [barricades:chess]
    immobile = w
    startFen = rnbqkbnr/pppppppp/8/4W3/3W4/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
    pieceValueMg = w:0
    pieceValueEg = w:0
    mobilityRegionBlackPawn = \(openSquares)
    mobilityRegionBlackKnight = \(openSquares)
    mobilityRegionBlackBishop = \(openSquares)
    mobilityRegionBlackRook = \(openSquares)
    mobilityRegionBlackQueen = \(openSquares)
    mobilityRegionBlackKing = \(openSquares)
    """

    private static let startFEN =
        "rnbqkbnr/pppppppp/8/4W3/3W4/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    private func writeINI() throws -> String {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("barricades-spike-\(UUID().uuidString).ini")
        try Self.ini.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    /// Démarre le moteur sur la variante et interroge UNE position.
    ///
    /// Un second essai à chaque étape, et un message qui DIT laquelle a
    /// lâché : sous la charge d'une suite complète, un démarrage ou un
    /// aller-retour de lignes peut manquer son budget sans que le moteur ait
    /// le moindre problème (voir ``FairyEngineController/captureRawLines``).
    /// Un `nil` anonyme laissait croire à un refus de la variante.
    private func query(fen: String, moves: [String] = []) async throws -> FairyEngineController.PositionQuery {
        let path = try writeINI()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let engine = FairyEngineController()
        defer { Task { await engine.stop() } }

        var started = await engine.start(variant: "barricades", variantPath: path)
        if !started {
            started = await engine.start(variant: "barricades", variantPath: path)
        }
        if !started {
            let phase = await engine.lastStartFailure ?? "phase inconnue"
            Issue.record("le moteur n'a pas démarré sur la variante, même au second essai — \(phase)")
        }
        try #require(started)

        var result = await engine.queryPosition(startFEN: fen, uciLog: moves)
        if result == nil {
            result = await engine.queryPosition(startFEN: fen, uciLog: moves)
        }
        return try #require(result, "le moteur n'a pas rendu la position, même au second essai")
    }

    @Test("Le moteur accepte la variante et rend une position lisible")
    func engineLoadsTheVariant() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let query = try await self.query(fen: Self.startFEN)
            // Les murs doivent être DANS la position rendue, sinon le moteur
            // a silencieusement ignoré le `W` et joue aux échecs ordinaires.
            #expect(query.fen.contains("W"), "les murs ont disparu de la position : \(query.fen)")
            #expect(!query.legalMoves.isEmpty)
        }
    }

    @Test("Aucun coup de départ ne se pose sur un mur, et d2-d4 disparaît")
    func noOpeningMoveLandsOnAWall() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let query = try await self.query(fen: Self.startFEN)
            let landings = Set(query.legalMoves.compactMap { $0.count >= 4 ? String($0.dropFirst(2).prefix(2)) : nil })
            #expect(!landings.contains("d4"), "d4 est un mur")
            #expect(!landings.contains("e5"), "e5 est un mur")
            // 20 coups aux échecs, moins la poussée double d2-d4 que le mur
            // interdit. e2-e4 reste jouable : e5 est derrière.
            #expect(query.legalMoves.count == 19, "coups obtenus : \(query.legalMoves.sorted())")
            #expect(query.legalMoves.contains("e2e4"))
            #expect(!query.legalMoves.contains("d2d4"))
        }
    }

    /// Les deux murs sont des PIÈCES blanches : sans `pieceValueMg/Eg = 0`,
    /// le moteur croirait les Blancs en avance de deux pièces dès le premier
    /// coup, et la barre d'évaluation mentirait toute la partie.
    @Test("Les murs ne pèsent rien dans l'évaluation")
    func wallsAreWorthNothing() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            let path = try self.writeINI()
            defer { try? FileManager.default.removeItem(atPath: path) }
            let engine = FairyEngineController()
            try #require(await engine.start(variant: "barricades", variantPath: path))

            await engine.send(.position(.fen(Self.startFEN)))
            await engine.send(.go(movetime: 400))

            var score: Int?
            let deadline = Date().addingTimeInterval(6)
            loop: for await response in await engine.responseStream {
                switch response {
                case let .info(info):
                    if (info.multipv ?? 1) == 1, let cp = EngineScore.moverCentipawns(info) { score = cp }
                case .bestmove:
                    break loop
                default:
                    break
                }
                if Date() > deadline { break }
            }
            await engine.stop()

            let cp = try #require(score, "le moteur n'a rendu aucun score")
            #expect(abs(cp) < 200, "position de départ évaluée à \(cp) cp : les murs pèsent")
        }
    }

    @Test("Une pièce glissante BUTE sur le mur au lieu de le traverser")
    func slidersStopAtTheWall() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // Tour blanche en d1, colonne d vide jusqu'au mur de d4.
            let fen = "4k3/8/8/4W3/3W4/8/8/3RK3 w - - 0 1"
            let query = try await self.query(fen: fen)
            let dFile = query.legalMoves.filter { $0.hasPrefix("d1d") }.sorted()
            #expect(dFile == ["d1d2", "d1d3"], "la tour doit s'arrêter sous le mur : \(dFile)")
        }
    }

    @Test("Un cavalier SAUTE par-dessus le mur, sans pouvoir s'y poser")
    func knightsJumpOverButNeverOnto() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // Cavalier noir en c6 : e5 (mur) lui est interdit, d4 aussi ;
            // mais b4/e7/a5… restent atteignables, et surtout le saut
            // c6→d4 est le seul refusé pour cause de mur, pas de blocage.
            let fen = "4k3/8/2n5/4W3/3W4/8/8/4K3 b - - 0 1"
            let query = try await self.query(fen: fen)
            let knight = query.legalMoves.filter { $0.hasPrefix("c6") }.sorted()
            #expect(!knight.contains("c6d4"), "d4 est un mur")
            #expect(!knight.contains("c6e5"), "e5 est un mur")
            #expect(knight.contains("c6b4"), "les autres sauts restent : \(knight)")
            #expect(knight.contains("c6e7"))
        }
    }

    @Test("Le mur ne se capture pas, même quand une pièce noire l'attaque")
    func wallsCannotBeCaptured() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // Tour noire en d8, colonne d vide : elle descend jusqu'à d5 et
            // s'arrête — d4 lui est refusé.
            let fen = "3rk3/8/8/4W3/3W4/8/8/4K3 b - - 0 1"
            let query = try await self.query(fen: fen)
            let dFile = query.legalMoves.filter { $0.hasPrefix("d8d") }.sorted()
            #expect(dFile == ["d8d5", "d8d6", "d8d7"], "la tour ne doit pas prendre le mur : \(dFile)")
        }
    }

    @Test("Un fou noir bute lui aussi sur le mur")
    func blackBishopStopsAtTheWall() async throws {
        try await EngineIntegrationGate.shared.withExclusiveAccess {
            // Fou noir en g7 : g7-f6-e5 est barré par le mur de e5.
            let fen = "4k3/6b1/8/4W3/3W4/8/8/4K3 b - - 0 1"
            let query = try await self.query(fen: fen)
            let diagonal = query.legalMoves.filter { $0.hasPrefix("g7") }.sorted()
            #expect(diagonal.contains("g7f6"))
            #expect(!diagonal.contains("g7e5"), "e5 est un mur : \(diagonal)")
            #expect(!diagonal.contains("g7d4"), "le fou ne traverse pas : \(diagonal)")
        }
    }
}
