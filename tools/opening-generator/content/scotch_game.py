# -*- coding: utf-8 -*-
"""Partie écossaise (1.e4 e5 2.Cf3 Cc6 3.d4) — répertoire BLANC.

Approfondie : Mieses, classique 4…Fc5, Steinitz 4…Dh4, gambit écossais.
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "scotch-game",
    "name": "Scotch Game",
    "side": "white",
    "level": "club",
    "eco": ["C44", "C45"],
    "summary": c(
        "On ouvre le centre tout de suite avec 3.d4 : jeu clair, pièces actives, peu de théorie lourde. Idéal pour prendre l'initiative sans mémoriser des tonnes de lignes.",
        "Open the centre at once with 3.d4: clear play, active pieces, little heavy theory. Ideal for seizing the initiative without memorising tons of lines.",
    ),
    "lines": [
        {
            "chapter": {"id": "mieses", "title": c("Variante Mieses", "Mieses Variation")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "d4", "comment": c("Le cœur de l'Écossaise : on brise le centre immédiatement.",
                                           "The heart of the Scotch: break the centre immediately.")},
                "exd4",
                {"san": "Nxd4", "eco": "Scotch Game",
                 "comment": c("Bien centralisé, le cavalier domine le milieu de l'échiquier.",
                              "Well centralised, the knight dominates the middle of the board.")},
                "Nf6",
                {"san": "Nxc6", "comment": c("La ligne moderne de Mieses : on échange puis on pousse e5.",
                                             "The modern Mieses line: trade, then push e5.")},
                "bxc6", "e5",
                {"san": "Qe7", "comment": c("Le seul bon coup : la dame attaque e5 et prépare …Cd5.",
                                            "The only good move: the queen hits e5 and prepares …Nd5.")},
                "Qe2", "Nd5", "c4", "Ba6", "b3", "g6",
            ],
        },
        {
            "chapter": {"id": "classical", "title": c("Variante classique — 4…Fc5", "Classical — 4…Bc5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4", "Nxd4",
                {"san": "Bc5", "comment": c("Les Noirs attaquent le cavalier d4 avec développement.",
                                            "Black hits the d4 knight while developing.")},
                {"san": "Be3", "comment": c("On défend d4 et on prépare c3 : la case f2 reste solide.",
                                            "Defend d4 and prepare c3: the f2 square stays solid.")},
                "Qf6", "c3", "Nge7", "Bc4", "Ne5", "Be2", "Qg6", "O-O", "d6",
            ],
        },
        {
            "chapter": {"id": "steinitz", "title": c("Variante Steinitz — 4…Dh4", "Steinitz — 4…Qh4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4", "Nxd4",
                {"san": "Qh4", "role": "sideline", "critical": True,
                 "eco": "Scotch Game: Steinitz Variation",
                 "comment": c("La sortie provocante de la dame vise e4 et g2 ; les Blancs se développent avec des tempos.",
                              "The provocative queen sortie eyes e4 and g2; White develops with tempo.")},
                {"san": "Nc3", "comment": c("On développe et on prépare Cde2 ou Fe2, sans céder à la panique.",
                                            "Develop and prepare Nde2 or Be2, without panicking.")},
                "Bb4", "Be2", "Qxe4", "Ndb5",
            ],
        },
        {
            "chapter": {"id": "scotch-gambit", "title": c("Gambit écossais — 4.Fc4", "Scotch Gambit — 4.Bc4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4",
                {"san": "Bc4", "role": "sideline", "eco": "Scotch Gambit",
                 "comment": c("Le Gambit écossais : au lieu de reprendre, on développe vite et on vise f7.",
                              "The Scotch Gambit: instead of recapturing, develop fast and target f7.")},
                "Nf6", "e5", "d5", "Bb5", "Ne4", "Nxd4", "Bc5",
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

        # ── Trous comblés le 22/08 (coverage.py, dette 0,94). Chemins par
        # `path_to_hole.py`, lignes au moteur à profondeur 21. ───────────────
        {
            "chapter": {"id": "scotch-main", "title": c("Écossaise — ligne principale", "Scotch — main line")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4", "Nxd4",
                {"san": "Nxd4",
                 "comment": c("L'échange le plus joué de toute l'Écossaise — deux Noirs sur cinq — et le cours ne connaissait que …Cf6, …Fc5 et …Dh4. Les Noirs simplifient pour finir leur développement en paix.",
                              "The most played exchange in the whole Scotch — two Black players in five — and the course only knew …Nf6, …Bc5 and …Qh4. Black simplifies to finish developing in peace."),
                 "critical": True},
                {"san": "Qxd4",
                 "comment": c("La dame au centre ne craint rien ici : aucun cavalier noir ne peut la déloger avec gain de temps, c'est précisément ce que l'échange a supprimé.",
                              "The queen in the centre is quite safe here: no black knight can dislodge her with tempo — that is exactly what the trade removed."),
                 "critical": True},
                "Qf6",
                {"san": "Qe3",
                 "comment": c("On refuse l'échange des dames. Les Noirs ont encore leur roi au centre et deux pièces à développer : garder les dames, c'est garder la pression.",
                              "We decline the queen trade. Black still has a king in the centre and two pieces to develop: keeping queens keeps the pressure.")},
                "Bb4+", "c3", "Ba5", "Qg3", "Ne7", "a4", "a6",
            ],
        },
        {
            "chapter": {"id": "scotch-gambit", "title": c("Gambit écossais — 4.Fc4", "Scotch Gambit — 4.Bc4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4", "Bc4",
                {"san": "Bc5",
                 "comment": c("Les Noirs défendent d4 par la pièce plutôt que de le rendre. Un Noir sur quatre, et le cours ne prévoyait que …Cf6.",
                              "Black defends d4 with a piece rather than giving it back. One Black player in four, and the course only planned for …Nf6."),
                 "critical": True},
                {"san": "c3",
                 "comment": c("On offre un second pion pour ouvrir la colonne c et la diagonale : c'est l'esprit du gambit écossais, le temps vaut plus que le matériel tant que le roi noir est au centre.",
                              "We offer a second pawn to open the c-file and the diagonal: the spirit of the Scotch Gambit — time is worth more than material while Black's king sits in the centre."),
                 "critical": True},
                "Nf6", "cxd4", "Bb4+", "Bd2", "Nxe4", "Bxb4", "Nxb4",
                {"san": "Bxf7+",
                 "comment": c("Le coup à connaître : l'échec découvre la dame sur le cavalier e4. Les Noirs récupèrent le matériel mais leur roi a perdu le roque pour de bon.",
                              "The move to know: the check uncovers the queen against the e4 knight. Black regains the material but their king has lost castling for good."),
                 "critical": True},
                "Kxf7",
            ],
        },
        {
            "chapter": {"id": "scotch-gambit", "title": c("Gambit écossais — 4.Fc4", "Scotch Gambit — 4.Bc4")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "d4", "exd4", "Bc4",
                {"san": "h6",
                 "comment": c("Un coup d'attente prudent — près d'un Noir sur cinq — qui empêche Cg5 mais laisse d4 en plan. Le cours n'en disait rien.",
                              "A cautious waiting move — nearly one Black player in five — stopping Ng5 but leaving d4 hanging. The course said nothing about it."),
                 "critical": True},
                {"san": "Nxd4",
                 "comment": c("Puisqu'ils ne défendent pas, on reprend simplement : le gambit n'a plus lieu d'être, on joue une Écossaise ordinaire avec un temps d'avance offert.",
                              "Since they do not defend it, we simply take it back: there is no gambit any more, we play an ordinary Scotch with a free tempo."),
                 "critical": True},
                "Nf6", "Nxc6", "bxc6", "Nc3", "d6", "Qe2", "Be7", "Be3", "Ng4",
            ],
        },
        {
            "chapter": {"id": "vs-petrov", "title": c("Contre la Petroff — 2…Cf6", "vs the Petrov — 2…Nf6")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "Nf6",
                 "comment": c("La Petroff : les Noirs contre-attaquent au lieu de défendre e5. Le cours ne prévoyait que …Cc6 et …d6 — or un joueur sur dix choisit celle-ci, et il faut savoir quoi en faire.",
                              "The Petrov: Black counterattacks instead of defending e5. The course only planned for …Nc6 and …d6 — yet one player in ten picks this, and you need an answer."),
                 "critical": True},
                {"san": "Nxe5",
                 "comment": c("On prend, et il faut connaître le piège qui suit : reprendre tout de suite par …Cxe4 perd la dame après Dе2. C'est …d6 d'abord, toujours.",
                              "We take, and the trap that follows must be known: recapturing at once with …Nxe4 loses the queen to Qe2. It is …d6 first, always."),
                 "critical": True},
                "d6", "Nf3", "Nxe4", "d4", "d5", "Bd3", "Bd6", "O-O", "O-O",
            ],
        },
        {
            "chapter": {"id": "vs-philidor", "title": c("Contre la Philidor — 2…d6", "vs the Philidor — 2…d6")},
            "moves": [
                "e4", "e5", "Nf3", "d6", "d4",
                {"san": "exd4",
                 "comment": c("Près de six Noirs sur dix relâchent la tension ici, et le cours ne voyait que …Cd7. Ils nous donnent le centre pour éviter d'être étouffés.",
                              "Nearly six Black players in ten release the tension here, and the course only saw …Nd7. They hand us the centre to avoid being squeezed."),
                 "critical": True},
                "Nxd4", "c5",
                {"san": "Nb3",
                 "comment": c("Le cavalier recule au lieu de s'échanger : le pion c5 a affaibli d5 et b5, deux cases que nos pièces vont occuper sans être dérangées.",
                              "The knight retreats rather than trade: the c5 pawn has weakened d5 and b5, two squares our pieces will occupy undisturbed."),
                 "critical": True},
                "Nf6", "Nc3", "Be6", "Bf4", "Nc6", "Qd2", "Be7",
            ],
        },
    ],
}
