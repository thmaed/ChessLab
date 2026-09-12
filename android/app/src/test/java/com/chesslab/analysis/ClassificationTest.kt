package com.chesslab.analysis

import chesskit.Board
import chesskit.Piece
import chesskit.Position
import chesskit.Square
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le barème de classification, vérifié sur des valeurs écrites à la main.
 *
 * Ces fonctions sont PURES : ni moteur, ni base, ni horloge. C'est ce qui les
 * rend vérifiables sans émulateur — et c'est pour ça qu'elles ont été écrites
 * comme ça des deux côtés.
 */
class ClassificationTest {

    private fun input(
        before: Double, after: Double,
        best: Boolean = false, gap: Double? = null,
        book: Boolean = false, forced: Boolean = false,
        sacrifice: Boolean = false, recaptured: Boolean = false,
        tactical: Boolean = false,
    ) = MoveClassifier.Input(
        winPercentBefore = before, winPercentAfter = after,
        isBestMove = best, gapToSecondBest = gap, isBook = book, isForced = forced,
        isSacrifice = sacrifice, sacrificeImmediatelyRecaptured = recaptured,
        bestMoveWasTactical = tactical,
    )

    @Test fun `l'échelle des pertes suit le barème`() {
        assertEquals(MoveQuality.excellent, MoveClassifier.classify(input(50.0, 49.0)))
        assertEquals(MoveQuality.good, MoveClassifier.classify(input(50.0, 46.0)))
        assertEquals(MoveQuality.inaccuracy, MoveClassifier.classify(input(50.0, 43.0)))
        assertEquals(MoveQuality.mistake, MoveClassifier.classify(input(50.0, 38.0)))
        assertEquals(MoveQuality.blunder, MoveClassifier.classify(input(50.0, 25.0)))
    }

    @Test fun `la théorie et le coup forcé échappent au barème`() {
        // Une gaffe théorique reste de la théorie : tant qu'on récite, l'éval
        // ne juge personne.
        assertEquals(MoveQuality.book, MoveClassifier.classify(input(50.0, 20.0, book = true)))
        assertEquals(MoveQuality.best, MoveClassifier.classify(input(50.0, 20.0, forced = true)))
    }

    @Test fun `le seul bon coup devient un grand coup`() {
        assertEquals(MoveQuality.great, MoveClassifier.classify(input(50.0, 50.0, best = true, gap = 20.0)))
        // Écart insuffisant : c'est simplement le meilleur coup.
        assertEquals(MoveQuality.best, MoveClassifier.classify(input(50.0, 50.0, best = true, gap = 10.0)))
    }

    @Test fun `un sacrifice repris tout de suite n'est pas brillant`() {
        assertEquals(
            MoveQuality.brilliant,
            MoveClassifier.classify(input(50.0, 55.0, best = true, gap = 20.0, sacrifice = true)),
        )
        assertEquals(
            MoveQuality.great,
            MoveClassifier.classify(
                input(50.0, 55.0, best = true, gap = 20.0, sacrifice = true, recaptured = true)
            ),
        )
    }

    @Test fun `dans une position gagnée, rater une tactique est une occasion manquée`() {
        // Gagnée avant, encore gagnante après, et c'est une TACTIQUE qui a été
        // ratée : « occasion manquée » et non « gaffe ».
        assertEquals(
            MoveQuality.miss,
            MoveClassifier.classify(input(95.0, 60.0, tactical = true)),
        )
        // Le même relâchement SANS tactique ratée reste une gaffe : sans cette
        // condition, tout flottement dans une position gagnée devenait un
        // « miss ».
        assertEquals(MoveQuality.blunder, MoveClassifier.classify(input(95.0, 60.0)))
    }

    @Test fun `un grand coup reste possible dans une position gagnée si le second choix s'effondre`() {
        // Position déjà gagnée : l'écart normal (20 %) ne suffit plus…
        assertEquals(MoveQuality.best, MoveClassifier.classify(input(90.0, 90.0, best = true, gap = 20.0)))
        // …mais un effondrement du 2e choix, si : un seul coup gardait le gain.
        assertEquals(MoveQuality.great, MoveClassifier.classify(input(90.0, 90.0, best = true, gap = 35.0)))
    }

    @Test fun `la sigmoïde sature comme sur iOS`() {
        assertEquals(50.0, EvalConversion.fromCentipawns(0), 0.001)
        assertTrue(EvalConversion.fromCentipawns(100) > 58)
        assertTrue(EvalConversion.fromCentipawns(100) < 62)
        // Un mat forcé vaut 100/0, quelle que soit sa longueur : sinon un mat
        // en 1 et un mat en 20 auraient des scores arbitrairement différents.
        assertEquals(100.0, EvalConversion.fromMate(1), 0.0)
        assertEquals(100.0, EvalConversion.fromMate(20), 0.0)
        assertEquals(0.0, EvalConversion.fromMate(-3), 0.0)
    }

    @Test fun `une partie sans faute plafonne à cent pour cent`() {
        assertEquals(100.0, AccuracyScore.accuracy(0.0), 0.0)
        assertTrue(AccuracyScore.accuracy(25.0) < 40)
    }

    @Test fun `la traîne de fin de partie ne gonfle plus la précision`() {
        // Une partie de club : une gaffe, deux erreurs, trois imprécisions,
        // puis du calme. Le camp blanc joue les coups pairs.
        val open = listOf(50.0, 50.0, 45.0, 44.0, 25.0, 26.0, 30.0)
        // Vingt coups de finition dans une position tranchée : ils ne doivent
        // PAS regonfler le score, puisqu'ils ne pouvaient rien perdre.
        val trailing = List(20) { 95.0 }
        val weights = AccuracyScore.moveWeights(open + trailing)
        // Les poids de la traîne sont au plancher, ceux du début ne le sont pas.
        val tail = weights.takeLast(15)
        assertTrue(tail.all { it <= AccuracyScore.DECIDED_STAKE * 3 + 1e-9 })
        assertTrue(weights.take(4).any { it > 0.5 })
    }

