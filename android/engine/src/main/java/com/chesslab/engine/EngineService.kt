package com.chesslab.engine

import android.app.ActivityManager
import android.content.Context
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Le moteur, partagé par toute l'app.
 *
 * Stockfish n'accepte qu'UNE instance par process — c'est une contrainte de
 * son état global, pas un choix. Côté iOS, l'ignorer avait coûté cher : deux
 * écrans démarraient chacun le leur, le second échouait en silence et
 * attendait un `uciok` qui n'arrivait jamais, pendant que ses commandes
 * polluaient le flux de l'autre.
 *
 * D'où ce service : un seul moteur, démarré à la première demande, et un
 * verrou qui garantit qu'un écran a le moteur pour lui seul le temps de sa
 * question.
 */
object EngineService {

    private val mutex = Mutex()
    private var engine: StockfishEngine? = null
    private var failed = false

    /** L'identité annoncée par le moteur, une fois démarré. */
    var identity: String? = null
        private set

    val threads: Int
        get() = (Runtime.getRuntime().availableProcessors() - 1).coerceIn(1, 4)

    /**
     * La taille de la table de transposition, en mégaoctets.
     *
     * **64 Mo était un chiffre de bureau.** Une recherche de 300 000 nœuds —
     * le budget de la classification — ne visite pas assez de positions pour
     * remplir le quart d'une table pareille ; le reste ne sert à rien et se
     * paie comptant sur un téléphone. Mesuré sur un Galaxy A16 (4 Go) :
     * ChessLab montait à 582 Mo en jeu et le système l'évinçait dès qu'on
     * passait à une autre app.
     *
     * La table se dimensionne donc sur ce que l'appareil peut donner, et non
     * sur ce qu'un moteur d'échecs aimerait avoir.
     */
    private fun hashMbFor(context: Context): Int {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        if (am?.isLowRamDevice == true) return 8
        // `memoryClass` est le tas Java que l'appareil concède à une app : un
        // bon indicateur de sa générosité générale.
        return when ((am?.memoryClass ?: 128)) {
            in 0..127 -> 8
            in 128..255 -> 16
            else -> 32
        }
    }

    /** Ce que la table occupe quand on veut qu'elle ne coûte presque rien. */
    private const val DORMANT_HASH_MB = 1

    /** La taille voulue quand on joue ; 0 tant que le moteur n'a pas démarré. */
    private var fullHashMb = 0

    /** La taille RÉELLEMENT posée sur le moteur. */
    private var currentHashMb = 0

    /**
     * Donne le moteur à [block], seul. Rend `null` si le moteur n'a pas pu
     * démarrer — l'appelant doit alors le dire à l'utilisateur plutôt que
     * d'attendre.
     */
    suspend fun <T> use(context: Context, block: suspend (StockfishEngine) -> T): T? =
        mutex.withLock {
            val e = start(context) ?: return@withLock null
            // La table a pu être rendue au système pendant qu'on était en
            // arrière-plan : on la reprend avant de servir l'appelant.
            if (currentHashMb != fullHashMb) {
                e.send("setoption name Hash value $fullHashMb")
                currentHashMb = fullHashMb
            }
            block(e)
        }

    /**
     * Rend au système la mémoire de la table de transposition.
     *
     * Appelée quand l'app passe en arrière-plan. Le moteur n'est PAS arrêté :
     * Stockfish n'en accepte qu'un par process, et un arrêt borné peut laisser
     * un fil détaché qui empêche le redémarrage — on a déjà payé ce prix
     * ailleurs. Réduire la table donne l'essentiel du gain sans ce risque, et
     * [use] la reprend toute seule au retour.
     */
    fun releaseMemory() {
        val e = engine
        if (e != null && currentHashMb != DORMANT_HASH_MB) {
            // Sans verrou : `setoption` arrive dans la file du moteur et sera
            // lu quand il sera au repos. Prendre le verrou ici bloquerait le
            // fil principal, d'où vient `onTrimMemory`.
            e.send("setoption name Hash value $DORMANT_HASH_MB")
            currentHashMb = DORMANT_HASH_MB
        }
    }

    /**
     * Rend au système les pages que l'allocateur garde en réserve.
     *
     * À appeler APRÈS avoir relâché ce qui devait l'être : libérer ne suffit
     * pas, l'allocateur conserve les pages pour la prochaine demande et le
     * tueur de processus, lui, les compte toujours.
     */
    fun purgeNativeMemory() {
        if (engine != null) runCatching { Stockfish.nativePurge() }
    }

    /**
     * Démarre le moteur, une fois pour toutes.
     *
     * **Le démarrage ne s'abandonne PAS à mi-chemin.** Il est entier ou pas du
     * tout, d'où le `NonCancellable` : quitter l'écran pendant la poignée de
     * main annulait la tâche entre `e.start()` (qui a lancé le moteur natif) et
     * l'affectation d'`engine`. Le moteur restait alors vivant SANS
     * propriétaire — et Stockfish n'en accepte qu'un par process, si bien que
     * toute demande suivante se voyait refuser, `failed` passait à vrai, et
     * l'app annonçait « moteur indisponible » pour le reste de la session.
     * Trouvé en analysant une partie juste après son chargement.
     */
    private suspend fun start(context: Context): StockfishEngine? = withContext(NonCancellable) {
        engine?.let { return@withContext it }
        if (failed) return@withContext null

        val app = context.applicationContext
        val assets = app.assets
        val nets = assets.list("")!!.filter { it.endsWith(".nnue") }
        val path = StockfishEngine.prepare(nets, app.filesDir) { assets.open(it) }

        val e = StockfishEngine(path)
        if (!e.start()) { failed = true; return@withContext null }
        fullHashMb = hashMbFor(app)
        currentHashMb = fullHashMb
        identity = e.handshake(threads, hashMb = fullHashMb)
        if (identity == null) {
            // Le moteur natif TOURNE : le laisser en plan condamnerait le
            // process, puisqu'il n'en accepte qu'un.
            e.stop()
            failed = true
            return@withContext null
        }

        engine = e
        e
    }
}
