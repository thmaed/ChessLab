package com.chesslab.variants

import chesskit.Position

/**
 * Ce que « nulle » veut dire dans une variante — proposée, ou constatée.
 * Pendant de `VariantDrawRules.swift`.
 *
 * Deux règles distinctes, et une seule chose en commun : elles n'ont pas le
 * même sens d'une variante à l'autre, et il vaut mieux le dire une fois ici
 * que le supposer partout.
 */
object VariantDrawRules {

    /**
     * Écart d'évaluation en deçà duquel l'ordinateur accepte une nulle.
     *
     * Même seuil qu'en mode « Contre l'ordinateur » : il accepte s'il ne se
     * voit pas mieux qu'une quasi-égalité sur son dernier coup, refuse
     * sinon — et refuse aussi tant qu'il n'a pas joué, faute d'avoir un avis.
     */
    const val ACCEPTANCE_CENTIPAWNS = 50

    fun engineAcceptsDraw(lastEngineEvalCp: Int?): Boolean =
        lastEngineEvalCp != null && kotlin.math.abs(lastEngineEvalCp) <= ACCEPTANCE_CENTIPAWNS

    /**
     * La règle du matériel insuffisant s'applique-t-elle à cette variante ?
     *
     * Elle dit : « avec ce matériel, personne ne peut plus mater ». Elle
     * suppose donc que gagner, c'est MATER — ce qui est faux dans la moitié du
     * hub, et l'appliquer partout déclarerait nulles des parties encore
     * gagnables. Le détail, variante par variante :
     *
     * - **Barricades** et **Barricades aléatoires** — oui : les murs ne
     *   matent pas, ils bloquent. Roi + fou contre roi reste nul.
     * - **Crazyhouse** — oui, mais SEULEMENT les deux réserves vides : une
     *   pièce en main se repose et mate, si peu de matériel qu'il reste.
     * - **Atomique** — non. Une explosion tue le roi sans jamais le mater :
     *   roi + fou y gagne.
     * - **Antéchecs** — non. Le but est inversé ; « plus assez pour mater »
     *   n'y veut rien dire.
     * - **Course des rois** — non. On gagne en atteignant la 8e rangée, deux
     *   rois seuls suffisent à faire une partie.
     * - **Roi de la colline**, **Trois échecs** — non, même raison : la
     *   victoire ne passe pas par le mat. Un fou seul donne trois échecs.
     * - **Horde** — non, ses deux camps n'ont ni le même matériel ni le même
     *   but.
     * - **Duck Chess** — non, et c'est le cas le plus contre-intuitif : on y
     *   gagne en CAPTURANT le roi. Un fou seul peut le prendre.
     * - **Coup Volé** — oui : les échecs ordinaires, avec un tour double.
     *   Deux coups d'affilée ne font pas mater roi + fou contre roi.
     */
    fun declaresInsufficientMaterial(variantId: String): Boolean = when (variantId) {
        "barricades", "randombarricades", "crazyhouse", "stolenmove", "chess", "chess960" -> true
        else -> false
    }

    /**
     * La position est-elle nulle faute de matériel ?
     *
     * @param fen la FEN du MOTEUR (réserve et murs compris) — assainie ici.
     * @param pocketIsEmpty les deux réserves sont-elles vides ? Sans objet
     *   hors Crazyhouse, où l'on passe `true`.
     */
    fun isInsufficientMaterial(fen: String, variantId: String, pocketIsEmpty: Boolean): Boolean {
        if (!declaresInsufficientMaterial(variantId) || !pocketIsEmpty) return false
        val position = Position.fromFen(VariantFen.forChessKit(fen)) ?: return false
        return position.hasInsufficientMaterial
    }
}
