package com.chesslab.scanner

import android.content.Intent
import android.net.Uri
import androidx.core.content.IntentCompat

/**
 * L'image qu'une autre app (Photos, Fichiers, un navigateur…) envoie à ChessLab
 * par « Partager ».
 *
 * Pendant de l'extension de partage iOS (`ShareExtension/`) : depuis la galerie,
 * un appui sur Partager › ChessLab ouvre le scanner sur cette image, sans
 * repasser par le sélecteur.
 *
 * Seule une image est acceptée. Le droit de lecture que l'app d'origine accorde
 * vaut pour la vie de l'activité : l'image est lue tout de suite, jamais gardée
 * pour plus tard.
 */
object SharedImage {

    /** L'URI de l'image reçue, ou `null` si l'intent n'en porte pas (lancement ordinaire, texte partagé…). */
    fun from(intent: Intent?): Uri? {
        if (intent?.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("image/") != true) return null
        return IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
    }
}
