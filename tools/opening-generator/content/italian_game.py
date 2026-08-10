# -*- coding: utf-8 -*-
"""Partie italienne (1.e4 e5 2.Cf3 Cc6 3.Fc4) — répertoire BLANC."""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "italian-game",
    "name": "Italian Game",
    "side": "white",
    "level": "club",
    "eco": ["C50", "C59"],
    "summary": c(
        "Le fou file en c4 et vise f7 : développement rapide, idées claires, mais un venin réel avec l'attaque des Deux Cavaliers et le gambit Evans.",
        "The bishop goes to c4 and eyes f7: quick development, clear ideas — yet real venom in the Two Knights and the Evans Gambit.",
    ),
    "lines": [
        # Giuoco Pianissimo (le grand classique moderne)
        {
            "chapter": {"id": "pianissimo", "title": c("Giuoco Pianissimo", "Giuoco Pianissimo")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "Bc4", "comment": c("Le fou italien : il presse f7, le point faible du camp noir.",
                                            "The Italian bishop: it presses f7, the soft spot in Black's camp.")},
                {"san": "Bc5", "eco": "Italian Game: Giuoco Piano",
                 "comment": c("Le Giuoco Piano : les fous se font face, la partie sera de manœuvre.",
                              "The Giuoco Piano: the bishops face off; a manoeuvring game lies ahead.")},
                {"san": "c3", "comment": c("On prépare d4 pour bâtir un grand centre.",
                                           "Preparing d4 to build a big centre.")},
                "Nf6",
                {"san": "d3", "comment": c("Le plan moderne, lent mais solide : d3, puis Cbd2-f1-g3 et une attaque à venir.",
                                           "The modern, slow-but-solid plan: d3, then Nbd2-f1-g3 and a coming attack.")},
                "d6", "O-O", "O-O",
            ],
        },
        # Deux Cavaliers + Fried Liver
        {
            "chapter": {"id": "two-knights", "title": c("Défense des Deux Cavaliers", "Two Knights Defense")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4",
                {"san": "Nf6", "eco": "Italian Game: Two Knights Defense",
                 "comment": c("Les Deux Cavaliers : au lieu de …Fc5, les Noirs contre-attaquent e4. Ça devient piquant.",
                              "The Two Knights: instead of …Bc5, Black hits e4. Things get sharp.")},
                {"san": "Ng5", "comment": c("Le coup agressif : on attaque f7 immédiatement.",
                                            "The aggressive move: hitting f7 at once.")},
                {"san": "d5", "comment": c("La seule bonne défense : contre-attaque plutôt que défendre f7.",
                                           "The only good defence: counterattack rather than defend f7.")},
                "exd5",
                {"san": "Na5", "comment": c("La ligne principale : le cavalier attaque le fou c4, les Noirs sacrifient un pion pour l'initiative.",
                                            "The main line: the knight hits the c4 bishop; Black gives a pawn for the initiative.")},
                "Bb5+", "c6", "dxc6", "bxc6",
                {"san": "Be2", "comment": c("Le fou recule ; les Noirs ont une compensation réelle mais les Blancs tiennent le pion.",
                                            "The bishop retreats; Black has real compensation but White keeps the pawn.")},
            ],
        },
        {
            "chapter": {"id": "fried-liver", "title": c("Attaque Fried Liver", "Fried Liver Attack")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Nf6", "Ng5", "d5", "exd5",
                {"san": "Nxd5", "role": "inaccuracy", "critical": True,
                 "comment": c("Reprendre en d5 est risqué : cela autorise le sacrifice Fried Liver.",
                              "Recapturing on d5 is risky: it allows the Fried Liver sacrifice.")},
                {"san": "Nxf7", "role": "trap", "critical": True,
                 "eco": "Italian Game: Fried Liver Attack",
                 "comment": c("Le sacrifice Fried Liver ! Le roi noir est traîné dehors ; l'attaque blanche est très dangereuse en pratique.",
                              "The Fried Liver sacrifice! Black's king is dragged out; White's attack is very dangerous in practice.")},
                "Kxf7", "Qf3+", "Ke6", "Nc3",
            ],
        },
        # Gambit Evans
        {
            "chapter": {"id": "evans", "title": c("Gambit Evans", "Evans Gambit")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "Bc4", "Bc5",
                {"san": "b4", "role": "trap", "critical": True,
                 "eco": "Italian Game: Evans Gambit",
                 "comment": c("Le Gambit Evans : un pion pour arracher le fou de c5 et lancer un développement fulgurant.",
                              "The Evans Gambit: a pawn to deflect the c5 bishop and unleash rapid development.")},
                "Bxb4", "c3", "Ba5",
                {"san": "d4", "comment": c("On ouvre le centre pendant que les Noirs sont en retard : compensation classique.",
                                           "Opening the centre while Black lags behind: classic compensation.")},
                "exd4", "O-O",
            ],
        },
    ],
}
