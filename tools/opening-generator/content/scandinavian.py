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
    ],
}
