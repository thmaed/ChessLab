# -*- coding: utf-8 -*-
"""Défense Philidor (1.e4 e5 2.Cf3 d6) — répertoire NOIR.

Arbre : système Hanham (…Cbd7/…Fe7), variante de l'échange (…exd4), et
l'hybride Philidor-Pirc (…exd4 …g6). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "philidor-defense",
    "name": "Philidor Defense",
    "side": "black",
    "level": "club",
    "eco": ["C41"],
    "summary": c(
        "Solide et discrète : les Noirs soutiennent e5 par …d6 au lieu de …Cc6. Peu d'espace, mais une position sans faiblesse et des plans clairs (…c6, …Fe7, …0-0).",
        "Solid and quiet: Black supports e5 with …d6 instead of …Nc6. Little space, but a weakness-free position with clear plans (…c6, …Be7, …0-0).",
    ),
    "lines": [
        {
            "chapter": {"id": "hanham", "title": c("Système Hanham", "Hanham System")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "Nf6", "Nc3", "Nbd7", "Bc4", "Be7", "O-O", "O-O",
                {"san": "a4", "comment": c("Les Blancs freinent …b5 ; les Noirs manœuvrent tranquillement derrière leur petit centre.",
                                           "White restrains …b5; Black manoeuvres calmly behind the small centre.")},
                "c6", "h3", "Qc7", "Qe2", "b6", "Rd1", "Bb7",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4",
                {"san": "exd4", "comment": c("On échange au centre pour un jeu simple et solide, sans souci d'espace.",
                                             "Trade in the centre for simple, solid play, free of space worries.")},
                "Nxd4", "Nf6", "Nc3", "Be7", "Be2", "O-O", "O-O", "Re8", "h3", "Bf8", "Bf4", "Nbd7", "Qd2", "a6",
            ],
        },
        {
            "chapter": {"id": "pirc-hybrid", "title": c("Hybride Philidor-Pirc — …g6", "Philidor-Pirc hybrid — …g6")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "exd4", "Nxd4", "g6", "Nc3", "Bg7", "Be3", "Nf6", "f3", "O-O", "Qd2", "Re8",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-bc4", "title": c("3.Fc4 — la sortie italienne", "3.Bc4 — the Italian bishop")},
            "moves": [
                "e4", "e5", "Nf3", "d6",
                {"san": "Bc4",
                 "comment": c("Le coup le plus fréquent contre la Philidor — plus de quatre parties sur dix — et le cours partait de 3.d4. Les Blancs visent f7 avant d'ouvrir le centre.",
                              "The most common move against the Philidor — over four games in ten — and the course started from 3.d4. White eyes f7 before opening the centre."),
                 "critical": True},
                {"san": "Be7",
                 "comment": c("Sobre et juste : on développe sans donner de cible. …Fe6 inviterait Fxe6 et un pion doublé sans compensation.",
                              "Sober and correct: develop without offering a target. …Be6 would invite Bxe6 and a doubled pawn for nothing.")},
                "d4", "exd4", "Nxd4", "Nf6", "Nc3", "O-O",
                {"san": "O-O",
                 "comment": c("Position typique de la Philidor moderne : à l'étroit mais sans faiblesse. Le plan est …Te8, …Ff8 et …c6.",
                              "The typical modern Philidor position: cramped but without weaknesses. The plan is …Re8, …Bf8 and …c6.")},
            ],
        },
        {
            "chapter": {"id": "vs-dxe5", "title": c("4.dxe5 — l'échange au centre", "4.dxe5 — the central exchange")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "Nf6",
                {"san": "dxe5",
                 "comment": c("Sept Blancs sur dix prennent ici, et le cours n'y répondait pas. Attention : reprendre en d6 par le pion perd un temps précieux.",
                              "Seven White players in ten take here, and the course had no answer. Careful: recapturing on d6 with the pawn loses precious time."),
                 "critical": True},
                {"san": "Nxe4", "critical": True,
                 "comment": c("LE coup à connaître : on ne reprend pas le pion e5, on prend celui de e4. C'est la ressource qui tient toute la variante.",
                              "THE move to know: don't recapture on e5 — take on e4 instead. That's the resource the whole line rests on.")},
                "Qd5", "Nc5", "Bg5", "Qd7", "exd6", "Bxd6",
            ],
        },
    ],
}
