import ChessKit
import Testing
@testable import ChessLab

/// L'ARBRE des lignes (écran A) : chaque coup écrit une fois, les
/// débranchements imbriqués, et surtout le CHEMIN derrière chaque coup — c'est
/// lui qui fait atterrir au bon endroit quand on tape un coup au milieu d'une
/// variante.
@MainActor
struct OpeningLineTreeTests {

    // MARK: Fixtures

    /// Un cours à DEUX branches partageant leur début :
    ///
    ///     1.e4 e5 2.Cf3  →  2…Cc6 3.Fb5   (« espagnole »)
    ///                    →  2…Cf6         (« russe »)
    private func branchingCourse() -> OpeningCourse {
        var positions: [String: PositionNode] = [:]
        var edges: [String: [MoveEdge]] = [:]
        var board = Board(position: .standard)
        let root = OpeningFENKey.key(for: board.position)

        func walk(sans: [String], role: MoveRole) -> [String] {
            var board = Board(position: .standard)
            var keys = [OpeningFENKey.key(for: board.position)]
            for san in sans {
                guard
                    let parsed = Move(san: san, position: board.position),
                    let applied = board.move(pieceAt: parsed.start, to: parsed.end)
                else { break }
                let from = keys[keys.count - 1]
                let to = OpeningFENKey.key(for: board.position)
                if !(edges[from] ?? []).contains(where: { $0.toFEN == to }) {
                    edges[from, default: []].append(
                        MoveEdge(san: applied.san, uci: applied.lan, toFEN: to, role: role)
                    )
                }
                keys.append(to)
            }
            return keys
        }

        let spanish = walk(sans: ["e4", "e5", "Nf3", "Nc6", "Bb5"], role: .mainLine)
        let russian = walk(sans: ["e4", "e5", "Nf3", "Nf6"], role: .sideline)
        board = Board(position: .standard)

        for key in Set(spanish + russian) {
            positions[key] = PositionNode(fen: key, moves: edges[key] ?? [])
        }
        return OpeningCourse(
            id: "fixture-tree", name: "Deux branches", rootFEN: root,
            chapters: [
                OpeningChapter(id: "spanish", title: .both("Espagnole"), positionFENs: spanish),
                OpeningChapter(id: "russian", title: .both("Russe"), positionFENs: russian),
            ],
            positions: positions
        )
    }

    // MARK: Structure

    /// La règle du croquis : une rangée S'ARRÊTE à la première déviation, et
    /// chaque coup en double emploi n'est écrit qu'une fois.
    @Test("Une rangée s'arrête à la première déviation")
    func aRowStopsAtTheFirstDeviation() throws {
        let root = try #require(OpeningLineTree.build(course: branchingCourse()))

        #expect(root.depth == 0)
        #expect(root.moves.map(\.san) == ["e4", "e5", "Nf3"],
                "la rangée s'arrête là où le choix se pose, pas après")
        #expect(root.children.count == 2, "les deux suites descendent d'un étage")

