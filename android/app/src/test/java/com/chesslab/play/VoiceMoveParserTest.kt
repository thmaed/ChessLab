package com.chesslab.play

import chesskit.Board
import chesskit.Position
import chesskit.Square
import com.chesslab.play.VoiceMoveParser.Candidate
import com.chesslab.play.VoiceMoveParser.Outcome
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Coups à la voix (19/11/2026). Pendant de `VoiceMoveParserTests` + `VoiceMoveRealTrialsTests` (iOS). */
class VoiceMoveParserTest {

    private fun candidates(fen: String? = null, after: List<String> = emptyList()): List<Candidate> {
        val board = Board(fen?.let { Position.fromFen(it) } ?: Position.standard)
        for (lan in after) board.move(pieceAt = Square(lan.take(2)), to = Square(lan.takeLast(2)))
        return VoiceMoveParser.candidates(board)
    }

    private fun uci(text: String, legal: List<Candidate>): String? =
        (VoiceMoveParser.resolve(listOf(text), legal) as? Outcome.Move)?.move?.uci

    @Test fun `la position initiale a vingt coups`() {
        assertEquals(20, candidates().size)
    }

    @Test fun `coups depuis la position initiale`() {
        val cases = listOf(
            "e4" to "e2e4", "E4" to "e2e4", "pion e4" to "e2e4", "Pion en e 4" to "e2e4", "euh 4" to "e2e4",
            "Cavalier f3" to "g1f3", "cavalier en F3." to "g1f3", "Cavalier effe trois" to "g1f3", "Cf3" to "g1f3",
            "c'est 4" to "c2c4", "dé 4" to "d2d4", "Cavalier c3" to "b1c3", "f3" to "f2f3",
        )
        val legal = candidates()
        for ((text, expected) in cases) assertEquals("« $text »", expected, uci(text, legal))
    }

    @Test fun `un coup qu'aucune pièce ne peut faire est impossible`() {
        assertEquals(Outcome.Illegal, VoiceMoveParser.resolve(listOf("fou c4"), candidates()))
        assertEquals(Outcome.NotUnderstood, VoiceMoveParser.resolve(listOf("bonjour"), candidates()))
    }

    @Test fun `e4 entendu Au quatre`() {
        // iPhone3 et iPhone XS, 20/11/2026 : « e4 » écrit « Au quatre » ou « O quatre ».
        assertEquals("e2e4", uci("Au quatre", candidates()))
        assertEquals("e2e4", uci("O quatre", candidates()))
        assertEquals(Outcome.NotUnderstood, VoiceMoveParser.resolve(listOf("au revoir"), candidates()))
    }

    @Test fun `les roques`() {
        val italian = candidates(after = listOf("e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5"))
        assertEquals("e1g1", uci("petit roque", italian))
        assertEquals(Outcome.Illegal, VoiceMoveParser.resolve(listOf("grand roque"), italian))
        assertEquals("e1g1", uci("roque", italian))
        // Ce que la reconnaissance a écrit en partie sur iPhone3 (20/11/2026).
        for (heard in listOf("Petit rock", "Roi, Petit roc", "P rock", "Roi Petitoc", "Rock")) {
            assertEquals("« $heard »", "e1g1", uci(heard, italian))
        }
        assertEquals(Outcome.Illegal, VoiceMoveParser.resolve(listOf("Grand rock"), italian))
    }

    @Test fun `deux cavaliers pour une case demandent lequel`() {
        val legal = candidates("4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1")
        val outcome = VoiceMoveParser.resolve(listOf("cavalier d2"), legal)
        assertTrue(outcome is Outcome.Ambiguous)
        assertEquals(setOf("b1d2", "f3d2"), (outcome as Outcome.Ambiguous).moves.map { it.uci }.toSet())
        assertEquals("b1d2", uci("cavalier b d2", legal))
        assertEquals("f3d2", uci("cavalier f3 d2", legal))
    }

