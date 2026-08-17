# -*- coding: utf-8 -*-
"""Dame contre pion-fou en 7e — l'exception, dépoussiérée par la tablebase.

Le folklore des manuels dit : « pion c ou f : le défenseur se réfugie en a1,
Dxc2 fait pat, nulle ». L'oracle raconte une histoire plus fine, et c'est
CELLE-LÀ qu'on enseigne : la vraie ressource est la PROMOTION-ÉCHANGE
(c1=D !) dès que la dame touche la zone ; le pèlerinage en a1, joué trop
tôt, PERD — la dame reroute par c1 et prend le pion avec échec. Le pat ne
sauve que si l'attaquant veut bien prendre.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-vs-bishop-pawn",
    "name": "Queen vs Bishop's Pawn",
    "side": "black",
    "kind": "endgame",
    "family": "queens",
    "level": "advanced",
    "rootFEN": "8/1K5Q/8/8/8/8/1kp5/8 w - - 0 1",
    "summary": c(
        "La même finale que « Dame contre pion »… sauf que le pion est en c2, et tout bascule : ici c'est NULLE, à condition de connaître la vraie ressource — qui n'est pas celle de la légende. La tablebase a des surprises pour les deux camps.",
        "The same ending as “Queen vs Pawn”… except the pawn stands on c2, and everything flips: this is a DRAW, provided you know the real resource — which is not the one of legend. The tablebase has surprises for both sides.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Promouvoir pour échanger", "Promote to trade")},
            "moves": [
                {"san": "Qc7",
                 "comment": c("Les Blancs se mettent en face du pion. Contre un pion central, la vis sans fin gagnerait — ici, regardez la parade.",
                              "White lines up in front of the pawn. Against a central pawn the endless screw would win — here, watch the antidote.")},
                {"san": "Kb1",
                 "comment": c("Le roi reste COLLÉ à son pion, prêt à reprendre en c1. C'est lui le garde du corps de l'échange qui vient.",
                              "The king stays GLUED to his pawn, ready to recapture on c1. He is the bodyguard of the coming trade."),
                 "critical": True},
                {"san": "Kb6", "comment": c("Le roi blanc accourt — il n'arrivera jamais à temps.",
                                            "The white king rushes over — he will never make it in time.")},
                {"san": "c1=Q",
                 "comment": c("LA ressource, et ce n'est pas le pat : promouvoir POUR ÉCHANGER. La colonne c s'est vidée, la dame blanche doit prendre — et le roi noir reprend. Il ne restera que deux rois.",
                              "THE resource, and it isn't stalemate: promote TO TRADE. The c-file is now empty, the white queen must take — and the black king recaptures. Only two kings will remain."),
                 "critical": True},
                {"san": "Qxc1+", "comment": c("Refuser l'échange laisserait dame contre dame : nulle aussi.",
                                              "Declining the trade leaves queen versus queen: also a draw.")},
                {"san": "Kxc1",
                 "comment": c("Roi contre roi. Retenez le duo qui tient cette nulle : roi collé au pion + promotion-échange dès que la dame s'approche de c1.",
                              "King versus king. Remember the duo that holds this draw: king glued to the pawn + promotion-trade the moment the queen nears c1."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "screw-fails", "title": c("La vis sans fin tourne à vide", "The screw spins loose")},
            "moves": [
                {"san": "Qh2", "comment": c("L'attaque « normale » : la dame arrive par derrière, comme contre le pion central.",
                                            "The “normal” attack: the queen comes from behind, as against the central pawn.")},
                "Kb1",
                {"san": "Qd2", "comment": c("La dame touche la zone de promotion. Contre un pion d, les Noirs seraient perdus. Ici…",
                                            "The queen touches the promotion zone. Against a d-pawn Black would be lost. Here…")},
                {"san": "c1=Q",
                 "comment": c("…la promotion-échange, ENCORE elle — et c'est le SEUL coup qui tient : tout le reste perd, y compris le fameux Ka1 (chapitre suivant). La dame d2 est trop près : elle ne peut ni refuser l'échange ni le gagner.",
                              "…the promotion-trade AGAIN — and it is the ONLY move that holds: everything else loses, including the famous Ka1 (next chapter). The d2-queen stands too close: she can neither decline the trade nor win it."),
                 "critical": True},
                "Qxc1+",
                {"san": "Kxc1", "critical": True},
            ],
        },
        {
            "chapter": {"id": "a1-legend", "title": c("La légende du coin a1", "The legend of the a1 corner")},
            "moves": [
                "Qh2", "Kb1", "Qd2",
                {"san": "Ka1", "role": "trap",
                 "comment": c("Le coup des manuels : « au coin, et si Dxc2 c'est pat ». La tablebase est formelle : joué ICI, il PERD. Le pat n'est une ressource que si l'adversaire veut bien prendre — et il ne prendra pas comme ça.",
                              "The book move: “into the corner, and Qxc2 is stalemate”. The tablebase is categorical: played HERE, it LOSES. Stalemate is only a resource if the opponent agrees to capture — and he won't, not like this."),
                 "critical": True},
                {"san": "Qc1+",
                 "comment": c("Le détour mortel : la dame passe PAR c1 — la case que le roi vient d'abandonner en quittant b1.",
                              "The lethal detour: the queen goes VIA c1 — the very square the king gave up when he left b1.")},
                "Ka2",
                {"san": "Qxc2+",
                 "comment": c("Et le pion tombe AVEC ÉCHEC : aucun pat possible. La différence entre la légende et la vérité tenait à un temps — celui que Ka1 a offert.",
                              "And the pawn falls WITH CHECK: no stalemate anywhere. The gap between legend and truth was one tempo — the one Ka1 gave away.")},
                "Ka1",
                {"san": "Qd2", "comment": c("Dame contre roi nu : voir « Le mat à la dame ».",
                                            "Queen against bare king: see “The Queen Mate”.")},
            ],
        },
        {
            "chapter": {"id": "stalemate", "title": c("Le pat existe — en face", "The stalemate exists — for them")},
            "moves": [
                "Qh2", "Kb1", "Qd2",
                {"san": "Ka1", "role": "trap"},
                {"san": "Qxc2", "role": "trap",
                 "comment": c("Si les Blancs GOBENT le pion… PAT — a2, b1 et b2 sont tous couverts par la dame, et le roi n'a plus un souffle. Voilà d'où vient la légende : le piège est réel, mais c'est un piège pour L'ATTAQUANT distrait, pas une défense fiable.",
                              "If White GOBBLES the pawn… STALEMATE — a2, b1 and b2 all covered by the queen, and the king can't breathe. That is where the legend comes from: the trap is real, but it traps a CARELESS ATTACKER — it is no reliable defence."),
                 "critical": True},
            ],
        },
    ],
}
