import ChessKit
import Testing
@testable import ChessLab

/// Les règles du Duck Chess, seule variante du hub dont la légalité est
/// calculée EN SWIFT — aucun moteur ne la connaît, donc aucun arbitre
/// extérieur ne rattrapera une erreur ici. D'où des tests serrés.
@Suite
struct DuckChessRulesTests {

    private func position(_ fen: String) -> Position {
        Position(fen: fen)!
    }

    private let start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    // MARK: Sans canard, on retrouve les échecs ordinaires

    @Test("Position de départ, canard absent : 20 coups, comme aux échecs")
    func openingHasTwentyMoves() {
        let moves = DuckChessRules.moves(in: position(start), duck: nil)
        #expect(moves.count == 20)
    }

    // MARK: Le canard bloque

    @Test("Le canard occupe une case : rien ne s'y pose")
    func duckSquareIsUnreachable() {
        let moves = DuckChessRules.moves(in: position(start), duck: Square("e4"))
        #expect(!moves.contains { $0.to == Square("e4") }, "e4 est sous le canard")
        // Le pion e2 garde sa poussée simple.
        #expect(moves.contains { $0.from == Square("e2") && $0.to == Square("e3") })
    }

    @Test("Le canard barre la poussée double d'un pion")
    func duckBlocksDoublePush() {
        let moves = DuckChessRules.moves(in: position(start), duck: Square("e3"))
        #expect(!moves.contains { $0.from == Square("e2") }, "e3 bloqué : le pion e2 ne bouge plus du tout")
    }

    @Test("Le canard arrête une pièce à distance, sans se faire capturer")
    func duckStopsSliders() {
        // Tour blanche en a1, colonne a vide, canard en a5.
        let fen = "4k3/8/8/8/8/8/8/R3K3 w - - 0 1"
        let moves = DuckChessRules.moves(in: position(fen), duck: Square("a5"))
            .filter { $0.from == Square("a1") }
        let targets = Set(moves.map(\.to))
        #expect(targets.contains(Square("a4")), "la tour monte jusqu'au canard")
        #expect(!targets.contains(Square("a5")), "elle ne prend PAS le canard")
        #expect(!targets.contains(Square("a6")), "et ne le traverse pas")
    }

    // MARK: Ni échec, ni mat — on capture le roi

    @Test("Un roi a le droit de se mettre en prise")
    func kingMayMoveIntoAttack() {
        // Roi blanc e1, tour noire e8 : aux échecs, Re2 serait illégal.
        let fen = "4r2k/8/8/8/8/8/8/4K3 w - - 0 1"
        let moves = DuckChessRules.moves(in: position(fen), duck: nil)
        #expect(moves.contains { $0.from == Square("e1") && $0.to == Square("e2") },
                "en Duck Chess, la notion d'échec n'existe pas")
    }

    @Test("La capture du roi est un coup comme un autre, et désigne le vainqueur")
    func kingCaptureIsTheWinCondition() {
        // Tour blanche e7, roi noir e8.
        let fen = "4k3/4R3/8/8/8/8/8/4K3 w - - 0 1"
        let pos = position(fen)
        let capture = DuckChessRules.Move(from: Square("e7"), to: Square("e8"))
        #expect(DuckChessRules.moves(in: pos, duck: nil).contains(capture))
        #expect(DuckChessRules.capturesKing(capture, in: pos) == .black)
        // Un coup ordinaire ne termine rien.
        #expect(DuckChessRules.capturesKing(
            DuckChessRules.Move(from: Square("e7"), to: Square("e6")), in: pos) == nil)
    }

    // MARK: Roque

    @Test("Le roque reste possible, et le canard peut l'empêcher")
    func castlingRespectsTheDuck() {
        let fen = "4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1"
        let free = DuckChessRules.moves(in: position(fen), duck: nil)
            .filter { $0.from == Square("e1") }
        #expect(free.contains { $0.to == Square("g1") }, "petit roque")
        #expect(free.contains { $0.to == Square("c1") }, "grand roque")

        // Canard en f1 : le petit roque tombe, le grand reste.
        let blocked = DuckChessRules.moves(in: position(fen), duck: Square("f1"))
            .filter { $0.from == Square("e1") }
        #expect(!blocked.contains { $0.to == Square("g1") }, "f1 occupé par le canard")
        #expect(blocked.contains { $0.to == Square("c1") })
    }

    @Test("Sans droit de roque, pas de roque")
    func castlingNeedsRights() {
        let fen = "4k3/8/8/8/8/8/8/R3K2R w - - 0 1"
        let moves = DuckChessRules.moves(in: position(fen), duck: nil).filter { $0.from == Square("e1") }
        #expect(!moves.contains { $0.to == Square("g1") })
        #expect(!moves.contains { $0.to == Square("c1") })
    }

    // MARK: Pions

    @Test("La promotion propose les quatre pièces")
    func promotionOffersFourPieces() {
        let fen = "4k3/P7/8/8/8/8/8/4K3 w - - 0 1"
        let moves = DuckChessRules.moves(in: position(fen), duck: nil)
            .filter { $0.from == Square("a7") }
        #expect(moves.count == 4)
        #expect(Set(moves.compactMap(\.promotion)) == [.queen, .rook, .bishop, .knight])
    }

    @Test("Un pion ne capture pas le canard en diagonale")
    func pawnDoesNotCaptureTheDuck() {
        let fen = "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1"
        let moves = DuckChessRules.moves(in: position(fen), duck: Square("d3"))
            .filter { $0.from == Square("e2") }
        #expect(!moves.contains { $0.to == Square("d3") }, "le canard ne se capture pas")
    }

    @Test("La prise en passant reste jouable")
    func enPassantWorks() {
        let fen = "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1"
        let moves = DuckChessRules.moves(in: position(fen), duck: nil, enPassant: Square("d6"))
            .filter { $0.from == Square("e5") }
        #expect(moves.contains { $0.to == Square("d6") })
    }

    // MARK: Le canard lui-même

    @Test("Le canard se pose sur une case vide, et doit bouger")
    func duckMustMoveToAnEmptySquare() {
        let targets = DuckChessRules.duckTargets(in: position(start), currentDuck: Square("e4"))
        #expect(!targets.contains(Square("e4")), "il doit changer de case")
        #expect(!targets.contains(Square("e2")), "pas sur une pièce")
        #expect(targets.contains(Square("e3")))
        // 64 cases − 32 pièces − la case du canard.
        #expect(targets.count == 31)
    }
}
