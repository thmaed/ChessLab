"""Conversion ONNX du détecteur de pièces — volet Scanner du dérisquage Android.

    ../maia3-spike/mlenv/bin/python convert_yolo_onnx.py

Compare le modèle Core ML RÉELLEMENT EMBARQUÉ dans l'app
(ChessLab/ChessPiecesYOLO.mlpackage) au même réseau exporté en ONNX, sur les
images de fixtures du scanner. Produit ensuite de quoi rejouer la comparaison
sur Android : l'image déjà mise au format d'entrée, et les détections attendues.

Portée : ce script mesure LE MODÈLE, pas le pipeline. La détection du plateau
(VNDetectRectanglesRequest) et la rectification ne sont pas portées ici — le
recadrage est choisi par un balayage grossier, ce qui suffit à obtenir une
image de plateau exploitable. Porter la rectification est du travail ordinaire
(OpenCV), pas un risque de conversion.
"""
import json, pathlib, sys, time
import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
CKPT = ROOT / "runs/detect/runs/detect/train-6/weights/best.pt"
MLPKG = ROOT / "ChessLab/ChessPiecesYOLO.mlpackage"
FIXDIR = ROOT / "ChessLabTests/ScannerFixtures"
SIZE = 640
CONF, IOU = 0.25, 0.7
NAMES = ["white-pawn", "white-knight", "white-bishop", "white-rook", "white-queen", "white-king",
         "black-pawn", "black-knight", "black-bishop", "black-rook", "black-queen", "black-king"]

# ------------------------------------------------------- 1. le .pt et son contrat
from ultralytics import YOLO
model = YOLO(str(CKPT))
names = [model.model.names[i] for i in range(len(model.model.names))]
print(f"1. checkpoint : {CKPT.relative_to(ROOT)}")
print(f"   {len(names)} classes, contrat {'IDENTIQUE' if names == NAMES else 'DIFFERENT'} au modèle embarqué")
if names != NAMES:
    print("   attendu :", NAMES); print("   obtenu  :", names); sys.exit(1)

# --------------------------------------------------------------- 2. export ONNX
onnx_path = pathlib.Path(model.export(format="onnx", imgsz=SIZE, opset=17, verbose=False))
# ultralytics écrit à côté du .pt, dans runs/ (ignoré par Git) : on rapatrie
# sous un nom stable, c'est ce fichier que le build Android consomme.
local_onnx = pathlib.Path("chess_pieces_yolo.onnx")
local_onnx.write_bytes(onnx_path.read_bytes())
print(f"2. ONNX écrit : {local_onnx.name} ({local_onnx.stat().st_size/1e6:.1f} Mo, "
      f"fp32 — le Core ML embarqué est en fp16, 5,2 Mo)")

import onnxruntime as ort
sess = ort.InferenceSession(str(onnx_path), providers=["CPUExecutionProvider"])
in_name = sess.get_inputs()[0].name

# ------------------------------------------------ 3. le Core ML réellement livré
import coremltools as ct
mlmodel = ct.models.MLModel(str(MLPKG), compute_units=ct.ComputeUnit.CPU_ONLY)
print(f"3. Core ML embarqué chargé : {MLPKG.name}")

# ------------------------------------------------------------ 4. les entrées
def square_crop(img, y):
    """Découpe un carré de la largeur de l'image, à l'ordonnée y."""
    w, h = img.size
    side = min(w, h)
    y = max(0, min(y, h - side))
    return img.crop((0, y, side, y + side)).resize((SIZE, SIZE), Image.BILINEAR)

def coreml_detect(pil):
    out = mlmodel.predict({"image": pil})
    conf, coord = np.asarray(out["confidence"]), np.asarray(out["coordinates"])
    dets = []
    for c, xywh in zip(conf, coord):
        k = int(np.argmax(c))
        if c[k] >= CONF:
            dets.append({"cls": k, "conf": float(c[k]), "xywh": [float(v) for v in xywh]})
    return sorted(dets, key=lambda d: -d["conf"])

