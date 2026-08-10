# -*- coding: utf-8 -*-
"""Sicilienne Najdorf (1.e4 c5 2.Cf3 d6 3.d4 cxd4 4.Cxd4 Cf6 5.Cc3 a6) — NOIR.

Arbre approfondi : Attaque anglaise 6.Fe3 (contre …e5 et …e6), ligne principale
6.Fg5 (6…Fe7 et le Pion empoisonné 6…Db6), Classique 6.Fe2, Fischer-Sozin
6.Fc4, Fianchetto 6.g3, Adams 6.h3. Lignes vérifiées (Wikipédia + lichess).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "sicilian-najdorf",
    "name": "Sicilian Defense: Najdorf",
    "side": "black",
    "level": "advanced",
    "eco": ["B90", "B99"],
    "summary": c(
        "La sicilienne la plus prestigieuse : …a6 avant tout, pour préparer …e5 ou …e6 en gardant une flexibilité maximale. Théorie exigeante mais récompense énorme.",
        "The most prestigious Sicilian: …a6 first, to prepare …e5 or …e6 with maximum flexibility. Demanding theory, huge reward.",
    ),
    "lines": [
        # 1) Attaque anglaise — 6.Fe3 e5 (ligne principale moderne)
        {
            "chapter": {"id": "english-attack", "title": c("Attaque anglaise — 6.Fe3", "English Attack — 6.Be3")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3",
                {"san": "a6", "eco": "Sicilian Defense: Najdorf Variation",
                 "comment": c("Le coup Najdorf : discret mais capital, il contrôle b5 et prépare …e5/…e6.",
                              "The Najdorf move: quiet but crucial, it controls b5 and prepares …e5/…e6.")},
                {"san": "Be3", "comment": c("L'Attaque anglaise : les Blancs visent Dd2, 0-0-0 et une ruée de pions à l'aile roi.",
                                            "The English Attack: White aims for Qd2, 0-0-0 and a kingside pawn storm.")},
                {"san": "e5", "comment": c("On repousse le cavalier et on revendique le centre ; en retour, d5 devient un trou.",
                                           "Kick the knight and claim the centre; in return d5 becomes a hole.")},
                {"san": "Nb3", "comment": c("Le cavalier recule en b3 ; il vise a5 et garde le contact avec c5/d4.",
                                            "The knight drops to b3, eyeing a5 and keeping touch with c5/d4.")},
                {"san": "Be6", "comment": c("Le fou surveille d5, la case-clé de toute la Najdorf.",
                                            "The bishop watches d5, the key square of the whole Najdorf.")},
                {"san": "f3", "comment": c("On soutient e4, on prépare g4 et l'assaut de pions.",
                                           "Supporting e4 and preparing g4 and the pawn assault.")},
                "Be7",
                {"san": "Qd2", "comment": c("La dame relie les tours et prépare le grand roque.",
                                            "The queen connects the rooks and prepares queenside castling.")},
                "O-O", "O-O-O",
                {"san": "Nbd7", "comment": c("Le cavalier b8 va d7 (puis b6/f8) : le plan noir est …b5-b4 à l'aile dame.",
                                             "The b8-knight heads to d7 (then b6/f8): Black's plan is …b5-b4 on the queenside.")},
                {"san": "g4", "comment": c("Course de pions : les deux camps attaquent le roque adverse. Le plus rapide gagne.",
                                           "Pawn races: both sides storm the other's king. The faster attack wins.")},
                "b5",
                {"san": "g5", "comment": c("Le pion chasse le cavalier f6, gardien de d5 et e4.",
                                           "The pawn chases the f6-knight, guardian of d5 and e4.")},
                {"san": "b4", "comment": c("Intermède : au lieu de bouger le cavalier attaqué, on frappe c3 d'abord.",
                                           "Zwischenzug: instead of moving the attacked knight, hit c3 first.")},
                "Ne2", "Ne8", "f4",
                {"san": "a5", "comment": c("Les pions noirs déferlent ; la position est double tranchant et se joue coup pour coup.",
                                           "Black's pawns roll on; the position is double-edged and a race move for move.")},
            ],
        },
        # 2) Attaque anglaise contre 6...e6
        {
            "chapter": {"id": "english-e6", "title": c("Attaque anglaise — 6.Fe3 e6", "English Attack — 6.Be3 e6")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6", "Be3",
                {"san": "e6", "comment": c("Version Scheveningen : petit centre solide, on renonce à …e5 pour garder d5 sous contrôle.",
                                           "Scheveningen setup: a solid small centre, giving up …e5 to keep d5 covered.")},
                "f3", "b5",
                {"san": "Qd2", "comment": c("Même plan : Dd2, 0-0-0, g4. Ici les Noirs ripostent au centre par …d5.",
                                            "Same plan: Qd2, 0-0-0, g4. Here Black hits back in the centre with …d5.")},
                "Nbd7", "g4", "h6", "O-O-O", "b4",
                {"san": "Nce2", "comment": c("Le cavalier c3 recule pour ne pas être chassé ; d4 reste tenu.",
                                             "The c3-knight retreats so it isn't kicked; d4 stays covered.")},
                {"san": "d5", "comment": c("La rupture thématique : on ouvre le centre pendant que le roi blanc est fixé sur l'aile dame.",
                                           "The thematic break: opening the centre while White's king is stuck on the queenside.")},
                "exd5", "Nxd5",
            ],
        },
        # 3) Ligne principale historique — 6.Fg5 e6 7.f4 Fe7
        {
            "chapter": {"id": "main-bg5", "title": c("Ligne principale — 6.Fg5", "Main Line — 6.Bg5")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6",
                {"san": "Bg5", "comment": c("La ligne principale historique : clouage sur f6, jeu très tranchant.",
                                            "The historical main line: pin on f6, extremely sharp play.")},
                {"san": "e6", "comment": c("On soutient f6 et on garde la structure souple.",
                                           "Support f6 and keep the structure flexible.")},
                {"san": "f4", "comment": c("Le centre de pions e4+f4 prépare e5 et une attaque directe.",
                                           "The e4+f4 pawn centre prepares e5 and a direct attack.")},
                "Be7",
                {"san": "Qf3", "comment": c("La dame va en f3 puis g3/h3 ; les Blancs roquent long.",
                                            "The queen goes to f3, then g3/h3; White castles long.")},
                "Qc7", "O-O-O", "Nbd7",
                {"san": "g4", "comment": c("La ruée de pions commence, soutenue par le clouage sur f6.",
                                           "The pawn storm begins, backed by the pin on f6.")},
                "b5",
                {"san": "Bxf6", "comment": c("On échange le défenseur de f6 avant de pousser g5, pour dégager la voie.",
                                             "Trade off f6's defender before pushing g5, clearing the way.")},
                "Nxf6", "g5", "Nd7",
                {"san": "f5", "comment": c("Le centre s'ouvre à l'assaut ; la position est extrêmement pointue.",
                                           "The centre bursts open for the assault; razor-sharp play.")},
            ],
        },
        # 4) Pion empoisonné — 6.Fg5 e6 7.f4 Db6
        {
            "chapter": {"id": "poisoned-pawn", "title": c("Pion empoisonné — 6…Db6", "Poisoned Pawn — 6…Qb6")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6", "Bg5", "e6", "f4",
                {"san": "Qb6", "role": "trap", "critical": True,
                 "eco": "Sicilian Defense: Najdorf, Poisoned Pawn",
                 "comment": c("Le Pion empoisonné, favori de Fischer : la dame vise b2 en pleine ouverture. Sang-froid absolu requis.",
                              "The Poisoned Pawn, Fischer's favourite: the queen grabs b2 in the opening. Ice-cold nerves required.")},
                {"san": "Qd2", "comment": c("Les Blancs offrent b2 : après la prise, la dame noire sera loin et exposée.",
                                            "White offers b2: after the capture Black's queen is far away and exposed.")},
                {"san": "Qxb2", "comment": c("On accepte le défi. Le pion vaut du temps et une attaque pour les Blancs.",
                                             "Accepting the challenge. The pawn is worth time and an attack for White.")},
                "Rb1", "Qa3",
                {"san": "f5", "comment": c("Les Blancs frappent e6 pour ouvrir les lignes vers le roi noir.",
                                           "White strikes e6 to open lines toward Black's king.")},
                "Nc6", "fxe6", "fxe6", "Nxc6", "bxc6",
                {"san": "e5", "comment": c("Le coup thématique : e5 chasse le cavalier f6 et déchire le centre.",
                                           "The thematic push: e5 kicks the f6-knight and rips the centre open.")},
                "dxe5", "Bxf6", "gxf6",
            ],
        },
        # 5) Variante classique — 6.Fe2 e5
        {
            "chapter": {"id": "classical-be2", "title": c("Variante classique — 6.Fe2", "Classical — 6.Be2")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6",
                {"san": "Be2", "comment": c("Le développement calme : les Blancs roquent court et jouent positionnel autour de d5.",
                                            "The quiet setup: White castles short and plays positionally around d5.")},
                "e5", "Nb3", "Be7", "O-O", "O-O",
                {"san": "Be3", "comment": c("Le fou surveille c5 et soutiendra un futur f3/Dd2 ou Cd5.",
                                            "The bishop covers c5 and supports a later f3/Qd2 or Nd5.")},
                "Be6",
                {"san": "Qd2", "comment": c("Manœuvre lente ; les Blancs pèsent sur d5, les Noirs jouent …Cbd7-b6 et …a5.",
                                            "Slow manoeuvring; White presses d5, Black plays …Nbd7-b6 and …a5.")},
                "Nbd7", "a4", "Rc8",
            ],
        },
        # 6) Attaque Fischer-Sozin — 6.Fc4
        {
            "chapter": {"id": "fischer-sozin", "title": c("Fischer-Sozin — 6.Fc4", "Fischer-Sozin — 6.Bc4")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6",
                {"san": "Bc4", "comment": c("L'attaque Fischer-Sozin : le fou vise e6/f7 et pointe vers le roi noir.",
                                            "The Fischer-Sozin: the bishop targets e6/f7 and points at Black's king.")},
                {"san": "e6", "comment": c("On ferme la diagonale a2-g8 et on prépare …b5.",
                                           "Shutting the a2-g8 diagonal and preparing …b5.")},
                {"san": "Bb3", "comment": c("Le fou se met à l'abri en b3 avant que …b5 ne le chasse.",
                                            "The bishop tucks into b3 before …b5 can chase it.")},
                "b5", "O-O", "Be7", "Qf3", "Qc7",
                {"san": "Qg3", "comment": c("La dame passe à l'attaque à l'aile roi ; menace Fh6 et pression sur g7.",
                                            "The queen swings to the kingside; threatening Bh6 and pressure on g7.")},
                "O-O", "Bh6", "Ne8",
            ],
        },
        # 7) Fianchetto — 6.g3
        {
            "chapter": {"id": "fianchetto", "title": c("Fianchetto — 6.g3", "Fianchetto — 6.g3")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6",
                {"san": "g3", "comment": c("Le plan positionnel : Fg2 pesant sur la grande diagonale et le contrôle de d5.",
                                           "The positional plan: Bg2 bearing on the long diagonal and control of d5.")},
                "e5", "Nde2", "Be7", "Bg2", "O-O", "O-O", "Nbd7", "h3", "b5",
            ],
        },
        # 8) Attaque Adams — 6.h3
        {
            "chapter": {"id": "adams", "title": c("Attaque Adams — 6.h3", "Adams Attack — 6.h3")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "d4", "cxd4", "Nxd4", "Nf6", "Nc3", "a6",
                {"san": "h3", "comment": c("L'idée d'Adams : préparer g4 sans permettre …Cg4, puis attaquer.",
                                           "Adams' idea: prepare g4 without allowing …Ng4, then attack.")},
                "e5", "Nde2", "Be7", "g4", "b5", "Ng3", "Nbd7",
            ],
        },
    ],
}
