import ChessKit
import Testing
@testable import ChessLab

/// Tests de l'éditeur de position (étape 7 / Lot 1.A).
///
/// L'enjeu du lot : le FEN produit doit être **relisible à l'identique** —
/// c'est lui qui alimentera le moteur (Jouer, Analyser) et, plus tard,
/// l'écran de confirmation du scanner. Un aller-retour qui perd une pièce ou
/// un droit de roque se verrait ici, pas à l'écran.
@MainActor
struct PositionEditorTests {

    private func square(_ notation: String) -> Square { Square(notation) }

    // MARK: Génération du FEN

    @Test func standardPositionGeneratesTheStandardFEN() {
        let vm = PositionEditorViewModel()

        #expect(vm.fen == "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        #expect(vm.fen == Position.standard.fen)
        #expect(vm.isValid)
    }

    /// Aller-retour complet : la grille repassée par le FEN puis par le
    /// parseur de ChessKit doit redonner exactement les mêmes pièces.
    @Test func gridSurvivesARoundTripThroughFENAndBack() throws {
        let vm = PositionEditorViewModel()
        vm.selectedTool = .eraser
        vm.apply(at: square("e2"))
        vm.selectedTool = .piece(kind: .pawn, color: .white)
        vm.apply(at: square("e4"))
        vm.sideToMove = .black

        let reloaded = PositionEditorViewModel(fen: vm.fen)

        #expect(reloaded.pieces == vm.pieces)
        #expect(reloaded.fen == vm.fen)
        #expect(reloaded.sideToMove == .black)

        // Et le parseur de ChessKit lit la même chose que nous.
        let position = try #require(Position(fen: vm.fen))
        #expect(Set(position.pieces) == Set(vm.pieces.values))
    }

    @Test func emptyBoardWithTwoKingsIsAValidPosition() {
        let vm = PositionEditorViewModel()
        vm.clearBoard()
        vm.selectedTool = .piece(kind: .king, color: .white)
        vm.apply(at: square("e1"))
        vm.selectedTool = .piece(kind: .king, color: .black)
        vm.apply(at: square("e8"))

        #expect(vm.fen == "4k3/8/8/8/8/8/8/4K3 w - - 0 1")
        #expect(vm.isValid)
    }

    // MARK: Palette

    @Test func retappingTheSamePieceWithTheSameToolErasesIt() {
        let vm = PositionEditorViewModel()
        vm.clearBoard()
        vm.selectedTool = .piece(kind: .queen, color: .white)

        vm.apply(at: square("d4"))
        #expect(vm.pieces[square("d4")]?.kind == .queen)

        vm.apply(at: square("d4"))
        #expect(vm.pieces[square("d4")] == nil)
    }

    /// Re-taper avec un outil DIFFÉRENT remplace au lieu d'effacer : sinon
    /// corriger une pièce demanderait deux taps (gomme, puis pose).
    @Test func tappingWithAnotherToolReplacesThePiece() {
        let vm = PositionEditorViewModel()
        vm.selectedTool = .piece(kind: .knight, color: .white)
        vm.apply(at: square("a1"))

        #expect(vm.pieces[square("a1")]?.kind == .knight)
        #expect(vm.pieces[square("a1")]?.color == .white)
    }

    @Test func eraserRemovesAPieceOfEitherColor() {
        let vm = PositionEditorViewModel()
        vm.selectedTool = .eraser
        vm.apply(at: square("d8"))

        #expect(vm.pieces[square("d8")] == nil)
    }

    // MARK: Validation (déléguée à FENValidator)

    @Test func twoWhiteKingsAreReported() {
        let vm = PositionEditorViewModel()
        vm.selectedTool = .piece(kind: .king, color: .white)
        vm.apply(at: square("e4"))

        #expect(!vm.isValid)
        #expect(vm.errors.contains { $0.contains("exactement un roi") })
    }

    @Test func aPawnOnTheLastRankIsReported() {
        let vm = PositionEditorViewModel()
        vm.selectedTool = .eraser
        vm.apply(at: square("a8"))
        vm.selectedTool = .piece(kind: .pawn, color: .white)
        vm.apply(at: square("a8"))

        #expect(!vm.isValid)
        #expect(vm.errors.contains { $0.contains("1re ou la 8e rangée") })
    }

    @Test func aBoardWithoutKingsIsReported() {
        let vm = PositionEditorViewModel()
        vm.clearBoard()

        #expect(!vm.isValid)
        #expect(vm.errors.contains { $0.contains("exactement un roi") })
    }

    // MARK: Roques

