import ChessKit
import Foundation

/// L'ARBRE des lignes d'une ouverture — ce que l'écran d'index affiche.
///
/// ## Le principe : chaque coup écrit UNE FOIS
///
/// La première version listait un chapitre par carte, chacun repartant de la
/// racine. « 1.e4 d5 2.exd5 ♛xd5 » se relisait donc douze fois avant d'arriver
/// à ce qui distingue les variantes. Ici, le tronc commun n'est écrit qu'une
/// fois et l'arbre DÉBRANCHE :
///
///     1.e4 d5
///       ↳ 2.exd5
///           ○ 2…♛xd5
///               □ 3.♘c3
///                   ◇ 3…♛a5 4.d4 ♞f6 …
///                   ◇ 3…♛d6 …
///               □ 3.♘f3 ♗g4 …
///           ○ 2…♞f6 …
///       ↳ 2.e5 ♗f5
///
/// ## Comment il se construit
///
/// Une rangée court tant que la position n'offre QU'UNE suite ; à la première
/// DÉVIATION elle s'arrête, et chaque suite — la principale comprise —
/// descend d'un étage et repart de la même façon.
///
/// Chaque rangée répond ainsi à une seule question : « à cette position, quels
/// sont les choix ? ». Prolonger la ligne principale à plat par-dessus une
/// déviation mentirait sur l'endroit où le choix se pose.
///
/// Ordre des branches : ligne principale d'abord, puis par popularité club —
/// le même que la liste des coups du lecteur, pour qu'on ne réapprenne pas un
/// ordre en passant d'un écran à l'autre.
///
/// ## Les transpositions
///
/// Le graphe fusionne les transpositions : une même position peut se rejoindre
/// par deux chemins. Une position n'est donc DÉPLIÉE QU'UNE FOIS ; la seconde
/// arrivée s'arrête sur un repère « transposition », cliquable comme les
/// autres. Sans cette règle, des sous-arbres entiers apparaîtraient en double
/// — exactement ce que l'arbre est censé supprimer — et un cycle ferait
/// tourner la construction sans fin.
///
/// ## Mesuré sur le catalogue livré
///
/// Voir `OpeningLineTreeTests` pour les bornes mesurées sur les 58 ouvertures
/// (nombre de rangées et profondeur de débranchement) — ce sont elles qui
/// garantissent que l'écran reste lisible sans repli ni troncature.
enum OpeningLineTree {

    /// Un nœud = une RANGÉE à l'écran : un tronçon de coups d'un seul tenant,
    /// puis les branches qui en partent.
    struct Node: Identifiable, Hashable, Sendable {
        /// Étage de débranchement — 0 pour le tronc. Pilote le retrait.
        let depth: Int
        /// Rang parmi les branches sœurs : 0 = le coup principal de la
        /// position, les suivants sont les alternatives.
        let rank: Int
        /// Les coups du tronçon, dans l'ordre.
        var moves: [OpeningLineIndex.IndexedMove]
        /// Titre de chapitre que CETTE branche ouvre — voir ``titles(for:in:)``.
        var chapterTitle: LocalizedText?
        /// Nom de variante atteint au bout du tronçon, quand la donnée en a un.
        var ecoName: String?
        /// La branche s'arrête parce que la suite est déjà dépliée ailleurs.
        var isTransposition: Bool
        /// Pour chaque étage traversé (1…`depth`), l'ancêtre de cet étage
        /// était-il le DERNIER de sa fratrie ?
        ///
        /// C'est ce qui permet de dessiner un vrai arbre plutôt qu'une colonne
        /// de marqueurs : un rail ne se prolonge sous une rangée que si la
        /// branche de cet étage a encore des sœurs à venir, et le connecteur
        /// de la rangée est un « └ » quand elle ferme sa fratrie, un « ├ »
        /// sinon. Le dernier élément décrit la rangée elle-même.
        var lineage: [Bool] = []

        /// Cette rangée est-elle SUR la ligne principale de l'ouverture ?
        ///
        /// Vrai pour la rangée de tête et pour toute descendance qui n'a pris
        /// que des rangs 0. Un seul rang > 0 quelque part dans la lignée, et
        /// on est dans une variante — définitivement.
        var isOnMainLine: Bool = false
        var children: [Node]

        /// Identité = le chemin complet du dernier coup, plus l'étage. Le
        /// chemin seul ne suffirait pas : après une transposition, deux nœuds
        /// peuvent finir sur la même position.
        var id: String { "\(depth)|" + (moves.last?.path ?? []).joined(separator: ".") }

        /// Toutes les rangées de ce sous-arbre, dans l'ordre de LECTURE
        /// (le tronçon, puis ses branches, chacune de même).
        var flattened: [Node] {
            [self] + children.flatMap(\.flattened)
        }
    }

    // MARK: Construction

