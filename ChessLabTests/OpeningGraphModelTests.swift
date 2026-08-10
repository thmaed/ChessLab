import Foundation
import Testing
@testable import ChessLab

/// Décodage du nouveau modèle en graphe et intégrité du graphe : aucune arête
/// orpheline, aucun FEN invalide, coups légaux, décodage défensif.
struct OpeningGraphModelTests {

    // MARK: Décodage défensif + règle des commentaires

    /// JSON écrit à la main : on vérifie la forme (noms de champs), les replis
    /// (rôle inconnu → `.sideline`), les défauts et la RÈGLE STRICTE des
    /// commentaires (un brouillon n'est jamais affichable comme définitif).
    private static let literalJSON = """
    {
      "schemaVersion": 1,
      "id": "test-course",
      "name": "Cours de test",
      "eco": ["B01"],
      "rootFEN": "K0",
      "positions": {
        "K0": {
          "fen": "K0",
          "moves": [
            {"san":"e4","uci":"e2e4","toFEN":"K1","role":"mainLine","comment":{"fr":"Contrôle le centre.","en":"Controls the center."},"commentStatus":"validated","isCritical":true},
            {"san":"d4","uci":"d2d4","toFEN":"K1b","role":"chelou-inconnu","comment":"Brouillon à relire.","commentStatus":"draft"}
          ]
        },
        "K1": {"fen":"K1","moves":[]},
        "K1b": {"fen":"K1b"}
      }
    }
    """

    @Test func decodesLiteralCourseWithDefensiveFallbacks() throws {
        let course = try OpeningCourseLoader.decodeCourse(from: Data(Self.literalJSON.utf8))

        #expect(course.id == "test-course")
        #expect(course.schemaVersion == 1)
        #expect(course.eco == ["B01"])
        #expect(course.side == .white)   // absent → défaut
        #expect(course.level == .club)   // absent → défaut
        #expect(course.positions.count == 3)

        let root = try #require(course.rootNode)
        #expect(root.moves.count == 2)

        let main = root.moves[0]
        #expect(main.role == .mainLine)
        #expect(main.isCritical)
        #expect(main.displayableComment("fr") == "Contrôle le centre.")
        #expect(main.displayableComment("en") == "Controls the center.")

        let side = root.moves[1]
        #expect(side.role == .sideline)             // rôle inconnu → repli
        #expect(side.isCritical == false)           // absent → défaut
        #expect(side.displayableComment("fr") == nil)     // brouillon jamais affiché
        #expect(side.comment?.resolved("fr") == "Brouillon à relire.")

        // Nœud sans clé "moves" → aucune arête (feuille).
        #expect(course.node(at: "K1b")?.moves.isEmpty == true)
    }

    // MARK: Intégrité du graphe (fixtures construits avec le vrai code)

    @Test func validFixtureHasNoIntegrityIssues() {
        let course = OpeningGraphFixtures.linearCourse(
            id: "ruy", name: "Partie espagnole", sans: ["e4", "e5", "Nf3", "Nc6", "Bb5"]
        )
        #expect(OpeningCourseValidator.validate(course).isEmpty)
    }

    @Test func courseSurvivesJSONRoundTrip() throws {
        let course = OpeningGraphFixtures.linearCourse(
            id: "scandi", name: "Défense scandinave", sans: ["e4", "d5", "exd5", "Qxd5", "Nc3"]
        )
        let data = try JSONEncoder().encode(course)
        let decoded = try OpeningCourseLoader.decodeCourse(from: data)

        #expect(decoded.id == course.id)
        #expect(decoded.positions.count == course.positions.count)
        #expect(OpeningCourseValidator.validate(decoded).isEmpty)
    }

    @Test func validatorCatchesOrphanEdge() {
        let good = OpeningGraphFixtures.linearCourse(
            id: "ital", name: "Partie italienne", sans: ["e4", "e5", "Nf3", "Nc6", "Bc4"]
        )
        let broken = OpeningGraphFixtures.withBrokenEdge(good)
        let issues = OpeningCourseValidator.validate(broken)

        #expect(issues.contains { $0.kind == .orphanEdge })
    }

    @Test func validatorCatchesIllegalOrMismatchedEdge() {
        // Une arête dont l'UCI ne correspond pas à un coup jouable depuis la
        // racine : doit lever illegalMove ou edgeTargetMismatch.
        let root = OpeningFENKey.key(for: .standard)
        let bogusTarget = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq -"
        let node = PositionNode(
            fen: root,
            moves: [MoveEdge(san: "???", uci: "a1a8", toFEN: bogusTarget, role: .mainLine)]
        )
        let course = OpeningCourse(
            id: "bogus", name: "Bogus", rootFEN: root,
            positions: [root: node, bogusTarget: PositionNode(fen: bogusTarget)]
        )
        let issues = OpeningCourseValidator.validate(course)

        #expect(issues.contains { $0.kind == .illegalMove || $0.kind == .edgeTargetMismatch })
    }
}
