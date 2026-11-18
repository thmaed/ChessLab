package com.chesslab.visualization

import android.content.Context
import kotlin.math.abs
import kotlin.random.Random

/**
 * VISUALISATION (18/11/2026) — s'entraîner à voir l'échiquier dans sa tête. Pendant de `Visualization.swift` : une
 * ÉCHELLE de marches, des exercices générés à l'infini, réglables, et la trace de ce qui a été raté (une question
 * ratée revient jusqu'à deux réussites). Lot 1 : marches 1 « Les cases » et 2 « Les lignes ».
 *
 * Ce fichier est la RÈGLE, pure : le hasard vient de l'appelant (les tests passent un `Random` réglé).
 */

// MARK: Les cases et les lignes

/** Une case, en coordonnées 0…7 (a1 = 0, 0). */
data class VSquare(val file: Int, val rank: Int) : Comparable<VSquare> {
    val isValid: Boolean get() = file in 0..7 && rank in 0..7
    val notation: String get() = "${FILES[file]}${rank + 1}"
    /** a1 est foncée. */
    val isLight: Boolean get() = (file + rank) % 2 == 1

    fun offset(df: Int, dr: Int): VSquare? = VSquare(file + df, rank + dr).takeIf { it.isValid }

    /** Sur une même diagonale (dans un sens ou dans l'autre). */
    fun sharesDiagonal(other: VSquare): Boolean = this != other && abs(file - other.file) == abs(rank - other.rank)

    override fun compareTo(other: VSquare): Int = compareValuesBy(this, other, { it.rank }, { it.file })

    companion object {
        val FILES = listOf("a", "b", "c", "d", "e", "f", "g", "h")
        val all: List<VSquare> = (0..7).flatMap { r -> (0..7).map { VSquare(it, r) } }

        fun parse(notation: String): VSquare? {
            if (notation.length != 2) return null
            val f = notation[0] - 'a'
            val r = notation[1] - '1'
            return VSquare(f, r).takeIf { it.isValid }
        }
    }
}

/** Une diagonale, nommée par ses deux extrémités (« a1–h8 »), du bas vers le haut. */
data class VDiagonal(val squares: List<VSquare>) {
    val start: VSquare get() = squares.first()
    val end: VSquare get() = squares.last()
    val name: String get() = "${start.notation}–${end.notation}"

    companion object {
        /** Toutes les diagonales d'au moins trois cases, dans les deux sens (22). */
        val all: List<VDiagonal> by lazy {
            val result = mutableListOf<VDiagonal>()
            for (direction in listOf(1, -1)) {
                val starts = (0..7).map { VSquare(it, 0) } + (1..7).map { VSquare(if (direction == 1) 0 else 7, it) }
                for (start in starts) {
                    val squares = mutableListOf(start)
                    while (true) squares.add(squares.last().offset(direction, 1) ?: break)
                    if (squares.size >= 3) result.add(VDiagonal(squares))
                }
            }
            result
        }

        fun named(name: String): VDiagonal? = all.firstOrNull { it.name == name }
    }
}

/** Une colonne ou une rangée. */
sealed class VLine {
    data class File(val file: Int) : VLine()
    data class Rank(val rank: Int) : VLine()

    fun contains(s: VSquare): Boolean = when (this) {
        is File -> s.file == file
        is Rank -> s.rank == rank
    }

    /** Clé de reprise : « f:d » ou « r:5 ». */
    val key: String get() = when (this) {
        is File -> "f:${VSquare.FILES[file]}"
        is Rank -> "r:${rank + 1}"
    }

    companion object {
        fun parse(key: String): VLine? {
            val parts = key.split(":")
            if (parts.size != 2) return null
            return when (parts[0]) {
                "f" -> VSquare.FILES.indexOf(parts[1]).takeIf { it >= 0 }?.let { File(it) }
                "r" -> parts[1].toIntOrNull()?.takeIf { it in 1..8 }?.let { Rank(it - 1) }
                else -> null
            }
        }
    }
}

/** Le plus court chemin d'un cavalier, en coups (0 sur place). */
object KnightDistance {
    private val jumps = listOf(1 to 2, 2 to 1, 2 to -1, 1 to -2, -1 to -2, -2 to -1, -2 to 1, -1 to 2)

    fun between(from: VSquare, to: VSquare): Int {
        val distance = hashMapOf(from to 0)
        val queue = ArrayDeque(listOf(from))
        while (queue.isNotEmpty()) {
            val square = queue.removeFirst()
            if (square == to) return distance.getValue(square)
            for ((df, dr) in jumps) {
                val next = square.offset(df, dr) ?: continue
                if (next !in distance) {
                    distance[next] = distance.getValue(square) + 1
                    queue.addLast(next)
                }
            }
        }
        return 0
    }
}

// MARK: Les marches et les exercices

enum class VisualizationStep(val number: Int) {
    squares(1),
    lines(2),
    /** Lot 2 (18/11/2026). */
    pieces(3),
    position(4);

