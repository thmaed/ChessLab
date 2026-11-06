import numpy as np
from common import *
ok=[];bad=[]
for k,(png,meta) in enumerate(items('../data/held')):
    if k>=250: break
    g=to_grid(raw_boxes(board_crop(png,meta)))
    for r in range(8):
        for c in range(8):
            t=meta['grid'][r][c]; d=g[r][c]
            if d is None or t=='.': continue
            s=np.sort(d[1])[::-1]; read=LET[int(d[1].argmax())]
            (ok if read==t else bad).append((s[0],s[1]))
ok=np.array(ok);bad=np.array(bad)
print('justes',len(ok),'fausses (type/couleur)',len(bad))
print('top1 justes p5/p50',np.percentile(ok[:,0],[5,50]).round(2),'fausses p50/p90',np.percentile(bad[:,0],[50,90]).round(2))
print('top2 justes p95/p99',np.percentile(ok[:,1],[95,99]).round(3),'fausses p50/p75/p90',np.percentile(bad[:,1],[50,75,90]).round(3))
for th in (0.05,0.1,0.2,0.3):
    print(f'top2>{th}: justes signalées {100*(ok[:,1]>th).mean():.2f}%  fausses attrapées {100*(bad[:,1]>th).mean():.1f}%')
for th in (0.9,0.8,0.7,0.6):
    print(f'top1<{th}: justes signalées {100*(ok[:,0]<th).mean():.2f}%  fausses attrapées {100*(bad[:,0]<th).mean():.1f}%')
