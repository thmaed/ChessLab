# -*- coding: utf-8 -*-
"""Partie italienne (1.e4 e5 2.Cf3 Cc6 3.Fc4) — répertoire BLANC.

Arbre approfondi : Giuoco Pianissimo (plan moderne), Giuoco Piano classique,
Deux Cavaliers (Ca5, Fritz, Ulvestad, Fried Liver), Traxler, Evans, hongroise,
gambit italien. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "italian-game",
    "name": "Italian Game",
    "side": "white",
    "level": "club",
    "eco": ["C50", "C59"],
    "summary": c(
        "Le fou file en c4 et vise f7. Deux mondes en un : le Giuoco Pianissimo, lent et positionnel, et l'univers tactique des Deux Cavaliers (Fried Liver, Traxler) et du gambit Evans.",
        "The bishop goes to c4 and eyes f7. Two worlds in one: the slow, positional Giuoco Pianissimo, and the tactical universe of the Two Knights (Fried Liver, Traxler) and the Evans Gambit.",
    ),
    "lines": [
        # 1) Giuoco Pianissimo — plan moderne (ligne principale)
        {
            "chapter": {"id": "pianissimo", "title": c("Giuoco Pianissimo", "Giuoco Pianissimo")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "Bc4", "comment": c("Le fou italien : il presse f7, le point faible du camp noir.",
                                            "The Italian bishop: it presses f7, Black's soft spot.")},
                {"san": "Bc5", "eco": "Italian Game: Giuoco Piano",
                 "comment": c("Le Giuoco Piano : les fous se font face, la partie sera de manœuvre.",
                              "The Giuoco Piano: the bishops face off; a manoeuvring game lies ahead.")},
                {"san": "c3", "comment": c("On prépare d4 et une case de repli en c2 pour le fou.",
                                           "Preparing d4 and a c2 retreat for the bishop.")},
                "Nf6",
                {"san": "d3", "comment": c("Le plan moderne : d3, puis le grand voyage Cbd2-f1-g3 et une attaque à l'aile roi.",
                                           "The modern plan: d3, then the famous Nbd2-f1-g3 tour and a kingside attack.")},
                "d6", "O-O", "O-O", "Re1",
                {"san": "a6", "comment": c("Chacun prépare l'expansion à l'aile dame (…b5 / a4).",
                                           "Each side prepares queenside expansion (…b5 / a4).")},
                "a4", "Ba7", "h3", "h6", "Nbd2", "Be6",
            ],
        },
        # 2) Giuoco Piano classique — 5.d4
        {
            "chapter": {"id": "classical", "title": c("Giuoco Piano classique — 5.d4", "Classical Giuoco Piano — 5.d4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5", "c3", "Nf6",
                {"san": "d4", "comment": c("La rupture classique : on ouvre le centre au lieu du plan lent d3.",
                                           "The classical break: opening the centre instead of the slow d3 plan.")},
                "exd4", "cxd4", "Bb4+",
                {"san": "Nc3", "comment": c("L'Attaque Møller : on offre un pion pour un développement et une initiative fulgurants.",
                                            "The Møller Attack: offering a pawn for rapid development and initiative.")},
                "Nxe4", "O-O", "Bxc3", "d5",
            ],
        },
        # 3) Deux Cavaliers — 4...d5 5.exd5 Ca5 (principale)
        {
            "chapter": {"id": "two-knights", "title": c("Deux Cavaliers — 5…Ca5", "Two Knights — 5…Na5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4",
                {"san": "Nf6", "eco": "Italian Game: Two Knights Defense",
                 "comment": c("Les Deux Cavaliers : au lieu de …Fc5, les Noirs contre-attaquent e4. Ça devient piquant.",
                              "The Two Knights: instead of …Bc5, Black hits e4. Things get sharp.")},
                {"san": "Ng5", "comment": c("Le coup agressif : on attaque f7 immédiatement.",
                                            "The aggressive move: hitting f7 at once.")},
                {"san": "d5", "comment": c("La seule bonne défense : contre-attaquer plutôt que défendre f7.",
                                           "The only good defence: counterattack rather than defend f7.")},
                "exd5",
                {"san": "Na5", "comment": c("La ligne principale : le cavalier chasse le fou c4 ; les Noirs sacrifient un pion pour l'initiative.",
                                            "The main line: the knight hits the c4 bishop; Black gives a pawn for the initiative.")},
                "Bb5+", "c6", "dxc6", "bxc6", "Be2", "h6", "Nf3", "e4", "Ne5", "Bd6",
            ],
        },
        # 4) Deux Cavaliers — 5...Cd4 (Fritz) et 5...b5 (Ulvestad)
        {
            "chapter": {"id": "fritz-ulvestad", "title": c("Deux Cavaliers — Fritz & Ulvestad", "Two Knights — Fritz & Ulvestad")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6", "Ng5", "d5", "exd5",
                {"san": "Nd4", "role": "sideline", "eco": "Italian Game: Two Knights, Fritz Variation",
                 "comment": c("La Fritz : plus tranchante que …Ca5, elle vise une attaque directe.",
                              "The Fritz: sharper than …Na5, aiming for a direct attack.")},
                "c3", "b5", "Bf1", "Nxd5",
            ],
        },
        {
            "chapter": {"id": "fritz-ulvestad", "title": c("Deux Cavaliers — Fritz & Ulvestad", "Two Knights — Fritz & Ulvestad")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6", "Ng5", "d5", "exd5",
                {"san": "b5", "role": "sideline", "eco": "Italian Game: Two Knights, Ulvestad Variation",
                 "comment": c("L'Ulvestad : …b5 repousse le fou avant de récupérer d5. Très pointue.",
                              "The Ulvestad: …b5 kicks the bishop before regaining d5. Very sharp.")},
                "Bf1", "Nd4", "c3", "Nxd5",
            ],
        },
        # 5) Fried Liver
        {
            "chapter": {"id": "fried-liver", "title": c("Attaque Fried Liver", "Fried Liver Attack")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6", "Ng5", "d5", "exd5",
                {"san": "Nxd5", "role": "inaccuracy", "critical": True,
                 "comment": c("Reprendre en d5 est risqué : cela autorise le sacrifice Fried Liver.",
                              "Recapturing on d5 is risky: it allows the Fried Liver sacrifice.")},
                {"san": "Nxf7", "role": "trap", "critical": True,
                 "eco": "Italian Game: Fried Liver Attack",
                 "comment": c("Le sacrifice Fried Liver ! Le roi noir est traîné dehors ; l'attaque est très dangereuse en pratique.",
                              "The Fried Liver sacrifice! Black's king is dragged out; the attack is very dangerous in practice.")},
                "Kxf7", "Qf3+", "Ke6", "Nc3", "Nb4",
            ],
        },
        # 6) Traxler / Wilkes-Barre
        {
            "chapter": {"id": "traxler", "title": c("Contre-attaque Traxler — 4…Fc5", "Traxler Counterattack — 4…Bc5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6", "Ng5",
                {"san": "Bc5", "role": "trap", "critical": True,
                 "eco": "Italian Game: Two Knights, Traxler Variation",
                 "comment": c("Le Traxler : les Noirs ignorent la menace sur f7 et attaquent f2 en retour ! Chaos garanti.",
                              "The Traxler: Black ignores the f7 threat and hits f2 in return! Guaranteed chaos.")},
                {"san": "Nxf7", "comment": c("Prendre f7 mène aux complications les plus folles ; Fxf7+ est la voie plus sûre.",
                                             "Taking f7 leads to the wildest complications; Bxf7+ is the safer route.")},
                "Bxf2+", "Kxf2", "Nxe4+", "Kg1", "Qh4",
            ],
        },
        # 7) Gambit Evans
        {
            "chapter": {"id": "evans", "title": c("Gambit Evans", "Evans Gambit")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5",
                {"san": "b4", "role": "trap", "critical": True,
                 "eco": "Italian Game: Evans Gambit",
                 "comment": c("Le Gambit Evans : un pion pour dévier le fou c5 et déchaîner le développement.",
                              "The Evans Gambit: a pawn to deflect the c5 bishop and unleash development.")},
                "Bxb4", "c3", "Ba5", "d4", "exd4", "O-O", "dxc3", "Qb3", "Qf6",
            ],
        },
        # 8) Défense hongroise
        {
            "chapter": {"id": "hungarian", "title": c("Défense hongroise — 3…Fe7", "Hungarian Defense — 3…Be7")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4",
                {"san": "Be7", "eco": "Hungarian Defense",
                 "comment": c("La hongroise : un choix modeste et solide pour éviter tout le venin tactique.",
                              "The Hungarian: a modest, solid choice to sidestep all the tactical venom.")},
                "d4", "exd4", "Nxd4", "Nf6", "Nc3", "O-O",
            ],
        },
        # 9) Gambit italien / écossais
        {
            "chapter": {"id": "italian-gambit", "title": c("Gambit italien — 4.d4", "Italian Gambit — 4.d4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5",
                {"san": "d4", "role": "sideline",
                 "comment": c("On ouvre le centre tout de suite : jeu ouvert, souvent transposé au gambit écossais.",
                              "Opening the centre at once: open play, often transposing to the Scotch Gambit.")},
                "exd4", "c3", "dxc3", "Nxc3", "d6",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-philidor", "title": c("2…d6 — la Philidor", "2…d6 — the Philidor")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "d6",
                 "comment": c("Les Noirs défendent e5 avec un pion et refusent tout le débat. Un cours de 1.e4 e5 doit y répondre : c'est une entrée, pas une variante.",
                              "Black defends e5 with a pawn and declines the whole debate. A 1.e4 e5 course must answer it: this is an entry point, not a sideline."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("On frappe immédiatement. La Philidor est solide mais étroite : lui laisser le temps de respirer serait lui rendre service.",
                              "Strike at once. The Philidor is solid but cramped: giving it time to breathe would be doing it a favour.")},
                "Nd7", "Bd3", "Ngf6", "O-O", "Be7", "Nc3",
                {"san": "O-O",
                 "comment": c("Les Noirs sont sains mais sans espace ni contre-jeu. Notre plan est simple : Te1, a4, et l'étouffement.",
                              "Black is sound but has neither space nor counterplay. Our plan is simple: Re1, a4, and squeeze.")},
            ],
        },
        {
            "chapter": {"id": "vs-petrov", "title": c("2…Cf6 — la Petroff", "2…Nf6 — the Petrov")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "Nf6",
                 "comment": c("La Petroff : au lieu de défendre e5, les Noirs attaquent e4. Réputée aride, elle est fréquente et le cours n'en disait rien.",
                              "The Petrov: instead of defending e5, Black attacks e4. Reputedly dry, it's common — and the course said nothing about it."),
                 "critical": True},
                {"san": "Nxe5",
                 "comment": c("On prend. La reprise immédiate …Cxe4 est l'erreur classique : Dе2 gagne alors la dame ou une pièce après l'échec à la découverte.",
                              "We take. The immediate …Nxe4 is the classic blunder: Qe2 then wins the queen or a piece via the discovered check.")},
                "d6",
                {"san": "Nf3",
                 "comment": c("Le cavalier rentre — jamais Cxf7, qui ne donne que deux pions pour une pièce.",
                              "The knight retreats — never Nxf7, which gives only two pawns for a piece.")},
                "Nxe4", "d4", "d5", "Bd3", "Be7",
            ],
        },
    ],
}
