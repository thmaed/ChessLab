package com.chesslab.courses

import chesskit.Piece

/**
 * Le COUP tel que l'index des lignes le manipule : de quoi l'afficher, de quoi
 * le juger, et de quoi y sauter. Pendant d'`OpeningLineIndex.IndexedMove`.
 */
data class IndexedMove(
    /** Demi-coup depuis la racine du cours (1 = premier coup blanc). */
    val ply: Int,
    val san: String,
    val uci: String,
    /** La clé FEN de la position ATTEINTE — la destination du saut. */
    val toFEN: String,
    /** La clé FEN de la position de DÉPART — de quoi juger le coup sans rejouer. */
    val fromFEN: String,
    val role: String,
    /** Le nom de variante atteint par ce coup, s'il y en a un. */
    val ecoName: String?,
    val isCritical: Boolean,
    val hasComment: Boolean,
    /**
     * Le chemin COMPLET en UCI depuis la racine, ce coup inclus.
     *
     * C'est l'instruction de saut : rejouer ces coups reconstruit exactement
     * la position ET le fil des coups. La seule FEN d'arrivée ne suffirait
     * pas — une position atteinte par transposition a plusieurs chemins, et
     * on veut CELUI de cette branche.
     */
    val path: List<String>,
    /**
     * Le verdict du moteur, quand il mérite d'être montré : gaffe, erreur,
     * imprécision, occasion manquée, coup brillant. `null` partout ailleurs.
     */
    val quality: com.chesslab.analysis.MoveQuality? = null,
) {
    /**
     * Identité = le CHEMIN COMPLET, pas (demi-coup, coup). Deux coups
     * différents peuvent partager leur demi-coup ET leur notation : dans la
     * scandinave, deux branches partent toutes deux de « 4…Cf6 » et ne
     * divergent qu'au coup blanc suivant. Avec une identité (demi-coup, coup),
     * la seconde branche disparaissait de l'index, en silence.
     */
    val id: String get() = path.joinToString(".")

    /** Le camp qui joue ce coup (demi-coups impairs = Blancs). */
    val color: Piece.Color get() = if (ply % 2 == 1) Piece.Color.white else Piece.Color.black

    /** Le numéro de coup entier (« 4 » pour 4.Fc4 comme pour 4…Fc5). */
    val moveNumber: Int get() = (ply + 1) / 2

    /**
     * Le préfixe de notation : « 4. » pour un coup blanc, « 4… » pour un coup
     * noir qui OUVRE une rangée — sinon rien : dans « 4.Fc4 Fc5 », le coup
     * noir se lit sans numéro.
     */
    fun numberPrefix(isFirstOfLine: Boolean): String? = when {
        color == Piece.Color.white -> "$moveNumber."
        isFirstOfLine -> "$moveNumber…"
        else -> null
    }
}

/**
 * L'ARBRE des lignes d'une ouverture — ce que l'écran d'index affiche.
 * Pendant d'`OpeningLineTree.swift`.
 *
 * **Le principe : chaque coup écrit UNE FOIS.** Le tronc commun n'est écrit
 * qu'une fois et l'arbre DÉBRANCHE :
 *
 *     1.e4 d5
 *       ↳ 2.exd5
 *           ○ 2…Dxd5
 *               □ 3.Cc3
 *                   ◇ 3…Da5 4.d4 Cf6 …
 *                   ◇ 3…Dd6 …
 *               □ 3.Cf3 Fg4 …
 *           ○ 2…Cf6 …
 *       ↳ 2.e5 Ff5
 *
 * Une rangée court tant que la position n'offre QU'UNE suite ; à la première
 * DÉVIATION elle s'arrête, et chaque suite — la principale comprise — descend
 * d'un étage. Chaque rangée répond ainsi à une seule question : « à cette
 * position, quels sont les choix ? ». Prolonger la ligne principale à plat
 * par-dessus une déviation mentirait sur l'endroit où le choix se pose.
 *
 * Ordre des branches : ligne principale d'abord, puis par popularité club — le
 * même que la liste des coups du lecteur.
 *
 * **Les transpositions.** Une position n'est DÉPLIÉE QU'UNE FOIS ; la seconde
 * arrivée s'arrête sur un repère « transposition », cliquable comme les
 * autres. Sans cette règle, des sous-arbres entiers apparaîtraient en double,
 * et un cycle ferait tourner la construction sans fin.
 */
object OpeningLineTree {

