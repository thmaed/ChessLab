# -*- coding: utf-8 -*-
"""Sicilienne dragon et dragon accélérée (1.e4 c5 … …g6) — NOIR.

Arbre approfondi : Attaque yougoslave (Soltis 9.Fc4, la rupture …d5, Dragon
chinois …Tb8), Classique 6.Fe2, Levenfish 6.f4, dragon accélérée et étau
Maroczy 5.c4. Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-dragon",
    "name": "Sicilian Defense: Dragon",
    "side": "black",
    "level": "advanced",
    "eco": ["B70", "B79"],
    "summary": c(
        "Le fou en g7 crache le feu sur la grande diagonale. Attaques opposées, courses de pions : la sicilienne la plus explosive.",
        "The g7 bishop breathes fire down the long diagonal. Opposite-side castling and pawn races: the most explosive Sicilian.",
    ),
    "lines": [
        # 1) Attaque yougoslave — variante Soltis (ligne principale)
        {
            "chapter": {"id": "yugoslav-soltis", "title": c("Yougoslave — Soltis 9.Fc4", "Yugoslav — Soltis 9.Bc4")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3",
                {"san": "g6", "eco": "Sicilian Defense: Dragon Variation",
                 "comment": c("Le Dragon : le fou ira en g7, âme de toute la variante.",
                              "The Dragon: the bishop heads for g7, the soul of the whole line.")},
                {"san": "Be3", "comment": c("Les Blancs préparent l'Attaque yougoslave : Dd2, 0-0-0, h4-h5.",
                                            "White prepares the Yugoslav: Qd2, 0-0-0, h4-h5.")},
                "Bg7",
                {"san": "f3", "comment": c("Le pion soutient e4 et coupe la case g4 : préparatif indispensable de l'assaut h4-h5.",
                                           "The pawn props up e4 and takes g4 away: an essential prelude to the h4-h5 storm.")},
                "O-O",
                {"san": "Qd2", "comment": c("La dame relie les tours ; roque long en vue.",
                                            "The queen connects the rooks; long castling is coming.")},
                "Nc6",
                {"san": "Bc4", "comment": c("Le fou en c4 freine …d5 et vise f7 : c'est la variante Soltis qui se profile.",
                                            "The bishop on c4 restrains …d5 and eyes f7: the Soltis variation is on the way.")},
                {"san": "Bd7", "comment": c("On développe et on prépare …Tc8 : la colonne c est l'autoroute de l'attaque noire.",
                                            "Develop and ready …Rc8: the c-file is the highway of Black's attack.")},
                "O-O-O",
                {"san": "Rc8", "comment": c("La tour se dresse face au roi blanc ; menace un jour …Cxc4 puis …Txc3.",
                                            "The rook lines up on White's king; …Nxc4 and …Rxc3 are in the air.")},
                "Bb3",
                {"san": "Ne5", "comment": c("Le cavalier saute en e5, prêt à …Cc4 et au sacrifice de qualité …Txc3.",
                                            "The knight jumps to e5, ready for …Nc4 and the exchange sac …Rxc3.")},
                {"san": "h4", "comment": c("La course commence : h4-h5 pour ouvrir la colonne h contre le roque noir.",
                                           "The race begins: h4-h5 to prise open the h-file against Black's king.")},
                {"san": "h5", "comment": c("La parade Soltis : …h5 fige l'aile roi avant que h5 n'ouvre les lignes.",
                                           "The Soltis reply: …h5 freezes the kingside before h5 can open lines.")},
                {"san": "Bg5", "comment": c("Les Blancs manœuvrent pour Fh6 et l'échange du fou-dragon.",
                                            "White manoeuvres for Bh6 to swap off the dragon bishop.")},
                {"san": "Rc5", "comment": c("Idée typique : la tour défend h5 latéralement et couve …b5.",
                                            "Typical idea: the rook defends h5 sideways and nurses …b5.")},
            ],
        },
        # 2) Yougoslave — la rupture …d5
        {
            "chapter": {"id": "yugoslav-d5", "title": c("Yougoslave — la rupture …d5", "Yugoslav — the …d5 break")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "g6", "Be3", "Bg7", "f3", "O-O", "Qd2", "Nc6",
                {"san": "O-O-O", "comment": c("Quand les Blancs roquent sans Fc4, …d5 devient l'antidote classique.",
                                              "When White castles without Bc4, …d5 is the classic antidote.")},
                {"san": "d5", "comment": c("La libération : d'un coup on ouvre le centre et on dévie le cavalier c3.",
                                           "Liberation: in one move the centre opens and the c3-knight is deflected.")},
                "exd5", "Nxd5", "Nxc6", "bxc6",
                {"san": "Bd4", "comment": c("Les Blancs proposent l'échange des fous noirs pour désamorcer la diagonale.",
                                            "White offers to trade the dark-squared bishops to defuse the diagonal.")},
                "e5", "Bc5", "Be6",
            ],
        },
        # 3) Dragon chinois — …Tb8 et …b5
        {
            "chapter": {"id": "chinese", "title": c("Dragon chinois — …Tb8", "Chinese Dragon — …Rb8")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "g6", "Be3", "Bg7", "f3", "O-O", "Qd2", "Nc6",
                "Bc4", "Bd7", "O-O-O",
                {"san": "Rb8", "comment": c("Le Dragon chinois : la tour va en b8 pour lancer …b5-b4 comme un bélier.",
                                            "The Chinese Dragon: the rook swings to b8 to ram …b5-b4 home.")},
                "Bb3", "Na5",
                {"san": "h4", "comment": c("Chacun fonce sur le roque adverse : c'est à celui qui arrivera le premier.",
                                           "Each side charges the enemy king: it's a matter of who lands first.")},
                "b5",
            ],
        },
        # 4) Variante classique — 6.Fe2
        {
            "chapter": {"id": "classical", "title": c("Classique — 6.Fe2", "Classical — 6.Be2")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "g6",
                {"san": "Be2", "comment": c("Le traitement calme : petit roque et jeu positionnel, sans l'orage yougoslave.",
                                            "The quiet approach: short castling and positional play, no Yugoslav storm.")},
                "Bg7", "O-O", "O-O", "Nb3", "Nc6", "Be3", "Be6", "f4",
                {"san": "Na5", "comment": c("Le cavalier va échanger en b3 pour alléger la pression et viser …d5/…b5.",
                                            "The knight heads to swap on b3, easing the pressure and eyeing …d5/…b5.")},
            ],
        },
        # 5) Levenfish — 6.f4
        {
            "chapter": {"id": "levenfish", "title": c("Levenfish — 6.f4", "Levenfish — 6.f4")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "g6",
                {"san": "f4", "comment": c("L'attaque Levenfish : les Blancs foncent, mais …Fg7 y est prématuré.",
                                           "The Levenfish Attack: White charges, but …Bg7 here is premature.")},
                {"san": "Nc6", "comment": c("Le bon ordre : d'abord …Cc6. Après …Fg7?! 7.e5 est très gênant.",
                                            "The right order: …Nc6 first. After …Bg7?! 7.e5 is very awkward.")},
                "Nxc6", "bxc6",
                {"san": "e5", "comment": c("Les Blancs bousculent le centre ; les Noirs rendent la structure solide par …Cd7.",
                                           "White jolts the centre; Black keeps things solid with …Nd7.")},
                "Nd7", "exd6", "exd6",
            ],
        },
        {
            "chapter": {"id": "levenfish", "title": c("Levenfish — 6.f4", "Levenfish — 6.f4")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "g6", "f4",
                {"san": "Bg7", "role": "inaccuracy", "critical": True,
                 "comment": c("Imprécis : jouer …Fg7 tout de suite permet le coup de bélier suivant.",
                              "Inaccurate: playing …Bg7 at once allows the following pawn thrust.")},
                {"san": "e5", "role": "trap",
                 "comment": c("7.e5 ! Le cavalier f6 est attaqué et la grande diagonale se retourne contre les Noirs.",
                              "7.e5! The f6-knight is hit and the long diagonal turns against Black.")},
                "dxe5", "fxe5", "Nd5", "Bc4", "Nb6",
            ],
        },
        # 6) Dragon accélérée
        {
            "chapter": {"id": "accelerated", "title": c("Dragon accélérée", "Accelerated Dragon")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4",
                {"san": "g6", "eco": "Sicilian Defense: Accelerated Dragon",
                 "comment": c("La version accélérée : …g6 sans …d6, pour gagner un temps et viser …d5 d'un coup.",
                              "The accelerated version: …g6 without …d6, saving a tempo and eyeing …d5 in one go.")},
                {"san": "Nc3", "comment": c("Sans l'étau Maroczy, les Noirs obtiennent un jeu confortable et actif.",
                                            "Without the Maróczy bind, Black gets comfortable, active play.")},
                "Bg7", "Be3", "Nf6",
                {"san": "Bc4", "comment": c("Le fou vise f7 ; les Noirs répliqueront par …0-0 puis …d6 et …Fd7.",
                                            "The bishop eyes f7; Black replies with …0-0, then …d6 and …Bd7.")},
                "O-O", "Bb3", "d6", "f3", "Bd7", "Qd2", "Rc8",
            ],
        },
        # 7) Étau Maroczy — 5.c4
        {
            "chapter": {"id": "maroczy", "title": c("Étau Maroczy — 5.c4", "Maróczy Bind — 5.c4")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "d4", "cxd4", "Nxd4", "g6",
                {"san": "c4", "eco": "Sicilian Defense: Accelerated Dragon, Maróczy Bind",
                 "comment": c("L'étau Maroczy : les pions c4+e4 briment …d5. Les Noirs jouent patient et cherchent …f5 ou …b5.",
                              "The Maróczy bind: the c4+e4 pawns restrain …d5. Black plays patiently, aiming for …f5 or …b5.")},
                "Bg7", "Be3", "Nf6", "Nc3", "d6", "Be2", "O-O", "O-O",
                {"san": "Bd7", "comment": c("Le système Gurgenidze : …Fd7 prépare …Cxd4 puis …Fc6 pour pilonner e4.",
                                            "The Gurgenidze system: …Bd7 prepares …Nxd4 then …Bc6 to hammer e4.")},
                "Qd2", "Nxd4", "Bxd4", "Bc6",
            ],
        },
    ],
}
