# -*- coding: utf-8 -*-
"""Défense Philidor (1.e4 e5 2.Cf3 d6) — répertoire NOIR.

Arbre : système Hanham (…Cbd7/…Fe7), variante de l'échange (…exd4), et
l'hybride Philidor-Pirc (…exd4 …g6). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "philidor-defense",
    "name": "Philidor Defense",
    "side": "black",
    "level": "club",
    "eco": ["C41"],
    "summary": c(
        "Solide et discrète : les Noirs soutiennent e5 par …d6 au lieu de …Cc6. Peu d'espace, mais une position sans faiblesse et des plans clairs (…c6, …Fe7, …0-0).",
        "Solid and quiet: Black supports e5 with …d6 instead of …Nc6. Little space, but a weakness-free position with clear plans (…c6, …Be7, …0-0).",
    ),
    "lines": [
        {
            "chapter": {"id": "hanham", "title": c("Système Hanham", "Hanham System")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "Nf6", "Nc3", "Nbd7", "Bc4", "Be7", "O-O", "O-O",
                {"san": "a4", "comment": c("Les Blancs freinent …b5 ; les Noirs manœuvrent tranquillement derrière leur petit centre.",
                                           "White restrains …b5; Black manoeuvres calmly behind the small centre.")},
                "c6", "h3", "Qc7", "Qe2", "b6", "Rd1", "Bb7",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4",
                {"san": "exd4", "comment": c("On échange au centre pour un jeu simple et solide, sans souci d'espace.",
                                             "Trade in the centre for simple, solid play, free of space worries.")},
                "Nxd4", "Nf6", "Nc3", "Be7", "Be2", "O-O", "O-O", "Re8", "h3", "Bf8", "Bf4", "Nbd7", "Qd2", "a6",
            ],
        },
        {
            "chapter": {"id": "pirc-hybrid", "title": c("Hybride Philidor-Pirc — …g6", "Philidor-Pirc hybrid — …g6")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "exd4", "Nxd4", "g6", "Nc3", "Bg7", "Be3", "Nf6", "f3", "O-O", "Qd2", "Re8",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-bc4", "title": c("3.Fc4 — la sortie italienne", "3.Bc4 — the Italian bishop")},
            "moves": [
                "e4", "e5", "Nf3", "d6",
                {"san": "Bc4",
                 "comment": c("Le coup le plus fréquent contre la Philidor — plus de quatre parties sur dix — et le cours partait de 3.d4. Les Blancs visent f7 avant d'ouvrir le centre.",
                              "The most common move against the Philidor — over four games in ten — and the course started from 3.d4. White eyes f7 before opening the centre."),
                 "critical": True},
                {"san": "Be7",
                 "comment": c("Sobre et juste : on développe sans donner de cible. …Fe6 inviterait Fxe6 et un pion doublé sans compensation.",
                              "Sober and correct: develop without offering a target. …Be6 would invite Bxe6 and a doubled pawn for nothing.")},
                "d4", "exd4", "Nxd4", "Nf6", "Nc3", "O-O",
                {"san": "O-O",
                 "comment": c("Position typique de la Philidor moderne : à l'étroit mais sans faiblesse. Le plan est …Te8, …Ff8 et …c6.",
                              "The typical modern Philidor position: cramped but without weaknesses. The plan is …Re8, …Bf8 and …c6.")},
            ],
        },
        {
            "chapter": {"id": "vs-dxe5", "title": c("4.dxe5 — l'échange au centre", "4.dxe5 — the central exchange")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "Nf6",
                {"san": "dxe5",
                 "comment": c("Sept Blancs sur dix prennent ici, et le cours n'y répondait pas. Attention : reprendre en d6 par le pion perd un temps précieux.",
                              "Seven White players in ten take here, and the course had no answer. Careful: recapturing on d6 with the pawn loses precious time."),
                 "critical": True},
                {"san": "Nxe4", "critical": True,
                 "comment": c("LE coup à connaître : on ne reprend pas le pion e5, on prend celui de e4. C'est la ressource qui tient toute la variante.",
                              "THE move to know: don't recapture on e5 — take on e4 instead. That's the resource the whole line rests on.")},
                "Qd5", "Nc5", "Bg5", "Qd7", "exd6", "Bxd6",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,74). Répertoire NOIR :
        # les trous sont des coups BLANCS. ───────────────────────────────────
        {
            "chapter": {"id": "vs-bc4-early", "title": c("Si les Blancs jouent 2.Fc4", "If White plays 2.Bc4")},
            "moves": [
                "e4", "e5",
                {"san": "Bc4",
                 "comment": c("Sans 2.Cf3, le pion e5 n'est pas attaqué : jouer …d6 tout de suite serait passif sans raison. Un Blanc sur neuf, et le cours n'avait rien.",
                              "Without 2.Nf3, the e5 pawn is not attacked: playing …d6 at once would be passive for no reason. One White player in nine, and the course had nothing."),
                 "critical": True},
                {"san": "Nf6",
                 "comment": c("On attaque e4 puisqu'on en a le temps. La Philidor est une défense de nécessité, pas de principe : quand la nécessité disparaît, on joue mieux.",
                              "We hit e4 since we have time for it. The Philidor is a defence of necessity, not of principle: when the necessity is gone, we play something better."),
                 "critical": True},
                "d3", "c6", "Nf3", "d5", "Bb3", "a5", "a3", "a4", "Ba2",
            ],
        },
        {
            "chapter": {"id": "philidor-main", "title": c("Philidor — ligne principale", "Philidor — main line")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4", "Nf6", "dxe5", "Nxe4",
                {"san": "exd6",
                 "comment": c("Plus d'un Blanc sur deux prend en passant plutôt que de jouer Dd5, et le cours ne prévoyait que Dd5. C'est la ligne calme, et il faut la connaître.",
                              "More than one White player in two takes on d6 rather than playing Qd5, and the course only planned for Qd5. It is the quiet line, and it must be known."),
                 "critical": True},
                {"san": "Bxd6",
                 "comment": c("On reprend du FOU, pas de la dame : la dame en d6 serait exposée aux coups de tempo, le fou y est simplement bien.",
                              "We recapture with the BISHOP, not the queen: the queen on d6 would invite tempo moves, the bishop is simply well placed there."),
                 "critical": True},
                "Bd3", "Nc5", "Nc3", "Nxd3+", "Qxd3", "O-O", "O-O", "Nc6", "Nb5",
            ],
        },
        {
            "chapter": {"id": "vs-nc3", "title": c("Contre 3.Cc3", "vs 3.Nc3")},
            "moves": [
                "e4", "e5", "Nf3", "d6",
                {"san": "Nc3",
                 "comment": c("Les Blancs développent sans pousser d4 : un joueur sur dix, et le cours ne prévoyait que d4 et Fc4. Sans d4, notre position n'a rien d'étriqué.",
                              "White develops without pushing d4: one player in ten, and the course only planned for d4 and Bc4. Without d4, our position is not cramped at all."),
                 "critical": True},
                {"san": "c5",
                 "comment": c("Le coup qui change tout : puisque d4 n'est plus jouable dans de bonnes conditions, on prend l'espace au lieu de le subir. La Philidor devient une Sicilienne à l'envers.",
                              "The move that changes everything: since d4 is no longer playable on good terms, we take space instead of suffering it. The Philidor becomes a reversed Sicilian."),
                 "critical": True},
                "Bc4", "Be7", "d3", "Nc6", "a4", "Nf6", "Bg5", "Ng4", "Bd2",
            ],
        },
        {
            "chapter": {"id": "vs-bc4", "title": c("Contre 3.Fc4", "vs 3.Bc4")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "Bc4", "Be7",
                {"san": "O-O",
                 "comment": c("Un Blanc sur cinq roque tout de suite au lieu de pousser d4, et le cours ne voyait que d4. Le temps qu'ils nous laissent, nous allons l'employer.",
                              "One White player in five castles at once instead of pushing d4, and the course only saw d4. The time they give us, we are going to use."),
                 "critical": True},
                "Nf6", "Nc3",
                {"san": "c5",
                 "comment": c("Encore ce coup : dès que les Blancs renoncent à d4, la case d4 devient NOTRE affaire. C'est le fil conducteur de tout ce chapitre.",
                              "That move again: as soon as White gives up on d4, the d4 square becomes OUR business. It is the thread running through this whole chapter."),
                 "critical": True},
                "d3", "O-O", "h3", "Nc6", "a4", "a6", "Bg5",
            ],
        },
        {
            "chapter": {"id": "vs-bc4", "title": c("Contre 3.Fc4", "vs 3.Bc4")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "Bc4", "Be7",
                {"san": "Nc3",
                 "comment": c("Le développement tranquille, un Blanc sur six. Même réponse que ci-dessus, et pour la même raison.",
                              "Quiet development, one White player in six. Same answer as above, and for the same reason."),
                 "critical": True},
                "c5", "d3", "Nf6", "O-O", "O-O", "a4", "Nc6", "h3", "Be6",
                {"san": "Ng5",
                 "comment": c("Les Blancs cherchent la paire de fous. Les laisser prendre en e6 n'est pas grave : notre pion e6 tiendra d5 et f5, et la position est fermée.",
                              "White goes for the bishop pair. Letting them take on e6 is no disaster: our e6 pawn will hold d5 and f5, and the position is closed.")},
            ],
        },
    ],
}
