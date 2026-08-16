# -*- coding: utf-8 -*-
"""Défense Alekhine (1.e4 Cf6) — répertoire NOIR.

Arbre approfondi : Moderne 4.Cf3 (4…Fg4 et 4…g6), Attaque des Quatre Pions,
Échange, variante de chasse 4.c5. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "alekhine-defense",
    "name": "Alekhine Defense",
    "side": "black",
    "level": "club",
    "eco": ["B02", "B05"],
    "summary": c(
        "Provocante : le cavalier invite les pions blancs à avancer… pour en faire des cibles. Une arme hypermoderne pleine de venin.",
        "Provocative: the knight invites White's pawns forward… to turn them into targets. A venomous hypermodern weapon.",
    ),
    "lines": [
        # 1) Moderne — 4.Cf3 Fg4 (ligne principale)
        {
            "chapter": {"id": "modern-bg4", "title": c("Moderne — 4.Cf3 Fg4", "Modern — 4.Nf3 Bg4")},
            "moves": [
                "e4",
                {"san": "Nf6", "eco": "Alekhine Defense",
                 "comment": c("Le cavalier attaque e4 dès le 1er coup et provoque l'avance des pions blancs.",
                              "The knight hits e4 on move one and provokes White's pawns forward.")},
                "e5", "Nd5", "d4", "d6",
                {"san": "Nf3", "eco": "Alekhine Defense: Modern Variation",
                 "comment": c("La ligne moderne, saine : les Blancs se contentent d'un centre raisonnable.",
                              "The sound modern line: White settles for a reasonable centre.")},
                {"san": "Bg4", "comment": c("On cloue le cavalier f3, défenseur de d4 et e5.",
                                            "Pin the f3-knight, defender of d4 and e5.")},
                "Be2", "e6", "O-O", "Be7", "c4",
                {"san": "Nb6", "comment": c("Le cavalier recule ; on visera le centre blanc par …d5 ou …dxe5.",
                                            "The knight retreats; Black will target the centre with …d5 or …dxe5.")},
                "Nc3", "O-O", "Be3", "d5",
            ],
        },
        # 2) Moderne — 4.Cf3 g6 (fianchetto)
        {
            "chapter": {"id": "modern-g6", "title": c("Moderne — 4.Cf3 g6", "Modern — 4.Nf3 g6")},
            "moves": [
                "e4", "Nf6", "e5", "Nd5", "d4", "d6", "Nf3",
                {"san": "g6", "comment": c("Le fianchetto : le fou g7 mordra sur le centre blanc et la case e5.",
                                           "The fianchetto: the g7 bishop will bite on White's centre and the e5 square.")},
                "Be2", "Bg7", "O-O", "O-O", "c4", "Nb6", "exd6", "cxd6",
            ],
        },
        # 3) Attaque des Quatre Pions
        {
            "chapter": {"id": "four-pawns", "title": c("Attaque des Quatre Pions", "Four Pawns Attack")},
            "moves": [
                "e4", "Nf6", "e5", "Nd5", "d4", "d6",
                {"san": "c4", "comment": c("Les Blancs prennent tout l'espace…",
                                           "White grabs all the space…")},
                "Nb6",
                {"san": "f4", "eco": "Alekhine Defense: Four Pawns Attack",
                 "comment": c("L'Attaque des Quatre Pions : impressionnante, mais ces pions deviennent des cibles après …dxe5 et …c5.",
                              "The Four Pawns Attack: impressive, but those pawns become targets after …dxe5 and …c5.")},
                "dxe5", "fxe5", "Nc6", "Be3", "Bf5", "Nc3", "e6", "Nf3", "Be7", "Be2", "O-O",
            ],
        },
        # 4) Échange
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "Nf6", "e5", "Nd5", "d4", "d6", "c4", "Nb6",
                {"san": "exd6", "eco": "Alekhine Defense: Exchange Variation",
                 "comment": c("L'échange : jeu tranquille où les Noirs finissent bien développés, sans faiblesse.",
                              "The exchange: quiet play where Black ends up well developed and solid.")},
                "cxd6", "Nc3", "g6", "Be3", "Bg7", "Rc1", "O-O", "Nf3", "Nc6", "Be2", "d5",
            ],
        },
        # 5) Variante de chasse — 4.c5
        {
            "chapter": {"id": "chase", "title": c("Variante de chasse — 4.c5", "Chase Variation — 4.c5")},
            "moves": [
                "e4", "Nf6", "e5", "Nd5",
                {"san": "c4", "comment": c("Les Blancs chassent le cavalier tout de suite…",
                                           "White chases the knight straight away…")},
                "Nb6",
                {"san": "c5", "comment": c("La chasse : le pion pousse encore. Le cavalier trouve refuge et le pion c5 sera faible.",
                                           "The chase: the pawn pushes again. The knight finds shelter and the c5-pawn will be weak.")},
                "Nd5", "Nc3", "e6", "Nxd5", "exd5", "d4", "d6",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-nc3", "title": c("2.Cc3 — les Blancs refusent la chasse", "2.Nc3 — White declines the chase")},
            "moves": [
                "e4", "Nf6",
                {"san": "Nc3",
                 "comment": c("Un tiers des parties. Les Blancs refusent de pousser e5 et donc de jouer l'Alekhine : plus de cavalier chassé, plus de contre-attaque.",
                              "A third of games. White declines to push e5 and therefore to play the Alekhine at all: no knight chased, no counterattack."),
                 "critical": True},
                {"san": "d5",
                 "comment": c("La réponse qui remet du jeu : on frappe e4 au centre plutôt que de subir un développement tranquille.",
                              "The reply that restores play: we hit e4 in the centre rather than endure a quiet development."),
                 "critical": True},
                "exd5", "Nxd5", "d4", "Nxc3", "bxc3",
                {"san": "c5",
                 "comment": c("Pions doublés blancs contre centre large : on attaque d4 tout de suite, c'est la faiblesse durable de cette structure.",
                              "White's doubled pawns against a broad centre: we hit d4 at once — the lasting weakness of this structure.")},
            ],
        },
        {
            "chapter": {"id": "four-pawns", "title": c("Attaque des quatre pions — 5.d4", "Four Pawns Attack — 5.d4")},
            "moves": [
                "e4", "Nf6", "e5", "Nd5", "c4", "Nb6", "d4",
                {"san": "d6",
                 "comment": c("Trois Noirs sur cinq jouent ce coup ici, et le chapitre continuait autrement. Il faut frapper le centre AVANT qu'il ne se solidifie.",
                              "Three Black players in five play this here, and the chapter went elsewhere. Strike the centre BEFORE it solidifies."),
                 "critical": True},
                "exd6", "cxd6", "Be2", "g6",
                {"san": "h3",
                 "comment": c("Les Blancs empêchent …Fg4. Sans cette précaution, le clouage rendrait d4 indéfendable.",
                              "White stops …Bg4. Without that precaution, the pin would make d4 indefensible.")},
                "Bg7",
            ],
        },
    ],
}
