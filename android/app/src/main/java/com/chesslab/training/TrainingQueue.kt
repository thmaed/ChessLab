package com.chesslab.training

import com.chesslab.courses.Course
import com.chesslab.courses.CourseMove
import com.chesslab.courses.CourseRepository

/**
 * Une carte de révision : une POSITION (clé FEN) où c'est au camp d'étude de
 * jouer, avec le coup attendu. L'unité de révision est la POSITION, pas la
 * ligne — c'est la position qui porte la progression FSRS, si bien qu'une
 * transposition apprise ailleurs compte aussi.
 */
data class TrainCard(
    val courseId: String,
    val fenKey: String,
    val expectedUci: String,
    val expectedSan: String,
    val comment: String?,
)

/** Ce que la file a besoin de savoir d'une position, sans toucher à Room. */
data class ProgressSnapshot(
    val dueAt: Long?,
    val lapses: Int,
    val stability: Double,
    val reps: Int,
    val state: FsrsState = FsrsState.new,
)

/**
 * Construction PURE des files de révision — pendant d'`OpeningTrainingQueue`.
 *
 * Aucune dépendance à Room ni à l'interface : le ViewModel fournit les cours
 * et un instantané de progression par clé FEN.
 */
object TrainingQueue {

    /** Le trait à une position, lu dans le deuxième champ de la clé FEN. */
    fun sideToMove(fenKey: String): String =
        if (fenKey.split(" ").getOrNull(1) == "b") "black" else "white"

    /**
     * La LIGNE PRINCIPALE d'un cours : rôle `mainLine` d'abord, popularité
     * sinon. Bornée et protégée des cycles de transposition — un arbre
     * d'ouverture en contient, et sans garde on tourne en rond.
     */
    fun mainLine(course: Course): List<Pair<String, CourseMove>> {
        val out = ArrayList<Pair<String, CourseMove>>()
        var key = CourseRepository.fenKey(course.rootFEN)
        val visited = HashSet<String>()
        while (out.size < 60 && visited.add(key)) {
            val moves = course.positions[key].orEmpty()
            if (moves.isEmpty()) break
            val edge = moves.firstOrNull { it.isMainLine }
                ?: moves.maxByOrNull { it.popularity ?: 0.0 } ?: break
            out += key to edge
            key = CourseRepository.fenKey(edge.toFEN)
        }
        return out
    }

    /**
     * Toutes les positions entraînables d'un cours : au trait du camp d'étude
     * ET dotées d'un coup à réciter.
     */
    fun trainableCards(course: Course, side: String): List<TrainCard> =
        course.positions.mapNotNull { (key, moves) ->
            if (sideToMove(key) != side) return@mapNotNull null
            val main = moves.firstOrNull { it.isMainLine } ?: moves.firstOrNull() ?: return@mapNotNull null
            TrainCard(course.id, key, main.uci, main.san, main.comment)
        }

    /** Les positions entraînables DANS L'ORDRE de la ligne principale. */
    fun lineCards(course: Course, side: String): List<TrainCard> =
        mainLine(course).mapNotNull { (key, edge) ->
            if (sideToMove(key) != side) null
            else TrainCard(course.id, key, edge.uci, edge.san, edge.comment)
        }

    /**
     * File QUOTIDIENNE : positions DUES d'abord, les plus en retard en tête,
     * puis un quota de positions NEUVES. Dédupliquée par clé FEN — une
     * position ne se révise qu'une fois, même si plusieurs cours la
     * contiennent par transposition.
     *
     * Un enregistrement SANS échéance est traité comme neuf, ce qu'il est :
     * sinon la position ne serait ni due ni neuve, et disparaîtrait en silence.
     */
    fun daily(
        cards: List<TrainCard>,
        progress: Map<String, ProgressSnapshot>,
        now: Long,
        newLimit: Int = 20,
    ): List<TrainCard> {
        val seen = HashSet<String>()
        val due = ArrayList<Pair<TrainCard, Long>>()
        val fresh = ArrayList<TrainCard>()
        for (card in cards) {
            if (!seen.add(card.fenKey)) continue
            val snap = progress[card.fenKey]
            val dueAt = snap?.dueAt
            when {
                snap == null || dueAt == null -> fresh += card
                dueAt <= now -> due += card to dueAt
            }
        }
        due.sortBy { it.second }
        return due.map { it.first } + fresh.take(newLimit)
    }

    /**
     * Une position est DIFFICILE si elle a déjà été oubliée, ou si elle n'est
     * pas encore acquise.
     *
     * iOS ne retient que `lapses > 0`, et c'est trop étroit : au sens de FSRS,
     * rater une position qu'on VOIT POUR LA PREMIÈRE FOIS n'est pas un oubli —
     * on ne peut oublier que ce qu'on a su. Le compteur reste donc à zéro, et
     * la liste des difficiles restait obstinément vide pour qui débute. Or
     * c'est précisément à ce moment-là qu'on a besoin de revoir ce qu'on vient
     * de manquer.
     *
     * On y ajoute donc les états `learning` et `relearning`, qui disent
     * exactement « pas encore solide » — sans toucher d'un iota à FSRS, qui
     * reste un calculateur fidèle.
     */
    fun isHard(snap: ProgressSnapshot): Boolean =
        snap.lapses > 0 || snap.state == FsrsState.learning || snap.state == FsrsState.relearning

    /**
     * Positions DIFFICILES, du plus raté au moins raté ; à égalité, la
     * stabilité la plus faible d'abord (la plus fragile).
     */
    fun hardest(
        cards: List<TrainCard>,
        progress: Map<String, ProgressSnapshot>,
        limit: Int = 30,
    ): List<TrainCard> {
        val seen = HashSet<String>()
        val scored = ArrayList<Triple<TrainCard, Int, Double>>()
        for (card in cards) {
            if (!seen.add(card.fenKey)) continue
            val snap = progress[card.fenKey] ?: continue
            if (!isHard(snap)) continue
            scored += Triple(card, snap.lapses, snap.stability)
        }
        scored.sortWith(compareByDescending<Triple<TrainCard, Int, Double>> { it.second }.thenBy { it.third })
        return scored.take(limit).map { it.first }
    }
}
