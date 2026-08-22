# -*- coding: utf-8 -*-
"""Défense française (1.e4 e6) — répertoire NOIR.

Arbre approfondi : Winawer (pion empoisonné 7.Dg4 Dc7 et 7…0-0), Avance
(6.a3 et gambit Milner-Barry), Tarrasch (3…c5 ouverte et 3…Cf6 fermée),
Classique (Steinitz 4.e5 et 4.Fg5), Rubinstein 3…dxe4, Échange. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "french-defense",
    "name": "French Defense",
    "side": "black",
    "level": "club",
    "eco": ["C00", "C19"],
    "summary": c(
        "Solide et combative : les Noirs cèdent un peu d'espace pour frapper le centre par …c5 et …f6. Le seul souci, le fou de cases blanches, guide tout le plan.",
        "Solid and combative: Black concedes a little space to strike the centre with …c5 and …f6. The one problem piece, the light-squared bishop, shapes the whole plan.",
    ),
    "lines": [
        # 1) Winawer — pion empoisonné 7.Dg4 Dc7 (ligne principale)
        {
            "chapter": {"id": "winawer", "title": c("Winawer — 7.Dg4", "Winawer — 7.Qg4")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3",
                {"san": "Bb4", "eco": "French Defense: Winawer Variation",
                 "comment": c("La Winawer : on cloue le cavalier c3 pour désorganiser le centre blanc.",
                              "The Winawer: pin the c3 knight to disrupt White's centre.")},
                {"san": "e5", "comment": c("Le centre se ferme ; la bataille portera sur la chaîne de pions d4-e5.",
                                           "The centre closes; the fight will be about the d4-e5 pawn chain.")},
                "c5", "a3", "Bxc3+", "bxc3",
                {"san": "Ne7", "comment": c("Les Blancs ont la paire de fous, les Noirs des pions doublés à attaquer : jeu double-tranchant.",
                                            "White has the bishop pair, Black has doubled pawns to attack: double-edged play.")},
                {"san": "Qg4", "comment": c("Le coup critique : la dame attaque g7 et met à l'épreuve le roi noir.",
                                            "The critical move: the queen hits g7 and tests Black's king.")},
                {"san": "Qc7", "comment": c("La ligne du pion empoisonné : on laisse g7 pour arracher c3 et d4 en retour.",
                                            "The Poisoned Pawn line: give up g7 to grab c3 and d4 in return.")},
                "Qxg7", "Rg8", "Qxh7", "cxd4", "Ne2", "Nbc6", "f4",
                {"san": "dxc3", "comment": c("Chacun dévore l'aile de l'autre : la partie se joue au fil du rasoir.",
                                             "Each side devours the other's wing: play balances on a knife's edge.")},
            ],
        },
        # 2) Winawer — 7.Dg4 0-0
        {
            "chapter": {"id": "winawer-oo", "title": c("Winawer — 7.Dg4 0-0", "Winawer — 7.Qg4 0-0")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3", "Bb4", "e5", "c5", "a3", "Bxc3+", "bxc3", "Ne7", "Qg4",
                {"san": "O-O", "comment": c("La version prudente : on roque au lieu de prendre le pion empoisonné.",
                                            "The safe version: castle instead of grabbing the poisoned pawn.")},
                "Bd3", "Nbc6", "Qh5", "Ng6", "Nf3", "Qc7", "Be3", "c4",
            ],
        },
        # 3) Avance — 6.a3
        {
            "chapter": {"id": "advance", "title": c("Variante d'avance — 6.a3", "Advance Variation — 6.a3")},
            "moves": [
                "e4", "e6", "d4", "d5",
                {"san": "e5", "eco": "French Defense: Advance Variation",
                 "comment": c("L'avance : les Blancs ferment le centre. Les Noirs vont assiéger la base d4.",
                              "The Advance: White closes the centre. Black will besiege the d4 base.")},
                {"san": "c5", "comment": c("Le coup de rupture typique : on attaque d4 à sa racine.",
                                           "The typical break: hitting d4 at its root.")},
                "c3", "Nc6", "Nf3",
                {"san": "Qb6", "comment": c("La dame vise b2 et surtout d4 : la pression s'accumule.",
                                            "The queen eyes b2 and above all d4: the pressure mounts.")},
                "a3",
                {"san": "Nh6", "comment": c("Le cavalier contourne par h6 pour sauter en f5 et frapper d4/e3.",
                                            "The knight routes via h6 to land on f5 and hit d4/e3.")},
                "b4", "cxd4", "cxd4", "Nf5",
            ],
        },
        # 4) Avance — gambit Milner-Barry 6.Fd3
        {
            "chapter": {"id": "milner-barry", "title": c("Avance — gambit Milner-Barry", "Advance — Milner-Barry Gambit")},
            "moves": [
                "e4", "e6", "d4", "d5", "e5", "c5", "c3", "Nc6", "Nf3", "Qb6",
                {"san": "Bd3", "comment": c("Le gambit Milner-Barry : les Blancs abandonnent d4 pour attaquer le roi resté au centre.",
                                            "The Milner-Barry Gambit: White gives up d4 to attack the king stuck in the centre.")},
                "cxd4", "cxd4", "Bd7",
                {"san": "O-O", "comment": c("On peut prendre en d4, mais il faut ensuite défendre très précisément.",
                                            "Grabbing d4 is fine, but precise defence must follow.")},
                "Nxd4", "Nxd4", "Qxd4", "Nc3",
            ],
        },
        # 5) Tarrasch — 3…c5 (ouverte)
        {
            "chapter": {"id": "tarrasch-open", "title": c("Tarrasch — 3.Cd2 c5", "Tarrasch — 3.Nd2 c5")},
            "moves": [
                "e4", "e6", "d4", "d5",
                {"san": "Nd2", "eco": "French Defense: Tarrasch Variation",
                 "comment": c("La Tarrasch : plus souple, elle évite le clouage …Fb4.",
                              "The Tarrasch: more flexible, it sidesteps the …Bb4 pin.")},
                {"san": "c5", "comment": c("On frappe le centre sans tarder : il naîtra un pion dame isolé à jouer activement.",
                                           "Strike the centre at once: an isolated queen's pawn arises, to be played actively.")},
                "exd5", "exd5", "Ngf3", "Nc6", "Bb5", "Bd6", "O-O", "Nge7", "dxc5", "Bxc5", "Nb3", "Bd6", "Re1", "O-O",
            ],
        },
        # 6) Tarrasch — 3…Cf6 (fermée)
        {
            "chapter": {"id": "tarrasch-closed", "title": c("Tarrasch — 3.Cd2 Cf6", "Tarrasch — 3.Nd2 Nf6")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nd2",
                {"san": "Nf6", "comment": c("La version fermée : plus stratégique, avec l'avance …f6 pour miner e5.",
                                            "The closed version: more strategic, with a later …f6 to undermine e5.")},
                "e5", "Nfd7", "Bd3", "c5", "c3", "Nc6", "Ne2", "cxd4", "cxd4", "f6",
            ],
        },
        # 7) Classique — Steinitz 4.e5
        {
            "chapter": {"id": "steinitz", "title": c("Classique — Steinitz 4.e5", "Classical — Steinitz 4.e5")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3", "Nf6",
                {"san": "e5", "comment": c("La Steinitz : les Blancs gagnent de l'espace ; on frappe par …c5 et …f6.",
                                           "The Steinitz: White grabs space; Black hits back with …c5 and …f6.")},
                "Nfd7", "f4", "c5", "Nf3", "Nc6", "Be3", "cxd4", "Nxd4", "Bc5",
            ],
        },
        # 8) Classique — 4.Fg5
        {
            "chapter": {"id": "classical-bg5", "title": c("Classique — 4.Fg5", "Classical — 4.Bg5")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3", "Nf6",
                {"san": "Bg5", "comment": c("La classique proprement dite : le fou cloue f6 avant de pousser e5.",
                                            "The Classical proper: the bishop pins f6 before pushing e5.")},
                "Be7", "e5", "Nfd7", "Bxe7", "Qxe7", "f4", "O-O", "Nf3", "c5",
            ],
        },
        # 9) Rubinstein — 3…dxe4
        {
            "chapter": {"id": "rubinstein", "title": c("Rubinstein — 3…dxe4", "Rubinstein — 3…dxe4")},
            "moves": [
                "e4", "e6", "d4", "d5", "Nc3",
                {"san": "dxe4", "comment": c("La Rubinstein : on rend le centre pour une position solide et sans faiblesse.",
                                             "The Rubinstein: give up the centre for a solid, weakness-free position.")},
                "Nxe4", "Nd7", "Nf3", "Ngf6", "Nxf6+", "Nxf6", "Bd3", "c5",
            ],
        },
        # 10) Échange
        {
            "chapter": {"id": "exchange", "title": c("Variante de l'échange", "Exchange Variation")},
            "moves": [
                "e4", "e6", "d4", "d5",
                {"san": "exd5", "eco": "French Defense: Exchange Variation",
                 "comment": c("L'échange libère le fou problématique des Noirs : la position devient symétrique et facile à jouer.",
                              "The exchange frees Black's problem bishop: the position becomes symmetrical and easy to play.")},
                "exd5", "Nf3", "Nf6", "Bd3", "Bd6", "O-O", "O-O", "Bg5", "Bg4", "Nbd2", "Nbd7",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-nf3", "title": c("2.Cf3 — les Blancs évitent d4", "2.Nf3 — White avoids d4")},
            "moves": [
                "e4", "e6",
                {"san": "Nf3",
                 "comment": c("Près d'un tiers des parties, et le cours partait toujours de 2.d4. Les Blancs gardent le centre souple, souvent pour éviter la théorie française.",
                              "Nearly a third of games, and the course always started from 2.d4. White keeps the centre flexible, often to dodge French theory."),
                 "critical": True},
                {"san": "d5",
                 "comment": c("On joue notre coup quand même : sans pion en d4, la poussée e5 nous laisse un jeu confortable.",
                              "We play our move anyway: with no pawn on d4, the e5 push leaves us comfortable.")},
                "e5", "c5", "c3", "Nc6", "d4",
                {"san": "Bd7",
                 "comment": c("Le fou sort AVANT que …c4 ne ferme la position : c'est la nuance qui distingue cet ordre de la Française classique, où il reste souvent enfermé.",
                              "The bishop develops BEFORE …c4 closes things: that's the nuance separating this move order from the classical French, where it often stays shut in."),
                 "critical": True},
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,60). Répertoire NOIR :
        # les trous sont des coups BLANCS. Deux d'entre eux concernent l'ordre
        # 2.Cf3, où les Blancs peuvent échanger en d5 avant même d'avoir joué
        # d4 — un cas que le cours ignorait entièrement. ─────────────────────
        {
            "chapter": {"id": "vs-nf3", "title": c("Contre 2.Cf3", "vs 2.Nf3")},
            "moves": [
                "e4", "e6", "Nf3", "d5",
                {"san": "exd5",
                 "comment": c("Deux Blancs sur trois échangent ici, et le cours ne prévoyait QUE e5. C'était le plus gros manque du répertoire : la variante d'échange par cet ordre de coups n'existait pas.",
                              "Two White players in three exchange here, and the course only planned for e5. It was the repertoire's biggest gap: the Exchange Variation via this move order simply did not exist."),
                 "critical": True},
                {"san": "exd5",
                 "comment": c("On reprime du pion e, ce qui règle d'un coup le problème de toute Française : le fou c8 n'est plus enfermé. La position est symétrique et parfaitement jouable.",
                              "We recapture with the e-pawn, which solves the French's eternal problem at a stroke: the c8 bishop is no longer shut in. The position is symmetrical and perfectly playable."),
                 "critical": True},
                "d4", "Nf6", "Bd3", "c5", "c3", "Be7", "O-O", "O-O", "h3",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante d'échange — 3.exd5", "Exchange Variation — 3.exd5")},
            "moves": [
                "e4", "e6", "d4", "d5", "exd5", "exd5",
                {"san": "Nc3",
                 "comment": c("Un Blanc sur cinq développe le cavalier dame en premier, et le cours ne voyait que Cf3. La différence compte : le cavalier c3 gêne le pion c2, donc la rupture c4.",
                              "One White player in five develops the queen's knight first, and the course only saw Nf3. The difference matters: the c3 knight blocks the c2 pawn, and so the c4 break."),
                 "critical": True},
                "Nf6",
                {"san": "Nf3",
                 "comment": c("Les Blancs n'ont plus de plan actif. L'échange en d5 a la réputation d'être nul : elle est méritée dès que le camp blanc renonce à c4.",
                              "White has no active plan left. The Exchange has a drawish reputation: it is deserved as soon as White gives up on c4.")},
                "Bd6", "Bd3", "O-O", "O-O", "c6", "h3", "Nbd7", "Re1",
            ],
        },
        {
            "chapter": {"id": "exchange", "title": c("Variante d'échange — 3.exd5", "Exchange Variation — 3.exd5")},
            "moves": [
                "e4", "e6", "d4", "d5", "exd5", "exd5",
                {"san": "Bd3",
                 "comment": c("Le fou avant les cavaliers — un Blanc sur sept, et le cours ne l'avait pas prévu. Il vise h7, mais rien ne s'y trouve encore.",
                              "The bishop before the knights — one White player in seven, and the course had not planned for it. It eyes h7, but nothing is there yet."),
                 "critical": True},
                {"san": "c5",
                 "comment": c("On frappe le centre tant qu'il n'est pas soutenu. Dans l'échange, c'est le camp qui rompt le premier avec profit qui prend l'initiative.",
                              "We hit the centre while it is unsupported. In the Exchange, whoever breaks first and profitably takes the initiative."),
                 "critical": True},
                "Nf3",
                {"san": "c4",
                 "comment": c("On pousse plutôt que d'échanger : le fou d3 doit reculer, et notre majorité à l'aile dame prend de l'avance.",
                              "We push rather than trade: the d3 bishop must retreat, and our queenside majority gets a head start."),
                 "critical": True},
                "Be2", "Nf6", "O-O", "Be7", "b3", "cxb3", "axb3",
            ],
        },
        {
            "chapter": {"id": "advance", "title": c("Variante d'avance — 3.e5", "Advance Variation — 3.e5")},
            "moves": [
                "e4", "e6", "d4", "d5", "e5", "c5",
                {"san": "Nf3",
                 "comment": c("Un Blanc sur cinq développe au lieu de soutenir d4 par c3, et le cours ne prévoyait que c3. Le pion d4 reste alors sous-défendu.",
                              "One White player in five develops instead of propping up d4 with c3, and the course only planned for c3. The d4 pawn is then underdefended."),
                 "critical": True},
                {"san": "cxd4",
                 "comment": c("On prend tout de suite : sans c3, les Blancs devront reprendre d'une pièce, et leur centre avancé perd son point d'appui.",
                              "We take at once: without c3, White must recapture with a piece, and their advanced centre loses its anchor."),
                 "critical": True},
                "Bd3", "Ne7", "O-O", "Nec6", "Nbd2", "g6", "Nb3", "Bg7", "Bf4",
            ],
        },
        {
            "chapter": {"id": "vs-nf3", "title": c("Contre 2.Cf3", "vs 2.Nf3")},
            "moves": [
                "e4", "e6", "Nf3", "d5", "e5", "c5",
                {"san": "d4",
                 "comment": c("Quatre Blancs sur dix soutiennent le centre par d4 plutôt que par c3, et le cours ne prévoyait que c3.",
                              "Four White players in ten support the centre with d4 rather than c3, and the course only planned for c3."),
                 "critical": True},
                "cxd4", "Bd3", "Nc6", "O-O", "a6", "Re1",
                {"san": "f6",
                 "comment": c("La rupture caractéristique de la Française : on attaque la tête de la chaîne de pions blanche. C'est le moment où la partie se décide, et il ne faut pas le manquer.",
                              "The French's signature break: we attack the head of White's pawn chain. This is where the game is decided, and the moment must not be missed."),
                 "critical": True},
                "Qe2", "Qc7", "exf6",
            ],
        },
    ],
}
