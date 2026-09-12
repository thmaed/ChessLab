package com.chesslab.play

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.R
import com.chesslab.maia.OpponentGallery
import com.chesslab.maia.OpponentProfile
import com.chesslab.maia.OpponentTint
import com.chesslab.ui.ControlShape
import com.chesslab.ui.Palette

/**
 * Les couleurs des personnages : celle de chacun EST celle de son avatar,
 * mesurée sur la planche. Portées d'`OpponentTintResolver` — une teinte
 * approchée ferait jurer le liseré contre l'illustration.
 */
fun tintColor(tint: OpponentTint): Color = when (tint) {
    OpponentTint.maiaBlue -> Color(0.200f, 0.435f, 0.675f)
    OpponentTint.red -> Color(0.882f, 0.141f, 0.125f)
    OpponentTint.deepBlue -> Color(0.016f, 0.373f, 0.718f)
    OpponentTint.green -> Color(0.192f, 0.518f, 0.247f)
    OpponentTint.purple -> Color(0.412f, 0.216f, 0.631f)
    OpponentTint.orange -> Color(0.976f, 0.604f, 0.086f)
    OpponentTint.cyan -> Color(0.004f, 0.667f, 0.753f)
    OpponentTint.slate -> Color(0.263f, 0.322f, 0.404f)
    OpponentTint.yellow -> Color(0.996f, 0.765f, 0.086f)
}

/** L'illustration d'un personnage. Elle porte déjà son disque de couleur. */
@Composable
fun OpponentAvatar(profile: OpponentProfile, size: androidx.compose.ui.unit.Dp = 44.dp, emphasized: Boolean = false) {
    val context = LocalContext.current
    val id = remember(profile.id) {
        context.resources.getIdentifier("avatar_${profile.id}", "drawable", context.packageName)
    }
    val tint = tintColor(profile.tint)
    if (id == 0) {
        // Pas d'illustration : un disque de sa couleur avec son initiale.
        Box(
            Modifier.size(size).clip(CircleShape).background(tint),
            contentAlignment = Alignment.Center,
        ) {
            Text(profile.firstName.take(1), color = Color.White, fontWeight = FontWeight.Bold, fontSize = size.value.sp * 0.4f)
        }
        return
    }
    Image(
        painterResource(id), null,
        contentScale = ContentScale.Fit,
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .border(
                if (emphasized) 2.dp else 1.dp,
                if (emphasized) Color.White.copy(alpha = 0.85f) else tint.copy(alpha = 0.5f),
                CircleShape,
            ),
    )
}

/**
 * La galerie : une grille de vignettes, puis la fiche du personnage choisi.
 * Pendant d'`OpponentGalleryView`.
 */
@Composable
fun OpponentGalleryGrid(selectedId: String, onSelect: (OpponentProfile) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        // Trois colonnes sur un téléphone, comme sur iPhone : la grille
        // s'élargit d'elle-même sur tablette.
        val rows = OpponentGallery.all.chunked(3)
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { profile ->
                    Box(Modifier.weight(1f)) {
                        OpponentTile(profile, profile.id == selectedId) { onSelect(profile) }
                    }
                }
                repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
        OpponentGallery.byId(selectedId)?.let { OpponentProfileCard(it) }
    }
}

/** Une vignette : illustration, prénom, surnom. Choisie, elle prend sa couleur. */
@Composable
private fun OpponentTile(profile: OpponentProfile, selected: Boolean, onClick: () -> Unit) {
    val tint = tintColor(profile.tint)
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(if (selected) tint.copy(alpha = 0.18f) else Palette.surfaceElevated)
            .border(
                if (selected) 2.dp else 1.dp,
                if (selected) tint else Palette.stroke,
                RoundedCornerShape(14.dp),
            )
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp, horizontal = 4.dp)
            .testTag("adversaire-${profile.id}"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        OpponentAvatar(profile, 54.dp, emphasized = selected)
        Text(
            profile.firstName, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
            color = Palette.textPrimary, maxLines = 1,
        )
        Text(
            stringResource(profile.nicknameRes), fontSize = 11.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (selected) tint else Palette.textTertiary,
            maxLines = 1, overflow = TextOverflow.Ellipsis,
        )
    }
}

/** La fiche : grande illustration, prénom et surnom, étiquettes, sa phrase. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OpponentProfileCard(profile: OpponentProfile, modifier: Modifier = Modifier) {
    val tint = tintColor(profile.tint)
    Row(
        modifier
            .fillMaxWidth()
            .clip(ControlShape)
            .background(
                Brush.linearGradient(listOf(tint.copy(alpha = 0.22f), Palette.surfaceElevated))
            )
            .border(1.dp, tint.copy(alpha = 0.35f), ControlShape)
            .padding(14.dp)
            .testTag("fiche-${profile.id}"),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        OpponentAvatar(profile, 84.dp, emphasized = true)
        Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(profile.firstName, fontSize = 19.sp, fontWeight = FontWeight.Bold, color = Palette.textPrimary)
                Text(
                    stringResource(R.string.opponent_nickname_quoted, stringResource(profile.nicknameRes)),
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = tint,
                )
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                profile.tagRes.forEach { tag ->
                    Text(
                        stringResource(tag), fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = tint,
                        modifier = Modifier
                            .clip(CircleShape)
                            .background(tint.copy(alpha = 0.14f))
                            .border(1.dp, tint.copy(alpha = 0.35f), CircleShape)
                            .padding(horizontal = 8.dp, vertical = 3.dp),
                    )
                }
            }
            Text(stringResource(profile.taglineRes), fontSize = 13.sp, color = Palette.textSecondary)
        }
    }
}
