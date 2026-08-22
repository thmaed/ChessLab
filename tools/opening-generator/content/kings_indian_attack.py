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

        # ── Trous comblés le 22/08 : les cinq réponses noires les plus jouées
        # qu'aucun chapitre n'atteignait (coverage.py, dette 1,58). Lignes au
        # moteur (suggest.py, profondeur 22).
        #
        # ⚠ Choix éditorial : sur deux de ces trous, le moteur préfère quitter
        # le système (3.d4, Sicilienne ouverte, +0,41 contre −0,07 pour 3.d3).
        # On garde le d3 de l'Attaque Est-Indienne : un répertoire qui bascule
        # en Sicilienne ouverte n'est plus le même cours, et son intérêt — peu
        # de théorie, un plan qui se rejoue — disparaît avec lui. ─────────────
        {
            "chapter": {"id": "vs-french", "title": c("Contre la Française — …e6", "vs the French — …e6")},
            "moves": [
                "e4", "e6", "d3", "d5", "Nd2",
                {"san": "c5",
                 "comment": c("Un Noir sur quatre joue ce coup ici, et le chapitre partait de …Cf6. Les Noirs prennent l'espace à l'aile dame — exactement l'aile que nous allons leur laisser.",
                              "One Black player in four plays this here, and the chapter started from …Nf6. Black takes queenside space — precisely the wing we are going to concede."),
                 "critical": True},
                {"san": "Ngf3",
                 "comment": c("On ne conteste rien à l'aile dame : le plan de l'Attaque Est-Indienne est toujours le même — roquer, jouer e5, puis attaquer au roi. Laisser l'adversaire s'étendre là-bas fait partie du marché.",
                              "We contest nothing on the queenside: the King's Indian Attack plan is always the same — castle, play e5, then attack on the king. Letting the opponent expand over there is part of the bargain.")},
                "Be7", "g3", "Nf6", "Bg2", "O-O", "O-O", "Nc6",
                {"san": "Re1",
                 "comment": c("La tour soutient la poussée e5, qui ferme le centre et donne le signal de l'attaque. C'est le coup pivot de tout le système.",
                              "The rook supports the e5 push, which closes the centre and starts the attack. It is the pivot move of the whole system."),
                 "critical": True},
                "Qc7",
            ],
        },
        {
            "chapter": {"id": "vs-french", "title": c("Contre la Française — …e6", "vs the French — …e6")},
            "moves": [
                "e4", "e6", "d3", "d5", "Nd2",
                {"san": "dxe4",
                 "comment": c("Les Noirs libèrent la tension tout de suite. C'est le deuxième coup le plus joué ici, et le cours n'en disait rien.",
                              "Black releases the tension at once. This is the second most played move here, and the course said nothing about it."),
                 "critical": True},
                {"san": "dxe4",
                 "comment": c("Reprendre du PION, pas du cavalier : la colonne d s'ouvre pour nous, et le cavalier d2 reste libre d'aller en c4 ou f3 selon ce que les Noirs feront.",
                              "Recapture with the PAWN, not the knight: the d-file opens for us, and the d2 knight stays free to go to c4 or f3 depending on what Black does."),
                 "critical": True},
                "e5", "Ngf3", "Bd6", "Bb5+", "Bd7", "Bd3", "Nf6", "Nc4",
                {"san": "Nc6",
                 "comment": c("Position symétrique en apparence, mais nos pièces visent toutes le roque adverse — et nous avons un temps d'avance.",
                              "The position looks symmetrical, but every one of our pieces eyes Black's castled king — and we are a tempo ahead.")},
            ],
        },
        {
            "chapter": {"id": "vs-sicilian", "title": c("Contre la Sicilienne — …c5", "vs the Sicilian — …c5")},
            "moves": [
                "e4", "c5", "Nf3",
                {"san": "e6",
                 "comment": c("La Sicilienne Paulsen. Le chapitre ne prévoyait que …Cc6 et …d6 — or c'est le coup d'un joueur sur six.",
                              "The Paulsen Sicilian. The chapter only planned for …Nc6 and …d6 — yet this is one player in six's choice."),
                 "critical": True},
                {"san": "d3",
                 "comment": c("On reste dans le système. Le moteur préfère 3.d4 et la Sicilienne ouverte, mais c'est un autre répertoire : ici, on veut le même plan à chaque partie, pas vingt variantes à réviser.",
                              "We stay in the system. The engine prefers 3.d4 and the Open Sicilian, but that is a different repertoire: here we want the same plan every game, not twenty variations to revise."),
                 "critical": True},
                "d5", "exd5", "exd5", "d4", "Nc6", "Bb5", "Nf6", "O-O", "Be7", "dxc5",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "Nf3", "d5", "g3", "c5", "Bg2",
                {"san": "Nc6",
                 "comment": c("Sept Noirs sur dix développent ce cavalier ici, et le chapitre partait de …Cf6. Ils bâtissent le grand centre ; nous allons le laisser se figer.",
                              "Seven Black players in ten develop this knight here, and the chapter started from …Nf6. They build the big centre; we are going to let it freeze."),
                 "critical": True},
                {"san": "O-O",
                 "comment": c("Le roi d'abord, comme toujours dans ce système. Le centre noir ne va nulle part, et chaque coup qu'ils y consacrent est un coup qu'ils ne consacrent pas à leur roi.",
                              "The king first, as always in this system. Black's centre is going nowhere, and every move they spend on it is a move they do not spend on their king.")},
                "e5", "d3", "Be7",
                {"san": "c4",
                 "comment": c("La rupture caractéristique : on frappe le centre à distance, depuis le flanc, sans jamais l'avoir affronté de face.",
                              "The signature break: we hit the centre from the flank, at a distance, having never faced it head-on."),
                 "critical": True},
                "Nf6", "cxd5", "Nxd5", "Nc3", "Be6", "Ng5",
            ],
        },
        {
            "chapter": {"id": "vs-sicilian", "title": c("Contre la Sicilienne — …c5", "vs the Sicilian — …c5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d3",
                {"san": "e6",
                 "comment": c("Les Noirs préparent …d5 pour contester le centre. Le chapitre ne connaissait que …g6.",
                              "Black prepares …d5 to contest the centre. The chapter only knew …g6."),
                 "critical": True},
                "g3", "d5",
                {"san": "Qe2",
                 "comment": c("Le coup discret qui tient tout : la dame soutient e4 sans bloquer personne, et prépare e5 — la poussée qui ferme le centre et libère l'attaque.",
                              "The quiet move that holds everything: the queen supports e4 without blocking anyone, and prepares e5 — the push that closes the centre and unleashes the attack."),
                 "critical": True},
                "Nf6", "Bg2", "Be7",
                {"san": "e5",
                 "comment": c("Et voilà le système au complet : centre fermé, cavalier noir repoussé, et toutes nos pièces tournées vers le roque adverse.",
                              "And there is the whole system: closed centre, Black's knight pushed back, and every piece of ours aimed at their king.")},
                "Nd7", "c4", "a6",
            ],
        },
    ],
}
