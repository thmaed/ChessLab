# -*- coding: utf-8 -*-
"""Attaque Nimzo-Larsen (1.b3) — répertoire BLANC.

Arbre : contre …e5, contre …d5, contre …Cf6/…g6. Lignes vérifiées.
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
    ],
}
