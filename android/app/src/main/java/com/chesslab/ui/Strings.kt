package com.chesslab.ui

import android.app.Application
import androidx.annotation.PluralsRes
import androidx.annotation.StringRes
import androidx.lifecycle.AndroidViewModel

/**
 * Le raccourci vers les textes, pour les modèles de vue.
 *
 * `stringResource` est réservé aux composables ; un modèle de vue passe par le
 * contexte. Comme tous les nôtres sont des [AndroidViewModel], une extension
 * suffit — et `s(R.string.x)` reste assez court pour ne pas alourdir la
 * lecture des états.
 */
fun AndroidViewModel.s(@StringRes id: Int): String =
    getApplication<Application>().getString(id)

fun AndroidViewModel.s(@StringRes id: Int, vararg args: Any): String =
    getApplication<Application>().getString(id, *args)

/**
 * Les textes qui dépendent d'un nombre.
 *
 * « 1 essai » contre « 3 essais » n'est pas une affaire de `if` : le français
 * compte 0 comme un singulier, l'anglais non, et d'autres langues ont d'autres
 * catégories encore. Android le sait ; on le laisse faire.
 */
fun AndroidViewModel.q(@PluralsRes id: Int, count: Int, vararg args: Any): String =
    getApplication<Application>().resources.getQuantityString(id, count, *args)
