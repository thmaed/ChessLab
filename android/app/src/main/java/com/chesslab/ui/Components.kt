package com.chesslab.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.sp

/**
 * Les pièces communes de l'identité visuelle, portées de `Theme.swift`.
 *
 * Elles ne servent pas qu'à décorer : ce sont elles qui font qu'un écran
 * ANDROID ressemble au même écran sur iPhone. Chaque valeur — rayon, opacité,
 * taille — vient de la source Swift, pas d'un à-peu-près.
 */

/** Le dégradé d'accent signature (émeraude → sarcelle), en diagonale. */
val accentGradient: Brush
    get() = Brush.linearGradient(listOf(Palette.accent, Palette.accentSecondary))

/** Le dégradé d'une carte : une lumière très légère en haut. */
val cardGradient: Brush
    get() = Brush.verticalGradient(
        listOf(Palette.surfaceElevated.copy(alpha = 0.9f), Palette.surface)
    )

/** Une teinte vers sa version assombrie — le fond des pastilles d'icône. */
fun tintGradient(color: Color): Brush =
    Brush.linearGradient(listOf(color, color.copy(alpha = 0.72f)))

/** Rayon des cartes (18) et des contrôles (14), comme `Theme.cardShape`. */
val CardShape = RoundedCornerShape(18.dp)
val ControlShape = RoundedCornerShape(14.dp)

/**
 * La pastille d'icône colorée : un carré arrondi rempli d'un dégradé de la
 * teinte, avec un liseré lumineux en haut qui lui donne le volume d'une
 * surface bombée, et le glyphe en SOMBRE — pas en blanc — pour qu'il tranche
 * sur la couleur.
 */
@Composable
fun IconBadge(
    icon: ImageVector,
    tint: Color,
    size: Dp = 48.dp,
    enabled: Boolean = true,
) {
    Box(
        Modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.3f))
            .then(
                if (enabled) Modifier.background(tintGradient(tint))
                else Modifier.background(Color.White.copy(alpha = 0.06f))
            )
            .border(
                1.dp,
                Brush.verticalGradient(
                    listOf(Color.White.copy(alpha = 0.38f), Color.White.copy(alpha = 0.02f))
                ),
                RoundedCornerShape(size * 0.3f),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon, contentDescription = null,
            tint = if (enabled) Palette.background else Palette.textTertiary,
            modifier = Modifier.size(size * 0.52f),
        )
    }
}

/**
 * L'intitulé d'une section : un petit trait en dégradé d'accent, puis le titre
 * en capitales espacées. C'est ce qui rythme les écrans longs.
 */
@Composable
fun SectionHeader(title: String, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .size(width = 18.dp, height = 3.dp)
                .clip(CircleShape)
                .background(accentGradient)
        )
        Spacer(Modifier.width(8.dp))
        Text(
            title.uppercase(),
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 0.5.sp,
            color = Palette.textSecondary,
        )
    }
}

/**
 * Le bouton rond de la barre d'outils (Aide, Progression, Réglages).
 *
 * Une couleur par fonction plutôt qu'un gris commun : l'accueil y gagne en
 * gaieté ce qu'il perd en hiérarchie, et les trois restent distincts.
 */
@Composable
fun CircleIconButton(
    icon: ImageVector,
    label: String,
    tint: Color,
    tag: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier
            .size(34.dp)
            .clip(CircleShape)
            .background(tint.copy(alpha = 0.16f))
            .border(1.dp, tint.copy(alpha = 0.5f), CircleShape)
            .clickable(onClick = onClick)
            .testTag(tag),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, label, tint = tint, modifier = Modifier.size(17.dp))
    }
}

/**
 * La bordure d'une carte : la teinte du mode en haut à gauche, le trait neutre
 * en bas à droite. Elle accroche la lumière au lieu d'être un liseré uniforme.
 */
fun Modifier.tintedCardBorder(tint: Color, enabled: Boolean = true, shape: RoundedCornerShape = CardShape) =
    border(
        1.dp,
        Brush.linearGradient(
            listOf(tint.copy(alpha = if (enabled) 0.48f else 0.10f), Palette.stroke)
        ),
        shape,
    )

/** Le liseré neutre des surfaces ordinaires. */
fun Modifier.subtleBorder(shape: RoundedCornerShape = CardShape) =
    border(BorderStroke(1.dp, Palette.stroke), shape)

/**
 * L'en-tête d'une section de réglages : une petite pastille teintée qui porte
 * l'icône, puis le titre en capitales. Pendant de `SettingsSection`.
 */