    @Test fun `un sacrifice se reconnaît à ce qu'il abandonne`() {
        // Dxh7+ : on donne neuf points pour en reprendre un, et le roi peut
        // encaisser. C'est un sacrifice au sens du classifieur.
        val board = Board(Position.fromFen("6k1/7p/8/7Q/8/8/8/6K1 w - - 0 1")!!)
        val move = board.move(Square("h5"), Square("h7"))!!
        assertTrue(MoveClassifier.involvesSacrifice(move, board))

        // La même dame qui avance sur une case que RIEN n'attaque ne sacrifie
        // rien : ce n'est un sacrifice que si l'adversaire peut encaisser.
        val quiet = Board(Position.fromFen("6k1/8/8/8/8/8/8/6KQ w - - 0 1")!!)
        val step = quiet.move(Square("h1"), Square("h5"))!!
        assertTrue(!MoveClassifier.involvesSacrifice(step, quiet))
    }
}

/** Les motifs, établis en rejouant les coups — jamais devinés. */
class TacticalMotifTest {

    private fun after(fen: String, from: String, to: String): Pair<chesskit.Move, Board> {
        val board = Board(Position.fromFen(fen)!!)
        val move = board.move(Square(from), Square(to))!!
        return move to board
    }

    @Test fun `une fourchette de cavalier sur roi et tour est nommée`() {
        // Cavalier blanc en h5 saute en f6 : échec au roi en g8 ET attaque de
        // la tour en e8 — la fourchette royale, sans traitement à part.
        val (move, board) = after("4r1k1/5ppp/8/7N/8/8/5PPP/6K1 w - - 0 1", "h5", "f6")
        val motif = TacticalMotifDetector.detect(move, board)
        assertTrue("motif = $motif", motif is TacticalMotif.Fork)
        val fork = motif as TacticalMotif.Fork
        // Le roi d'abord : c'est l'ordre de la menace, et celui de la phrase.
        assertEquals(Piece.Kind.king, fork.targets.first())
    }

    @Test fun `une pièce reprise n'est pas une pièce en prise`() {
        // La tour prend en d5 où un pion peut reprendre : c'est un échange.
        val (move, board) = after("6k1/8/4p3/3n4/8/3R4/6PP/6K1 w - - 0 1", "d3", "d5")
        assertNull(TacticalMotifDetector.detect(move, board))
    }

    @Test fun `le mat du couloir se distingue d'un mat de finale`() {
        // Roi noir en g8 étouffé par ses trois pions : la tour arrive en e8.
        val board = Board(Position.fromFen("6k1/5ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1")!!)
        val move = board.move(Square("e1"), Square("e8"))!!
        val motif = TacticalMotifDetector.detect(move, board)
        assertTrue("motif = $motif", motif is TacticalMotif.Checkmate)
        assertTrue((motif as TacticalMotif.Checkmate).isBackRank)
    }

    @Test fun `l'explication lit la réfutation et chiffre la perte`() {
        // Les Blancs viennent de poser leur tour en d5, où le cavalier noir la
        // prend. Rien ne reprend : la tour est perdue sèche.
        val position = Position.fromFen("6k1/8/8/3R4/8/4n3/6PP/6K1 b - - 0 1")!!
        val explanation = MoveExplainer.explain(position, listOf("e3d5"))
        assertNotNull(explanation)
        assertTrue("motif = ${explanation!!.motif}", explanation.motif is TacticalMotif.HangingPiece)
        // Cinq points de tour, et la ligne s'arrête sur une position calme.
        assertEquals(5, explanation.materialLoss)
        assertEquals("Nxd5", explanation.refutationSan)
    }

    @Test fun `une ligne qui ne coûte rien ne dit rien`() {
        // Position morte : ni motif, ni perte. Mieux vaut se taire que meubler.
        val position = Position.fromFen("6k1/5ppp/8/8/8/8/5PPP/6K1 b - - 0 1")!!
        assertNull(MoveExplainer.explain(position, listOf("g8h8", "g1h1", "h8g8")))
    }
}

/** La reconnaissance d'ouverture, et le critère « coup de théorie ». */
class EcoLookupTest {

    private val base = listOf(
        EcoOpening("B20", "Défense sicilienne", "Sicilian Defence", listOf("e4", "c5")),
        EcoOpening("B90", "Sicilienne, variante Najdorf", "Sicilian, Najdorf",
            listOf("e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6")),
        EcoOpening("C00", "Défense française", "French Defence", listOf("e4", "e6")),
    )

    @Test fun `le plus long préfixe gagne`() {
        val path = listOf("e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6", "Be3")
        assertEquals("B90", EcoOpeningLookup.openingName(path, base)?.eco)
        // Trois coups seulement : la Najdorf n'est pas encore confirmée.
        assertEquals("B20", EcoOpeningLookup.openingName(listOf("e4", "c5", "Nf3"), base)?.eco)
    }

    @Test fun `le livre se lit dans l'autre sens`() {
        // « Encore dans le livre » : c'est la BASE qui prolonge la partie.
        assertTrue(EcoOpeningLookup.isInBook(listOf("e4", "c5", "Nf3", "d6"), base))
        // Un coup hors théorie sort du livre, même court.
        assertTrue(!EcoOpeningLookup.isInBook(listOf("e4", "c5", "Bc4"), base))
        assertTrue(!EcoOpeningLookup.isInBook(emptyList(), base))
    }
}
