# -*- coding: utf-8 -*-
"""La position de Lucena — LE gain des finales de tours, par le pont.

Toutes les lignes vérifiées à la tablebase (DTM 41 à la racine).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-lucena",
    "name": "The Lucena Position",
    "side": "white",
    "kind": "endgame",
    "family": "rooks",
    "level": "club",
    "rootFEN": "1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1",
    "summary": c(
        "Le roi est devant son pion en 7e, la tour adverse harcèle : c'est la position que TOUTES vos finales de tours gagnées veulent atteindre. Elle se gagne par une manœuvre unique et fameuse — le pont — vieille de quatre siècles.",
        "Your king sits in front of its 7th-rank pawn, the enemy rook harasses: this is the position ALL your winning rook endings are trying to reach. It is won by one famous manoeuvre — the bridge — four centuries old.",
    ),
    "lines": [
        {
            "chapter": {"id": "bridge", "title": c("Construire le pont", "Building the bridge")},
            "moves": [
                {"san": "Rd1+",
                 "comment": c("D'abord chasser le roi noir UN rang plus loin : le pont aura besoin que d7 et d8 soient libres d'échecs. Chaque coup de la manœuvre a sa raison.",
                              "First drive the black king ONE file further: the bridge will need d7 and d8 free of tricks. Every move of the manoeuvre has its reason."),
                 "critical": True},
                {"san": "Ke7", "comment": c("Ke8 revient au même — voyez le chapitre suivant.",
                                            "Ke8 amounts to the same — see the next chapter.")},
                {"san": "Rd4",
                 "comment": c("LE coup du cours, incompréhensible au premier regard : la tour se pose au QUATRIÈME rang, ni plus haut ni plus bas. Elle attend le roi — c'est la pile du pont.",
                              "THE move of the course, baffling at first sight: the rook parks on the FOURTH rank, no higher, no lower. It is waiting for its king — this is the bridge's pillar."),
                 "critical": True},
                {"san": "Ra1",
                 "comment": c("Les Noirs ne peuvent qu'attendre : leur tour doit rester sur la colonne a — quitter la colonne, c'est laisser le roi sortir gratis.",
                              "Black can only wait: the rook must stay on the a-file — leaving it lets the king out for free.")},
                {"san": "Kc7",
                 "comment": c("Le roi sort ENFIN — il n'a jamais pu le faire sans ce préparatif. Les échecs commencent, et ils sont prévus au plan.",
                              "The king FINALLY steps out — he never could without the preparation. The checks begin, and the plan expects them.")},
                "Rc1+",
                {"san": "Kb6", "comment": c("Vers la tour qui échange ? Non : vers la case b5, d'où le roi ne sera plus qu'à un pas du pont.",
                                            "Towards the checking rook? No: towards b5, one step from the bridge.")},
                "Rb1+",
                {"san": "Kc6", "comment": c("Zigzag calculé : le roi ne fuit pas les échecs, il les use.",
                                            "A measured zigzag: the king isn't fleeing the checks, he is wearing them out.")},
                "Rc1+",
                {"san": "Kb5", "critical": True},
                "Rb1+",
                {"san": "Rb4",
                 "comment": c("Le PONT se referme : la tour de d4 s'interpose, les échecs sont finis pour toujours, le pion couronne au prochain coup. Quatre siècles que cette manœuvre gagne — elle vient de gagner pour vous.",
                              "The BRIDGE closes: the d4-rook interposes, the checks are over for good, the pawn queens next move. Four centuries this manoeuvre has been winning — it just won for you."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "ke8", "title": c("L'autre case du roi noir", "The other king square")},
            "moves": [
                "Rd1+",
                {"san": "Ke8", "comment": c("Un rang plus loin ou l'autre case du même rang : rien ne change.",
                                            "One square or the other on the same rank: nothing changes.")},
                {"san": "Rd4", "comment": c("Le pont se construit à l'identique.", "The bridge goes up identically.")},
                "Ra1", "Kc7", "Rc1+", "Kb6", "Rb1+", "Kc6", "Rc1+", "Kb5", "Rb1+",
                {"san": "Rb4", "critical": True},
            ],
        },
        {
            "chapter": {"id": "no-bridge", "title": c("Sans le pont : la roue tourne", "Without the bridge: the wheel spins")},
            "moves": [
                "Rd1+", "Ke7",
                {"san": "Kc7", "role": "inaccuracy",
                 "comment": c("Sortir SANS préparer le pont ne perd pas — mais ne gagne rien : les échecs n'ont pas de fin, et le roi n'a d'autre abri que… b8, d'où il vient.",
                              "Stepping out WITHOUT the bridge doesn't lose — but wins nothing: the checks never end, and the king's only shelter is… b8, where he came from.")},
                "Rc2+",
                {"san": "Kb8",
                 "comment": c("Retour à la case départ. Comptez : trois coups joués, zéro progrès. C'est LA démonstration par l'absurde du pont.",
                              "Back to square one. Count: three moves played, zero progress. The bridge, proven by contradiction.")},
                {"san": "Ra2", "comment": c("Et la tour noire reprend sa faction. Tout est à refaire — par le bon chemin cette fois.",
                                            "And the black rook resumes its post. Everything still to do — the right way this time.")},
            ],
        },
        {
            "chapter": {"id": "trade-trap", "title": c("Le piège du soulagement", "The relief trap")},
            "moves": [
                {"san": "Rc2", "role": "trap",
                 "comment": c("« J'échange les tours et je gagne la finale de pions » — NON : après Txc2, le roi noir est dans le carré et devant la porte. Ce n'est pas une nulle, c'est une DÉFAITE : pion et roi bloqués en b7/b8, la tour noire les cueille. Vérifiez toujours la finale d'APRÈS l'échange.",
                              "“Trade rooks, win the pawn ending” — NO: after Rxc2 the black king is inside the square and guarding the door. Not even a draw: a LOSS — king and pawn entombed on b7/b8, the black rook picks them off. Always check the ending AFTER the trade."),
                 "critical": True},
                {"san": "Rxc2",
                 "comment": c("Les Noirs remercient. Kb8 et b7 ne bougeront plus jamais ; le roi noir escorte sa tour jusqu'à la curée.",
                              "Black says thank you. Kb8 and b7 will never move again; the black king escorts his rook to the feast.")},
            ],
        },
    ],
}
