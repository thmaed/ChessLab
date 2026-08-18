# -*- coding: utf-8 -*-
"""Fou contre cavalier — la longue diagonale contre la case bloquée.

Sourcé Wikipédia (« Finale fou contre cavalier ») : l'étude de R. N. W. Hall
(1988) où un fou et un pion l'emportent sur un cavalier seul grâce à un
double avantage — la portée du fou sur la longue diagonale et le roi qui
garde le pion sans jamais le lâcher. Racine à 5 pièces, chaque coup blanc
tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-bishop-vs-knight-zugzwang",
    "name": "Bishop vs Knight — the Long Diagonal",
    "side": "white",
    "kind": "endgame",
    "family": "bishops",
    "level": "advanced",
    "rootFEN": "4n3/3K4/1kP5/8/8/8/1B6/8 w - - 0 1",
    "summary": c(
        "Étude de Hall (1988) : le pion c6 est déjà à un pas de la promotion, gardé par le roi blanc. Le fou n'a plus qu'à priver le cavalier de toute case utile — la longue diagonale fait le travail qu'aucun cavalier ne peut copier.",
        "Hall's study (1988): the c6 pawn is already one step from promotion, guarded by White's king. The bishop only has to strip the knight of every useful square — the long diagonal does what no knight can match.",
    ),
    "lines": [
        {
            "chapter": {"id": "main-line", "title": c("La manoeuvre qui étouffe le cavalier", "The manoeuvre that suffocates the knight")},
            "moves": [
                {"san": "Bc3",
                 "comment": c("Pas de hâte : le roi reste sur d7, où il garde le pion c6. Le fou seul part à la chasse — sur la longue diagonale a1-h8, il va priver le cavalier et le roi noir de cases, un coup à la fois.",
                              "No rush: the king stays on d7, guarding c6. The bishop alone goes hunting — on the long a1-h8 diagonal it will strip the knight and the black king of squares, one move at a time."),
                 "critical": True},
                {"san": "Kc5", "comment": c("Le roi noir cherche de l'air ; il n'y en a pas beaucoup.", "Black's king looks for air; there isn't much.")},
                {"san": "Bb4+",
                 "comment": c("Échec et gain de temps — le roi noir est repoussé plus loin du pion qu'il ne pourra jamais rattraper tant que d7 tient bon.",
                              "Check and a tempo — Black's king is pushed further from the pawn it can never catch while d7 holds."),
                 "critical": True},
                "Kb5",
                {"san": "Be7", "comment": c("Le fou change de diagonale sans jamais quitter son but : couper toute route de retour.", "The bishop switches diagonals without ever losing its purpose: cutting off every way back.")},
                "Kb6",
                {"san": "Bh4",
                 "comment": c("Manoeuvre patiente — le fou vise maintenant la diagonale g5-d8, celle qui va enfermer le cavalier pour de bon.",
                              "Patient manoeuvring — the bishop now aims at the g5-d8 diagonal, the one that will lock the knight in for good."),
                 "critical": True},
                "Kb5",
                "Bg5",
                "Kc5",
                {"san": "Be3+",
                 "comment": c("Encore un échec pour gagner un temps : le roi noir n'a plus de zone sûre où camper.", "Another check to win a tempo: Black's king has no safe zone left to camp in."),
                 "critical": True},
                "Kd5",
                {"san": "Bd4",
                 "comment": c("Le filet se referme : le roi noir n'approchera plus jamais de c6, et le cavalier doit maintenant bouger vers une case qui ne le sert à rien. C'est le zugzwang que toute la manoeuvre préparait.",
                              "The net closes: Black's king will never approach c6 again, and the knight must now move to a square that helps nothing. This is the zugzwang the whole manoeuvre was building toward."),
                 "critical": True},
                "Nd6",
                {"san": "c7",
                 "comment": c("Enfin ! Le pion avance seulement maintenant qu'il est réellement en sécurité — gardé par le roi, et le cavalier trop loin pour intervenir à temps.",
                              "At last! The pawn only advances now that it is genuinely safe — guarded by the king, with the knight too far away to intervene in time."),
                 "critical": True},
                "Nb5",
                {"san": "c8=Q",
                 "comment": c("Promotion. La technique dame contre cavalier qui suit est un exercice à part — mais la partie difficile, libérer le pion, est faite.",
                              "Promotion. The queen-versus-knight technique that follows is its own exercise — but the hard part, freeing the pawn, is done."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "greedy-king", "title": c("Le piège du gain gratuit", "The trap of the free capture")},
            "moves": [
                {"san": "Kxe8", "role": "trap",
                 "comment": c("Tentant : prendre le cavalier qui semble à portée. Mais le roi blanc abandonne alors la garde du pion c6, et le roi noir — déjà juste à côté — le reprend aussitôt. Fou seul contre roi : nulle, matériel insuffisant.",
                              "Tempting: grab the knight that looks within reach. But White's king then abandons its watch over c6, and Black's king — already right next to it — takes it back at once. Lone bishop versus king: a draw, insufficient material."),
                 "critical": True},
                {"san": "Kxc6",
                 "comment": c("Le pion tombe, et avec lui toute la victoire. C'est la leçon : dans ces finales, la pièce adverse offerte compte moins que le pion qu'on doit escorter.",
                              "The pawn falls, and the win with it. That's the lesson: in these endings, the offered enemy piece matters less than the pawn you have to escort."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "push-too-soon", "title": c("Pousser le pion tout de suite ?", "Push the pawn right away?")},
            "moves": [
                {"san": "c7", "role": "trap",
                 "comment": c("Le pion semble mûr pour avancer — mais le roi noir est encore assez près pour réagir, et le cavalier veille sur c7 depuis e8.",
                              "The pawn looks ripe to advance — but Black's king is still close enough to react, and the knight watches c7 from e8."),
                 "critical": True},
                {"san": "Nxc7",
                 "comment": c("Le cavalier avale le pion : plus rien à gagner. Le fou n'avait pas encore fini son travail de préparation — pousser trop tôt annule tout.",
                              "The knight swallows the pawn: nothing left to win. The bishop hadn't finished its preparatory work yet — pushing too soon undoes everything."),
                 "critical": True},
            ],
        },
    ],
}
