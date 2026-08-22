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

        # ── Trous comblés le 22/08 : les cinq réponses noires les plus jouées
        # qu'aucun chapitre n'atteignait (coverage.py, dette 1,11). Chemins
        # reconstruits par `path_to_hole.py`. ────────────────────────────────
        {
            "chapter": {"id": "from-gambit", "title": c("Gambit From — 1…e5", "From's Gambit — 1…e5")},
            "moves": [
                "f4", "e5", "fxe5", "d6", "exd6", "Bxd6", "Nf3",
                {"san": "Bg4",
                 "comment": c("Un Noir sur trois cloue immédiatement — c'est le coup le plus fréquent du gambit From, et le cours ne connaissait que …g5. Le cavalier f3 garde h4 et g5 : le clouer, c'est préparer …Dh4+.",
                              "One Black player in three pins at once — the most frequent move in the From's Gambit, and the course only knew …g5. The f3 knight guards h4 and g5: pinning it prepares …Qh4+."),
                 "critical": True},
                {"san": "e3",
                 "comment": c("Modeste et suffisant : on ouvre le fou f1 pour roquer vite. Contre un gambit, terminer son développement vaut mieux que chercher à réfuter.",
                              "Modest and sufficient: we open the f1 bishop to castle quickly. Against a gambit, finishing development beats trying to refute."),
                 "critical": True},
                "Nf6", "Be2", "c5", "Nc3", "Nc6", "O-O",
                {"san": "Bc7",
                 "comment": c("Les Noirs conservent le fou pour l'attaque. Nous avons le pion en plus et le roi à l'abri : c'est exactement le marché du gambit, et il nous convient.",
                              "Black keeps the bishop for the attack. We have the extra pawn and a safe king: precisely the gambit's bargain, and it suits us.")},
                "d3",
            ],
        },
        {
            "chapter": {"id": "from-gambit", "title": c("Gambit From — 1…e5", "From's Gambit — 1…e5")},
            "moves": [
                "f4", "e5", "fxe5", "d6", "exd6", "Bxd6", "Nf3",
                {"san": "Nf6",
                 "comment": c("Développement tranquille plutôt que clouage. Un Noir sur cinq, et le cours n'en disait rien.",
                              "Quiet development instead of a pin. One Black player in five, and the course said nothing about it."),
                 "critical": True},
                "e3",
                {"san": "Ng4",
                 "comment": c("Le saut qui frappe e3 : les Noirs cherchent à récupérer leur pion avec des échecs. Il faut connaître la suite, elle est forcée.",
                              "The jump that hits e3: Black tries to win the pawn back with checks. You need to know what follows — it is forced."),
                 "critical": True},
                "d4", "Qe7", "Nc3", "Nxe3", "Bxe3", "Qxe3+",
                {"san": "Qe2",
                 "comment": c("Et voilà le point : on propose l'échange des dames. Sans dames, l'attaque du gambit n'existe plus, et notre centre d4 reste sur l'échiquier.",
                              "And here is the point: we offer the queen trade. Without queens the gambit's attack no longer exists, and our d4 centre stays on the board."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5 — la Bird classique", "vs …d5 — the classical Bird")},
            "moves": [
                "f4", "d5", "Nf3", "c5", "e3",
                {"san": "Nc6",
                 "comment": c("Près de trois Noirs sur quatre développent ce cavalier ici, et le cours ne prévoyait que …a6.",
                              "Nearly three Black players in four develop this knight here, and the course only planned for …a6."),
                 "critical": True},
                {"san": "Bb5",
                 "comment": c("Le clouage à contre-emploi : on échange volontairement notre bon fou pour affaiblir le contrôle noir de e5 — la case autour de laquelle tourne toute la Bird.",
                              "The pin used the other way round: we deliberately trade our good bishop to weaken Black's grip on e5 — the square the whole Bird revolves around."),
                 "critical": True},
                "Bd7", "Bxc6", "Bxc6",
                {"san": "Ne5",
                 "comment": c("Le cavalier s'installe sur l'avant-poste, et il ne peut plus en être chassé par une pièce mineure. C'est le but de tout ce qui précède.",
                              "The knight settles on the outpost, and no minor piece can evict it any more. That is the point of everything before it."),
                 "critical": True},
                "Qb6", "O-O", "g6", "c4",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5 — la Bird classique", "vs …d5 — the classical Bird")},
            "moves": [
                "f4", "d5", "Nf3",
                {"san": "e6",
                 "comment": c("Les Noirs referment la diagonale avant tout. Le cours voyait …Cf6, …Cc6 et …c5, mais pas ce coup pourtant naturel.",
                              "Black shuts the diagonal first. The course saw …Nf6, …Nc6 and …c5, but not this perfectly natural move."),
                 "critical": True},
                {"san": "b3",
                 "comment": c("La Bird « Larsen » : le fou dame va en b2, où il regarde e5 et la grande diagonale. Nos deux pièces les plus lentes visent alors la même case.",
                              "The “Larsen” Bird: the queen's bishop goes to b2, eyeing e5 and the long diagonal. Our two slowest pieces then aim at the same square."),
                 "critical": True},
                "Nf6", "e3", "Be7", "Bb2", "O-O", "Be2", "c5", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5 — la Bird classique", "vs …d5 — the classical Bird")},
            "moves": [
                "f4", "d5", "Nf3",
                {"san": "Bf5",
                 "comment": c("Le bon fou dehors avant …e6 — la règle d'or, que les Noirs appliquent ici contre nous.",
                              "The good bishop out before …e6 — the golden rule, which Black applies here against us."),
                 "critical": True},
                {"san": "g3",
                 "comment": c("On fianchette de notre côté : le fou g2 contestera le fou f5 sur les cases blanches, et c'est le seul moyen de ne pas lui laisser cette diagonale.",
                              "We fianchetto on our side: the g2 bishop will contest f5 on the light squares, and it is the only way not to hand over that diagonal."),
                 "critical": True},
                "e6", "d3", "Bc5", "Bg2", "Nc6", "e3",
                {"san": "h5",
                 "comment": c("Les Noirs poussent à l'aile roi puisque le centre est bloqué. On répond h3 : le pion h5 n'ira pas plus loin sans concession.",
                              "Black pushes on the kingside since the centre is blocked. We answer h3: the h5 pawn goes no further without conceding something.")},
                "h3",
            ],
        },
    ],
}
