import numpy as np, collections
from common import *
def feat(cell):
    a=np.asarray(cell,dtype=np.float32)  # h,w,3
    h,w,_=a.shape; m=int(h*.12)
    ring=np.concatenate([a[:m].reshape(-1,3),a[-m:].reshape(-1,3),a[:,:m].reshape(-1,3),a[:,-m:].reshape(-1,3)])
    q=(ring//8).astype(int); key=q[:,0]*10000+q[:,1]*100+q[:,2]
    vals,cnt=np.unique(key,return_counts=True); bg=ring[key==vals[cnt.argmax()]].mean(0)
    c=a[int(h*.1):int(h*.9),int(w*.1):int(w*.9)]
    d=np.abs(c-bg).max(2)
    return (d>40).mean(), (d>90).mean()
R=collections.defaultdict(list)
for k,(png,meta) in enumerate(items('../data/held')):
    if k>=100: break
    img=board_crop(png,meta)
    for r in range(8):
        for c in range(8):
            t=meta['grid'][r][c]; f=feat(img.crop((c*100,r*100,c*100+100,r*100+100)))
            R['vide' if t=='.' else 'pion' if t.lower()=='p' else 'autre'].append(f)
for k,v in R.items():
    v=np.array(v)
    print(k,len(v),'f40 p50/p90/p99/max',np.percentile(v[:,0],[50,90,99,100]).round(3),'| f90',np.percentile(v[:,1],[50,90,99,100]).round(3),'| min',v[:,0].min().round(3),v[:,1].min().round(3), 'p1',np.percentile(v[:,0],1).round(3),np.percentile(v[:,1],1).round(3))
