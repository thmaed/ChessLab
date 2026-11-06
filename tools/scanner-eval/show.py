import sys
from common import *
from PIL import ImageDraw
k=int(sys.argv[1]); png=f'../cg/out/{k:04d}.png'; meta=json.load(open(f'../cg/out/{k:04d}.json'))
img=board_crop(png,meta); d=ImageDraw.Draw(img); g=to_grid(raw_boxes(img))
for r in range(8):
    for c in range(8):
        d.rectangle([c*100,r*100,c*100+99,r*100+99],outline=(255,0,255) if False else None)
        t=meta['grid'][r][c]
        if g[r][c] is not None:
            read=LET[int(g[r][c][1].argmax())]
            col=(0,200,0) if read==t else (255,0,0)
            d.text((c*100+4,r*100+4),f'{read} {g[r][c][0]:.2f}',fill=col)
            d.rectangle([c*100+2,r*100+2,c*100+97,r*100+97],outline=col,width=3)
img.save(f'show{k}.png'); print(meta['set'],meta['flags'])
