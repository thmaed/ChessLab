package com.chesslab

import android.app.Application
import android.content.ComponentCallbacks2
import com.chesslab.engine.EngineService
import com.chesslab.maia.MaiaModel
import com.chesslab.settings.SettingsStore

class ChessLabApp : Application() {
    override fun onCreate() {
        super.onCreate()
        SettingsStore.start(this)
        // Trouver le vibreur coûte un peu : on le fait une fois, ici, pour que
        // le premier coup ne soit pas plus lent que les suivants.
        com.chesslab.sound.Haptics.prepare(this)
        // Les répertoires personnels : leur dossier, relu une fois.
        com.chesslab.courses.UserOpeningStore.attach(this)
        // Les Barricades ne sont pas des variantes du moteur : c'est cette
        // définition qui les lui enseigne, au premier démarrage de Fairy.
        com.chesslab.engine.FairyEngine.variantDefinition =
            com.chesslab.variants.BarricadesConfiguration.configurationText
    }

    /**
     * Rend la mémoire quand on quitte l'app des yeux.
     *
     * **Pourquoi c'est nécessaire.** Un moteur d'échecs et un réseau de
     * neurones coûtent cher : mesuré sur un Galaxy A16 (4 Go), ChessLab occupe
     * 582 Mo en pleine partie — 320 Mo pour Stockfish (réseaux NNUE et table
     * de transposition), 170 Mo pour la session ONNX de Maia. Tant qu'on joue,
     * c'est légitime. Une fois l'app en arrière-plan, c'est la première chose
     * qu'Android évince : on passe une minute dans une autre app, on revient,
     * la partie a disparu. C'est exactement ce qui est arrivé en essai —
     * `lmkd: Reclaim 'com.chesslab', oom_score_adj 900, to free 243628kB`.
     *
     * On rend donc ce qui se reprend tout seul : la table de transposition
     * (reprise au prochain appel du moteur) et la session de Maia (rouverte au
     * prochain coup). Ni l'une ni l'autre ne porte d'état de partie — la
     * position, elle, est déjà sauvegardée ailleurs.
     *
     * `TRIM_MEMORY_UI_HIDDEN` suffit : c'est le signal « plus personne ne
     * regarde », et c'est justement là que l'app devient une cible. Attendre
     * les niveaux de détresse serait attendre d'être déjà en train de perdre.
     */
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= TRIM_MEMORY_UI_HIDDEN) {
            EngineService.releaseMemory()
            MaiaModel.releaseShared()
            // Et on demande au système de REPRENDRE les pages : sans cette
            // dernière étape, tout ce qui précède ne fait que rendre la
            // mémoire à l'allocateur, qui la garde.
            EngineService.purgeNativeMemory()
        }
    }

    private companion object {
        /** Le seuil, nommé : `ComponentCallbacks2` le porte, `Application` ne l'expose plus. */
        const val TRIM_MEMORY_UI_HIDDEN = ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN
    }
}
