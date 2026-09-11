package com.chesslab.help

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.chesslab.ui.Palette

/**
 * L'aide. Pendant réduit de `HelpView.swift`.
 *
 * On y dit ce que l'app FAIT VRAIMENT, y compris quand c'est moins flatteur :
 * ce que le filet corrige, ce que le scanner ne devine pas, ce que les niveaux
 * signifient. Une aide qui ne dit que le bon côté ne sert à personne.
 */
@Composable
fun HelpScreen() {
    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)
    ) {
        sections.forEach { (title, body) ->
            Text(
                title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary, modifier = Modifier.padding(top = 14.dp, bottom = 4.dp),
            )
            Text(
                body, fontSize = 12.sp, color = Palette.textSecondary,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Palette.surface)
                    .padding(12.dp),
            )
        }
        Spacer(Modifier.height(24.dp))
    }
}

private val sections = listOf(
    "Les neuf personnages" to
        "Ce ne sont pas des Stockfish bridés mais Maia-3, un réseau entraîné sur des parties " +
        "HUMAINES : il joue les coups que des joueurs de votre niveau jouent réellement, " +
        "erreurs comprises. Chaque personnage ajoute un style — attaque, échanges, gambits — " +
        "qui COLORE cette distribution sans la remplacer : il n'achète jamais une gaffe que " +
        "Maia jugeait improbable.",

    "Le niveau affiché" to
        "C'est l'échelle humaine de Maia, proche de celle de Lichess. Elle n'est PAS comparable " +
        "à un « niveau Stockfish » : un Stockfish bridé à 1100 bat un Maia réglé à 2200, parce " +
        "qu'il calcule là où l'autre reconnaît. Deux échelles, deux choses.",

    "Le filet de sécurité" to
        "Maia ne calcule pas : il peut rater un mat en deux ou gâcher une finale élémentaire. " +
        "À partir d'un certain niveau, Stockfish reprend la main dans QUATRE cas seulement — " +
        "un mat en un ou deux, une finale à peu de pièces, une répétition en position gagnée, " +
        "et le cas où le modèle ne répond pas. En dessous de ce niveau, rater un mat fait " +
        "partie du personnage.",

    "Les puzzles" to
        "Un seul essai par défaut. Trois invitent à tenter un coup « pour voir », exactement " +
        "l'inverse de ce qu'un puzzle entraîne : on calcule la variante jusqu'au bout AVANT de " +
        "poser la pièce. Le filet à trois essais reste dans les réglages.",

    "Ouvertures et finales" to
        "136 cours, chacun découpé en chapitres. Les commentaires viennent des positions " +
        "elles-mêmes, et les pourcentages sont ceux des parties de club. Les finales suivent " +
        "le même format que les ouvertures : ce sont des positions à comprendre, pas à retenir.",

    "Les variantes" to
        "Elles ne sont pas jouées par les règles des échecs classiques mais ARBITRÉES par un " +
        "moteur qui les connaît : la position et les coups légaux viennent de lui. C'est ce qui " +
        "permet l'Atomique ou l'Antichecs sans réécrire sept jeux de règles.",

    "Le scanner" to
        "Vous posez vous-même les quatre coins du plateau sur la photo. La reconnaissance des " +
        "pièces est automatique ; le TRAIT, les ROQUES et la PRISE EN PASSANT ne se lisent pas " +
        "sur une image, et l'app ne les invente pas — à vous de les corriger.",

    "Ce qui reste hors ligne" to
        "Tout. Aucun compte, aucun réseau, aucune donnée qui sort de l'appareil. Le moteur, les " +
        "puzzles, les cours et les adversaires sont embarqués.",
)
