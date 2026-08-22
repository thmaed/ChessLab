# -*- coding: utf-8 -*-
"""Partie viennoise (1.e4 e5 2.Cc3) + gambit viennois — répertoire BLANC.

Approfondie : gambit viennois, Frankenstein-Dracula (3.Fc4 Cxe4), 2…Cc6 3.f4.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "vienna-game",
    "name": "Vienna Game",
    "side": "white",
    "level": "club",
    "eco": ["C25", "C29"],
    "summary": c(
        "Une cousine agressive de l'italienne : 2.Cc3 prépare f4. Peu jouée, donc redoutable en club — et truffée de pièges, jusqu'au fou Frankenstein-Dracula.",
        "An aggressive cousin of the Italian: 2.Nc3 prepares f4. Rarely played, so dangerous at club level — and full of traps, right up to the Frankenstein-Dracula.",
    ),
    "lines": [
        {
            "chapter": {"id": "vienna-gambit", "title": c("Gambit viennois", "Vienna Gambit")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6",
                {"san": "f4", "eco": "Vienna Game: Vienna Gambit",
                 "comment": c("Le gambit viennois : on ouvre la colonne f pour une attaque directe sur le roi.",
                              "The Vienna Gambit: opening the f-file for a direct attack on the king.")},
                {"san": "d5", "comment": c("La bonne réaction : contre-attaquer au centre plutôt que prendre en f4.",
                                           "The right reaction: counterattack in the centre rather than take on f4.")},
                "fxe5", "Nxe4", "Nf3", "Be7", "d4", "O-O", "Bd3", "f5", "exf6", "Bxf6",
            ],
        },
        {
            "chapter": {"id": "frankenstein", "title": c("Frankenstein-Dracula — 3.Fc4 Cxe4", "Frankenstein-Dracula — 3.Bc4 Nxe4")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6",
                {"san": "Bc4", "comment": c("Le développement tranquille… qui tend un piège si les Noirs sont gourmands.",
                                            "Quiet development… that lays a trap if Black gets greedy.")},
                {"san": "Nxe4", "role": "inaccuracy", "critical": True,
                 "comment": c("Prendre e4 lance la mêlée Frankenstein-Dracula : des complications monstrueuses attendent.",
                              "Grabbing e4 unleashes the Frankenstein-Dracula: monstrous complications await.")},
                {"san": "Qh5", "role": "refutation", "critical": True,
                 "comment": c("La dame attaque le cavalier e4 ET menace mat en f7.",
                              "The queen hits the e4 knight AND threatens mate on f7.")},
                "Nd6", "Bb3", "Nc6", "Nb5", "g6", "Qf3", "f5", "Qd5", "Qe7", "Nxc7+", "Kd8", "Nxa8", "b6",
            ],
        },
        {
            "chapter": {"id": "2nc6", "title": c("2…Cc6 3.f4", "2…Nc6 3.f4")},
            "moves": [
                "e4", "e5", "Nc3", "Nc6",
                {"san": "f4", "comment": c("Même idée : on attaque e5 et on ouvre la colonne f.",
                                           "Same idea: hit e5 and open the f-file.")},
                "exf4", "Nf3", "g5", "d4", "g4", "Bxf4", "gxf3", "Qxf3",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vienna-gambit", "title": c("Gambit viennois — 3.f4", "Vienna Gambit — 3.f4")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6", "f4",
                {"san": "exf4",
                 "comment": c("Accepter est le coup principal — près de quatre Noirs sur dix — et le chapitre partait de …d5.",
                              "Accepting is the main move — nearly four Black players in ten — and the chapter started from …d5."),
                 "critical": True},
                {"san": "e5",
                 "comment": c("Le coup qui donne son sens au gambit : le pion chasse le cavalier avant qu'il ne s'installe, et la colonne f s'ouvrira pour notre tour.",
                              "The move that justifies the gambit: the pawn kicks the knight before it settles, and the f-file will open for our rook."),
                 "critical": True},
                "Ng8", "Nf3", "d6", "d4", "dxe5", "Bb5+",
            ],
        },
        {
            "chapter": {"id": "vs-d6", "title": c("2…d6 — l'installation Philidor", "2…d6 — the Philidor setup")},
            "moves": [
                "e4", "e5", "Nc3",
                {"san": "d6",
                 "comment": c("Les Noirs bâtissent une Philidor. On peut immédiatement liquider au centre et gagner l'échange de dames dans de bonnes conditions.",
                              "Black builds a Philidor. We can liquidate in the centre at once and trade queens on favourable terms.")},
                "d4", "Nf6", "dxe5", "dxe5",
                {"san": "Qxd8+",
                 "comment": c("On échange volontairement les dames : le roi noir perd le roque, et une finale légèrement meilleure vaut mieux qu'une attaque imaginaire.",
                              "We deliberately trade queens: Black's king loses castling rights, and a slightly better endgame beats an imaginary attack."),
                 "critical": True},
                "Kxd8", "Nf3", "Bd6",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,78). ────────────────
        {
            "chapter": {"id": "vienna-bc4", "title": c("Viennoise — 3.Fc4", "Vienna — 3.Bc4")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6", "Bc4",
                {"san": "Bc5",
                 "comment": c("Un Noir sur trois développe simplement au lieu de prendre en e4 — et le cours ne prévoyait QUE …Cxe4, c'est-à-dire le piège. Il faut aussi savoir jouer quand l'adversaire ne tombe pas dedans.",
                              "One Black player in three simply develops instead of taking on e4 — and the course only planned for …Nxe4, the trap. You also need to know how to play when the opponent does not fall for it."),
                 "critical": True},
                {"san": "d3",
                 "comment": c("On renonce à forcer. La Viennoise devient un jeu de manœuvre où notre cavalier c3 et le fou c4 pressent d5 et f7 sans se découvrir.",
                              "We give up on forcing matters. The Vienna becomes a manoeuvring game where our c3 knight and c4 bishop press d5 and f7 without committing."),
                 "critical": True},
                "c6", "Nf3", "d6", "O-O", "a5", "a3", "O-O", "h3", "Ba7",
            ],
        },
        {
            "chapter": {"id": "vienna-bc4", "title": c("Viennoise — 3.Fc4", "Vienna — 3.Bc4")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6", "Bc4",
                {"san": "Nc6",
                 "comment": c("Un Noir sur cinq développe le second cavalier, et le cours ne le prévoyait pas non plus.",
                              "One Black player in five develops the second knight, and the course did not plan for this either."),
                 "critical": True},
                "d3",
                {"san": "Na5",
                 "comment": c("Les Noirs vont chercher notre fou c4 — la pièce qui donne son mordant à la Viennoise. C'est le plan à connaître car il est fréquent et logique.",
                              "Black goes after our c4 bishop — the piece that gives the Vienna its bite. Worth knowing, because the plan is frequent and logical."),
                 "critical": True},
                "Nge2", "Bc5", "O-O", "c6", "a4",
                {"san": "Nxc4",
                 "comment": c("On reprend du pion d : la colonne d s'ouvre et le pion c4 contrôle d5, la case que toute la Viennoise dispute.",
                              "We recapture with the d-pawn: the d-file opens and the c4 pawn controls d5, the square the whole Vienna fights over."),
                 "critical": True},
                "dxc4", "a5",
            ],
        },
        {
            "chapter": {"id": "vienna-gambit", "title": c("Gambit viennois — 3.f4", "Vienna Gambit — 3.f4")},
            "moves": [
                "e4", "e5", "Nc3", "Nc6", "f4",
                {"san": "d6",
                 "comment": c("Un Noir sur cinq refuse le gambit en soutenant e5, et le cours ne voyait que la prise …exf4.",
                              "One Black player in five declines the gambit by propping up e5, and the course only saw the capture …exf4."),
                 "critical": True},
                "Nf3",
                {"san": "Nd4",
                 "comment": c("Le saut au centre pour échanger notre meilleur défenseur du pion e5. On accepte l'échange, mais on reprend du FOU : il arrivera en f3 avec un temps.",
                              "The central jump to trade off our best defender of e5. We allow the trade, but recapture with the BISHOP: it lands on f3 with tempo."),
                 "critical": True},
                "d3", "Ne7", "Be2", "Nxf3+", "Bxf3", "exf4", "Bxf4", "Ng6",
            ],
        },
        {
            "chapter": {"id": "vienna-gambit", "title": c("Gambit viennois — 3.f4", "Vienna Gambit — 3.f4")},
            "moves": [
                "e4", "e5", "Nc3", "Nf6", "f4",
                {"san": "d6",
                 "comment": c("Le refus solide : les Noirs soutiennent e5 sans se compromettre. Un joueur sur cinq, et le cours ne prévoyait que …d5 et …exf4.",
                              "The solid decline: Black props up e5 without committing. One player in five, and the course only planned for …d5 and …exf4."),
                 "critical": True},
                "Nf3", "Be7",
                {"san": "fxe5",
                 "comment": c("On ouvre maintenant, avant qu'ils ne roquent : la colonne f s'ouvre vers f7 et le cavalier f3 saute en e5 avec un temps.",
                              "We open now, before they castle: the f-file opens towards f7 and the f3 knight jumps to e5 with tempo."),
                 "critical": True},
                "dxe5", "Nxe5", "Nxe4", "Nxe4", "Qd4", "d3", "Qxe5",
            ],
        },
        {
            "chapter": {"id": "vs-philidor", "title": c("Contre …d6", "vs …d6")},
            "moves": [
                "e4", "e5", "Nc3", "d6", "d4",
                {"san": "exd4",
                 "comment": c("Près de six Noirs sur dix relâchent la tension, et le cours ne voyait que …Cf6.",
                              "Nearly six Black players in ten release the tension, and the course only saw …Nf6."),
                 "critical": True},
                {"san": "Qxd4",
                 "comment": c("On reprend de la dame : aucun cavalier noir ne peut la chasser avec gain de temps, et elle rejoindra c4 ou a4 selon ce qu'ils feront.",
                              "We recapture with the queen: no black knight can chase her with tempo, and she will go to c4 or a4 depending on what they do."),
                 "critical": True},
                "Nc6", "Bb5", "Nf6", "Qc4", "Bd7", "Bf4", "Be7",
                {"san": "O-O-O",
                 "comment": c("Grand roque et rois opposés : la colonne d est ouverte, notre tour y arrive la première, et c'est une course d'attaques où nous avons l'avance.",
                              "Castling long, opposite kings: the d-file is open, our rook gets there first, and it is a race of attacks in which we lead."),
                 "critical": True},
                "O-O",
            ],
        },
    ],
}
