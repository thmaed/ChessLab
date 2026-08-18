# -*- coding: utf-8 -*-
"""Cavalier + pion contre cavalier — première finale de la famille cavaliers.

Deux leçons opposées, chacune vérifiée : POUSSER tout de suite quand la
défense n'est pas encore en place ; tenir une forteresse de blocus quand
elle l'est déjà.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "eg-knight-and-pawn",
    "name": "Knight and Pawn vs Knight",
    "side": "white",
    "kind": "endgame",
    "family": "knights",
    "level": "advanced",
    "rootFEN": "8/8/8/4P3/4K3/8/8/n3k3 w - - 0 1",
    "summary": c(
        "Un cavalier seul peut bloquer un pion à jamais — mais SEULEMENT s'il arrive à temps devant lui. Cette finale se joue presque toujours sur une seule question : qui va plus vite, le pion ou le cavalier défenseur ?",
        "A lone knight can blockade a pawn forever — but ONLY if it gets in front of it in time. This ending almost always comes down to one race: the pawn, or the defending knight?",
    ),
    "lines": [
        {
            "chapter": {"id": "run", "title": c("Le défenseur est trop loin : foncez", "The defender is too far: run")},
            "moves": [
                {"san": "e6",
                 "comment": c("Le SEUL coup qui gagne — tout coup de roi, même pour « aider », laisse au cavalier noir le temps de revenir bloquer. Le cavalier et le roi noirs sont trop loin : c'est une course, et la course se gagne en partant tout de suite.",
                              "The ONLY move that wins — any king move, even to “help”, gives the black knight time to rush back and blockade. Black's knight and king are too far: this is a race, and races are won by starting now."),
                 "critical": True},
                {"san": "Nc2",
                 "comment": c("Le cavalier se précipite, mais il lui manque un temps que le roi blanc, prudent, aurait justement offert.",
                              "The knight rushes over, but he is missing exactly the tempo a cautious white king would have handed him.")},
                "e7",
                {"san": "Nb4", "comment": c("Toujours en retard d'un coup.", "Still one move behind.")},
                "e8=Q",
                {"san": "Kd2",
                 "comment": c("Une dame de plus, un cavalier esseulé : la conversion n'a plus qu'à suivre.",
                              "One more queen, one lonely knight: the conversion is now a formality."),
                 "critical": True},
            ],
        },
        {
            "chapter": {"id": "hesitate", "title": c("Amener le roi d'abord ? Trop tard", "Bring the king first? Too late")},
            "moves": [
                {"san": "Kd3", "role": "trap",
                 "comment": c("Le réflexe prudent — et il coûte la victoire entière. Le cavalier noir a maintenant EXACTEMENT le temps de revenir se placer devant le pion.",
                              "The cautious reflex — and it costs the entire win. Black's knight now has EXACTLY enough time to get back in front of the pawn."),
                 "critical": True},
                {"san": "Nb3",
                 "comment": c("Le cavalier fonce vers la case clé c5, qui surveille la case de promotion.",
                              "The knight races for the key square c5, which watches the queening square.")},
                "e6",
                {"san": "Nc5+",
                 "comment": c("Fourchette roi + pion : le cavalier arrive juste à temps et croque le pion au passage. Nulle — pour UN SEUL temps perdu au premier coup. Et si le cavalier noir avait déjà tenu sa case devant le pion dès le départ, aucune manœuvre blanche n'y aurait jamais rien changé : un cavalier bien placé devant un pion isolé est une forteresse, pas un obstacle temporaire.",
                              "Fork on king and pawn: the knight arrives just in time and picks up the pawn on the way through. Drawn — for the sake of a SINGLE tempo lost on move one. And had Black's knight already held the square in front of the pawn from the start, no white manoeuvre would ever have changed a thing: a well-placed knight in front of a lone pawn is a fortress, not a temporary obstacle."),
                 "critical": True},
            ],
        },
    ],
}