    val kinds: List<VisualizationKind> get() = VisualizationKind.entries.filter { it.step == this }
}

enum class VisualizationKind(val step: VisualizationStep) {
    /** « La case e5 est-elle claire ou foncée ? » — sans plateau. */
    squareColor(VisualizationStep.squares),
    /** « Touchez f3 » — sur un plateau sans coordonnées. */
    findSquare(VisualizationStep.squares),
    /** Une case surlignée sur un plateau sans coordonnées : laquelle est-ce ? */
    nameSquare(VisualizationStep.squares),
    /** « c1 et h6 sont-elles sur la même diagonale ? » */
    sameDiagonal(VisualizationStep.lines),
    /** « Quelle case est sur la colonne d et sur la diagonale a1–h8 ? » */
    lineIntersection(VisualizationStep.lines),
    /** « En combien de coups un cavalier va-t-il de b1 à f5 ? » */
    knightDistance(VisualizationStep.lines),
    /** « ♘ g1 → f3 → d4 → c6 : chaque coup est-il possible ? » */
    pathCheck(VisualizationStep.pieces),
    /** « ♗ c1 → g5 → e7 : la pièce attaque-t-elle a3 ? » */
    attackAfter(VisualizationStep.pieces),
    /** Deux pièces qui bougent tour à tour : « Quelle pièce attaque f7 ? » */
    twoPieces(VisualizationStep.pieces),
    /** Une position : « Les Blancs font-ils échec au roi noir ? » */
    isCheck(VisualizationStep.position),
    /** « Quelle pièce noire est en prise ? » (attaquée et non défendue ; ou aucune) */
    hangingPiece(VisualizationStep.position),
    /** « La case e5 est-elle attaquée par les Blancs ? » */
    squareAttacked(VisualizationStep.position);

    /** L'exercice se fait SUR un plateau (sans coordonnées) ; les autres, de tête. */
    val usesBoard: Boolean get() = this == findSquare || this == nameSquare

    /** Le chrono GRANDIT avec la marche (18/11/2026, comme iOS) : 5 s pour une case, 20 s pour une position. */
    fun seconds(base: Int): Int = base * step.number
}

sealed class VAnswer {
    data object Light : VAnswer()
    data object Dark : VAnswer()
    data object Yes : VAnswer()
    data object No : VAnswer()
    data class Square(val square: VSquare) : VAnswer()
    data class Number(val value: Int) : VAnswer()
    /** « first », « second », « both », « none ». */
    data class Option(val name: String) : VAnswer()

    /** Étiquette d'essai (tests instrumentés) : « light », « e4 », « 3 »… */
    val tag: String get() = when (this) {
        Light -> "light"
        Dark -> "dark"
        Yes -> "yes"
        No -> "no"
        is Square -> square.notation
        is Number -> "$value"
        is Option -> name
    }
}

data class VQuestion(
    val kind: VisualizationKind,
    /** La case à juger, trouver ou nommer ; les deux cases comparées ; départ et arrivée ; la réponse du croisement. */
    val squares: List<VSquare>,
    val line: VLine? = null,
    val diagonal: VDiagonal? = null,
    val answer: VAnswer,
    /** Vides pour « Touchez… » : on répond sur le plateau. */
    val choices: List<VAnswer>,
    /** Lot 2 — la position (marche 4), ou les deux pièces de départ (« Deux pièces »). */
    val pieces: List<VPiece> = emptyList(),
    /** Lot 2 — le trajet d'une pièce (départ compris), ou les coups des deux pièces. */
    val moves: List<VPiece> = emptyList(),
) {
    /** Ce qui permet de reposer la MÊME question plus tard. */
    val reviewKey: String get() = when (kind) {
        VisualizationKind.pathCheck -> "${kind.name}|${moves[0].kind.code}|${moves.joinToString(",") { it.square.notation }}"
        VisualizationKind.attackAfter ->
            "${kind.name}|${moves[0].kind.code}|${moves.joinToString(",") { it.square.notation }}|${squares[0].notation}"
        VisualizationKind.twoPieces -> "${kind.name}|${VPiece.codes(pieces)}|${VPiece.codes(moves)}|${squares[0].notation}"
        VisualizationKind.isCheck, VisualizationKind.hangingPiece -> "${kind.name}|${VPiece.codes(pieces)}"
        VisualizationKind.squareAttacked -> "${kind.name}|${VPiece.codes(pieces)}|${squares[0].notation}"
        VisualizationKind.squareColor, VisualizationKind.findSquare, VisualizationKind.nameSquare ->
            "${kind.name}|${squares[0].notation}"
        VisualizationKind.sameDiagonal, VisualizationKind.knightDistance ->
            "${kind.name}|${squares[0].notation}|${squares[1].notation}"
        VisualizationKind.lineIntersection -> "${kind.name}|${line!!.key}|${diagonal!!.name}"
    }
}

