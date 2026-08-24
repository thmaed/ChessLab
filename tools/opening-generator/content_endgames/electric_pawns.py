# -*- coding: utf-8 -*-
"""Pions électriques — deux passés séparés d'une colonne, et le roi qui grille.

Un « pion électrique » est un pion passé séparé d'un autre par UNE SEULE
colonne. Le roi adverse ne peut en toucher aucun : dès qu'il s'approche de
l'un, il sort du carré de l'autre, qui file à dame. Ils se gardent mutuellement
sans qu'aucune pièce ne les soutienne — d'où le nom.

L'écart d'une colonne est le point exact : collés, un seul roi les arrête ;
plus éloignés, le roi n'a plus à choisir, il en perd un franchement. À une
colonne d'intervalle, la menace est RÉCIPROQUE.

Position et définition fournies par l'utilisateur (24/08/2026), vérifiées à la
tablebase : gain blanc, mat en 39. Chaque coup de chaque ligne est tranché par
l'oracle.

Étendu le 24/08 : la tablebase montre que le thème est plus fin que « pousser
le pion lointain ». Depuis c5, seul `a4` gagne — tout coup de roi annule. Mais
depuis b5, c'est l'INVERSE : les deux poussées annulent (le roi touche a4 comme
c4) et il faut ATTENDRE. La règle unique qui couvre les deux cas : ne jamais
pousser un pion sur une case que le roi adverse contrôle déjà, et laisser le
roi noir désigner lui-même, en s'approchant, lequel des deux ira à dame.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-electric-pawns",
    "name": "Electric Pawns",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/8/8/2k5/8/P1P5/8/7K b - - 0 1",
    "summary": c(
        "Deux pions passés séparés par UNE colonne, un roi blanc à l'autre bout de l'échiquier, et pourtant les Noirs sont perdus. Le roi noir ne peut toucher ni l'un ni l'autre : s'approcher du premier, c'est sortir du carré du second. Ils se gardent l'un l'autre — d'où leur nom.",
        "Two passed pawns one file apart, a white king at the far end of the board, and yet Black is lost. Black's king can touch neither: approaching one means stepping out of the other's square. They guard each other — hence the name.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-shock", "title": c("Toucher l'un, c'est laisser filer l'autre", "Touch one, and the other runs")},
            "moves": [
                {"san": "Kc4",
                 "comment": c("Le roi noir s'attaque au pion c3 — la seule façon d'en prendre un, puisque b4 est contrôlé par les deux pions à la fois.",
                              "Black's king goes after the c3 pawn — the only way to take one, since b4 is covered by both pawns at once."),
                 "critical": True},
                {"san": "a4",
                 "comment": c("LE coup. Les Blancs n'essaient pas de sauver c3 : ils lancent l'autre. Le roi noir est maintenant devant un choix qui n'en est pas un — prendre en c3, ou courir après le pion a. Il ne peut pas les deux.",
                              "THE move. White does not try to save c3: he launches the other one. Black's king now faces a choice that isn't one — take on c3, or chase the a-pawn. He cannot do both."),
                 "critical": True},
                {"san": "Kxc3",
                 "comment": c("Le roi noir encaisse. Comptez le carré du pion a4 depuis c3 : il est déjà dehors, et chaque pas vers a8 arrive un temps trop tard.",
                              "Black's king collects. Count the a4 pawn's square from c3: he is already outside it, and every step toward a8 arrives one tempo late."),
                 "critical": True},
                "a5", "Kb4", "a6", "Kb5", "a7", "Kb6",
                {"san": "a8=Q",
                 "comment": c("À dame, avec un roi noir à deux cases. Le pion c3 n'était pas un cadeau : c'était l'appât. Retenez l'écart d'UNE colonne — collés, le roi noir les arrêtait tous les deux ; plus écartés, il n'aurait même pas eu à choisir.",
                              "Queening, with Black's king two squares away. The c3 pawn was no gift: it was the bait. Remember the ONE-file gap — side by side, Black's king would stop both; further apart, he would not even have had to choose."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "mirror", "title": c("L'autre côté du miroir", "The other side of the mirror")},
            "moves": [
                {"san": "Kb5",
                 "comment": c("Le roi noir se place ENTRE les deux pions, à égale distance. C'est sa meilleure tentative : d'ici il touche a4 et c4, les deux cases où les pions voudraient aller.",
                              "Black's king plants itself BETWEEN the two pawns, equidistant. This is his best try: from here he covers a4 and c4, the very squares the pawns want to reach."),
                 "critical": True},
                {"san": "Kg2",
                 "comment": c("On ATTEND. Aucun des deux pions ne peut avancer — le roi noir les prendrait. Mais lui doit bouger, et chaque case le rapproche d'un pion, donc l'éloigne de l'autre. Le roi blanc, à l'autre bout, ne fait que passer le tour.",
                              "WAIT. Neither pawn can advance — Black's king would take it. But he has to move, and every square brings him closer to one pawn, hence further from the other. White's king, far away, is merely passing the turn."),
                 "critical": True},
                {"san": "Ka4",
                 "comment": c("Le roi choisit le pion a. Il l'attaque, et il croit gagner un temps.",
                              "The king picks the a-pawn. He attacks it, and thinks he is gaining a tempo."),
                 "critical": True},
                {"san": "c4",
                 "comment": c("Exactement le geste du chapitre 1, dans l'autre sens : le pion attaqué est abandonné, l'AUTRE part. Rien à retenir de plus — le thème ne connaît pas la couleur de la colonne.",
                              "Exactly the move from chapter 1, mirrored: the attacked pawn is abandoned, the OTHER one runs. Nothing more to remember — the theme does not care which file it happens on."),
                 "critical": True},
                "Kxa3", "c5", "Kb4", "c6", "Kb5", "c7", "Kb6",
                {"san": "c8=Q",
                 "comment": c("Même dame, même écart de deux cases. Les deux pions sont interchangeables : c'est le roi noir qui désigne, en s'approchant, lequel des deux ira à dame.",
                              "Same queen, same two-square gap. The two pawns are interchangeable: it is Black's king who decides, by approaching, which of them will queen."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "push-on-check", "title": c("Pousser avec échec, c'est offrir le pion", "Pushing with check is giving the pawn away")},
            "moves": [
                {"san": "Kb5", "comment": c("Le roi noir se met entre les deux pions.", "Black's king steps between the two pawns.")},
                {"san": "a4+", "role": "trap",
                 "comment": c("Avec échec, donc irrésistible — et perdant. Depuis b5, le roi noir TOUCHE la case a4 : le pion n'y arrive pas, il s'y livre. La règle qui gouverne toute cette finale tient en une ligne : ne poussez jamais un pion sur une case que le roi adverse contrôle déjà.",
                              "With check, hence irresistible — and losing. From b5, Black's king TOUCHES a4: the pawn does not arrive there, it surrenders there. The rule that governs this whole ending fits in one line: never push a pawn onto a square the enemy king already covers."),
                 "critical": True},
                {"san": "Kxa4",
                 "comment": c("Le pion tombe. Il en reste un, seul, avec un roi blanc à l'autre bout de l'échiquier : c'est nulle, et c'était gagné.",
                              "The pawn falls. One is left, alone, with White's king at the far end of the board: that is a draw, and it was a win."),
                 "critical": True},
                {"san": "c4",
                 "comment": c("Trop tard pour le second. Le roi noir est dans son carré et le rattrape sans effort — un pion seul ne fait pas dame contre un roi qui le voit.",
                              "Too late for the second one. Black's king is inside its square and catches it without effort — a lone pawn does not queen against a king who can see it."),
                 "critical": True},
                "Kb4",
            ],
        },
        {
            "chapter": {"id": "clinging-to-c3", "title": c("Vouloir sauver les deux", "Trying to save both")},
            "moves": [
                {"san": "Kc4", "comment": c("Le roi noir vient chercher c3.", "Black's king comes for c3.")},
                {"san": "Kg2", "role": "trap",
                 "comment": c("Le réflexe humain : on ne lâche pas un pion sans rien faire, alors le roi se met en route pour le défendre. Sauf qu'il est à sept cases, et que le pion a, lui, ne partira jamais tout seul.",
                              "The human reflex: you don't drop a pawn for nothing, so the king sets off to defend it. Except that he is seven squares away — and the a-pawn will never set off by itself."),
                 "critical": True},
                {"san": "Kxc3",
                 "comment": c("Le pion tombe quand même, et le tempo perdu ne se rattrape pas.",
                              "The pawn falls anyway, and the lost tempo never comes back."),
                 "critical": True},
                {"san": "a4",
                 "comment": c("Le même coup qu'au chapitre 1, un temps trop tard. Comptez le carré : depuis c3, le roi noir est DEDANS, alors qu'il en était dehors quand a4 partait immédiatement. Un seul temps sépare le gain de la nulle.",
                              "The same move as in chapter 1, one tempo too late. Count the square: from c3, Black's king is INSIDE it — whereas he was outside when a4 went at once. A single tempo separates the win from the draw."),
                 "critical": True},
                "Kb4", "a5", "Kb5",
            ],
        },
    ],
}
