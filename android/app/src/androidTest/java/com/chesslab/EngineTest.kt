package com.chesslab

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.chesslab.engine.EngineService
import com.chesslab.engine.FairyEngine
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Les deux moteurs natifs. Le module `engine` n'avait aucun test : ce qu'il
 * fait passe par JNI, du C++ statique et des threads, c'est-à-dire tout ce qui
 * ne se voit pas à la lecture.
 *
 * Le cas qui motive ce fichier : `libchesslab_engine.so` et
 * `libchesslab_fairy.so` embarquent CHACUNE sa libc++ en statique, et toutes
 * deux exportent `std::cout` sous le même nom mangé. Si le lien dynamique les
 * confondait, le shim de l'une détournerait la sortie de l'autre et leurs
 * réponses se mélangeraient. Ce test le règle par l'expérience.
 */
@RunWith(AndroidJUnit4::class)
class EngineTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    /**
     * Le Crazyhouse, vérifié SUR LE MOTEUR et pas sur une idée qu'on s'en
     * fait : après 1.e4 d5 2.exd5, les Blancs ont un pion en main. La FEN doit
     * le porter entre crochets, et la liste des coups légaux doit contenir des
     * POSES, de la forme « P@e4 ».
     *
     * C'est la plomberie entière de la variante : la réserve affichée en vient,
     * et le geste de pose aussi. Pendant de `CrazyhousePlumbingTests`.
     */
    @Test fun leCrazyhouseRendUneReserveEtDesPoses() = runBlocking {
        val query = withContext(Dispatchers.IO) {
            FairyEngine.use(context) { engine ->
                engine.queryPosition("crazyhouse", null, listOf("e2e4", "d7d5", "e4d5"))
            }
        }
        assertNotNull("le moteur de variantes devrait répondre", query)
        val fen = query!!.fen
        assertTrue("la FEN devrait porter la réserve : $fen", fen.contains("[") && fen.contains("]"))

        val pocket = com.chesslab.variants.CrazyhouseFen.pocket(fen)
        assertEquals(
            "un pion blanc en main après la prise",
            mapOf(chesskit.Piece.Kind.pawn to 1),
            pocket[chesskit.Piece.Color.white],
        )

        // C'est aux NOIRS de jouer : les poses listées sont les leurs, et il
        // n'y en a pas — ils n'ont rien en main. On demande donc la position
        // d'après, où les Blancs reprennent la main.
        val white = withContext(Dispatchers.IO) {
            FairyEngine.use(context) { engine ->
                engine.queryPosition("crazyhouse", null, listOf("e2e4", "d7d5", "e4d5", "d8d5"))
            }
        }
        val drops = white!!.legalMoves.filter { it.contains('@') }
        assertTrue("les poses devraient être listées", drops.isNotEmpty())
        assertTrue("une pose s'écrit « P@xx » : ${drops.first()}", drops.all { it.startsWith("P@") })
        // Et la case d'arrivée d'une pose est une case VIDE du plateau.
        val board = chesskit.FenParser.parse(com.chesslab.variants.CrazyhouseFen.boardFen(white.fen))
        assertNotNull("le plateau doit rester lisible par chesskit", board)
        drops.forEach { drop ->
            assertEquals(null, board!!.piece(chesskit.Square(drop.takeLast(2))))
        }
    }

    /**
     * Les Barricades ne sont pas des variantes du moteur : c'est la définition
     * écrite par l'app qui les lui enseigne, via `VariantPath`. Ce test le
     * vérifie SUR LE MOTEUR — si le chargement échouait, Fairy resterait aux
     * échecs ordinaires SANS RIEN DIRE, et la variante se jouerait sans ses
     * murs sans que personne s'en aperçoive.
     */
    @Test fun leMoteurApprendLesBarricades() = runBlocking {
        val query = withContext(Dispatchers.IO) {
            FairyEngine.use(context) { it.queryPosition("barricades", null, emptyList()) }
        }
        assertNotNull("le moteur devrait connaître « barricades »", query)
        val walls = com.chesslab.variants.BarricadesFen.wallSquares(query!!.fen).map { it.notation }.sorted()
        assertEquals("les deux murs sont dans SA position de départ", listOf("d4", "e5"), walls)
        assertTrue("et la partie est jouable", query.legalMoves.isNotEmpty())
    }

    /**
     * La région de mobilité fait son travail : aux Barricades FIXES, un
     * cavalier noir ne peut pas prendre un mur. C'est le moteur qui le
     * refuse, pas l'app.
     */
    @Test fun unMurFixeNeSePrendPas() = runBlocking {
        val fen = "4k3/8/2n5/4W3/3W4/8/8/4K3 b - - 0 1"
        val query = withContext(Dispatchers.IO) {
            FairyEngine.use(context) { it.queryPosition("barricades", fen, emptyList()) }
        }
        assertNotNull(query)
        val moves = query!!.legalMoves
        assertTrue("le cavalier doit pouvoir jouer ailleurs", "c6b4" in moves)
        assertTrue("mais pas prendre le mur d4 : $moves", "c6d4" !in moves)
        assertTrue("ni celui d'e5 : $moves", "c6e5" !in moves)
    }

    /**
     * Aux Barricades ALÉATOIRES, le moteur propose au contraire ces prises —
     * aucune région ne peut suivre des murs qui bougent — et c'est l'app qui
     * les retire. Le test dit les DEUX moitiés : ce que le moteur offre, et ce
     * que l'app en garde.
     */
    @Test fun unMurMobileSePrendraitSansLeFiltreDeLApp() = runBlocking {
        val fen = "4k3/8/2n5/4W3/3W4/8/8/4K3 b - - 0 1"
        val query = withContext(Dispatchers.IO) {
            FairyEngine.use(context) { it.queryPosition("randombarricades", fen, emptyList()) }
        }
        assertNotNull(query)
        val offered = query!!.legalMoves
        assertTrue("le moteur les propose bien : $offered", "c6d4" in offered || "c6e5" in offered)

        val kept = com.chesslab.variants.BarricadesConfiguration.removingWallCaptures(offered, query.fen)
        assertTrue("l'app les retire", "c6d4" !in kept && "c6e5" !in kept)
        assertTrue("et ne retire rien d'autre", "c6b4" in kept)
    }

    /**
     * Un mur BLOQUE une ligne — non par la région de mobilité, qui n'est
     * qu'un masque d'arrivée, mais parce qu'un mur EST une pièce sur
     * l'échiquier du moteur.
     */
    @Test fun unMurArreteUneTour() = runBlocking {
        val fen = "4k3/8/8/4W3/R2W4/8/8/4K3 w - - 0 1"
        val query = withContext(Dispatchers.IO) {
            FairyEngine.use(context) { it.queryPosition("barricades", fen, emptyList()) }
        }
        assertNotNull(query)
        val moves = query!!.legalMoves
        assertTrue("la tour avance jusqu'au mur", "a4b4" in moves && "a4c4" in moves)
        assertTrue("et pas au-delà : $moves", "a4e4" !in moves && "a4h4" !in moves)
    }

    @Test fun stockfishRepondAUneQuestionSimple() = runBlocking {
        val best = withContext(Dispatchers.IO) {
            EngineService.use(context) { e ->
                e.send("position startpos")
                e.search("go depth 8", timeoutMs = 30_000)
            }
        }
        assertNotNull("Stockfish n'a pas répondu", best)
        assertTrue("réponse inattendue : $best", best!!.startsWith("bestmove"))
        assertNotNull("le moteur devrait s'être présenté", EngineService.identity)
    }

    @Test fun fairyArbitreUneVariante() = runBlocking {
        val query = withContext(Dispatchers.IO) {
            FairyEngine.use(context) { it.queryPosition("atomic", null, emptyList()) }
        }
        assertNotNull("Fairy n'a pas répondu", query)
        // Vingt coups légaux au départ, aux échecs comme à l'Atomique.
        assertEquals(20, query!!.legalMoves.size)
        assertTrue("e2e4 devrait être légal : ${query.legalMoves}", "e2e4" in query.legalMoves)
    }

    /**
     * Les deux moteurs, EN MÊME TEMPS. Chacun doit rendre SA réponse : c'est
     * la seule façon de savoir si leurs sorties natives se croisent.
     */
    @Test fun lesDeuxMoteursNeSeMelangentPas() = runBlocking {
        repeat(3) {
            val results = withContext(Dispatchers.IO) {
                listOf(
                    async {
                        EngineService.use(context) { e ->
                            e.send("position startpos moves e2e4 e7e5")
                            e.search("go depth 6", timeoutMs = 30_000)
                        }
                    },
                    async {
                        FairyEngine.use(context) { it.queryPosition("horde", null, emptyList()) }
                    },
                ).awaitAll()
            }
            val best = results[0] as String?
            val query = results[1] as com.chesslab.engine.PositionQuery?

            assertNotNull("Stockfish muet au tour $it", best)
            assertTrue("Stockfish a rendu « $best » — sortie croisée ?", best!!.startsWith("bestmove"))
            assertNotNull("Fairy muet au tour $it", query)
            // La Horde est le témoin : sa position de départ n'a RIEN à voir
            // avec celle des échecs. Une FEN d'échecs classiques ici voudrait
            // dire que la réponse vient de l'autre moteur.
            assertTrue(
                "position d'échecs classiques rendue pour la Horde : ${query!!.fen}",
                query.fen.startsWith("rnbqkbnr/pppppppp/8/1PP2PP1/"),
            )
            // Huit coups, et pas un de plus : tous les pions de la horde sont
            // bloqués par celui qui les précède, sauf ceux des quatre colonnes
            // sans pion en cinquième et les quatre de la cinquième elle-même.
            assertEquals(8, query.legalMoves.size)
        }
    }

    /**
     * Une recherche abandonnée ne doit pas polluer la suivante : c'est la
     * raison d'être du `stop` + attente de `bestmove` dans `search`.
     */
    @Test fun uneRechercheAbandonneeNePolluePasLaSuivante() = runBlocking {
        withContext(Dispatchers.IO) {
            EngineService.use(context) { e ->
                e.send("position startpos")
                // une recherche longue, coupée net par le délai
                e.search("go movetime 20000", timeoutMs = 300)
            }
        }
        val best = withContext(Dispatchers.IO) {
            EngineService.use(context) { e ->
                e.send("position startpos moves e2e4 e7e5 g1f3")
                e.search("go depth 6", timeoutMs = 30_000)
            }
        }
        assertNotNull(best)
        val move = best!!.split(" ").getOrNull(1)
        assertNotNull(move)
        // La réponse doit être un coup NOIR de cette position-ci.
        assertTrue("« $move » ne vient pas de la position demandée", move!!.length in 4..5)
        assertTrue("un coup noir part de la 6e, 7e ou 8e rangée, reçu $move", move[1] in '6'..'8')
    }
}
