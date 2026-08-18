# -*- coding: utf-8 -*-
"""Pions liés en 5e contre tour — un rang plus tôt, la tour rafle tout.

Racine construite en miroir exact du cours jumeau « Pions liés en 6e »
(même matériel, mêmes rois éloignés, pions UN rang en arrière) et vérifiée
à l'oracle : le verdict ne se contente pas de retomber à la nulle — il
s'inverse en PLEIN : la tour gagne, trait aux Blancs ou pas. Deux
trouvailles de l'oracle valent le cours à elles seules : après la poussée
e6, TOUS les coups de tour sur la colonne a perdent (les pions iraient plus
vite qu'elle) — c'est le ROI qui gagne, la tour restant clouée sur la 8e ;
et Ta5, qui gagne un pion tant que les deux pions sont en 5e, PERD un
tempo plus tard, une fois la frontière de la 6e franchie.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-rook-vs-connected-fifth",
    "name": "Connected Passers on the 5th — the Rook Strikes First",
    "side": "black",
    "kind": "endgame",
    "family": "rooks",
    "level": "club",
    "rootFEN": "r6k/8/8/3PP3/8/8/8/1K6 w - - 0 1",
    "summary": c(
        "Le cours jumeau l'a montré : deux pions liés sur la 6e rangée battent une tour seule. Les MÊMES pions un rang plus tôt, et tout s'inverse — la tour ne fait pas que tenir, elle gagne. Mais la technique est à double détente : tant que les deux pions sont en 5e, la tour croque ; dès qu'un pion touche la 6e, elle se fige sur la rangée de promotion et laisse le ROI faire le ménage. Confondre les deux moments coûte la partie entière.",
        "The twin course showed it: two connected passers on the 6th rank beat a lone rook. The SAME pawns one rank earlier, and everything flips — the rook does not merely hold, it wins. But the technique has two settings: while both pawns stand on the 5th, the rook snacks; the moment one pawn touches the 6th, it freezes on the promotion rank and lets the KING do the cleaning. Mixing up the two moments costs the whole game.",
    ),
    "lines": [
        {
            "chapter": {"id": "king-walks", "title": c("La poussée réfutée — par le roi, pas par la tour", "The push refuted — by the king, not the rook")},
            "moves": [
                {"san": "e6",
                 "comment": c("Le seul rêve des pions : courir. Sur la 5e, il leur manque exactement un rang — ce cours montre ce que ce rang change.",
                              "The pawns' only dream: to run. On the 5th they are exactly one rank short — this course shows what that rank changes.")},
                {"san": "Kg7",
                 "comment": c("Le coup-vedette, et le plus contre-intuitif du cours : la tour NE BOUGE PAS. Vérifié à la tablebase : après e6, chaque coup de tour sur la colonne a PERD — les pions iraient plus vite qu'elle. Depuis a8, la tour balaie déjà les DEUX cases de promotion ; le travailleur manquant, c'est le roi.",
                              "The star move, and the most counterintuitive of the course: the rook DOES NOT MOVE. Tablebase-verified: after e6, every rook move along the a-file LOSES — the pawns would outrun it. From a8 the rook already sweeps BOTH promotion squares; the missing worker is the king."),
                 "critical": True},
                "d6", "Kf6",
                {"san": "e7",
                 "comment": c("Les pions font ce qu'ils savent faire — mais regardez la répartition des rôles en face : la tour tient la rangée du fond, le roi arrive au contact.",
                              "The pawns do what pawns do — but look at the division of labour across the board: the rook holds the back rank, the king closes in.")},
                {"san": "Ke6",
                 "comment": c("Le roi noir pose une main sur chaque pion : e7 est attaqué, d7 est couvert. Aucun des deux ne passera — la promotion appartient à la tour, le contact appartient au roi.",
                              "The black king lays a hand on each pawn: e7 is attacked, d7 is covered. Neither will get through — the promotion rank belongs to the rook, the contact squares to the king."),
                 "critical": True},
                "d7",
                {"san": "Kxd7",
                 "comment": c("Le premier pion tombe au moment précis où il touche la 7e.",
                              "The first pawn falls at the precise moment it touches the 7th.")},
                "Kc2",
                {"san": "Kxe7",
                 "comment": c("Et le second. Deux pions liés, un rang trop court, zéro dame. La suite — tour et roi contre roi — est le mat élémentaire de la tour, enseigné dans son propre cours.",
                              "And the second. Two connected passers, one rank short, zero queens. What follows — rook and king versus king — is the elementary rook mate, taught in its own course."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "snack", "title": c("Tant qu'ils sont en 5e, la tour se sert", "While they stand on the 5th, the rook helps itself")},
            "moves": [
                {"san": "Kc2",
                 "comment": c("La meilleure défense selon la tablebase : ne PAS pousser (la poussée perd plus vite, chapitre précédent) et ramener le roi. Aveu remarquable : deux pions liés en 5e, seuls, n'osent même pas avancer.",
                              "The tablebase's best defence: do NOT push (the push loses faster, previous chapter) and bring the king home. A remarkable admission: two connected passers on the 5th, left alone, dare not even advance.")},
                {"san": "Ra5",
                 "comment": c("La tour attaque le rang des pions par le flanc. Côte à côte sur la 5e, ils ne se protègent PAS l'un l'autre — un pion ne défend jamais son voisin de rangée. Retenez le moment : ce même coup perd une fois qu'un pion a touché la 6e (voir le piège).",
                              "The rook attacks the pawns' rank from the flank. Side by side on the 5th, they do NOT protect each other — a pawn never defends its rank neighbour. Mark the timing: this same move loses once a pawn has touched the 6th (see the trap)."),
                 "critical": True},
                "Kd3",
                {"san": "Rxd5+",
                 "comment": c("Un pion dans la poche — avec échec, s'il vous plaît. Le duo était exactement cela : un duo ; il n'en reste qu'un pion isolé.",
                              "One pawn pocketed — with check, no less. The duo was exactly that: a duo; all that remains is one isolated pawn."),
                 "critical": True},
                "Ke4",
                {"san": "Rd1",
                 "comment": c("La tour se retire à distance de sécurité, hors de portée du roi — active, jamais accrochée.",
                              "The rook falls back to a safe distance, out of the king's reach — active, never entangled.")},
                "e6",
                {"san": "Re1+",
                 "comment": c("L'échec chasse d'abord le roi de l'escorte — la tour ne se met derrière le pion qu'une fois le roi écarté.",
                              "The check first drives the king away from escort duty — the rook only lines up behind the pawn once the king has been pushed aside."),
                 "critical": True},
                "Kd5",
                {"san": "Kg7",
                 "comment": c("Et le roi noir se met en route, comme au chapitre précédent. Un pion esseulé, une tour active, un roi qui arrive : la conversion est une formalité.",
                              "And the black king sets off, as in the previous chapter. One lonely pawn, an active rook, a king on its way: the conversion is a formality."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "late-snack", "title": c("Le même Ta5, un tempo trop tard", "The same Ra5, one tempo too late")},
            "moves": [
                "e6",
                {"san": "Ra5", "role": "trap",
                 "comment": c("Le coup qui gagnait au chapitre précédent — joué UN tempo trop tard, il perd la partie entière (vérifié : de gagnée, la position devient PERDUE). Le pion e a franchi la frontière de la 6e : la tour ne doit plus quitter la rangée du fond.",
                              "The move that won in the previous chapter — played ONE tempo too late, it loses the entire game (verified: from won, the position becomes LOST). The e-pawn has crossed the 6th-rank frontier: the rook must never leave the back rank again."),
                 "critical": True},
                {"san": "e7",
                 "comment": c("Et la tour découvre le piège géométrique : impossible de revenir par la 5e rangée — son propre butin visé, le pion d5, lui bloque le chemin vers la colonne e. Les échecs de flanc s'épuiseront pareil : le roi blanc remontera se cacher derrière ses pions.",
                              "And the rook discovers the geometric trap: no way back along the 5th rank — its own intended loot, the d5-pawn, blocks the road to the e-file. Flank checks would run dry the same way: the white king walks up and hides behind its own pawns."),
                 "critical": True},
                {"san": "Ra8",
                 "comment": c("Retour en rampant vers la rangée de promotion — un tempo trop tard, encore.",
                              "Crawling back to the promotion rank — one tempo too late, again.")},
                {"san": "d6",
                 "comment": c("Reconnaissez le tableau : pions en 6e et en 7e, tour spectatrice — la position exacte du cours jumeau, celle où les pions BATTENT la tour. Un rang et un tempo : c'était toute la partie.",
                              "Recognise the picture: pawns on the 6th and 7th, rook reduced to spectating — the exact position of the twin course, the one where the pawns BEAT the rook. One rank and one tempo: that was the whole game."),
                 "critical": True},
            ],
        },
    ],
}
