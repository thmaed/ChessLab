# -*- coding: utf-8 -*-
"""Deux cavaliers contre un pion — l'exception qui rend le mat possible.

Sourcé Rév. Horatio Bolton (1840) : deux cavaliers seuls ne peuvent JAMAIS
forcer mat contre un roi nu — mais un pion adverse change tout, car il
offre un coup de réserve qui évite le pat au bon moment. Racine à 5 pièces,
dtm 17, chaque coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-two-knights-vs-pawn",
    "name": "Two Knights vs Pawn",
    "side": "white",
    "kind": "endgame",
    "family": "knights",
    "level": "advanced",
    "rootFEN": "8/8/8/5K2/7k/7p/7N/7N w - - 0 1",
    "summary": c(
        "Deux cavaliers seuls contre un roi nu ne peuvent jamais forcer mat — le pat guette toujours. Mais si le camp faible a encore un pion, celui-ci peut fournir le coup de réserve qui évite le pat au bon moment, et le mat redevient possible.",
        "Two lone knights against a bare king can never force mate — stalemate always looms. But if the weaker side still has a pawn, it can supply the one spare move that avoids stalemate at just the right moment, and mate becomes possible again."),
    "lines": [
        {
            "chapter": {"id": "the-technique", "title": c("Bloquer le pion, resserrer le filet", "Blockade the pawn, tighten the net")},
            "moves": [
                {"san": "Nf2",
                 "comment": c("Un cavalier va bloquer le pion sur h3 — il ne doit plus jamais avancer, sous peine de priver le roi noir de son seul coup de réserve. L'autre cavalier et le roi blanc encerclent alors le roi noir sans jamais lui laisser le pat en offrande.",
                              "One knight goes to blockade the pawn on h3 — it must never advance again, or Black's king loses its only spare move. The other knight and White's king then close in on Black's king, never once offering stalemate."),
                 "critical": True},
                "Kg3",
                "Nfg4",
                "Kh4",
                {"san": "Kg6",
                 "comment": c("Le roi blanc s'approche à son tour — le cavalier de blocus reste sur place, immobile, pendant que tout le reste du dispositif se resserre.",
                              "White's king closes in too — the blockading knight stays put, motionless, while the rest of the setup tightens."),
                 "critical": True},
                "Kg3",
                "Kg5",
                "Kg2",
                "Kf4",
                "Kh1",
                "Kf3",
                "Kg1",
                "Kg3",
                "Kh1",
                {"san": "Nf3",
                 "comment": c("Le filet se referme : le roi noir n'a plus que h1 et le pion n'a plus que sa case de blocage.", "The net closes: Black's king has only h1 left, and the pawn has nowhere to go."),
                 "critical": True},
                {"san": "h2",
                 "comment": c("Forcé — et c'est précisément ce coup de réserve, gardé en poche depuis le début, qui permet enfin le mat : sans lui, ce serait pat.",
                              "Forced — and it's exactly this spare move, kept in reserve from the start, that finally allows mate: without it, this would be stalemate.")},
                {"san": "Nf2#",
                 "comment": c("Mat. Vérifié à l'oracle depuis la racine : dix-sept coups jusqu'au mat, et pas un pat en chemin.", "Mate. Verified from the root: seventeen moves to mate, and not a single stalemate along the way."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "wrong-plan", "title": c("Le roi avance trop tôt", "The king advances too soon")},
            "moves": [
                {"san": "Ke6", "role": "trap",
                 "comment": c("Semble logique — amener le roi blanc au combat sans attendre. Mais aucun cavalier n'est encore allé bloquer le pion, et sans ce blocage tout le plan s'effondre.",
                              "Seems logical — bring White's king into the fight without delay. But no knight has gone to blockade the pawn yet, and without that blockade the whole plan collapses."),
                 "critical": True},
                {"san": "Kg5",
                 "comment": c("Le roi noir s'échappe vers le pion, qui reste libre d'avancer ou d'être croqué selon les besoins de la défense — la case de blocus n'a jamais été prise, et la nulle tient.",
                              "Black's king escapes toward the pawn, which stays free to advance or be traded off as the defence needs — the blockading square was never taken, and the draw holds."),
                 "critical": True},
            ],
        },
    ],
}
