# -*- coding: utf-8 -*-
"""Le mauvais fou qui gagne quand même — la course au coin.

Position construite et vérifiée depuis zéro, pendant offensif du cours
« Le mauvais fou » (la forteresse) : la forteresse n'existe que si le roi
défenseur ATTEINT le coin. Ici il en est à trois pas — et l'oracle rend le
verdict le plus pédagogique possible : des six coups de fou légaux, SEUL
Ff4 gagne (l'unique route en un temps vers la diagonale-barrière b8-h2), et
la poussée naturelle a5?? jette le gain en laissant le roi noir se glisser
dans a8. Gagner avec le mauvais fou, c'est gagner la course au coin.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-wrong-bishop-win",
    "name": "The Wrong Bishop That Wins",
    "side": "white",
    "kind": "endgame",
    "family": "bishops",
    "level": "club",
    "rootFEN": "8/3k4/8/1K6/P7/8/8/2B5 w - - 0 1",
    "summary": c(
        "Fou de cases noires, pion a : le « mauvais fou » — et pourtant les Blancs gagnent. Car la fameuse forteresse a une condition d'entrée : le roi défenseur doit ATTEINDRE le coin a8. Il en est à trois pas ; la victoire se joue donc en une course, et elle se gagne avec un mur de deux cases : le fou barre b8, le roi barre b7. Un seul coup de fou construit ce mur à temps.",
        "Dark-squared bishop, a-pawn: the \"wrong bishop\" — and yet White wins. Because the famous fortress has an entry requirement: the defending king must REACH the a8 corner. It stands three steps away; the game is therefore a race, and it is won with a two-square wall: the bishop bars b8, the king bars b7. Exactly one bishop move builds that wall in time.",
    ),
    "lines": [
        {
            "chapter": {"id": "wall", "title": c("Ff4 ! — le mur avant la poussée", "Bf4! — the wall before the push")},
            "moves": [
                {"san": "Bf4",
                 "comment": c("Le coup de la finale. Des six coups de fou légaux, SEUL celui-ci gagne (vérifié : les cinq autres font nulle) — f4 est l'unique case qui rejoint en UN temps la diagonale b8-h2, celle qui verrouille la porte b8. Le pion attendra : la barrière d'abord.",
                              "The move of the ending. Of the six legal bishop moves, ONLY this one wins (verified: the other five draw) — f4 is the one square that reaches the b8-h2 diagonal in a SINGLE tempo, the diagonal that locks the b8 door. The pawn can wait: barrier first."),
                 "critical": True},
                {"san": "Kc8",
                 "comment": c("Le roi noir se rue vers le coin sauveur — un pas de plus et la forteresse classique (voir « Le mauvais fou ») était imprenable.",
                              "The black king dashes for the saving corner — one more step and the classic fortress (see \"The Wrong Bishop\") would be unbreakable.")},
                {"san": "Kb6",
                 "comment": c("Deuxième et dernière pierre du mur : le roi couvre b7 (et c7), le fou couvre b8. Le roi noir est enfermé DEHORS — b8 et b7, ses deux seules portes vers a8, sont condamnées à jamais.",
                              "The second and final stone of the wall: the king covers b7 (and c7), the bishop covers b8. The black king is locked OUT — b8 and b7, its only two doors to a8, are boarded up for good."),
                 "critical": True},
                "Kd7",
                {"san": "a5",
                 "comment": c("MAINTENANT le pion peut marcher — la nuance de tout le cours : la même poussée, jouée avant le mur, ne faisait que nulle. L'ordre des coups est toute la différence entre gagner et regarder le roi noir s'installer en a8.",
                              "NOW the pawn may march — the point of the whole course: the very same push, played before the wall, only drew. Move order is the entire difference between winning and watching the black king settle into a8."),
                 "critical": True},
                "Kd8", "a6", "Kc8",
                {"san": "a7",
                 "comment": c("Le roi noir a beau camper en c8, à une case du coin : il ne touche PAS a8. La couleur du fou n'a jamais eu d'importance — le pion promeut sur une case que personne ne conteste.",
                              "The black king may camp on c8, one square from the corner: it does NOT touch a8. The bishop's colour never mattered — the pawn promotes on a square nobody contests."),
                 "critical": True},
                "Kd7",
                {"san": "a8=Q",
                 "comment": c("Une dame, tout simplement. Retenez la règle dans les deux sens : mauvais fou + pion-tour = nulle SI le roi défenseur atteint le coin — et course au coin sinon. Le mur Ff4+Rb6 est la façon de gagner cette course.",
                              "A queen, plain and simple. Remember the rule in both directions: wrong bishop + rook's pawn = draw IF the defending king reaches the corner — and a race to the corner otherwise. The Bf4+Kb6 wall is how that race is won."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "hasty-push", "title": c("La poussée pressée — et la forteresse se referme", "The hasty push — and the fortress snaps shut")},
            "moves": [
                {"san": "a5", "role": "trap",
                 "comment": c("Pousser le pion passé : le geste le plus naturel du monde — et ici la faute décisive (vérifié : de gagné, la position devient nulle). Chaque tempo de pion est un tempo que le roi noir passe à courir vers a8.",
                              "Pushing the passed pawn: the most natural move in the world — and here the decisive mistake (verified: the position drops from won to drawn). Every pawn tempo is a tempo the black king spends running for a8."),
                 "critical": True},
                {"san": "Kc8",
                 "comment": c("Le roi noir file vers le coin — et plus rien ne peut l'arrêter : le fou n'a pas eu le temps de fermer b8.",
                              "The black king races for the corner — and nothing can stop it now: the bishop never had time to seal b8.")},
                "a6",
                {"san": "Kb8",
                 "comment": c("La porte b8 franchie, tout est dit. Notez que ce roi n'a fait que deux pas — la forteresse n'était vraiment qu'à une course de distance.",
                              "Through the b8 door, and the story is over. Note that this king only took two steps — the fortress really was just one race away."),
                 "critical": True},
                "a7+",
                {"san": "Ka8",
                 "comment": c("La position exacte du cours « Le mauvais fou » : roi collé au coin blanc, fou noir impuissant, pat en embuscade dès que le roi blanc s'approche. Nulle de fer. Un seul ordre de coups séparait ce demi-point de la dame du chapitre principal.",
                              "The exact position of \"The Wrong Bishop\" course: king glued to the light corner, dark-squared bishop helpless, stalemate lying in ambush the moment White's king steps closer. An iron draw. A single move order separated this half point from the main chapter's queen."),
                 "critical": True},
            ],
        },
    ],
}