        // Aucun coup en double dans tout l'arbre.
        let all = root.flattened.flatMap(\.moves).map(\.id)
        #expect(Set(all).count == all.count, "un coup apparaît deux fois dans l'arbre")
    }

    /// TOUTES les suites descendent d'un étage, la principale comprise : la
    /// prolonger à plat mentirait sur l'endroit où le choix se pose.
    @Test("Toutes les suites descendent d'un étage, la principale comprise")
    func everyContinuationGoesDownOneLevel() throws {
        let root = try #require(OpeningLineTree.build(course: branchingCourse()))
        let branches = root.children

        #expect(branches.map { $0.moves.first?.san } == ["Nc6", "Nf6"])
        #expect(branches.map(\.rank) == [0, 1], "la ligne principale est le rang 0, pas une exception")
        #expect(branches.allSatisfy { $0.depth == 1 })
        #expect(branches[0].moves.map(\.san) == ["Nc6", "Bb5"],
                "la branche court jusqu'à la déviation suivante")
    }

    /// La LIGNE PRINCIPALE de l'ouverture — celle qui s'affiche en gras :
    /// la rangée de tête et sa descendance de rang 0, et rien d'autre.
    @Test("La ligne principale se suit par les rangs 0")
    func theMainLineFollowsRankZero() throws {
        let root = try #require(OpeningLineTree.build(course: branchingCourse()))

        #expect(root.isOnMainLine, "la rangée de tête est la ligne principale")
        #expect(root.children[0].isOnMainLine, "le rang 0 la prolonge")
        #expect(!root.children[1].isOnMainLine, "un rang 1 n'en fait pas partie")
    }

    /// Une variante ne REDEVIENT jamais la ligne principale, si loin qu'aille
    /// son propre coup principal.
    @Test("Une variante ne redevient jamais la ligne principale")
    func aVariationNeverBecomesTheMainLineAgain() throws {
        var offenders: [String] = []
        for entry in OpeningCourseLoader.catalog where !entry.isEndgame {
            guard let course = OpeningCourseLoader.course(id: entry.id),
                  let root = OpeningLineTree.build(course: course)
            else { continue }
            func check(_ node: OpeningLineTree.Node) {
                for child in node.children where child.isOnMainLine && !node.isOnMainLine {
                    offenders.append("\(entry.id) : \(child.moves.first?.san ?? "?")")
                }
                node.children.forEach(check)
            }
            check(root)
        }
        #expect(offenders.isEmpty, "des variantes redeviennent ligne principale : \(offenders.prefix(5))")
    }

    /// Sur la donnée livrée, la ligne principale doit exister et rester une
    /// MINORITÉ des rangées : si tout l'arbre s'affichait en gras, le gras ne
    /// distinguerait plus rien.
    @Test("La ligne principale existe et reste minoritaire")
    func theMainLineExistsAndStaysAMinority() throws {
        var main = 0
        var total = 0
        for entry in OpeningCourseLoader.catalog where !entry.isEndgame {
            guard let course = OpeningCourseLoader.course(id: entry.id),
                  let root = OpeningLineTree.build(course: course)
            else { continue }
            let rows = root.flattened
            let onMain = rows.filter(\.isOnMainLine)
            #expect(!onMain.isEmpty, "\(entry.id) : aucune ligne principale")
            main += onMain.count
            total += rows.count
        }
        try #require(total > 500)
        let share = Double(main) / Double(total)
        #expect(share < 0.5, "la ligne principale couvre \(share) des rangées : le gras ne distingue plus")
    }

    /// L'ordre de LECTURE : la rangée, puis ses branches, chacune de même.
    @Test("L'aplatissement suit l'ordre de lecture")
    func flatteningFollowsReadingOrder() throws {
        let root = try #require(OpeningLineTree.build(course: branchingCourse()))
        let rows = root.flattened

        #expect(rows.count == 3)
        #expect(rows.map(\.depth) == [0, 1, 1])
        #expect(rows.map { $0.moves.first?.san } == ["e4", "Nc6", "Nf6"])
        #expect(Set(rows.map(\.id)).count == rows.count, "deux rangées partagent leur identifiant")
    }

    // MARK: Sauts

    /// Taper le n-ième coup d'une branche doit rejouer exactement les n
    /// premiers coups de CETTE branche.
    @Test("Chaque coup porte le chemin complet qui y mène")
    func everyMoveCarriesItsFullPath() throws {
        let course = branchingCourse()
        let root = try #require(OpeningLineTree.build(course: course))

        // Le dernier coup de la branche principale, et celui de l'autre : les
        // deux doivent porter le chemin qui y mène RÉELLEMENT.
        let bb5 = try #require(root.children.first?.moves.last)
        #expect(bb5.san == "Bb5")
        #expect(bb5.path == ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5"])

        let nf6 = try #require(root.children.last?.moves.first)
        #expect(nf6.san == "Nf6")
        #expect(nf6.path == ["e2e4", "e7e5", "g1f3", "g8f6"],
                "chaque branche repart de son point de déviation")

        for move in [bb5, nf6] {
            var key = course.rootFEN
            for uci in move.path {
                let edge = try #require(course.node(at: key)?.moves.first { $0.uci == uci })
                key = edge.toFEN
            }
            #expect(key == move.toFEN, "\(move.san) n'atterrit pas sur sa position")
        }
    }

    @Test("Le numéro de coup suit la ligne, blancs impairs")
    func plyNumberingFollowsTheLine() throws {
        let root = try #require(OpeningLineTree.build(course: branchingCourse()))
        let trunk = root.moves
        let spanish = try #require(root.children.first).moves

        #expect(trunk.map(\.ply) == [1, 2, 3])
        #expect(trunk.map(\.color) == [.white, .black, .white])
        // Une branche garde le numéro de coup de la ligne : elle part du
        // 4ᵉ demi-coup, elle s'annonce « 2…Cc6 ».
        #expect(spanish.map(\.ply) == [4, 5])
        #expect(spanish.map(\.color) == [.black, .white])
        #expect(spanish[0].numberPrefix(isFirstOfLine: true) == "2…")
        #expect(spanish[0].numberPrefix(isFirstOfLine: false) == nil)
        #expect(spanish[1].numberPrefix(isFirstOfLine: false) == "3.")
    }

    // MARK: Transpositions et cycles

    /// Une position rejointe par un second chemin ne se déplie pas deux fois :
    /// la branche s'arrête sur un repère. Sans cette règle, un cycle ferait
    /// tourner la construction sans fin.
    @Test("Une transposition s'arrête au lieu de se déplier deux fois")
    func aTranspositionStopsInsteadOfUnfoldingTwice() throws {
        let base = branchingCourse()
        var positions = base.positions
        // La fin de l'espagnole renvoie vers la position après 2.Cf3 : cycle.
        let spanishEnd = base.chapters![0].positionFENs.last!
        let afterNf3 = base.chapters![1].positionFENs[3]
        positions[spanishEnd] = PositionNode(
            fen: spanishEnd,
            moves: [MoveEdge(san: "→", uci: "a1a1", toFEN: afterNf3, role: .sideline)]
        )
        let cyclic = OpeningCourse(
            id: base.id, name: base.name, rootFEN: base.rootFEN,
            chapters: base.chapters, positions: positions
        )

        let root = try #require(OpeningLineTree.build(course: cyclic))
        let rows = root.flattened

        #expect(rows.contains { $0.isTransposition }, "la boucle doit être signalée")
        let all = rows.flatMap(\.moves).map(\.id)
        #expect(Set(all).count == all.count, "aucun coup dupliqué malgré le cycle")
    }

    // MARK: Titres de chapitre

    /// Un titre va sur la branche où son chapitre QUITTE la ligne dont il
    /// descend. Un chapitre qui ne la quitte jamais n'en reçoit pas : la carte
    /// porte déjà le nom de l'ouverture.
    @Test("Un titre de chapitre se pose sur sa branche")
    func aChapterTitleLandsOnItsBranch() throws {
        let root = try #require(OpeningLineTree.build(course: branchingCourse()))

        #expect(root.chapterTitle == nil, "la rangée de tête ne porte pas de titre : c'est l'ouverture")
        #expect(root.children[0].chapterTitle == nil, "l'espagnole EST la ligne principale")
        #expect(root.children[1].chapterTitle?.fr == "Russe", "la russe s'annonce sur sa branche")
    }

    @Test("Un cours sans coup ne produit pas d'arbre")
    func aCourseWithoutMovesYieldsNoTree() {
        let empty = OpeningCourse(
            id: "vide", name: "Vide", rootFEN: "8/8/8/8/8/8/8/K6k w - -",
            positions: ["8/8/8/8/8/8/8/K6k w - -": PositionNode(fen: "8/8/8/8/8/8/8/K6k w - -")]
        )
        #expect(OpeningLineTree.build(course: empty) == nil)
    }

    // MARK: L'arbre des cours RÉELLEMENT livrés

    /// Le contrat que l'écran suppose, vérifié sur la donnée embarquée : tout
    /// chemin de l'arbre doit se rejouer intégralement dans le graphe. Un seul
    /// chemin faux, et taper ce coup atterrit ailleurs — en silence.
    @Test("Tout chemin de l'arbre se rejoue dans le graphe livré")
    func shippedTreePathsAreReplayable() throws {
        let entries = OpeningCourseLoader.catalog.filter { !$0.isEndgame }
        try #require(!entries.isEmpty, "aucune ouverture embarquée")

        var checked = 0
        for entry in entries.prefix(12) {
            let course = try #require(OpeningCourseLoader.course(id: entry.id))
            let root = try #require(OpeningLineTree.build(course: course))
            for row in root.flattened {
                for move in row.moves {
                    var key = course.rootFEN
                    for uci in move.path {
                        let edge = course.node(at: key)?.moves.first { $0.uci == uci }
                        key = try #require(edge?.toFEN, "\(entry.id) : chemin rompu sur \(uci)")
                    }
                    #expect(key == move.toFEN, "\(entry.id) : \(move.san) n'atterrit pas sur sa position")
                    checked += 1
                }
            }
        }
        #expect(checked > 500, "l'échantillon doit être significatif (obtenu : \(checked))")
    }

    /// 🐛 Régression : deux branches qui commencent par le MÊME coup avaient le
    /// même identifiant. `ForEach` affichait alors la première deux fois, et la
    /// seconde — une variante entière — disparaissait sans le moindre signe.
    @Test("Les identifiants de rangées et de coups sont uniques")
    func rowAndMoveIdentifiersAreUnique() throws {
        let entries = OpeningCourseLoader.catalog.filter { !$0.isEndgame }
        try #require(!entries.isEmpty)

        var courses = 0
        for entry in entries {
            guard let course = OpeningCourseLoader.course(id: entry.id),
                  let root = OpeningLineTree.build(course: course)
            else { continue }
            let rows = root.flattened
            let rowIDs = rows.map(\.id)
            #expect(Set(rowIDs).count == rowIDs.count, "\(entry.id) : deux rangées partagent leur identifiant")
            let moveIDs = rows.flatMap(\.moves).map(\.id)
            #expect(Set(moveIDs).count == moveIDs.count, "\(entry.id) : un coup apparaît deux fois")
            courses += 1
        }
        #expect(courses > 50, "tout le catalogue doit être couvert (obtenu : \(courses))")
    }

    /// 🐛 Régression : à une déviation, la LIGNE PRINCIPALE est dépliée avant
    /// ses alternatives.
    ///
    /// Sinon une variante qui transpose plus loin dans la ligne principale
    /// réclame la position avant elle, et c'est la ligne principale qui
    /// s'arrête sur un « transposition » — l'inverse de ce qu'on veut lire.
    ///
    /// Vérifié sur un cas CONSTRUIT, parce que c'est l'ordre d'expansion qu'on
    /// veut prouver, et qu'il ne se lit pas dans l'arbre fini : sur la donnée
    /// livrée, un rang 0 peut légitimement transposer vers une position
    /// dépliée bien plus tôt, ailleurs dans l'arbre.
    @Test("La ligne principale est dépliée avant ses alternatives")
    func theMainLineIsExpandedBeforeItsAlternatives() throws {
        var board = Board(position: .standard)
        var edges: [String: [MoveEdge]] = [:]
        let root = OpeningFENKey.key(for: board.position)

        func line(_ sans: [String], role: MoveRole) -> [String] {
            var board = Board(position: .standard)
            var keys = [OpeningFENKey.key(for: board.position)]
            for san in sans {
                guard
                    let parsed = Move(san: san, position: board.position),
                    let applied = board.move(pieceAt: parsed.start, to: parsed.end)
                else { break }
                let from = keys[keys.count - 1]
                let to = OpeningFENKey.key(for: board.position)
                if !(edges[from] ?? []).contains(where: { $0.toFEN == to }) {
                    edges[from, default: []].append(
                        MoveEdge(san: applied.san, uci: applied.lan, toFEN: to, role: role)
                    )
                }
                keys.append(to)
            }
            return keys
        }

        // Deux ordres de coups qui MÈNENT À LA MÊME POSITION (transposition
        // authentique) : 1.e4 e5 2.Cf3 Cc6 3.Fb5 et 1.e4 e5 2.Cf3 Cc6 par
        // l'autre cavalier d'abord. La ligne principale doit être celle qui
        // se déplie ; la seconde doit hériter du repère.
        let main = line(["d4", "d5", "Nf3", "Nf6"], role: .mainLine)
        _ = line(["Nf3", "d5", "d4", "Nf6"], role: .sideline)
        board = Board(position: .standard)

        var positions: [String: PositionNode] = [:]
        for (key, moves) in edges { positions[key] = PositionNode(fen: key, moves: moves) }
        for key in main where positions[key] == nil {
            positions[key] = PositionNode(fen: key, moves: [])
        }
        let course = OpeningCourse(
            id: "fixture-transpo", name: "Transposition", rootFEN: root, positions: positions
        )

        let tree = try #require(OpeningLineTree.build(course: course))
        let rows = tree.flattened
        let mainBranch = try #require(rows.first { $0.moves.first?.san == "d4" })
        let sideBranch = try #require(rows.first { $0.moves.first?.san == "Nf3" })

        #expect(mainBranch.rank == 0)
        #expect(!mainBranch.isTransposition, "la ligne principale doit se déplier")
        #expect(mainBranch.moves.count > sideBranch.moves.count,
                "c'est la ligne principale qui porte la suite, pas l'alternative")

        // Et, invariant général : jamais deux fois le même coup.
        let all = rows.flatMap(\.moves).map(\.id)
        #expect(Set(all).count == all.count)
    }

    /// L'arbre doit rester LISIBLE. Si ces bornes explosent, l'écran redevient
    /// le pavé qu'on vient de supprimer.
    @Test("L'arbre livré reste borné en rangées et en profondeur")
    func theShippedTreeStaysBounded() throws {
        var rowCounts: [Int] = []
        var deepest = 0
        for entry in OpeningCourseLoader.catalog where !entry.isEndgame {
            guard let course = OpeningCourseLoader.course(id: entry.id),
                  let root = OpeningLineTree.build(course: course)
            else { continue }
            let rows = root.flattened
            rowCounts.append(rows.count)
            deepest = max(deepest, rows.map(\.depth).max() ?? 0)
        }

        try #require(rowCounts.count > 50)
        let biggest = rowCounts.max() ?? 0
        #expect(biggest <= 200, "une ouverture produit \(biggest) rangées : l'arbre ne compresse plus")
        #expect(deepest <= 12, "débranchement de profondeur \(deepest) : le retrait n'a plus de place")
        #expect(deepest >= 3, "aucune imbrication : l'arbre ne débranche plus")
    }

    /// Sur la donnée livrée, les titres écrits à la main doivent trouver leur
    /// branche — c'est tout l'intérêt de les avoir conservés.
    @Test("Les titres de chapitre trouvent leur branche")
    func chapterTitlesFindTheirBranch() throws {
        let course = try #require(OpeningCourseLoader.course(id: "italian-game"))
        let root = try #require(OpeningLineTree.build(course: course))
        let rows = root.flattened

        /// Le coup qui ouvre la branche portant ce titre.
        func head(of title: String) -> String? {
            rows.first { $0.chapterTitle?.fr?.contains(title) == true }?.moves.first?.san
        }

        #expect(head(of: "Evans") == "b4", "le gambit Evans s'annonce sur 4.b4")
        #expect(head(of: "Fried Liver") == "Nxd5")
        #expect(head(of: "hongroise") == "Be7")
        #expect(head(of: "Traxler") == "Bc5")

        // Et aucun titre ne se retrouve à deux endroits.
        let titles = rows.compactMap { $0.chapterTitle?.fr }
        #expect(Set(titles).count == titles.count, "un titre est posé sur deux branches")
    }
}
