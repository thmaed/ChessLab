#!/usr/bin/env python3
"""L'en-tête de la fiche App Store (visuel « universel » des résultats de recherche et de la page produit).

Tailles acceptées par App Store Connect : 5244 × 2950 et 3840 × 1646. Un seul visuel de marque, des captures
réelles, une phrase ; les éléments importants restent dans le centre (zone sûre), le reste est de l'ambiance.

    tools/entete-fiche.py <dossier des captures brutes> <sortie> <fr|en> <largeur> <hauteur>
"""
import sys, math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ICON = Path(__file__).resolve().parent.parent / "ChessLab/Assets.xcassets/AppIcon.appiconset/etna.png"
TEXT = {
    "fr": ("Jouez, analysez, progressez.", "Neuf adversaires qui jouent comme des humains"),
    "en": ("Play, analyse, improve.", "Nine opponents that play like humans"),
}
SHOTS = ["02-coach", "01-seance", "03-puzzles-offre"]   # gauche, centre (au premier plan), droite
TEAL = (52, 211, 163)
# Résultats de recherche : on cherche quelque chose de précis, l'usage doit se lire d'un coup d'œil.
SEARCH = {
    "fr": ("Jouez contre des adversaires qui pensent comme des humains", ["Analyse", "Coach", "Puzzles", "Ouvertures"]),
    "en": ("Play opponents that think like humans", ["Analysis", "Coach", "Puzzles", "Openings"]),
}


def font(size, index=2):
    return ImageFont.truetype("/System/Library/Fonts/Avenir Next.ttc", size, index=index)


def background(W, H):
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(0, W):
            t = (x / W * 0.6 + y / H * 0.4)
            px[x, y] = (int(10 + 22 * t), int(15 + 30 * t), int(32 + 62 * t))
    # Un damier très discret, en perspective plate, pour l'ambiance.
    over = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    sq = int(H * 0.11)
    for r in range(math.ceil(H / sq)):
        for c in range(math.ceil(W / sq)):
            if (r + c) % 2 == 0:
                d.rectangle((c * sq, r * sq, (c + 1) * sq, (r + 1) * sq), fill=(255, 255, 255, 9))
    img = Image.alpha_composite(img.convert("RGBA"), over)
    # Deux halos : turquoise derrière les téléphones, bleu à gauche.
    for cx, cy, rad, col, a in ((0.72, 0.5, 0.55, TEAL, 70), (0.12, 0.2, 0.45, (60, 90, 220), 60)):
        halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse((W * cx - H * rad, H * cy - H * rad, W * cx + H * rad, H * cy + H * rad), fill=col + (a,))
        img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(H * 0.16)))
    return img


