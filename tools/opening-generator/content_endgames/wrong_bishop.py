# -*- coding: utf-8 -*-
"""Le fou de la mauvaise couleur — la forteresse la plus fiable du jeu.

Deux positions JUMELLES, un seul détail différent (la couleur des cases du
fou), vérifiées séparément à la tablebase : l'une nulle à coup sûr, l'autre
gagnée en cinq coups. Rien n'illustre mieux la règle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-wrong-bishop",
    "name": "The Wrong Bishop",
    "side": "black",
    "kind": "endgame",
    "family": "bishops",
    "level": "club",
    "rootFEN": "k7/8/8/P7/8/3K4/3B4/8 w - - 0 1",
    "summary": c(
        "Fou et pion-tour contre roi seul : d'ordinaire un gain trivial. Mais si le fou ne contrôle PAS la case de promotion, la partie entière peut se réduire à un coin et deux cases — et rien, absolument rien, n'y changera quoi que ce soit.",
        "Bishop and rook's pawn against a lone king: normally a trivial win. But if the bishop does NOT control the promotion square, the whole game can shrink to one corner and two squares — and nothing, absolutely nothing, will ever change that.",
    ),
    "lines": [
        {
            "chapter": {"id": "fortress", "title": c("La forteresse à deux cases", "The two-square fortress")},
            "moves": [
                {"san": "Kc4",
                 "comment": c("Le fou de d2 ne contrôle QUE les cases noires — jamais a8, où le pion doit promouvoir. Un fou d'UNE case plus loin (e2, cases blanches) gagnerait en cinq coups ; ici, regardez le roi noir : il n'a besoin que de deux cases, a8 et b8, pour tenir ÉTERNELLEMENT.",
                              "The bishop on d2 controls ONLY dark squares — never a8, where the pawn must queen. A bishop one square over (e2, light squares) would win in five moves; here, watch the black king: he needs only two squares, a8 and b8, to hold FOREVER."),
                 "critical": True},
                "Kb8",
                {"san": "Kb5", "comment": c("Le roi blanc s'approche — il peut venir, il ne peut rien faire une fois là.",
                                            "The white king approaches — he may come, he can do nothing once there.")},
                "Ka7",
                {"san": "Bf4",
                 "comment": c("Le fou tente une autre diagonale : toutes se ressemblent depuis qu'aucune ne touche a8. Le roi noir n'a même pas besoin de réfléchir — il navette entre ses deux seules cases jusqu'à la fin des temps.",
                              "The bishop tries another diagonal: they all look the same once none of them touches a8. The black king doesn't even need to think — he shuttles between his only two squares until the end of time."),
                 "critical": True},
            ],
        },
    ],
}
