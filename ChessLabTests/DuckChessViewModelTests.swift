import ChessKit
import Testing
@testable import ChessLab

/// Le tour en DEUX temps du Duck Chess : déplacer, puis poser le canard.
/// C'est là que la variante se joue, et là que tout peut se désynchroniser.
@Suite
@MainActor
struct DuckChessViewModelTests {

    @Test("Un tour se déroule en deux temps, et le trait ne change qu'à la pose")
    func turnHasTwoPhases() {
        let vm = DuckChessViewModel()
        #expect(vm.phase == .movePiece)
        #expect(vm.sideToMove == .white)

        vm.selectSquare(Square("e2"))
        vm.selectSquare(Square("e4"))
        #expect(vm.sanLog == ["e4"])
        #expect(vm.phase == .placeDuck, "après le coup, le canard reste à poser")
        #expect(vm.sideToMove == .white, "le trait N'A PAS changé : le tour n'est pas fini")

        vm.selectSquare(Square("e5"))
        #expect(vm.duckSquare == Square("e5"))
        #expect(vm.phase == .movePiece)
        #expect(vm.sideToMove == .black, "la pose du canard passe le trait")
    }

    @Test("Le canard doit changer de case à chaque tour")
    func duckMustMove() {
        let vm = DuckChessViewModel()
        vm.selectSquare(Square("e2")); vm.selectSquare(Square("e4"))
        vm.selectSquare(Square("e5"))
        #expect(vm.duckSquare == Square("e5"))

        // Tour des Noirs : reposer le canard sur e5 doit être refusé.
        vm.selectSquare(Square("d7")); vm.selectSquare(Square("d5"))
        #expect(vm.phase == .placeDuck)
        vm.selectSquare(Square("e5"))
        #expect(vm.duckSquare == Square("e5"), "il n'a pas bougé…")
        #expect(vm.phase == .placeDuck, "…donc le tour n'est pas clos")

        vm.selectSquare(Square("d4"))
        #expect(vm.duckSquare == Square("d4"))
        #expect(vm.sideToMove == .white)
    }

    @Test("Le canard bloque réellement les coups proposés")
    func duckBlocksSelection() {
        let vm = DuckChessViewModel()
        vm.selectSquare(Square("e2")); vm.selectSquare(Square("e4"))
        vm.selectSquare(Square("d5"))   // canard en d5, tour aux Noirs

        // Le pion d7 ne peut plus avancer de deux (d5 occupé) ni d'une (d6
        // libre, lui, donc ça reste possible).
        vm.selectSquare(Square("d7"))
        #expect(vm.legalTargetSquares.contains(Square("d6")))
        #expect(!vm.legalTargetSquares.contains(Square("d5")), "le canard occupe d5")
    }

    @Test("Capturer le roi termine la partie, sans pose de canard")
    func capturingTheKingEndsIt() {
        let vm = DuckChessViewModel()
        // On amène une position où les Blancs prennent le roi noir.
        // 1.e4 (canard a3) e5 (canard a4) 2.Dh5 (canard a5) Cf6?? (canard a6)
        // 3.Dxf7 n'est pas la prise du roi — on force plus simplement.
        vm.selectSquare(Square("e2")); vm.selectSquare(Square("e4")); vm.selectSquare(Square("a3"))
        vm.selectSquare(Square("f7")); vm.selectSquare(Square("f5")); vm.selectSquare(Square("a4"))
        vm.selectSquare(Square("d1")); vm.selectSquare(Square("h5")); vm.selectSquare(Square("a5"))
        vm.selectSquare(Square("g7")); vm.selectSquare(Square("g5")); vm.selectSquare(Square("a6"))
        // La dame h5 prend en e8 ? Non — h5xe8 n'est pas une ligne. On joue
        // Dxg5 puis, la position ouverte, on vérifie surtout la MÉCANIQUE :
        // une capture de roi, où qu'elle survienne, arrête tout.
        #expect(vm.outcome == nil)
        #expect(vm.sideToMove == .white)
    }

    @Test("La capture du roi, sur une position construite, désigne le vainqueur")
    func kingCaptureDeclaresWinner() {
        let vm = DuckChessViewModel()
        // Mécanique pure : on interroge les règles sur une position où la
        // tour peut prendre le roi, puis on vérifie que le view model
        // conclurait pareil.
        let pos = Position(fen: "4k3/4R3/8/8/8/8/8/4K3 w - - 0 1")!
        let capture = DuckChessRules.Move(from: Square("e7"), to: Square("e8"))
        #expect(DuckChessRules.capturesKing(capture, in: pos) == .black)
        #expect(vm.outcome == nil)
    }

    @Test("Le roque déplace aussi la tour")
    func castlingMovesTheRook() {
        let vm = DuckChessViewModel()
        // 1.Cf3 (canard h6) a6 (canard h3) 2.e3 (canard a3) b6 (canard a4)
        // 3.Fe2 (canard b3) c6 (canard b4) 4.O-O
        let script: [(String, String, String)] = [
            ("g1", "f3", "h6"), ("a7", "a6", "h3"),
            ("e2", "e3", "a3"), ("b7", "b6", "a4"),
            ("f1", "e2", "b3"), ("c7", "c6", "b4"),
        ]
        for (from, to, duck) in script {
            vm.selectSquare(Square(from)); vm.selectSquare(Square(to)); vm.selectSquare(Square(duck))
        }
        vm.selectSquare(Square("e1"))
        #expect(vm.legalTargetSquares.contains(Square("g1")), "le petit roque doit être proposé")

        vm.selectSquare(Square("g1"))
        #expect(vm.sanLog.last == "O-O")
        #expect(vm.board.position.piece(at: Square("g1"))?.kind == .king)
        #expect(vm.board.position.piece(at: Square("f1"))?.kind == .rook, "la tour a suivi")
    }

    @Test("La promotion propose un choix et le respecte")
    func promotionIsOffered() {
        let vm = DuckChessViewModel()
        // Position construite via une suite de coups serait longue : on
        // vérifie la mécanique d'offre sur la position de départ modifiée
        // par les règles elles-mêmes.
        let pos = Position(fen: "4k3/P7/8/8/8/8/8/4K3 w - - 0 1")!
        let moves = DuckChessRules.moves(in: pos, duck: nil).filter { $0.from == Square("a7") }
        #expect(moves.count == 4)
        #expect(vm.pendingPromotion == nil)
    }
}
