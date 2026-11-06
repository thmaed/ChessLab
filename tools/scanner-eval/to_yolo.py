"""Rend un dossier de captures (png+json) en dataset YOLO : plateau recadré (jitter), 640x640,
une boîte d'UNE case par pièce — la convention du modèle livré (voir geom.py : toutes les boîtes font 1 case)."""
import sys, os, random, io, json, glob
from PIL import Image, ImageFilter, ImageEnhance
src, dst, split = sys.argv[1], sys.argv[2], sys.argv[3]
reps = int(sys.argv[4]) if len(sys.argv) > 4 else 1
LET = 'PNBRQKpnbrqk'
os.makedirs(f'{dst}/images/{split}', exist_ok=True); os.makedirs(f'{dst}/labels/{split}', exist_ok=True)
random.seed(hash(src) % 1000)
n = 0
for js in sorted(glob.glob(src + '/*.json')):
    meta = json.load(open(js)); png = js[:-5] + '.png'
    full = Image.open(png).convert('RGB'); x, y, w, h = meta['bbox']
    for rep in range(reps):
        # jitter du cadrage : le redressement de l'app tombe à ~1 % près
        j = lambda: random.uniform(-0.012, 0.012) * w
        s = random.uniform(-0.01, 0.01) * w
        x0, y0, x1, y1 = x + j() - s, y + j() - s, x + w + j() + s, y + h + j() + s
        img = full.crop((round(x0), round(y0), round(x1), round(y1))).resize((640, 640), Image.BILINEAR)
        cw, ch = x1 - x0, y1 - y0
        # perturbations : flou léger, JPEG, luminosité
        if random.random() < .4: img = img.filter(ImageFilter.GaussianBlur(random.uniform(.3, 1.2)))
        if random.random() < .3: img = ImageEnhance.Brightness(img).enhance(random.uniform(.75, 1.2))
        if random.random() < .5:
            b = io.BytesIO(); img.save(b, 'JPEG', quality=random.randint(50, 92)); img = Image.open(b).convert('RGB')
        name = os.path.basename(js)[:-5] + f'_{rep}'
        img.save(f'{dst}/images/{split}/{name}.jpg', quality=95)
        lines = []
        for r in range(8):
            for c in range(8):
                t = meta['grid'][r][c]
                if t == '.': continue
                # case (r,c) dans l'image d'origine, ramenée au cadrage jitteré
                cx = (x + (c + .5) * w / 8 - x0) / cw; cy = (y + (r + .5) * h / 8 - y0) / ch
                lines.append(f'{LET.index(t)} {cx:.5f} {cy:.5f} {w/8/cw:.5f} {h/8/ch:.5f}')
        open(f'{dst}/labels/{split}/{name}.txt', 'w').write('\n'.join(lines))
        n += 1
print(split, n)
