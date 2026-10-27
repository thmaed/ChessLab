#!/usr/bin/env python3
"""Habille les captures brutes de la fiche App Store : un titre court en tête, l'écran dessous.

Bonnes pratiques d'Apple (asset-best-practices) : les trois premières captures sont celles des résultats de
recherche, on ouvre donc sur ce qui compte ; une courte phrase qui souligne l'écran sans le décrire ; texte
localisé ; élément principal au centre, dans la zone sûre.

    tools/habiller-captures.py <dossier brut> <dossier sortie> <fr|en> <largeur> <hauteur>
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

CAPTIONS = {
    "fr": {
        "01-seance": "Votre séance du jour",
        "02-coach": "Ce que jouent les joueurs de votre niveau",
        "03-puzzles-offre": "Vos erreurs deviennent des puzzles",
        "04-adversaires": "Neuf adversaires qui jouent comme des humains",
        "05-partie": "Une vraie partie, analysée en direct",
        "06-ouvertures": "58 ouvertures illustrées",
        "07-lecteur": "Chaque coup est expliqué",
        "08-puzzle-cote": "Plus de 100 000 puzzles",
        "09-finales": "78 finales prouvées",
        "10-variantes": "Douze variantes",
    },
    "en": {
        "01-seance": "Your daily session",
        "02-coach": "What players at your level play",
        "03-puzzles-offre": "Your mistakes become puzzles",
        "04-adversaires": "Nine opponents that play like humans",
        "05-partie": "A real game, analysed live",
        "06-ouvertures": "58 illustrated openings",
        "07-lecteur": "Every move explained",
        "08-puzzle-cote": "100,000+ puzzles",
        "09-finales": "78 proven endgames",
        "10-variantes": "Twelve variants",
    },
}
TOP, BOTTOM = (14, 18, 34), (30, 40, 74)   # le fond sombre de l'app, légèrement bleuté


def font(size):
    return ImageFont.truetype("/System/Library/Fonts/Avenir Next.ttc", size, index=2)  # Demi Bold


def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=fnt) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def compose(src, dst, caption, W, H):
    shot = Image.open(src).convert("RGB")
    canvas = Image.new("RGB", (W, H))
    px = canvas.load()
    for y in range(H):
        t = y / (H - 1)
        row = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = row
    d = ImageDraw.Draw(canvas)
    margin = int(W * 0.07)
    size = int(W * 0.074)
    fnt = font(size)
    lines = wrap(d, caption, fnt, W - 2 * margin)
    while len(lines) > 3 or max(d.textlength(l, font=fnt) for l in lines) > W - 2 * margin:
        size = int(size * 0.92); fnt = font(size); lines = wrap(d, caption, fnt, W - 2 * margin)
    lead = int(size * 1.18)
    band = int(H * 0.035) + lead * 3                      # hauteur réservée, 3 lignes au plus
    y = int(H * 0.035) + (3 - len(lines)) * lead // 2     # centré dans la bande
    for l in lines:
        d.text((W / 2, y), l, font=fnt, fill=(255, 255, 255), anchor="ma")
        y += lead
    # L'écran, à 86 % de la largeur, sous le titre, rogné par le bas du cadre.
    sw = int(W * 0.86)
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    top = band + int(H * 0.025)
    visible = H - top
    shot = shot.crop((0, 0, sw, min(sh, visible)))
    mask = Image.new("L", shot.size, 0)
    r = int(sw * 0.055)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height + r), radius=r, fill=255)
    x = (W - sw) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, top, x + sw, H + r), radius=r, fill=(0, 0, 0, 150))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(18))).convert("RGB")
    canvas.paste(shot, (x, top), mask)
    canvas.save(dst, "PNG")


if __name__ == "__main__":
    raw, out, lang, W, H = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
    out.mkdir(parents=True, exist_ok=True)
    for f in sorted(raw.glob("*.png")):
        caption = CAPTIONS[lang].get(f.stem)
        if caption:
            compose(f, out / f.name, caption, W, H)
            print("  ", f.name)
