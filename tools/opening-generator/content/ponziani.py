# -*- coding: utf-8 -*-
"""Ouverture Ponziani (1.e4 e5 2.Cf3 Cc6 3.c3) — répertoire BLANC.

Une des plus vieilles ouvertures : c3 prépare d4 pour un grand centre. Peu
jouée, donc piégeuse. Arbre : 3…Cf6 et 3…d5. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "ponziani",
    "name": "Ponziani Opening",
    "side": "white",
    "level": "club",
    "eco": ["C44"],
    "summary": c(
        "Une antiquité pleine de venin : 3.c3 prépare d4 pour bâtir un grand centre. Rare, donc désarçonnante ; les deux réponses saines (…Cf6 et …d5) demandent de la précision.",
        "A venomous antique: 3.c3 prepares d4 to build a big centre. Rare, so disorienting; the two sound replies (…Nf6 and …d5) both require precision.",
    ),
    "lines": [
        # 1) 3…Cf6
        {
            "chapter": {"id": "nf6", "title": c("3…Cf6", "3…Nf6")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "c3", "eco": "Ponziani Opening",
                 "comment": c("Le coup Ponziani : c3 soutient d4, on vise un centre e4+d4 imposant.",
                              "The Ponziani move: c3 supports d4, aiming for an imposing e4+d4 centre.")},
                {"san": "Nf6", "comment": c("La réponse active : on attaque e4 pendant que le cavalier b1 n'est pas encore sorti.",
                                            "The active reply: hit e4 while White's b1-knight isn't out yet.")},
                "d4", "Nxe4", "d5", "Ne7", "Nxe5", "Ng6", "Nxg6", "hxg6",
            ],
        },
        # 2) 3…d5
        {
            "chapter": {"id": "d5", "title": c("3…d5", "3…d5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3",
                {"san": "d5", "comment": c("La réponse centrale : on frappe e4 tout de suite pour désamorcer le plan d4.",
                                           "The central reply: hit e4 at once to defuse the d4 plan.")},
                "Qa4", "f6", "Bb5", "Ne7", "exd5", "Qxd5", "d4", "e4",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-bc5", "title": c("3…Fc5 — le développement naturel", "3…Bc5 — natural development")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3",
                {"san": "Bc5",
                 "comment": c("Plus d'un quart des parties, et le cours partait de …Cf6 ou …d5. Le fou en c5 s'oppose à d4 — mais c3 a préparé exactement cela.",
                              "Over a quarter of games, and the course started from …Nf6 or …d5. The bishop on c5 opposes d4 — but c3 prepared precisely that."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("On pousse quand même. C'est la raison d'être du Ponziani : bâtir le centre avec un temps préparé.",
                              "We push anyway. That's the Ponziani's whole point: building the centre with a prepared tempo.")},
                "exd4", "cxd4", "Bb4+", "Nc3", "d5", "exd5",
            ],
        },
        {
            "chapter": {"id": "main", "title": c("Ligne principale — 3…Cf6", "Main line — 3…Nf6")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3", "Nf6", "d4",
                {"san": "exd4",
                 "comment": c("Sept Noirs sur dix prennent ici. Le cours continuait autrement et laissait donc l'élève seul dans la ligne la plus jouée.",
                              "Seven Black players in ten take here. The course went elsewhere, leaving the student alone in the most played line."),
                 "critical": True},
                {"san": "e5",
                 "comment": c("On avance plutôt que de reprendre : le cavalier f6 doit fuir et nous gagnons le temps qui paie le pion.",
                              "Push rather than recapture: the f6 knight must run, and we gain the tempo that pays for the pawn."),
                 "critical": True},
                "Nd5", "cxd4", "Bb4+", "Nbd2", "d6", "a3",
            ],
        },
    ],
}