    /// Construit l'arbre d'un cours. `nil` si la racine n'offre aucun coup.
    ///
    /// - Parameter sidecar: données Labs, pour juger la qualité des coups
    ///   (voir ``OpeningMoveQuality``). Absent : aucun verdict affiché.
    static func build(
        course: OpeningCourse, languageCode: String = "fr",
        sidecar: OpeningStatsSidecar? = nil
    ) -> Node? {
        var expanded: Set<String> = [course.rootFEN]
        let run = expand(
            from: course.rootFEN, path: [], depth: 0,
            course: course, languageCode: languageCode, expanded: &expanded
        )
        guard !run.moves.isEmpty || !run.children.isEmpty else { return nil }

        var root = Node(
            depth: 0, rank: 0, moves: run.moves,
            ecoName: run.moves.last.flatMap { course.node(at: $0.toFEN)?.ecoName },
            isTransposition: run.isTransposition, isOnMainLine: true, children: run.children
        )
        root = labelled(root, with: titles(for: course, in: root))
        root = withLineage(root, inherited: [])
        if let sidecar { root = judged(root, sidecar: sidecar) }
        return root
    }

    /// Déplie une ligne. La rangée courante s'arrête à la PREMIÈRE DÉVIATION,
    /// et toutes les suites — la principale comprise — descendent d'un étage.
    ///
    /// C'est la règle du croquis, et elle a une conséquence qu'il faut assumer :
    /// dans un cours qui offre des alternatives dès le deuxième coup, les
    /// premières rangées ne portent qu'un ou deux coups. Ce n'est pas un
    /// défaut d'affichage — c'est l'arbre réel de l'ouverture. Chaque rangée
    /// répond à une seule question : « à cette position, quels sont les
    /// choix ? ». Prolonger la ligne principale à plat par-dessus une déviation
    /// mentirait sur l'endroit où le choix se pose.
    ///
    /// - important: les branches sont dépliées DANS L'ORDRE DES RANGS, la
    ///   principale en premier. Sinon une variante qui transpose plus loin
    ///   dans la ligne principale réclame la position avant elle, et c'est la
    ///   ligne principale qui s'arrête sur un « transposition » — l'inverse de
    ///   ce qu'on veut lire.
    private static func expand(
        from fen: String, path: [String], depth: Int, onMainLine: Bool = true,
        course: OpeningCourse, languageCode: String, expanded: inout Set<String>
    ) -> (moves: [OpeningLineIndex.IndexedMove], children: [Node], isTransposition: Bool) {
        var moves: [OpeningLineIndex.IndexedMove] = []
        var cursor = fen
        var cursorPath = path

        while true {
            let edges = ordered(course.node(at: cursor)?.moves ?? [])
            guard let only = edges.first else { return (moves, [], false) }

            // Une seule suite : pas de choix à poser, la rangée continue.
            if edges.count == 1 {
                moves.append(move(only, from: cursor, path: cursorPath, course: course, languageCode: languageCode))
                guard !expanded.contains(only.toFEN) else { return (moves, [], true) }
                expanded.insert(only.toFEN)
                cursorPath.append(only.uci)
                cursor = only.toFEN
                continue
            }

            // Déviation : la rangée s'arrête ICI, chaque suite ouvre la sienne.
            var children: [Node] = []
            for (rank, edge) in edges.enumerated() {
                let head = move(edge, from: cursor, path: cursorPath, course: course, languageCode: languageCode)
                // La ligne principale se prolonge par le rang 0, et seulement
                // si on y était déjà : une variante ne redevient jamais la
                // ligne principale, si loin qu'aille son propre coup principal.
                let childOnMainLine = onMainLine && rank == 0
                guard !expanded.contains(edge.toFEN) else {
                    children.append(Node(
                        depth: depth + 1, rank: rank, moves: [head],
                        ecoName: course.node(at: edge.toFEN)?.ecoName,
                        isTransposition: true, isOnMainLine: childOnMainLine, children: []
                    ))
                    continue
                }
                expanded.insert(edge.toFEN)
                let sub = expand(
                    from: edge.toFEN, path: cursorPath + [edge.uci], depth: depth + 1,
                    onMainLine: childOnMainLine,
                    course: course, languageCode: languageCode, expanded: &expanded
                )
                let branchMoves = [head] + sub.moves
                children.append(Node(
                    depth: depth + 1, rank: rank, moves: branchMoves,
                    ecoName: branchMoves.last.flatMap { course.node(at: $0.toFEN)?.ecoName },
                    isTransposition: sub.isTransposition, isOnMainLine: childOnMainLine,
                    children: sub.children
                ))
            }
            return (moves, children, false)
        }
    }

    /// Ligne principale d'abord, puis par popularité club — même ordre que
    /// ``OpeningReaderViewModel/candidates``.
    private static func ordered(_ edges: [MoveEdge]) -> [MoveEdge] {
        edges.sorted { a, b in
            if (a.role == .mainLine) != (b.role == .mainLine) { return a.role == .mainLine }
            return (a.popularityClub ?? 0) > (b.popularityClub ?? 0)
        }
    }

