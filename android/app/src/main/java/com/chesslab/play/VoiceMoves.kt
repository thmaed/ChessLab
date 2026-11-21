package com.chesslab.play

/**
 * COUPS À LA VOIX (19/11/2026) : ce que la partie fait de ce que le micro a entendu. Pendant de
 * `PlayViewModel.handleVoice` (iOS), sorti du modèle de partie pour se tester sur la JVM — le modèle Android ne
 * vit que sur un appareil.
 *
 * Décisions de l'utilisateur : le coup compris est JOUÉ DIRECTEMENT ; « annule » le reprend ; un coup impossible,
 * une phrase incomprise ou ambiguë se DISENT ; une conversation est ignorée ; micro coupé, rien ne se joue.
 */
object VoiceMoves {

    sealed interface Decision {
        data class Play(val move: VoiceMoveParser.Candidate) : Decision
        data object Undo : Decision
        /** « annule » avec une pendule, ou le moteur qui réfléchit : on ne reprend pas. */
        data object CannotUndo : Decision
        data object Ambiguous : Decision
        /** La reconnaissance hésite entre deux coups (« a3 » ou « e3 ») : on le dit et on demande, sans rien jouer. */
        data class Conflicting(val moves: List<VoiceMoveParser.Candidate>) : Decision
        data object Illegal : Decision
        data object NotUnderstood : Decision
        data object Ignored : Decision
    }

    /**
     * @param listening réglage allumé, interrupteur « Micro » allumé et partie en cours — sinon une phrase arrivée
     *   en retard ne joue rien, pas même « annule ».
     * @param canAct c'est à l'utilisateur, sur la position vive (pas en consultation d'un coup passé).
     * @param candidates les coups légaux, calculés seulement si la phrase ressemble à un coup.
     */
    fun decide(
        transcripts: List<String>,
        vocabulary: VoiceMoveParser.Vocabulary,
        listening: Boolean,
        canTakeback: Boolean,
        canAct: Boolean,
        /** Les deux coups entre lesquels on vient de demander de choisir (encore valables), sinon vide. */
        pendingChoice: List<VoiceMoveParser.Candidate> = emptyList(),
        language: String = "fr",
        candidates: () -> List<VoiceMoveParser.Candidate>,
    ): Decision {
        if (!listening) return Decision.Ignored
        if (transcripts.any { VoiceMoveParser.isUndo(it, vocabulary) }) {
            return if (canTakeback) Decision.Undo else Decision.CannotUndo
        }
        if (!canAct) return Decision.Ignored
        val legal = candidates()
        // Après « a 3 ou e 3 ? » : « premier » ou « deuxième » tranche (les lettres, elles, s'embrouillent).
        val chosen = VoiceMoveParser.choice(transcripts, language)?.let { pendingChoice.getOrNull(it) }
        if (chosen != null && chosen in legal) return Decision.Play(chosen)
        if (!VoiceMoveParser.soundsLikeChess(transcripts, vocabulary)) return Decision.Ignored
        return when (val outcome = VoiceMoveParser.resolve(transcripts, legal, vocabulary = vocabulary)) {
            is VoiceMoveParser.Outcome.Move -> Decision.Play(outcome.move)
            is VoiceMoveParser.Outcome.Conflicting -> Decision.Conflicting(outcome.moves.take(2))
            // Sans dire OÙ sont les pièces : à l'aveugle, ce serait révéler la position.
            is VoiceMoveParser.Outcome.Ambiguous -> Decision.Ambiguous
            VoiceMoveParser.Outcome.Illegal -> Decision.Illegal
            VoiceMoveParser.Outcome.NotUnderstood -> Decision.NotUnderstood
        }
    }

    /**
     * Pour l'essai ANTICIPÉ de l'écoute (20/11/2026, pendant de `PlayViewModel.voiceIsDecisive`) : la phrase entendue
     * après une courte pause donne-t-elle déjà un coup sûr, à jouer sans attendre la fin ? « annule », un coup
     * impossible, une moitié de phrase attendent la fin ; une promotion aussi (« e8… cavalier », coupé après « e8 »,
     * deviendrait une dame).
     */
    fun isDecisive(
        transcripts: List<String>,
        vocabulary: VoiceMoveParser.Vocabulary,
        listening: Boolean,
        canAct: Boolean,
        pendingChoice: List<VoiceMoveParser.Candidate> = emptyList(),
        language: String = "fr",
        candidates: () -> List<VoiceMoveParser.Candidate>,
    ): Boolean {
        val decision = decide(
            transcripts, vocabulary, listening, canTakeback = false, canAct = canAct,
            pendingChoice = pendingChoice, language = language, candidates = candidates,
        )
        return decision is Decision.Play && decision.move.promotion == null
    }
}
