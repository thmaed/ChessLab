# -*- coding: utf-8 -*-
"""Système Colle (1.d4 + e3 + Fd3) — répertoire BLANC.

Arbre : Colle-Koltanowski (c3 + rupture e4), Colle-Zukertort (b3 + Fb2 + Ce5),
et le Colle contre le fianchetto …g6. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "colle-system",
    "name": "Colle System",
    "side": "white",
    "level": "club",
    "eco": ["D04", "D05"],
    "summary": c(
        "Un système d'installation quasi automatique : d4, Cf3, e3, Fd3, c3, 0-0, puis la rupture e4. Peu de théorie, un plan d'attaque clair au petit roque.",
        "An almost automatic setup: d4, Nf3, e3, Bd3, c3, 0-0, then the e4 break. Little theory, a clear kingside attacking plan.",
    ),
    "lines": [
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "d5", "Nf3", "Nf6", "e3", "e6", "Bd3", "c5", "c3", "Nc6", "Nbd2", "Bd6", "O-O", "O-O",
                {"san": "dxc5", "comment": c("On libère la rupture e4 : après …Fxc5, e4 brise le centre et ouvre l'attaque.",
                                             "Freeing the e4 break: after …Bxc5, e4 cracks the centre and opens the attack.")},
                "Bxc5", "e4", "Qc7", "e5", "Nd7",
                {"san": "Bxh7+", "critical": True,
                 "comment": c("Le sacrifice grec, raison d'être du Colle : le fou d3 et le cavalier f3 attendaient ce moment depuis le premier coup.",
                              "The Greek gift, the whole point of the Colle: the d3 bishop and f3 knight have been waiting for this since move one.")},
                "Kxh7", "Ng5+", "Kg6", "Qc2+", "f5",
                {"san": "exf6+",
                 "comment": c("La prise en passant rouvre les lignes. Les Blancs ont au minimum l'échec perpétuel — c'est le contrat du système.",
                              "The en-passant capture reopens the lines. White has at least perpetual check — that is the system's contract.")},
                "Kxf6",
            ],
        },
        # Ce que font les Noirs quand ils ne coopèrent pas : sans cette branche,
        # le chapitre laissait croire que le sacrifice grec arrive toujours.
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "d5", "Nf3", "Nf6", "e3", "e6", "Bd3", "c5", "c3", "Nc6", "Nbd2", "Bd6", "O-O", "O-O",
                "dxc5", "Bxc5", "e4", "Qc7", "e5",
                {"san": "Nxe5", "critical": True,
                 "comment": c("La bonne réponse : on prend le pion e5 au lieu de reculer en d7, et le sacrifice grec n'a jamais lieu.",
                              "The right answer: take the e5 pawn instead of retreating to d7, and the Greek gift never happens.")},
                "Nxe5", "Qxe5", "Nb3",
                {"san": "Bb6",
                 "comment": c("Il faut le savoir : contre cette défense les Blancs n'ont pas d'attaque, seulement un pion de moins. Le Colle mise sur …Cd7.",
                              "Worth knowing: against this defence White has no attack, just a pawn less. The Colle is betting on …Nd7.")},
            ],
        },
        {
            "chapter": {"id": "zukertort", "title": c("Colle-Zukertort — b3", "Colle-Zukertort — b3")},
            "moves": [
                "d4", "d5", "Nf3", "Nf6", "e3", "e6", "Bd3", "c5", "b3", "Nc6", "Bb2", "Bd6", "O-O", "O-O",
                {"san": "Ne5", "comment": c("La version Zukertort : le fou b2 rayonne sur la grande diagonale et Ce5 lance l'attaque.",
                                            "The Zukertort version: the b2 bishop rakes the long diagonal and Ne5 launches the attack.")},
                {"san": "Qc7"},
                {"san": "f4", "critical": True,
                 "comment": c("f4 AVANT Cd2 : l'inverse laisse …Cxe5 ! fxe5 Fxe5, et le pion d4 tombe pour rien.",
                              "f4 BEFORE Nd2: the other order allows …Nxe5! fxe5 Bxe5, and the d4 pawn drops for nothing.")},
                "cxd4", "exd4", "Nb4", "Ba3",
            ],
        },
        {
            "chapter": {"id": "vs-g6", "title": c("Contre …g6", "vs …g6")},
            "moves": [
                "d4", "Nf6", "Nf3", "g6", "e3", "Bg7", "Bd3", "O-O", "O-O", "d6", "c3", "Nbd7", "Nbd2", "e5",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        #
        # Sur les trois positions, le moteur propose c4 — un Gambit Dame. Ce
        # n'est pas le sujet : le Colle se joue avec e3, Fd3 et c3. On garde le
        # système, vérifié sain.
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "Nf6", "Nf3",
                {"san": "d5",
                 "comment": c("L'ordre le plus courant, et le cours partait de 1.d4 d5. Rien ne change : le Colle se monte toujours de la même façon.",
                              "The most common order, and the course started from 1.d4 d5. Nothing changes: the Colle is always built the same way."),
                 "critical": True},
                {"san": "e3",
                 "comment": c("Le coup du système. Modeste en apparence, il prépare Fd3, c3, Cbd2 et la poussée e4 au bon moment.",
                              "The system move. Modest-looking, it prepares Bd3, c3, Nbd2 and the e4 break at the right moment.")},
                "e6", "Bd3", "c5", "c3", "Nc6", "Nbd2",
            ],
        },
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "Nf6", "Nf3",
                {"san": "e6",
                 "comment": c("Même chose avec …e6 d'abord : un joueur de Colle n'a pas à s'en soucier.",
                              "Same with …e6 first: a Colle player needn't worry about it.")},
                "e3", "d5", "Bd3", "c5", "c3", "Nc6", "Nbd2",
            ],
        },
        {
            "chapter": {"id": "vs-nc6", "title": c("Contre …Cc6", "vs …Nc6")},
            "moves": [
                "d4", "d5", "Nf3",
                {"san": "Nc6",
                 "comment": c("Le cavalier avant les pions : les Noirs préparent …Fg4 pour échanger le défenseur de e5.",
                              "Knight before pawns: Black prepares …Bg4 to trade off the defender of e5."),
                 "critical": True},
                "e3",
                {"san": "Bg4",
                 "comment": c("Le clouage annoncé. Il ne faut pas le subir passivement.",
                              "The announced pin. Don't just put up with it.")},
                {"san": "Bb5",
                 "comment": c("On répond par une pression symétrique sur c6, et le clouage noir perd son sel : leur cavalier est attaqué avant le nôtre.",
                              "We answer with mirrored pressure on c6, and Black's pin loses its sting: their knight is hit before ours."),
                 "critical": True},
                "e6", "Nbd2", "Ne7", "h3",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,95 — premier cours
        # vierge de la file). Chemins par `path_to_hole.py`.
        #
        # ⚠ Même arbitrage qu'à l'Attaque Est-Indienne : le moteur propose
        # systématiquement 3.c4, c'est-à-dire le Gambit Dame. On garde e3 et le
        # Colle. Un système dont tout l'intérêt est de se rejouer à l'identique
        # ne survit pas à un basculement vers une ouverture théorique. ─────────
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "d5", "Nf3",
                {"san": "e6",
                 "comment": c("Un Noir sur six joue …e6 avant de sortir un cavalier, et le cours ne prévoyait que …Cf6 et …Cc6. Rien ne change pour nous : le Colle se met en place quel que soit l'ordre.",
                              "One Black player in six plays …e6 before developing a knight, and the course only planned for …Nf6 and …Nc6. Nothing changes for us: the Colle sets up whatever the order."),
                 "critical": True},
                {"san": "e3",
                 "comment": c("Et non c4. C'est le choix qui définit ce répertoire : on renonce à l'avantage théorique du Gambit Dame pour une position qu'on rejoue à l'identique chaque partie.",
                              "And not c4. This is the choice that defines the repertoire: we give up the Queen's Gambit's theoretical edge for a position we replay identically every game."),
                 "critical": True},
                "Nf6", "Bd3", "c5", "O-O", "a6",
                {"san": "b3",
                 "comment": c("La version Zukertort : le fou part en b2 plutôt que le pion en c3. Contre …a6 et un centre noir mobile, la grande diagonale vaut mieux que le soutien de d4.",
                              "The Zukertort version: the bishop goes to b2 rather than the pawn to c3. Against …a6 and a mobile black centre, the long diagonal is worth more than propping up d4."),
                 "critical": True},
                "cxd4", "exd4", "Nc6",
            ],
        },
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "d5", "Nf3",
                {"san": "Bf5",
                 "comment": c("Les Noirs sortent le bon fou avant …e6 — la règle d'or, appliquée ici contre nous. Un joueur sur dix, et le cours n'en disait rien.",
                              "Black develops the good bishop before …e6 — the golden rule, applied here against us. One player in ten, and the course said nothing."),
                 "critical": True},
                "e3", "e6", "c4", "c6", "Nc3", "Nd7",
                {"san": "Bd3",
                 "comment": c("On propose l'échange du fou que les Noirs ont pris soin de sortir. S'ils acceptent, ils perdent leur meilleure pièce ; s'ils refusent, ils perdent du temps.",
                              "We offer to trade the bishop Black took care to develop. If they accept they lose their best piece; if they decline they lose time."),
                 "critical": True},
                "Bxd3", "Qxd3", "Ngf6",
            ],
        },
        {
            "chapter": {"id": "vs-kid", "title": c("Contre le fianchetto roi", "vs the King's fianchetto")},
            "moves": [
                "d4", "Nf6", "Nf3", "g6", "e3", "Bg7", "Bd3",
                {"san": "d6",
                 "comment": c("Un Noir sur quatre soutient e5 avant de roquer. Le cours partait du roque, mais l'ordre inverse est fréquent.",
                              "One Black player in four props up e5 before castling. The course started from castling, but the reverse order is common."),
                 "critical": True},
                {"san": "e4",
                 "comment": c("La rupture, tout de suite : les Noirs ont dépensé un coup en …d6 et n'ont pas encore roqué. C'est le moment exact où e4 coûte le moins cher.",
                              "The break, at once: Black has spent a move on …d6 and has not castled yet. This is precisely when e4 costs the least."),
                 "critical": True},
                "Nc6", "O-O", "O-O", "Re1", "e5", "d5", "Nb4", "Bf1", "a5",
            ],
        },
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "d5", "Nf3", "Nc6", "e3",
                {"san": "Nf6",
                 "comment": c("Plus d'un Noir sur quatre développe ainsi, et le cours ne connaissait que …Fg4.",
                              "More than one Black player in four develops like this, and the course only knew …Bg4."),
                 "critical": True},
                "Bd3",
                {"san": "Nb4",
                 "comment": c("Le cavalier vient chercher notre fou d3 — celui qui porte toute l'attaque du Colle. Il faut décider : le garder coûte un temps, l'échanger double nos pions.",
                              "The knight comes for our d3 bishop — the one that carries the whole Colle attack. A decision is needed: keeping it costs a tempo, trading doubles our pawns."),
                 "critical": True},
                "h3",
                {"san": "Nxd3+",
                 "comment": c("On accepte les pions doublés : le pion d3 soutient e4, la rupture du système. Ce qui ressemble à une faiblesse sert exactement notre plan.",
                              "We accept the doubled pawns: the d3 pawn supports e4, the system's break. What looks like a weakness serves our plan precisely."),
                 "critical": True},
                "cxd3", "Bf5", "Nc3", "e6", "O-O", "h6",
            ],
        },
        {
            "chapter": {"id": "colle", "title": c("Colle-Koltanowski — c3", "Colle-Koltanowski — c3")},
            "moves": [
                "d4", "d5", "Nf3", "Nf6", "e3",
                {"san": "Bg4",
                 "comment": c("Le clouage avant …e6 : un Noir sur cinq, et le cours ne voyait que …e6. Ils gênent Cf3, donc la rupture e4.",
                              "The pin before …e6: one Black player in five, and the course only saw …e6. They hamper Nf3, and so the e4 break."),
                 "critical": True},
                "Bd3", "Nbd7", "c4", "e5",
                {"san": "Be2",
                 "comment": c("Le fou recule pour proposer l'échange sur ses propres termes : après …Fxe2, c'est notre dame qui reprend et qui se retrouve active.",
                              "The bishop steps back to offer the trade on our terms: after …Bxe2 it is our queen that recaptures, and she ends up active."),
                 "critical": True},
                "e4", "Nfd2", "Bxe2", "Qxe2", "c6",
            ],
        },
    ],
}
