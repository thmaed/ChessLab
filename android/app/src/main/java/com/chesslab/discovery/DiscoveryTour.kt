package com.chesslab.discovery

import android.content.Context
import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Looks3
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.SportsScore
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material.icons.filled.Whatshot
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Contrast
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.chesslab.R
import com.chesslab.ui.Palette
import com.chesslab.variants.VariantCatalog
import kotlin.math.max
import kotlin.math.min

// ============================================================================
// La VISITE GUIDÉE en coach marks : un voile sombre percé d'un trou au-dessus
// d'un vrai contrôle, une flèche courbe qui pointe dedans, une carte qui dit
// à quoi il sert. Pendant de `DiscoveryTour.swift`.
//
// Ce fichier tient la PARTIE PURE — cibles, étapes, contrôleur, géométrie,
// mémoire — testable sur la JVM. Le dessin vit dans `DiscoveryTourOverlay.kt`.
// Les décisions de géométrie sont commentées avec leur raison : chacune est
// le contre-exemple d'un bug déjà payé côté iOS.
// ============================================================================

/**
 * Les contrôles qu'une étape peut viser. JAMAIS de coordonnées en dur : les
 * vues se taguent elles-mêmes (`Modifier.discoveryAnchor`), la racine
 * résout. Un contrôle qui bouge emmène son trou ; un contrôle absent de
 * l'état courant perd simplement sa flèche (carte centrée).
 */
enum class DiscoverySpot {
    playTile,        // tuile « Contre l'ordinateur » (accueil)
    strengthSlider,  // section « Adversaire » : le curseur de force
    aidToggles,      // section « Aides » : indices + barre d'éval
    analysisLibrary, // carte « Bibliothèque » (entrée d'Analyser)
    recentGames,     // section « Parties récentes » (accueil)
    variantsTile,    // tuile « Variantes »
    puzzlesTile,     // tuile « Puzzles »
    helpButton,      // le « ? » de l'accueil — taguable ici, contrairement
                     // au ToolbarItem UIKit d'iPhone : l'étape 11 a sa flèche
}

/**
 * Où une étape emmène la navigation. La visite PILOTE la navigation : le
 * changement d'écran qui se joue sous les yeux est l'explication.
 */
enum class DiscoveryDestination { home, newGame, analysisEntry, openings }

/** Une capsule qui dessine, avec le VRAI symbole et le VRAI nom, ce qui vit un écran plus loin. */
data class DiscoveryChip(val icon: ImageVector, @StringRes val label: Int, val tint: Color)

data class DiscoveryStep(
    val id: Int,
    @StringRes val section: Int,
    /**
     * `null` = carte centrée sans flèche : la présentation HONNÊTE de ce qui
     * n'est pas sur cet écran — pas une flèche manquante.
     */
    val spot: DiscoverySpot?,
    val destination: DiscoveryDestination,
    @StringRes val title: Int,
    @StringRes val body: Int,
    val chips: List<DiscoveryChip> = emptyList(),
    /**
     * L'argument du titre quand il en a un : le NOMBRE de variantes, compté
     * sur le catalogue plutôt qu'écrit en toutes lettres comme sur iOS
     * (« Douze ») — Android n'en porte pas encore douze, et une visite qui
     * annonce ce qui n'existe pas encore est une visite qui ment.
     */
    val titleArg: Int? = null,
)

/**
 * Le contrôleur : l'état d'avancement, et rien d'autre. [onSeen] pose
 * l'empreinte « vue » à la fin — injectée pour que la JVM puisse le tester.
 */
class DiscoveryTourController(private val onSeen: () -> Unit = {}) {
    var isActive by mutableStateOf(false)
        private set
    var currentStepIndex by mutableStateOf(0)
        private set

    val steps: List<DiscoveryStep> = buildSteps()

    val currentStep: DiscoveryStep?
        get() = if (isActive && currentStepIndex in steps.indices) steps[currentStepIndex] else null

    fun start(at: Int = 0) {
        currentStepIndex = at.coerceIn(0, steps.size - 1)
        isActive = true
    }

    fun advance() {
        if (currentStepIndex + 1 < steps.size) currentStepIndex += 1 else finish()
    }

    fun goBack() {
        if (currentStepIndex > 0) currentStepIndex -= 1
    }

    /**
     * Passer COMPTE comme vue (la visite reste disponible depuis l'Aide) :
     * re-proposer une visite déjà refusée est la définition du harcèlement.
     */
    fun skip() = finish()

