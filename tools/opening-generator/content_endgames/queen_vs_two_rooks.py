# -*- coding: utf-8 -*-
"""Dame contre deux tours — la coordination qui tient, la case qui trahit.

Sans pion, deux tours bien coordonnées tiennent la nulle contre la dame
seule (Dvoretsky, Fine & Benko). La clé : les deux tours doivent se
défendre l'une l'autre. Un roi encore sur la rangée qui les sépare rompt
cette coordination — la dame croque alors une tour avec échec, gratuitement.
Racine à 4 pièces, chaque choix noir tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-vs-two-rooks",
    "name": "Queen vs Two Rooks",
    "side": "black",
    "kind": "endgame",
    "family": "queens",
    "level": "advanced",
    "rootFEN": "r5kr/8/8/8/3QK3/8/8/8 w - - 0 1",
    "summary": c(
        "Sans pion, deux tours valent en général un peu plus qu'une dame — mais seulement si elles se protègent mutuellement. Le roi noir doit impérativement quitter la rangée qui les sépare, sous peine de perdre l'une des deux gratuitement.",
        "Without pawns, two rooks are usually worth slightly more than a queen — but only if they protect each other. Black's king must get off the rank that separates them, or lose one of the two for free.",
    ),
    "lines": [
        {
            "chapter": {"id": "off-the-rank", "title": c("Le roi doit quitter la rangée", "The king must leave the rank")},
            "moves": [
                {"san": "Qd5+", "comment": c("Échec, et la dame vise déjà la diagonale a8-h1 — juste là où sommeille la tour a8.", "Check, and the queen already eyes the a8-h1 diagonal — right where the a8 rook sleeps.")},
                {"san": "Kg7",
                 "comment": c("Essentiel : en quittant complètement la 8e rangée, le roi noir libère la ligne entre les deux tours. Désormais a8 et h8 se défendent mutuellement — la dame ne peut plus en croquer une sans perdre l'échange dans la foulée.",
                              "Essential: by leaving the 8th rank entirely, Black's king clears the line between the two rooks. Now a8 and h8 defend each other — the queen can no longer grab one without losing the exchange right back."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "stay-on-the-rank", "title": c("Rester sur la rangée coûte une tour", "Staying on the rank costs a rook")},
            "moves": [
                {"san": "Qd5+", "comment": c("Le même échec.", "The same check.")},
                {"san": "Kf8", "role": "trap",
                 "comment": c("Une case tout aussi proche que g7 — mais le roi reste SUR la 8e rangée, coincé entre ses deux tours au lieu de les laisser communiquer.",
                              "A square just as close as g7 — but the king stays ON the 8th rank, wedged between its two rooks instead of letting them communicate."),
                 "critical": True},
                {"san": "Qxa8+",
                 "comment": c("La dame croque la tour a8 gratuitement — le roi, resté sur la rangée, bloque justement la case que la tour h8 aurait dû traverser pour reprendre. Et c'est échec en prime.",
                              "The queen grabs the a8 rook for free — the king, having stayed on the rank, blocks exactly the square the h8 rook would have needed to cross to recapture. And it's check to boot."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "grab-anyway", "title": c("Et si la dame croque quand même ?", "And if the queen grabs anyway?")},
            "moves": [
                "Qd5+",
                "Kg7",
                {"san": "Qxa8",
                 "comment": c("Cette fois la rangée est parfaitement dégagée — la tentation coûte cher.", "This time the rank is completely clear — the temptation is costly.")},
                {"san": "Rxa8",
                 "comment": c("La tour h8 reprend aussitôt le long de la 8e rangée. La dame a cédé sa valeur contre une seule tour, et le camp des tours se retrouve en fait matériellement supérieur : la coordination a payé exactement comme prévu.",
                              "The h8 rook recaptures at once along the 8th rank. The queen traded its value for a single rook, and the rook side ends up materially ahead: the coordination paid off exactly as intended."),
                 "critical": True},
            ],
        },
    ],
}