    /** Un nœud = une RANGÉE à l'écran : un tronçon de coups d'un seul tenant, puis ses branches. */
    data class Node(
        /** L'étage de débranchement — 0 pour le tronc. Pilote le retrait. */
        val depth: Int,
        /** Le rang parmi les branches sœurs : 0 = le coup principal de la position. */
        val rank: Int,
        val moves: List<IndexedMove>,
        /** Le titre de chapitre que CETTE branche ouvre — voir [titles]. */
        val chapterTitle: String? = null,
        /** Le nom de variante atteint au bout du tronçon, quand la donnée en a un. */
        val ecoName: String? = null,
        /** La branche s'arrête parce que la suite est déjà dépliée ailleurs. */
        val isTransposition: Boolean = false,
        /**
         * Pour chaque étage traversé (1…depth), l'ancêtre de cet étage était-il
         * le DERNIER de sa fratrie ? C'est ce qui permet de dessiner un vrai
         * arbre : un rail ne se prolonge sous une rangée que si la branche de
         * cet étage a encore des sœurs à venir, et le connecteur de la rangée
         * est un « └ » quand elle ferme sa fratrie, un « ├ » sinon.
         */
        val lineage: List<Boolean> = emptyList(),
        /**
         * Cette rangée est-elle SUR la ligne principale ? Vrai pour la rangée
         * de tête et pour toute descendance qui n'a pris que des rangs 0. Un
         * seul rang > 0 dans la lignée, et on est dans une variante —
         * définitivement.
         */
        val isOnMainLine: Boolean = false,
        val children: List<Node> = emptyList(),
    ) {
        /** Identité = le chemin du dernier coup, plus l'étage : après une transposition, deux nœuds peuvent finir sur la même position. */
        val id: String get() = "$depth|" + (moves.lastOrNull()?.path ?: emptyList()).joinToString(".")

        /** Toutes les rangées de ce sous-arbre, dans l'ordre de LECTURE. */
        val flattened: List<Node> get() = listOf(this) + children.flatMap { it.flattened }
    }

    /**
     * Construit l'arbre d'un cours. `null` si la racine n'offre aucun coup.
     * @param sidecar les données Labs, pour juger la qualité des coups ; sans
     * lui, aucun verdict n'est affiché.
     */
    fun build(course: Course, sidecar: OpeningStatsSidecar? = null): Node? {
        val rootKey = CourseRepository.fenKey(course.rootFEN)
        val expanded = hashSetOf(rootKey)
        val run = expand(rootKey, emptyList(), 0, true, course, expanded)
        if (run.moves.isEmpty() && run.children.isEmpty()) return null

        var root = Node(
            depth = 0, rank = 0, moves = run.moves,
            ecoName = run.moves.lastOrNull()?.let { course.ecoNames[it.toFEN] },
            isTransposition = run.isTransposition, isOnMainLine = true, children = run.children,
        )
        root = labelled(root, titles(course, root))
        root = withLineage(root, emptyList())
        if (sidecar != null) root = judged(root, sidecar)
        return root
    }

    private class Run(val moves: List<IndexedMove>, val children: List<Node>, val isTransposition: Boolean)

    /**
     * Déplie une ligne : la rangée s'arrête à la PREMIÈRE déviation, et toutes
     * les suites — la principale comprise — descendent d'un étage.
     *
     * Les branches sont dépliées DANS L'ORDRE DES RANGS, la principale en
     * premier. Sinon une variante qui transpose plus loin dans la ligne
     * principale réclame la position avant elle, et c'est la ligne principale
     * qui s'arrête sur un « transposition » — l'inverse de ce qu'on veut lire.
     */
    private fun expand(
        fen: String, path: List<String>, depth: Int, onMainLine: Boolean,
        course: Course, expanded: MutableSet<String>,
    ): Run {
        val moves = ArrayList<IndexedMove>()
        var cursor = fen
        var cursorPath = path

        while (true) {
            val edges = ordered(course.moves(cursor))
            val only = edges.firstOrNull() ?: return Run(moves, emptyList(), false)

            // Une seule suite : pas de choix à poser, la rangée continue.
            if (edges.size == 1) {
                moves += move(only, cursor, cursorPath, course)
                val to = CourseRepository.fenKey(only.toFEN)
                if (!expanded.add(to)) return Run(moves, emptyList(), true)
                cursorPath = cursorPath + only.uci
                cursor = to
                continue
            }

            // Déviation : la rangée s'arrête ICI, chaque suite ouvre la sienne.
            val children = ArrayList<Node>()
            edges.forEachIndexed { rank, edge ->
                val head = move(edge, cursor, cursorPath, course)
                val to = CourseRepository.fenKey(edge.toFEN)
                // La ligne principale se prolonge par le rang 0, et seulement
                // si on y était déjà : une variante ne redevient jamais la
                // ligne principale, si loin qu'aille son propre coup principal.
                val childOnMainLine = onMainLine && rank == 0
                if (!expanded.add(to)) {
                    children += Node(
                        depth = depth + 1, rank = rank, moves = listOf(head),
                        ecoName = course.ecoNames[to],
                        isTransposition = true, isOnMainLine = childOnMainLine,
                    )
                    return@forEachIndexed
                }
                val sub = expand(to, cursorPath + edge.uci, depth + 1, childOnMainLine, course, expanded)
                val branchMoves = listOf(head) + sub.moves
                children += Node(
                    depth = depth + 1, rank = rank, moves = branchMoves,
                    ecoName = branchMoves.lastOrNull()?.let { course.ecoNames[it.toFEN] },
                    isTransposition = sub.isTransposition, isOnMainLine = childOnMainLine,
                    children = sub.children,
                )
            }
            return Run(moves, children, false)
        }
    }

