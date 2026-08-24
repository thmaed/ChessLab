# -*- coding: utf-8 -*-
"""Pion passé éloigné — le leurre qui ouvre l'autre aile.

La technique classique des finales de pions sur les deux ailes : un pion passé
loin du reste force le roi adverse à s'en occuper seul, pendant que le roi
attaquant traverse l'échiquier pour croquer tout le reste.

## Le pion était en a5, il est en a4 (24/08/2026)

La version d'origine plaçait le pion sur a5 — et la leçon était FAUSSE, non
pas dans ses coups (l'audit tablebase les validait tous) mais dans sa
prémisse. Preuve par la table, les pions de l'aile roi retirés :

    8/4k3/8/P3K3/8/8/8/8 w  (pion a5, seul)  →  GAIN
    8/4k3/8/4K3/P7/8/8/8 w  (pion a4, seul)  →  NULLE

Depuis a5 le pion promeut tout seul : le roi noir, parti d'e7, arrive un temps
trop tard. Le « leurre », la traversée du roi, l'aile roi — tout cela était
décoratif, la position se gagnait par 1.a6, 2.a7, 3.a8=D. Le cours enseignait
d'ailleurs une défense noire (2…Rc7) qui permettait la promotion immédiate, et
un coup blanc (3.Re6) qui l'ignorait.

Depuis a4, le roi noir arrête le pion. Le gain ne peut donc venir QUE du
thème : le pion se donne, et le roi traverse pendant ce temps.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-outside-passed-pawn",
    "name": "The Outside Passed Pawn",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/4k1pp/8/4K3/P7/8/6PP/8 w - - 0 1",
    "summary": c(
        "Un pion passé isolé à l'opposé du reste ne sert pas à promouvoir : il sert de LEURRE, et il se sacrifie. Le roi noir doit aller le chercher tout seul ; pendant ces quatre temps-là, le roi blanc traverse l'échiquier et croque l'aile roi entière.",
        "A passed pawn isolated on the far side isn't there to promote: it is a DECOY, and it gets sacrificed. Black's king must go and fetch it alone; during those four tempi, White's king crosses the board and eats the whole kingside.",
    ),
    "lines": [
        {
            "chapter": {"id": "the-decoy", "title": c("Le pion se donne, le roi traverse", "The pawn gives itself up, the king crosses over")},
            "moves": [
                {"san": "a5",
                 "comment": c("Le pion s'élance seul, à l'opposé de tout le reste. Il n'ira pas à dame — le roi noir a juste le temps de l'arrêter — et ce n'est pas ce qu'on lui demande : on lui demande d'ATTIRER.",
                              "The pawn sets off alone, on the opposite side from everything else. It will not queen — Black's king has just enough time — and that is not its job: its job is to ATTRACT."),
                 "critical": True},
                {"san": "Kd7", "comment": c("Le roi noir part en voyage. Il n'a pas le choix : laisser le pion filer perdrait sur-le-champ.",
                                            "Black's king sets off. He has no choice: letting the pawn run loses on the spot.")},
                "a6",
                {"san": "Kc6", "comment": c("Deux cases parcourues, et le roi noir est déjà à cinq colonnes de ses propres pions.",
                                            "Two squares travelled, and Black's king is already five files from his own pawns.")},
                {"san": "a7",
                 "comment": c("Le pion va aussi loin qu'il peut. Il est perdu, et c'est prévu : chaque case qu'il gagne est un temps que le roi noir devra dépenser pour revenir.",
                              "The pawn goes as far as it can. It is lost, and that is the plan: every square it gains is a tempo Black's king will have to spend coming back."),
                 "critical": True},
                {"san": "Kb7", "comment": c("Le blocus. Le pion ne passera pas — mais le roi noir est désormais cloué dans le coin.",
                                            "The blockade. The pawn will not get through — but Black's king is now nailed to the corner.")},
                {"san": "Ke6",
                 "comment": c("LE moment. Le roi blanc n'attend pas que le pion tombe : il part, maintenant, pendant que l'autre roi est occupé. Noter qu'il ne peut pas passer par f6 — le pion g7 le contrôle — mais f7 lui est ouvert.",
                              "THE moment. White's king does not wait for the pawn to fall: he leaves NOW, while the other king is busy. Note he cannot go via f6 — the g7 pawn covers it — but f7 is open."),
                 "critical": True},
                {"san": "Kxa7", "comment": c("Le roi noir encaisse enfin son pion. Il lui aura coûté quatre temps, et la partie.",
                                             "Black's king finally collects the pawn. It will have cost him four tempi — and the game.")},
                "Kf7",
                "Kb6",
                {"san": "Kxg7",
                 "comment": c("Premier pion. Le roi noir est à six colonnes : il ne reviendra jamais.",
                              "First pawn. Black's king is six files away: he will never get back."),
                 "critical": True},
                "Kc5",
                {"san": "Kxh7",
                 "comment": c("Second pion, et deux pions liés escortés par leur roi contre un roi seul. Le leurre a tout fait : il n'a jamais menacé d'aller à dame, il a seulement acheté quatre temps — exactement ce qu'il fallait.",
                              "Second pawn, and two connected pawns escorted by their king against a bare king. The decoy did everything: it never threatened to queen, it merely bought four tempi — exactly what was needed."),
                 "critical": True},
            ],
        },
    ],
}
