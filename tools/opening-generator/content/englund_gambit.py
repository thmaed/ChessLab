# -*- coding: utf-8 -*-
"""Gambit Englund (1.d4 e5) — répertoire NOIR.

Objectivement douteux, mais un piège de blitz célèbre : la chasse à b2 avec
…Db4+/…Dxb2. À jouer en connaissant la limite : si les Blancs défendent bien,
les Noirs restent un peu moins bien. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "englund-gambit",
    "name": "Englund Gambit",
    "side": "black",
    "level": "club",
    "eco": ["A40"],
    "summary": c(
        "Un pion offert d'entrée pour un jeu de pièges à l'aile dame. Douteux si les Blancs défendent précisément, mais mortel contre un adversaire non prévenu.",
        "A pawn offered right away for queenside trickery. Dubious against precise defence, but lethal against an unwarned opponent.",
    ),
    "lines": [
        {
            "chapter": {"id": "trap", "title": c("Chasse à b2 — …Db4+/…Dxb2", "The b2 hunt — …Qb4+/…Qxb2")},
            "moves": [
                "d4",
                {"san": "e5", "eco": "Englund Gambit",
                 "comment": c("Le gambit Englund : on offre e5 pour tendre des pièges à l'aile dame.",
                              "The Englund Gambit: offer e5 to set queenside traps.")},
                "dxe5", "Nc6", "Nf3", "Qe7", "Bf4", "Qb4+", "Bd2",
                {"san": "Qxb2", "critical": True,
                 "comment": c("On dévore b2 : gare au piège si les Blancs jouent sans soin.",
                              "Gobble b2: beware the trap if White plays carelessly.")},
                {"san": "Bc3", "role": "trap",
                 "comment": c("L'erreur qu'on attend : le fou défend b2 mais se met sur la même diagonale que la tour a1.",
                              "The mistake we're waiting for: the bishop defends b2 but steps onto the a1 rook's diagonal.")},
                "Bb4", "Qd2", "Bxc3",
                {"san": "Nxc3", "role": "trap",
                 "comment": c("Forcé : 8.Dxc3?? perd sur-le-champ par 8…Dc1 mat.",
                              "Forced: 8.Qxc3?? loses on the spot to 8…Qc1 mate.")},
                {"san": "Qxa1+", "critical": True,
                 "comment": c("La tour est en prise et RIEN ne la défend : on l'emporte avec échec. C'est tout le sel du piège.",
                              "The rook hangs and NOTHING defends it: we take it with check. That is the whole point of the trap.")},
                {"san": "Nd1",
                 "comment": c("Le seul blocage qui tienne — et la dame noire n'est pas piégée pour autant.",
                              "The only block that holds — and the black queen is not trapped for all that.")},
                {"san": "Qxa2",
                 "comment": c("Tour et deux pions pour rien : les Noirs gagnent.",
                              "A rook and two pawns for nothing: Black is winning.")},
            ],
        },
        {
            "chapter": {"id": "solid", "title": c("Refus solide — 3.Cf3", "Solid decline — 3.Nf3")},
            "moves": [
                "d4", "e5", "dxe5", "Nc6", "Nf3",
                {"san": "Qe7", "comment": c("Si les Blancs défendent tranquillement e5, mieux vaut viser sa récupération sans excès.",
                                            "If White defends e5 calmly, aim to regain it without overreaching.")},
                "Bf4", "Qb4+", "Nc3",
                {"san": "Qxf4", "critical": True,
                 "comment": c("Ici on récupère le pion f4, PAS b2 : 5…Dxb2 laisse les Blancs nettement mieux après Fd2.",
                              "Here we take back on f4, NOT b2: 5…Qxb2 leaves White clearly better after Bd2.")},
                {"san": "Nd5",
                 "comment": c("La fourchette à venir en c7 fait peur — elle ne rapporte qu'une tour perdue en a8.",
                              "The coming fork on c7 looks scary — it only wins a rook that gets stranded on a8.")},
                "Qe4", "Nxc7+", "Kd8",
                {"san": "Nxa8",
                 "comment": c("Le cavalier a8 est enfermé : …b6 et …Fb7 le récupèrent. Matériel équilibré, position jouable.",
                              "The a8 knight is trapped: …b6 and …Bb7 round it up. Material is level and the position playable.")},
            ],
        },
    ],
}
