# -*- coding: utf-8 -*-
"""Cavalier ou fou : lequel prendre ? — sourcé ChessBase.

Sourcé ChessBase (« The Wrong Bishop »), position-test : le roi blanc
touche à la fois le cavalier et le fou noirs. L'un ou l'autre semble
également capturable — un seul choix tient la nulle. Racine à 5 pièces,
chaque capture tranchée par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-right-capture",
    "name": "Which Piece to Capture?",
    "side": "white",
    "kind": "endgame",
    "family": "imbalances",
    "level": "advanced",
    "rootFEN": "k7/7p/8/2nKb3/8/8/8/8 w - - 0 1",
    "summary": c(
        "Le roi blanc touche le cavalier ET le fou noirs — il ne peut en prendre qu'un, gratuitement. Prendre le cavalier tient la nulle ; prendre le fou, pourtant de la bonne couleur pour la case de promotion, perd. La vitesse du roi compte plus que la couleur de la pièce laissée en jeu.",
        "White's king touches both Black's knight AND bishop — it can only capture one, for free. Taking the knight holds the draw; taking the bishop, despite being the right colour for the queening square, loses. The king's speed matters more than the colour of the piece left on the board.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-right-capture", "title": c("Prendre le cavalier, puis courser la dame", "Take the knight, then race the queen down")},
            "moves": [
                {"san": "Kxc5",
                 "comment": c("Le bon choix. Le fou reste sur l'échiquier — de la bonne couleur pour h8, ce qui semblerait pourtant favoriser les noirs — mais le roi blanc part directement escorter sa propre course vers le coin.",
                              "The right choice. The bishop stays on the board — the right colour for h8, which would seem to favour Black — but White's king heads straight for its own race to the corner."),
                 "critical": True},
                "h5",
                {"san": "Kd5", "comment": c("Le roi blanc colle sa route à celle du pion, sur la même diagonale.", "White's king glues its path to the pawn's, on the same diagonal.")},
                "h4",
                "Ke4",
                "h3",
                "Kf3",
                "h2",
                {"san": "Kg2",
                 "comment": c("Le roi arrive pile à temps sur la case qui compte : juste à côté de la promotion.", "The king arrives exactly on time on the square that matters: right next to the queening square."),
                 "critical": True},
                "h1=Q+",
                {"san": "Kxh1",
                 "comment": c("Le roi croque la dame à la seconde même où elle apparaît. Nulle vérifiée : la vitesse du roi blanc, pas la couleur du fou noir, décidait de tout.",
                              "The king gobbles the queen the very instant it appears. Verified draw: White's king's speed, not Black's bishop's colour, decided everything."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "the-wrong-capture", "title": c("Prendre le fou : trop lent d'un coup", "Take the bishop: one tempo too slow")},
            "moves": [
                {"san": "Kxe5", "role": "trap",
                 "comment": c("Semble tout aussi naturel — capturer la pièce la plus proche du pion. Mais cela laisse le cavalier, qui n'a pas besoin d'accompagner le pion pas à pas : il saute directement vers la case clé.",
                              "Seems just as natural — capture the piece closest to the pawn. But this leaves the knight, which doesn't need to escort the pawn step by step: it hops straight to the key square."),
                 "critical": True},
                "h5",
                "Kf4",
                {"san": "Ne6+",
                 "comment": c("Le cavalier gagne un temps précieux par l'échec — exactement le temps qui manquait au roi blanc dans l'autre ligne.",
                              "The knight wins a precious tempo with check — exactly the tempo White's king was missing in the other line."),
                 "critical": True},
                "Kg3",
                {"san": "Ng7",
                 "comment": c("Le cavalier couvre la case de promotion depuis loin — le roi blanc, désormais hors course, ne peut plus rien changer au résultat.",
                              "The knight covers the queening square from a distance — White's king, now out of the race, can no longer change the result."),
                 "critical": True},
            ],
        },
    ],
}
