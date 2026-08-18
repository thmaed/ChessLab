# -*- coding: utf-8 -*-
"""Dame et pion contre dame — le parapluie.

Sourcé Müller & Lamprecht, « Fundamental Chess Endings », diagramme 9.12A
(via Wikipédia, « Queen and pawn versus queen endgame ») : Rg7/Df7/pion h5
contre Rc6/De2. Trait aux Blancs : gain ; trait aux Noirs : nulle — les DEUX
verdicts vérifiés à l'oracle. Une session précédente avait abandonné cette
finale (Botvinnik-Ravinsky 1944, dtm 98, inracontable) ; cette position de
manuel convertit en 21 coups, avec tout le programme dans la fenêtre :
l'abri roi-derrière-dame-et-pion (le « parapluie »), les échecs blancs qui
repositionnent la dame avec tempo, la promotion sous escorte, puis les DEUX
dames qui s'interposent tour à tour jusqu'à la liquidation.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-queen-pawn-vs-queen",
    "name": "Queen and Pawn vs Queen — the Umbrella",
    "side": "white",
    "kind": "endgame",
    "family": "queens",
    "level": "advanced",
    "rootFEN": "8/5QK1/2k5/7P/8/8/4q3/8 w - - 0 1",
    "summary": c(
        "La finale de dames par excellence : un pion de plus, une adversaire qui ne vivra que d'échecs. La course ne se gagne pas en fuyant les échecs mais en s'en abritant : le roi se glisse sous un « parapluie » fait de son pion et de sa dame, pendant que ses propres échecs à lui gagnent les tempos de la promotion. Position de manuel (Müller & Lamprecht) : trait aux Blancs gagné, trait aux Noirs nulle — un seul tempo sépare les deux mondes.",
        "The queen ending par excellence: one extra pawn, an opponent who will live on checks alone. The race is not won by fleeing the checks but by sheltering from them: the king slips under an \"umbrella\" made of its own pawn and queen, while White's own checks earn the tempi for promotion. A textbook position (Müller & Lamprecht): White to move wins, Black to move draws — a single tempo separates the two worlds.",
    ),
    "lines": [
        {
            "chapter": {"id": "umbrella", "title": c("Le parapluie, la promotion sous escorte, la liquidation", "The umbrella, the escorted promotion, the liquidation")},
            "moves": [
                {"san": "h6",
                 "comment": c("Le pion d'abord — la conversion la plus rapide de douze coups (vérifié : deux autres coups gagnent aussi, mais en 32 et 65 coups). En finale de dames, le pion passé est le seul argument : tout le reste n'est que gestion des échecs adverses.",
                              "The pawn first — the fastest conversion by twelve moves (verified: two other moves also win, but in 32 and 65 moves). In a queen ending the passed pawn is the only argument: everything else is just managing the enemy checks."),
                 "critical": True},
                {"san": "Kc5",
                 "comment": c("La meilleure défense : le roi noir accourt — une dame seule ne fait pas un perpétuel, il lui faut son roi pour resserrer le filet.",
                              "The best defence: the black king rushes over — a lone queen cannot deliver perpetual check, it needs its king to tighten the net.")},
                "h7",
                {"san": "Qg2+",
                 "comment": c("L'orage commence. Comptez les échecs noirs à partir d'ici : il n'y en aura que deux avant la panne sèche.",
                              "The storm begins. Count Black's checks from here: there will be only two before the well runs dry.")},
                {"san": "Qg6",
                 "comment": c("Première toile du parapluie : la dame s'interpose sur la colonne g ET vient monter la garde à côté du pion h7. Un seul coup, deux fonctions — c'est la marque des bons coups de finale de dames.",
                              "The first canvas of the umbrella: the queen interposes on the g-file AND takes up guard beside the h7-pawn. One move, two jobs — the hallmark of good queen-ending moves."),
                 "critical": True},
                "Qb7+",
                {"san": "Kh6",
                 "comment": c("Le parapluie est ouvert : pion en h7 au-dessus, dame en g6 sur le flanc — le roi est au sec. Vérifiez chaque ligne vers h6 : toutes bouchées ou couvertes. C'est LA image à retenir de cette finale.",
                              "The umbrella is open: pawn on h7 overhead, queen on g6 at the flank — the king is in the dry. Check every line into h6: all blocked or covered. THE picture to remember from this ending."),
                 "critical": True},
                {"san": "Qb2",
                 "comment": c("Plus un seul échec au compteur — la dame noire se rabat sur la grande diagonale, dernier regard vers h8, la case de promotion.",
                              "Not a single check left — the black queen falls back to the long diagonal, a last glance at h8, the promotion square.")},
                {"san": "Qf5+",
                 "comment": c("À votre tour : les échecs BLANCS, eux, rapportent. Chacun déplace la dame vers son poste final en volant le trait.",
                              "Your turn: WHITE's checks, on the other hand, pay. Each one moves the queen towards its final post while stealing the tempo."),
                 "critical": True},
                "Kb4",
                {"san": "Qf8+",
                 "comment": c("Deuxième échec-tempo, et regardez la case d'arrivée : f8 contrôle h8 par la rangée. La promotion est désormais escortée — la diagonale b2-h8 de la dame noire ne suffira pas.",
                              "A second tempo-check, and look at the arrival square: f8 controls h8 along the rank. The promotion is now escorted — the black queen's b2-h8 diagonal will not be enough."),
                 "critical": True},
                "Kc4",
                {"san": "h8=Q",
                 "comment": c("Deux dames contre une. Il reste à survivre à la dernière rafale d'échecs — avec deux interpositions disponibles, c'est une simple formalité de technique.",
                              "Two queens against one. All that remains is to weather the final volley of checks — with two interpositions available, it is a simple matter of technique."),
                 "critical": True},
                "Qh2+",
                {"san": "Kg6",
                 "comment": c("Le roi redescend s'abriter entre ses deux dames — g6, h7, g8 : chaque pas reste sous couverture.",
                              "The king walks back into shelter between its two queens — g6, h7, g8: every step stays under cover.")},
                "Qg2+", "Kh7", "Qh1+", "Kg8", "Qg2+",
                {"san": "Qhg7",
                 "comment": c("Premier service de la nouvelle dame : s'interposer. Une dame de plus, c'est un bouclier de plus — les échecs noirs s'épuisent contre du matériel, plus contre le roi.",
                              "The new queen's first duty: interpose. An extra queen is an extra shield — Black's checks now wear out against material, no longer against the king."),
                 "critical": True},
                "Qd5+",
                {"san": "Qgf7",
                 "comment": c("Deuxième interposition — et celle-ci ne peut plus être contournée : toutes les lignes vers g8 passent par une dame blanche.",
                              "The second interposition — and this one cannot be sidestepped: every line into g8 runs through a white queen.")},
                {"san": "Qxf7+",
                 "comment": c("La défense n'a plus que le baroud d'honneur : reprendre une dame.",
                              "The defence is down to its last gesture: winning one queen back.")},
                {"san": "Kxf7",
                 "comment": c("…et il en reste une. Dame contre roi nu : le mat élémentaire, enseigné dans son propre cours. Retenez la mécanique en trois temps : le pion court, le roi s'abrite sous le parapluie, les échecs BLANCS paient la promotion.",
                              "…and one remains. Queen against bare king: the elementary mate, taught in its own course. Remember the three-part mechanism: the pawn runs, the king shelters under the umbrella, and WHITE's checks pay for the promotion."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "no-roof", "title": c("S'abriter avant d'avoir un toit", "Sheltering before there is a roof")},
            "moves": [
                {"san": "Kh6", "role": "trap",
                 "comment": c("Monter le parapluie AVANT d'envoyer le pion : le geste semble prudent, et il jette le gain (vérifié : la position retombe à nulle). Le toit du parapluie, c'est le pion en h7 — tant qu'il est en h5, le roi sort sous la pluie.",
                              "Raising the umbrella BEFORE sending the pawn: it looks prudent, and it throws the win away (verified: the position drops back to a draw). The umbrella's roof is the pawn on h7 — while it sits on h5, the king is stepping out into the rain."),
                 "critical": True},
                {"san": "Qe3+",
                 "comment": c("L'averse, immédiatement — la diagonale e3-h6 est grande ouverte, aucune toile pour la fermer.",
                              "The downpour, immediately — the e3-h6 diagonal is wide open, with no canvas to close it."),
                 "critical": True},
                "Kh7",
                {"san": "Qh3",
                 "comment": c("Et le coup le plus élégant de la défense : pas un échec — un CLOUAGE. Le pion h5 est épinglé contre son roi, gelé pour toujours ; tout dégagement du roi rouvre les échecs. La nulle est scellée : le parapluie sans toit ne protège personne.",
                              "And the defence's most elegant move: not a check — a PIN. The h5-pawn is nailed against its own king, frozen for good; any king move to unpin walks back into the checks. The draw is sealed: an umbrella without a roof shelters no one."),
                 "critical": True},
            ],
        },
    ],
}
