# -*- coding: utf-8 -*-
"""Sicilienne Scheveningen (1.e4 c5 2.Cf3 e6 3.d4 cxd4 4.Cxd4 Cf6 5.Cc3 d6) — NOIR.

Le « petit centre » …e6/…d6 : élastique et solide, prêt à se détendre par …d5
ou …e5. Arbre : Classique 6.Fe2, attaque Keres 6.g4, et 6.f4 (roques opposés).
Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-scheveningen",
    "name": "Sicilian Defense: Scheveningen",
    "side": "black",
    "level": "advanced",
    "eco": ["B80", "B89"],
    "summary": c(
        "Le petit centre …e6/…d6 : une structure élastique, sans faiblesse, prête à se détendre par …d5 ou …e5 au bon moment. Base de nombreuses siciliennes.",
        "The small centre …e6/…d6: an elastic, weakness-free structure ready to uncoil with …d5 or …e5 at the right moment. The basis of many Sicilians.",
    ),
    "lines": [
        # 1) Classique — 6.Fe2
        {
            "chapter": {"id": "classical", "title": c("Classique — 6.Fe2", "Classical — 6.Be2")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3",
                {"san": "d6", "eco": "Sicilian Defense: Scheveningen Variation",
                 "comment": c("Le petit centre : …e6 et …d6, souple et solide, avec …d5/…e5 en réserve.",
                              "The small centre: …e6 and …d6, flexible and solid, with …d5/…e5 in reserve.")},
                {"san": "Be2", "comment": c("Le développement classique : petit roque et jeu de manœuvre.",
                                            "The classical development: short castling and manoeuvring play.")},
                "a6", "O-O", "Be7", "f4", "O-O", "Kh1", "Nc6", "Be3", "Bd7", "Nb3", "b5",
            ],
        },
        # 2) Attaque Keres — 6.g4
        {
            "chapter": {"id": "keres", "title": c("Attaque Keres — 6.g4", "Keres Attack — 6.g4")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "d6",
                {"san": "g4", "comment": c("L'attaque Keres : g4-g5 chasse le cavalier f6, gardien de d5/e4. Très tranchant.",
                                           "The Keres Attack: g4-g5 chases the f6-knight, guardian of d5/e4. Very sharp.")},
                "h6", "h4", "Nc6", "Rg1", "h5", "gxh5", "Nxh5",
            ],
        },
        # 3) 6.f4 — roques opposés
        {
            "chapter": {"id": "f4", "title": c("6.f4 — roques opposés", "6.f4 — opposite castling")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "d6",
                {"san": "f4", "comment": c("Le centre e4+f4 vise e5 et f5 ; suivi de Df3 et 0-0-0, c'est la course aux ailes.",
                                           "The e4+f4 centre eyes e5 and f5; with Qf3 and 0-0-0 it becomes a race on the wings.")},
                "Nc6", "Be3", "Be7", "Qf3", "O-O", "O-O-O", "Nxd4", "Bxd4",
                {"san": "Qa5", "critical": True,
                 "comment": c("La dame sort AVANT …b5 : la poussée immédiate perd la tour a8 après Fxf6 gxf6 puis e5.",
                              "The queen comes out BEFORE …b5: the immediate push drops the a8 rook to Bxf6 gxf6 and e5.")},
                "e5", "dxe5", "Bxe5", "Nd7",
            ],
        },
    ],
}