// MARK: Le générateur

object VisualizationGenerator {
    fun question(kind: VisualizationKind, rng: Random): VQuestion = when (kind) {
        VisualizationKind.squareColor -> squareColor(VSquare.all.random(rng))
        VisualizationKind.findSquare -> findSquare(VSquare.all.random(rng))
        VisualizationKind.nameSquare -> nameSquare(VSquare.all.random(rng), rng)
        VisualizationKind.sameDiagonal -> {
            val (a, b) = sameDiagonalPair(rng.nextBoolean(), rng)
            sameDiagonal(a, b)
        }
        VisualizationKind.lineIntersection -> {
            val diagonal = VDiagonal.all.random(rng)
            val square = diagonal.squares.random(rng)
            val line = if (rng.nextBoolean()) VLine.File(square.file) else VLine.Rank(square.rank)
            lineIntersection(line, diagonal, rng)!!
        }
        VisualizationKind.pathCheck -> randomPathCheck(rng.nextBoolean(), rng)
        VisualizationKind.attackAfter -> randomAttackAfter(rng.nextBoolean(), rng)
        VisualizationKind.twoPieces -> randomTwoPieces(rng)
        VisualizationKind.isCheck -> randomIsCheck(rng.nextBoolean(), rng)
        VisualizationKind.hangingPiece -> randomHangingPiece(rng.nextDouble() < 0.7, rng)
        VisualizationKind.squareAttacked -> randomSquareAttacked(rng.nextBoolean(), rng)
        VisualizationKind.knightDistance -> {
            var from = VSquare.all.random(rng)
            var to = VSquare.all.random(rng)
            // Un trajet nul n'a pas de sens ; on évite aussi de trop servir le saut unique, trop facile.
            while (to == from || (KnightDistance.between(from, to) == 1 && rng.nextInt(3) > 0)) {
                from = VSquare.all.random(rng)
                to = VSquare.all.random(rng)
            }
            knightDistance(from, to)
        }
    }

    /** La même question qu'avant, reconstruite de sa clé. */
    fun question(reviewKey: String, rng: Random): VQuestion? {
        val parts = reviewKey.split("|")
        val kind = VisualizationKind.entries.firstOrNull { it.name == parts.firstOrNull() } ?: return null
        return when (kind) {
            VisualizationKind.squareColor, VisualizationKind.findSquare, VisualizationKind.nameSquare -> {
                if (parts.size != 2) return null
                val s = VSquare.parse(parts[1]) ?: return null
                when (kind) {
                    VisualizationKind.squareColor -> squareColor(s)
                    VisualizationKind.findSquare -> findSquare(s)
                    else -> nameSquare(s, rng)
                }
            }
            VisualizationKind.sameDiagonal, VisualizationKind.knightDistance -> {
                if (parts.size != 3) return null
                val a = VSquare.parse(parts[1]) ?: return null
                val b = VSquare.parse(parts[2]) ?: return null
                if (a == b) return null
                if (kind == VisualizationKind.sameDiagonal) sameDiagonal(a, b) else knightDistance(a, b)
            }
            VisualizationKind.lineIntersection -> {
                if (parts.size != 3) return null
                val line = VLine.parse(parts[1]) ?: return null
                val diagonal = VDiagonal.named(parts[2]) ?: return null
                lineIntersection(line, diagonal, rng)
            }
            VisualizationKind.pathCheck, VisualizationKind.attackAfter -> {
                if (parts.size < 3) return null
                val pieceKind = VPieceKind.entries.firstOrNull { it.code == parts[1] } ?: return null
                val path = parts[2].split(",").map { VSquare.parse(it) ?: return null }
                if (path.size < 2) return null
                if (kind == VisualizationKind.pathCheck) return pathCheck(pieceKind, path)
                if (parts.size != 4) return null
                attackAfter(pieceKind, path, VSquare.parse(parts[3]) ?: return null)
            }
            VisualizationKind.twoPieces -> {
                if (parts.size != 4) return null
                val starts = VPiece.parse(parts[1])?.takeIf { it.size == 2 } ?: return null
                val moves = VPiece.parse(parts[2]) ?: return null
                twoPieces(starts, moves, VSquare.parse(parts[3]) ?: return null)
            }
            VisualizationKind.isCheck, VisualizationKind.hangingPiece, VisualizationKind.squareAttacked -> {
                if (parts.size < 2) return null
                val position = VPiece.parse(parts[1]) ?: return null
                when (kind) {
                    VisualizationKind.isCheck -> isCheck(position)
                    VisualizationKind.hangingPiece -> hangingPiece(position, rng)
                    else -> if (parts.size == 3) squareAttacked(position, VSquare.parse(parts[2]) ?: return null) else null
                }
            }
        }
    }

    fun squareColor(s: VSquare) = VQuestion(
        VisualizationKind.squareColor, listOf(s), answer = if (s.isLight) VAnswer.Light else VAnswer.Dark,
        choices = listOf(VAnswer.Light, VAnswer.Dark),
    )

