# -*- coding: utf-8 -*-
"""Attaque Nimzo-Larsen (1.b3) — répertoire BLANC.

Arbre : contre …e5, contre …d5, contre …Cf6/…g6. Lignes passées à l'audit moteur (`audit.py`).
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

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-e5", "title": c("Contre …e5", "vs …e5")},
            "moves": [
                "b3", "e5", "Bb2", "Nc6", "e3",
                {"san": "d5",
                 "comment": c("Le coup le plus joué ici — une partie sur deux — et le chapitre partait de …Cf6. Les Noirs bâtissent un gros centre : c'est exactement ce que le fou b2 attend.",
                              "The most played move here — one game in two — and the chapter started from …Nf6. Black builds a big centre: precisely what the b2 bishop is waiting for."),
                 "critical": True},
                {"san": "Bb5",
                 "comment": c("Toujours la même idée : saper c6, le défenseur de e5. Le centre noir n'est imposant que tant qu'il tient.",
                              "The same idea as ever: undermine c6, the defender of e5. Black's centre only looks impressive while it holds.")},
                "Bd6", "Nf3", "f6", "c4",
                {"san": "a6",
                 "comment": c("Les Noirs chassent le fou — et nous rendent service : après l'échange, leurs pions c sont doublés.",
                              "Black kicks the bishop — and does us a favour: after the trade, their c-pawns are doubled.")},
                "Bxc6+", "bxc6",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "b3", "d5", "Bb2",
                {"san": "Nc6",
                 "comment": c("Les Noirs préparent …e5 pour occuper la diagonale plutôt que de la subir. Le chapitre ne voyait que …Cf6.",
                              "Black prepares …e5, to occupy the diagonal rather than suffer it. The chapter only saw …Nf6."),
                 "critical": True},
                {"san": "Nf3",
                 "comment": c("On empêche …e5 d'un coup de développement : le cavalier surveille la case, sans rien concéder.",
                              "We stop …e5 with a developing move: the knight covers the square and concedes nothing.")},
                "f6", "d4",
                {"san": "Bg4",
                 "comment": c("…f6 a bouché la sortie du cavalier g8 et affaibli les cases blanches. Nous avons le centre et le meilleur jeu.",
                              "…f6 has blocked the g8 knight's exit and loosened the light squares. We have the centre and the better game.")},
                "a3", "e5", "dxe5",
            ],
        },
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre …Cf6/…g6", "vs …Nf6/…g6")},
            "moves": [
                "b3", "Nf6", "Bb2", "g6", "Nf3", "Bg7", "e3", "O-O",
                {"san": "d4",
                 "comment": c("Deux Noirs sur trois roquent ici, et le chapitre enchaînait sur Fe2. Prendre le centre est plus ambitieux : le fou g7 se retrouve face à un mur.",
                              "Two Black players in three castle here, and the chapter continued with Be2. Taking the centre is more ambitious: the g7 bishop runs into a wall."),
                 "critical": True},
                "b6", "c4", "c5", "Be2", "cxd4", "Nxd4",
                {"san": "Bb7",
                 "comment": c("Fianchettos face à face sur la grande diagonale : la partie se jouera sur qui contrôle d5 et e5.",
                              "Fianchettos facing off on the long diagonal: the game will turn on who controls d5 and e5.")},
            ],
        },

        # ── Trous comblés le 21/08 : les cinq réponses noires les plus jouées
        # au 2e coup, qu'aucun chapitre n'atteignait (coverage.py, dette 1,83 —
        # la plus lourde du catalogue). Lignes calculées au moteur (suggest.py,
        # profondeur 22) puis passées à audit.py. ───────────────────────────────
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre …Cf6/…g6", "vs …Nf6/…g6")},
            "moves": [
                "b3", "Nf6", "Bb2",
                {"san": "e6",
                 "comment": c("La réponse la plus jouée du répertoire — près d'une partie sur quatre — et le chapitre ne voyait que …g6. Les Noirs gardent tout ouvert : …b6, …c5 ou …d5 selon ce que nous ferons.",
                              "The most played reply in the whole repertoire — almost one game in four — and the chapter only saw …g6. Black keeps everything open: …b6, …c5 or …d5, depending on what we do."),
                 "critical": True},
                {"san": "Nf3",
                 "comment": c("On ne se découvre pas non plus. Le cavalier sort, e5 reste sous surveillance, et le choix de structure attend un coup de plus.",
                              "We stay non-committal too. The knight comes out, e5 stays covered, and the choice of structure waits one more move.")},
                "c5", "e3", "b6", "d4",
                {"san": "Bb7",
                 "comment": c("Deux fianchettos face à face. La différence est que nous avons pris le centre : le fou b7 bute sur d4-e3, le nôtre respire.",
                              "Two fianchettos facing each other. The difference is that we took the centre: the b7 bishop runs into d4-e3, ours breathes.")},
                "Bd3", "d5", "O-O", "Nc6",
                {"san": "Bb5",
                 "comment": c("Le motif du répertoire : presser c6 pour saper le défenseur du centre noir.",
                              "The repertoire's motif: press c6 to undermine the defender of Black's centre.")},
                "Be7",
            ],
        },
        {
            "chapter": {"id": "vs-e5", "title": c("Contre …e5", "vs …e5")},
            "moves": [
                "b3", "e5", "Bb2",
                {"san": "d6",
                 "comment": c("Les Noirs étayent e5 du pion plutôt que du cavalier, en gardant c6 libre. Une partie sur cinq, et le chapitre partait de …Cc6.",
                              "Black props up e5 with the pawn rather than the knight, keeping c6 free. One game in five, and the chapter started from …Nc6."),
                 "critical": True},
                {"san": "e4",
                 "comment": c("Le coup qui surprend : après …d6, e5 n'est plus attaqué par le fou, alors on occupe le centre. La position devient une Sicilienne fermée où c'est NOUS qui avons le fou en b2.",
                              "The surprising move: after …d6 the bishop no longer hits e5, so we occupy the centre instead. The position becomes a Closed Sicilian where WE are the ones with a bishop on b2.")},
                "Nc6", "Nf3",
                {"san": "f5",
                 "comment": c("Les Noirs cherchent le contre-jeu — et ouvrent la diagonale du fou b2 en même temps que la leur.",
                              "Black goes for counterplay — and opens the b2 bishop's diagonal at the same time as their own.")},
                "exf5", "Bxf5", "Bb5", "Qf6", "O-O", "a6", "Bxc6+",
                {"san": "bxc6",
                 "comment": c("Pions doublés sur une colonne ouverte, roi encore au centre : le fou b2 a désormais une cible.",
                              "Doubled pawns on an open file, king still in the centre: the b2 bishop finally has a target."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "b3", "d5", "Bb2",
                {"san": "c5",
                 "comment": c("Le double pion central : les Noirs prennent l'espace et refusent la diagonale. Le chapitre ne connaissait que …Cf6 et …Cc6.",
                              "The double centre pawn: Black grabs space and denies us the diagonal. The chapter only knew …Nf6 and …Nc6."),
                 "critical": True},
                {"san": "e3",
                 "comment": c("On ne se précipite pas sur d4 : d'abord ouvrir le fou roi, garder d4 comme rupture pour plus tard.",
                              "No hurry with d4: first open the king's bishop, and keep d4 as a break for later.")},
                "Nf6", "Nf3", "e6", "Be2", "Be7",
                {"san": "d4",
                 "comment": c("Maintenant seulement. Les Noirs doivent choisir : garder la tension, ou prendre — et l'échange leur laisse un pion isolé en perspective.",
                              "Only now. Black must choose: keep the tension, or take — and the exchange leaves them facing an isolated pawn.")},
                "O-O", "dxc5", "Bxc5", "Nbd2", "b6",
            ],
        },
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre …Cf6/…g6", "vs …Nf6/…g6")},
            "moves": [
                "b3", "Nf6", "Bb2",
                {"san": "d5",
                 "comment": c("Les Noirs occupent le centre au lieu de le contester à distance. Un joueur sur six, et le chapitre ne l'avait pas prévu.",
                              "Black occupies the centre instead of contesting it from afar. One player in six, and the chapter had not planned for it."),
                 "critical": True},
                "e3",
                {"san": "Bf5",
                 "comment": c("Le bon fou sort avant …e6 — c'est la règle d'or de ces structures, et les Noirs la respectent.",
                              "The good bishop comes out before …e6 — the golden rule of these structures, and Black follows it.")},
                "Nf3", "e6",
                {"san": "Nh4",
                 "comment": c("Le coup à retenir : on chasse le fou f5, celui qui tient les cases blanches. Le cavalier revient en f3 dès qu'il a fait son travail.",
                              "The move to remember: we chase the f5 bishop, the piece holding the light squares. The knight returns to f3 as soon as its job is done."),
                 "critical": True},
                "Bg4", "Be2", "Bxe2", "Qxe2", "Be7", "Nf3", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "b3", "d5", "Bb2",
                {"san": "e6",
                 "comment": c("Solide et sans histoire : les Noirs referment la diagonale avec un pion. On transpose vers la même structure que …Cf6, un coup plus tôt.",
                              "Solid and unfussy: Black shuts the diagonal with a pawn. We transpose into the same structure as …Nf6, one move earlier."),
                 "critical": True},
                "e3", "Nf6",
                {"san": "d4",
                 "comment": c("Puisque les Noirs ont renoncé à …c5 immédiat, on prend le centre pour de bon.",
                              "Since Black has passed on an immediate …c5, we take the centre for good.")},
                "Be7", "Bd3", "O-O", "Nf3", "b6", "O-O", "Bb7", "Nbd2", "c5",
            ],
        },
    ],
}
