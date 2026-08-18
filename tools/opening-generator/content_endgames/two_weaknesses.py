# -*- coding: utf-8 -*-
"""Le principe des deux faiblesses — la règle de Capablanca.

Position construite et vérifiée depuis zéro (aucune position de manuel
recopiée), pour illustrer un principe classique attribué à Capablanca : une
SEULE faiblesse peut toujours être défendue par un roi seul — il suffit de
se poster devant elle et d'attendre. Une SECONDE faiblesse, sur l'autre
aile, change tout : un roi ne peut être à deux endroits à la fois, et le
camp fort n'a plus qu'à choisir lequel des deux abandons il préfère
regarder. Racine à 5 pièces, chaque coup blanc tranché par l'oracle.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-theme-two-weaknesses",
    "name": "The Principle of Two Weaknesses",
    "side": "white",
    "kind": "endgame",
    "family": "themes",
    "level": "club",
    "rootFEN": "8/8/3k1p2/P7/8/4KP2/8/8 w - - 0 1",
    "summary": c(
        "C'est LE principe des deux faiblesses, la règle de Capablanca : un pion passé isolé à l'aile dame occupe le roi noir tout seul — il tiendrait éternellement s'il n'y avait que ça. Mais l'aile roi est une SECONDE faiblesse, et un roi ne peut en garder deux à la fois.",
        "This is THE principle of two weaknesses, Capablanca's rule: an isolated passed pawn on the queenside occupies Black's king all by itself — it would hold forever if that were the only issue. But the kingside is a SECOND weakness, and one king cannot guard two at once.",
    ),
    "lines": [
        {
            "chapter": {"id": "grab-the-passer", "title": c("Deux faiblesses, un seul roi", "Two weaknesses, one king")},
            "moves": [
                {"san": "Ke4",
                 "comment": c("Les Blancs ne se précipitent ni vers le pion a, ni vers l'aile roi : le roi attend de voir où le roi noir va s'engager avant de choisir son propre camp.",
                              "White doesn't rush toward the a-pawn or the kingside: the king waits to see where Black's king commits before choosing its own side."),
                 "critical": True},
                {"san": "Kc5",
                 "comment": c("Le roi noir fonce vers l'unique pion qu'il peut encore arrêter — la PREMIÈRE faiblesse mobilise déjà tout son roi, à elle seule.",
                              "Black's king rushes toward the only pawn it can still stop — the FIRST weakness already occupies its entire king, on its own.")},
                {"san": "f4",
                 "comment": c("Pendant que le roi noir est occupé à l'autre bout de l'échiquier, le pion f avance sans qu'aucune pièce noire ne puisse s'y opposer. La SECONDE faiblesse prend forme — et c'est elle, pas le pion a, qui va décider la partie.",
                              "While Black's king is busy at the other end of the board, the f-pawn advances with no black piece able to oppose it. The SECOND weakness takes shape — and it, not the a-pawn, is what will decide the game."),
                 "critical": True},
                {"san": "Kb5",
                 "comment": c("Rien d'autre à faire : le roi noir doit poursuivre sa route vers a5.",
                              "Nothing else to do: Black's king must continue its journey toward a5.")},
                {"san": "Kf5",
                 "comment": c("Le roi blanc rejoint lui aussi SA faiblesse — pendant que les Noirs sont allés chercher la leur à l'autre bout de l'échiquier.",
                              "White's king reaches ITS weakness too — while Black went to fetch theirs at the far end of the board."),
                 "critical": True},
                {"san": "Kxa5",
                 "comment": c("Le pion tombe — mais c'est un marché de dupes : en l'attrapant, le roi noir s'est banni à quatre colonnes de tout le reste.",
                              "The pawn falls — but it's a fool's bargain: in grabbing it, Black's king has banished itself four files from everything else.")},
                {"san": "Kxf6",
                 "comment": c("LE point de la leçon : le roi blanc croque à son tour, et le pion f survivant n'a plus personne pour l'arrêter — le roi noir est bien trop loin. Un seul roi ne peut jamais garder deux faiblesses en même temps : exactement la règle de Capablanca.",
                              "THE point of the lesson: White's king captures in turn, and the surviving f-pawn has no one left to stop it — Black's king is far too distant. One king can never guard two weaknesses at once: exactly Capablanca's rule."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "guard-the-kingside", "title": c("Garder l'autre faiblesse ? L'autre tombe", "Guard the other weakness instead? The other one falls")},
            "moves": [
                "Ke4",
                {"san": "Ke6",
                 "comment": c("Cette fois le roi noir choisit l'AUTRE faiblesse : il reste garder son pion f, abandonnant le pion a à lui-même.",
                              "This time Black's king picks the OTHER weakness: it stays to guard its f-pawn, leaving the a-pawn to fend for itself."),
                 "critical": True},
                {"san": "a6",
                 "comment": c("Sans personne pour le gêner, le pion a fonce tout seul vers la promotion.",
                              "With no one to bother it, the a-pawn charges alone toward promotion."),
                 "critical": True},
                {"san": "Kd6",
                 "comment": c("Le roi noir se rue enfin vers lui — mais chaque camp ne peut être qu'à un seul endroit à la fois, et il part avec deux coups de retard.",
                              "Black's king finally rushes toward it — but each side can only be in one place at a time, and it starts two moves too late.")},
                "a7",
                {"san": "Kc5",
                 "comment": c("Trop tard de toute façon : il ne reste plus qu'une case avant la dame.",
                              "Too late regardless: only one square remains before the queen.")},
                {"san": "a8=Q",
                 "comment": c("La dame naît tranquillement. Deux faiblesses, un seul roi : quelle que soit celle qu'il choisit de garder, c'est toujours l'AUTRE qui décide la partie.",
                              "The queen is born in peace. Two weaknesses, one king: whichever one it chooses to guard, it is always the OTHER one that decides the game."),
                 "critical": True},
            ],
        },
    ],
}
