# -*- coding: utf-8 -*-
"""Défense scandinave (1.e4 d5) — répertoire NOIR, rédigé à la main.

Commentaires bilingues (fr/en) sur les coups clés. La 1re ligne est la ligne
principale (3...Da5) ; les suivantes sont les variantes, fusionnées par
transposition à la compilation. Contenu de test.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "scandinavian",
    "name": "Scandinavian Defense",
    "side": "black",
    "level": "club",
    "eco": ["B01"],
    "summary": c(
        "Dès 1…d5, les Noirs frappent le centre et imposent leur plan : reprise à la dame ou contre-attaque par …Cf6. Sûre, logique et facile à jouer.",
        "With 1…d5 Black strikes the centre at once and dictates the plan: recapture with the queen, or counterattack with …Nf6. Sound, logical and easy to play.",
    ),

    "lines": [
        # ── Ligne principale : 3…Da5 (Mieses-Kotroc / classique) ──────────────
        {
            "chapter": {"id": "mainline", "title": c("Ligne principale — 3…Da5", "Main line — 3…Qa5")},
            "moves": [
                {"san": "e4"},
                {"san": "d5", "eco": "Scandinavian Defense",
                 "comment": c("Le coup caractéristique : les Noirs contestent e4 immédiatement, sans préparation.",
                              "The signature move: Black challenges e4 at once, with no preparation.")},
                {"san": "exd5",
                 "comment": c("Le plus franc. Les Blancs prennent le pion — les Noirs vont le reprendre.",
                              "The most direct. White grabs the pawn — Black will win it back.")},
                {"san": "Qxd5", "eco": "Scandinavian Defense: Main Line",
                 "comment": c("Reprise à la dame : le pion revient tout de suite, au prix d'un léger retard qu'on comblera vite.",
                              "Recapturing with the queen: the pawn comes straight back, at the cost of a small delay we soon make up.")},
                {"san": "Nc3",
                 "comment": c("Le coup de gain de temps : le cavalier attaque la dame. Où la placer ? C'est tout le choix de la Scandinave.",
                              "The tempo move: the knight hits the queen. Where to put her? That choice defines the Scandinavian.")},
                {"san": "Qa5", "eco": "Scandinavian Defense: Mieses-Kotroc Variation",
                 "comment": c("La retraite classique. La dame reste active sur la diagonale a5-e1 et garde …e5 en réserve.",
                              "The classical retreat. The queen stays active on the a5-e1 diagonal and keeps …e5 in reserve."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("Les Blancs prennent tout le centre — la position type est en place.",
                              "White takes the full centre — the standard tabiya is being set.")},
                {"san": "Nf6",
                 "comment": c("Développement naturel, avec un œil sur e4 et d5.",
                              "Natural development, eyeing e4 and d5.")},
                {"san": "Nf3"},
                {"san": "c6",
                 "comment": c("La case de repli de la dame (…Qc7/…Qd8) et un point d'appui : c'est la colonne vertébrale du système.",
                              "A retreat square for the queen (…Qc7/…Qd8) and a solid support point: the backbone of the setup.")},
                {"san": "Bc4"},
                {"san": "Bf5",
                 "comment": c("Le bon fou : on le sort AVANT de jouer …e6, pour ne pas l'enfermer.",
                              "The good bishop: develop it BEFORE …e6, so it never gets shut in."),
                 "critical": True},
                {"san": "Bd2"},
                {"san": "e6",
                 "comment": c("La structure est prête : …Be7/…Bb4, roque, et les Noirs sont pleinement développés, solides.",
                              "The structure is complete: …Be7/…Bb4, castle, and Black is fully developed and solid.")},
            ],
        },

        # ── Variante moderne : 3…Dd6 (Tiviakov) ───────────────────────────────
        {
            "chapter": {"id": "qd6", "title": c("Moderne — 3…Dd6", "Modern — 3…Qd6")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3",
                {"san": "Qd6", "eco": "Scandinavian Defense: Gubinsky-Melts Variation",
                 "comment": c("La grande alternative moderne : la dame en d6 est souple et moins exposée aux tempos.",
                              "The big modern alternative: the queen on d6 is flexible and less exposed to tempo hits."),
                 "critical": True},
                "d4", "Nf6", "Nf3",
                {"san": "a6",
                 "comment": c("Le système de Tiviakov : on prépare …b5, …Bb7 et une structure très sûre.",
                              "Tiviakov's system: preparing …b5, …Bb7 and a very solid structure.")},
                "g3", "b5", "Bg2", "Bb7",
                {"san": "O-O",
                 "comment": c("Les deux camps fianchettent ; la position est saine et jouable des deux côtés.",
                              "Both sides fianchetto; the position is sound and playable for both.")},
                "e6",
            ],
        },

        # ── 3…Dd8 (Valencienne) et 3…De5+ (à éviter) ──────────────────────────
        {
            "chapter": {"id": "queen-retreats", "title": c("Autres retraites de dame", "Other queen retreats")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3",
                {"san": "Qd8", "eco": "Scandinavian Defense: Valencian Variation",
                 "comment": c("La retraite la plus solide mais la plus passive : la dame rentre au bercail, on développe tranquillement.",
                              "The most solid but most passive retreat: the queen goes home and Black develops quietly.")},
                "d4", "Nf6", "Nf3",
                {"san": "Bf5",
                 "comment": c("Sortir le fou de cases blanches avant …e6 reste la bonne méthode.",
                              "Developing the light-squared bishop before …e6 is still the right method.")},
                "Bc4", "e6", "O-O", "Be7",
            ],
        },
        {
            "chapter": {"id": "queen-retreats", "title": c("Autres retraites de dame", "Other queen retreats")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3",
                {"san": "Qe5+", "role": "inaccuracy", "critical": True,
                 "comment": c("Tentant mais douteux : l'échec ne gagne rien et, après Fe2, la dame devra encore bouger — les Blancs prennent une belle avance.",
                              "Tempting but dubious: the check wins nothing and, after Be2, the queen must move again — White gets a fine lead in development.")},
                "Be2",
            ],
        },

        # ── Le gambit 4.b4 (Kotrč-Mieses) ─────────────────────────────────────
        {
            "chapter": {"id": "b4-gambit", "title": c("Le gambit 4.b4", "The 4.b4 gambit")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qa5", "d4",  # transpose au nœud 3…Da5 4.d4
            ],
        },
        {
            "chapter": {"id": "b4-gambit", "title": c("Le gambit 4.b4", "The 4.b4 gambit")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qa5",
                {"san": "b4", "role": "trap", "critical": True,
                 "comment": c("Le gambit Kotrč-Mieses : b4 attaque la dame. Le prendre est correct — c'est douteux pour les Blancs avec une défense précise.",
                              "The Kotrč-Mieses gambit: b4 hits the queen. Taking is correct — it's dubious for White against accurate defence.")},
                {"san": "Qxb4",
                 "comment": c("On accepte : un pion est un pion. Il faut juste connaître la suite.",
                              "We accept: a pawn is a pawn. You just need to know the follow-up.")},
                "Rb1",
                {"san": "Qd6",
                 "comment": c("La dame se met à l'abri en d6, prête à revenir dans le jeu. Les Noirs gardent l'avantage matériel.",
                              "The queen tucks into d6, ready to return to play. Black keeps the extra material.")},
                "Nf3",
            ],
        },

        # ── 2…Cf6 : reprise moderne (Cxd5) ────────────────────────────────────
        {
            "chapter": {"id": "nf6", "title": c("2…Cf6 — l'ordre moderne", "2…Nf6 — the modern move order")},
            "moves": [
                "e4", "d5", "exd5",
                {"san": "Nf6", "eco": "Scandinavian Defense: Modern Variation",
                 "comment": c("On ne reprend pas tout de suite : le cavalier attaque d5 et évite le gain de tempo Cc3. Très en vogue.",
                              "Black doesn't recapture yet: the knight attacks d5 and sidesteps the Nc3 tempo. Very fashionable."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("Le plus solide : les Blancs gardent le pion un instant et bâtissent le centre.",
                              "The most solid: White holds the pawn a moment and builds the centre.")},
                {"san": "Nxd5",
                 "comment": c("Le cavalier reprend le pion, bien centralisé.",
                              "The knight recaptures, nicely centralised.")},
                "c4", "Nb6", "Nf3", "g6", "Be2", "Bg7", "O-O", "O-O",
            ],
        },

        # ── Portugais : 3.d4 Fg4 ──────────────────────────────────────────────
        {
            "chapter": {"id": "portuguese", "title": c("Gambit portugais — 3…Fg4", "Portuguese Gambit — 3…Bg4")},
            "moves": [
                "e4", "d5", "exd5", "Nf6", "d4",
                {"san": "Bg4", "role": "trap", "critical": True,
                 "eco": "Scandinavian Defense: Portuguese Gambit",
                 "comment": c("Le Gambit portugais : au lieu de reprendre en d5, les Noirs développent avec gain de temps et une initiative dangereuse.",
                              "The Portuguese Gambit: instead of recapturing on d5, Black develops with tempo and a dangerous initiative.")},
                {"san": "f3",
                 "comment": c("La réponse la plus critique : on repousse le fou tout de suite.",
                              "The most critical reply: kick the bishop back at once.")},
                "Bf5", "Bb5+", "Nbd7", "c4", "e6",
            ],
        },

        # ── Islandais : 3.c4 e6 ───────────────────────────────────────────────
        {
            "chapter": {"id": "icelandic", "title": c("Gambit islandais — 3.c4 e6", "Icelandic Gambit — 3.c4 e6")},
            "moves": [
                "e4", "d5", "exd5", "Nf6",
                {"san": "c4",
                 "comment": c("Les Blancs veulent tenir le pion — mais cela ouvre la porte au gambit islandais.",
                              "White tries to hold the pawn — but that invites the Icelandic Gambit.")},
                {"san": "e6", "role": "trap", "critical": True,
                 "eco": "Scandinavian Defense: Icelandic-Palme Gambit",
                 "comment": c("Le Gambit islandais : les Noirs sacrifient un pion pour un développement fulgurant et des colonnes ouvertes.",
                              "The Icelandic Gambit: Black sacrifices a pawn for lightning development and open files.")},
                "dxe6", {"san": "Bxe6",
                          "comment": c("Le fou file en e6, les pièces suivent : compensation nette et jeu facile.",
                                       "The bishop lands on e6 and the pieces flow: clear compensation and easy play.")},
                "Nf3", "Nc6", "Be2", "Bc5",
            ],
        },

        # ── 3.Fb5+ ────────────────────────────────────────────────────────────
        {
            "chapter": {"id": "bb5", "title": c("3.Fb5+", "3.Bb5+")},
            "moves": [
                "e4", "d5", "exd5", "Nf6",
                {"san": "Bb5+",
                 "comment": c("Un échec pour garder le pion — les Noirs s'en sortent bien après …Fd7.",
                              "A check to cling to the pawn — Black is fine after …Bd7.")},
                {"san": "Bd7",
                 "comment": c("On bloque et on prépare …b5 pour récupérer le pion avec du jeu.",
                              "Block, then prepare …b5 to regain the pawn with active play.")},
                "Bc4", "b5", "Bb3",
                {"san": "Bg4", "critical": True,
                 "comment": c("L'ORDRE compte : …Cxd5 tout de suite perd une pièce, car le fou d7 bouche la colonne d et la dame ne défend pas d5. On dégage d'abord.",
                              "MOVE ORDER matters: …Nxd5 at once drops a piece — the d7 bishop blocks the d-file, so the queen does not defend d5. Clear the file first.")},
                "Nf3",
                {"san": "Nxd5",
                 "comment": c("Maintenant seulement : la dame d8 défend le cavalier, le pion est repris pour de bon.",
                              "Only now: the d8 queen defends the knight and the pawn comes back for good.")},
            ],
        },

        # ── Les Blancs déclinent : 2.Cc3 et 2.e5 ──────────────────────────────
        {
            "chapter": {"id": "white-declines", "title": c("Les Blancs déclinent", "White declines")},
            "moves": [
                "e4", "d5",
                {"san": "Nc3",
                 "comment": c("Les Blancs refusent d'échanger. Après …dxe4 Cxe4, les Noirs égalisent sans peine.",
                              "White declines the exchange. After …dxe4 Nxe4, Black equalises comfortably.")},
                "dxe4", "Nxe4",
            ],
        },
        {
            "chapter": {"id": "white-declines", "title": c("Les Blancs déclinent", "White declines")},
            "moves": [
                "e4", "d5",
                {"san": "e5", "role": "inaccuracy",
                 "comment": c("Pousser plutôt qu'échanger rend le fou de cases blanches très heureux : …Ff5 et les Noirs sont déjà à l'aise.",
                              "Pushing instead of trading makes the light-squared bishop very happy: …Bf5 and Black is already comfortable.")},
                "Bf5",
            ],
        },

        # ── 3.Cc3 après 2…Cf6 (trou de couverture n°1, 38 % des parties) ──────
        {
            "chapter": {"id": "nf6-nc3", "title": c("2…Cf6 — 3.Cc3", "2…Nf6 — 3.Nc3")},
            "moves": [
                "e4", "d5", "exd5",
                "Nf6",
                {"san": "Nc3",
                 "comment": c("Les Blancs défendent le pion d5 avec une pièce au lieu de le pousser. C'est leur coup le plus fréquent ici, et il change la nature de la partie : le pion va tomber, mais la structure blanche aussi.",
                              "White defends the d5 pawn with a piece rather than pushing. It's their most common move here, and it changes the nature of the game: the pawn will fall, but so will White's structure."),
                 "critical": True},
                {"san": "Nxd5",
                 "comment": c("On reprend enfin, et le cavalier se retrouve superbement centralisé — attaqué par rien.",
                              "Now we recapture, and the knight sits beautifully centralised — attacked by nothing.")},
                "Nf3",
                {"san": "Nxc3",
                 "comment": c("L'échange qui donne son sens à la variante : les Blancs vont devoir reprendre avec un pion.",
                              "The trade that gives the line its point: White will have to recapture with a pawn.")},
                {"san": "bxc3",
                 "comment": c("Pions doublés en c2-c3. En échange les Blancs tiennent un centre large et la colonne b ouverte : la position est équilibrée, pas gagnée.",
                              "Doubled pawns on c2-c3. In return White holds a broad centre and the open b-file: the position is balanced, not won.")},
                {"san": "g6",
                 "comment": c("Le fou ira en g7 mordre sur ce centre et sur les pions doublés. C'est le plan naturel des Noirs ici.",
                              "The bishop heads for g7 to bite at that centre and those doubled pawns. That's Black's natural plan here."),
                 "critical": True},
            ],
        },

        # ── 4.Cf3 avant d4 (trous n°2, 3 et 4 : le MÊME défaut d'ordre) ───────
        #
        # Les trois retraites de dame subissent la même chose : les Blancs
        # jouent Cf3 avant d4. Le relevé de couverture les comptait comme trois
        # trous distincts (46 %, 42 % et 36 % des parties) ; ce n'en est qu'un,
        # et il se raconte une fois. Le graphe étant indexé par FEN, chaque
        # ligne REJOINT ensuite le chapitre existant sans le dupliquer.
        {
            "chapter": {"id": "nf3-order", "title": c("4.Cf3 avant d4", "4.Nf3 before d4")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qd6",
                {"san": "Nf3",
                 "comment": c("Très fréquent, et déroutant si l'on a appris la ligne dans l'autre ordre : les Blancs développent le cavalier AVANT de pousser d4.",
                              "Very common, and disorienting if you learned the line in the other order: White develops the knight BEFORE playing d4."),
                 "critical": True},
                {"san": "Nf6",
                 "comment": c("On développe soi aussi, sans se laisser distraire.",
                              "We develop too, without being distracted.")},
                {"san": "d4",
                 "comment": c("Et voilà : c'est exactement la position du chapitre « Moderne — 3…Dd6 », atteinte par un autre chemin. Rien de nouveau à apprendre, il fallait juste ne pas paniquer.",
                              "And there it is: exactly the position from the “Modern — 3…Qd6” chapter, reached by another route. Nothing new to learn — you just had to keep your nerve.")},
            ],
        },
        {
            "chapter": {"id": "nf3-order", "title": c("4.Cf3 avant d4", "4.Nf3 before d4")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qd8", "Nf3",
                {"san": "Bf5",
                 "comment": c("Même principe que dans tout le répertoire : le fou de cases blanches sort AVANT …e6, sinon il reste enfermé pour la partie.",
                              "Same principle as everywhere in this repertoire: the light-squared bishop comes out BEFORE …e6, or it stays shut in for the game.")},
                "d4",
                {"san": "Nf6",
                 "comment": c("On rejoint « Autres retraites de dame ». L'ordre des Blancs n'a rien changé au plan.",
                              "We rejoin “Other queen retreats”. White's move order changed nothing about the plan.")},
            ],
        },
        {
            "chapter": {"id": "nf3-order", "title": c("4.Cf3 avant d4", "4.Nf3 before d4")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qa5", "Nf3", "Nf6", "d4",
                {"san": "c6",
                 "comment": c("Et l'on retombe sur la ligne principale, celle de la case de repli en c7/d8. Trois ordres différents, une seule position à connaître.",
                              "And we land back in the main line, the one with the c7/d8 retreat square. Three different move orders, a single position to know.")},
            ],
        },

        # ── Trous comblés le 21/08 : les quatre coups blancs les plus joués que
        # le répertoire laissait sans réponse (coverage.py). Lignes calculées au
        # moteur (suggest.py, profondeur 24) puis passées à audit.py. ──────────
        {
            "chapter": {"id": "nf6", "title": c("3…Cf6 — la Scandinave moderne", "3…Nf6 — the Modern Scandinavian")},
            "moves": [
                "e4", "d5", "exd5", "Nf6", "Nc3", "Nxd5",
                {"san": "Nxd5",
                 "comment": c("Les Blancs échangent — près de deux fois sur trois — et le répertoire ne voyait que Cf3. Rien de dramatique : notre dame va reprendre au centre, activement.",
                              "White trades — nearly two times in three — and the repertoire only saw Nf3. Nothing alarming: our queen recaptures in the centre, actively."),
                 "critical": True},
                {"san": "Qxd5",
                 "comment": c("Et non …exd5 : la dame est bien ici, et surtout aucun cavalier blanc ne vient plus la chasser avec gain de temps.",
                              "And not …exd5: the queen belongs here, and above all no white knight is left to chase her with tempo.")},
                "d4",
                {"san": "e5",
                 "comment": c("Le coup libérateur, et seulement MAINTENANT : on rend le pion d si besoin, les pièces sortent toutes seules et la partie s'égalise. Le jouer un temps plus tôt, à la place de …Dxd5, coûterait une pièce.",
                              "The freeing move — and only NOW: we give back the d-pawn if we must, every piece develops itself and the game levels out. Playing it one move earlier, instead of …Qxd5, would cost a piece."),
                 "critical": True},
                "Nf3", "Nc6", "Be3", "Bf5", "dxe5", "Qxd1+", "Kxd1",
            ],
        },
        {
            "chapter": {"id": "nf6", "title": c("3…Cf6 — la Scandinave moderne", "3…Nf6 — the Modern Scandinavian")},
            "moves": [
                "e4", "d5", "exd5", "Nf6",
                {"san": "Nf3",
                 "comment": c("Les Blancs se développent au lieu de défendre le pion : ils l'abandonnent tranquillement pour prendre de l'avance. Un joueur sur sept, et le répertoire n'avait rien à dire.",
                              "White develops instead of defending the pawn: they hand it back calmly in exchange for a lead. One player in seven, and the repertoire had nothing to say."),
                 "critical": True},
                {"san": "Nxd5",
                 "comment": c("On reprend au cavalier — pas de dame exposée ici, et c'est précisément ce que 3…Cf6 cherchait.",
                              "We recapture with the knight — no exposed queen here, and that is exactly what 3…Nf6 was after.")},
                "d4",
                {"san": "Bf5",
                 "comment": c("Le bon fou dehors AVANT …e6 : la règle d'or de toute Scandinave, sans exception.",
                              "The good bishop out BEFORE …e6: the golden rule of every Scandinavian, no exceptions.")},
                "Bd3", "Bxd3", "Qxd3", "e6", "c4", "Nf6", "O-O",
            ],
        },
        {
            "chapter": {"id": "mainline", "title": c("Ligne principale — 3…Da5", "Main line — 3…Qa5")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5",
                {"san": "Nf3",
                 "comment": c("Les Blancs renoncent au gain de temps par Cc3 : la dame n'est pas chassée, elle peut donc rester où elle est un moment.",
                              "White passes on the Nc3 tempo: the queen is not being chased, so she can stay put for a while."),
                 "critical": True},
                {"san": "Bg4",
                 "comment": c("On cloue le cavalier qui garde d4 et e5. Puisque personne ne nous presse, on développe en gênant.",
                              "We pin the knight that guards d4 and e5. Since nobody is hurrying us, we develop and annoy at the same time.")},
                "Be2", "Nc6", "d4", "O-O-O",
                {"san": "c4",
                 "comment": c("Le grand roque est déjà fait, nos tours sont reliées, et la colonne d nous appartient : le retard de développement de la Scandinave est effacé.",
                              "We have already castled long, our rooks are connected and the d-file is ours: the Scandinavian's development lag is gone."),
                 "critical": True},
                "Qf5", "Be3", "Bxf3", "Bxf3",
            ],
        },
        {
            "chapter": {"id": "mainline", "title": c("Ligne principale — 3…Da5", "Main line — 3…Qa5")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qe5+",
                {"san": "Qe2",
                 "comment": c("Les Blancs proposent l'échange des dames — une fois sur trois — et le répertoire n'avait prévu que Fe2. Accepter est le plus simple.",
                              "White offers the queen trade — one time in three — and the repertoire only planned for Be2. Accepting is simplest."),
                 "critical": True},
                {"san": "Qxe2+",
                 "comment": c("Sans les dames, le retard de développement pèse beaucoup moins : il n'y a plus personne pour l'exploiter vite.",
                              "Without queens the development lag matters far less: nobody is left to exploit it quickly.")},
                "Bxe2", "Nf6", "Nf3", "Bd7",
                {"san": "d4",
                 "comment": c("La finale est saine. Le fou d7 rejoindra c6, le cavalier b8 sortira sans être bousculé, et la structure noire est intacte.",
                              "The endgame is sound. The d7 bishop will come to c6, the b8 knight develops unhindered, and Black's structure is intact.")},
                "e6", "Bf4", "Bd6", "Ne5",
            ],
        },

        # ── Seconde passe du 22/08 : cinq trous plus profonds, tous à des
        # positions que le premier lot venait d'ouvrir. Chemins RECONSTRUITS
        # depuis le graphe (`path_to_hole.py`) et non lus à l'œil : trois des
        # cinq séquences déduites à la main étaient fausses, et une ligne
        # calculée pour la mauvaise position passe l'audit sans rien combler. ──
        {
            "chapter": {"id": "nf6", "title": c("3…Cf6 — la Scandinave moderne", "3…Nf6 — the Modern Scandinavian")},
            "moves": [
                "e4", "d5", "exd5", "Nf6", "Nc3", "Nxd5", "Nxd5", "Qxd5",
                {"san": "Nf3",
                 "comment": c("Une fois sur deux les Blancs développent avant de pousser d4 — le premier lot n'avait prévu que d4. La dame noire n'est pas chassée, on peut donc l'employer.",
                              "Half the time White develops before pushing d4 — the first batch only planned for d4. Black's queen is not being chased, so we can put her to work."),
                 "critical": True},
                {"san": "Nc6",
                 "comment": c("On développe en visant d4 : chaque pièce noire doit gêner cette poussée, sinon les Blancs prennent le centre gratuitement.",
                              "We develop while eyeing d4: every black piece should hinder that push, otherwise White takes the centre for free.")},
                "d4", "Bg4", "c4",
                {"san": "Qf5",
                 "comment": c("La dame trouve sa case : hors de portée des coups de tempo, et elle garde le clouage en g4 sous protection.",
                              "The queen finds her square: out of reach of tempo moves, and she keeps the g4 pin protected."),
                 "critical": True},
                "Be2", "O-O-O", "Be3", "e6",
            ],
        },
        {
            "chapter": {"id": "qd8", "title": c("3…Dd8 — la retraite discrète", "3…Qd8 — the quiet retreat")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3",
                {"san": "Qd8",
                 "comment": c("La retraite la plus modeste, et la plus solide : la dame rentre chez elle, les Blancs n'ont plus une seule cible et devront construire leur avantage à la main.",
                              "The most modest retreat, and the soundest: the queen goes home, White has no target left and must build any advantage by hand."),
                 "critical": True},
                {"san": "Bc4",
                 "comment": c("Le fou sort avant le cavalier : les Blancs visent f7 et gardent Cf3 ou d4 en réserve. Le cours ne connaissait que ces deux-là.",
                              "The bishop before the knight: White eyes f7 and keeps Nf3 or d4 in reserve. The course only knew those two."),
                 "critical": True},
                {"san": "c5",
                 "comment": c("On ne se laisse pas installer : puisque les Blancs ont retardé d4, on prend la case avant eux.",
                              "We refuse to be squeezed: since White has delayed d4, we take the square first.")},
                "Nf3", "Nc6", "Qe2", "e6", "O-O", "Be7", "d4", "cxd4", "Rd1",
            ],
        },
        {
            "chapter": {"id": "qd8", "title": c("3…Dd8 — la retraite discrète", "3…Qd8 — the quiet retreat")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qd8", "Nf3", "Bf5",
                {"san": "Bc4",
                 "comment": c("Les Blancs pressent f7 pendant que notre fou est sorti de l'autre côté. C'est le moment délicat de cette ligne.",
                              "White presses f7 while our bishop is out on the other side. This is the awkward moment of the line."),
                 "critical": True},
                {"san": "e6",
                 "comment": c("On ferme la diagonale et on libère le fou roi. L'ordre compte : …e6 APRÈS avoir sorti le fou dame, jamais avant — c'est la règle de toute la Scandinave.",
                              "We close the diagonal and free the king's bishop. The order matters: …e6 AFTER the queen's bishop is out, never before — the rule of the whole Scandinavian."),
                 "critical": True},
                "d4", "c6", "h3", "Nd7", "O-O", "Bd6", "Bg5", "Ngf6",
            ],
        },
        {
            "chapter": {"id": "mainline", "title": c("Ligne principale — 3…Da5", "Main line — 3…Qa5")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qa5", "d4", "Nf6",
                {"san": "Bd2",
                 "comment": c("Le coup le plus joué ici — près d'une fois sur deux — et le cours n'avait que Cf3. Les Blancs préparent Cd5 en dégageant la case, tout en menaçant de gagner un temps sur notre dame.",
                              "The most played move here — nearly half the time — and the course only had Nf3. White prepares Nd5 by clearing the square, while threatening to gain a tempo on our queen."),
                 "critical": True},
                {"san": "Bg4",
                 "comment": c("On sort le fou avec une menace plutôt que de reculer la dame : le clouage sur f3 gêne d4 et gagne le temps que les Blancs voulaient nous prendre.",
                              "We develop the bishop with a threat instead of retreating the queen: the pin on f3 hampers d4 and wins back the tempo White wanted from us."),
                 "critical": True},
                "f3", "Bd7", "f4", "a6", "Nf3", "Qb6", "Ne5", "e6",
            ],
        },
        {
            "chapter": {"id": "mainline", "title": c("Ligne principale — 3…Da5", "Main line — 3…Qa5")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qe5+",
                {"san": "Nge2",
                 "comment": c("Le cavalier bloque l'échec par la case e2 plutôt que par le fou. Le cours prévoyait Fe2 et De2 ; celui-ci manquait.",
                              "The knight blocks the check on e2 rather than the bishop. The course planned for Be2 and Qe2; this one was missing."),
                 "critical": True},
                {"san": "Nf6",
                 "comment": c("On développe sans se soucier de la dame : elle reculera d'elle-même en a5 quand les Blancs la chasseront, et ce sera un coup utile.",
                              "We develop without fussing over the queen: she will drop back to a5 when White chases her, and that will be a useful move.")},
                "d4", "Qa5", "Nf4", "e6", "a3", "Be7", "Bc4", "O-O", "O-O",
            ],
        },

        # ── Lot 29 : le développement blanc naturel, dans tous les ordres ─────
        # Cinq des douze trous les plus coûteux du cours étaient le MÊME coup —
        # Fc4, Fe2 ou Cf3 joué avant d4 — dans cinq ordres différents. Le club
        # développe avant de pousser ; le cours ne prévoyait que la poussée.
        {
            "chapter": {"id": "qd6", "title": c("Moderne — 3…Dd6", "Modern — 3…Qd6")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qd6", "Nf3", "Nf6",
                {"san": "Bc4",
                 "comment": c("Le fou sort avant d4 : les Blancs visent f7 pendant que la dame est encore en d6. Près d'une partie sur quatre à cet endroit, et le chapitre ne prévoyait que la poussée.",
                              "The bishop comes out before d4: White eyes f7 while the queen still sits on d6. Nearly one game in four here, and the chapter only planned for the push."),
                 "critical": True},
                {"san": "a6",
                 "comment": c("Le système de Tiviakov, exactement comme après d4 : …a6 d'abord, …b5 et …Fb7 ensuite. Le moteur préfère …Cc6 d'un cheveu — mais ce chapitre enseigne un PLAN, et changer de plan trois coups après l'avoir annoncé n'apprend rien.",
                              "Tiviakov's system, exactly as after d4: …a6 first, then …b5 and …Bb7. The engine marginally prefers …Nc6 — but this chapter teaches a PLAN, and switching plan three moves after announcing it teaches nothing."),
                 "critical": True},
                "d4",
                {"san": "b5",
                 "comment": c("Le temps gagné sur le fou c4 finance tout le développement de l'aile dame.",
                              "The tempo won against the c4 bishop pays for the whole queenside development.")},
                "Bd3",
                {"san": "Bb7",
                 "comment": c("Le fou trouve sa grande diagonale : c'est ce qui distingue ce système des lignes à …Ff5.",
                              "The bishop finds its long diagonal: that is what sets this system apart from the …Bf5 lines.")},
                "Qe2", "e6", "O-O", "Be7", "Ne4",
            ],
        },
        {
            "chapter": {"id": "mainline", "title": c("Ligne principale — 3…Da5", "Main line — 3…Qa5")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qa5", "Nf3", "Nf6",
                {"san": "Bc4",
                 "comment": c("Les Blancs sortent le fou avant de pousser d4 — plus d'une partie sur quatre. Le cours n'avait que d4 ici.",
                              "White develops the bishop before pushing d4 — more than one game in four. The course only had d4 here."),
                 "critical": True},
                {"san": "Bf5",
                 "comment": c("La règle du cours ne change pas parce que l'ordre change : le fou de cases blanches sort AVANT …e6.",
                              "The rule of the course does not change because the move order does: the light-squared bishop comes out BEFORE …e6."),
                 "critical": True},
                "d4", "e6", "Bd2",
                {"san": "Bb4",
                 "comment": c("On cloue le cavalier qui tient d5 et e4 : c'est lui, et pas le fou, qui gêne notre position.",
                              "We pin the knight that holds d5 and e4: it is the knight, not the bishop, that cramps us.")},
                "a3",
                {"san": "Bxc3",
                 "comment": c("On rend la paire de fous sans hésiter — le cavalier c3 disparu, la dame b6 prend le relais sur la diagonale.",
                              "We give up the bishop pair without hesitation — with the c3 knight gone, the queen takes over on the diagonal.")},
                "Bxc3", "Qb6", "Qe2",
            ],
        },
        {
            "chapter": {"id": "portuguese", "title": c("Gambit portugais — 3…Fg4", "Portuguese Gambit — 3…Bg4")},
            "moves": [
                "e4", "d5", "exd5", "Nf6", "d4", "Bg4",
                {"san": "Be2",
                 "comment": c("La réponse la plus fréquente au gambit — 42 % des parties — et la seule que le cours ne traitait pas. Les Blancs proposent l'échange pour rendre le pion dans de bonnes conditions.",
                              "The most common reply to the gambit — 42 % of games — and the only one the course did not cover. White offers the trade in order to return the pawn on good terms."),
                 "critical": True},
                {"san": "Bxe2",
                 "comment": c("On prend. Garder le clouage coûterait précisément le temps que le gambit nous a déjà coûté.",
                              "We take. Keeping the pin would cost exactly the tempo the gambit has already cost us.")},
                "Qxe2",
                {"san": "Qxd5",
                 "comment": c("Le pion revient enfin. Sans les fous de cases blanches, le léger retard noir ne se paie plus.",
                              "The pawn comes back at last. With the light-squared bishops gone, Black's small lag no longer costs anything.")},
                "Nf3", "e6", "O-O", "Nc6", "Rd1",
                {"san": "O-O-O",
                 "comment": c("Le grand roque met notre tour face à la sienne sur la colonne d : c'est la compensation naturelle de tout le gambit.",
                              "Castling long puts our rook opposite White's on the d-file: the natural compensation for the whole gambit.")},
                "c4",
            ],
        },
        {
            "chapter": {"id": "nf6", "title": c("2…Cf6 — l'ordre moderne", "2…Nf6 — the modern move order")},
            "moves": [
                "e4", "d5", "exd5", "Nf6", "d4", "Nxd5",
                {"san": "Nf3",
                 "comment": c("Quatre parties sur dix : les Blancs développent avant de chasser le cavalier par c4. Le cours n'avait que c4.",
                              "Four games in ten: White develops before chasing the knight with c4. The course only had c4."),
                 "critical": True},
                {"san": "Bf5",
                 "comment": c("Même règle, encore : le fou avant …e6. Ici il gagne en plus une case d'échange en d3, qui fait disparaître le fou blanc le plus actif.",
                              "The same rule again: the bishop before …e6. Here it also gains a trading square on d3, which removes White's most active piece."),
                 "critical": True},
                "Bd3", "Bxd3", "Qxd3", "e6", "c4",
                {"san": "Nf6",
                 "comment": c("Le cavalier recule sans regret : il a rempli son office, et le fou blanc le plus dangereux a déjà quitté l'échiquier.",
                              "The knight drops back without regret: it has done its job, and White's most dangerous bishop has already left the board.")},
                "Nc3", "c6", "O-O",
            ],
        },
        {
            "chapter": {"id": "nf6", "title": c("2…Cf6 — l'ordre moderne", "2…Nf6 — the modern move order")},
            "moves": [
                "e4", "d5", "exd5", "Nf6", "Nf3", "Nxd5",
                {"san": "Bc4",
                 "comment": c("Le fou attaque le cavalier d5 avant même d4 : plus d'une fois sur trois. Le cours ne prévoyait que d4.",
                              "The bishop hits the d5 knight before d4 is even played: more than one time in three. The course only planned for d4."),
                 "critical": True},
                {"san": "Bf5",
                 "comment": c("On sort quand même le fou : le cavalier d5 est défendu par la dame, il n'a besoin de personne d'autre.",
                              "We develop the bishop anyway: the d5 knight is defended by the queen and needs nobody else."),
                 "critical": True},
                "d4", "e6", "O-O", "Be7", "Bd3", "Bxd3", "Qxd3",
                {"san": "c5",
                 "comment": c("On frappe le centre juste après la disparition du fou blanc — c'est le coup qui égalise.",
                              "We hit the centre the moment White's bishop is gone — this is the move that equalises.")},
                "dxc5",
            ],
        },
        {
            "chapter": {"id": "mainline", "title": c("Ligne principale — 3…Da5", "Main line — 3…Qa5")},
            "moves": [
                "e4", "d5", "exd5", "Qxd5", "Nc3", "Qe5+", "Qe2", "Qxe2+",
                {"san": "Ngxe2",
                 "comment": c("La reprise du cavalier de g1, et non du fou : une fois sur cinq. Le cavalier ira en g3 ou f4, où il vaut mieux qu'en f3.",
                              "Recapturing with the g1 knight rather than the bishop: one time in five. The knight heads for g3 or f4, where it stands better than on f3."),
                 "critical": True},
                {"san": "Nf6",
                 "comment": c("Développement d'abord : sans les dames, notre léger retard n'a plus personne pour l'exploiter.",
                              "Development first: with the queens off, nobody is left to punish our small lag.")},
                "d4", "c6", "Ng3",
                {"san": "g6",
                 "comment": c("Le fianchetto : le fou g7 fixe d4 et compense largement la case d5 laissée aux Blancs.",
                              "The fianchetto: the g7 bishop bears down on d4 and amply offsets the d5 square left to White.")},
                "Bc4", "Bg7", "O-O", "O-O", "Re1",
            ],
        },
    ],
}
