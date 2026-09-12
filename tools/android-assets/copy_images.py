"""Recopie les images de l'app iOS dans les ressources Android.

    tools/maia3-spike/mlenv/bin/python tools/android-assets/copy_images.py

Les avatars des neuf personnages et le logo de l'accueil vivent dans
`Assets.xcassets`. Les recopier à la main garantirait une divergence le jour où
l'un d'eux change ; une commande, non.

Les PNG font 512 px : posés en `drawable-xxxhdpi` (densité 4×), ils valent
128 dp, de quoi tenir la plus grande vignette de l'app sans jamais s'étirer.
Android sous-échantillonne tout seul pour les densités moindres.
"""
import pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "ChessLab/Assets.xcassets"
DST = ROOT / "android/app/src/main/res/drawable-xxxhdpi"
DST.mkdir(parents=True, exist_ok=True)

written = []
for imageset in sorted((SRC / "Opponents").glob("avatar_*.imageset")):
    png = next(imageset.glob("*.png"))
    target = DST / png.name
    Image.open(png).convert("RGBA").save(target, optimize=True)
    written.append(target.name)

# Le logo de l'accueil : l'icône de l'app, en 256 (elle s'affiche à 56 dp).
logo = Image.open(SRC / "AppLogo.imageset/etna.png").convert("RGBA")
logo.resize((256, 256), Image.LANCZOS).save(DST / "app_logo.png", optimize=True)
written.append("app_logo.png")

print(f"{len(written)} images dans {DST.relative_to(ROOT)} :", ", ".join(written))
