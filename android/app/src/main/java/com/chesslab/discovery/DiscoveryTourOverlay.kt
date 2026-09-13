package com.chesslab.discovery

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.EaseOut
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateRectAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.ui.Palette
import com.chesslab.ui.accentGradient
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.math.sqrt

// ============================================================================
// Le DESSIN de la visite guidée : le voile percé, l'anneau qui respire, la
// flèche courbe, la carte. Pendant de l'overlay de `DiscoveryTour.swift`.
// Monté à la RACINE (`MainActivity`), par-dessus les écrans ET leurs barres :
// dans un écran, il ne pourrait couvrir que lui-même.
// ============================================================================

/**
 * `[spot: rectangle]`, en pixels de la racine. Les vues écrivent, l'overlay
 * lit ; un contrôle qui quitte la composition retire son ancre — sans quoi
 * une étape viserait un rectangle fantôme sur l'écran suivant.
 */
class DiscoveryAnchors {
    private val bounds = mutableStateMapOf<DiscoverySpot, Rect>()
    operator fun get(spot: DiscoverySpot): Rect? = bounds[spot]
    fun set(spot: DiscoverySpot, rect: Rect) { if (bounds[spot] != rect) bounds[spot] = rect }
    fun remove(spot: DiscoverySpot) { bounds.remove(spot) }
}

val LocalDiscoveryAnchors = staticCompositionLocalOf<DiscoveryAnchors?> { null }
val LocalDiscoveryTour = staticCompositionLocalOf<DiscoveryTourController?> { null }

/**
 * Tague un contrôle comme cible possible de la visite — aucun effet de
 * layout. Quand l'étape courante le vise, il se fait amener à l'écran
 * (`bringIntoView`, qui traverse tous les conteneurs défilants) : les étapes
 * des autres écrans ne défilent rien.
 */
@OptIn(ExperimentalFoundationApi::class)
fun Modifier.discoveryAnchor(spot: DiscoverySpot): Modifier = composed {
    val anchors = LocalDiscoveryAnchors.current ?: return@composed Modifier
    val tour = LocalDiscoveryTour.current
    val requester = remember { BringIntoViewRequester() }
    DisposableEffect(spot, anchors) { onDispose { anchors.remove(spot) } }
    val targeted = tour?.isActive == true && tour.currentStep?.spot == spot
    LaunchedEffect(targeted) {
        // Petit délai : la navigation de l'étape vient parfois d'être
        // appliquée, et l'écran cible n'a pas encore posé ses vues.
        if (targeted) { delay(80); requester.bringIntoView() }
    }
    Modifier
        .bringIntoViewRequester(requester)
        .onGloballyPositioned { anchors.set(spot, it.boundsInRoot()) }
}

