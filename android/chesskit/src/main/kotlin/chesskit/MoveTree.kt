package chesskit

/**
 * Traduction Kotlin de `MoveTree.swift`, `MoveTree+Index.swift` et
 * `MoveTree+Collection.swift` (ChessKit, MIT).
 *
 * L'arbre des coups d'une partie, variantes comprises, avec un accès par
 * index. C'est lui qui porte les annotations et qui sait rendre un PGN.
 *
 * Écart assumé : côté Swift, `next` est une référence FAIBLE (les nœuds sont
 * retenus par le dictionnaire). Kotlin étant ramassé par le GC, la référence
 * est simplement forte — même structure, une subtilité de moins.
 */
class MoveTree {

    /** L'index d'un nœud : numéro du coup, couleur, et numéro de variante. */
    data class Index(
        val number: Int,
        val color: Piece.Color,
        val variation: Int = MAIN_VARIATION,
    ) : Comparable<Index> {

        /** Suppose la variante constante ; voir [MoveTree.indexBefore]. */
        val previous: Index
            get() = when (color) {
                Piece.Color.white -> Index(number - 1, Piece.Color.black, variation)
                Piece.Color.black -> Index(number, Piece.Color.white, variation)
            }

        /** Suppose la variante constante ; voir [MoveTree.indexAfter]. */
        val next: Index
            get() = when (color) {
                Piece.Color.white -> Index(number, Piece.Color.black, variation)
                Piece.Color.black -> Index(number + 1, Piece.Color.white, variation)
            }

        override fun compareTo(other: Index): Int = when {
            // la variante principale (0) passe devant
            variation != other.variation -> other.variation.compareTo(variation)
            number != other.number -> number.compareTo(other.number)
            color == other.color -> 0
            color == Piece.Color.white -> -1
            else -> 1
        }

        companion object {
            const val MAIN_VARIATION = 0

            /** La position de départ : le coup 1 des blancs est `minimum.next`. */
            val minimum = Index(0, Piece.Color.black)
        }
    }

    class Node(var move: Move) {
        var positionAssessment: PositionAssessment = PositionAssessment.null_
        var index: Index = Index.minimum
        var previous: Node? = null
        var next: Node? = null
        val children: MutableList<Node> = mutableListOf()
    }

    enum class PathDirection { forward, reverse }

    /** Un élément de PGN : numéro, coup, annotation, ouverture ou fermeture de variante. */
    sealed class PGNElement {
        data class WhiteNumber(val number: Int) : PGNElement()
        data class BlackNumber(val number: Int) : PGNElement()
        data class MoveElement(val move: Move, val index: Index) : PGNElement()
        data class PositionAssessmentElement(val assessment: PositionAssessment) : PGNElement()
        data object VariationStart : PGNElement()
        data object VariationEnd : PGNElement()
    }

    var minimumIndex: Index = Index.minimum
    var lastMainVariationIndex: Index = Index.minimum
        private set

    private val dictionary = LinkedHashMap<Index, Node>()
    private var root: Node? = null

    val indices: List<Index> get() = dictionary.keys.toList()
    val isEmpty: Boolean get() = root == null

    /**
     * Ajoute un coup. Sans `parentIndex`, l'arbre est vidé et le coup devient
     * la racine.
     */
    fun add(move: Move, parentIndex: Index? = null): Index {
        val newNode = Node(move)
        val currentRoot = root

        if (currentRoot == null || parentIndex == null) {
            val index = minimumIndex.next
            newNode.index = index
            root = newNode
            dictionary.clear()
            dictionary[index] = newNode
            if (index.variation == Index.MAIN_VARIATION) lastMainVariationIndex = index
            return index
        }

        val parent = dictionary[parentIndex] ?: currentRoot
        newNode.previous = parent

        var newIndex = parentIndex.next
        if (parent.next == null) {
            parent.next = newNode
        } else {
            parent.children += newNode
            while (dictionary.containsKey(newIndex)) {
                newIndex = newIndex.copy(variation = newIndex.variation + 1)
            }
        }

        dictionary[newIndex] = newNode
        newNode.index = newIndex
        if (newIndex.variation == Index.MAIN_VARIATION) lastMainVariationIndex = newIndex
        return newIndex
    }

    /** L'index du coup `move` parmi les suites de `index`, s'il y est. */
    fun nextIndex(containing: Move, forIndex: Index): Index? {
        val node = dictionary[forIndex]
            ?: return if (forIndex == minimumIndex && root?.move == containing) root?.index else null

        val next = node.next
        return if (next != null && next.move == containing) next.index
        else node.children.firstOrNull { it.move == containing }?.index
    }

    /** Du premier coup jusqu'à `index` inclus, variantes traversées comprises. */
    fun history(forIndex: Index): List<Index> {
        val start = if (forIndex == Index.minimum) Index.minimum.next else forIndex
        val out = ArrayList<Index>()
        var current = dictionary[start]
        while (current != null) {
            out += current.index
            current = current.previous
        }
        return out.reversed()
    }