    @Test fun `deux tours pour une case, dites à la façon officielle`() {
        // Retour de Nils (21/11/2026). Tours a1 et h1, roi e2 : les deux tours peuvent aller en e1.
        val legal = candidates("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
        for (text in listOf(
            "Tour H E 1", "Tour h e1", "Tour H E un", "tour he1", "Tour HE1", "Tour, H, E 1", "Tour hache e un",
            "Tour H en e1", "Tour h1 en e1", "The1", "Tour H 1 en E 1", "Tour ache e un",
        )) assertEquals("« $text »", "h1e1", uci(text, legal))
        for (text in listOf("Tour A E 1", "Tour a e1", "Tour ae1", "Tour a1 en e1")) {
            assertEquals("« $text »", "a1e1", uci(text, legal))
        }
    }

    @Test fun `le SAN réel de deux tours porte la colonne de départ`() {
        val legal = candidates("4k3/8/8/8/8/8/4K3/R6R w - - 0 1")
        assertEquals(setOf("Rhe1", "Rae1"), legal.filter { it.to == "e1" && it.piece == 'R' }.map { it.san }.toSet())
        // Ce que l'annonce répète (« tour h en e 1 ») se comprend en retour.
        assertEquals("h1e1", uci("tour h en e 1", legal))
    }

    @Test fun `la rangée de départ distingue aussi deux tours`() {
        // Tours a1 et a5, roi e1 : les deux vont en a3.
        val legal = candidates("7k/8/8/R7/8/8/8/R3K3 w - - 0 1")
        assertEquals("a1a3", uci("Tour 1 a3", legal))
        assertEquals("a5a3", uci("Tour 5 en a 3", legal))
        assertEquals("a5a3", uci("Tour 5 a 3", legal))
    }

    @Test fun `en anglais deux pour to n'est pas une rangée`() {
        val english = VoiceMoveParser.vocabulary("en")
        assertEquals(null, VoiceMoveParser.heard("knight 2 f3", english).fromRank)
        assertEquals(null, VoiceMoveParser.heard("rook 1 a3", english).fromRank)
        assertEquals('1', VoiceMoveParser.heard("tour 1 a3").fromRank)
    }

    @Test fun `promotion en dame sauf si une autre pièce est nommée`() {
        val legal = candidates("8/P7/8/8/8/8/8/k6K w - - 0 1")
        assertEquals("a7a8q", uci("a8", legal))
        assertEquals("a7a8q", uci("a8 dame", legal))
        assertEquals("a7a8n", uci("a8 cavalier", legal))
        assertEquals("a7a8r", uci("pion a8 promotion tour", legal))
    }

    @Test fun `une lettre qui rime est rattrapée quand un seul coup convient`() {
        val legal = candidates("4k3/8/8/8/8/8/3P4/4K3 w - - 0 1")
        assertEquals("d2d4", uci("bé 4", legal))
        assertEquals(Outcome.Illegal, VoiceMoveParser.resolve(listOf("bé 4"), legal, confusions = false))
    }

    @Test fun `les formes dites couvrent l'usage`() {
        val forms = VoiceMoveParser.spokenForms(candidates())
        assertTrue("cavalier f3" in forms)
        assertTrue("pion en e4" in forms)
        assertTrue("e4" in forms)
    }

    /**
     * Les 51 essais RÉELS du 19/11/2026 sur iPhone3, rejoués : Android doit donner EXACTEMENT les mêmes chiffres
     * qu'iOS (48/48/47/48/47 justes, 49 avec au moins une) — la preuve que le portage est fidèle.
     */
    @Test fun `rejeu des essais réels de l'iPhone`() {
        val text = javaClass.classLoader!!.getResource("voice/trials-2026-11-19-iphone3.jsonl")!!.readText()
        val trials = text.lines().filter { it.isNotBlank() }.map { JSONObject(it) }
        assertEquals(51, trials.size)
        val right = HashMap<String, Int>()
        val wrong = HashMap<String, Int>()
        var anyRight = 0
        for (trial in trials) {
            fun candidate(o: JSONObject) = Candidate(o.getString("uci"), o.getString("san"))
            val target = candidate(trial.getJSONObject("target"))
            val legal = trial.getJSONArray("candidates").let { a -> (0 until a.length()).map { candidate(a.getJSONObject(it)) } }
            var found = false
            val results = trial.getJSONArray("results")
            for (i in 0 until results.length()) {
                val result = results.getJSONObject(i)
                val transcripts = result.getJSONArray("transcripts").let { a -> (0 until a.length()).map { a.getString(it) } }
                val outcome = VoiceMoveParser.resolve(transcripts, legal)
                if (outcome is Outcome.Move && outcome.move == target) {
                    right.merge(result.getString("engine"), 1, Int::plus)
                    found = true
                } else if (outcome is Outcome.Move) {
                    wrong.merge(result.getString("engine"), 1, Int::plus)
                }
            }
            if (found) anyRight++
        }
        println("REJEU justes : $right ; faux coups : $wrong ; au moins une : $anyRight")
        assertEquals(
            // D : 48 → 49 le 20/11/2026 avec « au »/« o » pour la colonne e (« Au quatre »).
            mapOf("A classique" to 48, "B indices" to 48, "C vocabulaire" to 47, "D iOS 26" to 49, "E iOS 26 + vocab." to 47),
            right.toMap(),
        )
        assertEquals(50, anyRight)
    }

    // Les cinq langues — pendant de `VoiceMoveParserLanguagesTests` (iOS).

    private fun uciIn(text: String, language: String, after: List<String> = emptyList()): String? =
        (VoiceMoveParser.resolve(
            listOf(text), candidates(after = after), vocabulary = VoiceMoveParser.vocabulary(language),
        ) as? Outcome.Move)?.move?.uci

    private val italianGame = listOf("e2e4", "e7e5", "g1f3", "b8c6", "f1c4", "f8c5")

    @Test fun `le cavalier en f3 dans chaque langue`() {
        listOf(
            "knight f3" to "en", "Knight to F3" to "en", "Nf3" to "en", "knight to foxtrot three" to "en",
            "caballo f3" to "es", "caballo a efe tres" to "es", "Cf3" to "es",
            "Springer f3" to "de", "Springer nach f drei" to "de", "Sf3" to "de",
            "cavallo f3" to "it", "cavallo in effe tre" to "it", "Cf3" to "it",
            "cavalier f3" to "fr", "Cavalier Foxtrot 3" to "fr",
        ).forEach { (text, language) -> assertEquals("« $text » ($language)", "g1f3", uciIn(text, language)) }
    }

    @Test fun `le pion en e4 dans chaque langue`() {
        listOf(
            "pawn e4" to "en", "e four" to "en", "peón e4" to "es", "e cuatro" to "es",
            "Bauer e4" to "de", "e vier" to "de", "pedone e4" to "it", "e quattro" to "it",
        ).forEach { (text, language) -> assertEquals("« $text » ($language)", "e2e4", uciIn(text, language)) }
    }

    @Test fun `le petit roque dans chaque langue`() {
        listOf(
            "castles kingside" to "en", "enroque corto" to "es", "kurze Rochade" to "de", "arrocco corto" to "it",
            "petit roque" to "fr",
        ).forEach { (text, language) -> assertEquals("« $text » ($language)", "e1g1", uciIn(text, language, italianGame)) }
    }

    @Test fun `la reprise s'entend dans chaque langue`() {
        listOf("annule" to "fr", "take back" to "en", "deshacer" to "es", "zurück" to "de", "annulla" to "it")
            .forEach { (text, language) ->
                assertTrue(text, VoiceMoveParser.isUndo(text, VoiceMoveParser.vocabulary(language)))
            }
        assertTrue(!VoiceMoveParser.isUndo("cavalier f3"))
    }

    @Test fun `une conversation n'est pas un coup`() {
        assertTrue(!VoiceMoveParser.soundsLikeChess(listOf("tu veux un café ?")))
        assertTrue(VoiceMoveParser.soundsLikeChess(listOf("cavalier f3")))
        assertTrue(VoiceMoveParser.soundsLikeChess(listOf("annule")))
    }

    /**
     * Les essais du GALAXY (mesure du 19/11/2026 au soir), s'ils sont là : `tools/mesure-dictee-galaxy.sh` les
     * récupère dans `src/test/resources/voice/` et lit ce rapport. Aucune attente chiffrée : il s'agit de DÉCIDER
     * (quelle reconnaissance garder, avec ou sans indices), pas de vérifier.
     */
    @Test fun `rapport des essais du Galaxy`() {
        val dir = javaClass.classLoader!!.getResource("voice")?.let { java.io.File(it.toURI()) } ?: return
        val files = dir.listFiles { f -> f.name.contains("galaxy") && f.name.endsWith(".jsonl") }.orEmpty().sorted()
        if (files.isEmpty()) return
        java.io.File("build/voice-lab-report.txt").writeText(replayReport(files))
    }

    /**
     * N'importe quel journal au format de la mesure, déposé dans `app/build/voice-replay/` — par exemple les
     * transcriptions de Whisper (`tools/whisper-spike`, étude du 19/11/2026) : rejouées par le VRAI module.
     */
    @Test fun `rapport des journaux rejoués`() {
        val files = java.io.File("build/voice-replay").listFiles { f -> f.name.endsWith(".jsonl") }.orEmpty().sorted()
        if (files.isEmpty()) return
        java.io.File("build/voice-replay-report.txt").writeText(replayReport(files))
    }

    private fun replayReport(files: List<java.io.File>): String {
        val report = StringBuilder()
        for (file in files) {
            val trials = file.readLines().filter { it.isNotBlank() }.map { JSONObject(it) }
            report.appendLine("${file.name} : ${trials.size} essais")
            val recorded = HashMap<String, Int>()
            val replayed = HashMap<String, Int>()
            val empty = HashMap<String, Int>()
            val wrong = HashMap<String, Int>()
            val millis = HashMap<String, MutableList<Long>>()
            var anyRight = 0
            for (trial in trials) {
                fun candidate(o: JSONObject) = Candidate(o.getString("uci"), o.getString("san"))
                val target = candidate(trial.getJSONObject("target"))
                val legal = trial.getJSONArray("candidates").let { a -> (0 until a.length()).map { candidate(a.getJSONObject(it)) } }
                var found = false
                val results = trial.getJSONArray("results")
                for (i in 0 until results.length()) {
                    val result = results.getJSONObject(i)
                    val engine = result.getString("engine")
                    val transcripts = result.getJSONArray("transcripts").let { a -> (0 until a.length()).map { a.getString(it) } }
                    if (result.optBoolean("correct")) recorded.merge(engine, 1, Int::plus)
                    if (transcripts.isEmpty()) empty.merge(engine, 1, Int::plus)
                    millis.getOrPut(engine) { mutableListOf() } += result.optLong("millis")
                    when (val outcome = VoiceMoveParser.resolve(transcripts, legal)) {
                        is Outcome.Move -> if (outcome.move == target) {
                            replayed.merge(engine, 1, Int::plus); found = true
                        } else wrong.merge(engine, 1, Int::plus)
                        else -> Unit
                    }
                }
                if (found) anyRight++
            }
            for (engine in millis.keys.sorted()) {
                val times = millis.getValue(engine).sorted()
                report.appendLine(
                    "  $engine : justes ${replayed[engine] ?: 0}/${trials.size} au rejeu (${recorded[engine] ?: 0} sur le " +
                        "téléphone), FAUX coups ${wrong[engine] ?: 0}, rien entendu ${empty[engine] ?: 0}, " +
                        "médiane ${times[times.size / 2]} ms",
                )
            }
            report.appendLine("  au moins une juste : $anyRight/${trials.size}")
            report.appendLine("  (iPhone, 51 essais : 48/48/47/48/47 justes, 49 au moins une)")
        }
        return report.toString()
    }

    // Quand la reconnaissance hésite (pendant des tests iOS, iPhone 11, 21/11/2026).

    @Test fun `deux coups legaux a egalite de voix font hesiter la reconnaissance`() {
        val legal = candidates()
        val outcome = VoiceMoveParser.resolve(listOf("A3", "E3"), legal)
        assertTrue("« A3 » et « E3 » : deux coups légaux", outcome is VoiceMoveParser.Outcome.Conflicting)
        assertEquals(listOf("a2a3", "e2e3"), (outcome as VoiceMoveParser.Outcome.Conflicting).moves.map { it.uci })
        val other = VoiceMoveParser.resolve(listOf("pion c3", "Pion des quatre"), legal)
        assertEquals(
            listOf("c2c3", "d2d4"),
            (other as VoiceMoveParser.Outcome.Conflicting).moves.map { it.uci },
        )
    }

    @Test fun `le coup que le plus d alternatives designent l emporte`() {
        val legal = candidates()
        assertEquals("d2d4", uci("pion d4", legal))
        val voted = VoiceMoveParser.resolve(listOf("A3", "13", "E3", "Eux trois"), legal)
        assertEquals("e2e3", (voted as VoiceMoveParser.Outcome.Move).move.uci)
        // Les variantes d'un MÊME coup ne sont pas une hésitation.
        val same = VoiceMoveParser.resolve(listOf("D4", "Des quatre", "pion en d4"), legal)
        assertEquals("d2d4", (same as VoiceMoveParser.Outcome.Move).move.uci)
    }

    @Test fun `la reponse premier ou deuxieme tranche entre deux coups dans les cinq langues`() {
        val cases = listOf(
            Triple("Premier", "fr", 0), Triple("le deuxième", "fr", 1), Triple("deux", "fr", 1),
            Triple("Second", "fr", 1), Triple("e4", "fr", null),
            Triple("first", "en", 0), Triple("the second one", "en", 1),
            Triple("primero", "es", 0), Triple("el segundo", "es", 1),
            Triple("erster", "de", 0), Triple("zweiter", "de", 1),
            Triple("primo", "it", 0), Triple("il secondo", "it", 1),
        )
        for ((text, language, expected) in cases) {
            assertEquals("« $text » ($language)", expected, VoiceMoveParser.choice(listOf(text), language))
        }
    }
}
