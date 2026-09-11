"""Fabrique l'icône Android à partir de l'icône iOS (une seule source de vérité).

    tools/maia3-spike/mlenv/bin/python tools/android-icon/make_icon.py

Source : ChessLab/Assets.xcassets/AppIcon.appiconset/etna.png (1024 carré).

Une icône adaptative Android est faite de deux calques de 108 dp ; le lanceur
n'en montre JAMAIS plus que le carré central de 72 dp — le reste sert aux
effets de parallaxe. L'illustration est donc posée sur 78 dp (un rien plus
large que le masque, pour qu'aucun bord ne se devine) et centrée. Le masque,
rond ou arrondi selon le lanceur, ne rogne ainsi que les coins du damier :
le cavalier, lui, reste entier.
"""
import pathlib, sys
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "ChessLab/Assets.xcassets/AppIcon.appiconset/etna.png"
RES = ROOT / "android/app/src/main/res"

art = Image.open(SRC).convert("RGBA")

# dp → px par densité, pour un calque de 108 dp et une icône héritée de 48 dp.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
ART_DP = 73  # sur 108 : couvre le masque (72 dp) avec un dp de débord

def rounded(img, radius_ratio=0.22):
    """Coins arrondis, pour l'icône héritée posée à même le lanceur."""
    mask = Image.new("L", img.size, 0)
    r = int(img.size[0] * radius_ratio)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], r, fill=255)
    out = img.copy(); out.putalpha(mask); return out

written = []
for name, k in DENSITIES.items():
    layer = round(108 * k)
    side = round(ART_DP * k)
    fg = Image.new("RGBA", (layer, layer), (0, 0, 0, 0))
    fg.paste(art.resize((side, side), Image.LANCZOS), ((layer - side) // 2,) * 2)
    d = RES / f"mipmap-{name}"; d.mkdir(parents=True, exist_ok=True)
    fg.save(d / "ic_launcher_foreground.png"); written.append(d / "ic_launcher_foreground.png")

    legacy = round(48 * k)
    icon = rounded(art.resize((legacy, legacy), Image.LANCZOS))
    icon.save(d / "ic_launcher.png"); written.append(d / "ic_launcher.png")
    icon.save(d / "ic_launcher_round.png"); written.append(d / "ic_launcher_round.png")

# L'icône de la fiche Google Play : 512 carré, opaque, coins francs.
play = ROOT / "tools/android-icon/play-icon-512.png"
art.convert("RGB").resize((512, 512), Image.LANCZOS).save(play)
print(f"{len(written)} fichiers dans res/mipmap-*, plus {play.relative_to(ROOT)}")
