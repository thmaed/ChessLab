# -*- coding: utf-8 -*-
"""Gambit de l'éléphant (1.e4 e5 2.Cf3 d5) — NOIR.

Un gambit rare et provocant : …d5 d'entrée pour ouvrir le jeu. Douteux au fond
mais désarçonnant. Arbre : 3.exd5 Fd6 et 3.exd5 e4. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "elephant-gambit",
    "name": "Elephant Gambit",
    "side": "black",
    "level": "club",
    "eco": ["C40"],
    "summary": c(
        "Un contre-gambit rare et piégeur : au lieu de défendre e5, on frappe par …d5. Objectivement douteux, mais peu d'adversaires connaissent la bonne réfutation.",
        "A rare, tricky countergambit: instead of defending e5, strike with …d5. Objectively dubious, but few opponents know the correct refutation.",
    ),
    "lines": [
        # 1) 3.exd5 Fd6
        {
            "chapter": {"id": "bd6", "title": c("3.exd5 Fd6", "3.exd5 Bd6")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "d5", "eco": "Elephant Gambit",
                 "comment": c("Le gambit de l'éléphant : on offre le centre pour un développement rapide et des complications.",
                              "The Elephant Gambit: offer the centre for fast development and complications.")},
                "exd5",
                {"san": "Bd6", "comment": c("On garde e5 fort et on développe agressivement, prêt à …e4 pour chasser le cavalier.",
                                            "Keep e5 strong and develop aggressively, ready for …e4 to chase the knight.")},
                "d4", "e4", "Ne5", "Nf6", "Bc4", "O-O", "Nc3", "Nbd7",
            ],
        },
        # 2) 3.exd5 e4
        {
            "chapter": {"id": "e4", "title": c("3.exd5 e4", "3.exd5 e4")},
            "moves": [
                "e4", "e5", "Nf3", "d5", "exd5",
                {"san": "e4", "comment": c("On chasse le cavalier f3 tout de suite ; il faudra récupérer d5 précisément.",
                                           "Kick the f3-knight at once; d5 must then be regained accurately.")},
                "Qe2", "Nf6", "Nc3", "Be7", "Nxe4", "Nxe4", "Qxe4", "O-O",
            ],
        },

        # ── Quand les Blancs déclinent (16/08) ────────────────────────────────
        {
            "chapter": {"id": "vs-nxe5", "title": c("3.Cxe5 — la réfutation calme", "3.Nxe5 — the calm refutation")},
            "moves": [
                "e4", "e5", "Nf3", "d5",
                {"san": "Nxe5",
                 "comment": c("Le coup le plus solide des Blancs, joué une fois sur cinq, et le cours partait de 3.exd5. Ils prennent le pion et rendent le nôtre inutile.",
                              "White's most solid move, played in one game in five, and the course started from 3.exd5. They take the pawn and make ours pointless."),
                 "critical": True},
                {"san": "dxe4",
                 "comment": c("On récupère au centre. La position reste jouable mais l'initiative promise par le gambit n'est plus là : c'est le prix d'un refus propre.",
                              "We recapture in the centre. The position stays playable, but the initiative the gambit promised is gone — the price of a clean decline.")},
                "Bc4", "Nh6", "d4", "Nd7", "Nxd7", "Bxd7",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,80). Répertoire NOIR :
        # les trous sont des coups BLANCS, et ce sont surtout les façons de
        # sauver le cavalier f3 attaqué par …e4.
        #
        # Honnêteté : plusieurs lignes finissent nettement en faveur des Blancs.
        # Le gambit de l'éléphant est une arme de SURPRISE, pas une ouverture
        # correcte — le cours doit le dire, pas le cacher. ────────────────────
        {
            "chapter": {"id": "vs-nc3", "title": c("4.Cc3 — le développement sain", "4.Nc3 — sound development")},
            "moves": [
                "e4", "e5", "Nf3", "d5", "exd5", "Bd6",
                {"san": "Nc3",
                 "comment": c("Un Blanc sur trois développe simplement au lieu de pousser d4, et le cours ne prévoyait que d4. C'est la réponse la plus gênante : ils gardent le pion sans se découvrir.",
                              "One White player in three simply develops instead of pushing d4, and the course only planned for d4. It is the most awkward reply: they keep the pawn without committing."),
                 "critical": True},
                {"san": "Nf6",
                 "comment": c("On développe en attaquant d5. Il faut jouer vite et concrètement : le pion est perdu, seule l'initiative peut le compenser.",
                              "We develop while hitting d5. Play must be fast and concrete: the pawn is gone, only the initiative can pay for it."),
                 "critical": True},
                "Bb5+", "Bd7", "d4", "e4", "Bxd7+", "Nbxd7", "Nd2", "O-O", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-e4-push", "title": c("3…e4 — chasser le cavalier", "3…e4 — kicking the knight")},
            "moves": [
                "e4", "e5", "Nf3", "d5", "exd5", "e4",
                {"san": "Nd4",
                 "comment": c("Le cavalier saute au centre plutôt que de reculer — près d'un Blanc sur trois, et le cours ne voyait que De2. De d4 il est actif, mais il est aussi une cible.",
                              "The knight jumps to the centre rather than retreat — nearly one White player in three, and the course only saw Qe2. On d4 it is active, but it is also a target."),
                 "critical": True},
                {"san": "Qxd5",
                 "comment": c("On récupère le pion tout de suite : la dame est en sécurité au centre puisque le cavalier d4 lui bouche la route à ses propres pièces.",
                              "We take the pawn back at once: the queen is safe in the centre because the d4 knight blocks White's own pieces from reaching her."),
                 "critical": True},
                "Nb5", "Qd7", "Be2", "Nf6", "O-O", "a6", "N5c3", "Be7", "d3",
            ],
        },
        {
            "chapter": {"id": "vs-e4-push", "title": c("3…e4 — chasser le cavalier", "3…e4 — kicking the knight")},
            "moves": [
                "e4", "e5", "Nf3", "d5", "exd5", "e4",
                {"san": "Ng1",
                 "comment": c("Le retour à la maison : humiliant en apparence, très solide en réalité. Un Blanc sur cinq le joue, et le cours n'en disait rien.",
                              "Going home: humiliating in appearance, very solid in reality. One White player in five plays it, and the course said nothing about it."),
                 "critical": True},
                "Qxd5", "Nc3",
                {"san": "Qe6",
                 "comment": c("La dame se met à l'abri en gardant e4 — le pion avancé est notre seul acquis du gambit, le perdre serait tout perdre.",
                              "The queen steps aside while holding e4 — that advanced pawn is our only gain from the gambit; losing it would be losing everything."),
                 "critical": True},
                "Qe2", "Nf6", "f3", "exf3", "Nxf3", "Nc6", "d3",
            ],
        },
        {
            "chapter": {"id": "vs-nc3", "title": c("4.Cc3 — le développement sain", "4.Nc3 — sound development")},
            "moves": [
                "e4", "e5", "Nf3", "d5", "exd5", "Bd6",
                {"san": "d3",
                 "comment": c("Le coup le plus décevant pour nous : les Blancs se contentent de garder le pion et ne donnent aucune cible. Un Blanc sur six, absent du cours.",
                              "The most disappointing move for us: White simply keeps the pawn and offers no target. One White player in six, missing from the course."),
                 "critical": True},
                "Nf6", "c4", "c6",
                {"san": "Nc3",
                 "comment": c("Ils défendent tout. Il faut accepter la réalité : contre un adversaire qui joue simplement, le gambit de l'éléphant ne donne rien de plus qu'un pion de moins.",
                              "They defend everything. The reality has to be accepted: against an opponent who plays simply, the Elephant Gambit gives nothing beyond being a pawn down."),
                 "critical": True},
                "O-O", "dxc6", "Nxc6", "Be2", "h6", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-bc4", "title": c("Si les Blancs jouent 2.Fc4", "If White plays 2.Bc4")},
            "moves": [
                "e4", "e5",
                {"san": "Bc4",
                 "comment": c("Sans 2.Cf3, il n'y a pas de gambit de l'éléphant : le pion e5 n'est pas attaqué, donc …d5 ne gagne aucun temps. Un Blanc sur neuf, et le cours n'avait rien.",
                              "Without 2.Nf3 there is no Elephant Gambit: the e5 pawn is not attacked, so …d5 gains no tempo. One White player in nine, and the course had nothing."),
                 "critical": True},
                {"san": "Nf6",
                 "comment": c("On bascule sur une défense saine plutôt que de forcer un gambit qui n'a plus de sens. Savoir renoncer à son arme favorite fait partie du répertoire.",
                              "We switch to a sound defence rather than force a gambit that no longer makes sense. Knowing when to drop your pet weapon is part of a repertoire."),
                 "critical": True},
                "d3", "c6", "Nf3", "d5", "Bb3", "a5", "a3", "a4", "Ba2",
            ],
        },
    ],
}