    private fun finish() {
        isActive = false
        onSeen()
    }

    private fun buildSteps(): List<DiscoveryStep> {
        val playControls = listOf(
            DiscoveryChip(Icons.Default.Lightbulb, R.string.discovery_chip_hint, Palette.accent),
            DiscoveryChip(Icons.Default.Contrast, R.string.discovery_chip_draw, Palette.info),
            DiscoveryChip(Icons.AutoMirrored.Filled.List, R.string.discovery_chip_moves, Palette.teal),
            DiscoveryChip(Icons.AutoMirrored.Filled.ArrowBack, R.string.discovery_chip_back, Palette.violet),
            DiscoveryChip(Icons.Default.Flag, R.string.discovery_chip_resign, Palette.warning),
        )
        // Les variantes viennent du CATALOGUE : la visite dit ce que l'app
        // sait jouer, et suivra chaque variante ajoutée sans qu'on y pense.
        val variantChips = VariantCatalog.all.map { v ->
            DiscoveryChip(variantIcon(v.id), v.titleRes, variantTint(v.id))
        }
        val trainingChips = listOf(
            DiscoveryChip(Icons.Default.Extension, R.string.route_puzzles, Palette.violet),
            DiscoveryChip(Icons.Default.MenuBook, R.string.route_openings, Palette.warning),
            DiscoveryChip(Icons.Default.EmojiEvents, R.string.route_endgames, Palette.gold),
        )
        val play = R.string.discovery_section_play
        val understand = R.string.discovery_section_understand
        val explore = R.string.discovery_section_explore
        return listOf(
            // ---- JOUER : d'abord ce que l'utilisateur s'apprête à toucher.
            DiscoveryStep(0, play, DiscoverySpot.playTile, DiscoveryDestination.home,
                R.string.discovery_0_title, R.string.discovery_0_body),
            DiscoveryStep(1, play, DiscoverySpot.strengthSlider, DiscoveryDestination.newGame,
                R.string.discovery_1_title, R.string.discovery_1_body),
            DiscoveryStep(2, play, DiscoverySpot.aidToggles, DiscoveryDestination.newGame,
                R.string.discovery_2_title, R.string.discovery_2_body),
            // Sans cible : les contrôles décrits vivent UN ÉCRAN PLUS LOIN —
            // c'est le cas d'usage exact des chips.
            DiscoveryStep(3, play, null, DiscoveryDestination.newGame,
                R.string.discovery_3_title, R.string.discovery_3_body, chips = playControls),
            // ---- COMPRENDRE : les affichages, ensuite.
            DiscoveryStep(4, understand, DiscoverySpot.analysisLibrary, DiscoveryDestination.analysisEntry,
                R.string.discovery_4_title, R.string.discovery_4_body),
            DiscoveryStep(5, understand, DiscoverySpot.recentGames, DiscoveryDestination.home,
                R.string.discovery_5_title, R.string.discovery_5_body),
            DiscoveryStep(6, understand, null, DiscoveryDestination.home,
                R.string.discovery_6_title, R.string.discovery_6_body),
            // ---- EXPLORER : les autres écrans, puis le « ? » qui ramène tout.
            DiscoveryStep(7, explore, null, DiscoveryDestination.openings,
                R.string.discovery_7_title, R.string.discovery_7_body),
            DiscoveryStep(8, explore, DiscoverySpot.variantsTile, DiscoveryDestination.home,
                R.string.discovery_8_title, R.string.discovery_8_body, chips = variantChips,
                titleArg = variantChips.size),
            DiscoveryStep(9, explore, DiscoverySpot.puzzlesTile, DiscoveryDestination.home,
                R.string.discovery_9_title, R.string.discovery_9_body, chips = trainingChips),
            DiscoveryStep(10, explore, DiscoverySpot.helpButton, DiscoveryDestination.home,
                R.string.discovery_10_title, R.string.discovery_10_body),
        )
    }

    private fun variantIcon(id: String): ImageVector = when (id) {
        "chess960" -> Icons.Default.Casino
        "kingofthehill" -> Icons.Default.Terrain
        "3check" -> Icons.Default.Looks3
        "horde" -> Icons.Default.Groups
        "racingkings" -> Icons.Default.SportsScore
        "atomic" -> Icons.Default.Whatshot
        else -> Icons.Default.SwapVert
    }

    private fun variantTint(id: String): Color = when (id) {
        "chess960" -> Palette.violet
        "kingofthehill" -> Palette.warning
        "3check" -> Palette.teal
        "horde" -> Palette.gold
        "racingkings" -> Palette.info
        "atomic" -> Palette.danger
        else -> Palette.rose
    }
}

