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

        # ── Trous comblés le 22/08 (coverage.py, dette 0,84). Répertoire BLANC :
        # comment les Blancs font face à la Slave et à ses cousines. ──────────
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre 2…Cf6", "vs 2…Nf6")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "Nf6",
                 "comment": c("Les Noirs développent avant de choisir leur défense — un joueur sur sept — et le cours ne prévoyait que …c6, …e6 et …dxc4. Il faut une réponse qui ne les laisse pas transposer où ils veulent.",
                              "Black develops before choosing a defence — one player in seven — and the course only planned for …c6, …e6 and …dxc4. We need a reply that does not let them transpose wherever they like."),
                 "critical": True},
                {"san": "cxd5",
                 "comment": c("On prend immédiatement, avant que …c6 ou …e6 ne viennent soutenir d5. C'est le seul moment où cet échange gagne quelque chose.",
                              "We take at once, before …c6 or …e6 come to support d5. This is the only moment when that exchange wins anything."),
                 "critical": True},
                "c6", "dxc6", "Nxc6", "Nf3", "e5", "dxe5",
                {"san": "Qxd1+",
                 "comment": c("Les Noirs ont un pion de moins et proposent l'échange des dames pour ralentir. On accepte : sans dames, un pion de plus est un pion de plus.",
                              "Black is a pawn down and offers the queen trade to slow things. We accept: without queens, a pawn up is a pawn up."),
                 "critical": True},
                "Kxd1", "Ng4",
            ],
        },
        {
            "chapter": {"id": "vs-qgd", "title": c("Contre le gambit refusé — 2…e6", "vs the Declined — 2…e6")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3", "Nf6", "Bg5",
                {"san": "Be7",
                 "comment": c("Le coup le plus joué de tout ce cours — près de six Noirs sur dix — et il n'y figurait pas : seul …c5 était prévu. Les Noirs brisent le clouage en développant.",
                              "The most played move in this entire course — nearly six Black players in ten — and it was absent: only …c5 was planned. Black breaks the pin by developing."),
                 "critical": True},
                "e3", "Nbd7", "Nf3", "O-O",
                {"san": "Rc1",
                 "comment": c("La tour se poste sur la colonne c AVANT qu'elle ne s'ouvre. C'est le coup qui distingue un plan d'un enchaînement de coups naturels.",
                              "The rook takes the c-file BEFORE it opens. This is the move that separates a plan from a string of natural moves."),
                 "critical": True},
                "h6", "Bh4", "c5", "dxc5", "Nxc5",
            ],
        },
        {
            "chapter": {"id": "vs-qga", "title": c("Contre le gambit accepté — 2…dxc4", "vs the Accepted — 2…dxc4")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "e4",
                {"san": "e6",
                 "comment": c("Les Noirs ouvrent la sortie de leur fou f8 plutôt que de contester le centre. Un joueur sur quatre, et le cours ne voyait que …e5.",
                              "Black opens the way for their f8 bishop rather than contesting the centre. One player in four, and the course only saw …e5."),
                 "critical": True},
                {"san": "Bxc4",
                 "comment": c("On récupère le pion sans se presser : les Noirs n'ont jamais pu le garder, tout l'enjeu était le temps qu'ils nous coûteraient pour le reprendre.",
                              "We take the pawn back unhurried: Black could never keep it, the whole question was how many tempi it would cost us."),
                 "critical": True},
                "c5", "Nf3", "cxd4", "Nxd4", "Nf6", "Nc3", "Bc5", "Be3", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-qga", "title": c("Contre le gambit accepté — 2…dxc4", "vs the Accepted — 2…dxc4")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "e4",
                {"san": "b5",
                 "comment": c("La tentative de GARDER le pion — un Noir sur cinq essaie, et le cours n'en disait rien. C'est là qu'il faut connaître la réfutation, pas l'improviser.",
                              "The attempt to KEEP the pawn — one Black player in five tries it, and the course said nothing. This is where the refutation must be known, not improvised."),
                 "critical": True},
                {"san": "a4",
                 "comment": c("On frappe la chaîne à sa base. Les Noirs ne peuvent pas tout tenir : après l'échange, leur pion b5 tombe ou leur structure s'effondre.",
                              "We hit the chain at its base. Black cannot hold everything: after the exchange, either the b5 pawn falls or the structure collapses."),
                 "critical": True},
                "c6", "axb5", "cxb5", "Nc3", "Bd7", "d5", "a6", "e5", "e6",
            ],
        },
        {
            "chapter": {"id": "exchange-slav", "title": c("Slave d'échange — 3.cxd5", "Exchange Slav — 3.cxd5")},
            "moves": [
                "d4", "d5", "c4", "c6", "cxd5", "cxd5", "Nc3",
                {"san": "Nc6",
                 "comment": c("Un Noir sur cinq sort ce cavalier avant l'autre, et le cours ne prévoyait que …Cf6. La Slave d'échange a la réputation d'être nulle : elle ne l'est que si les Blancs jouent sans plan.",
                              "One Black player in five develops this knight first, and the course only planned for …Nf6. The Exchange Slav has a drawish reputation: it only deserves it when White plays without a plan."),
                 "critical": True},
                {"san": "e4",
                 "comment": c("Le plan qui donne du jeu : on offre un pion pour ouvrir la position avant que les Noirs n'aient fini de se développer. La symétrie disparaît d'un coup.",
                              "The plan that creates play: we offer a pawn to open the position before Black has finished developing. The symmetry vanishes at once."),
                 "critical": True},
                "Nf6", "e5", "Ne4", "Nf3", "Bg4", "h3", "Bxf3", "gxf3", "Nxc3",
            ],
        },
    ],
}
