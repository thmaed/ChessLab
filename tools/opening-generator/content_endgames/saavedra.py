# -*- coding: utf-8 -*-
"""La position de Saavedra (1895) — la sous-promotion la plus célèbre du jeu.

Ligne historique intégralement vérifiée à la tablebase, pat compris. Sources
factuelles : Wikipédia (histoire Fenton-Potter 1875, Barbier, Saavedra).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-saavedra",
    "name": "The Saavedra Position",
    "side": "white",
    "kind": "endgame",
    "family": "practical",
    "level": "advanced",
    "rootFEN": "8/8/1KP5/3r4/8/8/8/k7 w - - 0 1",
    "summary": c(
        "Un pion contre une tour, et la plus belle chute de l'histoire des finales : en 1895, un prêtre espagnol de passage à Glasgow trouve le coup que tout le monde avait manqué. La promotion… mais pas en dame.",
        "A pawn against a rook, and the most beautiful punchline in endgame history: in 1895 a Spanish priest passing through Glasgow found the move everyone had missed. Promotion… but not to a queen.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("L'escalier et la chute", "The staircase and the punchline")},
            "moves": [
                {"san": "c7",
                 "comment": c("Le pion fonce — la tour n'a que les échecs pour l'arrêter. Suivez le roi blanc : chaque pas de sa descente est le SEUL qui marche.",
                              "The pawn charges — the rook has only checks to stop it. Watch the white king: every step of his descent is the ONLY one that works."),
                 "critical": True},
                "Rd6+",
                {"san": "Kb5",
                 "comment": c("Ni Kb7/Ka7 (…Td7 cloue le pion), ni Kc5 — voir le chapitre du détour. Le roi descend COLLÉ à la colonne c.",
                              "Not Kb7/Ka7 (…Rd7 pins the pawn), not Kc5 — see the detour chapter. The king walks down HUGGING the c-file.")},
                "Rd5+",
                {"san": "Kb4"},
                "Rd4+",
                {"san": "Kb3"},
                "Rd3+",
                {"san": "Kc2",
                 "comment": c("La descente s'achève : plus d'échecs utiles, la tour est à court de rangées. Il ne lui reste qu'une ruse — la plus fine de l'histoire.",
                              "The descent ends: no useful checks left, the rook has run out of ranks. One trick remains — the finest ever played."),
                 "critical": True},
                {"san": "Rd4",
                 "comment": c("Le piège de Barbier : la tour ATTEND. Si la dame apparaît en c8, …Tc4+! force DxT — PAT, le roi noir en a1 n'a plus un souffle. Pendant des semaines, le monde a cru cette étude nulle.",
                              "Barbier's trap: the rook WAITS. If a queen appears on c8, …Rc4+! forces QxR — STALEMATE, the black king on a1 out of breath. For weeks the world believed this study drawn.")},
                {"san": "c8=R",
                 "comment": c("LA trouvaille de Saavedra : une TOUR. Elle menace Ta8-a1 mat, et le pat s'est évanoui — une tour en c4 se prendrait sans étouffer personne. Une seule pièce au monde gagne ici, et ce n'est pas la dame.",
                              "Saavedra's find: a ROOK. It threatens Ra8-a1 mate, and the stalemate has vanished — a rook on c4 could be captured without smothering anyone. Exactly one piece in the world wins here, and it is not the queen."),
                 "critical": True},
                {"san": "Ra4",
                 "comment": c("La dernière défense : parer le mat en préparant …Ta4-a2+ ou le retour du pat.",
                              "The last defence: stopping the mate while eyeing …Ra4-a2+ or another stalemate try.")},
                {"san": "Kb3",
                 "comment": c("Le coup double qui clôt l'étude : menace Tc1 MAT, et la tour a4 est en prise. Les Noirs peuvent donner un échec (…Tb4+), le roi prend, et la suite est « Le mat à la tour ».",
                              "The double blow that ends the study: Rc1 MATE is threatened, and the a4-rook hangs. Black may spite-check (…Rb4+), the king takes, and what follows is “The Rook Mate”."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "queen-trap", "title": c("La dame qui fait pat", "The queen that stalemates")},
            "moves": [
                "c7", "Rd6+", "Kb5", "Rd5+", "Kb4", "Rd4+", "Kb3", "Rd3+", "Kc2", "Rd4",
                {"san": "c8=Q", "role": "trap",
                 "comment": c("Le réflexe de tout joueur — et la nulle instantanée que Barbier avait publiée comme verdict final de l'étude.",
                              "Every player's reflex — and the instant draw Barbier had published as the study's final verdict."),
                 "critical": True},
                {"san": "Rc4+",
                 "comment": c("L'échec-suicide : la tour se jette sur la dame.",
                              "The suicide check: the rook hurls itself at the queen.")},
                {"san": "Qxc4",
                 "comment": c("Forcé (fuir l'échec abandonne la tour ET le gain)… et c'est PAT : a2 et b1 sont sous la dame, b2 sous les deux rois. Toute l'étude tient dans la différence entre cette image et c8=T.",
                              "Forced (running abandons rook and win alike)… and it is STALEMATE: a2 and b1 covered by the queen, b2 by both kings. The whole study lives in the gap between this picture and c8=R.")},
            ],
        },
        {
            "chapter": {"id": "detour", "title": c("Le détour qui annule", "The detour that draws")},
            "moves": [
                "c7", "Rd6+",
                {"san": "Kc5", "role": "trap",
                 "comment": c("Attaquer la tour a l'air actif — mais le roi quitte l'ombre de la colonne c : …Td1 ! et la tour reviendra en c1 derrière le pion. La descente b5-b4-b3 n'était pas une manière, c'était LA route.",
                              "Attacking the rook looks active — but the king leaves the c-file's shadow: …Rd1! and the rook will swing to c1 behind the pawn. The b5-b4-b3 descent wasn't a style choice, it was THE road."),
                 "critical": True},
                {"san": "Rd1",
                 "comment": c("Menace Tc1(+) : le pion est condamné à donner sa vie pour rien. Nulle.",
                              "Threatens Rc1(+): the pawn is doomed to give itself for nothing. Draw.")},
            ],
        },
        {
            "chapter": {"id": "no-checks", "title": c("Et sans les échecs ?", "And without the checks?")},
            "moves": [
                "c7",
                {"san": "Rd1",
                 "comment": c("Renoncer aux échecs tout de suite ne vaut rien ICI : le roi blanc touche encore son pion.",
                              "Giving up the checks at once is worthless HERE: the white king still touches his pawn.")},
                {"san": "c8=Q",
                 "comment": c("La dame naît tranquille — …Tc1 arrive trop tard, Dxc1 n'est même pas pat (le roi blanc est loin du coin). Les échecs noirs de la ligne principale étaient la SEULE tentative ; c'est ce qui rend l'étude si pure.",
                              "The queen is born in peace — …Rc1 comes too late, and Qxc1 isn't even stalemate (the white king is far from the corner). Black's checks in the main line were the ONLY try; that purity is the study's beauty."),
                 "critical": True},
            ],
        },
    ],
}
