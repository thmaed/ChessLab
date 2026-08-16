# -*- coding: utf-8 -*-
"""Ouverture Bird (1.f4) — répertoire BLANC.

Arbre : classique (hollandaise inversée, attaque Fe1-h4), gambit From 1…e5,
et l'installation solide contre …e6. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "birds-opening",
    "name": "Bird's Opening",
    "side": "white",
    "level": "club",
    "eco": ["A02", "A03"],
    "summary": c(
        "1.f4 : une hollandaise avec les Blancs, un temps en plus. On contrôle e5, on fianchette ou on installe un Stonewall, puis on attaque le roque adverse.",
        "1.f4: a Dutch with White, a tempo up. Control e5, fianchetto or set up a Stonewall, then attack the enemy king.",
    ),
    "lines": [
        {
            "chapter": {"id": "classical", "title": c("Classique — hollandaise inversée", "Classical — reversed Dutch")},
            "moves": [
                {"san": "f4", "eco": "Bird's Opening",
                 "comment": c("On prend d'emblée le contrôle de e5 : c'est une hollandaise avec un temps de plus.",
                              "Grab control of e5 at once: it's a Dutch a tempo up.")},
                "d5", "Nf3", "Nf6", "e3", "g6", "Be2", "Bg7", "O-O", "O-O", "d3", "c5", "Nbd2", "Nc6", "Qe1", "b6", "Qh4", "Bb7",
            ],
        },
        {
            "chapter": {"id": "from", "title": c("Gambit From — 1…e5", "From's Gambit — 1…e5")},
            "moves": [
                "f4",
                {"san": "e5", "comment": c("Le gambit From : un pion pour l'attaque. La bonne voie est de rendre le pion et de finir bien placé.",
                                           "From's Gambit: a pawn for attack. The right path is to return the pawn and end up well placed.")},
                "fxe5", "d6", "exd6", "Bxd6", "Nf3", "g5", "d4", "g4", "Ne5", "Bxe5", "dxe5", "Qxd1+", "Kxd1", "Nc6",
            ],
        },
        {
            "chapter": {"id": "vs-e6", "title": c("Installation solide contre …e6", "Solid setup vs …e6")},
            "moves": [
                "f4", "d5", "Nf3", "Nf6", "e3", "e6", "b3", "Be7", "Bb2", "O-O", "Be2", "c5", "O-O", "Nc6",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "classical", "title": c("Classique — hollandaise inversée", "Classical — reversed Dutch")},
            "moves": [
                "f4", "d5", "Nf3",
                {"san": "Nc6",
                 "comment": c("Plus d'un quart des parties, et le chapitre n'en parlait pas. Les Noirs préparent …Fg4 et …e5.",
                              "More than a quarter of games, and the chapter didn't mention it. Black prepares …Bg4 and …e5."),
                 "critical": True},
                "e3",
                {"san": "Bg4",
                 "comment": c("Le fou sort avant …e6 pour ne pas rester enfermé — bonne méthode, mais elle nous laisse un temps.",
                              "The bishop comes out before …e6 so as not to be shut in — good method, but it hands us a tempo.")},
                {"san": "Bb5",
                 "comment": c("On attaque le défenseur de e5 : c'est le point sensible de toute installation noire contre la Bird.",
                              "We hit the defender of e5: the sore point of every Black setup against the Bird.")},
                "e6", "h3", "Bh5", "Bxc6+",
                {"san": "bxc6",
                 "comment": c("Pions doublés, et la case e5 nous revient pour de bon.",
                              "Doubled pawns, and the e5 square is ours for good.")},
            ],
        },
        {
            "chapter": {"id": "from", "title": c("Gambit From — 1…e5", "From's Gambit — 1…e5")},
            "moves": [
                "f4", "e5", "fxe5",
                {"san": "Nc6",
                 "comment": c("La version moderne du gambit : au lieu de …d6 tout de suite, les Noirs développent et gardent la menace.",
                              "The modern version of the gambit: instead of …d6 at once, Black develops and keeps the threat alive."),
                 "critical": True},
                {"san": "Nf3",
                 "comment": c("On rend le pion au bon moment plutôt que de s'y accrocher : c'est l'erreur classique dans le From.",
                              "Give the pawn back at the right moment rather than clinging to it: that's the classic mistake against From's.")},
                "d6", "exd6", "Bxd6", "d4", "Nf6", "Nc3",
            ],
        },
        {
            "chapter": {"id": "vs-c5", "title": c("Contre …c5", "vs …c5")},
            "moves": [
                "f4", "d5", "Nf3",
                {"san": "c5",
                 "comment": c("Les Noirs jouent une hollandaise inversée à leur tour. La partie devient une bataille de plans, pas de théorie.",
                              "Black plays a reversed Dutch in turn. The game becomes a battle of plans, not theory.")},
                "e3", "a6", "b3",
                {"san": "Bf5",
                 "comment": c("Double fianchetto contre développement classique : on jouera Ch4 pour échanger ce fou, notre meilleure pièce adverse.",
                              "Double fianchetto against classical development: we'll play Nh4 to trade that bishop, our opponent's best piece.")},
                "Nh4", "Bd7", "g3",
            ],
        },
    ],
}