    fun findSquare(s: VSquare) = VQuestion(VisualizationKind.findSquare, listOf(s), answer = VAnswer.Square(s), choices = emptyList())

    /** Quatre noms : le bon, et les confusions les plus fréquentes — vue de l'autre côté, reflets, une voisine. */
    fun nameSquare(s: VSquare, rng: Random): VQuestion {
        val lookalikes = listOf(VSquare(7 - s.file, 7 - s.rank), VSquare(7 - s.file, s.rank), VSquare(s.file, 7 - s.rank)) +
            listOf(1 to 0, -1 to 0, 0 to 1, 0 to -1, 1 to 1, -1 to -1).mapNotNull { s.offset(it.first, it.second) }
        return VQuestion(VisualizationKind.nameSquare, listOf(s), answer = VAnswer.Square(s), choices = distractors(s, lookalikes, rng))
    }

    fun sameDiagonal(a: VSquare, b: VSquare) = VQuestion(
        VisualizationKind.sameDiagonal, listOf(a, b), answer = if (a.sharesDiagonal(b)) VAnswer.Yes else VAnswer.No,
        choices = listOf(VAnswer.Yes, VAnswer.No),
    )

    /** Deux cases d'une diagonale, pas voisines ; ou deux cases qui en sont à UNE colonne près — le piège. */
    fun sameDiagonalPair(on: Boolean, rng: Random): Pair<VSquare, VSquare> {
        while (true) {
            val diagonal = VDiagonal.all.random(rng)
            val i = rng.nextInt(diagonal.squares.size)
            val j = rng.nextInt(diagonal.squares.size)
            if (abs(i - j) < 2) continue
            val a = diagonal.squares[i]
            val b = diagonal.squares[j]
            if (on) return a to b
            val shifted = b.offset(if (rng.nextBoolean()) 1 else -1, 0) ?: continue
            if (a.sharesDiagonal(shifted) || shifted == a) continue
            return a to shifted
        }
    }

    /** `null` si la ligne ne croise pas la diagonale. */
    fun lineIntersection(line: VLine, diagonal: VDiagonal, rng: Random): VQuestion? {
        val answer = diagonal.squares.firstOrNull { line.contains(it) } ?: return null
        val index = diagonal.squares.indexOf(answer)
        val lookalikes = mutableListOf<VSquare>()
        listOf(index - 1, index + 1).forEach { if (it in diagonal.squares.indices) lookalikes.add(diagonal.squares[it]) }
        when (line) {
            is VLine.File -> lookalikes += listOfNotNull(answer.offset(0, 1), answer.offset(0, -1), answer.offset(0, 2))
            is VLine.Rank -> lookalikes += listOfNotNull(answer.offset(1, 0), answer.offset(-1, 0), answer.offset(2, 0))
        }
        lookalikes.add(VSquare(answer.rank, answer.file))
        return VQuestion(
            VisualizationKind.lineIntersection, listOf(answer), line = line, diagonal = diagonal,
            answer = VAnswer.Square(answer), choices = distractors(answer, lookalikes, rng),
        )
    }

    /** Au plus loin, six coups (a1–h8) : on répond par un chiffre de 1 à 6. */
    fun knightDistance(from: VSquare, to: VSquare) = VQuestion(
        VisualizationKind.knightDistance, listOf(from, to), answer = VAnswer.Number(KnightDistance.between(from, to)),
        choices = (1..6).map { VAnswer.Number(it) },
    )

    /** La bonne case et trois leurres DIFFÉRENTS, mélangés ; complétés au hasard si les leurres manquent. */
    private fun distractors(answer: VSquare, candidates: List<VSquare>, rng: Random): List<VAnswer> {
        val picked = mutableListOf<VSquare>()
        for (candidate in candidates.shuffled(rng)) {
            if (candidate != answer && candidate.isValid && candidate !in picked) picked.add(candidate)
            if (picked.size == 3) break
        }
        while (picked.size < 3) {
            val random = VSquare.all.random(rng)
            if (random != answer && random !in picked) picked.add(random)
        }
        return (listOf(answer) + picked).shuffled(rng).map { VAnswer.Square(it) }
    }
}

// MARK: Les réglages

enum class VisualizationLength(val questionCount: Int?) { ten(10), twenty(20), oneMinute(null) }

data class VisualizationSettings(
    val steps: Set<VisualizationStep> = setOf(VisualizationStep.squares),
    val length: VisualizationLength = VisualizationLength.ten,
    /** Le plateau des exercices sur plateau, vu du côté noir. */
    val fromBlack: Boolean = false,
    /** Secondes pour répondre à chaque question ; `null` : pas de chrono. */
    val secondsPerQuestion: Int? = null,
) {
    val kinds: List<VisualizationKind> get() = VisualizationKind.entries.filter { it.step in steps }

    companion object {
        /** « Court », « Moyen », « Long » — 5, 10 et 15 s pour une case : des MOTS dans le menu (18/11/2026, comme iOS). */
        val SECONDS_CHOICES = listOf(5, 10, 15)
        const val SERIES_DURATION_MS = 60_000L
    }
}

