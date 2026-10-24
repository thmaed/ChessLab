package com.chesslab.transfer

import com.chesslab.training.Fsrs
import com.chesslab.training.FsrsCard
import com.chesslab.training.FsrsRating
import com.chesslab.training.OpeningProgress
import com.chesslab.training.OpeningReviewLog

/**
 * La fusion de deux appareils. Logique PURE : aucune base, aucun fichier,
 * aucune horloge — donc vérifiable sur la JVM en quelques millisecondes.
 *
 * ## Pourquoi il n'y a rien à arbitrer
 *
 * On ne fusionne PAS des états, on réunit des ÉVÉNEMENTS. Le journal des
 * révisions est append-only et chaque entrée porte un identifiant tiré au
 * sort : deux journaux se réunissent par simple union, sans qu'aucune ligne
 * n'en contredise une autre. L'état FSRS, lui, n'est pas transporté — il est
 * RECALCULÉ en rejouant le journal fusionné dans l'ordre des dates réelles.
 *
 * Il en découle trois propriétés, et ce sont elles qui font tenir l'ensemble :
 *
 * - **Déterministe** : le résultat ne dépend pas de l'ordre d'arrivée des
 *   fichiers, seulement de la chronologie des révisions.
 * - **Idempotent** : réimporter deux fois le même fichier ne change rien.
 * - **Commutatif** : A puis B donne le même état que B puis A.
 *
 * C'est la stratégie d'`OpeningProgressSync.swift`, dont le transport iCloud
 * n'était qu'un tuyau parmi d'autres.
 */
object TransferMerge {

    /** Ce qu'un import a réellement changé, pour le dire à l'utilisateur. */
    data class Summary(
        val newReviews: Int,
        val newGames: Int,
        val positionsAffected: Int,
        val newRepertoires: Int = 0,
        /** Puzzles dont la progression a été reprise de l'autre appareil. */
        val puzzlesUpdated: Int = 0,
        val woodpeckerUpdated: Int = 0,
    ) {
        val isEmpty: Boolean
            get() = newReviews == 0 && newGames == 0 && newRepertoires == 0 &&
                puzzlesUpdated == 0 && woodpeckerUpdated == 0
    }

    /**
     * Réunit deux journaux. Les doublons disparaissent, le tri se fait par
     * date — c'est l'ordre dans lequel FSRS devra les rejouer.
     */
    fun mergeLogs(
        local: List<OpeningReviewLog>,
        incoming: List<TransferFile.LogEntry>,
    ): List<OpeningReviewLog> {
        val known = local.mapTo(HashSet()) { it.uid }
        val merged = ArrayList(local)
        for (entry in incoming) {
            if (!known.add(entry.uid)) continue
            merged += OpeningReviewLog(
                uid = entry.uid,
                fenKey = entry.fenKey,
                ratingRaw = entry.rating,
                reviewedAt = entry.reviewedAt,
                elapsedDays = entry.elapsedDays,
                scheduledDays = entry.scheduledDays,
                stabilityAfter = entry.stabilityAfter,
            )
        }
        return merged.sortedBy { it.reviewedAt }
    }

    /**
     * Reconstruit l'état de chaque position en rejouant son journal.
     *
     * `elapsedDays` et `stabilityAfter` du journal ne sont PAS réutilisés :
     * ils décrivent ce qu'un appareil avait calculé avec sa vision partielle
     * de l'histoire. Après fusion, l'histoire a changé — une révision d'un
     * autre appareil peut s'être intercalée — et seul un rejeu complet donne
     * l'état juste.
     */
    fun replay(log: List<OpeningReviewLog>, fsrs: Fsrs = Fsrs()): Map<String, OpeningProgress> {
        val out = HashMap<String, OpeningProgress>()
        for (entry in log.sortedBy { it.reviewedAt }) {
            val existing = out[entry.fenKey]
            val card = existing?.card ?: FsrsCard.new
            val outcome = fsrs.review(card, FsrsRating.of(entry.ratingRaw), entry.reviewedAt)
            out[entry.fenKey] = (existing ?: OpeningProgress(fenKey = entry.fenKey)).applying(outcome)
        }
        return out
    }

    /** Les parties : union par identifiant, la plus ancienne d'abord. */
    fun mergeGames(
        localUids: Set<String>,
        incoming: List<TransferFile.GameEntry>,
    ): List<TransferFile.GameEntry> =
        incoming.filter { it.uid !in localUids }
            .distinctBy { it.uid }
            .sortedBy { it.playedAt }

    /**
     * Les répertoires à écrire : ceux dont l'identité MANQUE ici.
     *
     * Un répertoire qui existe déjà des deux côtés n'est jamais écrasé — il a
     * pu être modifié ici depuis l'export, et l'import FUSIONNE, il ne
     * remplace pas. L'identité vient du fichier lui-même (`user-<uuid>`,
     * posée à la création), donc elle traverse les appareils : réimporter deux
     * fois le même fichier ne crée pas de doublon.
     */
    fun mergeRepertoires(
        localIds: Set<String>,
        incoming: List<TransferFile.RepertoireEntry>,
    ): List<TransferFile.RepertoireEntry> =
        incoming.filter { it.id !in localIds }
            .distinctBy { it.id }
            .sortedBy { it.name.lowercase() }

    /**
     * Les compteurs de puzzles : le MAXIMUM des deux.
     *
     * Ils ne montent jamais, donc le plus grand est le plus informé. Les
     * additionner compterait deux fois les puzzles résolus avant le premier
     * échange.
     */
    fun mergeCounters(local: Int, incoming: Int): Int = maxOf(local, incoming)

    /**
     * La progression d'un puzzle : la plus RÉCENTE l'emporte (`updatedAt`),
     * comme dans la synchro iCloud d'iOS (`PuzzleProgressSync`). Rend celles
     * à écrire ici ; une égalité garde la locale — réimporter ne change rien.
     */
    fun mergePuzzleProgress(
        local: Map<String, Long>,
        incoming: List<TransferFile.PuzzleProgressEntry>,
    ): List<TransferFile.PuzzleProgressEntry> =
        incoming.groupBy { it.externalId }
            .map { (_, entries) -> entries.maxBy { it.updatedAt } }
            .filter { entry -> local[entry.externalId]?.let { entry.updatedAt > it } ?: true }

    /** Les programmes Woodpecker : même règle, le plus récemment joué l'emporte. */
    fun mergeWoodpecker(
        local: Map<String, Long>,
        incoming: List<TransferFile.WoodpeckerEntry>,
    ): List<TransferFile.WoodpeckerEntry> =
        incoming.groupBy { it.id }
            .map { (_, entries) -> entries.maxBy { it.updatedAt } }
            .filter { entry -> local[entry.id]?.let { entry.updatedAt > it } ?: true }
}
