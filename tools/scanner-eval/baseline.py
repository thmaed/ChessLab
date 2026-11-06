import sys, collections, numpy as np
from common import *
folder=sys.argv[1]; n=int(sys.argv[2])
cnt=collections.Counter(); rows=[]; boards=0; exact=0
for k,(png,meta) in enumerate(items(folder)):
    if k>=n: break
    img=board_crop(png,meta); g=to_grid(raw_boxes(img)); boards+=1; bad=0
    for r in range(8):
        for c in range(8):
            t=meta['grid'][r][c]; d=g[r][c]; read='.' if d is None else LET[int(d[1].argmax())]
            conf=0 if d is None else d[0]
            cnt['squares']+=1
            if t==read: kind='ok'
            elif t=='.': kind='FAUSSE_PIECE'
            elif read=='.': kind='MANQUEE'
            elif t.lower()==read.lower(): kind='COULEUR'
            elif t.isupper()==read.isupper(): kind='TYPE'
            else: kind='TYPE+COULEUR'
            cnt[kind]+=1
            if kind!='ok':
                bad+=1; rows.append((kind,t,read,round(conf,2),meta['set'],meta['flags']['sel'],meta['flags']['arrows'],meta['flags']['chrome']))
    exact+= bad==0
print('plateaux',boards,'exacts',exact, f'{100*exact/boards:.1f}%')
for k,v in cnt.items(): print(k,v, f'{100*v/cnt["squares"]:.3f}%')
import pickle; pickle.dump(rows,open('errors.pkl','wb'))
c2=collections.Counter((r[0],r[1],r[2]) for r in rows)
print('confusions fréquentes:',c2.most_common(15))
print('par jeu (erreurs):',collections.Counter(r[4] for r in rows).most_common(10))
print('confiance moyenne des erreurs non-manquées:',np.mean([r[3] for r in rows if r[0]!='MANQUEE']))
print('fausses pièces avec conf>=0.55 (silencieuses):',sum(1 for r in rows if r[0]=='FAUSSE_PIECE' and r[3]>=0.55),'/',sum(1 for r in rows if r[0]=='FAUSSE_PIECE'))
