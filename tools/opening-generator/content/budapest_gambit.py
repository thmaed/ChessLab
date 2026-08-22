# -*- coding: utf-8 -*-
"""Gambit Budapest (1.d4 Cf6 2.c4 e5) — NOIR.

On offre e5 pour un développement rapide et des pièces actives ; le cavalier
récupère le pion depuis g4 ou e4. Arbre : Rubinstein 3.dxe5 Cg4 4.Cf3, la
critique 4.Ff4, et la Fajarowicz 3…Ce4. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "budapest-gambit",
    "name": "Budapest Gambit",
    "side": "black",
    "level": "club",
    "eco": ["A51", "A52"],
    "summary": c(
        "Un gambit sain et joueur : on rend e5 tout de suite mais on obtient des pièces actives, des cavaliers baladeurs et des pièges tactiques bien réels. Idéal en club.",
        "A sound, fun gambit: give e5 back at once but get active pieces, hopping knights and very real tactical traps. Ideal at club level.",
    ),
    "lines": [
        # 1) Rubinstein — 3.dxe5 Cg4 4.Cf3
        {
            "chapter": {"id": "rubinstein", "title": c("Rubinstein — 3.dxe5 Cg4 4.Cf3", "Rubinstein — 3.dxe5 Ng4 4.Nf3")},
            "moves": [
                "d4", "Nf6", "c4",
                {"san": "e5", "eco": "Budapest Gambit",
                 "comment": c("Le gambit Budapest : on offre e5 pour un développement rapide et un jeu de pièces actif.",
                              "The Budapest Gambit: offer e5 for fast development and active piece play.")},
                "dxe5",
                {"san": "Ng4", "comment": c("Le cavalier file en g4 : il reprendra e5 et vise déjà f2/e3.",
                                            "The knight leaps to g4: it will regain e5 and already eyes f2/e3.")},
                "Nf3", "Bc5", "e3", "Nc6", "Be2", "Ngxe5", "Nxe5", "Nxe5", "O-O", "O-O",
            ],
        },
        # 2) 4.Ff4 (critique)
        {
            "chapter": {"id": "bf4", "title": c("4.Ff4 (critique)", "4.Bf4 (critical)")},
            "moves": [
                "d4", "Nf6", "c4", "e5", "dxe5", "Ng4",
                {"san": "Bf4", "comment": c("Les Blancs défendent e5 par Ff4 ; les Noirs clouent par …Fb4+ et récupèrent le pion.",
                                            "White holds e5 with Bf4; Black pins with …Bb4+ and regains the pawn.")},
                "Nc6", "Nf3", "Bb4+", "Nbd2", "Qe7", "a3", "Ngxe5", "Nxe5", "Nxe5",
            ],
        },
        # 3) Fajarowicz — 3…Ce4
        {
            "chapter": {"id": "fajarowicz", "title": c("Fajarowicz — 3…Ce4", "Fajarowicz — 3…Ne4")},
            "moves": [
                "d4", "Nf6", "c4", "e5", "dxe5",
                {"san": "Ne4", "comment": c("La Fajarowicz : le cavalier saute en e4 au lieu de g4, pour un jeu plus positionnel et piégeux.",
                                            "The Fajarowicz: the knight jumps to e4 instead of g4, for more positional, trap-laden play.")},
                "Nd2", "Nc5", "Ngf3", "Nc6", "g3", "Qe7", "Bg2", "g6",
            ],
        },

        # ── Quand le gambit n'est pas possible (16/08) ────────────────────────
        #
        # Le Budapest EST 1.d4 Cf6 2.c4 e5. Sans c4, il n'existe pas : le
        # signaler vaut mieux que laisser l'élève chercher un coup qui n'a plus
        # de sens.
        {
            "chapter": {"id": "no-c4", "title": c("Si les Blancs ne jouent pas c4", "If White doesn't play c4")},
            "moves": [
                "d4", "Nf6",
                {"san": "Nf3",
                 "comment": c("Pas de c4, donc pas de Budapest : …e5 ne serait plus un gambit mais une faute. On développe normalement et l'on attend c4.",
                              "No c4, so no Budapest: …e5 would no longer be a gambit but a mistake. We develop normally and wait for c4."),
                 "critical": True},
                "e6", "c4",
                {"san": "d5",
                 "comment": c("c4 est arrivé trop tard pour le gambit — on est dans un Gambit Dame refusé, position saine et parfaitement jouable.",
                              "c4 came too late for the gambit — we're in a Queen's Gambit Declined, a sound and perfectly playable position.")},
                "Bg5", "dxc4", "Qa4+", "Nbd7",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,66). Répertoire NOIR :
        # les trous sont des coups BLANCS, et les deux plus gros sont des refus
        # d'entrer dans le gambit. ───────────────────────────────────────────
        {
            "chapter": {"id": "vs-london", "title": c("Si les Blancs jouent la London", "If White plays the London")},
            "moves": [
                "d4", "Nf6",
                {"san": "Bf4",
                 "comment": c("Sans c4, il n'y a pas de Budapest : …e5 n'attaquerait rien et perdrait un pion. Un Blanc sur six joue la London, et le cours ne prévoyait que c4 et Cf3.",
                              "Without c4 there is no Budapest: …e5 would attack nothing and drop a pawn. One White player in six plays the London, and the course only planned for c4 and Nf3."),
                 "critical": True},
                {"san": "e6",
                 "comment": c("On bascule sur un jeu sain plutôt que de forcer un gambit qui n'existe pas. Un répertoire de gambit doit dire ce qu'on joue quand le gambit n'est pas disponible.",
                              "We switch to sound play rather than force a gambit that is not there. A gambit repertoire must say what to play when the gambit is unavailable."),
                 "critical": True},
                "e3", "d5", "Nf3", "c5", "c3", "Bd6",
                {"san": "Bg3",
                 "comment": c("Les Blancs évitent l'échange des fous. Nous avons obtenu ce qui compte : le centre partagé et un développement sans problème.",
                              "White avoids the bishop trade. We have what matters: a shared centre and untroubled development.")},
                "O-O", "Nbd2",
            ],
        },
        {
            "chapter": {"id": "fajarowicz", "title": c("Fajarowicz — 3…Ce4", "Fajarowicz — 3…Ne4")},
            "moves": [
                "d4", "Nf6", "c4", "e5", "dxe5", "Ne4",
                {"san": "Nf3",
                 "comment": c("Le développement simple, joué quatre fois sur dix, et le cours ne prévoyait que Cd2. C'est la réponse qui met le plus en difficulté la variante Fajarowicz.",
                              "Simple development, played four times in ten, and the course only planned for Nd2. It is the reply that troubles the Fajarowicz most."),
                 "critical": True},
                {"san": "Bb4+",
                 "comment": c("L'échec est notre seule ressource active : il faut développer avec des menaces, sans quoi le pion e5 reste tranquillement aux Blancs.",
                              "The check is our only active resource: we must develop with threats, otherwise White simply keeps the e5 pawn."),
                 "critical": True},
                "Bd2", "Nxd2", "Nbxd2", "Be7", "e3", "d6", "exd6", "Qxd6", "Qc2",
            ],
        },
        {
            "chapter": {"id": "declined", "title": c("Gambit refusé — 3.d5", "Declined — 3.d5")},
            "moves": [
                "d4", "Nf6", "c4", "e5",
                {"san": "d5",
                 "comment": c("Plus d'un Blanc sur cinq ferme au lieu de prendre, et le cours ne prévoyait QUE la prise. Le gambit est refusé : la position devient une Est-Indienne à structure fermée.",
                              "More than one White player in five closes instead of taking, and the course only planned for the capture. The gambit is declined: the position becomes a closed King's Indian structure."),
                 "critical": True},
                {"san": "Bb4+",
                 "comment": c("L'échec avant tout : il force les Blancs à préciser, et notre fou trouve une case active avant que la position ne se referme sur lui.",
                              "The check first: it forces White to commit, and our bishop finds an active square before the position closes around it."),
                 "critical": True},
                "Bd2", "a5", "e3", "d6", "Bd3", "c6", "dxc6", "bxc6", "Ne2",
            ],
        },
        {
            "chapter": {"id": "declined", "title": c("Gambit refusé — 3.d5", "Declined — 3.d5")},
            "moves": [
                "d4", "Nf6", "c4", "e5",
                {"san": "Nc3",
                 "comment": c("Un Blanc sur neuf développe sans trancher, et le cours ne l'avait pas prévu. C'est le coup le plus flexible — et le moins engageant.",
                              "One White player in nine develops without committing, and the course had not planned for it. The most flexible move — and the least committal."),
                 "critical": True},
                {"san": "exd4",
                 "comment": c("On prend puisqu'ils ne l'ont pas fait : notre pion disparaît du centre, mais leur dame devra venir le reprendre et se fera chasser.",
                              "We take since they did not: our centre pawn goes, but their queen has to come and collect it, and she will be chased."),
                 "critical": True},
                "Qxd4", "Nc6", "Qd1", "Bb4", "Bd2", "O-O", "e3", "Re8", "Nf3",
            ],
        },
        {
            "chapter": {"id": "budapest-main", "title": c("Budapest — ligne principale", "Budapest — main line")},
            "moves": [
                "d4", "Nf6", "c4", "e5", "dxe5", "Ng4", "Nf3", "Bc5", "e3", "Nc6",
                {"san": "Nc3",
                 "comment": c("Près de trois Blancs sur dix développent le cavalier plutôt que de jouer Fe2, et le cours ne voyait que Fe2.",
                              "Nearly three White players in ten develop the knight rather than play Be2, and the course only saw Be2."),
                 "critical": True},
                {"san": "O-O",
                 "comment": c("Le roi à l'abri avant de récupérer le pion. Dans le Budapest, la précipitation coûte plus cher que le pion lui-même : c'est l'activité des pièces qui paie, pas le matériel.",
                              "King to safety before collecting the pawn. In the Budapest, hurrying costs more than the pawn itself: piece activity pays, not material."),
                 "critical": True},
                "a3", "Re8", "b4", "Bf8", "Be2", "Ncxe5", "Nxe5", "Nxe5", "f4",
            ],
        },
    ],
}
