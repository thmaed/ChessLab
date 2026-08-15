import ChessKit
import Testing
@testable import ChessLab

/// Import d'un répertoire PGN dans le graphe indexé par FEN.
///
/// Le test central est `variationsBecomeBranches` : un répertoire n'est pas une
/// partie, c'est un arbre, et tout l'intérêt de la fonctionnalité tient à ce
/// que les parenthèses du PGN deviennent de vraies alternatives jouables — pas
/// à ce qu'on retienne la ligne principale en jetant le reste.
struct OpeningPGNImporterTests {

    private func makeCourse(
        _ pgn: String, name: String = "Test", side: OpeningSide = .white
    ) throws -> OpeningPGNImporter.Result {
        try OpeningPGNImporter.course(fromPGN: pgn, name: name, side: side, id: "user-test")
    }

    /// Une ligne simple : un nœud par position, une arête par coup.
    @Test func linearGameBecomesAChain() throws {
        let result = try makeCourse("1. e4 e5 2. Nf3 Nc6 *")
        let course = result.course

        #expect(OpeningCourseValidator.validate(course).isEmpty)
        #expect(course.positions.count == 5)          // départ + 4 coups
        #expect(course.rootFEN == OpeningFENKey.key(for: .standard))
        #expect(course.positions[course.rootFEN]?.moves.map(\.san) == ["e4"])
        #expect(result.skippedMoves == 0)
    }

    /// LE cas qui justifie la fonctionnalité : les variantes entre parenthèses
    /// deviennent des arêtes alternatives depuis la MÊME position.
    @Test func variationsBecomeBranches() throws {
        let result = try makeCourse("1. e4 e5 (1... c5 2. Nf3) (1... e6 2. d4) 2. Nf3 *")
        let course = result.course
        #expect(OpeningCourseValidator.validate(course).isEmpty)

        var board = Board(position: .standard)
        _ = board.move(pieceAt: Square("e2"), to: Square("e4"))
        let afterE4 = OpeningFENKey.key(for: board.position)

        let replies = Set(course.positions[afterE4]?.moves.map(\.san) ?? [])
        #expect(replies == ["e5", "c5", "e6"])
        // La ligne principale garde son rang : c'est elle que le lecteur
        // propose en « coup à venir ».
        #expect(course.positions[afterE4]?.moves.first { $0.san == "e5" }?.role == .mainLine)
        #expect(course.positions[afterE4]?.moves.first { $0.san == "c5" }?.role == .sideline)
    }

    /// Deux ordres de coups menant à la même position PARTAGENT leur nœud —
    /// c'est ce qui distingue un graphe d'un empilement d'arbres, et ce qui
    /// fait que la mémorisation d'une position profite à toutes ses entrées.
    @Test func transpositionsMergeIntoOneNode() throws {
        // La variante remplace le coup qu'elle SUIT : ici 1…e6 au lieu de
        // 1…Cf6. Les deux ordres arrivent sur la même position après 2 coups.
        let result = try makeCourse("1. d4 Nf6 (1... e6 2. c4 Nf6) 2. c4 e6 *")
        let course = result.course
        #expect(OpeningCourseValidator.validate(course).isEmpty)

        var board = Board(position: .standard)
        for (from, to) in [("d2", "d4"), ("g8", "f6"), ("c2", "c4"), ("e7", "e6")] {
            _ = board.move(pieceAt: Square(from), to: Square(to))
        }
        let tabiya = OpeningFENKey.key(for: board.position)
        #expect(course.positions[tabiya] != nil)

        // UN seul nœud pour cette position, atteint par DEUX arêtes distinctes
        // (…e6 depuis 1.d4 Cf6 2.c4, et …Cf6 depuis 1.d4 e6 2.c4). C'est ce qui
        // distingue le graphe d'un empilement d'arbres — et ce qui fait qu'on
        // ne réapprend pas deux fois la même position.
        let incoming = course.positions.values
            .flatMap(\.moves)
            .filter { $0.toFEN == tabiya }
        #expect(incoming.count == 2)
        #expect(Set(incoming.map(\.san)) == ["e6", "Nf6"])
    }

    /// Le jugement de l'auteur (`?`, `?!`) devient un rôle : le lecteur affiche
    /// la pastille sans que l'utilisateur ait à ressaisir quoi que ce soit.
    @Test func annotationsBecomeRoles() throws {
        let course = try makeCourse("1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?! 4. Nxe5?? Qg5 *").course
        let edges = course.positions.values.flatMap(\.moves)
        #expect(edges.first { $0.san == "Nd4" }?.role == .inaccuracy)
        #expect(edges.first { $0.san == "Nxe5" }?.role == .trap)
    }

    /// Les commentaires PGN suivent, et sont affichables : ils viennent de
    /// l'utilisateur, pas d'une génération automatique.
    @Test func commentsAreCarriedAndDisplayable() throws {
        let course = try makeCourse("1. e4 {Le coup du centre} e5 *").course
        let edge = try #require(course.positions[course.rootFEN]?.moves.first)
        #expect(edge.displayableComment("fr") == "Le coup du centre")
        #expect(edge.displayableComment("en") == "Le coup du centre")
    }

    /// Plusieurs parties dans un même fichier (l'export d'une étude Lichess) :
    /// un chapitre chacune, un seul graphe.
    @Test func severalGamesBecomeSeveralChapters() throws {
        let pgn = """
        [Event "Contre 1.e4"]

        1. e4 e5 *

        [Event "Contre 1.d4"]

        1. d4 d5 *
        """
        let course = try makeCourse(pgn).course
        #expect(OpeningCourseValidator.validate(course).isEmpty)
        #expect(course.chapters?.count == 2)
        #expect(course.chapters?.map { $0.title.resolved("fr") } == ["Contre 1.e4", "Contre 1.d4"])
        #expect(Set(course.positions[course.rootFEN]?.moves.map(\.san) ?? []) == ["e4", "d4"])
    }

    @Test func emptyInputIsRejected() {
        #expect(throws: OpeningPGNImporter.ImportError.empty) {
            try makeCourse("   \n  ")
        }
    }

    /// Un texte sans le moindre coup jouable ne doit pas créer une entrée vide
    /// dans la liste de l'utilisateur.
    @Test func gameWithoutMovesIsRejected() {
        #expect(throws: (any Error).self) {
            try makeCourse("[Event \"Vide\"]\n\n*")
        }
    }

    /// Le camp étudié est le seul choix qu'un PGN ne porte pas.
    @Test func sideIsCarriedThrough() throws {
        let course = try makeCourse("1. e4 c5 *", side: .black).course
        #expect(course.side == .black)
    }
}
