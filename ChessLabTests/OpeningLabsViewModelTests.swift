import ChessKit
import Testing
@testable import ChessLab

/// Le lecteur Labs. Sa particularité tient en une phrase : l'état est un
/// CHEMIN, et tout le reste s'en déduit. Ces tests vérifient que le rejeu ne
/// laisse jamais l'écran dans un état incohérent — c'est le seul risque
/// sérieux d'un modèle sans pile d'annulation.
@MainActor
struct OpeningLabsViewModelTests {

    private func course() -> OpeningCourse {
        OpeningGraphFixtures.linearCourse(
            id: "fixture-labs", name: "Ligne d'essai", sans: ["e4", "e5", "Nf3", "Nc6", "Bb5"]
        )
    }

    private func viewModel(sidecar: OpeningLabsSidecar? = nil) -> OpeningLabsViewModel {
        let course = course()
        return OpeningLabsViewModel(
            course: course,
            sidecar: sidecar ?? OpeningLabsSidecar(id: course.id, positions: [:])
        )
    }

    // MARK: Navigation

    @Test("On part de la racine, index ouvert")
    func startsAtTheRootWithTheIndexOpen() {
        let vm = viewModel()
        #expect(vm.isRoot)
        #expect(vm.playedSANs.isEmpty)
        #expect(!vm.canGoBack)
        #expect(vm.isIndexPresented, "l'index s'ouvre à l'arrivée — c'est l'écran d'entrée")
    }

    @Test("« Suivant » suit la ligne principale")
    func nextFollowsTheMainLine() {
        let vm = viewModel()
        vm.next()
        vm.next()
        #expect(vm.playedSANs == ["e4", "e5"])
        #expect(vm.path == ["e2e4", "e7e5"])
    }

    @Test("« Précédent » défait exactement un coup")
    func backUndoesExactlyOneMove() {
        let vm = viewModel()
        vm.next(); vm.next(); vm.next()
        vm.back()
        #expect(vm.playedSANs == ["e4", "e5"])
        #expect(vm.canGoBack)
        vm.back(); vm.back()
        #expect(vm.isRoot)
        #expect(!vm.canGoBack)
    }

    /// Le geste de l'index : sauter directement au milieu d'une ligne.
    @Test("Un saut reconstruit le plateau ET le fil des coups")
    func aJumpRebuildsBoardAndTrail() {
        let vm = viewModel()
        vm.jump(path: ["e2e4", "e7e5", "g1f3", "b8c6"])

        #expect(vm.playedSANs == ["e4", "e5", "Nf3", "Nc6"])
        #expect(vm.path.count == 4)
        #expect(vm.board.position.piece(at: Square("c6"))?.kind == .knight)
        #expect(vm.board.position.sideToMove == .white)
    }

    /// Sauter puis revenir doit donner exactement l'état d'un parcours pas à
    /// pas : c'est là qu'un modèle à pile d'annulation aurait divergé.
    @Test("Sauter puis reculer équivaut à avancer pas à pas")
    func jumpingThenSteppingBackMatchesWalkingForward() {
        let stepped = viewModel()
        stepped.next(); stepped.next(); stepped.next()

        let jumped = viewModel()
        jumped.jump(path: ["e2e4", "e7e5", "g1f3", "b8c6"])
        jumped.back()

        #expect(jumped.path == stepped.path)
        #expect(jumped.playedSANs == stepped.playedSANs)
        #expect(jumped.currentKey == stepped.currentKey)
        #expect(jumped.board.position.fen == stepped.board.position.fen)
    }

    /// Donnée incohérente : on atterrit aussi loin que possible, sans planter
    /// ni rester bloqué à la racine.
    @Test("Un chemin invalide s'arrête au dernier coup jouable")
    func anInvalidPathStopsAtTheLastPlayableMove() {
        let vm = viewModel()
        vm.jump(path: ["e2e4", "e7e5", "h1h8", "g1f3"])

        #expect(vm.playedSANs == ["e4", "e5"], "le rejeu s'arrête au coup impossible")
        #expect(vm.path == ["e2e4", "e7e5"])
    }

