import ChessKit
import Foundation
import Testing
@testable import ChessLab

/// Retour d'un joueur (27/10/2026) : l'app plantait à chaque reprise d'une partie, dans Stockfish. Une FEN
/// qui annonce un droit de roque dont la tour n'est plus dans son coin fait boucler `Position::set` hors de
/// l'échiquier. ChessKit GARDE le droit d'un camp quand sa tour est capturée dans son coin (constaté ici) :
/// ces tests le documentent, et vérifient que ``UCIPositionSanitizer`` y remédie avant le moteur.
struct CastlingRightsTests {

    private func play(_ lans: [String]) -> Board {
        var board = Board(position: .standard)
        for lan in lans {
            let from = Square(String(lan.prefix(2)))
            let to = Square(String(lan.dropFirst(2).prefix(2)))
            guard let move = board.move(pieceAt: from, to: to) else {
                Issue.record("coup illégal \(lan)")
                return board
            }
            if case .promotion = board.state { _ = board.completePromotion(of: move, to: .queen) }
        }
        return board
    }

    private func castlingField(_ board: Board) -> String {
        board.position.fen.split(separator: " ").dropFirst(2).first.map(String.init) ?? "?"
    }

    @Test("La partie du joueur : tour a8 capturée, plus aucun droit de roque noir côté dame")
    func gameThatCrashedTheEngine() {
        let lans = "e2e4 c7c6 d2d4 d7d5 e4e5 c8f5 g1f3 f5g4 f1e2 g4f3 e2f3 e7e6 e1g1 c6c5 c2c4 c5d4 c4d5 e6d5 d1b3 b7b6 b3d5 d8d5 f3d5 f7f6 d5a8 f6e5 c1g5 f8e7 f2f4 h7h6 g5e7 g8e7 f4e5 h8f8 f1f8"
            .split(separator: " ").map(String.init)
        let board = play(lans)
        // ChessKit garde un droit périmé…
        #expect(castlingField(board).contains("q"), "si ChessKit est corrigé un jour, ce garde-fou devient redondant")
        // …et le garde-fou le retire avant le moteur.
        let fixed = UCIPositionSanitizer.castlingFixed(board.position.fen)
        let field = fixed.split(separator: " ").dropFirst(2).first.map(String.init) ?? "?"
        #expect(field == "-", "plus aucun droit : « \(field) »")
    }

    @Test("Une tour prise dans son coin : le droit disparaît avant le moteur")
    func capturingARookRemovesTheRight() {
        // 1.a4 b5 2.axb5 Bb7 3.b6 Nf6 4.b7?? — l'idée : prendre la tour a8 par un pion qui promeut.
        let board = play(["a2a4", "b7b5", "a4b5", "g8f6", "b5b6", "a7a5", "b6b7", "h7h6", "b7a8"])
        let fixed = UCIPositionSanitizer.castlingFixed(board.position.fen)
        let field = fixed.split(separator: " ").dropFirst(2).first.map(String.init) ?? "?"
        #expect(!field.contains("q"), "tour a8 prise par promotion : « \(field) »")
    }
}

struct UCIPositionSanitizerTests {

    @Test("Un droit de roque sans tour dans le coin est retiré avant d'atteindre le moteur")
    func removesRightsWithoutARook() {
        // La FEN réelle qui faisait planter Stockfish : la tour noire a8 a été prise, la h8 a bougé.
        let fen = "Bn2kR2/p3n1p1/1p5p/4P3/3p4/8/PP4PP/RN4K1 b kq - 0 18"
        #expect(UCIPositionSanitizer.castlingFixed(fen) == "Bn2kR2/p3n1p1/1p5p/4P3/3p4/8/PP4PP/RN4K1 b - - 0 18")
    }

    @Test("Les droits encore valides sont conservés")
    func keepsValidRights() {
        let start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        #expect(UCIPositionSanitizer.castlingFixed(start) == start)
        // Une seule tour du camp : seul le droit de son côté reste.
        let oneRook = "r3k3/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
        #expect(UCIPositionSanitizer.castlingFixed(oneRook) == "r3k3/8/8/8/8/8/8/R3K2R w KQq - 0 1")
    }

    @Test("Seule la FEN d'une commande position est touchée, et les coups suivent intacts")
    func onlyPositionCommandsAreRewritten() {
        #expect(UCIPositionSanitizer.sanitize("go depth 12") == "go depth 12")
        #expect(UCIPositionSanitizer.sanitize("position startpos moves e2e4") == "position startpos moves e2e4")
        let line = "position fen 4k3/8/8/8/8/8/8/4K3 w KQkq - 0 1 moves e1e2 e8e7"
        #expect(UCIPositionSanitizer.sanitize(line) == "position fen 4k3/8/8/8/8/8/8/4K3 w - - 0 1 moves e1e2 e8e7")
    }

    @Test("Un échiquier qui n'est pas 8 × 8, ou une lettre de colonne Shredder, ne sont pas touchés")
    func leavesOtherFENsAlone() {
        let shredder = "bbqnnrkr/pppppppp/8/8/8/8/PPPPPPPP/BBQNNRKR w HFhf - 0 1"
        #expect(UCIPositionSanitizer.castlingFixed(shredder) == shredder)
        let wide = "rnbqkbnrr/9/9/9/9/9/9/9/9/RNBQKBNRR w KQkq - 0 1"
        #expect(UCIPositionSanitizer.castlingFixed(wide) == wide)
    }
}
