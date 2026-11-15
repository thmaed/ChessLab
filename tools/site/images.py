#!/usr/bin/env python3
"""Prépare les images du site (docs/img/<langue>/) à partir des captures de la fiche : JPEG réduits, un jeu par langue.

    python3 tools/site/images.py
"""
from pathlib import Path
from PIL import Image, ImageDraw
RACINE = Path(__file__).resolve().parents[2]
SHOTS = RACINE / "AppStoreSubmission/screenshots"
SORTIE = RACINE / "docs/img"
LANGS = {"fr": "fr-FR", "en": "en-US", "es": "es-ES", "de": "de-DE", "it": "it-IT"}   # uniquement du matériel Apple
NOMS = ["01-seance", "02-coach", "03-puzzles-offre", "04-adversaires", "05-puzzles-ecran",
        "06-ouvertures", "07-lecteur", "08-puzzle-cote", "09-finales", "10-variantes"]

def sauve(src, dst, largeur, q=82):
    im = Image.open(src).convert("RGB")
    im = im.resize((largeur, round(im.height * largeur / im.width)), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "JPEG", quality=q, optimize=True, progressive=True)

for lang, loc in LANGS.items():
    d = SORTIE / lang
    for n in NOMS:
        sauve(SHOTS / "iphone-6.7" / lang / f"{n}.png", d / f"{n}.jpg", 640)
    sauve(SHOTS / "ipad-13" / lang / "02-coach.png", d / "ipad.jpg", 1000)
    sauve(SHOTS / "iphone-duo" / lang / "inner-01-seance.png", d / "duo-inner.jpg", 1300)
    sauve(SHOTS / "iphone-duo" / lang / "outer-02-coach.png", d / "duo-outer.jpg", 560)
    sauve(RACINE / f"AppStoreSubmission/entete/entete-{lang}-3840x1646.png", d / "banniere.jpg", 1800, 80)
    # Aperçu des réseaux et messageries : 1200 × 630.
    b = Image.open(RACINE / f"AppStoreSubmission/entete/entete-{lang}-3840x1646.png").convert("RGB")
    b = b.resize((1200, round(b.height * 1200 / b.width)), Image.LANCZOS)
    fond = Image.new("RGB", (1200, 630), (13, 21, 18)); fond.paste(b, (0, (630 - b.height) // 2))
    fond.save(d / "partage.jpg", "JPEG", quality=84, optimize=True)
    print(lang, "ok")
