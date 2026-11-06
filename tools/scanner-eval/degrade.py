"""Dégradations « photo d'un écran » appliquées aux captures du banc, pour mesurer
ce que le détecteur perd quand l'image n'est plus une capture pixel-parfaite.
Usage : WEIGHTS=...pt python degrade.py HELD 200"""
import sys, io, collections, numpy as np
from PIL import Image, ImageFilter
from common import *

rng = np.random.default_rng(7)

def moire(im, period=None):
    """Battement entre la grille de pixels de l'écran et celle du capteur : bandes sinusoïdales croisées."""
    a = np.asarray(im, dtype=np.float32)
    h, w, _ = a.shape
    p = period or rng.uniform(5, 14)
    ang = rng.uniform(0, np.pi)
    y, x = np.mgrid[0:h, 0:w]
    s = np.sin(2*np.pi*(x*np.cos(ang)+y*np.sin(ang))/p) * np.sin(2*np.pi*(-x*np.sin(ang)+y*np.cos(ang))/(p*1.07))
    a = a * (1 + 0.12*s[..., None])
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

def glare(im):
    a = np.asarray(im, dtype=np.float32)
    h, w, _ = a.shape
    cx, cy = rng.uniform(0.2, 0.8)*w, rng.uniform(0.2, 0.8)*h
    r = rng.uniform(0.25, 0.5)*w
    y, x = np.mgrid[0:h, 0:w]
    g = np.exp(-(((x-cx)**2+(y-cy)**2)/(2*(r/2)**2)))
    a = a + 110*g[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

def noise(im):
    a = np.asarray(im, dtype=np.float32) + rng.normal(0, rng.uniform(4, 12), (im.height, im.width, 1))
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

def blur(im): return im.filter(ImageFilter.GaussianBlur(rng.uniform(1.2, 2.6)))

def lowres(im):
    s = int(rng.uniform(260, 420))
    return im.resize((s, s), Image.BILINEAR).resize(im.size, Image.BILINEAR)

def jpeg(im):
    b = io.BytesIO(); im.save(b, 'JPEG', quality=int(rng.uniform(35, 65))); b.seek(0)
    return Image.open(b).convert('RGB')

def tone(im):
    a = np.asarray(im, dtype=np.float32)
    a = (a - 128) * rng.uniform(0.7, 1.15) + 128 + rng.uniform(-25, 25)
    a = a * rng.uniform(0.9, 1.0, 3)  # dominante légère
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

def photo(im):
    """Cumul réaliste : flou + moiré + bruit + tonalité + JPEG, un reflet une fois sur deux."""
    im = blur(lowres(im)) if rng.random() < .5 else blur(im)
    im = moire(im); im = tone(im); im = noise(im)
    if rng.random() < .5: im = glare(im)
    return jpeg(im)

MODES = {'propre': lambda i: i, 'flou': blur, 'basse-res': lowres, 'moiré': moire, 'reflet': glare,
         'bruit': noise, 'jpeg': jpeg, 'tonalité': tone, 'PHOTO (cumul)': photo}

if __name__ == '__main__':
    folder, n = sys.argv[1], int(sys.argv[2])
    src = []
    for k, (png, meta) in enumerate(items(folder)):
        if k >= n: break
        src.append((board_crop(png, meta), meta))
    for name, fn in MODES.items():
        cnt = collections.Counter(); exact = 0; silent = 0
        for img, meta in src:
            g = to_grid(raw_boxes(fn(img))); bad = 0
            for r in range(8):
                for c in range(8):
                    t = meta['grid'][r][c]; d = g[r][c]; read = '.' if d is None else LET[int(d[1].argmax())]
                    conf = 0 if d is None else d[0]
                    cnt['sq'] += 1
                    if t == read: continue
                    bad += 1
                    kind = 'fausse' if t == '.' else 'manquée' if read == '.' else 'type/couleur'
                    cnt[kind] += 1
                    # « silencieuse » = pas signalée à l'utilisateur (confiance calibrée ≥ 0,55 ⇔ brute ≥ 0,87)
                    if conf >= 0.87: silent += 1
            exact += bad == 0
        N = cnt['sq']
        print(f"{name:15s} exacts {100*exact/len(src):5.1f}%  fausses {100*cnt['fausse']/N:.3f}%  manquées {100*cnt['manquée']/N:.3f}%  "
              f"type/couleur {100*cnt['type/couleur']/N:.3f}%  erreurs silencieuses {silent}", flush=True)
