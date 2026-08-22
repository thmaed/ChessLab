# -*- coding: utf-8 -*-
"""Ouverture Ponziani (1.e4 e5 2.Cf3 Cc6 3.c3) — répertoire BLANC.

Une des plus vieilles ouvertures : c3 prépare d4 pour un grand centre. Peu
jouée, donc piégeuse. Arbre : 3…Cf6 et 3…d5. Lignes passées à l'audit moteur (`audit.py`).
"""


def c(fr, en):
    return {"fr": fr, "en": en}


COURSE = {
    "id": "ponziani",
    "name": "Ponziani Opening",
    "side": "white",
    "level": "club",
    "eco": ["C44"],
    "summary": c(
        "Une antiquité pleine de venin : 3.c3 prépare d4 pour bâtir un grand centre. Rare, donc désarçonnante ; les deux réponses saines (…Cf6 et …d5) demandent de la précision.",
        "A venomous antique: 3.c3 prepares d4 to build a big centre. Rare, so disorienting; the two sound replies (…Nf6 and …d5) both require precision.",
    ),
    "lines": [
        # 1) 3…Cf6
        {
            "chapter": {"id": "nf6", "title": c("3…Cf6", "3…Nf6")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6",
                {"san": "c3", "eco": "Ponziani Opening",
                 "comment": c("Le coup Ponziani : c3 soutient d4, on vise un centre e4+d4 imposant.",
                              "The Ponziani move: c3 supports d4, aiming for an imposing e4+d4 centre.")},
                {"san": "Nf6", "comment": c("La réponse active : on attaque e4 pendant que le cavalier b1 n'est pas encore sorti.",
                                            "The active reply: hit e4 while White's b1-knight isn't out yet.")},
                "d4", "Nxe4", "d5", "Ne7", "Nxe5", "Ng6", "Nxg6", "hxg6",
            ],
        },
        # 2) 3…d5
        {
            "chapter": {"id": "d5", "title": c("3…d5", "3…d5")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3",
                {"san": "d5", "comment": c("La réponse centrale : on frappe e4 tout de suite pour désamorcer le plan d4.",
                                           "The central reply: hit e4 at once to defuse the d4 plan.")},
                "Qa4", "f6", "Bb5", "Ne7", "exd5", "Qxd5", "d4", "e4",
            ],
        },

        # ── Trous comblés le 16/08 ────────────────────────────────────────────
        {
            "chapter": {"id": "vs-bc5", "title": c("3…Fc5 — le développement naturel", "3…Bc5 — natural development")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3",
                {"san": "Bc5",
                 "comment": c("Plus d'un quart des parties, et le cours partait de …Cf6 ou …d5. Le fou en c5 s'oppose à d4 — mais c3 a préparé exactement cela.",
                              "Over a quarter of games, and the course started from …Nf6 or …d5. The bishop on c5 opposes d4 — but c3 prepared precisely that."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("On pousse quand même. C'est la raison d'être du Ponziani : bâtir le centre avec un temps préparé.",
                              "We push anyway. That's the Ponziani's whole point: building the centre with a prepared tempo.")},
                "exd4", "cxd4", "Bb4+", "Nc3", "d5", "exd5",
            ],
        },
        {
            "chapter": {"id": "main", "title": c("Ligne principale — 3…Cf6", "Main line — 3…Nf6")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3", "Nf6", "d4",
                {"san": "exd4",
                 "comment": c("Sept Noirs sur dix prennent ici. Le cours continuait autrement et laissait donc l'élève seul dans la ligne la plus jouée.",
                              "Seven Black players in ten take here. The course went elsewhere, leaving the student alone in the most played line."),
                 "critical": True},
                {"san": "e5",
                 "comment": c("On avance plutôt que de reprendre : le cavalier f6 doit fuir et nous gagnons le temps qui paie le pion.",
                              "Push rather than recapture: the f6 knight must run, and we gain the tempo that pays for the pawn."),
                 "critical": True},
                "Nd5", "cxd4", "Bb4+", "Nbd2", "d6", "a3",
            ],
        },

        # ── Trous comblés le 22/08 (coverage.py, dette 0,73). ────────────────
        {
            "chapter": {"id": "vs-philidor", "title": c("Contre la Philidor — 2…d6", "vs the Philidor — 2…d6")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "d6",
                 "comment": c("Sans …Cc6, il n'y a pas de Ponziani : c3 ne sert à rien si aucun cavalier ne garde e5. Un joueur sur six, et le cours ne prévoyait QUE …Cc6.",
                              "Without …Nc6 there is no Ponziani: c3 serves no purpose if no knight is guarding e5. One player in six, and the course only planned for …Nc6."),
                 "critical": True},
                {"san": "d4",
                 "comment": c("On change de plan sans état d'âme : contre une défense passive, la rupture immédiate vaut mieux que la préparation lente.",
                              "We change plan without hesitation: against a passive defence, the immediate break beats slow preparation."),
                 "critical": True},
                "exd4", "Nxd4", "Be7", "Nc3", "Nf6", "Bf4", "O-O", "Qd2", "Nc6",
            ],
        },
        {
            "chapter": {"id": "vs-petrov", "title": c("Contre la Petroff — 2…Cf6", "vs the Petrov — 2…Nf6")},
            "moves": [
                "e4", "e5", "Nf3",
                {"san": "Nf6",
                 "comment": c("La Petroff écarte aussi le Ponziani. Un joueur sur dix, et le cours n'avait rien.",
                              "The Petrov also sidesteps the Ponziani. One player in ten, and the course had nothing."),
                 "critical": True},
                "Nxe5",
                {"san": "d6",
                 "comment": c("Le coup obligé, et le piège à connaître : …Cxe4 tout de suite perd la dame après De2.",
                              "The forced move, and the trap to know: …Nxe4 at once loses the queen to Qe2."),
                 "critical": True},
                "Nf3", "Nxe4", "d4", "d5", "Bd3", "Bd6", "O-O", "O-O",
            ],
        },
        {
            "chapter": {"id": "ponziani-main", "title": c("Ponziani — 3.c3", "Ponziani — 3.c3")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3",
                {"san": "d6",
                 "comment": c("Un Noir sur huit se contente de soutenir e5, et le cours ne prévoyait que …Cf6, …d5 et …Fc5. C'est passif, et cela nous laisse construire le centre entier.",
                              "One Black player in eight simply props up e5, and the course only planned for …Nf6, …d5 and …Bc5. It is passive, and it lets us build the whole centre."),
                 "critical": True},
                "d4", "Nf6",
                {"san": "d5",
                 "comment": c("On ferme au moment précis où le cavalier c6 n'a plus de bonne case : il devra aller en e7 et gêner le fou f8. Tout le gain de c3 est là.",
                              "We close at the exact moment when the c6 knight has no good square: it must go to e7 and get in the f8 bishop's way. That is the whole point of c3."),
                 "critical": True},
                "Ne7", "Bd3", "g6", "c4", "Bg7", "Nc3", "Nh5",
            ],
        },
        {
            "chapter": {"id": "ponziani-main", "title": c("Ponziani — 3.c3", "Ponziani — 3.c3")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3", "Bc5", "d4", "exd4", "cxd4",
                {"san": "Bb6",
                 "comment": c("Plus de quatre Noirs sur dix reculent plutôt que de clouer par …Fb4+, et le cours ne connaissait que ce clouage. Le fou en b6 regarde le centre mais n'y touche pas.",
                              "More than four Black players in ten retreat rather than pin with …Bb4+, and the course only knew that pin. On b6 the bishop watches the centre without touching it."),
                 "critical": True},
                {"san": "Bg5",
                 "comment": c("On cloue avant qu'ils ne développent. Les Noirs n'ont plus de bon coup de développement : chaque pièce qui sort laisse une faiblesse derrière elle.",
                              "We pin before they develop. Black has no good developing move left: every piece that comes out leaves a weakness behind it."),
                 "critical": True},
                "f6", "Be3", "d5", "exd5", "Nce7", "Qa4+", "Kf8", "Bc4", "Nxd5",
            ],
        },
        {
            "chapter": {"id": "ponziani-main", "title": c("Ponziani — 3.c3", "Ponziani — 3.c3")},
            "moves": [
                "e4", "e5", "Nf3", "Nc6", "c3", "Nf6", "d4", "exd4", "e5",
                {"san": "Ng4",
                 "comment": c("Le cavalier fuit vers g4 plutôt qu'en d5 — près d'un Noir sur quatre, et le cours ne prévoyait que …Cd5. C'est une erreur : le cavalier n'a plus de case pour rentrer.",
                              "The knight flees to g4 rather than d5 — nearly one Black player in four, and the course only planned for …Nd5. It is a mistake: the knight has no way back."),
                 "critical": True},
                "cxd4", "d6", "h3",
                {"san": "Nh6",
                 "comment": c("Obligé, et fatal : on échange en h6 et leur roque est détruit avant même d'avoir eu lieu. C'est la punition concrète de …Cg4.",
                              "Forced, and fatal: we take on h6 and their kingside is wrecked before they have even castled. The concrete punishment of …Ng4."),
                 "critical": True},
                "Bxh6", "gxh6", "Bb5", "Bg7", "d5", "a6",
            ],
        },
    ],
}
