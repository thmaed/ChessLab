# -*- coding: utf-8 -*-
"""Attaque est-indienne / KIA (Cf3, g3, Fg2, 0-0, d3, e4) — répertoire BLANC.

Arbre : contre la Française (…e6/…d5), contre …d5, contre la Sicilienne (…c5).
Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "kings-indian-attack",
    "name": "King's Indian Attack",
    "side": "white",
    "level": "club",
    "eco": ["A07", "A08"],
    "summary": c(
        "Un système à jouer contre tout ce qui commence par …e6 ou …d5 : Cf3, g3, Fg2, 0-0, d3, e4. On attaque à l'aile roi par e5, Cf1-h2-g4 et f4.",
        "A setup to play against anything starting …e6 or …d5: Nf3, g3, Bg2, 0-0, d3, e4. Attack on the kingside with e5, Nf1-h2-g4 and f4.",
    ),
    "lines": [
        {
            "chapter": {"id": "vs-french", "title": c("Contre la Française — …e6", "vs the French — …e6")},
            "moves": [
                "e4", "e6", "d3", "d5", "Nd2", "Nf6", "Ngf3", "c5", "g3", "Nc6", "Bg2", "Be7", "O-O", "O-O", "Re1",
                {"san": "b5", "comment": c("Chacun attaque sur son aile : les Noirs à gauche, les Blancs par e5 puis Cf1-h2-g4.",
                                           "Each side attacks on its wing: Black on the left, White with e5 then Nf1-h2-g4.")},
                "e5", "Nd7", "Nf1", "a5", "h4", "b4",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "Nf3", "d5", "g3", "Nf6", "Bg2", "e6", "O-O", "Be7", "d3", "O-O", "Nbd2", "c5", "e4", "Nc6", "Re1", "Qc7", "e5", "Nd7",
                {"san": "Qe2", "critical": True,
                 "comment": c("Il faut d'abord surdéfendre e5 : 10.Cf1 tout de suite perd le pion sur …Cdxe5 !, la dame c7 appuyant la prise.",
                              "e5 must be over-defended first: 10.Nf1 at once drops the pawn to …Ndxe5!, backed up by the c7 queen.")},
                "b5", "Nf1", "a5",
            ],
        },
        {
            "chapter": {"id": "vs-sicilian", "title": c("Contre la Sicilienne — …c5", "vs the Sicilian — …c5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d3", "g6", "g3", "Bg7", "Bg2", "e5", "O-O", "Nge7", "Nbd2", "O-O", "a3", "d6",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        #
        # Sur ces trois positions le moteur propose d4 — c'est-à-dire une
        # Sicilienne ouverte ou une Anglaise. Ce serait quitter le système que
        # l'élève est venu apprendre. On garde d3 et le fianchetto : c'est le
        # sujet du cours, et c'est parfaitement sain.
        {
            "chapter": {"id": "vs-sicilian", "title": c("Contre la Sicilienne — …c5", "vs the Sicilian — …c5")},
            "moves": [
                "e4", "c5", "Nf3",
                {"san": "d6",
                 "comment": c("Près d'un Sicilien sur trois joue …d6 avant de sortir le cavalier, et le chapitre partait de …Cc6.",
                              "Nearly one Sicilian player in three plays …d6 before developing the knight, and the chapter started from …Nc6."),
                 "critical": True},
                {"san": "d3",
                 "comment": c("Le coup du système : on renonce à d4 et à toute théorie sicilienne. La partie se jouera sur nos termes.",
                              "The system move: we give up d4 and all Sicilian theory. The game will be played on our terms.")},
                "Nf6", "g3", "g6", "Bg2", "Bg7", "O-O",
                {"san": "Nc6",
                 "comment": c("Structure symétrique, mais c'est nous qui connaissons le plan : Cbd2, Te1, e5 puis Cf1-h2-g4.",
                              "A symmetrical structure — but we're the ones who know the plan: Nbd2, Re1, e5, then Nf1-h2-g4.")},
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "Nf3", "d5", "g3",
                {"san": "Nc6",
                 "comment": c("Les Noirs préparent …e5 pour prendre le centre avant nous. Le chapitre ne voyait que …Cf6.",
                              "Black prepares …e5 to seize the centre first. The chapter only saw …Nf6."),
                 "critical": True},
                {"san": "Bg2",
                 "comment": c("On ne s'en émeut pas : le fou file en g2 et prendra le pion d5 pour cible dès qu'il avancera.",
                              "No cause for alarm: the bishop heads to g2 and will target the d5 pawn as soon as it advances.")},
                "e5", "d3", "Be6", "O-O", "Qd7",
                {"san": "e4",
                 "comment": c("Le moment du système : on frappe d5 au centre. Après l'échange, le fou g2 respire enfin.",
                              "The system's moment: we hit d5 in the centre. After the trade, the g2 bishop breathes at last."),
                 "critical": True},
                "dxe4", "dxe4",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "Nf3", "d5", "g3",
                {"san": "c5",
                 "comment": c("L'ordre le plus fréquent après …Cc6, et lui non plus n'était pas traité.",
                              "The next most common order after …Nc6, and it wasn't covered either.")},
                "Bg2", "Nf6", "O-O", "e6", "d4",
                {"san": "cxd4",
                 "comment": c("Ici, exceptionnellement, d4 est le bon coup : les Noirs ont déjà engagé …c5 et …e6, la structure est celle d'une Catalane, pas d'un système où l'on temporise.",
                              "Here, exceptionally, d4 is right: Black has already committed to …c5 and …e6, and the structure is a Catalan one, not a system where we bide our time.")},
                "Nxd4", "e5",
            ],
        },
    ],
}
