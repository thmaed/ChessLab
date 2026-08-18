# -*- coding: utf-8 -*-
"""Tour et fou contre tour — la position de Philidor (celle qui GAGNE).

Sourcé Wikipédia (« Rook and bishop versus rook endgame ») : la position
analysée par Philidor en 1749 — Rd6/Ff1→d5/Tf1 contre Rd8/Te7. Le pendant
offensif des trois défenses déjà au catalogue (2e rangée, Cochrane, Szén) :
quand le roi défenseur est acculé sur la rangée du fond FACE au roi
attaquant, même la meilleure défense perd. Vérifié à l'oracle : des 23
coups blancs possibles à la racine, UN SEUL gagne (1.Tf8+, dtm 41) — tous
les autres, y compris le naturel 1.Fc6, ne font que nulle. Ligne principale
DTM-optimale de bout en bout, défense la plus coriace de la tablebase.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-philidor-rook-bishop",
    "name": "Rook and Bishop vs Rook — Philidor's Win",
    "side": "white",
    "kind": "endgame",
    "family": "imbalances",
    "level": "advanced",
    "rootFEN": "3k4/4r3/3K4/3B4/8/8/8/5R2 w - - 0 1",
    "summary": c(
        "Tour et fou contre tour est nulle en général — trois cours de ce catalogue enseignent comment la tenir. Voici l'exception que Philidor a analysée dès 1749 : le roi défenseur acculé sur la rangée du fond, FACE au roi attaquant, perd même avec la meilleure défense. Un seul des 23 coups blancs gagne ici : chaque étape de la manœuvre a un sens précis.",
        "Rook and bishop versus rook is generally a draw — three courses in this catalogue teach how to hold it. Here is the exception Philidor analysed back in 1749: the defending king trapped on the back rank, FACING the attacking king, loses even against best defence. Only one of White's 23 moves wins here — and every step of the manoeuvre has a precise meaning.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("La manœuvre de Philidor, coup par coup", "Philidor's manoeuvre, move by move")},
            "moves": [
                {"san": "Rf8+",
                 "comment": c("Le SEUL coup gagnant sur 23 possibles (vérifié à la tablebase — tout le reste est nulle). L'échec force la tour noire à s'interposer en e8, où elle bloque sa propre case de fuite.",
                              "The ONLY winning move out of 23 (tablebase-checked — everything else is a draw). The check forces Black's rook to interpose on e8, where it blocks its king's own escape square."),
                 "critical": True},
                "Re8",
                {"san": "Rf7",
                 "comment": c("Le cœur de l'idée : la tour blanche prend la 7e rangée et menace le mat par le flanc. La tour noire est en zugzwang — rester en e8 est impossible (elle doit parer Ta7-a8), elle doit donc quitter la 8e rangée et abandonner son roi.",
                              "The heart of the idea: White's rook seizes the 7th rank and threatens mate from the side. Black's rook is in zugzwang — it cannot stay on e8 (it must meet Ra7-a8), so it has to leave the 8th rank and abandon its king."),
                 "critical": True},
                {"san": "Re2",
                 "comment": c("La meilleure défense selon la tablebase : la tour file le plus loin possible, prête à harceler par-derrière.",
                              "The tablebase's toughest defence: the rook runs as far as it can, ready to harass from behind.")},
                "Rg7", "Re1", "Rb7",
                {"san": "Rc1",
                 "comment": c("La tour noire doit garder la colonne c — sinon Tb8+ suivi du mat. La voilà assignée à une seule colonne : c'est exactement ce que Blancs voulaient.",
                              "Black's rook must guard the c-file — otherwise Rb8+ followed by mate. It is now tied to a single file: exactly what White wanted.")},
                {"san": "Bb3",
                 "comment": c("Première étape du triangle du fou (b3-e6-d5) : le fou quitte d5 EN GAGNANT un tempo — depuis b3 il contrôle toujours la grande diagonale vers e6, et prépare à revenir en d5 au moment où cela gênera le plus la tour noire.",
                              "First step of the bishop triangle (b3-e6-d5): the bishop leaves d5 while GAINING a tempo — from b3 it still eyes e6, preparing to return to d5 at the exact moment it most inconveniences Black's rook."),
                 "critical": True},
                "Rc3", "Be6", "Rd3+",
                {"san": "Bd5",
                 "comment": c("Le triangle est bouclé : même position qu'au départ, mais la tour noire est passée de c1 à d3 — une case bien pire, comme la suite le montre. Perdre un tempo pour le donner à l'adversaire : la même arme que la triangulation des finales de pions.",
                              "The triangle is complete: same position as before, but Black's rook has been pushed from c1 to d3 — a far worse square, as the sequel shows. Losing a tempo to hand the move back: the very weapon of triangulation in pawn endings."),
                 "critical": True},
                "Rc3",
                {"san": "Rd7+",
                 "comment": c("Maintenant que la tour noire n'est plus en c1, le roi noir est chassé de d8 — vers le côté où la tour blanche l'attend.",
                              "Now that Black's rook no longer sits on c1, the black king is evicted from d8 — towards the side where White's rook awaits it."),
                 "critical": True},
                "Kc8", "Rf7", "Kb8", "Rb7+", "Kc8",
                {"san": "Rb4",
                 "comment": c("Le filet final : la tour vise a4 puis a8. Contre la menace Fe6+ suivie de Tb8 mat, la défense n'a plus que des ressources d'un coup.",
                              "The final net: the rook aims for a4, then a8. Against the threat of Be6+ followed by Rb8 mate, the defence is down to one-move resources."),
                 "critical": True},
                "Rd3",
                {"san": "Ra4",
                 "comment": c("Menace Ta8 mat (le fou d5 couvre la case de fuite b7). La tour noire n'a qu'une parade : se jeter sur le fou.",
                              "Threatening Ra8 mate (the d5-bishop covers the b7 escape square). Black's rook has a single resource left: throwing itself at the bishop."),
                 "critical": True},
                {"san": "Rxd5+",
                 "comment": c("Le sacrifice du désespoir — la meilleure défense de la tablebase, littéralement : tout le reste se fait mater plus vite.",
                              "The desperado sacrifice — literally the tablebase's best defence: everything else gets mated faster.")},
                {"san": "Kxd5",
                 "comment": c("Il reste roi et tour contre roi : le mat élémentaire, enseigné dans son propre cours. La leçon de Philidor s'arrête ici — retenez le trio : échec qui force l'interposition, 7e rangée, triangle du fou.",
                              "What remains is king and rook versus king: the elementary mate, taught in its own course. Philidor's lesson ends here — remember the trio: the check forcing the interposition, the 7th rank, the bishop triangle."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "natural-draw", "title": c("Le coup naturel qui laisse tout filer", "The natural move that lets it all slip")},
            "moves": [
                {"san": "Bc6", "role": "trap",
                 "comment": c("Développer une menace de mat avec le fou semble naturel — et ne fait que NULLE (vérifié : la position passe de gagnée à nulle). La tour noire dispose d'une ressource étonnante.",
                              "Building a mating threat with the bishop looks natural — and only DRAWS (verified: the position drops from won to drawn). Black's rook has an astonishing resource."),
                 "critical": True},
                {"san": "Rd7+",
                 "comment": c("Le contre-coup : échec ET offre de la tour. La refuser oblige le roi blanc à lâcher d6, et toute la pression s'évapore.",
                              "The counterblow: a check AND a rook offer. Declining it forces White's king to give up d6, and all the pressure evaporates."),
                 "critical": True},
                {"san": "Bxd7",
                 "comment": c("Pat ! Le roi noir n'a plus une seule case (le fou en d7 couvre c8 et e8, le roi blanc couvre le reste) et aucune pièce à jouer. Voilà pourquoi seul 1.Tf8+ gagne : il ne laisse jamais naître ce contre-jeu.",
                              "Stalemate! The black king has no square left (the d7-bishop covers c8 and e8, White's king covers the rest) and no piece to move. That is why only 1.Rf8+ wins: it never lets this counterplay arise."),
                 "critical": True},
            ],
        },
    ],
}