/** Le voile, l'anneau, la flèche et la carte de l'étape courante ; rien quand la visite dort. */
@Composable
fun DiscoveryTourOverlay(tour: DiscoveryTourController, anchors: DiscoveryAnchors, modifier: Modifier = Modifier) {
    val step = tour.currentStep ?: return
    val density = LocalDensity.current
    // Les barres système, mesurées ICI : l'overlay couvre tout l'écran, et la
    // carte ne doit mordre ni l'heure ni la barre de navigation.
    val systemBars = WindowInsets.systemBars
    val topInset = with(density) { systemBars.getTop(this).toDp().value }
    val bottomInset = with(density) { systemBars.getBottom(this).toDp().value }

    BoxWithConstraints(modifier.fillMaxSize().testTag("visite")) {
        val screen = Size(maxWidth.value, maxHeight.value)
        // Tout se calcule en dp — la géométrie d'iOS est en points.
        val hole: Rect? = step.spot?.let { anchors[it] }?.let { px ->
            with(density) {
                Rect(px.left.toDp().value - 6f, px.top.toDp().value - 6f, px.right.toDp().value + 6f, px.bottom.toDp().value + 6f)
            }
        }
        // Étape sans trou : le trou animable file vers un point central de
        // taille nulle, pour que la TRANSITION reste un glissement continu.
        val targetHole = hole ?: Rect(Offset(screen.width / 2f, screen.height / 2f), Size.Zero)
        val animatedHole by animateRectAsState(targetHole, tween(450, easing = FastOutSlowInEasing), label = "trou")
        val side = hole?.let { DiscoveryGeometry.side(it, screen, topInset, bottomInset) } ?: DiscoveryGeometry.CardSide.centered
        val arrow = hole?.let { DiscoveryGeometry.arrow(it, screen, topInset, bottomInset) }

        // La flèche se dessine à chaque étape, après un souffle : l'œil
        // arrive sur la cible avant qu'elle ait fini.
        val arrowProgress = remember { Animatable(0f) }
        LaunchedEffect(step.id) {
            arrowProgress.snapTo(0f)
            delay(180)
            arrowProgress.animateTo(1f, tween(550, easing = EaseOut))
        }
        val breath by rememberInfiniteTransition(label = "souffle").animateFloat(
            0f, 1f, infiniteRepeatable(tween(1600, easing = EaseOut), RepeatMode.Restart), label = "anneau",
        )

        Canvas(
            Modifier
                .fillMaxSize()
                // Le voile ENTIER avance la visite : c'est l'affordance que
                // les gens cherchent avant de trouver le bouton.
                .pointerInput(step.id) { detectTapGestures { tour.advance() } }
                .testTag("visite-voile"),
        ) {
            val h = animatedHole
            val hp = Rect(h.left.dp.toPx(), h.top.dp.toPx(), h.right.dp.toPx(), h.bottom.dp.toPx())
            val radius = 14.dp.toPx()
            // UN seul chemin, rempli pair-impair : le rectangle plein écran
            // et le trou arrondi — se compose proprement sur tout fond.
            val veil = Path().apply {
                fillType = PathFillType.EvenOdd
                addRect(Rect(0f, 0f, size.width, size.height))
                addRoundRect(RoundRect(hp, CornerRadius(radius)))
            }
            // 0,68 : assez sombre pour que l'app recule nettement derrière.
            drawPath(veil, Color.Black.copy(alpha = 0.68f))

            if (hole != null && hp.width > 0f) {
                drawRoundRect(
                    brush = accentGradient, topLeft = hp.topLeft, size = hp.size,
                    cornerRadius = CornerRadius(radius), style = Stroke(2.dp.toPx()),
                )
                // L'anneau qui respire : grandit et s'efface, relancé sans fin.
                val scale = 1f + 0.09f * breath
                val w = hp.width * scale
                val hh = hp.height * scale
                drawRoundRect(
                    color = Palette.accent.copy(alpha = 0.55f * (1f - breath)),
                    topLeft = Offset(hp.center.x - w / 2f, hp.center.y - hh / 2f), size = Size(w, hh),
                    cornerRadius = CornerRadius(radius * scale), style = Stroke(2.dp.toPx()),
                )
                arrow?.let { a ->
                    val curve = Path().apply {
                        moveTo(a.startX.dp.toPx(), a.startY.dp.toPx())
                        quadraticBezierTo(a.controlX.dp.toPx(), a.controlY.dp.toPx(), a.endX.dp.toPx(), a.endY.dp.toPx())
                    }
                    val measure = PathMeasure().apply { setPath(curve, false) }
                    val visible = Path()
                    measure.getSegment(0f, measure.length * arrowProgress.value, visible, true)
                    val stroke = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
                    drawPath(visible, Palette.accent, style = stroke)
                    // Tête CALCULÉE : la tangente en t=1 vaut (fin − contrôle),
                    // et les deux barbes sont cette direction tournée de ±28°.
                    if (arrowProgress.value > 0.999f) {
                        val ex = a.endX.dp.toPx()
                        val ey = a.endY.dp.toPx()
                        val tx = ex - a.controlX.dp.toPx()
                        val ty = ey - a.controlY.dp.toPx()
                        val len = max(sqrt(tx * tx + ty * ty), 0.001f)
                        val dx = tx / len
                        val dy = ty / len
                        val barb = 11.dp.toPx()
                        for (degrees in listOf(28f, -28f)) {
                            val angle = degrees * PI.toFloat() / 180f
                            val rx = dx * cos(angle) - dy * sin(angle)
                            val ry = dx * sin(angle) + dy * cos(angle)
                            drawLine(
                                Palette.accent, Offset(ex, ey), Offset(ex - rx * barb, ey - ry * barb),
                                strokeWidth = 2.5.dp.toPx(), cap = StrokeCap.Round,
                            )
                        }
                    }
                }
            }
        }

        // Posée avec du PADDING, pas une position : la carte reste aussi
        // haute que son texte l'exige, et le padding du côté opposé est un
        // garde-fou d'inset.
        val placement: Modifier
        val alignment: Alignment
        when (side) {
            DiscoveryGeometry.CardSide.below -> {
                val gap = DiscoveryGeometry.effectiveGap(screen.height - bottomInset - hole!!.bottom)
                placement = Modifier.padding(top = (hole.bottom + gap).dp, bottom = (bottomInset + 8f).dp)
                alignment = Alignment.TopCenter
            }
            DiscoveryGeometry.CardSide.above -> {
                val gap = DiscoveryGeometry.effectiveGap(hole!!.top - topInset)
                placement = Modifier.padding(bottom = (screen.height - hole.top + gap).dp, top = (topInset + 8f).dp)
                alignment = Alignment.BottomCenter
            }
            DiscoveryGeometry.CardSide.centered -> {
                placement = Modifier.padding(top = (topInset + 8f).dp, bottom = (bottomInset + 8f).dp)
                alignment = Alignment.Center
            }
        }
        val shift = with(density) { 14.dp.roundToPx() }
        Box(
            Modifier.fillMaxSize().then(placement).padding(horizontal = 20.dp),
            contentAlignment = alignment,
        ) {
            // La carte se REJOUE à chaque étape : entrée décalée du côté d'où
            // l'on vient (±14 dp) + opacité, sortie en opacité seule.
            AnimatedContent(
                targetState = step,
                transitionSpec = {
                    (fadeIn(tween(220)) + slideInVertically(tween(220)) {
                        if (side == DiscoveryGeometry.CardSide.above) -shift else shift
                    }) togetherWith fadeOut(tween(160))
                },
                label = "carte",
            ) { shown ->
                DiscoveryCard(
                    step = shown,
                    stepNumber = shown.id + 1,
                    stepCount = tour.steps.size,
                    onBack = tour::goBack, onSkip = tour::skip, onNext = tour::advance,
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DiscoveryCard(
    step: DiscoveryStep,
    stepNumber: Int,
    stepCount: Int,
    onBack: () -> Unit,
    onSkip: () -> Unit,
    onNext: () -> Unit,
) {
    val shape = RoundedCornerShape(18.dp)
    Column(
        Modifier
            .widthIn(max = 360.dp)
            .shadow(24.dp, shape, ambientColor = Color.Black.copy(alpha = 0.55f), spotColor = Color.Black.copy(alpha = 0.55f))
            .clip(shape)
            // Fond ÉMERAUDE sombre, pas la surface des cartes de l'app : sur un
            // écran fait des mêmes gris, la carte se confondait avec le contenu
            // qu'elle commente. Tout ce qui est vert-menthe EST la visite.
            .background(Brush.verticalGradient(listOf(Color(0.098f, 0.200f, 0.160f), Color(0.078f, 0.125f, 0.115f))))
            .border(1.5.dp, accentGradient, shape)
            // La carte n'avance pas la visite : un tap dedans reste un tap dedans.
            .pointerInput(Unit) { detectTapGestures { } }
            .padding(16.dp)
            .testTag("visite-carte"),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Une BARRE, pas des points : le nom de section dit OÙ l'on est —
        // trois courtes visites plutôt qu'une longue.
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(step.section).uppercase(), fontSize = 10.sp,
                    fontWeight = FontWeight.Bold, letterSpacing = 0.8.sp, color = Palette.accent,
                )
                Spacer(Modifier.weight(1f))
                Text("$stepNumber/$stepCount", fontSize = 10.sp, color = Palette.textTertiary)
            }
            Box(Modifier.fillMaxWidth().height(3.dp).clip(CircleShape).background(Palette.surfaceElevated)) {
                Box(Modifier.fillMaxWidth(stepNumber.toFloat() / stepCount).fillMaxHeight().background(accentGradient))
            }
        }

        Text(
            if (step.titleArg != null) stringResource(step.title, step.titleArg) else stringResource(step.title),
            fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary,
        )

        // Le texte défile si l'écran est petit ; les boutons, eux, restent —
        // « Suivant » est le seul contrôle qui ne doit JAMAIS devenir
        // inatteignable.
        Column(
            Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(stringResource(step.body), fontSize = 13.sp, color = Palette.textSecondary)
            if (step.chips.isNotEmpty()) {
                // Un flux qui REPLIE : un défilement horizontal cacherait la
                // moitié des options derrière un geste que personne ne fait.
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    step.chips.forEach { chip ->
                        Row(
                            Modifier
                                .clip(CircleShape)
                                .background(Palette.surfaceElevated)
                                .border(1.dp, chip.tint.copy(alpha = 0.45f), CircleShape)
                                .padding(horizontal = 8.dp, vertical = 5.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            Icon(chip.icon, null, tint = chip.tint, modifier = Modifier.size(13.dp))
                            Text(
                                stringResource(chip.label), fontSize = 10.sp, fontWeight = FontWeight.Medium,
                                color = Palette.textPrimary, maxLines = 1, overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                }
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            // Retour dès la deuxième étape.
            if (stepNumber > 1) {
                Box(
                    Modifier
                        .size(34.dp)
                        .clip(CircleShape)
                        .background(Palette.surfaceElevated)
                        .clickable(onClick = onBack)
                        .testTag("visite-retour"),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.discovery_previous),
                        tint = Palette.textSecondary, modifier = Modifier.size(20.dp),
                    )
                }
            }
            // Passer est DANS la carte, et AMBRE : gris, il se lirait comme
            // une légende ; en accent, comme un second « continuer ». La seule
            // chose qu'une visite ne doit jamais faire, c'est paraître
            // inéluctable.
            Text(
                stringResource(R.string.discovery_skip), fontSize = 13.sp, fontWeight = FontWeight.Medium,
                color = Palette.warning,
                modifier = Modifier.clip(CircleShape).clickable(onClick = onSkip).padding(horizontal = 8.dp, vertical = 8.dp).testTag("visite-passer"),
            )
            Spacer(Modifier.weight(1f))
            Text(
                stringResource(if (stepNumber == stepCount) R.string.discovery_done else R.string.discovery_next),
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Palette.background,
                modifier = Modifier
                    .clip(CircleShape)
                    .background(accentGradient)
                    .clickable(onClick = onNext)
                    .padding(horizontal = 18.dp, vertical = 9.dp)
                    .testTag("visite-suivant"),
            )
        }
    }
}
