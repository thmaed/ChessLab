# -*- coding: utf-8 -*-
"""Système Londres (1.d4 + Ff4) + Jobava Londres — répertoire BLANC.

Arbre approfondi : Londres contre …d5 (plan Ce5 + attaque), Jobava 2.Cc3,
contre le fianchetto …g6, et contre …c5 (avec le piège …Db6). Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "london-system",
    "name": "London System",
    "side": "white",
    "level": "club",
    "eco": ["D02", "A48"],
    "summary": c(
        "Un système facile à jouer contre presque tout : Ff4, e3, Fd3, c3, Cbd2. Peu de théorie, des plans solides et une attaque à l'aile roi souvent au menu.",
        "An easy system against almost everything: Bf4, e3, Bd3, c3, Nbd2. Little theory, solid plans and a kingside attack often on the menu.",
    ),
    "lines": [
        # 1) Londres contre …d5 (ligne principale)
        {
            "chapter": {"id": "main", "title": c("Londres contre …d5", "London vs …d5")},
            "moves": [
                "d4", "d5",
                {"san": "Bf4", "eco": "London System",
                 "comment": c("Le coup-signature : le fou sort AVANT e3, jamais enfermé.",
                              "The signature move: the bishop develops BEFORE e3, never shut in.")},
                "Nf6", "e3", "e6", "Nf3", "c5", "c3", "Nc6",
                {"san": "Nbd2", "comment": c("La formation type est complète ; suivra Fd3, puis Ce5 et une attaque.",
                                             "The standard formation is complete; Bd3 follows, then Ne5 and an attack.")},
                "Bd6",
                {"san": "Bg3", "comment": c("On garde le bon fou en le glissant en g3 plutôt que de l'échanger.",
                                            "Keep the good bishop by sliding it to g3 rather than trading.")},
                "O-O", "Bd3", "b6",
                {"san": "Ne5", "comment": c("Le cavalier s'installe sur son avant-poste : c'est le pivot de l'attaque londonienne.",
                                            "The knight lands on its outpost: the pivot of the London attack.")},
                "Bb7", "f4",
                {"san": "Ne7",
                 "comment": c("Les Noirs réorientent vers f5 pour contester g3 : c'est la bonne défense, …Ce4 f4 laisse le fou b7 muet après l'échange.",
                              "Black reroutes to f5 to challenge g3: that's the right defence — …Ne4 leaves the b7 bishop mute after the trade.")},
                "Qf3", "Nf5", "Bf2",
            ],
        },
        # 2) Jobava Londres — 2.Cc3
        {
            "chapter": {"id": "jobava", "title": c("Jobava Londres — 2.Cc3", "Jobava London — 2.Nc3")},
            "moves": [
                "d4", "Nf6",
                {"san": "Nc3", "comment": c("La version Jobava, plus mordante : le cavalier sort avant, prêt à jouer e4 ou Cb5.",
                                            "The sharper Jobava version: the knight develops first, ready for e4 or Nb5.")},
                "d5", "Bf4",
                {"san": "a6", "comment": c("Les Noirs préviennent le saut Cb5-c7 avant de continuer.",
                                           "Black rules out the Nb5-c7 jump before continuing.")},
                "e3", "e6", "Bd3", "c5", "dxc5", "Bxc5", "Nf3", "Nc6", "O-O", "O-O",
            ],
        },
        # 3) Contre le fianchetto …g6
        {
            "chapter": {"id": "vs-kid", "title": c("Contre le fianchetto — …g6", "vs the fianchetto — …g6")},
            "moves": [
                "d4", "Nf6", "Bf4", "g6",
                {"san": "Nc3", "comment": c("Contre …g6, la Londres tient très bien : e3, h4-h5 est même possible.",
                                            "Against …g6 the London holds up well: e3, and even h4-h5 is on.")},
                "d5", "e3", "Bg7",
                {"san": "h4", "comment": c("La ruée h4-h5 vise directement le roque adverse — la Londres a des dents.",
                                           "The h4-h5 rush aims straight at the enemy castled king — the London has teeth.")},
                "h5", "Bd3", "O-O", "Nf3", "c5",
            ],
        },
        # 4) Contre …c5 (et le piège …Db6)
        {
            "chapter": {"id": "vs-c5", "title": c("Contre …c5", "vs …c5")},
            "moves": [
                "d4", "Nf6", "Bf4", "c5", "e3",
                {"san": "Qb6", "comment": c("Le coup piquant : la dame attaque b2. Il faut connaître la parade.",
                                            "The pesky move: the queen hits b2. You must know the reply.")},
                {"san": "Nc3", "comment": c("On développe en menaçant Cb5 ; prendre b2 devient très dangereux pour les Noirs.",
                                            "Develop while threatening Nb5; grabbing b2 becomes very risky for Black.")},
                "e6", "Rb1", "Nc6", "Nf3", "Be7", "Bd3", "O-O", "O-O", "cxd4",
            ],
        },
        {
            "chapter": {"id": "vs-c5", "title": c("Contre …c5", "vs …c5")},
            "moves": [
                "d4", "Nf6", "Bf4", "c5", "e3", "Qb6", "Nc3",
                {"san": "Qxb2", "role": "inaccuracy", "critical": True,
                 "comment": c("Trop gourmand : prendre b2 laisse la dame se faire piéger.",
                              "Too greedy: grabbing b2 lets the queen get trapped.")},
                {"san": "Nb5", "role": "trap",
                 "comment": c("La réfutation : Cb5 menace Cc7+ fourchette, et la dame en b2 manque de cases. À éviter côté noir !",
                              "The refutation: Nb5 threatens the Nc7+ fork, and the b2-queen is short of squares. Avoid it as Black!")},
                {"san": "Na6",
                 "comment": c("La défense naturelle — et perdante. Voir l'autre variante pour …Cd5, la seule qui tient.",
                              "The natural defence — and a losing one. See the other line for …Nd5, the only move that holds.")},
                {"san": "a3", "critical": True,
                 "comment": c("Le vrai coup : a3 ferme la case a2 AVANT Tb1. Joué dans l'autre ordre, 6.Tb1 Dxa2 et la dame s'échappe.",
                              "The real move: a3 shuts the a2 square BEFORE Rb1. In the other order, 6.Rb1 Qxa2 and the queen slips away.")},
                "Nd5", "Rb1", "Qa2", "c4",
            ],
        },
        # La défense qui TIENT après 5.Cb5 — sans elle, le chapitre laissait
        # croire que le piège gagne par la force. Il ne gagne que contre …Ca6.
        {
            "chapter": {"id": "vs-c5", "title": c("Contre …c5", "vs …c5")},
            "moves": [
                "d4", "Nf6", "Bf4", "c5", "e3", "Qb6", "Nc3", "Qxb2", "Nb5",
                {"san": "Nd5", "critical": True,
                 "comment": c("LE coup à connaître des deux côtés : le cavalier couvre c7 et rouvre une case à la dame. Le piège ne gagne pas par la force.",
                              "THE move to know from both sides: the knight covers c7 and reopens a square for the queen. The trap does not win by force.")},
                "Rb1", "Qxa2", "Ra1",
                {"san": "Qb2",
                 "comment": c("Répétition : les Blancs gardent une petite initiative, mais rien de plus. Le vrai gain se joue contre 5…Ca6.",
                              "Repetition: White keeps a small initiative, nothing more. The real win only comes against 5…Na6.")},
            ],
        },

        # ── Trous de couverture comblés le 16/08 ──────────────────────────────
        #
        # Le relevé montrait quatre entrées distinctes ; deux ne sont que des
        # ORDRES DE COUPS qui rejoignent des chapitres déjà écrits. Le graphe
        # étant indexé par FEN, il suffit d'atteindre la position : elle est
        # déjà meublée.
        {
            "chapter": {"id": "move-orders", "title": c("Ordres de coups", "Move orders")},
            "moves": [
                "d4",
                {"san": "Nf6",
                 "comment": c("Les Noirs commencent souvent par le cavalier plutôt que par …d5. Rien ne change pour nous : le fou sort quand même en premier.",
                              "Black often starts with the knight rather than …d5. Nothing changes for us: the bishop still comes out first.")},
                "Bf4",
                {"san": "d5",
                 "comment": c("Et l'on retombe sur la ligne principale. Un joueur de Londres ne devrait jamais être surpris par l'ordre : le plan est le même.",
                              "And we're back in the main line. A London player should never be thrown by the move order: the plan is identical.")},
            ],
        },
        {
            "chapter": {"id": "move-orders", "title": c("Ordres de coups", "Move orders")},
            "moves": [
                "d4", "Nf6", "Bf4",
                {"san": "e6",
                 "comment": c("Même chose avec …e6 d'abord : très fréquent, et sans conséquence.",
                              "Same with …e6 first: very common, and of no consequence.")},
                "e3",
                {"san": "d5",
                 "comment": c("Ligne principale, une fois de plus. On enchaîne Cf3, c3, Cbd2.",
                              "Main line once again. Nf3, c3, Nbd2 follow.")},
            ],
        },
        {
            "chapter": {"id": "vs-kid", "title": c("Contre le fianchetto — …g6", "vs the fianchetto — …g6")},
            "moves": [
                "d4", "Nf6", "Bf4", "g6", "Nc3",
                {"san": "Bg7",
                 "comment": c("Le fou avant …d5 : c'est ce que jouent quatre Noirs sur cinq ici, et le chapitre partait de l'autre ordre.",
                              "The bishop before …d5: four Black players in five do this, and the chapter started from the other order.")},
                "e3",
                {"san": "d5",
                 "comment": c("Position identique à celle du chapitre principal contre le fianchetto. Rien de neuf : e3 puis h4-h5.",
                              "The very same position as the main anti-fianchetto chapter. Nothing new: e3 then h4-h5.")},
            ],
        },

        # ── Jobava : ce que devient 2.Cc3 quand les Noirs ne jouent pas …d5 ───
        {
            "chapter": {"id": "jobava", "title": c("Jobava Londres — 2.Cc3", "Jobava London — 2.Nc3")},
            "moves": [
                "d4", "Nf6", "Nc3",
                {"san": "g6",
                 "comment": c("Les Noirs partent au fianchetto. Le moteur propose e4 — mais ce serait quitter la Londres pour une Pirc : on reste chez nous.",
                              "Black heads for the fianchetto. The engine likes e4 — but that means leaving the London for a Pirc: we stay home.")},
                {"san": "Bf4",
                 "comment": c("Le fou sort, comme toujours. La position reste équilibrée et, elle, se joue avec des repères connus.",
                              "The bishop comes out, as always. The position stays balanced — and it plays with familiar landmarks."),
                 "critical": True},
                "d5",
                {"san": "Qd2",
                 "comment": c("La dame prépare le grand roque : c'est la version mordante du Jobava, avec attaque sur l'aile roi.",
                              "The queen prepares long castling: this is the sharp Jobava, with a kingside attack to follow.")},
                "c5", "dxc5", "Nc6",
                {"san": "O-O-O",
                 "comment": c("Rois opposés, jeu tranchant. On sait où frapper ; l'adversaire, souvent, pas encore.",
                              "Opposite castling, sharp play. We know where to strike; the opponent often doesn't yet.")},
            ],
        },
        {
            "chapter": {"id": "jobava", "title": c("Jobava Londres — 2.Cc3", "Jobava London — 2.Nc3")},
            "moves": [
                "d4", "Nf6", "Nc3",
                {"san": "e6",
                 "comment": c("Sans …a6, les Noirs oublient la menace que tout le chapitre annonçait.",
                              "Without …a6, Black forgets the very threat this chapter announced.")},
                "Bf4", "d5",
                {"san": "Nb5", "critical": True,
                 "comment": c("Et voilà le saut promis. La ligne principale voyait les Noirs jouer …a6 pour l'empêcher ; ici ils ne l'ont pas fait, et c7 est faible.",
                              "There's the promised jump. In the main line Black plays …a6 to stop it; here they didn't, and c7 is weak.")},
                "Na6",
                {"san": "e3",
                 "comment": c("On consolide sans se presser : le cavalier a6 est mal placé, l'avantage de développement est durable.",
                              "Consolidate without hurrying: the a6 knight is offside and the lead in development is lasting.")},
            ],
        },

        # ── 2…Cc6 : le coup qui vise directement le fou ───────────────────────
        {
            "chapter": {"id": "vs-nc6", "title": c("Contre …Cc6", "vs …Nc6")},
            "moves": [
                "d4", "d5", "Bf4",
                {"san": "Nc6",
                 "comment": c("Un coup d'apparence anodine, joué dans près d'une partie sur quatre, et que le répertoire ne traitait pas.",
                              "An innocuous-looking move, played in nearly one game in four, and untreated by this repertoire.")},
                "e3", "Nf6", "Nf3",
                {"san": "Nh5", "critical": True,
                 "comment": c("LE coup à connaître : les Noirs veulent échanger notre bon fou. Ne pas le laisser filer en h5 par distraction.",
                              "THE move to know: Black wants to trade off our good bishop. Don't lose track of it on h5.")},
                {"san": "Bg3",
                 "comment": c("Le fou recule et reste sur la diagonale. On ne l'échange jamais volontairement — c'est la pièce qui donne son nom au système.",
                              "The bishop steps back and keeps the diagonal. We never trade it willingly — it's the piece the system is named for.")},
                "Nxg3",
                {"san": "hxg3",
                 "comment": c("On reprend vers le centre ET on ouvre la colonne h. L'échange que les Noirs cherchaient nous a rendu service.",
                              "Recapture towards the centre AND open the h-file. The trade Black wanted has done us a favour."),
                 "critical": True},
            ],
        },

        # ── Trous comblés le 22/08 : les cinq réponses noires les plus jouées
        # qu'aucun chapitre n'atteignait (coverage.py, dette 1,47). Lignes au
        # moteur (suggest.py, profondeur 22, deux candidats comparés). ─────────
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "d4", "d5", "Bf4",
                {"san": "e6",
                 "comment": c("Le coup le plus joué contre la London après 2.Ff4 — un joueur sur cinq — et le cours ne voyait que …Cf6 et …Cc6. Les Noirs enferment leur fou dame pour contester la diagonale.",
                              "The most played move against the London after 2.Bf4 — one player in five — and the course only saw …Nf6 and …Nc6. Black shuts in their own queen's bishop to contest the diagonal."),
                 "critical": True},
                "Nf3", "c5", "e3", "Nf6",
                {"san": "c3",
                 "comment": c("Le triangle d4-e3-c3 : la structure de la London. Elle ne cherche pas l'avantage d'ouverture, elle cherche une position qu'on sait jouer les yeux fermés.",
                              "The d4-e3-c3 triangle: the London structure. It is not after an opening advantage, it is after a position you can play with your eyes closed.")},
                {"san": "Bd6",
                 "comment": c("Les Noirs proposent l'échange du fou qui fait toute la London. C'est leur meilleure idée dans ce système.",
                              "Black offers to trade the bishop the whole London is built on. It is their best idea against this setup."),
                 "critical": True},
                {"san": "Bb5+",
                 "comment": c("Un échec intercalé avant de décider : on gagne un temps et on force les Noirs à préciser leur défense avant qu'on ne prenne en d6.",
                              "An in-between check before deciding: we gain a tempo and force Black to commit before we take on d6.")},
                "Nc6", "Bxd6", "Qxd6",
            ],
        },
        {
            "chapter": {"id": "vs-d5", "title": c("Contre …d5", "vs …d5")},
            "moves": [
                "d4", "d5", "Bf4",
                {"san": "Bf5",
                 "comment": c("Les Noirs jouent la London à l'envers : leur fou sort avant …e6, exactement comme le nôtre. Un joueur sur sept, et le cours n'en disait rien.",
                              "Black plays the London in reverse: their bishop comes out before …e6, exactly like ours. One player in seven, and the course said nothing."),
                 "critical": True},
                {"san": "c4",
                 "comment": c("Puisque les Noirs ont sorti le fou plutôt que de tenir le centre, on frappe d5 tout de suite : c'est le moment où ce coup a le plus de valeur.",
                              "Since Black developed the bishop instead of holding the centre, we hit d5 at once: this is the moment when that move is worth the most."),
                 "critical": True},
                "e6", "e3", "Nf6", "Nd2", "c5", "cxd5", "exd5", "Bb5+", "Nbd7",
            ],
        },
        {
            "chapter": {"id": "vs-nf6", "title": c("Contre …Cf6", "vs …Nf6")},
            "moves": [
                "d4", "Nf6", "Bf4",
                {"san": "d6",
                 "comment": c("Les Noirs préparent …e5 pour chasser le fou f4 — c'est le plan le plus direct contre la London, et le cours ne l'avait pas prévu.",
                              "Black prepares …e5 to kick the f4 bishop — the most direct plan against the London, and the course had not planned for it."),
                 "critical": True},
                {"san": "Nc3",
                 "comment": c("La version « Jobava » : on développe vers le centre plutôt que de reculer par précaution. Si les Noirs jouent …e5, on répondra d5 et le fou trouvera une autre diagonale.",
                              "The “Jobava” version: we develop towards the centre instead of retreating for safety. If Black plays …e5 we answer d5, and the bishop finds another diagonal.")},
                "Nbd7", "Nf3", "c5",
                {"san": "d5",
                 "comment": c("On ferme au lieu d'échanger : les Noirs se retrouvent avec un cavalier d7 sans case et un fou f8 qui attend son heure derrière ses propres pions.",
                              "We close instead of trading: Black is left with a d7 knight without a square and an f8 bishop waiting behind its own pawns."),
                 "critical": True},
                "Qa5", "a4", "Ne4", "Qd3", "Ndf6",
            ],
        },
        {
            "chapter": {"id": "vs-kid", "title": c("Contre le fianchetto roi", "vs the King's fianchetto")},
            "moves": [
                "d4", "Nf6", "Bf4", "g6", "Nc3", "Bg7", "e3",
                {"san": "O-O",
                 "comment": c("Une partie sur deux passe par ce roque, et le chapitre enchaînait directement sur …d5. Le roi noir est en place ; le nôtre va suivre.",
                              "One game in two goes through this castling, and the chapter jumped straight to …d5. Black's king is home; ours will follow."),
                 "critical": True},
                "Nf3", "d5", "Be2", "c5", "O-O", "b6",
                {"san": "Nb1",
                 "comment": c("Un retour de cavalier qui surprend, et pourtant logique : le cavalier c3 n'a plus rien à faire là, il repart vers d2 puis f3 ou b3, selon l'aile où la partie se jouera.",
                              "A knight retreat that surprises, and yet makes sense: the c3 knight has nothing left to do there, so it heads back to d2 and then f3 or b3, depending on which wing the game turns on."),
                 "critical": True},
                "Nh5", "Be5", "Nf6",
            ],
        },
        {
            "chapter": {"id": "vs-jobava", "title": c("London Jobava — 3.Cc3", "Jobava London — 3.Nc3")},
            "moves": [
                "d4", "d5", "Bf4", "Nf6", "Nc3",
                {"san": "e6",
                 "comment": c("Un Noir sur quatre joue ce coup naturel — et il permet précisément ce que …a6, la seule réponse que le cours connaissait, cherchait à empêcher.",
                              "One Black player in four plays this natural move — and it allows exactly what …a6, the only reply the course knew, was designed to prevent."),
                 "critical": True},
                {"san": "Nb5",
                 "comment": c("Voilà l'idée de toute la London Jobava : le cavalier saute vers c7, où roi et tour se croisent. Les Noirs doivent réagir tout de suite, et chaque réponse concède quelque chose.",
                              "Here is the whole point of the Jobava London: the knight jumps at c7, where king and rook cross. Black must react at once, and every reply concedes something."),
                 "critical": True},
                "Bb4+", "c3", "Ba5", "a4",
                {"san": "a6",
                 "comment": c("Les Noirs chassent enfin le cavalier, mais un temps trop tard : la position s'est ouverte à notre avantage pendant qu'ils s'en occupaient.",
                              "Black finally kicks the knight, but a tempo too late: the position has opened in our favour while they were busy with it.")},
                "b4", "Bxb4", "cxb4", "axb5",
            ],
        },
    ],
}
