# -*- coding: utf-8 -*-
"""Centurini, le gain — deux diagonales, dont une trop courte.

Le principe est sourcé (règles de Luigi Centurini, 1856, fou et pion contre
fou de même couleur) : le défenseur ne tient que si son fou dispose de DEUX
diagonales praticables vers la case de promotion. La position, elle, est
construite et vérifiée depuis zéro — aucune source en ligne consultée ce
soir ne donne les coordonnées exactes du gain historique (transcriptions
contradictoires, l'une avec des rois adjacents, illégale). Première
construction rejetée d'ailleurs par l'oracle : mon fou blanc en e1 prenait
le fou noir au premier coup — même défaut de pièce en prise déjà attrapé
deux fois dans cette campagne. Version corrigée : dtm 19, et la mécanique
célèbre sort toute seule de `derive_optimal` — interposition en b8 protégée
par le roi, retour du fou sur la grande diagonale, et la petite diagonale
n'a qu'une case utile (a7), propriété du roi blanc.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-centurini-deflection",
    "name": "Centurini — Two Diagonals, One Too Short",
    "side": "white",
    "kind": "endgame",
    "family": "bishops",
    "level": "advanced",
    "rootFEN": "8/K7/1P6/1k6/8/6b1/3B4/8 w - - 0 1",
    "summary": c(
        "Fou et pion contre fou de même couleur : la règle de Centurini (1856) dit que le défenseur tient si son fou dispose de deux diagonales vers la case de promotion — et qu'il perd si l'une des deux est trop courte. Ici la grande diagonale b8-h2 est saine, mais la petite (a7-b8) n'a qu'UNE case d'attaque, a7 — et le roi blanc va se l'approprier. Le plan en trois actes : occuper a7, s'interposer en b8, puis rafler la grande diagonale entière d'une seule case.",
        "Bishop and pawn versus bishop of the same colour: Centurini's rule (1856) says the defender holds if his bishop has two workable diagonals to the promotion square — and loses if one of the two is too short. Here the long b8-h2 diagonal is healthy, but the short one (a7-b8) has just ONE attacking square, a7 — and White's king is about to claim it. The plan in three acts: occupy a7, interpose on b8, then sweep the entire long diagonal from a single square.",
    ),
    "lines": [
        {
            "chapter": {"id": "deflection", "title": c("a7, b8, retour — le fou noir n'a plus de diagonale", "a7, b8, and back — the black bishop runs out of diagonals")},
            "moves": [
                {"san": "b7",
                 "comment": c("Le pion se fixe à un pas du but. À partir de maintenant, le fou noir est de garde à perpétuité sur la diagonale b8-h2 — le cours entier consiste à rendre cette garde impossible.",
                              "The pawn plants itself one step from glory. From now on the black bishop stands eternal guard on the b8-h2 diagonal — the whole course is about making that guard impossible."),
                 "critical": True},
                {"san": "Kc4",
                 "comment": c("Le roi noir attaquait le pion — la poussée l'a dépassé. Selon la règle de Centurini, un roi défenseur DERRIÈRE le pion ne participe plus : le fou doit tenir seul.",
                              "The black king was attacking the pawn — the push walked right past it. By Centurini's rule, a defending king BEHIND the pawn no longer takes part: the bishop must hold alone.")},
                {"san": "Ka8",
                 "comment": c("Le coup à comprendre avant tous les autres : sur la petite diagonale a7-b8, UNE seule case attaque b8 — a7. Le roi s'en empare pour toujours, et protégera au passage l'interposition qui vient. La petite diagonale vient de mourir.",
                              "The move to understand before all others: on the short a7-b8 diagonal, exactly ONE square attacks b8 — a7. The king seizes it for good, and will incidentally protect the coming interposition. The short diagonal just died."),
                 "critical": True},
                "Kd3",
                {"san": "Be1",
                 "comment": c("Le fou blanc entame son grand voyage vers a7 — par l'autre bout de l'échiquier. Les Noirs ne peuvent qu'attendre : leur roi est hors jeu, leur fou est de garde.",
                              "The white bishop sets out on its grand tour to a7 — via the far end of the board. Black can only wait: their king is out of play, their bishop is on guard duty."),
                 "critical": True},
                "Bh2", "Bf2", "Bf4",
                {"san": "Ba7",
                 "comment": c("Première étape accomplie : le fou est posté sur la petite diagonale, sous la protection du roi, prêt à s'interposer en b8. Le fou noir, lui, fait les cent pas — il n'a nulle part où aller.",
                              "First stage complete: the bishop is posted on the short diagonal, under the king's protection, ready to interpose on b8. The black bishop, meanwhile, paces up and down — it has nowhere to go."),
                 "critical": True},
                "Bh2",
                {"san": "Bb8",
                 "comment": c("L'interposition, protégée par le roi : la porte b8 claque au nez du fou noir. Sa grande diagonale ne mène plus qu'au dos d'un fou blanc intouchable.",
                              "The interposition, protected by the king: the b8 door slams in the black bishop's face. Its long diagonal now leads only to the back of an untouchable white bishop."),
                 "critical": True},
                {"san": "Bg1",
                 "comment": c("L'unique ressource : changer de diagonale — viser a7, la seule case de la petite diagonale qui attaque b8. Un seul coup de fou l'y amènerait… si la case n'appartenait pas déjà au roi blanc.",
                              "The only resource: switch diagonals — aim for a7, the short diagonal's one square that attacks b8. A single bishop move would get there… if the square did not already belong to the white king.")},
                {"san": "Bg3",
                 "comment": c("Le chef-d'œuvre tranquille de la manœuvre : mission accomplie en b8, le fou blanc redescend occuper la GRANDE diagonale — et regardez : depuis g3, il couvre à lui seul h2, f4, e5, d6 et c7, toutes les cases de réentrée. Une diagonale morte de chaque côté : c'est la domination.",
                              "The quiet masterpiece of the manoeuvre: mission accomplished on b8, the white bishop drops back to occupy the LONG diagonal — and look: from g3 it single-handedly covers h2, f4, e5, d6 and c7, every re-entry square. One dead diagonal on each side: that is domination."),
                 "critical": True},
                {"san": "Be3",
                 "comment": c("Le fou noir s'arrête à mi-chemin, faute de mieux : b6 et c5 n'attaquent pas b8 — sur la petite diagonale, seule a7 le fait, et elle est gardée. « Deux diagonales, dont une trop courte » : voilà la position qui donne son sens à la formule.",
                              "The black bishop stops halfway, for want of better: b6 and c5 do not attack b8 — on the short diagonal only a7 does, and it is guarded. \"Two diagonals, one too short\": this is the position that gives the phrase its meaning.")},
                {"san": "b8=Q",
                 "comment": c("Promotion, dix coups après la poussée initiale. Retenez le triptyque : le roi confisque la case unique de la petite diagonale, le fou s'interpose en b8, puis rafle la grande diagonale entière depuis g3.",
                              "Promotion, ten moves after the initial push. Remember the triptych: the king confiscates the short diagonal's only square, the bishop interposes on b8, then sweeps the whole long diagonal from g3."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "false-trade", "title": c("Échanger le gardien ? Il se fait reprendre à son poste", "Trade the guard? The recapture happens at its post")},
            "moves": [
                "b7", "Kc4",
                {"san": "Bf4", "role": "trap",
                 "comment": c("Le réflexe le plus humain du monde : proposer l'échange pour éliminer le gardien de b8. Vérifié à la tablebase : la position gagnée devient NULLE sur ce seul coup.",
                              "The most human reflex in the world: offer the trade to eliminate the guardian of b8. Tablebase-verified: the winning position becomes a DRAW on this one move."),
                 "critical": True},
                {"san": "Bxf4",
                 "comment": c("Et voilà le vice caché : la prise a lieu SUR la grande diagonale — le fou noir reprend sans quitter son poste une seule seconde, et il n'y a rien pour reprendre en f4. Un fou de garde ne s'échange pas : il se contourne — c'est toute la manœuvre du chapitre principal.",
                              "And here is the hidden flaw: the capture happens ON the long diagonal — the black bishop recaptures without leaving its post for a single second, and nothing can take back on f4. A guarding bishop cannot be traded off: it must be outflanked — which is the whole manoeuvre of the main chapter."),
                 "critical": True},
            ],
        },
    ],
}