    /// Le cœur de la cohérence automatique : déplacer la tour h1 rend le
    /// petit roque blanc impossible. L'éditeur le décoche seul, plutôt que
    /// de laisser l'utilisateur buter sur une erreur de validation qu'il n'a
    /// pas provoquée.
    @Test func movingARookClearsTheMatchingCastlingRight() {
        let vm = PositionEditorViewModel()
        #expect(vm.whiteCanCastleKingside)

        vm.selectedTool = .eraser
        vm.apply(at: square("h1"))

        #expect(!vm.whiteCanCastleKingside)
        #expect(!vm.isWhiteKingsideAvailable)
        #expect(vm.whiteCanCastleQueenside)
        #expect(vm.fen.split(separator: " ")[2] == "Qkq")
    }

    @Test func movingTheKingClearsBothOfItsCastlingRights() {
        let vm = PositionEditorViewModel()
        vm.selectedTool = .eraser
        vm.apply(at: square("e8"))

        #expect(!vm.blackCanCastleKingside)
        #expect(!vm.blackCanCastleQueenside)
        #expect(vm.fen.split(separator: " ")[2] == "KQ")
    }

    @Test func noCastlingRightAtAllProducesADash() {
        let vm = PositionEditorViewModel()
        vm.clearBoard()
        vm.selectedTool = .piece(kind: .king, color: .white)
        vm.apply(at: square("e1"))
        vm.selectedTool = .piece(kind: .king, color: .black)
        vm.apply(at: square("e8"))

        #expect(vm.fen.split(separator: " ")[2] == "-")
    }

    /// Un FEN relu dont les droits de roque sont incohérents avec la grille
    /// (roi hors de e1) est élagué à la lecture : le scanner produira ce
    /// genre de FEN, il ne doit pas ressortir tel quel.
    @Test func loadingPrunesInconsistentCastlingRights() {
        let vm = PositionEditorViewModel(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQ1BNR w KQkq - 0 1")

        #expect(!vm.whiteCanCastleKingside)
        #expect(!vm.whiteCanCastleQueenside)
        #expect(vm.blackCanCastleKingside)
        #expect(vm.fen.split(separator: " ")[2] == "kq")
    }

    // MARK: En passant

    @Test func enPassantFileIsOfferedOnlyWhereAPawnJustCouldHaveJumped() {
        let vm = PositionEditorViewModel()
        // 1. e4 : pion blanc en e4, e2 et e3 vides, trait aux Noirs.
        vm.selectedTool = .eraser
        vm.apply(at: square("e2"))
        vm.selectedTool = .piece(kind: .pawn, color: .white)
        vm.apply(at: square("e4"))
        vm.sideToMove = .black

        #expect(vm.enPassantRank == 3)
        #expect(vm.availableEnPassantFiles == [.e])

        vm.enPassantFile = .e
        #expect(vm.fen.split(separator: " ")[3] == "e3")
        #expect(vm.isValid)
    }

    @Test func noEnPassantIsOfferedInTheStandardPosition() {
        let vm = PositionEditorViewModel()

        #expect(vm.availableEnPassantFiles.isEmpty)
        #expect(vm.fen.split(separator: " ")[3] == "-")
    }

    /// La case en passant appartient au trait : le rendre à l'autre camp la
    /// périme, il faut donc l'oublier — sinon le FEN décrit une prise en
    /// passant impossible et `FENValidator` la refuse.
    @Test func changingTheSideToMoveClearsTheEnPassantSquare() {
        let vm = PositionEditorViewModel()
        vm.selectedTool = .eraser
        vm.apply(at: square("e2"))
        vm.selectedTool = .piece(kind: .pawn, color: .white)
        vm.apply(at: square("e4"))
        vm.sideToMove = .black
        vm.enPassantFile = .e
        #expect(vm.enPassantFile == .e)

        vm.sideToMove = .white

        #expect(vm.enPassantFile == nil)
        #expect(vm.fen.split(separator: " ")[3] == "-")
        #expect(vm.isValid)
    }

    // MARK: Chargement

    @Test func anUnreadableFENFallsBackToTheStandardPosition() {
        let vm = PositionEditorViewModel(fen: "n'importe quoi")

        #expect(vm.fen == Position.standard.fen)
    }

    @Test func loadingKeepsTheSideToMoveAndTheEnPassantSquare() {
        let source = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 3"
        let vm = PositionEditorViewModel(fen: source)

        #expect(vm.sideToMove == .white)
        #expect(vm.enPassantFile == .e)
        #expect(vm.enPassantRank == 6)
        // Les compteurs sont volontairement remis à `0 1` (un éditeur ne
        // connaît pas l'historique) : le reste du FEN est identique.
        #expect(vm.fen == "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 1")
    }

    // MARK: Orientation

    @Test func flippingTheOrientationDoesNotTouchTheFEN() {
        let vm = PositionEditorViewModel()
        let before = vm.fen

        vm.flipOrientation()

        #expect(vm.orientation == .black)
        #expect(vm.fen == before)
    }
}

/// Complétion assistée des types (étape 7 / Lot 1.E).
///
/// Un plateau réel vu du dessus livre l'occupation et la couleur, jamais le
/// type. L'éditeur doit donc savoir tenir des pièces « sans type » : les
/// montrer, refuser de sortir tant qu'il en reste, et les faire compléter à
/// raison d'un tap par pièce.
@MainActor
struct PositionEditorUnknownPiecesTests {

