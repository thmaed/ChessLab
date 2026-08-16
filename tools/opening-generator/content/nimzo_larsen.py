# -*- coding: utf-8 -*-
"""Attaque Nimzo-Larsen (1.b3) — répertoire BLANC.

Arbre : contre …e5, contre …d5, contre …Cf6/…g6. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "nimzo-larsen",
    "name": "Nimzo-Larsen Attack",
    "side": "white",
    "level": "club",
    "eco": ["A01"],
    "summary": c(
        "1.b3 : le fou dame se fianchette en b2 et vise le centre et le roque adverse sur la grande diagonale. Peu théorique, très logique, souvent piégeur.",
        "1.b3: the queen's bishop fianchettoes to b2 and eyes the centre and Black's king along the long diagonal. Little theory, very logical, often tricky.",
    ),
    "lines": [
        {
            "chapter": {"id": "vs-e5", "title": c("Contre …e5", "vs …e5")},
            "moves": [
                {"san": "b3", "eco": "Nimzo-Larsen Attack",
                 "comment": c("Le fou ira en b2 : toute la stratégie tourne autour de la grande diagonale a1-h8.",
                              "The bishop heads for b2: the whole strategy revolves around the a1-h8 diagonal.")},
                "e5", "Bb2", "Nc6", "e3", "Nf6",
                {"san": "Bb5", "comment": c("On presse c6 pour saper le défenseur de e5, cible du fou b2.",
                                            "Pressing c6 to undermine the defender of e5, the b2 bishop's target.")},
                "Bd6", "Nf3", "Qe7", "d3", "a6", "Bxc6", "dxc6", "Nbd2", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "b3", "d5", "Bb2", "Nf6", "e3", "e6", "Nf3", "Be7", "c4", "O-O", "Nc3", "c5", "cxd5", "Nxd5", "Nxd5", "exd5", "Be2", "Nc6",
            ],
        },
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre …Cf6/…g6", "vs …Nf6/…g6")},
            "moves": [
                "b3", "Nf6", "Bb2", "g6", "Nf3", "Bg7", "e3", "O-O", "Be2", "d6", "O-O", "e5", "c4", "Nbd7",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-e5", "title": c("Contre …e5", "vs …e5")},
            "moves": [
                "b3", "e5", "Bb2", "Nc6", "e3",
                {"san": "d5",
                 "comment": c("Le coup le plus joué ici — une partie sur deux — et le chapitre partait de …Cf6. Les Noirs bâtissent un gros centre : c'est exactement ce que le fou b2 attend.",
                              "The most played move here — one game in two — and the chapter started from …Nf6. Black builds a big centre: precisely what the b2 bishop is waiting for."),
                 "critical": True},
                {"san": "Bb5",
                 "comment": c("Toujours la même idée : saper c6, le défenseur de e5. Le centre noir n'est imposant que tant qu'il tient.",
                              "The same idea as ever: undermine c6, the defender of e5. Black's centre only looks impressive while it holds.")},
                "Bd6", "Nf3", "f6", "c4",
                {"san": "a6",
                 "comment": c("Les Noirs chassent le fou — et nous rendent service : après l'échange, leurs pions c sont doublés.",
                              "Black kicks the bishop — and does us a favour: after the trade, their c-pawns are doubled.")},
                "Bxc6+", "bxc6",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "b3", "d5", "Bb2",
                {"san": "Nc6",
                 "comment": c("Les Noirs préparent …e5 pour occuper la diagonale plutôt que de la subir. Le chapitre ne voyait que …Cf6.",
                              "Black prepares …e5, to occupy the diagonal rather than suffer it. The chapter only saw …Nf6."),
                 "critical": True},
                {"san": "Nf3",
                 "comment": c("On empêche …e5 d'un coup de développement : le cavalier surveille la case, sans rien concéder.",
                              "We stop …e5 with a developing move: the knight covers the square and concedes nothing.")},
                "f6", "d4",
                {"san": "Bg4",
                 "comment": c("…f6 a bouché la sortie du cavalier g8 et affaibli les cases blanches. Nous avons le centre et le meilleur jeu.",
                              "…f6 has blocked the g8 knight's exit and loosened the light squares. We have the centre and the better game.")},
                "a3", "e5", "dxe5",
            ],
        },
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre …Cf6/…g6", "vs …Nf6/…g6")},
            "moves": [
                "b3", "Nf6", "Bb2", "g6", "Nf3", "Bg7", "e3", "O-O",
                {"san": "d4",
                 "comment": c("Deux Noirs sur trois roquent ici, et le chapitre enchaînait sur Fe2. Prendre le centre est plus ambitieux : le fou g7 se retrouve face à un mur.",
                              "Two Black players in three castle here, and the chapter continued with Be2. Taking the centre is more ambitious: the g7 bishop runs into a wall."),
                 "critical": True},
                "b6", "c4", "c5", "Be2", "cxd4", "Nxd4",
                {"san": "Bb7",
                 "comment": c("Fianchettos face à face sur la grande diagonale : la partie se jouera sur qui contrôle d5 et e5.",
                              "Fianchettos facing off on the long diagonal: the game will turn on who controls d5 and e5.")},
            ],
        },
    ],
}
