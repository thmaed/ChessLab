"""Peint, avec PIL (donc SANS chessground), des surcharges de style chess.com sur de VRAIES captures et compare deux modèles."""
import os, sys, json, random
from PIL import Image, ImageDraw
import numpy as np
os.environ.setdefault('WEIGHTS','x')
import common
FX='/Users/thierry/Developer/ChessLab/ChessLabTests/ScannerFixtures/'
cases=[('chesscom_endgame_rook.png','5rk1/P7/2R5/5P1p/8/4b3/6K1/8',(3,742,1200)),
       ('chesscom_endgame_pawns.png','3r4/6k1/P1R3p1/4p2p/3bP3/6P1/5PK1/8',(3,742,1200))]
def grid_of(fen):
    rows=[]
    for r in fen.split('/'): rows.append(''.join('.'*int(c) if c.isdigit() else c for c in r))
    return rows
def run(weights, seed):
    common._m=None; common.W=weights
    random.seed(seed); tot=dict(squares=0,fp=0,other=0)
    for f,fen,(bx,by,bs) in cases:
        truth=grid_of(fen)
        for style in range(6):
            im=Image.open(FX+f).convert('RGB'); ov=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(ov)
            cs=bs/8; empties=[(r,c) for r in range(8) for c in range(8) if truth[r][c]=='.']
            dots=random.sample(empties,random.randint(6,16))
            col=[(0,0,0,40),(0,0,0,60),(30,30,30,90),(20,80,30,110),(90,90,90,130),(0,0,0,30)][style]
            rad=cs*random.uniform(.12,.2)
            for r,c in dots:
                cx,cy=bx+(c+.5)*cs,by+(r+.5)*cs; d.ellipse([cx-rad,cy-rad,cx+rad,cy+rad],fill=col)
            # une flèche orange translucide façon chess.com
            r0,c0,r1,c1=[random.randint(0,7) for _ in range(4)]
            p0=(bx+(c0+.5)*cs,by+(r0+.5)*cs); p1=(bx+(c1+.5)*cs,by+(r1+.5)*cs)
            if style%2==0: d.line([p0,p1],fill=(255,170,0,150),width=int(cs*.2)); d.ellipse([p1[0]-cs*.18,p1[1]-cs*.18,p1[0]+cs*.18,p1[1]+cs*.18],fill=(255,170,0,150))
            im=Image.alpha_composite(im.convert('RGBA'),ov).convert('RGB')
            crop=im.crop((bx,by,bx+bs,by+bs)).resize((800,800),Image.BILINEAR)
            g=common.to_grid(common.raw_boxes(crop))
            for r in range(8):
                for c in range(8):
                    t=truth[r][c]; read='.' if g[r][c] is None else common.LET[int(g[r][c][1].argmax())]
                    tot['squares']+=1
                    if t=='.' and read!='.': tot['fp']+=1
                    elif t!=read: tot['other']+=1
    return tot
for name,w in (('actuel (train-6)','/Users/thierry/Developer/ChessLab/runs/detect/runs/detect/train-6/weights/best.pt'),('candidat',os.environ.get('CANDIDATE','exp/cand1.pt'))):
    print(name, run(w,3))