// MARK: Les statistiques et les erreurs à revoir

/** Par exercice : posées et justes ; et les questions ratées, qui reviennent jusqu'à deux réussites. */
data class VisualizationStats(
    val attempts: Map<String, Int> = emptyMap(),
    val correct: Map<String, Int> = emptyMap(),
    /** Clé de question → réussites encore nécessaires pour la retirer. */
    val review: Map<String, Int> = emptyMap(),
) {
    fun record(question: VQuestion, isCorrect: Boolean): VisualizationStats {
        val kind = question.kind.name
        val newAttempts = attempts + (kind to (attempts[kind] ?: 0) + 1)
        val newCorrect = if (isCorrect) correct + (kind to (correct[kind] ?: 0) + 1) else correct
        val key = question.reviewKey
        val newReview = when {
            !isCorrect -> review + (key to SUCCESSES_TO_CLEAR)
            review[key] != null -> {
                val remaining = review.getValue(key)
                if (remaining > 1) review + (key to remaining - 1) else review - key
            }
            else -> review
        }
        return VisualizationStats(newAttempts, newCorrect, newReview)
    }

    fun attempts(step: VisualizationStep): Int = step.kinds.sumOf { attempts[it.name] ?: 0 }
    fun correct(step: VisualizationStep): Int = step.kinds.sumOf { correct[it.name] ?: 0 }

    /** Réussite d'une marche, en pour cent ; `null` tant qu'elle n'a pas été jouée. */
    fun accuracy(step: VisualizationStep): Int? {
        val n = attempts(step)
        if (n == 0) return null
        return Math.round(correct(step).toDouble() / n * 100).toInt()
    }

    fun reviewKeys(kinds: List<VisualizationKind>): List<String> {
        val wanted = kinds.map { it.name }.toSet()
        return review.keys.filter { it.substringBefore("|") in wanted }.sorted()
    }

    /** En texte, une entrée par ligne (« clé=nombre ») : ni JSON ni dépendance, testable hors appareil. */
    fun encode(): String = listOf(attempts, correct, review).joinToString("\n\n") { map ->
        map.entries.joinToString("\n") { "${it.key}=${it.value}" }
    }

    companion object {
        const val SUCCESSES_TO_CLEAR = 2

        fun decode(text: String?): VisualizationStats {
            if (text.isNullOrBlank()) return VisualizationStats()
            val blocks = text.split("\n\n").map { block ->
                block.lines().mapNotNull { line ->
                    val i = line.lastIndexOf('=')
                    if (i <= 0) null else line.substring(0, i) to (line.substring(i + 1).toIntOrNull() ?: return@mapNotNull null)
                }.toMap()
            }
            return VisualizationStats(blocks.getOrElse(0) { emptyMap() }, blocks.getOrElse(1) { emptyMap() }, blocks.getOrElse(2) { emptyMap() })
        }
    }
}

/** Réglages et statistiques, sur l'appareil. Pendant de `VisualizationStore` (iOS). */
object VisualizationStore {
    private const val PREFS = "visualization"

    fun loadSettings(context: Context): VisualizationSettings {
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val steps = p.getString("steps", null)?.split(",")
            ?.mapNotNull { name -> VisualizationStep.entries.firstOrNull { it.name == name } }?.toSet()
            ?.takeIf { it.isNotEmpty() } ?: setOf(VisualizationStep.squares)
        return VisualizationSettings(
            steps = steps,
            length = VisualizationLength.entries.firstOrNull { it.name == p.getString("length", null) } ?: VisualizationLength.ten,
            fromBlack = p.getBoolean("fromBlack", false),
            secondsPerQuestion = p.getInt("seconds", 0).takeIf { it > 0 },
        )
    }

    fun save(context: Context, settings: VisualizationSettings) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("steps", settings.steps.joinToString(",") { it.name })
            .putString("length", settings.length.name)
            .putBoolean("fromBlack", settings.fromBlack)
            .putInt("seconds", settings.secondsPerQuestion ?: 0)
            .apply()
    }

    fun loadStats(context: Context): VisualizationStats =
        VisualizationStats.decode(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("stats", null))

    fun save(context: Context, stats: VisualizationStats) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("stats", stats.encode()).apply()
    }
}

// MARK: La série

/** La question suivante : une question RATÉE revient environ une fois sur trois ; jamais deux fois de suite la même. */
object VisualizationDrawer {
    const val REVIEW_SHARE = 0.3

