# -*- coding: utf-8 -*-
"""Benoni moderne (1.d4 Cf6 2.c4 c5 3.d5 e6) — répertoire NOIR.

Arbre approfondi : ligne classique (Ce2/Cd2-c4), attaque Taimanov 7.f4 Fb5+,
fianchetto (g3), et la ligne moderne 7.h3. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "modern-benoni",
    "name": "Modern Benoni",
    "side": "black",
    "level": "advanced",
    "eco": ["A60", "A79"],
    "summary": c(
        "Déséquilibre assumé : centre blanc contre majorité noire à l'aile dame et fou g7 mordant. Tactique, risquée, mais riche en contre-jeu par …b5.",
        "Deliberate imbalance: White's centre versus Black's queenside majority and a biting g7 bishop. Tactical, risky, but full of counterplay with …b5.",
    ),
    "lines": [
        # 1) Ligne classique
        {
            "chapter": {"id": "classical", "title": c("Ligne classique", "Classical Main Line")},
            "moves": [
                "d4", "Nf6", "c4", "c5",
                {"san": "d5", "comment": c("Les Blancs ferment ; la structure Benoni se met en place.",
                                           "White closes; the Benoni structure takes shape.")},
                {"san": "e6", "eco": "Benoni Defense: Modern Variation",
                 "comment": c("On attaque d5 pour ouvrir la colonne e et fixer la structure caractéristique.",
                              "Striking d5 to open the e-file and fix the signature structure.")},
                "Nc3", "exd5", "cxd5", "d6", "e4", "g6", "Nf3", "Bg7", "Be2", "O-O", "O-O", "Re8",
                "Nd2", "Na6", "f3", "Nc7", "a4", "b6", "Nc4", "Ba6",
            ],
        },
        # 2) Attaque Taimanov — 7.f4 Fb5+
        {
            "chapter": {"id": "taimanov", "title": c("Attaque Taimanov — 7.f4 Fb5+", "Taimanov — 7.f4 Bb5+")},
            "moves": [
                "d4", "Nf6", "c4", "c5", "d5", "e6", "Nc3", "exd5", "cxd5", "d6", "e4", "g6",
                {"san": "f4", "comment": c("L'Attaque Taimanov, la plus redoutée : les Blancs menacent e4-e5 pour balayer le centre.",
                                           "The feared Taimanov Attack: White threatens e4-e5 to sweep the centre.")},
                "Bg7",
                {"san": "Bb5+", "comment": c("L'échec précis avant d'installer le centre. …Cfd7 est la réponse principale.",
                                             "The precise check before setting up the centre. …Nfd7 is the main reply.")},
                "Nfd7", "a4", "O-O", "Nf3", "Na6", "O-O", "Nc7", "Be2", "b6",
            ],
        },
        # 3) Variante du fianchetto — g3
        {
            "chapter": {"id": "fianchetto", "title": c("Variante du fianchetto — g3", "Fianchetto Variation — g3")},
            "moves": [
                "d4", "Nf6", "c4", "c5", "d5", "e6", "Nc3", "exd5", "cxd5", "d6", "Nf3", "g6",
                {"san": "g3", "comment": c("Le fianchetto : jeu plus calme et positionnel, le fou g2 surveille d5 et b7.",
                                           "The fianchetto: calmer, positional play; the g2 bishop watches d5 and b7.")},
                "Bg7", "Bg2", "O-O", "O-O", "Re8", "Nd2", "Na6", "h3", "Nc7", "a4", "b6", "Nc4", "Ba6",
            ],
        },
        # 4) Ligne moderne — 7.h3
        {
            "chapter": {"id": "modern-h3", "title": c("Ligne moderne — 7.h3", "Modern Line — 7.h3")},
            "moves": [
                "d4", "Nf6", "c4", "c5", "d5", "e6", "Nc3", "exd5", "cxd5", "d6", "e4", "g6",
                {"san": "h3", "comment": c("La ligne moderne : h3 coupe …Fg4 et prépare Fd3, Cf3 en gardant tout solide.",
                                           "The modern line: h3 takes away …Bg4 and prepares Bd3, Nf3 while keeping everything solid.")},
                "a6", "a4", "Bg7", "Bd3", "O-O", "Nf3", "Nbd7", "O-O", "Re8",
            ],
        },

        # ── Sans c4, il n'y a pas de Benoni (16/08) ───────────────────────────
        {
            "chapter": {"id": "no-c4", "title": c("Si les Blancs ne jouent pas c4", "If White doesn't play c4")},
            "moves": [
                "d4", "Nf6",
                {"san": "Bf4",
                 "comment": c("Le Benoni moderne suppose 2.c4 c5 3.d5 : sans c4, les Blancs ne pousseront pas d5 et la structure à chaîne de pions n'apparaîtra jamais.",
                              "The Modern Benoni assumes 2.c4 c5 3.d5: without c4, White won't push d5 and the pawn-chain structure never appears."),
                 "critical": True},
                "e6", "e3", "d5", "Nf3", "c5", "c3", "Nc6",
            ],
        },
        {
            "chapter": {"id": "no-c4", "title": c("Si les Blancs ne jouent pas c4", "If White doesn't play c4")},
            "moves": [
                "d4", "Nf6", "Nf3",
                {"san": "d5",
                 "comment": c("Sans c4, …c5 ne mène à rien : on bâtit une structure classique et l'on attend. Si c4 vient plus tard, le Benoni redevient possible.",
                              "Without c4, …c5 leads nowhere: we build a classical structure and wait. If c4 comes later, the Benoni is back on.")},
                "c4", "e6", "cxd5", "exd5", "Nc3", "c6",
            ],
        },
    ],
}
