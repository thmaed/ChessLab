# -*- coding: utf-8 -*-
"""Le mat fou + cavalier — le quatrième et dernier mat élémentaire.

Position de départ construite (le dispositif d'école classique : roi noir
déjà réfugié dans le MAUVAIS coin a8, pièces blanches à distance de travail),
puis ligne ENTIÈREMENT DTM-optimale dérivée de la tablebase — dtm 39, comme
`bishop_pair_mate.py` en son temps. La défense optimale de la tablebase joue
exactement la tentative classique des manuels : courir vers l'AUTRE mauvais
coin (h1) — et la ligne montre la barrière de fou et l'épaulement qui
l'interceptent en route, jusqu'au mat dans le coin de la couleur du fou.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-bishop-knight-mate",
    "name": "The Bishop and Knight Mate",
    "side": "white",
    "kind": "endgame",
    "family": "mates",
    "level": "advanced",
    "rootFEN": "k7/8/1K6/3N4/5B2/8/8/8 w - - 0 1",
    "summary": c(
        "Le plus difficile des quatre mats élémentaires — et le seul où le COIN a de l'importance : un fou de cases noires ne peut mater que dans un coin noir (a1 ou h8). Le roi noir s'est réfugié en a8, coin blanc où aucun mat n'existe : il faut l'en déloger, puis intercepter sa course vers l'autre coin blanc, h1. Ligne entièrement optimale selon la tablebase, du délogement au mat.",
        "The hardest of the four elementary mates — and the only one where the CORNER matters: a dark-squared bishop can only deliver mate in a dark corner (a1 or h8). The black king has taken refuge on a8, a light corner where no mate exists: he must be evicted, then intercepted on his dash towards the other light corner, h1. The whole line is tablebase-optimal, from eviction to mate.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Déloger, barrer la route, mater dans le bon coin", "Evict, bar the road, mate in the right corner")},
            "moves": [
                {"san": "Nc7+",
                 "comment": c("Le délogement : a8 est un coin de la MAUVAISE couleur pour le fou — aucun mat n'y existe, il faut donc en chasser le roi. Le cavalier s'en charge, c'est le seul des trois qui puisse attaquer les cases blanches.",
                              "The eviction: a8 is a corner of the WRONG colour for the bishop — no mate exists there, so the king must be driven out. The knight does the job: of White's pieces it is the only one that can attack light squares."),
                 "critical": True},
                "Kb8",
                {"san": "Be5",
                 "comment": c("Le fou prend la grande diagonale et cloue le roi noir sur la rangée du fond : b8 et les cases noires voisines lui sont interdites. La cage est posée — elle va maintenant glisser vers h8.",
                              "The bishop takes the long diagonal and pins the black king to the back rank: b8 and the neighbouring dark squares are off-limits. The cage is set — now it will slide towards h8."),
                 "critical": True},
                "Kc8", "Nd5", "Kd7", "Nf4", "Kc8",
                {"san": "Kc6",
                 "comment": c("Comme dans tous les mats élémentaires, les pièces seules ne suffisent pas : le roi blanc avance en épaulant son homologue, une rangée à la fois.",
                              "As in every elementary mate, the pieces alone are not enough: White's king advances shoulder to shoulder with its counterpart, one rank at a time."),
                 "critical": True},
                "Kd8", "Nd5", "Kc8", "Nb6+", "Kd8",
                {"san": "Bf6+",
                 "comment": c("L'échec qui pousse le roi noir hors de l'aile dame — vers l'est. À partir d'ici, les Noirs jouent LA défense classique : courir vers h1, l'autre coin de la mauvaise couleur, à l'opposé de l'échiquier.",
                              "The check that shoves the black king out of the queenside — eastwards. From here on, Black plays THE classical defence: a dash for h1, the other wrong-coloured corner, at the far end of the board."),
                 "critical": True},
                "Ke8", "Kd6", "Kf7", "Nd5", "Kg6",
                {"san": "Ke6",
                 "comment": c("L'interception commence : le roi blanc coupe la route du sud pendant que le fou, resté en f6, tient toute la diagonale du coin h8. Le roi noir voulait h1 — il n'atteindra jamais la moitié inférieure de l'échiquier.",
                              "The interception begins: White's king cuts off the southern route while the bishop, still on f6, holds the whole diagonal into the h8 corner. Black's king wanted h1 — he will never even reach the lower half of the board."),
                 "critical": True},
                "Kh5",
                {"san": "Kf5",
                 "comment": c("L'épaulement : les deux rois face à face, le blanc vole au noir les cases g4 et g6. Il ne reste au roi noir que la colonne h — un couloir qui remonte tout droit… vers h8, le coin de la couleur du fou.",
                              "The shoulder-block: the two kings face off, and White steals g4 and g6 from Black. Only the h-file is left — a corridor leading straight back up… to h8, the corner of the bishop's colour."),
                 "critical": True},
                "Kh6",
                {"san": "Nc7",
                 "comment": c("Le cavalier entame son dernier trajet, vers e6 : de là il couvrira g7 et f8, les deux dernières échappatoires. Remarquez la lenteur assumée — un cavalier met du temps à se replacer, et tout l'art de ce mat est de le replacer au bon moment.",
                              "The knight sets off on its final journey, to e6: from there it will cover g7 and f8, the last two bolt-holes. Note the unhurried pace — a knight takes time to redeploy, and the whole art of this mate lies in redeploying it at the right moment."),
                 "critical": True},
                "Kh5", "Ne6", "Kh6",
                {"san": "Bg5+",
                 "comment": c("Le fou quitte la grande diagonale un instant pour pousser le roi noir sur la 7e rangée — droit dans le filet que roi et cavalier viennent de tendre.",
                              "The bishop leaves the long diagonal for a moment to push the black king onto the 7th rank — straight into the net king and knight have just laid."),
                 "critical": True},
                "Kh7", "Kf6", "Kg8", "Kg6", "Kh8", "Kf7", "Kh7",
                {"san": "Nf8+",
                 "comment": c("L'avant-dernier tableau : le cavalier chasse le roi noir vers h8 pendant que le roi blanc garde g6, g7 et g8. Il ne reste qu'une case — la noire, celle du coin du fou.",
                              "The penultimate picture: the knight drives the black king to h8 while White's king guards g6, g7 and g8. One square remains — the dark one, the bishop's corner."),
                 "critical": True},
                "Kh8",
                {"san": "Bf6#",
                 "comment": c("Mat — et notez QUI le donne : le fou, dans le coin de sa propre couleur, exactement comme la théorie l'annonce. Roi et cavalier bouchent tout le reste. Retenez les trois phases : déloger du mauvais coin, barrer la course vers l'autre mauvais coin, refermer sur le bon.",
                              "Mate — and note WHO delivers it: the bishop, in the corner of its own colour, exactly as theory promises. King and knight seal everything else. Remember the three phases: evict from the wrong corner, bar the dash to the other wrong corner, close in on the right one."),
                 "critical": True},
            ],
        },
    ],
}
