"""Ajoute au dataset YOLO d'entraînement des copies « photo d'écran » (flou, moiré, reflet,
bruit, JPEG, basse résolution, tonalité, ou le cumul) des mêmes images — mêmes étiquettes.
Usage : python photo_dataset.py DS_SRC DS_DST   (DS_SRC/images/train → DS_DST, originales + dégradées)"""
import sys, os, shutil, random, glob
import numpy as np
from PIL import Image
import degrade
src, dst = sys.argv[1], sys.argv[2]
random.seed(11); degrade.rng = np.random.default_rng(11)
for sub in ('images/train', 'labels/train'):
    os.makedirs(f'{dst}/{sub}', exist_ok=True)
single = [degrade.blur, degrade.lowres, degrade.moire, degrade.glare, degrade.noise, degrade.jpeg, degrade.tone]
n = 0
for img_path in sorted(glob.glob(f'{src}/images/train/*.jpg')):
    name = os.path.basename(img_path)[:-4]
    shutil.copy(img_path, f'{dst}/images/train/{name}.jpg')
    shutil.copy(f'{src}/labels/train/{name}.txt', f'{dst}/labels/train/{name}.txt')
    im = Image.open(img_path).convert('RGB')
    out = degrade.photo(im) if random.random() < .55 else random.choice(single)(im)
    out.save(f'{dst}/images/train/{name}_p.jpg', quality=92)
    shutil.copy(f'{src}/labels/train/{name}.txt', f'{dst}/labels/train/{name}_p.txt')
    n += 1
shutil.copytree(f'{src}/images/val', f'{dst}/images/val', dirs_exist_ok=True) if os.path.isdir(f'{src}/images/val') else None
shutil.copytree(f'{src}/labels/val', f'{dst}/labels/val', dirs_exist_ok=True) if os.path.isdir(f'{src}/labels/val') else None
open(f'{dst}/data.yaml', 'w').write(open(f'{src}/data.yaml').read().replace(src, dst))
print('dégradées :', n)
