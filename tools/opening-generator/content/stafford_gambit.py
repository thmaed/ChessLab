# -*- coding: utf-8 -*-
"""Gambit Stafford (1.e4 e5 2.Cf3 Cf6 3.Cxe5 Cc6) — répertoire NOIR.

Une arme de blitz : objectivement douteuse, mais bourrée de pièges. Ligne
principale d'attaque + le piège classique qui gagne la dame. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "stafford-gambit",
    "name": "Stafford Gambit",
    "side": "black",
    "level": "club",
    "eco": ["C42"],
    "summary": c(
        "Un gambit surprise dans la Petrov : on rend un pion pour un développement fou et des pièges mortels sur f2 et e4. Douteux au fond, redoutable en blitz.",
        "A surprise gambit in the Petrov: give back a pawn for wild development and deadly traps on f2 and e4. Dubious at heart, lethal in blitz.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Attaque principale", "Main attack")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6",
                {"san": "Nxe5", "comment": c("Les Blancs prennent e5 ; la réponse Stafford est le surprenant …Cc6.",
                                             "White grabs e5; the Stafford reply is the surprising …Nc6.")},
                {"san": "Nc6", "eco": "Russian Game: Stafford Gambit",
                 "comment": c("Le coup Stafford : on offre un pion pour ramener le cavalier et développer à toute vitesse.",
                              "The Stafford move: offer a pawn to bring the knight back and develop at top speed.")},
                "Nxc6", "dxc6", "d3", "Bc5",
                {"san": "Nc3", "role": "trap",
                 "comment": c("Le réflexe naturel — protéger e4 — mais il perd : …Cg4 arrive et f2 s'écroule. Seul 6.Fe2 ! tient, et laisse les Blancs nettement mieux.",
                              "The natural reflex — guard e4 — but it loses: …Ng4 comes and f2 collapses. Only 6.Be2! holds, and leaves White clearly better.")},
                "Ng4", "Be3", "Bxe3", "fxe3", "Qh4+", "g3", "Qf6", "Qe2", "Ne5",
            ],
        },
        {
            "chapter": {"id": "trap", "title": c("Piège — Fg5 ?", "Trap — Bg5?")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6", "Nxe5", "Nc6", "Nxc6", "dxc6", "d3", "Bc5",
                {"san": "Bg5", "role": "trap",
                 "comment": c("Le clouage naturel… mais fatal : il tombe sur une combinaison qui gagne la dame.",
                              "The natural pin… but fatal: it runs into a combination that wins the queen.")},
                "Nxe4", "dxe4", "Bxf2+", "Kxf2", "Qxd1",
            ],
        },

        # ── Quand les Blancs refusent le gambit (16/08) ───────────────────────
        #
        # Le Stafford EST 1.e4 e5 2.Cf3 Cf6 3.Cxe5 Cc6. Si les Blancs ne
        # prennent pas en e5, il n'existe pas — et c'est le cas d'une partie
        # sur deux. Le cours n'en disait rien.
        {
            "chapter": {"id": "declined-nc3", "title": c("3.Cc3 — les Quatre Cavaliers", "3.Nc3 — the Four Knights")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6",
                {"san": "Nc3",
                 "comment": c("Un tiers des parties. Pas de prise en e5, donc pas de Stafford : on joue les Quatre Cavaliers, sainement.",
                              "A third of games. No capture on e5, so no Stafford: we play the Four Knights, soundly."),
                 "critical": True},
                "Nc6", "Bb5", "Bb4", "O-O", "O-O", "d3", "d6",
            ],
        },
        {
            "chapter": {"id": "declined-bc4", "title": c("3.Fc4 — vers les Deux Cavaliers", "3.Bc4 — into the Two Knights")},
            "moves": [
                "e4", "e5", "Nf3", "Nf6",
                {"san": "Bc4",
                 "comment": c("Près d'une partie sur cinq. Ici, contrairement à la ligne du gambit, …Cxe4 est parfaitement jouable.",
                              "Nearly one game in five. Here, unlike in the gambit line, …Nxe4 is perfectly playable."),
                 "critical": True},
                {"san": "Nxe4", "critical": True,
                 "comment": c("On prend : le cavalier reculera en c5 avec un temps, et la position est saine. Un joueur de Stafford aime ce genre de jeu.",
                              "We take: the knight will drop back to c5 with tempo, and the position is sound. A Stafford player enjoys this kind of game.")},
                "d3", "Nc5", "Nc3", "c6", "Nxe5", "d5",
            ],
        },
    ],
}