/**
 * « Déjà vue » : l'EMPREINTE de l'installation, pas un booléen.
 *
 * iOS stocke la date de création du conteneur Documents, refaite à chaque
 * installation — parce qu'un booléen voyage dans les sauvegardes et
 * arriverait déjà posé sur un appareil vierge. Le pendant Android est
 * `firstInstallTime` : neuf à chaque installation, inchangé par une mise à
 * jour. La promesse est la même : une nouvelle installation montre la
 * visite, à chaque fois ; une mise à jour reste silencieuse.
 */
object DiscoveryTourMemory {
    private const val PREFS = "discovery"
    private const val KEY = "discoveryTourSeenInstallStamp"

    fun installStamp(context: Context): Long? = runCatching {
        context.packageManager.getPackageInfo(context.packageName, 0).firstInstallTime
    }.getOrNull()

    fun shouldOffer(context: Context): Boolean {
        val stamp = installStamp(context) ?: return false
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(KEY, -1L) != stamp
    }

    fun markSeen(context: Context) {
        val stamp = installStamp(context) ?: return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(KEY, stamp).apply()
    }
}

/**
 * Les règles de placement, en fonctions pures et en dp : chacune est le
 * contre-exemple d'un bug déjà payé, et un test unitaire est la seule
 * mémoire qui survive aux relectures.
 */
object DiscoveryGeometry {
    enum class CardSide {
        below, above,
        /** Aucun côté ne peut loger la carte : centrée par-dessus, sans flèche. */
        centered,
    }

    /** Réserve de hauteur de carte : texte + chips + boutons aux tailles ordinaires. */
    const val cardReserve = 250f

    /**
     * Le côté de la carte est celui qui a le PLUS de place, mesuré DES DEUX
     * CÔTÉS et NET des barres système : `(bas sûr − trou.bottom)` contre
     * `(trou.top − haut sûr)`. La règle naïve « le trou est-il dans la moitié
     * haute ? » échoue sur une cible haute ET grande ; la place mesurée sans
     * les insets envoyait la carte sous la barre d'état.
     */
    fun side(hole: Rect, screen: Size, topInset: Float, bottomInset: Float): CardSide {
        val below = screen.height - bottomInset - hole.bottom
        val above = hole.top - topInset
        if (max(below, above) < cardReserve) return CardSide.centered
        return if (below >= above) CardSide.below else CardSide.above
    }

    /**
     * La flèche cède sa longueur AVANT que la carte cède sa hauteur : une
     * carte rognée est un bug, une flèche courte n'en est pas un. Plancher à
     * 22 dp pour que la carte ne COLLE jamais au trou.
     */
    fun effectiveGap(available: Float): Float = max(22f, min(72f, available - cardReserve))

    /**
     * Le bow s'incline à l'OPPOSÉ du bord le plus proche. Seuil décentré
     * (0,55) : une cible pile au centre penche à droite.
     */
    fun bowSign(holeMidX: Float, screenWidth: Float): Float = if (holeMidX > screenWidth * 0.55f) -1f else 1f

    data class Arrow(val startX: Float, val startY: Float, val controlX: Float, val controlY: Float, val endX: Float, val endY: Float)

    /**
     * La flèche, en dp, du bord de la carte au bord du trou — ou `null` quand
     * la carte est centrée (rien à relier) ou que le gap est trop court pour
     * se lire comme une flèche.
     */
    fun arrow(hole: Rect, screen: Size, topInset: Float, bottomInset: Float): Arrow? {
        val side = side(hole, screen, topInset, bottomInset)
        if (side == CardSide.centered) return null
        val below = side == CardSide.below
        val available = if (below) screen.height - bottomInset - hole.bottom else hole.top - topInset
        val gap = effectiveGap(available)
        if (gap <= 30f) return null
        val bow = bowSign(hole.center.x, screen.width)
        val endY = if (below) hole.bottom + 7f else hole.top - 7f
        val startY = if (below) hole.bottom + gap - 8f else hole.top - gap + 8f
        val endX = hole.center.x + bow * 10f
        val startX = (hole.center.x + bow * 54f).coerceIn(24f, screen.width - 24f)
        val midX = (startX + endX) / 2f
        val midY = (startY + endY) / 2f
        return Arrow(startX, startY, midX + bow * 26f, midY, endX, endY)
    }
}
