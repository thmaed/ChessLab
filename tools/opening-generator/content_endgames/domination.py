# -*- coding: utf-8 -*-
"""La domination — une seule case qui gouverne toutes les fuites.

Position construite et vérifiée depuis zéro (aucune étude recopiée) :
recherche faite pour une étude sourcée de Troitzky, Kubbel ou Kasparyan sur
le thème « cavalier dominé », sans FEN exacte retrouvée avec assez de
certitude pour la citer honnêtement. La construction ci-dessous illustre
le MÊME thème que ces études classiques : une pièce qui, d'une seule case,
attaque une pièce ennemie ET couvre en même temps TOUTES ses cases de fuite
— la proie est perdue avant même d'être prise. Racine à 4 pièces, chaque
coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-theme-domination",
    "name": "Domination — the Knight With No Square",
    "side": "white",
    "kind": "endgame",
    "family": "themes",
    "level": "club",
    "rootFEN": "n5k1/8/8/1K6/7Q/8/8/8 w - - 0 1",
    "summary": c(
        "C'est LA domination : une seule case de dame qui attaque le cavalier ET couvre en même temps ses deux seules cases de fuite. Le cavalier est perdu avant même que la dame ne le prenne — voilà toute la différence avec une simple attaque.",
        "This is DOMINATION: one single queen square that attacks the knight AND simultaneously covers its only two flight squares. The knight is lost before the queen even takes it — that is the entire difference from a plain attack.",
    ),
    "lines": [
        {
            "chapter": {"id": "true-domination", "title": c("Une seule case gouverne tout le sort du cavalier", "One square governs the knight's entire fate")},
            "moves": [
                {"san": "Qd8+",
                 "comment": c("LA case de la domination : la dame donne échec le long de la 8e rangée, ET couvre b6 et c7 sur la diagonale a5-d8 — les deux SEULES cases où le cavalier a8 pourrait fuir. Une case, trois fonctions à la fois : voilà ce que veut dire « dominer ».",
                              "THE domination square: the queen checks along the 8th rank, AND covers b6 and c7 on the a5-d8 diagonal — the ONLY two squares the a8-knight could ever flee to. One square, three jobs at once: that is what \"domination\" means."),
                 "critical": True},
                {"san": "Kg7",
                 "comment": c("Le roi noir s'écarte — il n'a pas d'autre choix, et cela ne change strictement rien : le cavalier reste condamné, où qu'aille le roi.",
                              "Black's king steps aside — it has no other choice, and it changes nothing at all: the knight remains doomed no matter where the king goes.")},
                {"san": "Qxa8",
                 "comment": c("Le cavalier n'avait tout simplement nulle part où aller — ni b6 ni c7 n'étaient libres depuis le premier coup. Voilà ce qui distingue la domination d'une simple attaque : la pièce était déjà perdue AVANT que la dame ne vienne la ramasser.",
                              "The knight simply had nowhere to go — neither b6 nor c7 had been free since move one. This is what separates domination from a plain attack: the piece was already lost BEFORE the queen came to collect it."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "attack-without-domination", "title": c("Attaquer sans dominer : le cavalier s'échappe", "Attacking without dominating: the knight escapes")},
            "moves": [
                {"san": "Qa4", "role": "inaccuracy",
                 "comment": c("La dame attaque bel et bien le cavalier, tout le long de la colonne a — mais elle NE COUVRE NI b6 NI c7. Le gain reste acquis (la dame l'emporte toujours contre le cavalier seul), mais ce n'est déjà plus de la domination : juste une attaque, qu'on peut fuir.",
                              "The queen does attack the knight, straight down the a-file — but it covers NEITHER b6 NOR c7. The win is still there (the queen always beats a lone knight eventually), but this is no longer domination: just an attack, and attacks can be dodged."),
                 "critical": True},
                {"san": "Nc7+",
                 "comment": c("Le cavalier s'échappe — et trouve même le temps de donner un échec au passage. Comparez avec Qd8+ : la différence entre les deux chapitres tient tout entière à une seule case de dame.",
                              "The knight escapes — and even finds time to give a check on its way out. Compare with Qd8+: the entire difference between the two chapters comes down to a single queen square.")},
                {"san": "Kc5",
                 "comment": c("Le roi blanc se met à l'abri ; la partie reste gagnée, mais il faudra maintenant recommencer la chasse — le travail que Qd8+ avait fait d'un seul coup.",
                              "White's king steps to safety; the game is still won, but the hunt must now start over — the very job Qd8+ had finished in a single move.")},
            ],
        },
    ],
}