    fun next(kinds: List<VisualizationKind>, stats: VisualizationStats, previous: VQuestion?, rng: Random): VQuestion {
        require(kinds.isNotEmpty())
        val review = stats.reviewKeys(kinds).filter { it != previous?.reviewKey }
        if (review.isNotEmpty() && rng.nextDouble() < REVIEW_SHARE) {
            VisualizationGenerator.question(review.random(rng), rng)?.let { return it }
        }
        repeat(20) {
            val question = VisualizationGenerator.question(kinds.random(rng), rng)
            if (question.reviewKey != previous?.reviewKey) return question
        }
        return VisualizationGenerator.question(kinds.random(rng), rng)
    }
}

/** Une réponse donnée, pour le bilan ; `given == null` : le temps s'est écoulé. */
data class VAnswered(val id: Int, val question: VQuestion, val given: VAnswer?) {
    val isCorrect: Boolean get() = given == question.answer
}

// MARK: Lot 2 — les pièces, et ce qu'elles attaquent (pendant de la section « Lot 2 » de `Visualization.swift`)

enum class VPieceKind(val code: String, val white: String, val black: String) {
    king("K", "♔", "♚"), queen("Q", "♕", "♛"), rook("R", "♖", "♜"), bishop("B", "♗", "♝"), knight("N", "♘", "♞"), pawn("P", "♙", "♟");
}

data class VPiece(val kind: VPieceKind, val isWhite: Boolean, val square: VSquare) {
    /** La figurine, forcée en TEXTE (pour le lecteur d'écran) ; l'écran montre les images du jeu de pièces. */
    val figurine: String get() = (if (isWhite) kind.white else kind.black) + "︎"
    val label: String get() = figurine + square.notation
    /** « Ng1 » (blanc), « kg8 » (noir). */
    val code: String get() = (if (isWhite) kind.code else kind.code.lowercase()) + square.notation

    companion object {
        fun white(kind: VPieceKind, square: VSquare) = VPiece(kind, true, square)

        fun parseOne(code: String): VPiece? {
            if (code.length != 3) return null
            val kind = VPieceKind.entries.firstOrNull { it.code == code[0].uppercase() } ?: return null
            val square = VSquare.parse(code.substring(1)) ?: return null
            return VPiece(kind, code[0].isUpperCase(), square)
        }

        fun codes(pieces: List<VPiece>) = pieces.joinToString(",") { it.code }
        fun parse(text: String): List<VPiece>? = text.split(",").map { parseOne(it) ?: return null }
    }
}

object VisualizationAttacks {
    private val straight = listOf(1 to 0, -1 to 0, 0 to 1, 0 to -1)
    private val diagonal = listOf(1 to 1, 1 to -1, -1 to 1, -1 to -1)
    private val jumps = listOf(1 to 2, 2 to 1, 2 to -1, 1 to -2, -1 to -2, -2 to -1, -2 to 1, -1 to 2)

    /** Les cases qu'attaque une pièce ; une ligne s'arrête sur la première case OCCUPÉE (comprise). */
    fun from(kind: VPieceKind, at: VSquare, white: Boolean = true, occupied: Set<VSquare> = emptySet()): Set<VSquare> {
        fun rays(directions: List<Pair<Int, Int>>): Set<VSquare> {
            val result = mutableSetOf<VSquare>()
            for ((df, dr) in directions) {
                var current = at
                while (true) {
                    val next = current.offset(df, dr) ?: break
                    result.add(next)
                    if (next in occupied) break
                    current = next
                }
            }
            return result
        }
        return when (kind) {
            VPieceKind.king -> (straight + diagonal).mapNotNull { at.offset(it.first, it.second) }.toSet()
            VPieceKind.queen -> rays(straight + diagonal)
            VPieceKind.rook -> rays(straight)
            VPieceKind.bishop -> rays(diagonal)
            VPieceKind.knight -> jumps.mapNotNull { at.offset(it.first, it.second) }.toSet()
            VPieceKind.pawn -> listOf(-1, 1).mapNotNull { at.offset(it, if (white) 1 else -1) }.toSet()
        }
    }

    /** Tout ce qu'attaque un camp dans une position. */
    fun by(white: Boolean, position: List<VPiece>): Set<VSquare> {
        val occupied = position.map { it.square }.toSet()
        return position.filter { it.isWhite == white }.flatMap { from(it.kind, it.square, it.isWhite, occupied) }.toSet()
    }
}

private val travellers = listOf(VPieceKind.knight, VPieceKind.bishop, VPieceKind.rook, VPieceKind.queen, VPieceKind.king)

/** Un trajet LÉGAL sur un plateau vide : le départ, puis [steps] coups, sans repasser par une case. */
fun VisualizationGenerator.legalPath(kind: VPieceKind, steps: Int, rng: Random): List<VSquare> {
    while (true) {
        val path = mutableListOf(VSquare.all.random(rng))
        for (i in 0 until steps) {
            val options = (VisualizationAttacks.from(kind, path.last()) - path.toSet()).sorted()
            if (options.isEmpty()) break
            path.add(options.random(rng))
        }
        if (path.size == steps + 1) return path
    }
}

