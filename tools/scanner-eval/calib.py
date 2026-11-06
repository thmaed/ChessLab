import numpy as np
from common import *
ok=[];bad=[]
for k,(png,meta) in enumerate(items('../data/held')):
    g=to_grid(raw_boxes(board_crop(png,meta)))
    for r in range(8):
        for c in range(8):
            t=meta['grid'][r][c]; d=g[r][c]
            if d is None: continue
            s=np.sort(d[1])[::-1]; read=LET[int(d[1].argmax())]
            (ok if read==t else bad).append((s[0],s[1]))
ok=np.array(ok);bad=np.array(bad)
print('pièces justes',len(ok),'| pièces fausses (type, couleur OU fausse pièce)',len(bad))
print('conf des erreurs :',np.sort(bad[:,0]).round(2))
for th in (0.92,0.9,0.88,0.87,0.86,0.85):
    print(f'top1<{th}: justes signalées {100*(ok[:,0]<th).mean():.2f}% ({(ok[:,0]<th).sum()})  erreurs attrapées {(bad[:,0]<th).sum()}/{len(bad)}')
for th in (0.02,0.05,0.1):
    print(f'top2>{th}: justes {100*(ok[:,1]>th).mean():.2f}%  erreurs {(bad[:,1]>th).sum()}/{len(bad)}')
