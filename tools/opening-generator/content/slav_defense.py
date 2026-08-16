# -*- coding: utf-8 -*-
"""Slave et semi-slave (1.d4 d5 2.c4 c6) — répertoire BLANC (jouer CONTRE).

Arbre approfondi : Slave pure 4…dxc4 5.a4 Ff5, Slave d'échange, semi-slave
Meran, et l'anti-Meran / Botvinnik 5.Fg5. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "slav-defense",
    "name": "Slav Defense",
    "side": "white",
    "level": "advanced",
    "eco": ["D10", "D19"],
    "summary": c(
        "La Slave (…c6) garde le fou c8 libre — le grand atout sur le gambit refusé. Ce répertoire montre comment les Blancs y font face, Slave pure comme semi-slave.",
        "The Slav (…c6) keeps the c8 bishop free — its big edge over the QGD. This repertoire shows how White handles it, both pure Slav and Semi-Slav.",
    ),
    "lines": [
        # 1) Slave pure — 4…dxc4
        {
            "chapter": {"id": "pure-slav", "title": c("Slave pure — 4…dxc4", "Pure Slav — 4…dxc4")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "c6", "eco": "Slav Defense",
                 "comment": c("La Slave : les Noirs soutiennent d5 tout en gardant …Ff5/…Fg4 possible.",
                              "The Slav: Black supports d5 while keeping …Bf5/…Bg4 available.")},
                "Nf3", "Nf6", "Nc3", "dxc4",
                {"san": "a4", "comment": c("Le coup clé : on empêche …b5 qui tiendrait le pion c4.",
                                           "The key move: stopping …b5, which would hold the c4 pawn.")},
                "Bf5", "e3", "e6", "Bxc4", "Bb4", "O-O", "O-O",
                {"san": "Qe2", "comment": c("On prépare e4 et l'installation Ce5. La Slave est solide mais un peu passive.",
                                            "Preparing e4 and the Ne5 outpost. The Slav is solid but a touch passive.")},
                "Bg6", "Ne5", "Nbd7", "Nxg6", "hxg6",
            ],
        },
        # 2) Slave d'échange
        {
            "chapter": {"id": "exchange-slav", "title": c("Slave d'échange — 3.cxd5", "Exchange Slav — 3.cxd5")},
            "moves": [
                "d4", "d5", "c4", "c6",
                {"san": "cxd5", "comment": c("L'échange : structure symétrique, sûre, idéale pour jouer simple avec un léger plus.",
                                             "The exchange: a symmetrical, safe structure, ideal for simple play with a nagging edge.")},
                "cxd5", "Nc3", "Nf6", "Nf3", "Nc6", "Bf4", "Bf5", "e3", "e6", "Bb5", "Nd7",
            ],
        },
        # 3) Semi-slave — Meran
        {
            "chapter": {"id": "meran", "title": c("Semi-slave — Meran", "Semi-Slav — Meran")},
            "moves": [
                "d4", "d5", "c4", "c6", "Nf3", "Nf6", "Nc3",
                {"san": "e6", "eco": "Semi-Slav Defense",
                 "comment": c("La semi-slave : plus combative, elle prépare …dxc4 et …b5 avec du contre-jeu.",
                              "The Semi-Slav: more combative, preparing …dxc4 and …b5 with counterplay.")},
                "e3", "Nbd7", "Bd3", "dxc4", "Bxc4", "b5", "Bd3", "a6",
                {"san": "e4", "comment": c("Le Meran : les Blancs poussent e4-e5 pour ouvrir le jeu au centre pendant que les Noirs s'étendent à l'aile dame.",
                                           "The Meran: White pushes e4-e5 to open the centre while Black expands on the queenside.")},
                "c5", "e5", "cxd4", "Nxb5", "axb5", "exf6", "gxf6",
            ],
        },
        # 4) Anti-Meran / Botvinnik — 5.Fg5
        {
            "chapter": {"id": "botvinnik", "title": c("Anti-Meran / Botvinnik — 5.Fg5", "Anti-Meran / Botvinnik — 5.Bg5")},
            "moves": [
                "d4", "d5", "c4", "c6", "Nf3", "Nf6", "Nc3", "e6",
                {"san": "Bg5", "comment": c("L'anti-Meran : on cloue f6 tout de suite. La ligne Botvinnik est l'une des plus tranchantes des échecs.",
                                            "The Anti-Meran: pin f6 at once. The Botvinnik line is one of the sharpest in all of chess.")},
                "h6", "Bh4", "dxc4", "e4", "g5", "Bg3", "b5", "Be2", "Bb7",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        #
        # Comme pour ses deux cours frères (Gambit Dame accepté et refusé), les
        # plus gros trous de la Slave sont les AUTRES réponses à 2.c4. On nomme
        # la bifurcation au lieu de recopier un répertoire entier.
        {
            "chapter": {"id": "sisters", "title": c("Si les Noirs ne jouent pas …c6", "If Black doesn't play …c6")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "e6",
                 "comment": c("Le Gambit Dame refusé — un quart des parties. Différence essentielle avec la Slave : le fou c8 est maintenant enfermé, et tout le plan noir en découle.",
                              "The Queen's Gambit Declined — a quarter of games. The key difference from the Slav: the c8 bishop is now shut in, and Black's whole plan follows from that."),
                 "critical": True},
                "Nc3", "Nf6", "Bg5", "c5", "cxd5", "cxd4", "Qxd4",
            ],
        },
        {
            "chapter": {"id": "sisters", "title": c("Si les Noirs ne jouent pas …c6", "If Black doesn't play …c6")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "dxc4",
                 "comment": c("Le Gambit Dame accepté. Les Noirs ne garderont pas le pion ; l'enjeu est de le reprendre sans perdre de temps.",
                              "The Queen's Gambit Accepted. Black won't keep the pawn; the point is to take it back without losing time.")},
                {"san": "e4",
                 "comment": c("La version ambitieuse : on prend tout le centre plutôt que de récupérer le pion tout de suite.",
                              "The ambitious version: take the whole centre rather than regaining the pawn at once."),
                 "critical": True},
                "e5", "Nf3", "Bb4+", "Bd2", "Bxd2+", "Nbxd2",
            ],
        },
    ],
}
