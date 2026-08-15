import ChessKit
import Testing
@testable import ChessLab

/// Le détecteur ne doit JAMAIS nommer un motif qui n'est pas là : dans une app
/// d'apprentissage, une explication inventée s'apprend aussi bien qu'une vraie.
/// Chaque test part donc d'une position construite à la main, où le motif
/// attendu — ou son absence — est vérifiable à l'œil.
struct TacticalMotifDetectorTests {

    /// Joue un coup en LAN sur une position et rend `(coup, plateau après)`.
    private func play(_ lan: String, from fen: String) throws -> (move: Move, board: Board) {
        let position = try #require(Position(fen: fen))
        var board = Board(position: position)
        let start = Square(String(lan.prefix(2)))
        let end = Square(String(lan.dropFirst(2).prefix(2)))
        // `move(pieceAt:to:)` est `mutating` : l'appeler DANS `#require` le
        // ferait passer par la fermeture immuable de la macro, qui refuse.
        let played = board.move(pieceAt: start, to: end)
        return (try #require(played), board)
    }

    // MARK: Fourchette

    @Test func detectsAFork() throws {
        // Cavalier c5 → e6 : attaque à la fois la dame d8 et la tour c7.
        let (move, board) = try play("c5e6", from: "3q2k1/2r5/8/2N5/8/8/8/4K3 w - - 0 1")
        let motif = TacticalMotifDetector.detect(punishing: move, boardAfter: board)
        #expect(motif == .fork(by: .knight, on: .e6, targets: [.queen, .rook]))
    }

    @Test func namesTheKingFirstInARoyalFork() throws {
        // Même cavalier, mais c'est le ROI qui est en f8 : la fourchette royale
        // se raconte en commençant par le roi, qui est la menace qui compte.
        let (move, board) = try play("c5e6", from: "5k2/2r5/8/2N5/8/8/8/4K3 w - - 0 1")
        let motif = TacticalMotifDetector.detect(punishing: move, boardAfter: board)
        #expect(motif == .fork(by: .knight, on: .e6, targets: [.king, .rook]))
    }

    @Test func doesNotCallASingleAttackAFork() throws {
        // Une seule cible : ce n'est pas une fourchette, et le détecteur ne doit
        // pas se rabattre dessus faute de mieux.
        let (move, board) = try play("c5e6", from: "3q2k1/8/8/2N5/8/8/8/4K3 w - - 0 1")
        if case .fork = TacticalMotifDetector.detect(punishing: move, boardAfter: board) {
            Issue.record("une attaque simple a été prise pour une fourchette")
        }
    }

    // MARK: Pièce en prise

    @Test func detectsAHangingPiece() throws {
        // Dame a1 prend le cavalier h8 : le roi noir est en b8, rien ne reprend.
        let (move, board) = try play("a1h8", from: "1k5n/8/8/8/8/8/8/Q3K3 w - - 0 1")
        let motif = TacticalMotifDetector.detect(punishing: move, boardAfter: board)
        #expect(motif == .hangingPiece(kind: .knight, on: .h8))
    }

    @Test func doesNotCallAnExchangeAHangingPiece() throws {
        // Même prise, mais le roi noir est en g8 et REPREND : c'est un échange,
        // pas une pièce oubliée en prise.
        let (move, board) = try play("a1h8", from: "6kn/8/8/8/8/8/8/Q3K3 w - - 0 1")
        #expect(TacticalMotifDetector.detect(punishing: move, boardAfter: board) == nil)
    }

    // MARK: Échec à la découverte

    @Test func detectsADiscoveredCheck() throws {
        // Le cavalier e4 s'écarte en c5 : c'est la TOUR e1 qui donne l'échec.
        let (move, board) = try play("e4c5", from: "4k3/8/8/8/4N3/8/8/4R1K1 w - - 0 1")
        let motif = TacticalMotifDetector.detect(punishing: move, boardAfter: board)
        #expect(motif == .discoveredCheck(by: .rook))
    }

    @Test func doesNotCallADirectCheckDiscovered() throws {
        // La tour e1 monte en e7 : elle donne l'échec elle-même. Rien de
        // « découvert » — et c'est le piège classique de cette détection.
        let (move, board) = try play("e1e7", from: "4k3/8/8/8/8/8/8/4R1K1 w - - 0 1")
        #expect(TacticalMotifDetector.detect(punishing: move, boardAfter: board) == nil)
    }

    // MARK: Clouage

    @Test func detectsAnAbsolutePin() throws {
        // Fou f1 → b5 : le cavalier c6 est cloué devant le roi e8.
        let (move, board) = try play("f1b5", from: "4k3/8/2n5/8/8/8/8/5BK1 w - - 0 1")
        let motif = TacticalMotifDetector.detect(punishing: move, boardAfter: board)
        #expect(motif == .pin(victim: .knight, behind: .king))
    }

    @Test func doesNotCallAKingInFrontOfNothingAPin() throws {
        // Même fou en b5, mais SANS cavalier en c6 : le roi e8 est directement
        // sur la diagonale, donc simplement en échec. Un roi n'est pas cloué —
        // c'est le piège de cette détection, la première pièce du rayon doit
        // être écartée quand c'est le roi.
        let (move, board) = try play("f1b5", from: "4k3/8/8/8/8/8/8/5BK1 w - - 0 1")
        if case .pin = TacticalMotifDetector.detect(punishing: move, boardAfter: board) {
            Issue.record("un roi en échec a été pris pour une pièce clouée")
        }
    }

    // MARK: Mat du couloir

    @Test func recognizesABackRankMate() throws {
        // Dame d1 → d8 : le roi g8 étouffe derrière ses pions f7/g7/h7.
        let (_, board) = try play("d1d8", from: "6k1/5ppp/8/8/8/8/8/3QK3 w - - 0 1")
        #expect(TacticalMotifDetector.isBackRankMate(of: .black, board: board))
    }

    @Test func doesNotCallAnOpenBoardMateABackRankMate() throws {
        // Même mat sur la rangée de fond, mais le roi a de l'air devant lui
        // (pas de pion en g7) : ce n'est pas le motif du couloir.
        let (_, board) = try play("d1d8", from: "6k1/5p1p/8/8/8/8/6Q1/3QK3 w - - 0 1")
        #expect(!TacticalMotifDetector.isBackRankMate(of: .black, board: board))
    }
}
