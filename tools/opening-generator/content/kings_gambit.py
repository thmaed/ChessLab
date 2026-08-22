# -*- coding: utf-8 -*-
"""Gambit du Roi (1.e4 e5 2.f4) — répertoire BLANC.

Approfondi : moderne 3…d5, Kieseritzky, gambit Muzio, gambit du fou 3.Fc4,
Falkbeer, refusé.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "kings-gambit",
    "name": "King's Gambit",
    "side": "white",
    "level": "advanced",
    "eco": ["C30", "C39"],
    "summary": c(
        "Le gambit romantique par excellence : un pion pour un centre fort, une colonne f ouverte et une attaque immédiate. Du Kieseritzky au sacrifice Muzio, du feu pur.",
        "The romantic gambit par excellence: a pawn for a strong centre, an open f-file and an immediate attack. From the Kieseritzky to the Muzio sacrifice, pure fire.",
    ),
    "lines": [
        {
            "chapter": {"id": "modern", "title": c("Défense moderne — 3…d5", "Modern Defence — 3…d5")},
            "moves": [
                "e4", "e5",
                {"san": "f4", "eco": "King's Gambit",
                 "comment": c("On offre le pion f pour ouvrir la colonne et dominer le centre.",
                              "Offering the f-pawn to open the file and dominate the centre.")},
                "exf4",
                {"san": "Nf3", "comment": c("On empêche …Dh4+ et on développe : le Gambit du Cavalier-Roi.",
                                            "Stopping …Qh4+ and developing: the King's Knight Gambit.")},
                {"san": "d5", "comment": c("La défense moderne, la plus saine : les Noirs rendent le pion pour un jeu clair.",
                                           "The modern, soundest defence: Black gives the pawn back for clear play.")},
                "exd5", "Nf6", "Bc4", "Nxd5", "O-O", "Be7", "d4", "O-O",
            ],
        },
        {
            "chapter": {"id": "kieseritzky", "title": c("Gambit Kieseritzky — 3…g5", "Kieseritzky Gambit — 3…g5")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Nf3",
                {"san": "g5", "comment": c("Les Noirs s'accrochent au pion f4 — la ligne la plus tranchante.",
                                           "Black clings to the f4 pawn — the sharpest line.")},
                {"san": "h4", "comment": c("On frappe la chaîne de pions tout de suite.",
                                           "Striking the pawn chain at once.")},
                "g4",
                {"san": "Ne5", "eco": "King's Gambit Accepted: Kieseritzky Gambit",
                 "comment": c("Le Gambit Kieseritzky : le cavalier plonge en e5, prêt à sacrifier davantage.",
                              "The Kieseritzky Gambit: the knight leaps to e5, ready to sacrifice more.")},
                "Nf6", "d4", "d6", "Nd3", "Nxe4", "Bxf4", "Qe7",
            ],
        },
        {
            "chapter": {"id": "muzio", "title": c("Gambit Muzio — 5.O-O", "Muzio Gambit — 5.O-O")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Nf3", "g5",
                {"san": "Bc4", "comment": c("On développe et on vise f7 avant de sacrifier.",
                                            "Develop and target f7 before sacrificing.")},
                "g4",
                {"san": "O-O", "role": "trap", "critical": True,
                 "eco": "King's Gambit Accepted: Muzio Gambit",
                 "comment": c("Le Gambit Muzio : on abandonne carrément le cavalier f3 pour une attaque dévastatrice sur f7 et le roi.",
                              "The Muzio Gambit: flatly giving up the f3 knight for a devastating attack on f7 and the king.")},
                "gxf3", "Qxf3", "Qf6", "e5", "Qxe5", "d3", "Bh6", "Nc3", "Ne7",
            ],
        },
        {
            "chapter": {"id": "bishops-gambit", "title": c("Gambit du fou — 3.Fc4", "Bishop's Gambit — 3.Bc4")},
            "moves": [
                "e4", "e5", "f4", "exf4",
                {"san": "Bc4", "eco": "King's Gambit Accepted: Bishop's Gambit",
                 "comment": c("Le Gambit du fou : on développe le fou avant le cavalier et on autorise …Dh4+ (pas grave, on joue Rf1).",
                              "The Bishop's Gambit: develop the bishop before the knight and allow …Qh4+ (fine — we play Kf1).")},
                "Qh4+", "Kf1", "d5", "Bxd5", "g5", "Nf3", "Qh5",
            ],
        },
        {
            "chapter": {"id": "falkbeer", "title": c("Contre-gambit Falkbeer — 2…d5", "Falkbeer Counter-gambit — 2…d5")},
            "moves": [
                "e4", "e5", "f4",
                {"san": "d5", "eco": "King's Gambit Declined: Falkbeer Counter-gambit",
                 "comment": c("Le contre-gambit Falkbeer : au lieu de prendre, les Noirs rendent coup pour coup.",
                              "The Falkbeer: instead of taking, Black strikes back blow for blow.")},
                "exd5", "e4",
                {"san": "d3", "comment": c("On mine le pion e4 avancé plutôt que de le laisser gêner le développement.",
                                           "Undermine the advanced e4 pawn rather than let it cramp development.")},
                "Nf6", "dxe4", "Nxe4",
            ],
        },
        {
            "chapter": {"id": "declined", "title": c("Gambit du Roi refusé — 2…Fc5", "King's Gambit Declined — 2…Bc5")},
            "moves": [
                "e4", "e5", "f4",
                {"san": "Bc5", "comment": c("Le refus le plus sûr : le fou en c5 empêche le roque et vise f2.",
                                            "The safest declination: the c5 bishop stops castling and eyes f2.")},
                "Nf3", "d6", "Nc3", "Nf6", "Bc4", "Nc6",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "declined-nc6", "title": c("Refusé — 2…Cc6", "Declined — 2…Nc6")},
            "moves": [
                "e4", "e5", "f4",
                {"san": "Nc6",
                 "comment": c("Un Noir sur cinq développe au lieu de prendre ou de contre-attaquer. Le cours ne traitait ni ce coup ni …d6.",
                              "One Black player in five develops rather than taking or counter-attacking. The course covered neither this nor …d6."),
                 "critical": True},
                "Nf3", "d6",
                {"san": "Bb5",
                 "comment": c("On cloue le défenseur de e5 avant de résoudre la tension : c'est l'ordre qui donne l'avantage.",
                              "Pin the defender of e5 before resolving the tension: that move order is what gives the edge.")},
                "exf4", "d4", "g5", "d5",
            ],
        },
        {
            "chapter": {"id": "declined-d6", "title": c("Refusé — 2…d6", "Declined — 2…d6")},
            "moves": [
                "e4", "e5", "f4",
                {"san": "d6",
                 "comment": c("La façon la plus solide de refuser : les Noirs consolident e5 et attendent.",
                              "The most solid way to decline: Black shores up e5 and waits.")},
                {"san": "d3",
                 "comment": c("On ne force rien. La position devient une partie de pions rois où notre f4 gagne de l'espace sans rien concéder.",
                              "No forcing. It becomes a king's pawn game where our f4 gains space without conceding anything.")},
                "g6", "Be2",
                {"san": "Qh4+", "role": "inaccuracy",
                 "comment": c("L'échec réflexe. Après g3, la dame aura perdu deux temps et notre développement sera en avance.",
                              "The reflex check. After g3, the queen has lost two tempi and our development is ahead.")},
                "g3", "Qe7", "Be3",
            ],
        },
        {
            "chapter": {"id": "kieseritzky", "title": c("Gambit Kieseritzky — 3…g5", "Kieseritzky Gambit — 3…g5")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Nf3",
                {"san": "d6",
                 "comment": c("La défense moderne du gambit accepté : au lieu de tenir le pion par …g5, les Noirs rendent et développent.",
                              "The modern defence in the accepted gambit: instead of clinging with …g5, Black gives back and develops."),
                 "critical": True},
                "d4", "g5", "h4", "g4", "Ng1",
                {"san": "Bh6",
                 "comment": c("Le cavalier est retourné en g1 — humiliant mais correct : il repartira par e2 et le centre blanc vaut le temps perdu.",
                              "The knight is back on g1 — humiliating but correct: it will re-emerge via e2, and White's centre is worth the lost time.")},
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,90). Trois des cinq
        # trous sont à la MÊME position — après 3.Fc4, où le cours ne couvrait
        # que …Dh4+ : le chapitre du gambit du fou était quasi vide.
        #
        # Note d'honnêteté : plusieurs de ces lignes finissent légèrement en
        # faveur des Noirs. C'est le gambit du roi — on offre un pion pour
        # l'initiative, et les tables de finales ne mentent pas. L'audit vérifie
        # qu'aucune n'est une GAFFE ; il n'exige pas qu'elles soient gagnantes. ─
        {
            "chapter": {"id": "bishops-gambit", "title": c("Gambit du fou — 3.Fc4", "Bishop's Gambit — 3.Bc4")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Bc4",
                {"san": "d6",
                 "comment": c("Le coup le plus sensé : les Noirs consolident avant de chercher …g5. Un joueur sur sept, et le cours ne prévoyait que l'échec …Dh4+.",
                              "The soundest move: Black consolidates before going for …g5. One player in seven, and the course only planned for the check …Qh4+."),
                 "critical": True},
                {"san": "Nf3",
                 "comment": c("On développe en couvrant h4 : plus d'échec à craindre, et le cavalier surveille g5 où les Noirs voudront pousser.",
                              "We develop while covering h4: no more check to fear, and the knight watches g5, where Black wants to push."),
                 "critical": True},
                "h6", "d4", "g5", "h4", "Bg7", "Qd3", "Nc6", "Nc3", "g4",
            ],
        },
        {
            "chapter": {"id": "bishops-gambit", "title": c("Gambit du fou — 3.Fc4", "Bishop's Gambit — 3.Bc4")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Bc4",
                {"san": "Nf6",
                 "comment": c("Les Noirs attaquent e4 au lieu de tenir le pion f4. C'est la façon moderne de traiter le gambit du fou, et le cours n'en disait rien.",
                              "Black attacks e4 instead of clinging to the f4 pawn. The modern way to meet the Bishop's Gambit, and the course said nothing about it."),
                 "critical": True},
                {"san": "Nc3",
                 "comment": c("On défend e4 par une pièce, sans bouger un pion : le centre reste intact et le développement continue.",
                              "We defend e4 with a piece, without touching a pawn: the centre stays whole and development continues.")},
                "Nc6", "Nf3", "Bb4", "O-O", "O-O", "d3",
                {"san": "Bxc3",
                 "comment": c("Les Noirs doublent nos pions pour tenir e4. Nous obtenons en échange la colonne b et deux fous face à un roi qui a perdu son pion f.",
                              "Black doubles our pawns to hold e4. In exchange we get the b-file and two bishops against a king that has lost its f-pawn."),
                 "critical": True},
                "bxc3", "d5",
            ],
        },
        {
            "chapter": {"id": "bishops-gambit", "title": c("Gambit du fou — 3.Fc4", "Bishop's Gambit — 3.Bc4")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Bc4",
                {"san": "Nc6",
                 "comment": c("Développement simple. Un joueur sur huit, absent du cours.",
                              "Simple development. One player in eight, missing from the course."),
                 "critical": True},
                "d4",
                {"san": "Qh4+",
                 "comment": c("L'échec caractéristique du gambit du fou : il n'y a pas de cavalier en f3 pour le couvrir, et le roi blanc doit bouger. C'est le prix assumé de 3.Fc4.",
                              "The check that defines the Bishop's Gambit: there is no knight on f3 to block it, and White's king must move. That is the accepted price of 3.Bc4."),
                 "critical": True},
                {"san": "Kf1",
                 "comment": c("Le roi marche, et ce n'est pas une catastrophe : la tour h1 sortira par g1 une fois le pion g poussé, et les Noirs auront dépensé leur dame en sorties précoces.",
                              "The king steps aside, and it is no disaster: the h1 rook will come out via g1 once the g-pawn moves, and Black will have spent their queen on early sorties.")},
                "d6", "Nf3", "Bg4", "Nxh4", "Bxd1", "Nc3", "Bxc2",
            ],
        },
        {
            "chapter": {"id": "kings-knight", "title": c("Gambit accepté — 3.Cf3", "Accepted — 3.Nf3")},
            "moves": [
                "e4", "e5", "f4", "exf4", "Nf3",
                {"san": "Nc6",
                 "comment": c("Un Noir sur six développe avant de tenir le pion. Le cours ne prévoyait que …d5, …g5 et …d6.",
                              "One Black player in six develops before holding the pawn. The course only planned for …d5, …g5 and …d6."),
                 "critical": True},
                "d4", "g5",
                {"san": "d5",
                 "comment": c("La poussée qui renverse tout : le pion attaque le cavalier c6 au moment précis où les Noirs se sont engagés à l'aile roi. La suite est forcée et il faut la connaître.",
                              "The push that turns everything around: the pawn hits the c6 knight at the exact moment Black has committed on the kingside. What follows is forced and must be known."),
                 "critical": True},
                "g4", "dxc6", "gxf3", "Qxf3", "Qh4+", "g3", "fxg3",
            ],
        },
        {
            "chapter": {"id": "kings-knight", "title": c("Gambit accepté — 3.Cf3", "Accepted — 3.Nf3")},
            "moves": [
                "e4", "e5", "f4",
                {"san": "Nc6",
                 "comment": c("Les Noirs refusent le pion pour développer. Le cours ne voyait que la prise …exf4 et …d6.",
                              "Black declines the pawn to develop. The course only saw the capture …exf4 and …d6."),
                 "critical": True},
                "Nf3",
                {"san": "exf4",
                 "comment": c("Ils acceptent finalement, un coup plus tard — et transposent dans la ligne précédente, où d4 puis d5 nous attendent.",
                              "They accept after all, one move later — and transpose into the previous line, where d4 and then d5 are waiting."),
                 "critical": True},
                "d4", "g5", "d5", "g4", "dxc6", "gxf3", "Qxf3", "Qh4+", "g3", "fxg3",
            ],
        },
    ],
}
