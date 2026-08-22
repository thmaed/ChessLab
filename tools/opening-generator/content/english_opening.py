# -*- coding: utf-8 -*-
"""Anglaise (1.c4) — répertoire BLANC.

Arbre approfondi : Sicilienne inversée 1…e5 (dragon inversé), Symétrique 1…c5
(avec la rupture d4), et l'attaque Mikenas 2.Cc3 e6 3.e4. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "english-opening",
    "name": "English Opening",
    "side": "white",
    "level": "club",
    "eco": ["A10", "A39"],
    "summary": c(
        "Une ouverture de flanc hypermoderne : on contrôle d5 à distance et on garde une flexibilité totale. Souvent une sicilienne avec un temps de plus.",
        "A hypermodern flank opening: control d5 from afar and keep total flexibility. Often a Sicilian with an extra tempo.",
    ),
    "lines": [
        # 1) Sicilienne inversée — 1…e5
        {
            "chapter": {"id": "reversed-sicilian", "title": c("Sicilienne inversée — 1…e5", "Reversed Sicilian — 1…e5")},
            "moves": [
                {"san": "c4", "eco": "English Opening",
                 "comment": c("On revendique d5 sans engager les pions centraux : jeu souple.",
                              "Claiming d5 without committing the central pawns: flexible play.")},
                {"san": "e5", "comment": c("Les Noirs prennent le centre : c'est une sicilienne à camps inversés, un temps en plus pour les Blancs.",
                                           "Black grabs the centre: it's a Sicilian with colours reversed, White a tempo up.")},
                "Nc3", "Nf6", "Nf3", "Nc6", "g3", "d5", "cxd5", "Nxd5", "Bg2",
                {"san": "Nb6", "comment": c("Le dragon inversé : les Blancs jouent la structure sicilienne avec un temps de plus.",
                                            "The reversed Dragon: White plays the Sicilian structure a tempo up.")},
                "O-O", "Be7", "d3", "O-O", "a3", "a5", "Be3", "Re8",
            ],
        },
        # 2) Variante symétrique — 1…c5
        {
            "chapter": {"id": "symmetrical", "title": c("Variante symétrique — 1…c5", "Symmetrical — 1…c5")},
            "moves": [
                "c4",
                {"san": "c5", "eco": "English Opening: Symmetrical Variation",
                 "comment": c("La symétrique : chacun campe sur ses positions. Les Blancs cherchent à rompre la symétrie au bon moment.",
                              "The Symmetrical: both sides mirror. White looks to break the symmetry at the right moment.")},
                "Nc3", "Nc6", "g3", "g6", "Bg2", "Bg7", "Nf3", "Nf6", "O-O", "O-O",
                {"san": "d4", "comment": c("Le bon moment pour rompre : d4 casse la symétrie et ouvre le fou g2.",
                                           "The right moment to break: d4 shatters the symmetry and opens the g2 bishop.")},
                "cxd4", "Nxd4", "Nxd4", "Qxd4", "d6", "Qd3", "a6",
            ],
        },
        # 3) Attaque Mikenas — 2.Cc3 e6 3.e4
        {
            "chapter": {"id": "mikenas", "title": c("Attaque Mikenas — 3.e4", "Mikenas Attack — 3.e4")},
            "moves": [
                "c4", "Nf6", "Nc3", "e6",
                {"san": "e4", "comment": c("L'attaque Mikenas : les Blancs prennent tout le centre. Le jeu devient concret d'emblée.",
                                           "The Mikenas Attack: White seizes the whole centre. Play turns concrete at once.")},
                {"san": "d5", "comment": c("La réponse la plus critique : on frappe e4 tout de suite.",
                                           "The most critical reply: hit e4 immediately.")},
                "e5", "d4", "exf6", "dxc3", "fxg7", "cxd2+", "Bxd2", "Bxg7",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-kid-setup", "title": c("Contre l'installation …Cf6/…g6", "vs the …Nf6/…g6 setup")},
            "moves": [
                "c4",
                {"san": "Nf6",
                 "comment": c("Le début le plus fréquent après 1.c4, et le cours partait de …e5 ou …c5.",
                              "The most common reply to 1.c4, and the course started from …e5 or …c5."),
                 "critical": True},
                "Nc3",
                {"san": "g6",
                 "comment": c("Les Noirs visent une Est-Indienne. On peut la refuser en occupant le centre tout de suite.",
                              "Black is heading for a King's Indian. We can decline it by taking the centre at once.")},
                {"san": "d4",
                 "comment": c("Transposition assumée : l'Anglaise se transforme en jeu de pions dames, où notre pion c4 est déjà idéalement placé.",
                              "A deliberate transposition: the English turns into a queen's pawn game, where our c4 pawn already stands ideally.")},
                "d5", "Nf3", "Bg7",
                {"san": "Qb3",
                 "comment": c("La pression sur d5 avant le roque : c'est l'idée qui donne le ton à toute la variante.",
                              "Pressure on d5 before castling: the idea that sets the tone for the whole line.")},
                "dxc4", "Qxc4",
            ],
        },
        {
            "chapter": {"id": "reversed-sicilian", "title": c("Sicilienne inversée — 1…e5", "Reversed Sicilian — 1…e5")},
            "moves": [
                "c4", "e5", "Nc3",
                {"san": "Nc6",
                 "comment": c("Le développement le plus naturel, absent du chapitre qui partait de …Cf6.",
                              "The most natural developing move, missing from the chapter, which started from …Nf6.")},
                {"san": "g3",
                 "comment": c("Fianchetto : c'est une Sicilienne avec un temps de plus. Le fou g2 mordra sur d5 toute la partie.",
                              "Fianchetto: this is a Sicilian with an extra tempo. The g2 bishop will bite on d5 all game.")},
                "g6", "Bg2", "Bg7", "d3", "a5", "e3",
            ],
        },
        {
            "chapter": {"id": "reversed-sicilian", "title": c("Sicilienne inversée — 1…e5", "Reversed Sicilian — 1…e5")},
            "moves": [
                "c4", "e5", "Nc3",
                {"san": "Bc5",
                 "comment": c("Un coup de club fréquent : le fou sort vite, mais il devra bouger encore quand d4 arrivera.",
                              "A common club move: the bishop develops fast, but it will have to move again once d4 comes.")},
                "e3", "Nc6", "Nf3", "d6", "a3",
                {"san": "a5",
                 "comment": c("Les Noirs freinent b4. On joue d4 quand même : le fou c5 perd son temps, et c'est notre avantage.",
                              "Black slows b4 down. We play d4 anyway: the c5 bishop loses time, and that's our edge.")},
                "d4", "Ba7",
            ],
        },

        # ── Trous comblés le 21/08 : les cinq réponses noires les plus jouées
        # qu'aucun chapitre n'atteignait (coverage.py, dette 1,68 — la plus
        # lourde du catalogue après les deux lots précédents). Lignes calculées
        # au moteur (suggest.py, profondeur 22, deux candidats comparés). ──────
        {
            "chapter": {"id": "vs-kid", "title": c("Contre le fianchetto roi", "vs the King's fianchetto")},
            "moves": [
                "c4", "Nf6", "Nc3", "g6", "d4",
                {"san": "Bg7",
                 "comment": c("Trois Noirs sur quatre jouent ce fianchetto — c'est LA réponse à l'Anglaise — et le chapitre ne connaissait que 3…d5. On entre dans une Est-Indienne, où c'est nous qui avons pris le centre en premier.",
                              "Three Black players in four play this fianchetto — it IS the answer to the English — and the chapter only knew 3…d5. We enter a King's Indian, where we are the ones who took the centre first."),
                 "critical": True},
                {"san": "e4",
                 "comment": c("Le grand centre, tant qu'à faire. Le fou g7 vient de se poster sur une diagonale que nous refermons avant même qu'il l'emprunte.",
                              "The full centre, while we can. The g7 bishop has just taken aim along a diagonal we close before it ever gets to use it.")},
                "d6", "Be2", "e5",
                {"san": "d5",
                 "comment": c("On ferme, et c'est un choix : la position devient un combat d'ailes où les Blancs poussent à l'aile dame et les Noirs au roi. Notre pion c4 est déjà en place, le leur non.",
                              "We close, and it is a choice: the game becomes a battle of wings, White pushing on the queenside and Black on the kingside. Our c4 pawn is already there, theirs is not."),
                 "critical": True},
                "a5", "h4",
                {"san": "h5",
                 "comment": c("Les Noirs doivent arrêter h5, sinon l'ouverture de la colonne h arrive avant leur propre attaque.",
                              "Black must stop h5, otherwise the h-file opens before their own attack ever gets going.")},
                "Bg5", "Bh6", "Bxh6",
            ],
        },
        {
            "chapter": {"id": "vs-e5", "title": c("Contre …e5 — la Sicilienne inversée", "vs …e5 — the Reversed Sicilian")},
            "moves": [
                "c4", "Nf6", "Nc3",
                {"san": "e5",
                 "comment": c("Les Noirs prennent le centre : c'est une Sicilienne avec les couleurs inversées, et un tempo de plus pour nous. Le chapitre ne prévoyait que …e6 et …g6.",
                              "Black takes the centre: this is a Sicilian with colours reversed, and a spare tempo for us. The chapter only planned for …e6 and …g6."),
                 "critical": True},
                {"san": "g3",
                 "comment": c("Le fianchetto est ici la bonne façon de traiter le centre noir : on ne l'attaque pas de front, on le regarde de loin depuis g2.",
                              "The fianchetto is the right way to handle Black's centre: we do not hit it head-on, we watch it from afar on g2.")},
                "Bb4", "Bg2", "O-O", "e4",
                {"san": "d6",
                 "comment": c("Les deux camps ont leur centre. La différence tient au tempo : nos pièces arrivent une demi-mesure plus tôt sur chaque case utile.",
                              "Both sides have their centre. The difference is the tempo: our pieces reach every useful square half a beat earlier.")},
                "Nge2", "Bc5", "h3", "Nc6", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-symmetrical", "title": c("Contre …c5 — l'Anglaise symétrique", "vs …c5 — the Symmetrical English")},
            "moves": [
                "c4", "c5", "Nc3",
                {"san": "Nf6",
                 "comment": c("La symétrie complète. Le chapitre ne connaissait que …Cc6 — or un Noir sur neuf sort ce cavalier-là d'abord.",
                              "Full symmetry. The chapter only knew …Nc6 — yet one Black player in nine develops this knight first."),
                 "critical": True},
                {"san": "g3",
                 "comment": c("Contre la symétrie, c'est celui qui rompt le premier avec profit qui gagne l'initiative. Le fou g2 prépare d4 dans de bonnes conditions.",
                              "Against symmetry, whoever breaks first and profitably takes the initiative. The g2 bishop prepares d4 under the right conditions.")},
                "e6", "Nf3", "d5", "cxd5", "exd5",
                {"san": "d4",
                 "comment": c("La rupture. Les Noirs héritent d'un pion isolé en d5 ; nous, d'une case forte en d4 et d'un fou qui le fixe depuis g2.",
                              "The break. Black is left with an isolated pawn on d5; we get a strong square on d4 and a bishop fixing it from g2."),
                 "critical": True},
                "Nc6", "Bg2", "cxd4", "Nxd4",
            ],
        },
        {
            "chapter": {"id": "vs-symmetrical", "title": c("Contre …c5 — l'Anglaise symétrique", "vs …c5 — the Symmetrical English")},
            "moves": [
                "c4", "c5", "Nc3",
                {"san": "e6",
                 "comment": c("Les Noirs préparent …d5 avant de sortir un cavalier. Même famille que la ligne précédente, ordre différent — et le cours n'avait rien.",
                              "Black prepares …d5 before developing a knight. Same family as the previous line, different order — and the course had nothing."),
                 "critical": True},
                "Nf3", "Nf6", "g3", "d5", "cxd5", "exd5", "d4", "cxd4", "Nxd4",
                {"san": "Bc5",
                 "comment": c("Le pion isolé donne aux Noirs des cases actives : ne pas croire la position gagnée d'avance, elle est simplement plus facile à jouer pour nous.",
                              "The isolated pawn gives Black active squares: do not think the position wins itself — it is simply easier to play for us.")},
                "Bg2",
            ],
        },
        {
            "chapter": {"id": "vs-symmetrical", "title": c("Contre …c5 — l'Anglaise symétrique", "vs …c5 — the Symmetrical English")},
            "moves": [
                "c4", "c5", "Nc3",
                {"san": "d6",
                 "comment": c("Un début d'Est-Indienne ou de Sicilienne selon la suite. Les Noirs gardent tout ouvert ; à nous de prendre le centre pendant qu'ils hésitent.",
                              "The start of a King's Indian or a Sicilian, depending on what follows. Black keeps everything open; it is up to us to take the centre while they hesitate."),
                 "critical": True},
                "Nf3", "Nf6",
                {"san": "d4",
                 "comment": c("Sans attendre : les Noirs n'ont pas encore de pièce pour contester d4, et après l'échange nous obtenons une Sicilienne Maroczy avec les Blancs — un des meilleurs marchés de l'ouverture.",
                              "Without waiting: Black has no piece contesting d4 yet, and after the trade we get a Maroczy Bind Sicilian as White — one of the best bargains in the opening."),
                 "critical": True},
                "cxd4", "Nxd4", "Nc6", "e4", "g6", "Be2", "Nxd4", "Qxd4",
            ],
        },

        # ── Seconde passe du 22/08 : cinq trous ouverts par le premier lot.
        # Chemins reconstruits par `path_to_hole.py` (jamais lus à l'œil). ─────
        {
            "chapter": {"id": "vs-kid", "title": c("Contre le fianchetto roi", "vs the King's fianchetto")},
            "moves": [
                "c4", "Nf6", "Nc3", "g6", "d4", "Bg7", "e4", "d6", "Be2",
                {"san": "O-O",
                 "comment": c("Plus de quatre Noirs sur cinq roquent ici — c'est de très loin le coup le plus joué de tout le répertoire — et le premier lot enchaînait directement sur …e5.",
                              "More than four Black players in five castle here — by far the most played move in the whole repertoire — and the first batch went straight on to …e5."),
                 "critical": True},
                {"san": "Bg5",
                 "comment": c("Avant de refermer le centre, on cloue : le cavalier f6 est le gardien de e4 et de d5, et le déranger maintenant vaut mieux que plus tard.",
                              "Before closing the centre, we pin: the f6 knight guards e4 and d5, and disturbing it now is worth more than later."),
                 "critical": True},
                "Nc6", "Nf3", "h6",
                {"san": "Bc1",
                 "comment": c("Le fou rentre plutôt que de s'échanger. Les Noirs ont dépensé …h6 pour rien, et ce pion affaibli servira de cible quand on attaquera.",
                              "The bishop goes home rather than trade itself off. Black has spent …h6 for nothing, and that loosened pawn becomes a target when we attack."),
                 "critical": True},
                "e5", "d5", "Ne7",
            ],
        },
        {
            "chapter": {"id": "vs-symmetrical", "title": c("Contre …c5 — l'Anglaise symétrique", "vs …c5 — the Symmetrical English")},
            "moves": [
                "c4", "c5", "Nc3", "Nc6", "g3",
                {"san": "Nf6",
                 "comment": c("Un Noir sur six sort ce cavalier plutôt que de fianchetter, et le premier lot n'avait prévu que …g6.",
                              "One Black player in six develops this knight instead of fianchettoing, and the first batch only planned for …g6."),
                 "critical": True},
                "Bg2", "e6", "Nf3", "d5", "cxd5", "exd5",
                {"san": "d4",
                 "comment": c("Toujours la même rupture : on la joue quand elle laisse aux Noirs un pion isolé, jamais avant.",
                              "The same break as ever: we play it when it leaves Black with an isolated pawn, never before."),
                 "critical": True},
                "cxd4", "Nxd4", "Bc5",
            ],
        },
        {
            "chapter": {"id": "vs-symmetrical", "title": c("Contre …c5 — l'Anglaise symétrique", "vs …c5 — the Symmetrical English")},
            "moves": [
                "c4", "c5", "Nc3", "Nc6", "g3",
                {"san": "e6",
                 "comment": c("Les Noirs préparent …d5 sans se découvrir. Même famille que la ligne précédente, un ordre de coups plus tôt.",
                              "Black prepares …d5 without committing. Same family as the previous line, one move order earlier."),
                 "critical": True},
                "Nf3", "d5", "cxd5", "exd5", "d4", "Nf6", "Bg2",
                {"san": "c4",
                 "comment": c("Les Noirs refusent l'isolé en poussant. Le pion c4 avance loin de ses bases : il paraît gênant, il sera surtout faible.",
                              "Black declines the isolated pawn by pushing. The c4 pawn advances far from its friends: it looks annoying, it will mostly be weak."),
                 "critical": True},
                "Ne5", "Be6",
            ],
        },
        {
            "chapter": {"id": "vs-symmetrical", "title": c("Contre …c5 — l'Anglaise symétrique", "vs …c5 — the Symmetrical English")},
            "moves": [
                "c4", "c5", "Nc3", "Nc6", "g3",
                {"san": "d6",
                 "comment": c("Un début à la Sicilienne fermée, couleurs inversées. Le premier lot ne voyait que …g6.",
                              "The start of a Closed Sicilian, colours reversed. The first batch only saw …g6."),
                 "critical": True},
                {"san": "e3",
                 "comment": c("Un coup modeste et redoutable : il prépare d4 en une fois, avec le pion e3 pour le soutenir — la rupture arrive alors sans concession.",
                              "A modest and dangerous move: it prepares d4 in one go, with the e3 pawn behind it — the break then comes without concessions."),
                 "critical": True},
                "g6", "Bg2", "Bg7", "Nge2", "Nf6", "d4", "O-O", "O-O", "Bg4",
            ],
        },
        {
            "chapter": {"id": "vs-e5", "title": c("Contre …e5 — la Sicilienne inversée", "vs …e5 — the Reversed Sicilian")},
            "moves": [
                "c4", "e5", "Nc3", "Nc6", "g3",
                {"san": "Nf6",
                 "comment": c("Deux Noirs sur cinq développent ainsi, et le premier lot n'avait que …g6. Ils construisent un centre classique ; nous le prendrons de biais.",
                              "Two Black players in five develop like this, and the first batch only had …g6. They build a classical centre; we will take it from the side."),
                 "critical": True},
                "Bg2",
                {"san": "Bc5",
                 "comment": c("Le fou vise f2, la case la plus tendre du roque blanc. C'est le vrai poison de la Sicilienne inversée : la case f2 n'est gardée que par le roi.",
                              "The bishop eyes f2, the softest square of White's castled position. That is the real venom of the Reversed Sicilian: f2 is guarded only by the king."),
                 "critical": True},
                "Nf3", "d6", "e3", "Bf5", "d3", "Bb4", "e4", "Bxc3+",
            ],
        },
    ],
}