    /** Ligne principale d'abord, puis par popularité club — l'ordre du lecteur. */
    fun ordered(edges: List<CourseMove>): List<CourseMove> =
        edges.sortedWith(compareByDescending<CourseMove> { it.isMainLine }.thenByDescending { it.popularity ?: 0.0 })

    private fun move(edge: CourseMove, fen: String, path: List<String>, course: Course): IndexedMove {
        val full = path + edge.uci
        val to = CourseRepository.fenKey(edge.toFEN)
        return IndexedMove(
            ply = full.size, san = edge.san, uci = edge.uci,
            toFEN = to, fromFEN = fen, role = edge.role,
            ecoName = course.ecoNames[to],
            isCritical = edge.isCritical, hasComment = edge.comment != null,
            path = full,
        )
    }

    // MARK: Titres de chapitre

    /**
     * Où poser chaque titre de chapitre écrit à la main.
     *
     * Un chapitre est un CHEMIN, l'arbre est fait de nœuds : il n'y a pas de
     * correspondance directe. La règle est celle du **point de divergence** :
     * le titre va sur la première branche de sa colonne vertébrale qui n'est
     * PAS le coup principal de sa position — là où ce chapitre quitte la ligne
     * dont il descend. Un chapitre qui ne quitte jamais la ligne principale
     * n'obtient pas de titre : la carte porte déjà le nom de l'ouverture.
     *
     * Chaque branche n'est réclamée qu'une fois, dans l'ordre des chapitres.
     */
    private fun titles(course: Course, root: Node): Map<String, String> {
        val headRank = HashMap<String, Int>()
        for (node in root.flattened) {
            if (node.depth == 0) continue
            val head = node.moves.firstOrNull() ?: continue
            headRank[head.toFEN] = node.rank
        }
        val assigned = HashMap<String, String>()
        val claimed = HashSet<String>()
        for (chapter in course.chapters) {
            val fens = chapter.positionFENs.map { CourseRepository.fenKey(it) }
            val candidates = spine(fens, course) + fens
            for (fen in candidates) {
                val rank = headRank[fen] ?: continue
                if (rank <= 0 || fen in claimed) continue
                claimed += fen
                assigned[fen] = chapter.title
                break
            }
        }
        return assigned
    }

    /**
     * La colonne vertébrale d'un chapitre : son premier tronçon CONTIGU depuis
     * le début. Un chapitre liste souvent, après sa ligne, des positions de
     * variantes annexes ; les prendre en compte d'abord ferait atterrir le
     * titre sur une branche qui n'est pas la sienne.
     */
    private fun spine(fens: List<String>, course: Course): List<String> {
        val result = ArrayList<String>()
        var previous: String? = null
        for (fen in fens) {
            if (previous != null && course.moves(previous).none { CourseRepository.fenKey(it.toFEN) == fen }) break
            result += fen
            previous = fen
        }
        return result
    }

    /** Renseigne [Node.lineage] de proche en proche : c'est le parent qui sait si un enfant ferme sa fratrie. */
    private fun withLineage(node: Node, inherited: List<Boolean>): Node {
        val last = node.children.size - 1
        return node.copy(
            lineage = inherited,
            children = node.children.mapIndexed { index, child -> withLineage(child, inherited + (index == last)) },
        )
    }

    private fun labelled(node: Node, titles: Map<String, String>): Node = node.copy(
        chapterTitle = node.moves.firstOrNull()?.let { titles[it.toFEN] },
        children = node.children.map { labelled(it, titles) },
    )

    /**
     * Attribue son verdict à chaque coup — seconde passe, parce qu'un coup
     * brillant se reconnaît en partie au coup SUIVANT (un sacrifice repris
     * sur-le-champ n'en est pas un). Le coup suivant est cherché dans le MÊME
     * tronçon : au bout, la suite dépend de la branche, aucune n'est « le »
     * coup suivant.
     */
    private fun judged(node: Node, sidecar: OpeningStatsSidecar): Node = node.copy(
        moves = node.moves.mapIndexed { index, move ->
            val next = node.moves.getOrNull(index + 1)?.uci
            move.copy(
                quality = OpeningMoveQuality.classify(
                    OpeningMoveQuality.Context(move.fromFEN, move.toFEN, move.uci, next), sidecar,
                )
            )
        },
        children = node.children.map { judged(it, sidecar) },
    )
}
