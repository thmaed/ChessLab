# -*- coding: utf-8 -*-
"""La percée — trois pions qui en valent une dame.

Racine à 8 pièces : les premiers coups sont vérifiés au MOTEUR (mat annoncé),
la tablebase prend le relais dès la première capture. L'ordre des poussées
est TOUT : b6 gagne (#23), a6 et c6 perdent — pas « annulent », PERDENT.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-breakthrough",
    "name": "The Pawn Breakthrough",
    "side": "white",
    "kind": "endgame",
    "family": "pawns",
    "level": "advanced",
    "rootFEN": "7k/ppp5/8/PPP5/8/8/8/7K w - - 0 1",
    "summary": c(
        "Trois pions contre trois, les rois à l'autre bout du monde : le camp qui sait PERCER fabrique une dame en trois coups. Mais des trois poussées possibles, une seule gagne — et les deux autres perdent la partie. Le sacrifice s'apprend dans l'ordre.",
        "Three pawns against three, kings a world away: the side that knows how to BREAK THROUGH makes a queen in three moves. Yet of the three possible pushes, exactly one wins — and the other two lose the game. This sacrifice is learned in order.",
    ),
    "lines": [
        {
            "chapter": {"id": "main", "title": c("Le bélier du milieu", "The middle ram")},
            "moves": [
                {"san": "b6",
                 "comment": c("TOUJOURS le pion du milieu d'abord : il attaque deux cases, il FORCE une prise, et chaque prise noire ouvre l'autoroute d'un pion latéral. a6 ou c6 d'abord ? L'adversaire bloque tout par b6 — et gagne (voir les pièges).",
                              "ALWAYS the middle pawn first: it attacks two squares, FORCES a capture, and each black capture opens a side pawn's motorway. a6 or c6 first? The opponent seals everything with b6 — and wins (see the traps)."),
                 "critical": True},
                {"san": "axb6",
                 "comment": c("L'autre prise (cxb6) mène au miroir exact : a6 ! au lieu de c6 — le pion qui court est alors le c. Même mécanique, autre couloir.",
                              "The other capture (cxb6) mirrors exactly: a6! instead of c6 — the running pawn is then the c-pawn. Same mechanism, other corridor.")},
                {"san": "c6",
                 "comment": c("Deuxième sacrifice, même logique : détourner le pion b7, dernier douanier du couloir a.",
                              "Second sacrifice, same logic: deflect the b7-pawn, last customs officer of the a-file."),
                 "critical": True},
                {"san": "bxc6", "comment": c("Forcé — sinon c7-c8 passe tout seul.", "Forced — else c7-c8 sails through unassisted.")},
                {"san": "a6",
                 "comment": c("Et le pion a n'a plus personne devant lui. Comptez avec les Noirs : leur roi est à cinq cases du carré, leurs pions à cinq temps de la promotion. Le a arrive en trois.",
                              "And the a-pawn has nobody left in front of it. Count for Black: his king is five squares outside, his pawns five tempi from promoting. The a-pawn arrives in three."),
                 "critical": True},
                {"san": "c5", "comment": c("La contre-course — c'est TOUJOURS elle qu'il faut calculer avant de sacrifier deux pions.",
                                           "The counter-race — ALWAYS the thing to calculate before shedding two pawns.")},
                "a7", "c4",
                {"san": "a8=Q+",
                 "comment": c("Dame — AVEC échec, le détail qui tue la contre-course : les Noirs perdent le temps qui leur manquait déjà. La suite est le cours « Dame contre pion ».",
                              "Queen — WITH check, the detail that kills the counter-race: Black loses the very tempo he was already missing. What follows is the “Queen vs Pawn” course."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "mirror", "title": c("L'autre prise, l'autre couloir", "The other capture, the other corridor")},
            "moves": [
                "b6",
                {"san": "cxb6", "comment": c("Prise côté c : le couloir libre sera l'autre.", "Capturing towards c: the free corridor will be the other one.")},
                {"san": "a6",
                 "comment": c("Miroir : on détourne b7 par la GAUCHE cette fois. Le principe est le même : ouvrir le couloir du pion resté en arrière.",
                              "Mirror image: b7 is deflected from the LEFT this time. Same principle: open the corridor of the pawn left behind."),
                 "critical": True},
                "bxa6",
                {"san": "c6", "critical": True},
                "a5", "c7", "a4",
                {"san": "c8=Q+",
                 "comment": c("Toujours avec échec — la géométrie du coin h8 est impitoyable pour les Noirs.",
                              "Again with check — the h8-corner geometry is merciless for Black.")},
            ],
        },
        {
            "chapter": {"id": "wrong-order", "title": c("Le mauvais ordre PERD", "The wrong order LOSES")},
            "moves": [
                {"san": "c6", "role": "trap",
                 "comment": c("Le pion de côté d'abord ? Les Noirs ont DEUX réponses gagnantes — la plus nette : prendre, et c'est le camp noir qui a désormais la percée. Notez bien : pas nulle, PERDANT (mat en 31 au moteur). Trois pions sacrifiés dans le désordre sont juste trois pions perdus.",
                              "The side pawn first? Black has TWO winning replies — cleanest: capture, and now BLACK owns the breakthrough. Mark it well: not a draw, LOSING (engine announces mate in 31). Three pawns sacrificed in the wrong order are just three lost pawns."),
                 "critical": True},
                {"san": "bxc6",
                 "comment": c("Le douanier prend — il ne se laisse pas détourner, puisque rien ne menace derrière.",
                              "The customs officer takes — no deflection works, since nothing threatens behind him.")},
                {"san": "bxc6", "comment": c("Reprendre maintient l'illusion un coup de plus…", "Recapturing keeps the illusion alive one more move…")},
                {"san": "a6",
                 "comment": c("…et voilà le verrou : a5 est mort, c6 est mort (c7 le bloque), et le roi noir va traverser l'échiquier pour tout ramasser. La percée était à sens unique — dans l'autre sens.",
                              "…and there is the deadbolt: a5 is dead, c6 is dead (c7 blocks it), and the black king will stroll across the board to collect everything. The breakthrough was one-way — the other way.")},
            ],
        },
    ],
}