    private static func move(
        _ edge: MoveEdge, from fen: String, path: [String],
        course: OpeningCourse, languageCode: String
    ) -> OpeningLineIndex.IndexedMove {
        let full = path + [edge.uci]
        return OpeningLineIndex.IndexedMove(
            ply: full.count,
            san: edge.san,
            uci: edge.uci,
            toFEN: edge.toFEN,
            fromFEN: fen,
            role: edge.role,
            ecoName: course.node(at: edge.toFEN)?.ecoName,
            isCritical: edge.isCritical,
            hasComment: edge.displayableComment(languageCode) != nil,
            path: full
        )
    }

    // MARK: Titres de chapitre

    /// Où poser chaque titre de chapitre écrit à la main.
    ///
    /// Un chapitre est un CHEMIN, l'arbre est fait de nœuds : il n'y a pas de
    /// correspondance directe. La règle retenue, après essais sur la donnée
    /// réelle, est celle du **point de divergence** : le titre va sur la
    /// première branche de sa colonne vertébrale qui n'est PAS le coup
    /// principal de sa position — c'est-à-dire là où ce chapitre quitte la
    /// ligne dont il descend.
    ///
    /// Elle donne, sans exception notable : Gambit Evans → 4.b4, Fried Liver →
    /// 6.Cxf7, Défense hongroise → 3…Fe7, Attaque Panov → 3.exd5, Karpov →
    /// 4…Cd7. Un chapitre qui ne quitte jamais la ligne principale n'obtient
    /// pas de titre — c'est correct : la carte porte déjà le nom de
    /// l'ouverture, et c'est bien de lui qu'il parle.
    ///
    /// Chaque branche n'est réclamée qu'une fois, dans l'ordre des chapitres
    /// (le fichier les range du principal au marginal) : deux chapitres qui
    /// divergent au même endroit ne se disputent pas la place.
    private static func titles(for course: OpeningCourse, in root: Node) -> [String: LocalizedText] {
        // Toutes les têtes de branche, par position d'arrivée.
        var headRank: [String: Int] = [:]
        for node in root.flattened where node.depth > 0 {
            guard let head = node.moves.first else { continue }
            headRank[head.toFEN] = node.rank
        }

        var assigned: [String: LocalizedText] = [:]
        var claimed: Set<String> = []
        for chapter in course.chapters ?? [] {
            let candidates = spine(of: chapter, in: course) + chapter.positionFENs
            for fen in candidates {
                guard let rank = headRank[fen], rank > 0, !claimed.contains(fen) else { continue }
                claimed.insert(fen)
                assigned[fen] = chapter.title
                break
            }
        }
        return assigned
    }

    /// La colonne vertébrale d'un chapitre : son premier tronçon CONTIGU
    /// depuis le début. Un chapitre liste souvent, après sa ligne, des
    /// positions de variantes annexes ; les prendre en compte d'abord ferait
    /// atterrir le titre sur une branche qui n'est pas la sienne.
    private static func spine(of chapter: OpeningChapter, in course: OpeningCourse) -> [String] {
        var result: [String] = []
        var previous: String?
        for fen in chapter.positionFENs {
            if let previous, !(course.node(at: previous)?.moves.contains { $0.toFEN == fen } ?? false) {
                break
            }
            result.append(fen)
            previous = fen
        }
        return result
    }

    /// Renseigne ``Node/lineage`` de proche en proche.
    ///
    /// Une passe SÉPARÉE, parce qu'un nœud ne peut pas savoir s'il est le
    /// dernier de sa fratrie pendant qu'on le construit : c'est son parent qui
    /// le sait, une fois tous ses enfants faits.
    private static func withLineage(_ node: Node, inherited: [Bool]) -> Node {
        var node = node
        node.lineage = inherited
        let lastIndex = node.children.count - 1
        node.children = node.children.enumerated().map { index, child in
            withLineage(child, inherited: inherited + [index == lastIndex])
        }
        return node
    }

    private static func labelled(_ node: Node, with titles: [String: LocalizedText]) -> Node {
        var node = node
        if let head = node.moves.first, let title = titles[head.toFEN] {
            node.chapterTitle = title
        }
        node.children = node.children.map { labelled($0, with: titles) }
        return node
    }

    // MARK: Verdicts moteur

    /// Attribue son verdict à chaque coup — seconde passe, parce qu'un coup
    /// brillant se reconnaît en partie au coup SUIVANT (un sacrifice repris
    /// sur-le-champ n'en est pas un).
    ///
    /// Le coup suivant est cherché dans le MÊME tronçon. Au bout d'un tronçon,
    /// la suite dépend de la branche qu'on prend : aucune n'est « le » coup
    /// suivant, et en choisir une au hasard fausserait le jugement.
    private static func judged(_ node: Node, sidecar: OpeningStatsSidecar) -> Node {
        var node = node
        node.moves = node.moves.enumerated().map { index, move in
            var move = move
            let next = index + 1 < node.moves.count ? node.moves[index + 1].uci : nil
            move.quality = OpeningMoveQuality.classify(
                .init(fromFEN: move.fromFEN, toFEN: move.toFEN, uci: move.uci, nextUCI: next),
                sidecar: sidecar
            )
            return move
        }
        node.children = node.children.map { judged($0, sidecar: sidecar) }
        return node
    }
}