@Composable
fun SettingsSection(
    title: String,
    icon: ImageVector? = null,
    tint: Color = Palette.accent,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (icon != null) {
                // Teinte pâle et icône colorée — le langage « au repos » des
                // puces — plutôt que la pastille pleine : un en-tête n'est pas
                // un élément actif.
                Box(
                    Modifier
                        .size(22.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(tint.copy(alpha = 0.14f)),
                    contentAlignment = Alignment.Center,
                ) { Icon(icon, null, tint = tint, modifier = Modifier.size(13.dp)) }
            } else {
                Box(Modifier.size(width = 18.dp, height = 3.dp).clip(CircleShape).background(accentGradient))
            }
            Spacer(Modifier.width(8.dp))
            Text(
                title.uppercase(), fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                letterSpacing = 0.4.sp, color = Palette.textSecondary,
            )
        }
        Column(
            Modifier
                .fillMaxWidth()
                .clip(CardShape)
                .background(cardGradient)
                .subtleBorder()
                .padding(14.dp),
            content = content,
        )
    }
}

/**
 * La puce de choix : capsule pleine en dégradé d'accent quand elle est
 * choisie, surface élevée sinon. C'est le contrôle « un parmi n » de l'app.
 */
@Composable
fun ChipButton(
    label: String,
    selected: Boolean,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .clip(CircleShape)
            .then(
                if (selected) Modifier.background(accentGradient)
                else Modifier.background(Palette.surfaceElevated).border(1.dp, Palette.stroke, CircleShape)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(
                icon, null, modifier = Modifier.size(15.dp),
                tint = if (selected) Palette.background else Palette.textPrimary,
            )
            Spacer(Modifier.width(6.dp))
        }
        Text(
            label, fontSize = 14.sp, fontWeight = FontWeight.Medium,
            color = if (selected) Palette.background else Palette.textPrimary,
        )
    }
}

/** Une rangée à bascule : le libellé, puis l'interrupteur. */
@Composable
fun ToggleRow(label: String, checked: Boolean, tag: String = "", onChange: (Boolean) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            // TOUTE la ligne bascule, pas seulement le petit interrupteur :
            // viser un rectangle de 50 dp sur 30 quand la phrase juste à côté
            // ne répond pas est une gêne inutile, et iOS coche la ligne
            // entière.
            .clickable { onChange(!checked) }
            .padding(vertical = 2.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, fontSize = 14.sp, color = Palette.textPrimary, modifier = Modifier.weight(1f))
        Spacer(Modifier.width(12.dp))
        androidx.compose.material3.Switch(
            checked = checked, onCheckedChange = onChange,
            colors = androidx.compose.material3.SwitchDefaults.colors(
                checkedTrackColor = Palette.accent,
                checkedThumbColor = Palette.background,
            ),
        )
    }
}

/**
 * Une carte d'entrée : pastille d'icône, titre, sous-titre, chevron.
 *
 * C'est le langage des écrans de CHOIX (Analyser, Variantes) : chaque ligne
 * annonce où elle mène et ce qu'elle demande, là où une liste de mots obligeait
 * à deviner.
 */
@Composable
fun EntryCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    tint: Color,
    tag: String,
    enabled: Boolean = true,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .clip(CardShape)
            .background(cardGradient)
            .tintedCardBorder(tint, enabled)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(14.dp)
            .testTag(tag),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconBadge(icon, tint, 42.dp, enabled)
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(
                title, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                color = if (enabled) Palette.textPrimary else Palette.textTertiary,
            )
            Text(subtitle, fontSize = 12.sp, color = Palette.textSecondary)
        }
    }
}

/**
 * Un champ de saisie nu, avec sa consigne quand il est vide.
 *
 * `OutlinedTextField` de Material apporte son propre cadre, son étiquette
 * flottante et ses couleurs : dans une barre de recherche déjà dessinée, tout
 * cela se contrarie. Ici, le texte et rien d'autre.
 */
@Composable
fun BasicTextFieldWithPlaceholder(
    value: String,
    placeholder: String,
    modifier: Modifier = Modifier,
    /** Le repère va sur le CHAMP, pas sur la boîte : un test qui vise la boîte
     *  ne trouve pas de quoi prendre le focus. */
    tag: String = "",
    onChange: (String) -> Unit,
) {
    Box(modifier, contentAlignment = Alignment.CenterStart) {
        if (value.isEmpty()) {
            Text(placeholder, fontSize = 14.sp, color = Palette.textTertiary, maxLines = 1)
        }
        androidx.compose.foundation.text.BasicTextField(
            value = value,
            onValueChange = onChange,
            singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(
                color = Palette.textPrimary, fontSize = 14.sp,
            ),
            cursorBrush = androidx.compose.ui.graphics.SolidColor(Palette.accent),
            modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp).testTag(tag),
        )
    }
}
