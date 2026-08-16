import ChessKit
import Testing
@testable import ChessLab

/// Édition d'un répertoire personnel : ajouter, retirer, commenter.
///
/// Le test qui porte le reste est `removingKeepsTransposedPositions` : le graphe
/// est indexé par FEN, donc retirer une variante ne doit PAS emporter les
/// positions qu'une autre ligne atteint encore. Une purge naïve du sous-arbre
/// passerait tous les autres tests et casserait précisément ce qui fait la
/// valeur du graphe.
///
/// Second garde-fou de fond : chaque cours produit doit passer
/// ``OpeningCourseValidator`` — c'est ce que fait `UserOpeningStore.save`, et un
/// éditeur qui fabrique un graphe invalide échoue à l'enregistrement, pas à
/// l'écran.
struct OpeningCourseEditorTests {

    /// 1.e4 e5 2.Cf3 Cc6, sur lequel on greffe.
    private func base() -> OpeningCourse {
        OpeningGraphFixtures.linearCourse(
            id: "user-edit", name: "Test", sans: ["e4", "e5", "Nf3", "Nc6"]
        )
    }

    private func key(after sans: [String]) -> String {
        var board = Board(position: .standard)
        for san in sans {
            guard let parsed = Move(san: san, position: board.position) else { break }
            _ = board.move(pieceAt: parsed.start, to: parsed.end)
        }
        return OpeningFENKey.key(for: board.position)
    }

    // MARK: Ajout

    @Test func addingCreatesEdgeAndTargetNode() throws {
        let course = base()
        let from = key(after: ["e4", "e5"])
        let edited = try OpeningCourseEditor.addMove(uci: "f1c4", from: from, in: course)

        let node = try #require(edited.positions[from])
        let edge = try #require(node.moves.first { $0.uci == "f1c4" })
        #expect(edge.san == "Bc4")
        #expect(edited.positions[edge.toFEN] != nil, "la position d'arrivée doit exister")
        #expect(OpeningCourseValidator.validate(edited).isEmpty)
    }

    /// Le SAN n'est jamais celui que l'appelant prétend : il est recalculé.
    @Test func addingDerivesSANFromTheBoard() throws {
        let course = base()
        let from = key(after: ["e4", "e5", "Nf3"])
        let edited = try OpeningCourseEditor.addMove(uci: "d7d6", from: from, in: course)
        let edge = try #require(edited.positions[from]?.moves.first { $0.uci == "d7d6" })
        #expect(edge.san == "d6")
    }