    private func square(_ notation: String) -> Square { Square(notation) }

    /// Lecture typique d'un plateau réel : un roi blanc et un roi noir, dont
    /// on ne connaît que la couleur.
    private func loadedWithTwoUnknowns() -> PositionEditorViewModel {
        let vm = PositionEditorViewModel()
        vm.load(
            fen: "8/8/8/8/8/8/8/8 w - - 0 1",
            unknownPieces: [square("e8"): .black, square("e1"): .white]
        )
        return vm
    }

    @Test func aPositionWithUnknownKindsIsNeverValid() {
        let vm = loadedWithTwoUnknowns()

        #expect(!vm.isValid, "aucune action ne doit être possible tant qu'un type manque")
        #expect(vm.errors.first?.contains("sans type") == true)
        // Le FEN ne contient PAS les pièces sans type : elles n'existent pas
        // pour ChessKit, et surtout pas pour le moteur.
        #expect(vm.fen == "8/8/8/8/8/8/8/8 w - - 0 1")
    }

    /// Ordre de lecture d'un échiquier : 8e rangée d'abord, de a à h. Sans
    /// ordre stable, la sélection sauterait d'un bout à l'autre du plateau
    /// entre deux taps.
    @Test func unknownSquaresAreOfferedInReadingOrder() {
        let vm = PositionEditorViewModel()
        vm.load(
            fen: "8/8/8/8/8/8/8/8 w - - 0 1",
            unknownPieces: [
                square("a1"): .white, square("h8"): .black,
                square("a8"): .black, square("d4"): .white
            ]
        )

        #expect(vm.unknownSquaresInOrder.map(\.notation) == ["a8", "h8", "d4", "a1"])
        #expect(vm.selectedUnknownSquare == square("a8"))
    }

    @Test func assigningAKindAdvancesToTheNextUnknownSquare() {
        let vm = loadedWithTwoUnknowns()
        #expect(vm.selectedUnknownSquare == square("e8"))
        #expect(vm.selectedUnknownColor == .black)

        vm.assignKindToSelectedUnknown(.king)

        #expect(vm.pieces[square("e8")]?.kind == .king)
        #expect(vm.pieces[square("e8")]?.color == .black, "la couleur lue ne doit pas se perdre en route")
        #expect(vm.selectedUnknownSquare == square("e1"), "la case suivante s'enchaîne toute seule")
        #expect(vm.selectedUnknownColor == .white)
    }

    @Test func completingEveryKindMakesThePositionUsable() {
        let vm = loadedWithTwoUnknowns()

        vm.assignKindToSelectedUnknown(.king)
        vm.assignKindToSelectedUnknown(.king)

        #expect(vm.unknownPieces.isEmpty)
        #expect(vm.fen == "4k3/8/8/8/8/8/8/4K3 w - - 0 1")
        #expect(vm.isValid)
    }

    /// La palette classique reste utilisable sur une case sans type : c'est le
    /// chemin de correction quand la couleur elle-même a été mal lue.
    @Test func tappingAnUnknownSquareWithTheClassicPaletteResolvesIt() {
        let vm = loadedWithTwoUnknowns()
        vm.selectedTool = .piece(kind: .queen, color: .white)

        vm.apply(at: square("e8"))

        #expect(vm.unknownPieces[square("e8")] == nil)
        #expect(vm.pieces[square("e8")] == Piece(.queen, color: .white, square: square("e8")))
    }

    /// Une pièce vue là où il n'y en a pas (ombre, reflet) s'efface — et
    /// « re-taper pour effacer » n'a aucun sens sur ce qui n'a pas de type.
    @Test func theEraserRemovesAnUnknownPiece() {
        let vm = loadedWithTwoUnknowns()
        vm.selectedTool = .eraser

        vm.apply(at: square("e8"))

        #expect(vm.unknownPieces[square("e8")] == nil)
        #expect(vm.pieces[square("e8")] == nil)
        #expect(vm.selectedUnknownSquare == square("e1"))
    }

    @Test func resettingTheBoardForgetsTheUnknownPieces() {
        let vm = loadedWithTwoUnknowns()

        vm.resetToStandard()

        #expect(vm.unknownPieces.isEmpty)
        #expect(vm.isValid)
    }
}
