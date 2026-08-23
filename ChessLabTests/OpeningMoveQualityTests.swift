import ChessKit
import Testing
@testable import ChessLab

/// Le verdict porté sur les coups de l'index : gaffe, erreur, imprécision,
/// occasion manquée, coup brillant — et RIEN d'autre.
@MainActor
struct OpeningMoveQualityTests {

    // MARK: Fixture

    /// Cours linéaire d'essai, avec un sidecar dont on choisit les évaluations
    /// coup par coup. C'est le seul moyen de tester des verdicts précis : la
    /// donnée livrée ne contient pas d'exemple de chaque catégorie.
    private func course() -> OpeningCourse {
        OpeningGraphFixtures.linearCourse(
            id: "fixture-quality", name: "Ligne d'essai", sans: ["e4", "e5", "Nf3", "Nc6"]
        )
    }

    /// Clés FEN successives de la ligne, racine incluse.
    private func keys(of course: OpeningCourse) -> [String] {
        var keys = [course.rootFEN]
        var key = course.rootFEN
        while let edge = course.node(at: key)?.moves.first {
            key = edge.toFEN
            keys.append(key)
        }
        return keys
    }

    /// Sidecar donnant à chaque position l'évaluation voulue (centipions, point
    /// de vue BLANC), et comme meilleur coup celui de la ligne.
    private func sidecar(for course: OpeningCourse, evals: [Int]) -> OpeningLabsSidecar {
        let keys = keys(of: course)
        var positions: [String: LabsPositionData] = [:]
        for (index, key) in keys.enumerated() where index < evals.count {
            let best = course.node(at: key)?.moves.first
            positions[key] = LabsPositionData(
                engine: [
                    LabsEngineLine(san: best?.san ?? "—", uci: best?.uci ?? "0000", cp: evals[index]),
                ]
            )
        }
        return OpeningLabsSidecar(id: course.id, engineDepth: 20, positions: positions)
    }

    private func qualities(evals: [Int]) -> [MoveQuality?] {
        let course = course()
        let root = OpeningLineTree.build(course: course, sidecar: sidecar(for: course, evals: evals))
        return root?.flattened.flatMap(\.moves).map(\.quality) ?? []
    }

    // MARK: Ce qui est jugé

    /// Une ligne où rien ne bouge ne porte AUCUNE marque : c'est tout l'intérêt
    /// du filtre — 97 % des coups du catalogue livré sont dans ce cas.
    @Test("Une ligne saine ne porte aucun verdict")
    func aSoundLineCarriesNoVerdict() {
        #expect(qualities(evals: [20, 20, 20, 20, 20]).allSatisfy { $0 == nil })
    }

    /// L'évaluation est au point de vue des BLANCS ; la perte se mesure, elle,
    /// du point de vue du joueur qui vient de jouer. Une chute de +0,20 à
    /// −3,00 est une gaffe des BLANCS ; la même chute vue des noirs serait un
    /// gain. C'est l'inversion de signe la plus facile à rater du domaine.
    @Test("Une chute brutale après un coup blanc est une gaffe blanche")
    func aCollapseAfterAWhiteMoveIsAWhiteBlunder() {
        // Coup 1 (blancs) : +0,20 → −3,00.
        let verdicts = qualities(evals: [20, -300, -300, -300, -300])
        #expect(verdicts.first == .blunder)
    }

    /// Symétrique : un coup NOIR qui fait grimper l'évaluation blanche est une
    /// faute noire.
    @Test("Une envolée après un coup noir est une gaffe noire")
    func aSurgeAfterABlackMoveIsABlackBlunder() {
        // Coup 2 (noirs) : l'éval blanche passe de +0,20 à +3,00.
        let verdicts = qualities(evals: [20, 20, 300, 300, 300])
        #expect(verdicts.count >= 2)
        #expect(verdicts[0] == nil, "le coup blanc n'a rien perdu")
        #expect(verdicts[1] == .blunder)
    }

    /// L'échelle intermédiaire : imprécision puis erreur, aux seuils de
    /// ``MoveClassifier`` (5 % et 10 % de probabilité de gain).
    @Test("L'échelle intermédiaire distingue imprécision et erreur")
    func theMiddleOfTheScaleSeparatesInaccuracyFromMistake() {
        let slight = qualities(evals: [20, -50, -50, -50, -50]).first ?? nil
        let worse = qualities(evals: [20, -150, -150, -150, -150]).first ?? nil
        #expect(slight == .inaccuracy)
        #expect(worse == .mistake)
    }

    // MARK: Ce qui n'est PAS affiché

    /// Un bon coup ne porte pas de pastille — sinon l'index redeviendrait
    /// illisible. Seules cinq catégories passent le filtre.
    @Test("Seules les cinq catégories demandées sont affichables")
    func onlyTheFiveRequestedCategoriesAreDisplayable() {
        #expect(OpeningMoveQuality.displayed == [.brilliant, .miss, .inaccuracy, .mistake, .blunder])
        for excluded: MoveQuality in [.great, .best, .excellent, .good, .book] {
            #expect(!OpeningMoveQuality.displayed.contains(excluded), "\(excluded.rawValue) ne doit pas s'afficher")
        }
    }

