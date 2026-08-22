# -*- coding: utf-8 -*-
"""Gambit dame accepté (1.d4 d5 2.c4 dxc4) — répertoire BLANC.

Arbre approfondi : ligne principale 3.Cf3 (pion isolé), variante centrale 3.e4,
et la tentative …a6/…b5 pour garder le pion (réfutée). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "queens-gambit-accepted",
    "name": "Queen's Gambit Accepted",
    "side": "white",
    "level": "club",
    "eco": ["D20", "D29"],
    "summary": c(
        "Les Noirs prennent en c4 — mais ne peuvent pas garder le pion. Les Blancs reprennent le centre par e3/e4 et jouissent d'une belle liberté de développement.",
        "Black grabs c4 — but can't hold the pawn. White regains the centre with e3/e4 and enjoys easy, free development.",
    ),
    "lines": [
        # 1) Ligne principale — 3.Cf3
        {
            "chapter": {"id": "classical", "title": c("Ligne principale — 3.Cf3", "Main Line — 3.Nf3")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "dxc4", "eco": "Queen's Gambit Accepted",
                 "comment": c("Accepter le pion : les Noirs ne le garderont pas, mais gagnent du temps de développement.",
                              "Accepting the pawn: Black won't keep it, but gains development time.")},
                {"san": "Nf3", "comment": c("On empêche …e5 avant de reprendre le pion tranquillement.",
                                            "Stopping …e5 before calmly recovering the pawn.")},
                "Nf6", "e3", "e6", "Bxc4", "c5", "O-O", "a6",
                {"san": "a4", "comment": c("On freine …b5 ; il naîtra un pion dame isolé où les Blancs pressent activement.",
                                           "Restrain …b5; an isolated queen's pawn arises with active pressure for White.")},
                "Nc6", "Qe2", "cxd4", "Rd1", "Be7", "exd4", "O-O", "Nc3",
            ],
        },
        # 2) Variante centrale — 3.e4
        {
            "chapter": {"id": "central", "title": c("Variante centrale — 3.e4", "Central Variation — 3.e4")},
            "moves": [
                "d4", "d5", "c4", "dxc4",
                {"san": "e4", "eco": "Queen's Gambit Accepted: Central Variation",
                 "comment": c("La version ambitieuse : les Blancs bâtissent d'emblée un centre e4+d4 imposant.",
                              "The ambitious version: White builds a big e4+d4 centre at once.")},
                "e5", "Nf3", "exd4", "Bxc4", "Nc6", "O-O", "Be6",
                {"san": "Bxe6", "comment": c("On échange en e6 pour attaquer b7 et e6 à la dame — un pion revient souvent.",
                                             "Trade on e6 to hit b7 and e6 with the queen — a pawn usually returns.")},
                "fxe6", "Qb3", "Qd7", "Qxb7", "Rb8", "Qa6", "Nf6",
            ],
        },
        # 3) La tentative …a6/…b5 (garder le pion)
        {
            "chapter": {"id": "hold-attempt", "title": c("La tentative …a6/…b5", "The …a6/…b5 hold attempt")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "Nf3",
                {"san": "a6", "comment": c("Les Noirs veulent tenir c4 par …b5. C'est une illusion : le pion tombe.",
                                           "Black wants to hold c4 with …b5. It's an illusion: the pawn falls.")},
                "e3", "b5",
                {"san": "a4", "comment": c("Le coup de sape : a4 attaque la chaîne b5-c4 par la base.",
                                           "The undermining blow: a4 hits the b5-c4 chain at its base.")},
                "Bb7", "axb5", "axb5", "Rxa8", "Bxa8", "b3", "cxb3", "Qxb3",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        #
        # Ce cours part de 2…dxc4. Ses deux plus gros trous sont les DEUX AUTRES
        # réponses au Gambit Dame — …e6 et …c6 — qui ont chacune leur cours.
        # On ne les recopie pas : on dit où l'on arrive.
        {
            "chapter": {"id": "sisters", "title": c("Si les Noirs ne prennent pas", "If Black doesn't take")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "e6",
                 "comment": c("Le Gambit Dame REFUSÉ, joué dans un quart des parties. Ce n'est pas notre sujet ici — le cours dédié le traite — mais il faut savoir le reconnaître.",
                              "The Queen's Gambit DECLINED, played in a quarter of games. Not our subject here — its own course covers it — but you must recognise it."),
                 "critical": True},
                {"san": "Nc3",
                 "comment": c("Le coup naturel. Si …Fb4, c'est la Ragozine ; si …Cf6, la position classique du Refusé.",
                              "The natural move. If …Bb4, that's the Ragozin; if …Nf6, the classical Declined position.")},
                "Bb4", "Qa4+", "Nc6", "e3", "Nf6",
            ],
        },
        {
            "chapter": {"id": "sisters", "title": c("Si les Noirs ne prennent pas", "If Black doesn't take")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "c6",
                 "comment": c("La Slave : les Noirs soutiennent d5 par un pion sans enfermer leur fou. Cours dédié également.",
                              "The Slav: Black supports d5 with a pawn without shutting in the bishop. It too has its own course.")},
                "Nf3", "Nf6", "Nc3", "e6", "e3", "Nbd7", "Bd3",
                {"san": "dxc4",
                 "comment": c("Et l'on retombe sur NOTRE sujet, avec un temps de plus : la Slave qui prend en c4 devient un Gambit Dame accepté retardé.",
                              "And we're back to OUR subject, a tempo up: a Slav that takes on c4 becomes a delayed Queen's Gambit Accepted.")},
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,83). Répertoire BLANC.
        # Trois de ces trous recoupent ceux de la Slave — les deux cours
        # traversent les mêmes positions par des ordres différents ; le graphe
        # étant indexé par FEN, chaque cours doit néanmoins les couvrir. ──────
        {
            "chapter": {"id": "vs-qgd", "title": c("Contre le gambit refusé — 2…e6", "vs the Declined — 2…e6")},
            "moves": [
                "d4", "d5", "c4", "e6", "Nc3",
                {"san": "Nf6",
                 "comment": c("Plus d'un Noir sur deux joue ce développement naturel, et le cours ne prévoyait que le clouage …Fb4. C'était le plus gros manque de ce répertoire.",
                              "More than one Black player in two makes this natural developing move, and the course only planned for the pin …Bb4. It was this repertoire's biggest gap."),
                 "critical": True},
                {"san": "Bg5",
                 "comment": c("Le clouage classique du gambit refusé : le cavalier f6 garde d5 et e4, et tant qu'il est cloué, le centre noir tient sur une seule jambe.",
                              "The classical Queen's Gambit Declined pin: the f6 knight guards d5 and e4, and while it is pinned, Black's centre stands on one leg."),
                 "critical": True},
                "Be7", "e3", "h6", "Bh4", "O-O", "Nf3",
                {"san": "Ne4",
                 "comment": c("Les Noirs cherchent les échanges pour respirer. On les laisse : le fou h4 s'échange contre le fou e7, et il nous reste la meilleure structure.",
                              "Black goes for trades to breathe. We let them: the h4 bishop goes for the e7 bishop, and we keep the better structure.")},
                "Bxe7", "Qxe7",
            ],
        },
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre 2…Cf6", "vs 2…Nf6")},
            "moves": [
                "d4", "d5", "c4",
                {"san": "Nf6",
                 "comment": c("Les Noirs se développent avant de choisir. Un joueur sur sept, et le cours ne voyait que …dxc4, …e6 et …c6.",
                              "Black develops before committing. One player in seven, and the course only saw …dxc4, …e6 and …c6."),
                 "critical": True},
                "cxd5", "c6", "dxc6", "Nxc6", "Nf3", "e5", "dxe5", "Qxd1+", "Kxd1", "Ng4",
            ],
        },
        {
            "chapter": {"id": "qga-e4", "title": c("Accepté — 3.e4, le grand centre", "Accepted — 3.e4, the big centre")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "e4",
                {"san": "e6",
                 "comment": c("Un Noir sur quatre ouvre la sortie du fou f8 au lieu de frapper le centre par …e5. Le cours ne voyait que …e5.",
                              "One Black player in four opens the way for the f8 bishop instead of hitting the centre with …e5. The course only saw …e5."),
                 "critical": True},
                "Bxc4", "c5", "Nf3", "cxd4", "Nxd4", "Nf6", "Nc3", "Bc5", "Be3", "O-O",
            ],
        },
        {
            "chapter": {"id": "qga-e4", "title": c("Accepté — 3.e4, le grand centre", "Accepted — 3.e4, the big centre")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "e4",
                {"san": "b5",
                 "comment": c("La tentative de garder le pion. Un Noir sur cinq essaie, et il faut connaître la réfutation plutôt que de l'improviser à l'échiquier.",
                              "The attempt to keep the pawn. One Black player in five tries it, and the refutation must be known rather than improvised at the board."),
                 "critical": True},
                {"san": "a4",
                 "comment": c("On frappe la chaîne à sa base : les Noirs ne peuvent pas tout tenir, et chaque coup qu'ils passent à défendre ce pion nous en donne un au centre.",
                              "We hit the chain at its base: Black cannot hold everything, and every move they spend defending that pawn gives us one in the centre."),
                 "critical": True},
                "c6", "axb5", "cxb5", "Nc3", "Bd7", "d5", "a6", "e5", "e6",
            ],
        },
        {
            "chapter": {"id": "qga-classical", "title": c("Accepté — 3.Cf3, la ligne classique", "Accepted — 3.Nf3, the classical line")},
            "moves": [
                "d4", "d5", "c4", "dxc4", "Nf3",
                {"san": "e6",
                 "comment": c("Presque un Noir sur cinq, et le cours ne prévoyait que …Cf6 et …a6. Ils préparent …c5 en libérant le fou.",
                              "Nearly one Black player in five, and the course only planned for …Nf6 and …a6. They prepare …c5 while freeing the bishop."),
                 "critical": True},
                {"san": "e3",
                 "comment": c("Modeste et solide : on reprendra le pion c4 avec le fou, sans jamais avoir affaibli le centre pour y arriver.",
                              "Modest and solid: we will recapture on c4 with the bishop, having never weakened the centre to get there.")},
                "c5", "Bxc4", "Nf6", "O-O", "a6",
                {"san": "a4",
                 "comment": c("On empêche …b5 avant qu'il n'arrive. Sans cette expansion, le fou c8 des Noirs reste le problème qu'il a toujours été dans le gambit accepté.",
                              "We stop …b5 before it happens. Without that expansion, Black's c8 bishop stays the problem it has always been in the Accepted."),
                 "critical": True},
                "Nc6", "Qe2", "cxd4",
            ],
        },
    ],
}
