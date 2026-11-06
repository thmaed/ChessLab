"""Calibration du doute sur des images « photo d'écran » (cumul) : combien d'erreurs un seuil attrape-t-il,
au prix de combien de pièces justes signalées. Usage : WEIGHTS=...pt python calib_photo.py HELD 150"""
import sys, numpy as np
from common import *
import degrade
folder, n = sys.argv[1], int(sys.argv[2])
ok, bad = [], []
for k, (png, meta) in enumerate(items(folder)):
    if k >= n: break
    g = to_grid(raw_boxes(degrade.photo(board_crop(png, meta))))
    for r in range(8):
        for c in range(8):
            t = meta['grid'][r][c]; d = g[r][c]
            if d is None: continue
            (ok if LET[int(d[1].argmax())] == t else bad).append(float(d[1].max()))
ok, bad = np.array(ok), np.array(bad)
print('pièces justes', len(ok), '| fausses', len(bad))
for th in (0.97, 0.95, 0.92, 0.9, 0.87):
    print(f'top1<{th}: justes signalées {100*(ok<th).mean():.2f}%  erreurs attrapées {(bad<th).sum()}/{len(bad)}')
