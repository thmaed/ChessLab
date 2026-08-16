# -*- coding: utf-8 -*-
"""Sicilienne Taimanov (1.e4 c5 2.Cf3 e6 3.d4 cxd4 4.Cxd4 Cc6) — NOIR.

Souple et solide : …e6 + …Cc6, en gardant …Db6/…Fb4/…a6 en réserve. Arbre :
5.Cc3 Dc7 (Bastrikov, attaque anglaise), 5.Cb5 d6 (étau Maroczy), 5.Cc3 a6
classique. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-taimanov",
    "name": "Sicilian Defense: Taimanov",
    "side": "black",
    "level": "advanced",
    "eco": ["B44", "B49"],
    "summary": c(
        "Une sicilienne flexible : …e6 et …Cc6 sans se dévoiler. Les Noirs choisissent tard entre …Db6, …Fb4, …a6 et …d6 selon ce que font les Blancs.",
        "A flexible Sicilian: …e6 and …Nc6 without committing. Black decides late between …Qb6, …Bb4, …a6 and …d6 depending on White.",
    ),
    "lines": [
        # 1) Bastrikov — 5.Cc3 Dc7, attaque anglaise
        {
            "chapter": {"id": "bastrikov", "title": c("Bastrikov — 5.Cc3 Dc7", "Bastrikov — 5.Nc3 Qc7")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4", "Nc6", "Nc3",
                {"san": "Qc7", "eco": "Sicilian Defense: Taimanov Variation",
                 "comment": c("La dame en c7 : elle presse e5/c-file et garde toutes les options de développement.",
                              "The queen on c7: it presses e5 and the c-file and keeps every developing option open.")},
                "Be3", "a6",
                {"san": "Qd2", "comment": c("L'attaque anglaise : Dd2, 0-0-0, puis f3 et g4 contre le roque noir.",
                                            "The English Attack: Qd2, 0-0-0, then f3 and g4 against Black's king.")},
                "Nf6", "O-O-O", "Bb4", "f3", "Ne5", "Nb3", "b5",
            ],
        },
        # 2) 5.Cb5 d6 — étau Maroczy
        {
            "chapter": {"id": "nb5", "title": c("5.Cb5 d6 — étau Maroczy", "5.Nb5 d6 — Maróczy bind")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4", "Nc6",
                {"san": "Nb5", "comment": c("Le saut Cb5 force …d6 (sinon Cd6+), puis c4 pose l'étau Maroczy.",
                                            "The Nb5 jump forces …d6 (else Nd6+), then c4 sets the Maróczy bind.")},
                "d6", "c4", "Nf6", "N1c3", "a6", "Na3", "Be7", "Be2", "O-O",
            ],
        },
        # 3) 5.Cc3 a6 — classique
        {
            "chapter": {"id": "classical", "title": c("5.Cc3 a6 — classique", "5.Nc3 a6 — classical")},
            "moves": [
                "e4", "c5", "Nf3", "e6", "d4", "cxd4", "Nxd4", "Nc6", "Nc3",
                {"san": "a6", "comment": c("Le coup souple : …a6 prévient Cb5/Fb5 et prépare …Dc7, …Cf6, …b5.",
                                           "The flexible move: …a6 rules out Nb5/Bb5 and prepares …Qc7, …Nf6, …b5.")},
                "Be2", "Nf6", "O-O", "Qc7", "Be3", "Be7", "f4", "d6",
            ],
        },

        # ── Le fou en c4, qui empêche la Sicilienne ouverte (16/08) ───────────
        #
        # Toutes les Siciliennes de ce répertoire supposent 2.Cf3 puis 3.d4.
        # Les sorties précoces du fou en c4 l'évitent, et aucun cours ne les
        # traitait. Le remède est le même partout — …e6 coupe la diagonale et
        # prépare …d5 — mais il fallait l'écrire.
        {
            "chapter": {"id": "vs-bc4", "title": c("2.Fc4 et 3.Fc4", "2.Bc4 and 3.Bc4")},
            "moves": [
                "e4", "c5",
                {"san": "Bc4",
                 "comment": c("Le fou sort avant tout, en visant f7. Sans centre pour l'appuyer, l'attaque n'arrivera jamais.",
                              "The bishop develops first, eyeing f7. With no centre behind it, the attack never comes."),
                 "critical": True},
                {"san": "e6", "critical": True,
                 "comment": c("On coupe la diagonale et l'on prépare …d5. Le fou c4 devra bouger une seconde fois — deux temps perdus pour les Blancs.",
                              "We cut the diagonal and prepare …d5. The c4 bishop must move again — two tempi lost for White.")},
                "Nf3", "Nf6", "Qe2", "a6", "d3", "b5",
                {"san": "Bb3",
                 "comment": c("Le fou recule, et notre expansion à l'aile dame est gratuite : c'est exactement le jeu qu'une Sicilienne cherche.",
                              "The bishop retreats and our queenside expansion is free: precisely the kind of play a Sicilian wants.")},
            ],
        },
        {
            "chapter": {"id": "vs-bc4", "title": c("2.Fc4 et 3.Fc4", "2.Bc4 and 3.Bc4")},
            "moves": [
                "e4", "c5", "Nf3", "e6",
                {"san": "Bc4",
                 "comment": c("Une partie sur sept après 2…e6. Même traitement : on développe, on pousse …b5, et le fou perd son temps.",
                              "One game in seven after 2…e6. Same treatment: develop, play …b5, and the bishop loses time.")},
                "Nf6", "Qe2", "a6", "Bb3", "b5", "d3",
            ],
        },
    ],
}
