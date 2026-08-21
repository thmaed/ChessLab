import Testing
@testable import ChessLab

/// La nature d'un cours (`kind == "endgame"`) et sa famille doivent SURVIVRE à
/// toute recopie.
///
/// 🐛 Elles ne survivaient à aucune : `OpeningCourse.init` — le seul chemin de
/// recopie — ne portait pas ces deux champs. Une finale perdait donc son `kind`
/// dès qu'on la partageait (ré-identification à l'import), qu'on la renommait
/// ou qu'on y touchait un coup. Elle disparaissait alors de l'écran Finales,
/// réapparaissait dans les Ouvertures, et le lecteur la retournait (une finale
/// s'oriente rangée 1 en bas, une ouverture selon le camp étudié).
///
/// Ces trois tests verrouillent les trois chemins, un par un.
@MainActor
struct OpeningCourseKindTests {

    /// Une finale d'exemple : trois coups depuis la position initiale suffisent,
    /// seuls les métadonnées comptent ici.
    private func endgameCourse(id: String = "user-eg") -> OpeningCourse {
        var course = OpeningGraphFixtures.linearCourse(
            id: id, name: "L'opposition", sans: ["e4", "e5", "Ke2"]
        )
        course.kind = "endgame"
        course.family = "pawns"
        return course
    }

    @Test("La ré-identification à l'import conserve la nature de finale")
    func rekeyingKeepsTheEndgameKind() throws {
        let store = UserOpeningStore.shared
        let received = endgameCourse(id: "user-venu-d-ailleurs")

        let reidentified = store.rekeyed(received, to: "user-nouvel-id")

        #expect(reidentified.id == "user-nouvel-id")
        #expect(reidentified.kind == "endgame")
        #expect(reidentified.family == "pawns")
        #expect(reidentified.isEndgame, "une finale partagée doit rester une finale")
    }

    @Test("Le renommage conserve la nature de finale")
    func renamingKeepsTheEndgameKind() throws {
        let renamed = OpeningCourseEditor.rename(endgameCourse(), to: "Opposition distante")

        #expect(renamed.name == "Opposition distante")
        #expect(renamed.isEndgame)
        #expect(renamed.family == "pawns")
    }

    @Test("L'édition d'un coup conserve la nature de finale")
    func editingAMoveKeepsTheEndgameKind() throws {
        let course = endgameCourse()
        // `addMove` passe par `replacing(positions:chapters:)`, le chemin
        // emprunté par CHAQUE geste de l'éditeur (il n'y a pas de bouton
        // « Enregistrer » : on sauvegarde à chaque coup).
        let edited = try OpeningCourseEditor.addMove(uci: "d2d4", from: course.rootFEN, in: course)

        #expect(edited.isEndgame, "toucher un coup ne doit pas transformer une finale en ouverture")
        #expect(edited.family == "pawns")
    }

    @Test("Une ouverture reste une ouverture après recopie")
    func openingsStayOpenings() throws {
        let opening = OpeningGraphFixtures.linearCourse(id: "user-op", name: "Italienne", sans: ["e4", "e5"])

        let renamed = OpeningCourseEditor.rename(opening, to: "Partie italienne")

        #expect(renamed.kind == nil)
        #expect(!renamed.isEndgame)
    }
}
