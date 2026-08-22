# -*- coding: utf-8 -*-
"""Anti-siciliennes (1.e4 c5, quand les Blancs évitent 2.Cf3/3.d4) — NOIR.

Ce que le joueur de club affronte VRAIMENT face à la sicilienne : Alapin
(2…d5 et 2…Cf6), Rossolimo (…g6 et …e6), Moscou (…Fd7 et …Cd7), Grand Prix,
gambit Smith-Morra, sicilienne fermée, gambit de l'aile. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "anti-sicilians",
    "name": "Anti-Sicilians",
    "side": "black",
    "level": "club",
    "eco": ["B20", "B29"],
    "summary": c(
        "La plupart des adversaires de club fuient la sicilienne ouverte. Voici les réponses saines aux Alapin, Rossolimo, Grand Prix, Smith-Morra et compagnie.",
        "Most club opponents dodge the Open Sicilian. Here are sound answers to the Alapin, Rossolimo, Grand Prix, Smith-Morra and friends.",
    ),
    "lines": [
        # 1) Alapin 2.c3 — 2…d5 (ligne principale)
        {
            "chapter": {"id": "alapin", "title": c("Alapin — 2.c3", "Alapin — 2.c3")},
            "moves": [
                "e4", "c5",
                {"san": "c3", "eco": "Sicilian Defense: Alapin Variation",
                 "comment": c("L'Alapin : les Blancs préparent d4 sans se laisser prendre en d4. Frapper au centre est la clé.",
                              "The Alapin: White prepares d4 without allowing …cxd4 tricks. Striking the centre is the key.")},
                {"san": "d5", "comment": c("La réponse la plus simple : on ouvre et on égalise proprement.",
                                           "The simplest reply: open up and equalise cleanly.")},
                "exd5", "Qxd5",
                {"san": "d4", "comment": c("Les Blancs gagnent un temps sur la dame en poussant d4.",
                                           "White gains a tempo on the queen by pushing d4.")},
                "Nf6", "Nf3", "e6",
                {"san": "Be2", "comment": c("Chacun développe ; il naîtra une structure de pion dame isolé (IQP) équilibrée.",
                                            "Both sides develop; a balanced isolated queen's-pawn (IQP) structure arises.")},
                "Nc6", "O-O", "cxd4", "cxd4", "Be7", "Nc3", "Qd6",
            ],
        },
        # 2) Alapin — 2…Cf6
        {
            "chapter": {"id": "alapin-nf6", "title": c("Alapin — 2…Cf6", "Alapin — 2…Nf6")},
            "moves": [
                "e4", "c5", "c3",
                {"san": "Nf6", "comment": c("L'autre grande réponse : on attaque e4 tout de suite.",
                                            "The other main reply: hit e4 immediately.")},
                {"san": "e5", "comment": c("Le pion avance ; le cavalier doit reculer en d5, où il sera bousculé.",
                                           "The pawn advances; the knight must go to d5, where it gets harassed.")},
                "Nd5", "d4", "cxd4", "Nf3", "Nc6", "cxd4", "d6",
                {"san": "Bc4", "comment": c("Le fou attaque le cavalier d5 ; les Noirs le repoussent et frappent e5.",
                                            "The bishop hits the d5-knight; Black kicks it and strikes at e5.")},
                "Nb6", "Bb3", "dxe5",
            ],
        },
        # 3) Rossolimo — 3…g6
        {
            "chapter": {"id": "rossolimo-g6", "title": c("Rossolimo — 3.Fb5 g6", "Rossolimo — 3.Bb5 g6")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6",
                {"san": "Bb5", "eco": "Sicilian Defense: Rossolimo Variation",
                 "comment": c("Le Rossolimo : les Blancs échangent en c6 pour jouer la structure. …g6 est fiable.",
                              "The Rossolimo: White trades on c6 to play the structure. …g6 is reliable.")},
                "g6", "Bxc6", "dxc6",
                {"san": "d3", "comment": c("Sans les dames actives, la paire de fous noire compense le pion doublé.",
                                           "With queens likely to come off, Black's bishop pair offsets the doubled pawn.")},
                "Bg7", "h3", "Nf6", "Nc3", "Nd7", "Be3", "e5",
            ],
        },
        # 4) Rossolimo — 3…e6
        {
            "chapter": {"id": "rossolimo-e6", "title": c("Rossolimo — 3.Fb5 e6", "Rossolimo — 3.Bb5 e6")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "Bb5",
                {"san": "e6", "comment": c("On garde la structure intacte et on chasse le fou par …a6/…b5.",
                                           "Keep the structure intact and chase the bishop with …a6/…b5.")},
                "O-O", "Nge7", "c3", "a6", "Ba4", "b5", "Bc2", "Bb7",
            ],
        },
        # 5) Moscou — 3.Fb5+ Fd7
        {
            "chapter": {"id": "moscow-bd7", "title": c("Moscou — 3.Fb5+ Fd7", "Moscow — 3.Bb5+ Bd7")},
            "moves": [
                "e4", "c5", "Nf3", "d6",
                {"san": "Bb5+", "eco": "Sicilian Defense: Moscow Variation",
                 "comment": c("La Moscou : l'échec en b5. …Fd7 est net et sans histoire.",
                              "The Moscow: the b5 check. …Bd7 is clean and trouble-free.")},
                "Bd7", "Bxd7+", "Qxd7", "O-O", "Nc6", "c3", "Nf6", "Re1", "e6", "d4", "cxd4", "cxd4", "d5",
            ],
        },
        # 6) Moscou — 3.Fb5+ Cd7
        {
            "chapter": {"id": "moscow-nd7", "title": c("Moscou — 3.Fb5+ Cd7", "Moscow — 3.Bb5+ Nd7")},
            "moves": [
                "e4", "c5", "Nf3", "d6", "Bb5+",
                {"san": "Nd7", "comment": c("La version combative : on garde le fou de cases claires pour …e5 et …Fe7.",
                                            "The combative version: keep the light bishop for …e5 and …Be7.")},
                "d4", "Ngf6", "Nc3", "cxd4", "Qxd4", "e5", "Qd3", "h6",
            ],
        },
        # 7) Gambit Smith-Morra — accepté
        {
            "chapter": {"id": "smith-morra", "title": c("Gambit Smith-Morra — 2.d4", "Smith-Morra Gambit — 2.d4")},
            "moves": [
                "e4", "c5",
                {"san": "d4", "comment": c("Le gambit Smith-Morra : un pion pour un développement rapide et des colonnes ouvertes.",
                                           "The Smith-Morra Gambit: a pawn for fast development and open files.")},
                "cxd4", "c3",
                {"san": "dxc3", "eco": "Sicilian Defense: Smith-Morra Gambit Accepted",
                 "comment": c("Accepter puis se défendre précisément neutralise le gambit.",
                              "Accept, then defend precisely to neutralise the gambit.")},
                "Nxc3", "Nc6", "Nf3", "d6",
                {"san": "Bc4", "comment": c("Le fou vise f7 ; les Noirs adoptent le dispositif défensif type.",
                                            "The bishop eyes f7; Black adopts the standard defensive setup.")},
                "e6", "O-O", "a6",
                {"san": "Qe2", "comment": c("Contre la pression sur e5/d5, la formation …a6, …Cf6, …Fe7, …0-0 tient bon.",
                                            "Against the pressure on e5/d5, the …a6, …Nf6, …Be7, …0-0 formation holds firm.")},
                "Nf6", "Rd1",
                {"san": "Qc7", "critical": True,
                 "comment": c("La dame AVANT le fou : …Fe7 tout de suite laisse e5 ! et les Blancs récupèrent tout avec intérêt.",
                              "The queen BEFORE the bishop: …Be7 at once allows e5! and White gets everything back with interest.")},
                "Bf4", "Be7", "Rac1", "O-O",
            ],
        },
        # 8) Attaque Grand Prix — 4…Fg7 5.Fb5
        {
            "chapter": {"id": "grand-prix", "title": c("Attaque Grand Prix — 2.Cc3 & f4", "Grand Prix Attack — 2.Nc3 & f4")},
            "moves": [
                "e4", "c5", "Nc3", "Nc6",
                {"san": "f4", "eco": "Sicilian Defense: Grand Prix Attack",
                 "comment": c("Le Grand Prix : les Blancs veulent f4-f5 et un assaut sur le roi. …g6 et …Fg7 contiennent l'attaque.",
                              "The Grand Prix: White wants f4-f5 and a kingside assault. …g6 and …Bg7 contain it.")},
                "g6", "Nf3", "Bg7",
                {"san": "Bb5", "comment": c("Le fou vient clouer/échanger en c6 pour affaiblir le contrôle noir du centre.",
                                            "The bishop comes to pin/trade on c6 to weaken Black's grip on the centre.")},
                "Nd4", "O-O", "Nxb5", "Nxb5", "d6",
            ],
        },
        # 9) Sicilienne fermée — 2.Cc3 & g3
        {
            "chapter": {"id": "closed", "title": c("Sicilienne fermée — 2.Cc3 & g3", "Closed Sicilian — 2.Nc3 & g3")},
            "moves": [
                "e4", "c5", "Nc3", "Nc6",
                {"san": "g3", "eco": "Sicilian Defense: Closed",
                 "comment": c("La fermée : jeu de manœuvre. Les Noirs prennent leur espace à l'aile dame par …Tb8 et …b5.",
                              "The Closed: a manoeuvring game. Black grabs queenside space with …Rb8 and …b5.")},
                "g6", "Bg2", "Bg7", "d3", "d6", "f4", "e6", "Nf3", "Nge7", "O-O", "O-O", "Be3", "Nd4",
            ],
        },
        # 10) Gambit de l'aile — 2.b4
        {
            "chapter": {"id": "wing-gambit", "title": c("Gambit de l'aile — 2.b4", "Wing Gambit — 2.b4")},
            "moves": [
                "e4", "c5",
                {"san": "b4", "comment": c("Le gambit de l'aile : un pion d'aile pour dévier le pion c et prendre le centre.",
                                           "The Wing Gambit: a flank pawn to deflect the c-pawn and grab the centre.")},
                "cxb4", "a3",
                {"san": "d5", "comment": c("La réfutation nette : on rend le pion pour ouvrir le centre et prendre l'initiative.",
                                           "The clean refutation: give the pawn back to open the centre and seize the initiative.")},
                "exd5", "Qxd5", "Nf3", "e5", "axb4", "Bxb4",
            ],
        },

        # ── Quand les Blancs jouent la Sicilienne OUVERTE (16/08) ─────────────
        #
        # Le relevé de couverture désigne 3.d4 comme le plus gros « trou » du
        # cours (51 % des parties). C'en est un au sens statistique, pas au sens
        # pédagogique : ce cours enseigne les DÉVIATIONS, et 3.d4 est la ligne
        # principale, traitée par les cours Sicilienne dédiés. Le combler
        # reviendrait à recopier un répertoire entier ici. On dit où l'on est,
        # et on renvoie — c'est ce qui manquait vraiment.
        {
            "chapter": {"id": "open-sicilian", "title": c("Si les Blancs jouent d4", "If White plays d4")},
            "moves": [
                "e4", "c5", "Nf3",
                {"san": "d6",
                 "comment": c("Un ordre de coups courant, qui laisse toutes les options ouvertes.",
                              "A common move order that keeps every option open.")},
                {"san": "d4",
                 "comment": c("Les Blancs refusent les déviations et entrent dans la Sicilienne ouverte : ce cours-ci s'arrête là. Les lignes qui suivent sont celles des cours Dragon, Najdorf et Scheveningue.",
                              "White declines the sidelines and enters the Open Sicilian: this course stops here. What follows belongs to the Dragon, Najdorf and Scheveningen courses."),
                 "critical": True},
                "cxd4", "Nxd4",
                {"san": "Nf6",
                 "comment": c("Position de départ de toute la Sicilienne ouverte. Si tu joues la Sicilienne pour de bon, c'est ce carrefour qu'il faut travailler ensuite.",
                              "The starting point of the whole Open Sicilian. If you play the Sicilian seriously, this is the junction to study next.")},
            ],
        },
        {
            "chapter": {"id": "bc4", "title": c("2.Fc4 — la sortie précoce", "2.Bc4 — the early bishop")},
            "moves": [
                "e4", "c5",
                {"san": "Bc4",
                 "comment": c("Vu dans une partie sur huit en club : les Blancs sortent le fou avant tout. C'est jouable, mais sans mordant.",
                              "Seen in one club game in eight: White develops the bishop first. Playable, but toothless."),
                 "critical": True},
                {"san": "e6",
                 "comment": c("La réfutation positionnelle : …e6 prépare …d5 et le fou c4 devra bouger une seconde fois.",
                              "The positional refutation: …e6 prepares …d5 and the c4 bishop will have to move a second time.")},
                "Nf3", "Nf6", "Qe2", "Nc6",
                {"san": "Bb5",
                 "comment": c("Le fou déménage déjà — deux temps perdus. Les Noirs égalisent sans effort.",
                              "The bishop is already relocating — two tempi gone. Black equalises without effort.")},
                "Nd4",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,89). Répertoire NOIR :
        # les trous sont des coups BLANCS. Le plus gros est 3.d4, la sicilienne
        # OUVERTE — hors sujet pour un cours d'anti-siciliennes, mais joué une
        # fois sur deux : on ouvre une porte honnête plutôt que de laisser le
        # lecteur sans rien. ─────────────────────────────────────────────────
        {
            "chapter": {"id": "open-sicilian-door", "title": c("Si les Blancs ouvrent — 3.d4", "If White opens up — 3.d4")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6",
                {"san": "d4",
                 "comment": c("La sicilienne OUVERTE, jouée près d'une fois sur deux — et ce cours ne parle pas d'elle : il traite des anti-siciliennes. Voici de quoi ne pas être perdu, pas un traitement complet. L'ouverte est un répertoire à elle seule.",
                              "The OPEN Sicilian, played nearly half the time — and this course is not about it: it covers the anti-Sicilians. What follows keeps you afloat, it is not a treatment. The Open Sicilian is a repertoire of its own."),
                 "critical": True},
                "cxd4", "Nxd4", "Nf6", "Nc3",
                {"san": "e5",
                 "comment": c("Le Sveshnikov : on chasse le cavalier d4 immédiatement et on accepte le trou en d5 contre un jeu de pièces très actif. C'est la ligne la plus facile à retenir pour qui vient des anti-siciliennes.",
                              "The Sveshnikov: we kick the d4 knight at once and accept the d5 hole in exchange for very active piece play. The easiest line to remember for someone coming from the anti-Sicilians."),
                 "critical": True},
                "Ndb5", "d6", "Bg5", "a6", "Na3",
            ],
        },
        {
            "chapter": {"id": "vs-bc4", "title": c("Contre 3.Fc4", "vs 3.Bc4")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6",
                {"san": "Bc4",
                 "comment": c("Un Blanc sur cinq sort le fou en c4, et le cours ne prévoyait que le Rossolimo 3.Fb5. Le fou vise f7 mais gêne peu : nous allons le prendre pour cible.",
                              "One White player in five puts the bishop on c4, and the course only planned for the Rossolimo 3.Bb5. The bishop eyes f7 but bothers little: we are going to make it a target."),
                 "critical": True},
                {"san": "Nf6",
                 "comment": c("On attaque e4 tout de suite. Si les Blancs poussent e5, leur pion sera faible et notre cavalier trouvera de bonnes cases.",
                              "We hit e4 at once. If White pushes e5, that pawn will be weak and our knight will find good squares.")},
                "e5", "Ng4", "Qe2", "f6",
                {"san": "exf6",
                 "comment": c("La position s'ouvre et c'est nous qui en profitons : le pion e5 avancé a disparu, et le fou c4 se retrouve face à un mur de pions noirs.",
                              "The position opens and we are the ones who benefit: the advanced e5 pawn is gone, and the c4 bishop faces a wall of black pawns."),
                 "critical": True},
                "Nxf6", "Nc3", "e6", "Nd5",
            ],
        },
        {
            "chapter": {"id": "vs-bc4", "title": c("Contre 3.Fc4", "vs 3.Bc4")},
            "moves": [
                "e4", "c5", "Nf3", "d6",
                {"san": "Bc4",
                 "comment": c("Le même fou, contre notre ordre …d6. Le cours ne connaissait que 3.Fb5+ et 3.d4.",
                              "The same bishop, against our …d6 move order. The course only knew 3.Bb5+ and 3.d4."),
                 "critical": True},
                "Nf6", "Nc3", "e6", "d4", "cxd4", "Nxd4",
                {"san": "a6",
                 "comment": c("Le coup de la Najdorf, et il est ici doublement utile : il prépare …b5 qui chassera le fou c4 de sa diagonale avec gain de temps.",
                              "The Najdorf move, doubly useful here: it prepares …b5, which will chase the c4 bishop off its diagonal with tempo."),
                 "critical": True},
                "Be3", "b5", "Bb3",
            ],
        },
        {
            "chapter": {"id": "alapin", "title": c("Alapin — 3.c3", "Alapin — 3.c3")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6",
                {"san": "c3",
                 "comment": c("L'Alapin par transposition : les Blancs préparent d4 sans jamais permettre …cxd4 suivi de Cxd4. Le cours ne le voyait pas venir dans cet ordre.",
                              "The Alapin by transposition: White prepares d4 without ever allowing …cxd4 and Nxd4. The course did not see it coming in this order."),
                 "critical": True},
                {"san": "d5",
                 "comment": c("La réfutation de principe : on frappe au centre avant que le grand centre blanc n'existe. Contre l'Alapin, attendre est toujours une erreur.",
                              "The principled answer: we strike in the centre before White's big centre exists. Against the Alapin, waiting is always a mistake."),
                 "critical": True},
                "exd5", "Qxd5", "d4", "Nf6", "dxc5",
                {"san": "Qxd1+",
                 "comment": c("On échange les dames volontairement : sans elles, le pion c5 avancé n'est plus un atout mais une faiblesse à récupérer tranquillement.",
                              "We trade queens deliberately: without them, the advanced c5 pawn stops being an asset and becomes a weakness to collect at leisure."),
                 "critical": True},
                "Kxd1", "Bf5", "Be3",
            ],
        },
        {
            "chapter": {"id": "rossolimo", "title": c("Rossolimo — 3.Fb5", "Rossolimo — 3.Bb5")},
            "moves": [
                "e4", "c5", "Nf3", "Nc6", "Bb5", "e6",
                {"san": "Bxc6",
                 "comment": c("Près d'un Blanc sur deux échange ici, et le cours ne prévoyait que le roque. Ils nous donnent la paire de fous contre des pions doublés.",
                              "Nearly one White player in two trades here, and the course only planned for castling. They hand us the bishop pair in exchange for doubled pawns."),
                 "critical": True},
                {"san": "bxc6",
                 "comment": c("On reprend du pion b, pas du pion d : la colonne b s'ouvre pour notre tour, et le pion c6 soutiendra …d5 le moment venu.",
                              "We recapture with the b-pawn, not the d-pawn: the b-file opens for our rook, and the c6 pawn will support …d5 when the time comes."),
                 "critical": True},
                "d3", "Qc7", "O-O", "e5",
                {"san": "c3",
                 "comment": c("Les Blancs préparent d4 pour ouvrir avant que nos fous ne respirent. C'est la course de cette structure : nos deux fous contre leur meilleure structure de pions.",
                              "White prepares d4 to open up before our bishops breathe. That is the race in this structure: our two bishops against their better pawn structure.")},
                "Ne7", "d4", "cxd4", "cxd4",
            ],
        },
    ],
}
