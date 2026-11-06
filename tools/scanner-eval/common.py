import json, glob, numpy as np, torch, torchvision
from PIL import Image
from ultralytics import YOLO
CLASSES=['white-pawn','white-knight','white-bishop','white-rook','white-queen','white-king','black-pawn','black-knight','black-bishop','black-rook','black-queen','black-king']
LET='PNBRQKpnbrqk'
import os
W=os.environ.get('WEIGHTS','/Users/thierry/Developer/ChessLab/runs/detect/runs/detect/train-6/weights/best.pt')
_m=None
def model():
    global _m
    if _m is None: _m=YOLO(W).model.eval()
    return _m
def raw_boxes(img, conf=0.25, iou=0.45, size=640, tta=None):
    """img: PIL carrée. Rend [(cx,cy,w,h, scores[12])] normalisés, NMS classe-agnostique sur le meilleur score."""
    x=np.asarray(img.convert('RGB').resize((size,size),Image.BILINEAR),dtype=np.float32)/255
    t=torch.from_numpy(x).permute(2,0,1)[None]
    with torch.no_grad(): out=model()(t)[0][0]   # (16,8400)
    out=out.T; xywh=out[:,:4]; sc=out[:,4:]
    best=sc.max(1).values; keep=best>conf
    xywh,sc,best=xywh[keep],sc[keep],best[keep]
    xyxy=torch.stack([xywh[:,0]-xywh[:,2]/2,xywh[:,1]-xywh[:,3]/2,xywh[:,0]+xywh[:,2]/2,xywh[:,1]+xywh[:,3]/2],1)
    k=torchvision.ops.nms(xyxy,best,iou)
    return [(float(xywh[i,0])/size,float(xywh[i,1])/size,float(xywh[i,2])/size,float(xywh[i,3])/size,sc[i].numpy()) for i in k]
def to_grid(boxes):
    """Mapping de YOLODetectionMapper : bas-centre remonté d'une demi-case ; la plus sûre gagne."""
    g=[[None]*8 for _ in range(8)]
    for cx,cy,w,h,sc in boxes:
        c=min(max(int(cx*8),0),7); r=min(max(int((cy+h/2-1/16)*8),0),7)
        conf=float(sc.max())
        if g[r][c] is None or conf>g[r][c][0]: g[r][c]=(conf,sc)
    return g
def board_crop(png,meta):
    im=Image.open(png).convert('RGB'); x,y,w,h=meta['bbox']
    return im.crop((round(x),round(y),round(x+w),round(y+h))).resize((800,800),Image.BILINEAR)
def items(folder):
    for j in sorted(glob.glob(folder+'/*.json')):
        yield j[:-5]+'.png', json.load(open(j))