    /** Du coup suivant `index` jusqu'au bout de sa variante. */
    fun future(forIndex: Index): List<Index> {
        val start = if (forIndex == Index.minimum) Index.minimum.next else forIndex
        val out = ArrayList<Index>()
        var current = dictionary[start]
        while (current != null) {
            current = current.next
            if (current != null) out += current.index
        }
        return out
    }

    fun fullVariation(forIndex: Index): List<Index> = history(forIndex) + future(forIndex)

    private fun indicesBetween(start: Index, end: Index): List<Index> {
        val endNode = dictionary[end]
        val out = ArrayList<Index>()
        var current = dictionary[start]
        while (current !== endNode) {
            if (current == null) break
            out += current.index
            current = current.previous
        }
        return out
    }

    /**
     * Le chemin le plus court pour aller de `from` à `to` : les coups à
     * défaire puis ceux à rejouer. `from` est inclus, `to` ne l'est pas.
     */
    fun path(from: Index, to: Index): List<Pair<PathDirection, Index>> {
        if (from == to) return emptyList()

        val startHistory = history(from)
        val endHistory = history(to)

        if (to in startHistory) {
            return indicesBetween(from, to).map { PathDirection.reverse to it }
        }
        if (from in endHistory) {
            return indicesBetween(to, from).map { PathDirection.forward to it }.reversed()
        }

        // plus proche ancêtre commun
        val lca = startHistory.zip(endHistory).lastOrNull { it.first == it.second }?.first ?: return emptyList()
        val startLca = startHistory.indexOf(lca)
        val endLca = endHistory.indexOf(lca)
        if (startLca < 0 || endLca < 0) return emptyList()

        val toLca = startHistory.subList(startLca, startHistory.size)
            .reversed()          // l'historique est croissant
            .dropLast(1)         // l'ancêtre appartient à la seconde moitié
            .map { PathDirection.reverse to it }
        val fromLca = endHistory.subList(endLca, endHistory.size)
            .map { PathDirection.forward to it }

        return toLca + fromLca
    }

    fun annotate(moveAt: Index, assessment: Move.Assessment = Move.Assessment.null_, comment: String = ""): Move? {
        val node = dictionary[moveAt] ?: return null
        node.move = node.move.copy(assessment = assessment, comment = comment)
        return node.move
    }

    fun annotate(positionAt: Index, assessment: PositionAssessment) {
        dictionary[positionAt]?.positionAssessment = assessment
    }

    operator fun get(index: Index): Move? = dictionary[index]?.move

    fun indexBefore(i: Index): Index = previousIndexOrNull(i) ?: i
    fun hasIndexBefore(i: Index): Boolean = previousIndexOrNull(i) != null
    fun indexAfter(i: Index): Index = nextIndexOrNull(i) ?: i
    fun hasIndexAfter(i: Index): Boolean = nextIndexOrNull(i) != null

    private fun previousIndexOrNull(index: Index): Index? =
        if (index == minimumIndex.next) minimumIndex else dictionary[index]?.previous?.index

    private fun nextIndexOrNull(index: Index): Index? =
        if (index == minimumIndex) dictionary[minimumIndex.next]?.index else dictionary[index]?.next?.index

    /** L'arbre sous forme d'éléments de PGN, variantes imbriquées comprises. */
    val pgnRepresentation: List<PGNElement> get() = pgn(root)

    private fun pgn(node: Node?): List<PGNElement> {
        if (node == null) return emptyList()
        val result = ArrayList<PGNElement>()

        result += when (node.index.color) {
            Piece.Color.white -> PGNElement.WhiteNumber(node.index.number)
            Piece.Color.black -> PGNElement.BlackNumber(node.index.number)
        }
        result += PGNElement.MoveElement(node.move, node.index)
        if (node.positionAssessment != PositionAssessment.null_) {
            result += PGNElement.PositionAssessmentElement(node.positionAssessment)
        }

        var current = node.next
        var previousIndex = node.index
        while (current != null) {
            val currentIndex = current.index
            if (previousIndex.number < currentIndex.number) {
                result += PGNElement.WhiteNumber(currentIndex.number)
            }
            result += PGNElement.MoveElement(current.move, currentIndex)
            if (current.positionAssessment != PositionAssessment.null_) {
                result += PGNElement.PositionAssessmentElement(current.positionAssessment)
            }

            // les variantes s'ouvrent au point de branchement, c'est-à-dire
            // sur les enfants du nœud PRÉCÉDENT
            current.previous?.children?.forEach { child ->
                result += PGNElement.VariationStart
                result += pgn(child)
                result += PGNElement.VariationEnd
            }

            previousIndex = currentIndex
            current = current.next
        }

        return result
    }
}
