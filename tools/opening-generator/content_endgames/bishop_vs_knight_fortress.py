# -*- coding: utf-8 -*-
"""Fou contre cavalier — le sacrifice qui bloque le pion.

Sourcé Wikipédia (« Finale fou contre cavalier ») : l'étude de Sam Loyd
(1860). Un fou seul contre cavalier et pion presque promu : la seule
parade est un sacrifice de fou sur la case même de promotion, qui emmure
le roi noir derrière son propre pion. Racine à 5 pièces, chaque coup
blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-bishop-vs-knight-fortress",
    "name": "Bishop vs Knight — Sam Loyd's Fortress",
    "side": "white",
    "kind": "endgame",
    "family": "bishops",
    "level": "advanced",
    "rootFEN": "8/8/8/8/B6n/7p/6k1/4K3 w - - 0 1",
    "summary": c(
        "Un pion à un pas de la promotion, un cavalier qui le soutient, et un fou tout seul en face. La retraite naturelle perd toujours — la seule parade est un sacrifice qui piège le roi noir derrière son propre pion.",
        "A pawn one step from queening, a knight backing it up, and a lone bishop facing them. The natural retreat always loses — the only defence is a sacrifice that traps Black's own king behind his pawn.",
    ),
    "lines": [
        {
            "chapter": {"id": "main-line", "title": c("Le sacrifice qui bloque le pion", "The sacrifice that jams the pawn")},
            "moves": [
                {"san": "Bd7",
                 "comment": c("Le seul coup qui tienne la nulle depuis la racine — chaque retraite testée par l'oracle perd. Le fou garde ses distances sans encore rien décider.",
                              "The only move that holds the draw from the start — every retreat the oracle tried loses. The bishop keeps its distance without committing yet."),
                 "critical": True},
                {"san": "h2", "comment": c("Le pion est à un pas de dame.", "The pawn is one step from queening.")},
                {"san": "Bc6+",
                 "comment": c("Échec — le roi noir doit choisir son camp avant que le fou ne joue sa carte.", "Check — Black's king must commit before the bishop plays its card."),
                 "critical": True},
                "Kg1",
                {"san": "Bh1",
                 "comment": c("Le coup du siècle : le fou se plante SUR la case de promotion, en prise. Le roi noir n'a pas d'autre choix raisonnable que de le prendre — et en le prenant, il s'emmure lui-même dans le coin, juste devant son propre pion.",
                              "The move of the study: the bishop plants itself ON the queening square, hanging. Black's king has no reasonable choice but to take it — and in taking it, it walls itself into the corner, right in front of its own pawn."),
                 "critical": True},
                {"san": "Kxh1",
                 "comment": c("Forcé dans les faits : refuser, c'est laisser le fou continuer à surveiller la case de promotion indéfiniment. Mais accepter coûte cher — le roi noir ne ressortira plus jamais du coin tant que le pion h2 reste derrière lui.",
                              "Forced in practice: declining leaves the bishop watching the queening square forever. But accepting costs dearly — Black's king will never leave the corner again while the h2 pawn sits behind it.")},
                {"san": "Kf2",
                 "comment": c("Le roi blanc vient garder l'entrée — g1 et g2 restent sous contrôle, la seule porte de sortie du roi noir.", "White's king comes to guard the entrance — g1 and g2 stay covered, Black's king's only way out."),
                 "critical": True},
                "Ng2",
                {"san": "Kf1",
                 "comment": c("Forteresse : le roi blanc navigue entre f1 et f2, le cavalier a beau tourner autour, il ne peut ni déloger le roi blanc ni libérer le roi noir. Nulle par répétition — vérifié : aucune tentative noire testée par l'oracle depuis ce carrefour n'a jamais fait mieux.",
                              "Fortress: White's king shuttles between f1 and f2; the knight can circle all it wants, it can neither dislodge White's king nor free Black's. Draw by repetition — verified: no Black try the oracle tested from this crossroads ever did better."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "natural-retreat", "title": c("La retraite naturelle qui perd", "The natural retreat that loses")},
            "moves": [
                "Bd7",
                "h2",
                "Bc6+",
                "Kg1",
                {"san": "Bg2", "role": "trap",
                 "comment": c("L'instinct : mettre le fou à l'abri, loin de la case de promotion. Mais g2 est juste à côté du roi noir — et rien ne défend le fou.",
                              "The instinct: tuck the bishop away, far from the queening square. But g2 sits right next to Black's king — and nothing defends the bishop."),
                 "critical": True},
                {"san": "Kxg2",
                 "comment": c("Le roi noir croque le fou gratuitement et sort du coin au lieu d'y être enfermé. Sans le sacrifice sur la case de promotion, il ne reste plus rien pour arrêter le pion.",
                              "Black's king gobbles the bishop for free and steps out of the corner instead of being trapped in it. Without the sacrifice on the queening square, nothing is left to stop the pawn."),
                 "critical": True},
            ],
        },
    ],
}