    /// Sans sidecar, aucun verdict — et surtout pas de plantage : l'index
    /// reste parfaitement navigable, il ne porte simplement pas de marques.
    @Test("Sans données moteur, aucun verdict n'est inventé")
    func withoutEngineDataNoVerdictIsInvented() {
        let course = course()
        let moves = OpeningLineTree.build(course: course)?.flattened.flatMap(\.moves) ?? []
        #expect(!moves.isEmpty)
        #expect(moves.allSatisfy { $0.quality == nil })
    }

    /// Une position dont le sidecar ne dit rien ne casse pas la ligne : les
    /// coups qu'on peut juger le sont, les autres non.
    @Test("Une position sans évaluation laisse ses voisines jugées")
    func aPositionWithoutEvalLeavesItsNeighboursJudged() {
        let course = course()
        var sidecar = sidecar(for: course, evals: [20, -300, -300, -300, -300])
        // On retire l'évaluation de la position de départ : le 1er coup n'est
        // plus jugeable, le reste doit continuer de l'être.
        var positions = sidecar.positions
        positions.removeValue(forKey: course.rootFEN)
        sidecar = OpeningLabsSidecar(id: course.id, engineDepth: 20, positions: positions)

        let moves = OpeningLineTree.build(course: course, sidecar: sidecar)?.flattened.flatMap(\.moves) ?? []
        #expect(moves.first?.quality == nil, "sans position de départ, pas de verdict")
        #expect(moves.count > 1)
    }

    // MARK: Sur le catalogue LIVRÉ

    /// Le filtre doit rester RARE. Mesure du 23/08 sur les 58 ouvertures :
    /// 7 252 coups d'index, 97,2 % sans marque, 166 imprécisions, 25 erreurs,
    /// 7 gaffes, 2 coups brillants. Si ce test se met à voir un coup sur cinq
    /// marqué, c'est que la classification a dérivé — et l'index redevient le
    /// pavé illisible qu'on vient de corriger.
    @Test("Les verdicts restent rares sur le catalogue livré")
    func verdictsStayRareOnTheShippedCatalog() throws {
        var total = 0
        var marked = 0
        var seen: Set<MoveQuality> = []
        for entry in OpeningCourseLoader.catalog where !entry.isEndgame {
            guard let course = OpeningCourseLoader.course(id: entry.id) else { continue }
            let sidecar = OpeningLabsLoader.sidecar(id: entry.id)
            OpeningLabsLoader.flush()
            for row in OpeningLineTree.build(course: course, sidecar: sidecar)?.flattened ?? [] {
                for move in row.moves {
                    total += 1
                    if let quality = move.quality {
                        marked += 1
                        seen.insert(quality)
                    }
                }
            }
        }

        try #require(total > 5000, "l'index complet doit être parcouru (obtenu : \(total))")
        let rate = Double(marked) / Double(total)
        #expect(rate > 0.005, "aucun verdict : la classification ne tourne plus")
        #expect(rate < 0.10, "un coup sur dix marqué : l'index redevient illisible (\(rate))")
        #expect(seen.isSubset(of: OpeningMoveQuality.displayed), "une catégorie non demandée s'affiche")
        #expect(seen.contains(.inaccuracy) && seen.contains(.blunder))
    }

    /// Contrôle de SENS, et pas seulement de forme : dans un piège authentique,
    /// le coup qui y tombe doit être jugé sévèrement.
    ///
    /// Le gambit Englund est le cas d'école : 1.d4 e5 2.dxe5 Cc6 3.Cf3 De7
    /// 4.Ff4 Db4+ 5.Fd2 Dxb2 6.Fc3?? Fb4! et les blancs perdent la dame. Le
    /// moteur retrouve les deux coups, indépendamment de ce que l'auteur du
    /// cours a marqué — c'est cette CONCORDANCE qui valide la chaîne.
    @Test("Le piège de l'Englund est jugé comme tel")
    func theEnglundTrapIsJudgedAsSuch() throws {
        let course = try #require(OpeningCourseLoader.course(id: "englund-gambit"))
        let sidecar = OpeningLabsLoader.sidecar(id: "englund-gambit")
        try #require(!sidecar.positions.isEmpty, "sidecar Englund absent")

        let moves = OpeningLineTree.build(course: course, sidecar: sidecar)?.flattened.flatMap(\.moves) ?? []
        let blunder = moves.first { $0.quality == .blunder }
        let brilliant = moves.first { $0.quality == .brilliant }

        #expect(blunder?.san == "Bc3", "le coup qui tombe dans le piège doit être une gaffe")
        #expect(brilliant?.san == "Bb4", "la réfutation doit être saluée")
    }
}
