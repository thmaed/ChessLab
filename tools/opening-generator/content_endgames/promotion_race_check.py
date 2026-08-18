# -*- coding: utf-8 -*-
"""La course à la promotion — le premier échec rafle tout.

Position construite et vérifiée depuis zéro : course de pions pure,
trois temps contre trois temps — le décompte naïf annonce deux dames et
la nulle. L'oracle raconte autre chose : UN SEUL des huit coups blancs
gagne (la poussée), quatre coups de roi font nulle et trois PERDENT.
Tout tient à la géométrie des cases de promotion : le roi noir campe sur
la grande diagonale a8-h1, la promotion blanche tombe donc avec ÉCHEC —
et le pion g2 attend son tour sur la même diagonale. Le piège inverse est
symétrique : un seul tempo de roi « d'escorte », et c'est la promotion
NOIRE qui arrive avec échec sur l'autre diagonale (g1-b6). Ma première
racine pour ce thème était fausse (le roi noir, trop proche, rattrapait
le pion a tout en gardant sa course) — l'oracle l'a rejetée avant
publication, celle-ci est la version corrigée.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-promotion-race-check",
    "name": "The Promotion Race and the First Check",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "club",
    "rootFEN": "8/8/8/PK6/4k1p1/8/8/8 w - - 0 1",
    "summary": c(
        "Course de pions pure : trois temps chacun, les deux pions promeuvent — nulle, dit le décompte. Faux : le roi noir est posté sur la grande diagonale a8-h1, celle qui relie les DEUX cases de promotion. La dame blanche naît donc avec échec, et dévore le pion g2 sur cette même diagonale le coup d'après. Compter les temps ne suffit jamais : regardez toujours ce que la nouvelle dame verra depuis sa case de naissance.",
        "A pure pawn race: three tempi each, both pawns promote — a draw, says the count. Wrong: the black king stands on the long a8-h1 diagonal, the one connecting BOTH promotion squares. So White's queen is born with check, and devours the g2-pawn along that very diagonal a move later. Counting tempi is never enough: always look at what the new queen will see from its birth square.",
    ),
    "lines": [
        {
            "chapter": {"id": "race", "title": c("Pousser, pousser, promouvoir avec échec", "Push, push, promote with check")},
            "moves": [
                {"san": "a6",
                 "comment": c("L'UNIQUE coup gagnant sur huit (vérifié : quatre coups de roi font nulle, trois perdent). Dans une course pure, chaque tempo de roi est un tempo volé à la course — et le roi b5 fait déjà tout son travail sans bouger : il couvre c6, la case dont le roi noir aurait besoin pour rattraper le pion.",
                              "The ONLY winning move out of eight (verified: four king moves draw, three lose). In a pure race every king tempo is a tempo stolen from the race — and the b5-king already does its whole job standing still: it covers c6, the square the black king would need to catch the pawn."),
                 "critical": True},
                {"san": "g3",
                 "comment": c("Les Noirs courent aussi — c'est leur meilleure défense selon la tablebase. Trois temps contre trois : sur le papier, personne ne gagne cette course.",
                              "Black races too — the tablebase's best defence. Three tempi against three: on paper, nobody wins this race.")},
                "a7", "g2",
                {"san": "a8=Q+",
                 "comment": c("La promotion tombe avec ÉCHEC — et toute la finale était décidée là, dès le départ : le roi noir est posté sur la grande diagonale a8-h1, celle qui relie les deux cases de promotion. Comptez les temps, puis vérifiez TOUJOURS cette géométrie-là.",
                              "The promotion lands with CHECK — and the whole ending was decided right there, from the start: the black king stands on the long a8-h1 diagonal, the one linking the two promotion squares. Count the tempi, then ALWAYS check that geometry."),
                 "critical": True},
                {"san": "Ke3",
                 "comment": c("Le roi doit parer l'échec — remarquez qu'aucune case de fuite ne reste sur la diagonale : la dame qui donne l'échec balaie elle-même toutes ces cases. Le pion g2 attend, à un pas du but, un pas qu'il ne fera jamais.",
                              "The king must answer the check — note that no escape square remains on the diagonal: the checking queen sweeps every one of them herself. The g2-pawn waits, one step from glory, a step it will never take.")},
                {"san": "Qxg2",
                 "comment": c("Le même trait de dame qui donnait l'échec ramasse le pion : g2 est SUR la diagonale a8-h1. Un échec = un tempo = toute la course. La suite est le mat de la dame, enseigné dans son propre cours.",
                              "The same queen's line that delivered the check now scoops up the pawn: g2 sits ON the a8-h1 diagonal. One check = one tempo = the whole race. What follows is the queen mate, taught in its own course."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "escort", "title": c("Un seul tempo d'escorte — et l'échec change de camp", "One escorting tempo — and the check changes sides")},
            "moves": [
                {"san": "Kb6", "role": "trap",
                 "comment": c("Escorter son pion avec le roi : le bon réflexe des finales de dames… et ici, la faute qui jette le gain (vérifié : la position passe de gagnée à nulle). La course n'attend personne.",
                              "Escorting the pawn with the king: the right instinct in queen endings… and here, the mistake that throws the win away (verified: the position drops from won to drawn). The race waits for no one."),
                 "critical": True},
                "g3", "a6", "g2", "a7",
                {"san": "g1=Q+",
                 "comment": c("Le miroir exact de la ligne principale : c'est la promotion NOIRE qui tombe avec échec — le roi blanc s'est placé lui-même sur la diagonale g1-a7 en jouant Rb6. Le tempo « perdu » ne s'est pas dissous : il a changé de propriétaire.",
                              "The exact mirror of the main line: it is BLACK's promotion that lands with check — the white king put itself on the g1-a7 diagonal by playing Kb6. The \"lost\" tempo did not dissolve: it changed owners."),
                 "critical": True},
                "Ka6",
                {"san": "Qxa7+",
                 "comment": c("Et la dame toute neuve s'offre même le luxe de rendre le matériel : elle achète le pion a7 et la nulle la plus propre qui soit.",
                              "And the brand-new queen even affords the luxury of giving the material back: it buys the a7-pawn and the cleanest draw there is."),
                 "critical": True},
                {"san": "Kxa7",
                 "comment": c("Deux rois nus. Toute l'histoire des courses de pions tient dans ce diptyque : un tempo d'écart, deux diagonales — et l'échec décide, jamais le décompte seul.",
                              "Two bare kings. The whole story of pawn races fits in this diptych: one tempo's difference, two diagonals — and the check decides, never the count alone."),
                 "critical": True},
            ],
        },
    ],
}
