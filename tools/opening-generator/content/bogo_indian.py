# -*- coding: utf-8 -*-
"""Défense Bogo-indienne (1.d4 Cf6 2.c4 e6 3.Cf3 Fb4+) — NOIR.

Quand les Blancs jouent 3.Cf3 (pas de Cc3), l'échec …Fb4+ garde l'esprit
Nimzo. Arbre : 4.Fd2 De7 (principale), 4.Cbd2 b6, 4.Fd2 a5. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "bogo-indian",
    "name": "Bogo-Indian Defense",
    "side": "black",
    "level": "advanced",
    "eco": ["E11"],
    "summary": c(
        "La sœur tranquille de la Nimzo-indienne : quand les Blancs évitent Cc3, …Fb4+ garde l'idée de contrôler e4 et d'échanger le fou contre un cavalier. Sûre et sans théorie lourde.",
        "The quiet sister of the Nimzo-Indian: when White avoids Nc3, …Bb4+ keeps the idea of controlling e4 and trading the bishop for a knight. Safe, with little heavy theory.",
    ),
    "lines": [
        # 1) 4.Fd2 De7 (principale)
        {
            "chapter": {"id": "bd2-qe7", "title": c("4.Fd2 De7", "4.Bd2 Qe7")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nf3",
                {"san": "Bb4+", "eco": "Bogo-Indian Defense",
                 "comment": c("L'échec Bogo : sans Cc3 pour bloquer, les Blancs interposent en d2 et les Noirs gardent l'esprit Nimzo.",
                              "The Bogo check: with no Nc3 to block, White interposes on d2 and Black keeps the Nimzo spirit.")},
                {"san": "Bd2", "comment": c("Le blocage naturel ; les Noirs le prendront au bon moment pour dégrader la coordination blanche.",
                                            "The natural block; Black will trade it at the right moment to disrupt White's coordination.")},
                {"san": "Qe7", "comment": c("On soutient le fou b4 et on prépare …Cc6 et la rupture …e5.",
                                            "Support the b4 bishop and prepare …Nc6 and the …e5 break.")},
                "g3", "Nc6", "Bg2", "Bxd2+", "Qxd2", "d6", "O-O", "O-O", "Nc3", "a5", "b3", "e5",
            ],
        },
        # 2) 4.Cbd2 b6
        {
            "chapter": {"id": "nbd2", "title": c("4.Cbd2 b6", "4.Nbd2 b6")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nf3", "Bb4+",
                {"san": "Nbd2", "comment": c("L'autre blocage : le cavalier va en d2, gardant la structure de pions intacte.",
                                             "The other block: the knight goes to d2, keeping the pawn structure intact.")},
                "b6", "a3", "Bxd2+", "Bxd2", "Bb7", "Bg5", "d6", "e3", "Nbd7", "Bd3", "O-O",
            ],
        },
        # 3) 4.Fd2 a5 (garder le fou)
        {
            "chapter": {"id": "bd2-a5", "title": c("4.Fd2 a5", "4.Bd2 a5")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nf3", "Bb4+", "Bd2",
                {"san": "a5", "comment": c("On soutient le fou en b4 (contre a3) pour le garder cloueur plus longtemps.",
                                           "Prop up the b4 bishop (against a3) to keep it pinning longer.")},
                "g3", "O-O", "Bg2", "d6", "O-O",
                {"san": "Bd7",
                 "comment": c("On développe SANS lâcher le fou b4 : …Cbd7 d'abord permet Fc1 et le clouage tombe pour rien.",
                              "Develop WITHOUT letting the b4 bishop go: …Nbd7 first allows Bc1 and the pin falls apart for nothing.")},
                "Bg5", "a4",
            ],
        },

        # ── 3.Cc3 : ce n'est plus une Bogo-Indienne (16/08) ───────────────────
        #
        # Deux Blancs sur trois jouent 3.Cc3 ici, et le cours partait de 3.Cf3.
        # Or la Bogo EST 3.Cf3 Fb4+ : contre 3.Cc3, le clouage donne une
        # Nimzo-Indienne, qui est une autre ouverture. On le dit, et on donne
        # de quoi ne pas être perdu.
        {
            "chapter": {"id": "vs-nc3", "title": c("3.Cc3 — vers la Nimzo-Indienne", "3.Nc3 — into the Nimzo-Indian")},
            "moves": [
                "d4", "Nf6", "c4", "e6",
                {"san": "Nc3",
                 "comment": c("Le coup le plus fréquent — deux parties sur trois — et le cours n'en parlait pas. La Bogo suppose 3.Cf3 ; ici le cavalier va en c3.",
                              "The most common move — two games in three — and the course didn't mention it. The Bogo assumes 3.Nf3; here the knight goes to c3."),
                 "critical": True},
                {"san": "Bb4",
                 "comment": c("Le même clouage, mais il porte maintenant un autre nom : c'est la Nimzo-Indienne. Bonne nouvelle pour un joueur de Bogo — l'idée est identique, seule la théorie change.",
                              "The same pin, but it now has another name: the Nimzo-Indian. Good news for a Bogo player — the idea is identical, only the theory differs."),
                 "critical": True},
                "g3", "d5", "Nf3", "O-O", "Bg2", "Nc6",
            ],
        },
        {
            "chapter": {"id": "vs-london", "title": c("Contre la London — 2.Ff4", "vs the London — 2.Bf4")},
            "moves": [
                "d4", "Nf6",
                {"san": "Bf4",
                 "comment": c("Sans c4, il n'y a ni Bogo ni Nimzo : on joue une position saine avec les repères d'un joueur de …e6.",
                              "Without c4 there is no Bogo and no Nimzo: we play a sound position with the landmarks of an …e6 player.")},
                "d5", "e3", "c5", "c3",
                {"san": "Qb6", "critical": True,
                 "comment": c("Le coup qui met la London mal à l'aise : la dame attaque b2, que le fou parti en f4 ne défend plus.",
                              "The move that makes the London uncomfortable: the queen hits b2, which the bishop — gone to f4 — no longer defends.")},
                "Qb3", "c4",
            ],
        },
    ],
}