fun VisualizationGenerator.isLegalPath(kind: VPieceKind, path: List<VSquare>): Boolean =
    path.zipWithNext().all { (a, b) -> b in VisualizationAttacks.from(kind, a) }

fun VisualizationGenerator.pathCheck(kind: VPieceKind, path: List<VSquare>) = VQuestion(
    VisualizationKind.pathCheck, emptyList(), answer = if (isLegalPath(kind, path)) VAnswer.Yes else VAnswer.No,
    choices = listOf(VAnswer.Yes, VAnswer.No), moves = path.map { VPiece.white(kind, it) },
)

/** Trois coups ; « impossible » : UN coup déplacé d'une case — le piège qu'on veut travailler. */
fun VisualizationGenerator.randomPathCheck(possible: Boolean, rng: Random): VQuestion {
    val kind = travellers.random(rng)
    while (true) {
        val path = legalPath(kind, 3, rng).toMutableList()
        if (!possible) {
            val i = rng.nextInt(1, 4)
            val candidates = listOf(1 to 0, -1 to 0, 0 to 1, 0 to -1, 1 to 1, -1 to -1, 1 to -1, -1 to 1)
                .mapNotNull { path[i].offset(it.first, it.second) }
                .filter { it !in path && it !in VisualizationAttacks.from(kind, path[i - 1]) }
            if (candidates.isEmpty()) continue
            path[i] = candidates.random(rng)
        }
        return pathCheck(kind, path)
    }
}

fun VisualizationGenerator.attackAfter(kind: VPieceKind, path: List<VSquare>, target: VSquare) = VQuestion(
    VisualizationKind.attackAfter, listOf(target),
    answer = if (target in VisualizationAttacks.from(kind, path.last())) VAnswer.Yes else VAnswer.No,
    choices = listOf(VAnswer.Yes, VAnswer.No), moves = path.map { VPiece.white(kind, it) },
)

/** Deux coups ; la case visée est attaquée, ou en est tout près. */
fun VisualizationGenerator.randomAttackAfter(attacked: Boolean, rng: Random): VQuestion {
    val kind = travellers.random(rng)
    while (true) {
        val path = legalPath(kind, 2, rng)
        val end = path.last()
        val attackedSet = VisualizationAttacks.from(kind, end)
        val pool = if (attacked) attackedSet.sorted() else VSquare.all.filter {
            it !in attackedSet && it != end && maxOf(abs(it.file - end.file), abs(it.rank - end.rank)) <= 3
        }
        if (pool.isEmpty()) continue
        return attackAfter(kind, path, pool.random(rng))
    }
}

/** Les deux pièces après leurs coups, et qui attaque la case visée (l'une peut masquer l'autre). */
fun VisualizationGenerator.twoPieces(starts: List<VPiece>, moves: List<VPiece>, target: VSquare): VQuestion {
    var a = starts[0].square
    var b = starts[1].square
    for (move in moves) if (move.kind == starts[0].kind) a = move.square else b = move.square
    val occupied = setOf(a, b)
    val byA = target in VisualizationAttacks.from(starts[0].kind, a, occupied = occupied)
    val byB = target in VisualizationAttacks.from(starts[1].kind, b, occupied = occupied)
    val answer = when {
        byA && byB -> "both"
        byA -> "first"
        byB -> "second"
        else -> "none"
    }
    return VQuestion(
        VisualizationKind.twoPieces, listOf(target), answer = VAnswer.Option(answer),
        choices = listOf("first", "second", "both", "none").map { VAnswer.Option(it) }, pieces = starts, moves = moves,
    )
}

fun VisualizationGenerator.randomTwoPieces(rng: Random): VQuestion {
    val wanted = listOf("first", "second", "both", "none").random(rng)
    while (true) {
        val kinds = listOf(VPieceKind.knight, VPieceKind.bishop, VPieceKind.rook, VPieceKind.queen).shuffled(rng).take(2)
        val a0 = VSquare.all.random(rng)
        val b0 = VSquare.all.random(rng)
        if (a0 == b0) continue
        val current = mutableListOf(a0, b0)
        val moves = mutableListOf<VPiece>()
        for (mover in listOf(0, 1, 0)) {
            val other = current[1 - mover]
            val options = (VisualizationAttacks.from(kinds[mover], current[mover], occupied = setOf(other)) - other).sorted()
            if (options.isEmpty()) break
            val next = options.random(rng)
            current[mover] = next
            moves.add(VPiece.white(kinds[mover], next))
        }
        if (moves.size != 3) continue
        val starts = listOf(VPiece.white(kinds[0], a0), VPiece.white(kinds[1], b0))
        val target = VSquare.all.filter { it !in current }.shuffled(rng)
            .firstOrNull { twoPieces(starts, moves, it).answer == VAnswer.Option(wanted) } ?: continue
        return twoPieces(starts, moves, target)
    }
}

