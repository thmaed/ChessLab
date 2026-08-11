# -*- coding: utf-8 -*-
"""Nimzo-indienne et Ouest-indienne (1.d4 Cf6 2.c4 e6) — répertoire NOIR.

Arbre approfondi : Rubinstein 4.e3, Classique 4.Dc2, Sämisch 4.a3, 4.f3, et
l'Ouest-indienne 3.Cf3 b6. Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "nimzo-indian",
    "name": "Nimzo-Indian Defense",
    "side": "black",
    "level": "advanced",
    "eco": ["E20", "E59"],
    "summary": c(
        "Une des défenses les plus fiables du jeu : …Fb4 cloue le cavalier c3 pour infliger des pions doublés et contrôler e4. Si les Blancs évitent Cc3, l'Ouest-indienne prend le relais.",
        "One of the most reliable defences in chess: …Bb4 pins the c3 knight to inflict doubled pawns and control e4. If White avoids Nc3, the Queen's Indian takes over.",
    ),
    "lines": [
        # 1) Rubinstein — 4.e3
        {
            "chapter": {"id": "rubinstein", "title": c("Nimzo — Rubinstein 4.e3", "Nimzo — Rubinstein 4.e3")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nc3",
                {"san": "Bb4", "eco": "Nimzo-Indian Defense",
                 "comment": c("Le clouage Nimzowitsch : la menace …Fxc3 pèse sur la structure blanche et sur e4.",
                              "The Nimzowitsch pin: the threat of …Bxc3 weighs on White's structure and on e4.")},
                {"san": "e3", "comment": c("Rubinstein, la ligne la plus solide et la plus jouée.",
                                           "Rubinstein, the most solid and most played line.")},
                "O-O", "Bd3", "d5", "Nf3", "c5", "O-O", "Nc6", "a3", "Bxc3", "bxc3", "dxc4", "Bxc4", "Qc7",
            ],
        },
        # 2) Classique — 4.Dc2
        {
            "chapter": {"id": "classical", "title": c("Nimzo — Classique 4.Dc2", "Nimzo — Classical 4.Qc2")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nc3", "Bb4",
                {"san": "Qc2", "eco": "Nimzo-Indian Defense: Classical Variation",
                 "comment": c("La Classique : les Blancs veulent reprendre en c3 par la dame et éviter les pions doublés.",
                              "The Classical: White wants to recapture on c3 with the queen and avoid doubled pawns.")},
                "O-O", "a3", "Bxc3+", "Qxc3", "b6", "Bg5", "Bb7", "f3", "h6", "Bh4", "d5",
            ],
        },
        # 3) Sämisch — 4.a3
        {
            "chapter": {"id": "saemisch", "title": c("Nimzo — Sämisch 4.a3", "Nimzo — Sämisch 4.a3")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nc3", "Bb4",
                {"san": "a3", "comment": c("Le Sämisch : les Blancs prennent la paire de fous d'emblée, au prix de pions doublés.",
                                           "The Sämisch: White grabs the bishop pair at once, at the cost of doubled pawns.")},
                "Bxc3+", "bxc3", "c5", "e3", "Nc6", "Bd3", "O-O", "Ne2", "b6", "e4", "Ne8",
            ],
        },
        # 4) 4.f3 (moderne, agressif)
        {
            "chapter": {"id": "f3", "title": c("Nimzo — 4.f3", "Nimzo — 4.f3")},
            "moves": [
                "d4", "Nf6", "c4", "e6", "Nc3", "Bb4",
                {"san": "f3", "comment": c("Les Blancs veulent e4 à tout prix. La réponse énergique est …d5 au centre.",
                                           "White wants e4 at all costs. The energetic reply is …d5 in the centre.")},
                "d5", "a3", "Bxc3+", "bxc3", "c5", "cxd5", "Nxd5", "dxc5", "Qa5",
            ],
        },
        # 5) Ouest-indienne — 3.Cf3 b6
        {
            "chapter": {"id": "queens-indian", "title": c("Ouest-indienne — 3.Cf3 b6", "Queen's Indian — 3.Nf3 b6")},
            "moves": [
                "d4", "Nf6", "c4", "e6",
                {"san": "Nf3", "comment": c("Les Blancs évitent le clouage …Fb4. Les Noirs passent à l'Ouest-indienne.",
                                            "White sidesteps the …Bb4 pin. Black switches to the Queen's Indian.")},
                {"san": "b6", "eco": "Queen's Indian Defense",
                 "comment": c("Le fou dame se fianchette en b7 et dispute e4 à distance.",
                              "The queen's bishop fianchettoes to b7 and contests e4 from afar.")},
                "g3", "Bb7", "Bg2", "Be7", "O-O", "O-O", "Nc3", "Ne4", "Qc2", "Nxc3", "Qxc3", "c5",
            ],
        },
    ],
}