    @Test func addingIllegalMoveThrows() {
        let course = base()
        let from = key(after: ["e4", "e5"])
        #expect(throws: OpeningCourseEditor.EditError.illegalMove("e1e8")) {
            try OpeningCourseEditor.addMove(uci: "e1e8", from: from, in: course)
        }
    }

    /// `canMove`/`legalMoves` de ChessKit ignorent le trait : sans garde
    /// explicite, on fabriquerait une arête vers une position inatteignable,
    /// que le validateur ne verrait pas puisqu'il rejoue avec la même mécanique.
    @Test func addingOutOfTurnMoveThrows() {
        let course = base()
        // Racine : les Blancs ont le trait. On tente un coup NOIR.
        #expect(throws: OpeningCourseEditor.EditError.illegalMove("e7e5")) {
            try OpeningCourseEditor.addMove(uci: "e7e5", from: course.rootFEN, in: course)
        }
        #expect(OpeningCourseEditor.play(uci: "e7e5", from: course.rootFEN) == nil)
    }

    @Test func addingUnknownPositionThrows() {
        #expect(throws: OpeningCourseEditor.EditError.self) {
            try OpeningCourseEditor.addMove(uci: "e2e4", from: "PAS UNE FEN", in: base())
        }
    }

    @Test func addingSameMoveTwiceThrows() throws {
        let course = base()
        let from = key(after: ["e4", "e5"])
        let once = try OpeningCourseEditor.addMove(uci: "f1c4", from: from, in: course)
        #expect(throws: OpeningCourseEditor.EditError.duplicateMove("Bc4")) {
            try OpeningCourseEditor.addMove(uci: "f1c4", from: from, in: once)
        }
    }

    /// Une transposition REJOINT le nœud existant au lieu d'en créer un second :
    /// c'est la raison d'être du graphe indexé par FEN.
    @Test func addingTransposingMoveReusesExistingNode() throws {
        // 1.e4 e5 2.Cf3 Cc6 existe déjà. On greffe 2.Cc3 puis on transpose.
        var course = base()
        let afterE5 = key(after: ["e4", "e5"])
        course = try OpeningCourseEditor.addMove(uci: "b1c3", from: afterE5, in: course)
        let afterNc3 = key(after: ["e4", "e5", "Nc3"])
        course = try OpeningCourseEditor.addMove(uci: "b8c6", from: afterNc3, in: course)
        let afterNc3Nc6 = key(after: ["e4", "e5", "Nc3", "Nc6"])

        let before = course.positions.count
        // 3.Cf3 depuis 2.Cc3 Cc6 mène à la MÊME position que 2.Cf3 Cc6 3.Cc3.
        course = try OpeningCourseEditor.addMove(uci: "g1f3", from: afterNc3Nc6, in: course)
        let target = key(after: ["e4", "e5", "Nc3", "Nc6", "Nf3"])

        #expect(course.positions[target] != nil)
        #expect(course.positions.count == before + 1, "un seul nœud neuf")
        #expect(OpeningCourseValidator.validate(course).isEmpty)
    }

    // MARK: Retrait

    @Test func removingDropsEdgeAndUnreachableNodes() throws {
        let course = base()
        let afterE4 = key(after: ["e4"])
        let edited = OpeningCourseEditor.removeMove(uci: "e7e5", from: afterE4, in: course)

        #expect(edited.positions[afterE4]?.moves.isEmpty == true)
        #expect(edited.positions[key(after: ["e4", "e5"])] == nil, "la suite devient inatteignable")
        #expect(edited.positions[key(after: ["e4", "e5", "Nf3", "Nc6"])] == nil)
        #expect(edited.positions[course.rootFEN] != nil, "la racine survit toujours")
        #expect(OpeningCourseValidator.validate(edited).isEmpty)
    }

    /// LE test de fond : une position encore atteinte par une autre ligne
    /// SURVIT au retrait. Une purge du sous-arbre la supprimerait à tort.
    @Test func removingKeepsTransposedPositions() throws {
        var course = base()
        let afterE5 = key(after: ["e4", "e5"])
        // Deuxième chemin vers 1.e4 e5 2.Cf3 Cc6 : 2.Cc3 Cc6 3.Cf3, transposition.
        course = try OpeningCourseEditor.addMove(uci: "b1c3", from: afterE5, in: course)
        let afterNc3 = key(after: ["e4", "e5", "Nc3"])
        course = try OpeningCourseEditor.addMove(uci: "b8c6", from: afterNc3, in: course)
        let afterNc3Nc6 = key(after: ["e4", "e5", "Nc3", "Nc6"])
        course = try OpeningCourseEditor.addMove(uci: "g1f3", from: afterNc3Nc6, in: course)

        let shared = key(after: ["e4", "e5", "Nc3", "Nc6", "Nf3"])
        #expect(course.positions[shared] != nil)

        // On coupe la ligne 2.Cf3 : la position partagée reste jointe par 2.Cc3.
        let edited = OpeningCourseEditor.removeMove(uci: "g1f3", from: afterE5, in: course)
        #expect(edited.positions[key(after: ["e4", "e5", "Nf3"])] == nil, "la branche coupée part")
        #expect(edited.positions[shared] != nil, "mais la transposition la maintient jointe")
        #expect(OpeningCourseValidator.validate(edited).isEmpty)
    }

    @Test func removingUnknownMoveChangesNothing() {
        let course = base()
        let edited = OpeningCourseEditor.removeMove(uci: "h2h4", from: course.rootFEN, in: course)
        #expect(edited.positions.count == course.positions.count)
    }

    /// Un chapitre qui référencerait une position disparue ferait échouer la
    /// validation : les chapitres sont donc nettoyés en même temps.
    @Test func removingCleansDanglingChapterEntries() throws {
        let course = base()
        let removedFEN = key(after: ["e4", "e5", "Nf3"])
        #expect(course.chapters?.first?.positionFENs.contains(removedFEN) == true)

        let edited = OpeningCourseEditor.removeMove(
            uci: "g1f3", from: key(after: ["e4", "e5"]), in: course
        )
        let fens = edited.chapters?.flatMap(\.positionFENs) ?? []
        #expect(!fens.contains(removedFEN))
        #expect(OpeningCourseValidator.validate(edited).isEmpty)
    }

    /// Vider un répertoire de toutes ses variantes reste légal : le fichier doit
    /// rester valide, pas devenir irrécupérable.
    ///
    /// Le chapitre SURVIT en ne gardant que la racine, seule position encore
    /// présente — il n'est pas vidé, et c'est bien ce qu'on veut : un chapitre
    /// n'est nettoyé que de ses positions disparues.
    @Test func emptiedCourseStaysValid() {
        let course = base()
        let edited = OpeningCourseEditor.removeMove(uci: "e2e4", from: course.rootFEN, in: course)
        #expect(edited.positions.count == 1)
        let referenced = edited.chapters?.flatMap(\.positionFENs) ?? []
        #expect(referenced.allSatisfy { edited.positions[$0] != nil },
                "aucun chapitre ne doit pointer vers une position disparue")
        #expect(referenced == [edited.rootFEN])
        #expect(OpeningCourseValidator.validate(edited).isEmpty)
    }

    // MARK: Commentaire

    @Test func commentIsWrittenAndDisplayable() throws {
        let course = base()
        let edited = OpeningCourseEditor.setComment(
            "On occupe le centre.", code: "fr", uci: "e2e4", from: course.rootFEN, in: course
        )
        let edge = try #require(edited.positions[course.rootFEN]?.moves.first)
        #expect(edge.displayableComment("fr") == "On occupe le centre.")
    }

    /// Le texte de l'auteur est `validated` par construction — sinon il resterait
    /// invisible, la règle « pas de brouillon affiché » visant le contenu généré.
    @Test func commentIsValidatedSoItShows() throws {
        let course = OpeningCourseEditor.setComment(
            "Texte", code: "fr", uci: "e2e4", from: base().rootFEN, in: base()
        )
        let edge = try #require(course.positions[course.rootFEN]?.moves.first)
        #expect(edge.validatedComment != nil)
    }

    @Test func commentInOneLanguageKeepsTheOther() throws {
        var course = OpeningCourseEditor.setComment(
            "English text", code: "en", uci: "e2e4", from: base().rootFEN, in: base()
        )
        course = OpeningCourseEditor.setComment(
            "Texte français", code: "fr", uci: "e2e4", from: course.rootFEN, in: course
        )
        let edge = try #require(course.positions[course.rootFEN]?.moves.first)
        #expect(edge.displayableComment("fr") == "Texte français")
        #expect(edge.displayableComment("en") == "English text")
    }

    @Test func blankCommentClearsIt() throws {
        var course = OpeningCourseEditor.setComment(
            "À effacer", code: "fr", uci: "e2e4", from: base().rootFEN, in: base()
        )
        course = OpeningCourseEditor.setComment(
            "   ", code: "fr", uci: "e2e4", from: course.rootFEN, in: course
        )
        let edge = try #require(course.positions[course.rootFEN]?.moves.first)
        #expect(edge.comment == nil)
        #expect(edge.displayableComment("fr") == nil)
    }

    // MARK: Renommage

    @Test func renameTrimsAndRefusesBlank() {
        let course = base()
        #expect(OpeningCourseEditor.rename(course, to: "  Ma Scandinave  ").name == "Ma Scandinave")
        #expect(OpeningCourseEditor.rename(course, to: "   ").name == course.name)
    }
}