def phone(shot_path, width, height_visible):
    shot = Image.open(shot_path).convert("RGB")
    sh = int(shot.height * width / shot.width)
    shot = shot.resize((width, sh), Image.LANCZOS).crop((0, 0, width, min(sh, height_visible)))
    pad = int(width * 0.035)
    frame = Image.new("RGBA", (width + 2 * pad, shot.height + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    rad = int(width * 0.13)
    d.rounded_rectangle((0, 0, frame.width - 1, frame.height + rad), radius=rad + pad, fill=(18, 20, 28, 255), outline=(120, 130, 160, 255), width=max(2, pad // 4))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height + rad), radius=rad, fill=255)
    frame.paste(shot, (pad, pad), mask)
    return frame


def main(raw, out, lang, W, H):
    img = background(W, H)
    # `u` : la hauteur utile. Sur un cadre plus haut que large (16:9), le contenu se cale sur la LARGEUR et se
    # centre en hauteur, au lieu de gonfler jusqu'à manger le titre.
    u = min(H, int(W * 0.43))
    oy = (H - u) // 2
    left = int(W * 0.10)
    icon_s = int(u * 0.2)
    icon = Image.open(ICON).convert("RGBA").resize((icon_s, icon_s), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, icon_s - 1, icon_s - 1), radius=int(icon_s * 0.225), fill=255)
    top = oy + int(u * 0.27)
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((left, top + 14, left + icon_s, top + icon_s + 14), radius=int(icon_s * 0.225), fill=(0, 0, 0, 150))
    img = Image.alpha_composite(img, sh.filter(ImageFilter.GaussianBlur(u * 0.012)))
    img.paste(icon, (left, top), m)
    d = ImageDraw.Draw(img)
    title_f = font(int(u * 0.15), 0)
    x = left + icon_s + int(u * 0.04)
    ty = top + icon_s // 2 - int(u * 0.095)
    d.text((x, ty), "Chess", font=title_f, fill=(255, 255, 255))
    d.text((x + d.textlength("Chess", font=title_f), ty), "Lab", font=title_f, fill=TEAL)
    tag, sub = TEXT[lang]
    d.text((left, top + icon_s + int(u * 0.07)), tag, font=font(int(u * 0.068), 2), fill=(255, 255, 255))
    d.text((left, top + icon_s + int(u * 0.175)), sub, font=font(int(u * 0.042), 5), fill=(170, 185, 215))
    # Bloc de droite : trois captures réelles, celle du milieu devant, rognées par le bas du cadre.
    pw = int(u * 0.37)
    cx = int(W * 0.725)
    names = {-1: SHOTS[0], 1: SHOTS[2], 0: SHOTS[1]}
    for k in (-1, 1, 0):
        w = pw if k == 0 else int(pw * 0.84)
        y = oy + int(u * (0.12 if k == 0 else 0.24))
        ph = phone(Path(raw) / f"{names[k]}.png", w, H - y)
        x0 = cx - ph.width // 2 + k * int(pw * 0.9)
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((x0, y + 20, x0 + ph.width, H + 200), radius=int(w * 0.16), fill=(0, 0, 0, 170))
        img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(u * 0.018)))
        img.alpha_composite(ph, (x0, y))
    img.convert("RGB").save(out, "PNG")
    print(out, img.size)


def search(raw, out, lang, W, H):
    img = background(W, H)
    u = min(H, int(W * 0.43))
    oy = (H - u) // 2
    left = int(W * 0.09)
    d = ImageDraw.Draw(img)
    # Marque en petit, en haut du bloc de texte.
    icon_s = int(u * 0.13)
    icon = Image.open(ICON).convert("RGBA").resize((icon_s, icon_s), Image.LANCZOS)
    m = Image.new("L", icon.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, icon_s - 1, icon_s - 1), radius=int(icon_s * 0.225), fill=255)
    top = oy + int(u * 0.17)
    img.paste(icon, (left, top), m)
    d = ImageDraw.Draw(img)
    name_f = font(int(u * 0.075), 0)
    d.text((left + icon_s + int(u * 0.03), top + icon_s // 2), "Chess", font=name_f, fill=(255, 255, 255), anchor="lm")
    d.text((left + icon_s + int(u * 0.03) + d.textlength("Chess", font=name_f), top + icon_s // 2), "Lab", font=name_f, fill=TEAL, anchor="lm")
    # Le titre : gros, sur trois lignes au plus.
    headline, chips = SEARCH[lang]
    size = int(u * 0.115)
    maxw = int(W * 0.44)
    while True:
        f = font(size, 0)
        lines, line = [], ""
        for word in headline.split():
            trial = (line + " " + word).strip()
            if d.textlength(trial, font=f) <= maxw or not line:
                line = trial
            else:
                lines.append(line); line = word
        lines.append(line)
        if len(lines) <= 3 or size < 20:
            break
        size = int(size * 0.94)
    y = top + icon_s + int(u * 0.06)
    for l in lines:
        d.text((left, y), l, font=f, fill=(255, 255, 255))
        y += int(size * 1.15)
    # Les pastilles : ce que l'app fait.
    cf = font(int(u * 0.045), 2)
    x = left
    y += int(u * 0.04)
    for chip in chips:
        w = int(d.textlength(chip, font=cf)) + int(u * 0.07)
        h = int(u * 0.08)
        d.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, fill=(255, 255, 255, 28) if False else (36, 52, 92), outline=TEAL, width=max(2, int(u * 0.004)))
        d.text((x + w // 2, y + h // 2), chip, font=cf, fill=(255, 255, 255), anchor="mm")
        x += w + int(u * 0.025)
    # Deux écrans : le Coach devant, la galerie d'adversaires derrière.
    pw = int(u * 0.40)
    cx = int(W * 0.745)
    for k, name, scale, dy in ((1, "04-adversaires", 0.86, 0.20), (0, "02-coach", 1.0, 0.09)):
        w = int(pw * scale)
        yy = oy + int(u * dy)
        ph = phone(Path(raw) / f"{name}.png", w, H - yy)
        x0 = cx - ph.width // 2 + k * int(pw * 0.78) - (0 if k else int(pw * 0.2))
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((x0, yy + 20, x0 + ph.width, H + 200), radius=int(w * 0.16), fill=(0, 0, 0, 170))
        img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(u * 0.018)))
        img.alpha_composite(ph, (x0, yy))
    img.convert("RGB").save(out, "PNG")
    print(out, img.size)


if __name__ == "__main__":
    if len(sys.argv) > 6 and sys.argv[6] == "recherche":
        search(sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]))
        sys.exit(0)
    main(sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]))