/** Deux rois qui ne se touchent pas, deux ou trois pièces de chaque côté (une dame au plus), pions hors des bords. */
fun VisualizationGenerator.randomPosition(rng: Random): List<VPiece> {
    val pool = listOf(VPieceKind.queen, VPieceKind.rook, VPieceKind.rook, VPieceKind.bishop, VPieceKind.bishop,
        VPieceKind.knight, VPieceKind.knight, VPieceKind.pawn, VPieceKind.pawn)
    while (true) {
        val taken = mutableSetOf<VSquare>()
        fun free(pawn: Boolean): VSquare? =
            VSquare.all.filter { it !in taken && (!pawn || it.rank in 1..6) }.randomOrNull(rng)
        val position = mutableListOf<VPiece>()
        val wk = free(false) ?: continue
        taken.add(wk); position.add(VPiece(VPieceKind.king, true, wk))
        val bk = free(false) ?: continue
        if (maxOf(abs(bk.file - wk.file), abs(bk.rank - wk.rank)) <= 1) continue
        taken.add(bk); position.add(VPiece(VPieceKind.king, false, bk))
        for (white in listOf(true, false)) {
            val count = rng.nextInt(2, 4)
            var kinds = pool.shuffled(rng).take(count)
            if (kinds.count { it == VPieceKind.queen } > 1) kinds = kinds.map { if (it == VPieceKind.queen) VPieceKind.rook else it }
            for (kind in kinds) {
                val s = free(kind == VPieceKind.pawn) ?: continue
                taken.add(s); position.add(VPiece(kind, white, s))
            }
        }
        if (wk in VisualizationAttacks.by(false, position)) continue
        return position
    }
}

fun VisualizationGenerator.isCheck(position: List<VPiece>): VQuestion {
    val blackKing = position.first { it.kind == VPieceKind.king && !it.isWhite }.square
    val check = blackKing in VisualizationAttacks.by(true, position)
    return VQuestion(VisualizationKind.isCheck, emptyList(), answer = if (check) VAnswer.Yes else VAnswer.No,
        choices = listOf(VAnswer.Yes, VAnswer.No), pieces = position)
}

fun VisualizationGenerator.randomIsCheck(check: Boolean, rng: Random): VQuestion {
    repeat(400) {
        val q = isCheck(randomPosition(rng))
        if (q.answer == (if (check) VAnswer.Yes else VAnswer.No)) return q
    }
    return isCheck(randomPosition(rng))
}

/** Les pièces noires (hors roi) attaquées par les Blancs et que rien de noir ne défend. */
fun VisualizationGenerator.hanging(position: List<VPiece>): List<VPiece> {
    val byWhite = VisualizationAttacks.by(true, position)
    val byBlack = VisualizationAttacks.by(false, position)
    return position.filter { !it.isWhite && it.kind != VPieceKind.king && it.square in byWhite && it.square !in byBlack }
}

/** `null` si la position n'a pas UNE réponse (deux pièces en prise) ou trop peu de pièces noires à proposer. */
fun VisualizationGenerator.hangingPiece(position: List<VPiece>, rng: Random): VQuestion? {
    val blacks = position.filter { !it.isWhite && it.kind != VPieceKind.king }
    val hung = hanging(position)
    if (blacks.size < 2 || hung.size > 1) return null
    val answer: VAnswer = hung.firstOrNull()?.let { VAnswer.Square(it.square) } ?: VAnswer.Option("none")
    val choices = blacks.shuffled(rng).map { VAnswer.Square(it.square) } + VAnswer.Option("none")
    return VQuestion(VisualizationKind.hangingPiece, emptyList(), answer = answer, choices = choices, pieces = position)
}

fun VisualizationGenerator.randomHangingPiece(one: Boolean, rng: Random): VQuestion {
    var fallback: VQuestion? = null
    repeat(600) {
        val q = hangingPiece(randomPosition(rng), rng) ?: return@repeat
        if ((q.answer != VAnswer.Option("none")) == one) return q
        if (fallback == null) fallback = q
    }
    fallback?.let { return it }
    while (true) hangingPiece(randomPosition(rng), rng)?.let { return it }
}

fun VisualizationGenerator.squareAttacked(position: List<VPiece>, target: VSquare) = VQuestion(
    VisualizationKind.squareAttacked, listOf(target),
    answer = if (target in VisualizationAttacks.by(true, position)) VAnswer.Yes else VAnswer.No,
    choices = listOf(VAnswer.Yes, VAnswer.No), pieces = position,
)

fun VisualizationGenerator.randomSquareAttacked(attacked: Boolean, rng: Random): VQuestion {
    while (true) {
        val position = randomPosition(rng)
        val occupied = position.map { it.square }.toSet()
        val byWhite = VisualizationAttacks.by(true, position)
        val pool = VSquare.all.filter { it !in occupied && (it in byWhite) == attacked }
        if (pool.isNotEmpty()) return squareAttacked(position, pool.random(rng))
    }
}