def onnx_detect(pil):
    """Sortie brute → détections. La NMS est réécrite ici plutôt qu'empruntée
    à ultralytics (elle a changé de module en 8.4) : c'est de toute façon ce
    que devra faire Android, l'export ONNX ne l'embarquant pas — contrairement
    à l'export Core ML. Cette fonction est donc la référence de YoloBench.kt."""
    x = np.asarray(pil, dtype=np.float32).transpose(2, 0, 1)[None] / 255.0
    raw = sess.run(None, {in_name: x})[0][0]          # (4 + classes) × ancres
    boxes, scores = raw[:4], raw[4:]
    cls = scores.argmax(0)
    conf = scores.max(0)
    keep = np.nonzero(conf >= CONF)[0]
    order = keep[np.argsort(-conf[keep])]

    dets = []
    for i in order:
        cx, cy, w, h = boxes[:, i]
        box = (cx / SIZE, cy / SIZE, w / SIZE, h / SIZE)
        # NMS PAR CLASSE, glouton : on ne garde que ce qui ne recouvre pas déjà
        # une boîte plus sûre de la même classe.
        if any(d["cls"] == int(cls[i]) and iou(d["xywh"], box) > IOU for d in dets):
            continue
        dets.append({"cls": int(cls[i]), "conf": float(conf[i]), "xywh": list(box)})
    return dets

def iou(a, b):
    ax, ay, aw, ah = a; bx, by, bw, bh = b
    a1, a2, a3, a4 = ax - aw / 2, ay - ah / 2, ax + aw / 2, ay + ah / 2
    b1, b2, b3, b4 = bx - bw / 2, by - bh / 2, bx + bw / 2, by + bh / 2
    ix = max(0.0, min(a3, b3) - max(a1, b1)); iy = max(0.0, min(a4, b4) - max(a2, b2))
    inter = ix * iy
    union = aw * ah + bw * bh - inter
    return inter / union if union > 0 else 0.0

# ---------------------------------------------------- 5. comparaison sur fixtures
manifest = json.load(open(FIXDIR / "manifest.json"))
android = []
print("4. comparaison Core ML (embarqué) vs ONNX, par image :")
for entry in manifest:
    img = Image.open(FIXDIR / entry["file"]).convert("RGB")
    # Balayage grossier : on retient le recadrage qui donne le plus de pièces.
    best, best_pil = [], None
    for frac in [i / 20 for i in range(21)]:
        pil = square_crop(img, int(frac * (img.size[1] - min(img.size))))
        d = coreml_detect(pil)
        if len(d) > len(best): best, best_pil = d, pil
    cm = best
    on = onnx_detect(best_pil)

    matched = 0; worst_iou = 1.0; worst_conf = 0.0
    for d in cm:
        cands = [o for o in on if o["cls"] == d["cls"]]
        if not cands: continue
        o = max(cands, key=lambda o: iou(d["xywh"], o["xywh"]))
        j = iou(d["xywh"], o["xywh"])
        if j > 0.9:
            matched += 1
            worst_iou = min(worst_iou, j)
            worst_conf = max(worst_conf, abs(d["conf"] - o["conf"]))
    print(f"   {entry['file']:32s} Core ML {len(cm):2d} pièces, ONNX {len(on):2d}, "
          f"appariées {matched}/{len(cm)}, IoU min {worst_iou:.3f}, Δconf max {worst_conf:.3f}")

    name = entry["file"].replace(".png", "_640.png")
    best_pil.save(pathlib.Path(name))
    android.append({"image": name, "expect": cm})

json.dump({"conf": CONF, "iou": IOU, "names": NAMES, "cases": android},
          open("android_yolo_fixture.json", "w"))
print(f"5. android_yolo_fixture.json : {len(android)} images, "
      f"{sum(len(c['expect']) for c in android)} détections attendues")

# --------------------------------------------------------------- 6. latences
pil = Image.open(android[0]["image"])
x = np.asarray(pil.convert("RGB"), dtype=np.float32).transpose(2, 0, 1)[None] / 255.0
for _ in range(3): sess.run(None, {in_name: x})
t0 = time.perf_counter(); N = 20
for _ in range(N): sess.run(None, {in_name: x})
print(f"6. latence ONNX Runtime CPU sur ce Mac : {(time.perf_counter()-t0)/N*1000:.1f} ms")
for _ in range(3): mlmodel.predict({"image": pil})
t0 = time.perf_counter()
for _ in range(N): mlmodel.predict({"image": pil})
print(f"   latence Core ML CPU sur ce Mac      : {(time.perf_counter()-t0)/N*1000:.1f} ms")
