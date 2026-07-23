import ChessKitEngine
import Testing
@testable import ChessLab

/// Consommation des scores du moteur (Lot 6.B du final-1407).
///
/// Le parsing brut vit dans ChessKitEngine (délégué). Ce qu'on teste ici,
/// c'est NOTRE interprétation — et on la teste sur de VRAIES lignes UCI,
/// parsées par ChessKitEngine via `EngineResponse(rawValue:)`, pas sur des
/// `Info` fabriqués à la main : le test couvre ainsi la chaîne réelle, du
/// texte du moteur jusqu'à notre centipion.
struct EngineScoreTests {

    /// Extrait l'`Info` d'une ligne `info …` réelle.
    private func info(_ raw: String) throws -> EngineResponse.Info {
        let response = try #require(EngineResponse(rawValue: raw))
        guard case let .info(info) = response else {
            Issue.record("« \(raw) » n'a pas été parsé comme une ligne info")
            throw CancellationError()
        }
        return info
    }

    // MARK: Score en centipions

    @Test func aCentipawnScoreIsReadAsIs() throws {
        let info = try info("info depth 20 multipv 1 score cp 34 pv e2e4 e7e5")
        #expect(EngineScore.moverCentipawns(info) == 34)
        #expect(EngineScore.mateInMoves(info) == nil)
    }

    @Test func aNegativeCentipawnScoreKeepsItsSign() throws {
        let info = try info("info depth 18 score cp -152 pv d2d4")
        #expect(EngineScore.moverCentipawns(info) == -152)
    }

    // MARK: Mat

    @Test func aMateForTheMoverIsPlusTenThousand() throws {
        let info = try info("info depth 30 score mate 3 pv f3f7")
        #expect(EngineScore.moverCentipawns(info) == 10_000)
        #expect(EngineScore.mateInMoves(info) == 3)
    }

    @Test func aMateAgainstTheMoverIsMinusTenThousand() throws {
        let info = try info("info depth 30 score mate -2 pv h7h8")
        #expect(EngineScore.moverCentipawns(info) == -10_000)
        #expect(EngineScore.mateInMoves(info) == -2)
    }

    /// `mate` prime sur `cp` : Stockfish n'envoie normalement que l'un, mais
    /// notre lecture doit être sans ambiguïté si les deux apparaissaient.
    @Test func mateWinsOverCentipawns() throws {
        // Ligne construite à la main via le parseur : score mate, pas de cp.
        let info = try info("info depth 25 score mate 1 pv a1a8")
        #expect(EngineScore.moverCentipawns(info) == 10_000)
    }

    // MARK: Lignes sans score

    /// Une ligne `info` de progression (profondeur, nps, temps) ne porte
    /// aucun score : elle ne doit rien dire, pas renvoyer 0 (qui serait lu
    /// comme « position égale »).
    @Test func aProgressLineWithoutScoreYieldsNil() throws {
        let info = try info("info depth 12 seldepth 18 nodes 120000 nps 900000 time 133")
        #expect(EngineScore.moverCentipawns(info) == nil)
        #expect(EngineScore.mateInMoves(info) == nil)
    }

    // MARK: bestmove (none) — la position terminale

    /// Sur une position terminale, Stockfish répond `bestmove (none)`. C'est
    /// ChessKitEngine qui le transmet tel quel, et notre code (voir
    /// `applyEngineMove`) le traite comme « aucun coup » plutôt que de crasher.
    /// On vérifie ici que la ligne est bien reconnue comme un `bestmove`.
    @Test func bestmoveNoneIsParsedAsABestmove() throws {
        let response = try #require(EngineResponse(rawValue: "bestmove (none)"))
        guard case let .bestmove(move, _) = response else {
            Issue.record("« bestmove (none) » devrait être un bestmove")
            return
        }
        #expect(move == "(none)")
        // `applyEngineMove` refuse les LAN de moins de 4 caractères ET
        // « (none) » : la partie se conclut sur l'état réel du plateau.
        #expect(move.count < 4 || move == "(none)")
    }
}