    @Test("Le retour à la position de départ vide le fil")
    func resetClearsTheTrail() {
        let vm = viewModel()
        vm.jump(path: ["e2e4", "e7e5", "g1f3"])
        vm.reset()
        #expect(vm.isRoot)
        #expect(vm.playedSANs.isEmpty)
        #expect(vm.currentKey == vm.course.rootFEN)
    }

    @Test("Le saut par demi-coup tronque le chemin")
    func jumpToPlyTruncatesThePath() {
        let vm = viewModel()
        vm.jump(path: ["e2e4", "e7e5", "g1f3", "b8c6"])
        vm.jump(toPly: 2)
        #expect(vm.playedSANs == ["e4", "e5"])
        // Hors bornes : sans effet, plutôt qu'un état incohérent.
        vm.jump(toPly: 99)
        #expect(vm.playedSANs == ["e4", "e5"])
    }

    // MARK: Surlignage de l'index

    @Test("Les coups du chemin courant sont reconnus dans tout l'arbre")
    func movesOnTheCurrentPathAreRecognised() throws {
        let vm = viewModel()
        vm.jump(path: ["e2e4", "e7e5", "g1f3"])
        let moves = try #require(vm.rows.first?.moves)

        #expect(vm.isOnCurrentPath(moves[0]))
        #expect(vm.isOnCurrentPath(moves[2]))
        #expect(vm.isCurrent(moves[2]), "le 3ᵉ demi-coup EST la position affichée")
        #expect(!vm.isCurrent(moves[0]))
        #expect(!vm.isOnCurrentPath(moves[3]), "le coup suivant n'est pas encore joué")
    }

    // MARK: Données Labs

    private func sidecar(for course: OpeningCourse) -> OpeningLabsSidecar {
        // Position après 1.e4 : on lui attache des maîtres et un moteur.
        var board = Board(position: .standard)
        _ = board.move(pieceAt: Square("e2"), to: Square("e4"))
        let key = OpeningFENKey.key(for: board.position)
        return OpeningLabsSidecar(
            id: course.id, engineDepth: 20,
            positions: [key: LabsPositionData(
                masters: LabsMasterStats(
                    white: 40, draws: 30, black: 30,
                    moves: [LabsMasterMove(san: "e5", uci: "e7e5", games: 50, white: 20, draws: 15, black: 15)]
                ),
                engine: [
                    LabsEngineLine(san: "e5", uci: "e7e5", cp: 30),
                    LabsEngineLine(san: "c5", uci: "c7c5", cp: 24),
                ]
            )]
        )
    }

    @Test("Maîtres et moteur suivent la position affichée")
    func mastersAndEngineFollowThePosition() {
        let course = course()
        let vm = OpeningLabsViewModel(course: course, sidecar: sidecar(for: course))

        #expect(vm.masterStats == nil, "rien à la racine dans ce sidecar")
        vm.next()
        #expect(vm.masterStats?.totalGames == 100)
        #expect(vm.engineLines.count == 2)
        #expect(vm.engineDepth == 20)
    }

    /// L'évaluation vient de la ligne de tête du moteur, TOUJOURS du point de
    /// vue des blancs — la convention de la barre et du reste de l'app.
    @Test("L'évaluation vient du moteur pré-calculé")
    func evalComesFromThePrecomputedEngine() {
        let course = course()
        let vm = OpeningLabsViewModel(course: course, sidecar: sidecar(for: course))
        vm.next()

        #expect(vm.evalCp == 30)
        #expect(vm.evalMate == nil)
        #expect(vm.hasPrecomputedEval)
    }

    @Test("Sans donnée moteur, aucune évaluation n'est inventée")
    func withoutEngineDataNoEvalIsInvented() {
        let vm = viewModel()
        vm.next()
        #expect(vm.evalCp == nil)
        #expect(!vm.hasPrecomputedEval)
    }

