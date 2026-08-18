# -*- coding: utf-8 -*-
"""Cavalier seul contre pion-tour — la danse des échecs.

Position construite et vérifiée depuis zéro (aucune position de manuel
recopiée) : le principe classique — un cavalier arrête à lui SEUL un
pion-tour qui n'a pas dépassé sa 6e rangée — démontré avec un roi noir
volontairement relégué à l'autre bout de l'échiquier. L'oracle rend la
leçon spectaculaire : à CHAQUE tentative d'éviction du roi blanc, le
cavalier n'a qu'UN seul coup qui sauve — et c'est toujours un échec ou le
retour au poste. Reprise de la piste « cavalier contre pion-tour »
abandonnée lors d'une session précédente (le camp fort y était inversé) :
ici le cavalier est le HÉROS défenseur, et la question gagné/nul a un sens.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-knight-vs-rook-pawn",
    "name": "Knight vs Rook's Pawn — the Lone Defender",
    "side": "black",
    "kind": "endgame",
    "family": "knights",
    "level": "club",
    "rootFEN": "8/n6k/P7/1K6/8/8/8/8 w - - 0 1",
    "summary": c(
        "Un cavalier seul, roi aux abonnés absents, contre roi et pion-tour : nulle — tant que le pion n'a pas dépassé sa 6e rangée. Mais la défense ne tient qu'à un fil : à chaque attaque du roi blanc, la tablebase ne donne qu'UN coup qui sauve, toujours le même motif — un échec de cavalier qui gagne le temps de revenir. Un pas de danse à connaître par cœur.",
        "A lone knight, its king nowhere in sight, against king and rook's pawn: a draw — as long as the pawn has not passed its 6th rank. But the defence hangs by a thread: after every white king attack, the tablebase gives exactly ONE saving move, always the same motif — a knight check that buys the time to come back. A dance step worth knowing by heart.",
    ),
    "lines": [
        {
            "chapter": {"id": "dance", "title": c("La danse c8-d6-b5 — un seul coup qui sauve, à chaque fois", "The c8-d6-b5 dance — one saving move, every time")},
            "moves": [
                {"san": "Kb6",
                 "comment": c("La seule idée des Blancs : chasser le cavalier de son poste de blocus. Tant qu'il campe en a7, le pion ne peut littéralement pas bouger.",
                              "White's only idea: evict the knight from its blockading post. While it camps on a7, the pawn literally cannot move."),
                 "critical": True},
                {"san": "Nc8+",
                 "comment": c("L'UNIQUE coup qui sauve (tout le reste perd, vérifié à la tablebase) — et c'est un échec. Le cavalier ne se défend jamais passivement : il mord en reculant, et l'échec lui achète le tempo dont il aura besoin pour revenir.",
                              "The ONLY saving move (everything else loses, tablebase-checked) — and it is a check. The knight never defends passively: it bites as it retreats, and the check buys the tempo it will need to come back."),
                 "critical": True},
                {"san": "Kb7",
                 "comment": c("Le roi blanc poursuit sa proie : il attaque c8 et rêve d'escorter le pion depuis b7.",
                              "The white king keeps chasing: it attacks c8 and dreams of escorting the pawn from b7.")},
                {"san": "Nd6+",
                 "comment": c("Deuxième coup unique, deuxième échec. Remarquez le trajet : a7-c8-d6, chaque case du circuit garde un œil sur a8 ou sur les cases d'escorte du roi blanc.",
                              "Second only-move, second check. Note the route: a7-c8-d6 — every square of the circuit keeps an eye on a8 or on the white king's escort squares."),
                 "critical": True},
                "Kc7",
                {"san": "Nb5+",
                 "comment": c("Troisième échec, troisième coup unique. Le roi blanc a beau gagner du terrain, il ne trouve aucune case d'où le cavalier ne puisse le harceler.",
                              "Third check, third only-move. However much ground the white king gains, it cannot find a single square from which the knight cannot harass it."),
                 "critical": True},
                "Kb6",
                {"san": "Nd6",
                 "comment": c("Le seul coup calme de la danse — et toujours le seul qui tienne : depuis d6, le cavalier surveille b7 ET c8, les deux cases dont le roi blanc a besoin pour escorter son pion.",
                              "The one quiet move of the dance — and still the only one that holds: from d6 the knight watches both b7 AND c8, the two squares the white king needs to escort its pawn."),
                 "critical": True},
                "Kc7",
                {"san": "Nb5+",
                 "comment": c("Et la boucle se referme : position identique à celle d'il y a deux coups. Le roi blanc peut recommencer le circuit autant qu'il veut — c8, d6, b5 se relaient sans fin. Nulle par répétition, un cavalier contre un roi entier.",
                              "And the loop closes: the identical position of two moves ago. The white king can run the circuit as often as it likes — c8, d6 and b5 take turns forever. Drawn by repetition, one knight against a whole king."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "push", "title": c("Et si le pion pousse ? Il tombe", "What if the pawn pushes? It falls")},
            "moves": [
                "Kb6", "Nc8+",
                {"san": "Ka5",
                 "comment": c("Le roi blanc renonce à l'éviction et redescend, espérant pousser le pion sous sa seule protection.",
                              "The white king gives up the eviction and drops back, hoping to push the pawn under its own protection.")},
                {"san": "Na7",
                 "comment": c("Le roi s'éloigne d'une case ? Le cavalier retourne au poste dans l'instant. Le blocus reprend comme si rien ne s'était passé.",
                              "The king steps one square away? The knight returns to its post at once. The blockade resumes as if nothing had happened."),
                 "critical": True},
                "Ka4",
                {"san": "Nc6",
                 "comment": c("Mieux : le roi parti, le cavalier peut même quitter le blocus pour ATTAQUER. Depuis c6 il vise la case a7 — si le pion s'y aventure, il ne repartira pas.",
                              "Better still: with the king gone, the knight can even leave the blockade to ATTACK. From c6 it targets a7 — if the pawn ventures there, it will not leave."),
                 "critical": True},
                {"san": "a7",
                 "comment": c("La poussée tant préparée…", "The long-prepared push…")},
                {"san": "Nxa7",
                 "comment": c("…perd le pion sur-le-champ. Cavalier contre roi nu : la nulle la plus limpide du répertoire. Retenez le double registre du cavalier : bloqueur quand le roi presse, chasseur dès qu'il relâche.",
                              "…loses the pawn on the spot. Knight versus bare king: the cleanest draw in the book. Remember the knight's two registers: blockader when the king presses, hunter the moment it lets go."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "one-square-too-far", "title": c("Ne7 — une case trop loin", "Ne7 — one square too far")},
            "moves": [
                "Kb6", "Nc8+", "Kb7",
                {"san": "Ne7", "role": "trap",
                 "comment": c("Fuir vers e7 semble raisonnable — le cavalier « reste en contact » avec c8 et c6. La tablebase est sans appel : la position bascule de nulle à PERDUE. Depuis e7, il faut DEUX sauts pour reprendre le contrôle du chemin de promotion… et les Blancs n'ont besoin que de deux coups.",
                              "Fleeing to e7 looks reasonable — the knight \"stays in touch\" with c8 and c6. The tablebase is final: the position flips from drawn to LOST. From e7 the knight needs TWO hops to regain control of the promotion path… and White only needs two moves."),
                 "critical": True},
                {"san": "a7",
                 "comment": c("Le pion passe la frontière de la 6e rangée — précisément la ligne au-delà de laquelle un cavalier seul ne rattrape plus un pion-tour.",
                              "The pawn crosses the 6th-rank frontier — precisely the line beyond which a lone knight can no longer catch a rook's pawn."),
                 "critical": True},
                {"san": "Nc6",
                 "comment": c("Le cavalier accourt et attaque même le pion — mais a7 est défendu par le roi, et c6 ne contrôle PAS la case a8.",
                              "The knight rushes back and even attacks the pawn — but a7 is defended by the king, and c6 does NOT control a8.")},
                {"san": "a8=Q",
                 "comment": c("Un tempo trop tard. Toute la finale tient dans ce contraste : c8-d6-b5 tiennent la nulle au coup près, e7 perd au coup près.",
                              "One tempo too late. The whole ending lives in this contrast: c8-d6-b5 hold the draw to the exact move, e7 loses by the exact move."),
                 "critical": True},
            ],
        },
    ],
}
