import sys, collections
from common import *
folder='../cg/out'; N=300
stat=collections.defaultdict(lambda:[0,0])  # [fausses, cases vides]
bad=[]
for k,(png,meta) in enumerate(items(folder)):
    if k>=N: break
    g=to_grid(raw_boxes(board_crop(png,meta)))
    f=meta['flags']
    for r in range(8):
        for c in range(8):
            if meta['grid'][r][c]!='.': continue
            fp = g[r][c] is not None
            for key in [('coords',f['coords']),('sel',f['sel']),('arrows',f['arrows']),('lastMove',f['lastMove']),('edgeRow',r in (0,7)),('edgeCol',c in (0,7))]:
                stat[key][0]+=fp; stat[key][1]+=1
            if fp: bad.append((k,r,c,round(float(g[r][c][0]),2)))
for k,v in sorted(stat.items(),key=str): print(k, f'{100*v[0]/v[1]:.2f}%', v)
import pickle; pickle.dump(bad,open('bad.pkl','wb'))
# par image : combien de fausses pièces
per=collections.Counter(b[0] for b in bad); print('images avec >=1 fausse:',len(per),'sur',N, 'max',max(per.values()))
print(per.most_common(8))