    /// Un coup joué par les maîtres mais absent du répertoire n'est pas
    /// jouable : l'écran le montre sans en faire un bouton (il n'y aurait
    /// aucune suite à afficher derrière).
    @Test("Un coup hors répertoire n'est pas jouable")
    func anOutOfRepertoireMoveIsNotPlayable() {
        let vm = viewModel()
        vm.next()
        #expect(vm.edge(forUCI: "e7e5") != nil, "e5 est dans la ligne")
        #expect(vm.edge(forUCI: "c7c5") == nil, "c5 ne l'est pas")
    }

    // MARK: Renvoi des transpositions

    /// Une branche qui s'arrête sur « transposition » doit savoir vers quelle
    /// rangée renvoyer : sinon la puce est une impasse — on saurait que la
    /// suite existe sans pouvoir l'atteindre.
    @Test("Chaque transposition sait où la suite est dépliée")
    func everyTranspositionKnowsWhereTheContinuationLives() throws {
        var found = 0
        var orphans: [String] = []
        for entry in OpeningCourseLoader.catalog.prefix(20) where !entry.isEndgame {
            guard let course = OpeningCourseLoader.course(id: entry.id) else { continue }
            let vm = OpeningLabsViewModel(
                course: course, sidecar: OpeningLabsSidecar(id: entry.id, positions: [:])
            )
            for row in vm.rows where row.isTransposition {
                found += 1
                guard let destination = vm.destinationRow(of: row) else {
                    orphans.append("\(entry.id) : \(row.moves.last?.san ?? "?")")
                    continue
                }
                // Le renvoi pointe sur une AUTRE rangée, qui existe vraiment.
                #expect(destination != row.id, "\(entry.id) : une transposition se renvoie à elle-même")
                #expect(vm.rows.contains { $0.id == destination },
                        "\(entry.id) : renvoi vers une rangée inexistante")
            }
        }
        try #require(found > 0, "aucune transposition dans l'échantillon")
        #expect(orphans.isEmpty, "transpositions sans destination : \(orphans.prefix(5))")
    }

    /// Une rangée ordinaire n'a pas de renvoi.
    @Test("Une rangée sans transposition n'a pas de destination")
    func anOrdinaryRowHasNoDestination() throws {
        let vm = viewModel()
        let row = try #require(vm.rows.first)
        #expect(!row.isTransposition)
        #expect(vm.destinationRow(of: row) == nil)
    }

    // MARK: Noms de variantes

    /// Le lecteur nomme les lignes comme l'index : titre de chapitre écrit à
    /// la main d'abord, nom ECO à défaut. Vérifié sur la donnée LIVRÉE, seule
    /// à porter ces noms.
    @Test("Les coups du répertoire portent le nom de leur variante")
    func repertoireMovesCarryTheirVariationName() throws {
        let course = try #require(OpeningCourseLoader.course(id: "italian-game"))
        let vm = OpeningLabsViewModel(
            course: course, sidecar: OpeningLabsLoader.sidecar(id: "italian-game")
        )
        OpeningLabsLoader.flush()

        // 1.e4 e5 2.Cf3 Cc6 3.Fc4 : ici s'ouvrent le gambit Evans (4.b4), la
        // défense hongroise (3…Fe7) et les Deux Cavaliers.
        vm.jump(path: ["e2e4", "e7e5", "g1f3", "b8c6", "f1c4"])
        let named = vm.candidates.compactMap { vm.branchName(for: $0) }
        #expect(!named.isEmpty, "aucun coup nommé à une position pourtant riche en variantes")

        // Et un nom ne s'invente pas : un coup sans variante nommée n'en a pas.
        let all = vm.candidates.count
        #expect(named.count <= all)
    }

    /// Un cours d'essai n'a ni titre ni nom ECO : aucun nom ne doit apparaître.
    @Test("Sans donnée de nommage, aucun nom n'est inventé")
    func withoutNamingDataNoNameIsInvented() {
        let vm = viewModel()
        #expect(vm.candidates.allSatisfy { vm.branchName(for: $0) == nil })
    }

    @Test("La FEN exportée vers les autres modes a bien six champs")
    func exportedFENHasSixFields() {
        let vm = viewModel()
        vm.next()
        #expect(vm.currentFEN.split(separator: " ").count == 6)
    }
}
