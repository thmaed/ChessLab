#!/usr/bin/env python3
"""
Engendre `docs/privacy-policy.html` à partir de `PRIVACY.md`.

UNE source, UNE page. Le texte a existé en deux exemplaires — un Markdown à la
racine et une page HTML écrite à la main — et les deux avaient déjà divergé :
la page annonçait qu'iCloud « pourrait être ajouté dans une future version »
alors que la synchronisation existait depuis des mois. Une politique de
confidentialité inexacte n'est pas un détail de présentation.

L'URL de la page ne change PAS : elle est déposée chez Apple et chez Google, et
une politique qui déménage est une politique introuvable.

    python3 tools/engendrer-site.py
"""

import html
import pathlib
import re

RACINE = pathlib.Path(__file__).resolve().parent.parent
SOURCE = RACINE / "PRIVACY.md"
CIBLE = RACINE / "docs" / "privacy-policy.html"


def enrichir(texte: str) -> str:
    t = html.escape(texte)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"`(.+?)`", r"<code>\1</code>", t)
    t = re.sub(r"&lt;(https?://[^&]+)&gt;", r'<a href="\1">\1</a>', t)
    t = re.sub(r"\[(.+?)\]\((.+?)\)", r'<a href="\2">\1</a>', t)
    t = re.sub(r"(?<![\w@.>\"/])([\w.]+@[\w.]+\.\w+)", r'<a href="mailto:\1">\1</a>', t)
    return t


def convertir(markdown: str) -> str:
    sortie: list[str] = []
    paragraphe: list[str] = []
    dans_liste = False

    def vider():
        nonlocal paragraphe
        if paragraphe:
            sortie.append("<p>" + enrichir(" ".join(paragraphe)) + "</p>")
            paragraphe = []

    for brut in markdown.split("\n"):
        ligne = brut.rstrip()
        if not ligne:
            vider()
            if dans_liste:
                sortie.append("</ul>")
                dans_liste = False
            continue
        if ligne.startswith("- "):
            vider()
            if not dans_liste:
                sortie.append("<ul>")
                dans_liste = True
            sortie.append("<li>" + enrichir(ligne[2:]) + "</li>")
            continue
        if dans_liste and ligne.startswith("  "):
            # Suite d'un point de liste, replié par la source.
            sortie[-1] = sortie[-1][:-5] + " " + enrichir(ligne.strip()) + "</li>"
            continue
        if dans_liste:
            sortie.append("</ul>")
            dans_liste = False
        if ligne.startswith("## "):
            vider()
            sortie.append(f"<h2>{html.escape(ligne[3:])}</h2>")
        elif ligne.startswith("# "):
            vider()
            sortie.append(f"<h1>{html.escape(ligne[2:])}</h1>")
        elif ligne.startswith("*") and ligne.endswith("*"):
            vider()
            sortie.append(f'<p class="date">{html.escape(ligne.strip("*"))}</p>')
        else:
            paragraphe.append(ligne)
    vider()
    if dans_liste:
        sortie.append("</ul>")
    return "\n".join(sortie)


def main() -> None:
    markdown = SOURCE.read_text(encoding="utf-8")
    francais, anglais = markdown.split("\n---\n\n# Privacy Policy")
    anglais = "# Privacy Policy" + anglais

    page = f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ChessLab — Politique de confidentialité / Privacy Policy</title>
<meta name="description" content="ChessLab ne collecte aucune donnée personnelle et ne communique avec aucun de nos serveurs.">
<link rel="stylesheet" href="style.css">
</head>
<body>
<main class="page">
<p class="langues"><a href="index.html">&larr; ChessLab</a> &nbsp;&middot;&nbsp; <a href="#english">English</a></p>

{convertir(francais)}

<hr style="border:0;border-top:1px solid var(--trait);margin:4rem 0 0">
<div id="english">
{convertir(anglais)}
</div>
</main>
</body>
</html>
"""
    CIBLE.write_text(page, encoding="utf-8")
    print(f"{CIBLE.relative_to(RACINE)} : {len(page)} octets")


if __name__ == "__main__":
    main()
