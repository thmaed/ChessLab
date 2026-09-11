"""Conversion ONNX d'un checkpoint Maia-3 — volet Android du dérisquage.

    mlenv/bin/python convert_maia3_onnx.py 23m maia3-23m.pt maia3_23m.onnx

Même wrapper `ExportMaia` que la conversion Core ML : c'est une COPIE
CONFORME de celui de convert_maia3.py, recopiée telle quelle. convert_maia3.py
reste figé comme trace de la conversion iOS livrée ; toute correction du
wrapper doit être reportée ici.

Vérifications, dans l'ordre :
  1. le wrapper rend bien les mêmes logits que le modèle d'origine ;
  2. ONNX Runtime rend les mêmes que le wrapper torch ;
  3. ONNX Runtime retrouve les coups des fixtures qui servent DÉJÀ aux tests
     iOS (ChessLabTests/Fixtures_maia3.json) — même référence, deux plateformes.

Produit aussi android_fixture.json : les mêmes cas, prémâchés pour que l'app
Android puisse comparer sans porter l'encodeur.
"""
import sys, time, math, types, json, os
sys.path.insert(0, "maia3")
import torch, torch.nn as nn, torch.nn.functional as F, numpy as np, chess
from maia3.models import MAIA3Model
from maia3.model_registry import resolve_model_spec
from maia3.dataset import tokenize_board, get_legal_moves_mask, get_historical_tokens
from maia3.utils import get_all_possible_moves, mirror_move
from collections import deque

alias, ckpt_path, out_path = (sys.argv + ["23m", "maia3-23m.pt", "maia3_23m.onnx"])[1:4]
spec = resolve_model_spec(alias)
cfg = types.SimpleNamespace(**spec.config, device="cpu")
model = MAIA3Model(cfg)
sd = torch.load(ckpt_path, map_location="cpu", weights_only=True)
sd = sd["model_state_dict"] if "model_state_dict" in sd else sd
sd = {k.replace("smolgen", "gab"): v for k, v in sd.items()}
model.load_state_dict(sd, strict=False)
model.eval()
print(f"{spec.display_name}: {sum(p.numel() for p in model.parameters())/1e6:.2f} M paramètres")

all_moves = get_all_possible_moves(); idx = {m: i for i, m in enumerate(all_moves)}

def masked_probs(b, logits):
    mask = get_legal_moves_mask(b, idx)
    return torch.softmax(logits.masked_fill(~mask, float("-inf")), -1)

def top_moves(b, logits, k=5):
    p, i = torch.topk(masked_probs(b, logits), min(k, int(get_legal_moves_mask(b, idx).sum())))
    out = []
    for pp, ii in zip(p.tolist(), i.tolist()):
        m = all_moves[ii]
        if b.turn == chess.BLACK: m = mirror_move(m)
        out.append((m, round(pp, 5)))
    return out

class ExportMaia(nn.Module):
    """Le même réseau, écrit pour l'export : formes littérales, batch 1."""
    def __init__(self, m):
        super().__init__(); self.m = m; self.cfg = m.cfg
        self.register_buffer("elo_low", m.elo_embedding_low.weight.detach().clone())
        self.register_buffer("elo_high", m.elo_embedding_high.weight.detach().clone())
    def elo_emb(self, elo):
        w = torch.clamp(elo, 0.0, 5000.0) / 5000.0
        return w[:, None] * self.elo_low + (1 - w)[:, None] * self.elo_high
    def rms(self, norm, x):
        if isinstance(norm, nn.RMSNorm):
            return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + (norm.eps or 1e-6)) * norm.weight
        return norm(x)
    def sq_bias(self, mha, x):
        H = mha.num_heads; G = mha.gen_size
        if mha.sm1 is not None:
            # 23M : une projection PAR CASE, concaténée (64 × p), puis sm2.
            y = mha.sm1(x).reshape(1, -1)
        else:
            # 5M : moyenne des cases.
            y = torch.mean(x, dim=1)
        y = mha.sm_act(mha.sm2(y))
        y = mha.ln1(y)
        y = mha.sm_act(mha.sm3(y))
        y = mha.ln2(y).reshape(H, G)
        return torch.matmul(y, mha.gab_weight.t()).reshape(H, 64, 64)
    def attn(self, mha, x):
        H = mha.num_heads; d = mha.mha.head_dim
        bias = self.sq_bias(mha, x)
        m = mha.mha
        qkv = F.linear(x, m.in_proj_weight, m.in_proj_bias)
        q, k, v = qkv.chunk(3, dim=-1)
        q = q.reshape(64, H, d).permute(1, 0, 2)
        k = k.reshape(64, H, d).permute(1, 0, 2)
        v = v.reshape(64, H, d).permute(1, 0, 2)
        s = torch.bmm(q, k.transpose(1, 2)) * (1.0 / math.sqrt(d)) + bias
        a = torch.softmax(s, -1)
        o = torch.bmm(a, v).permute(1, 0, 2).reshape(1, 64, H * d)
        return m.out_proj(o)
    def forward(self, tokens, self_elo, oppo_elo):
        m = self.m; c = self.cfg
        tokens = tokens[:, :, :12 * c.history]
        se = self.elo_emb(self_elo)[:, None, :].expand(-1, 64, -1)
        oe = self.elo_emb(oppo_elo)[:, None, :].expand(-1, 64, -1)
        x = m.token_projection(torch.cat([tokens, se, oe], -1))
        if hasattr(m, "abs_pe"):
            x = m.abs_pe(x)
        for blk in m.transformer.layers:
            x = self.rms(blk.norm1, x + self.attn(blk.self_attn, x))
            x = self.rms(blk.norm2, x + blk.linear2(F.gelu(blk.linear1(x))))
        x = m.transformer.norm(x)
        sq_from = m.proj_sq_from(x); sq_to = m.proj_sq_to(x)
        scores = torch.bmm(sq_from, sq_to.transpose(1, 2)) / math.sqrt(c.head_hid_dim)
        flat = scores.reshape(1, 4096)
        base = scores[:, 48:56, 56:64]
        pb = m.promo_bias_proj(sq_to[:, 56:64, :]) * math.sqrt(c.head_hid_dim)
        promo = (base[:, :, :, None] + pb[:, None, :, :]).reshape(1, 256)
        logits_move = torch.cat([flat, promo], 1)
        g = m.last_ln(x.mean(1))
        logits_value = m.fc_value(F.relu(m.fc_value_hid(g)))
        return logits_move, logits_value

w = ExportMaia(model).eval()

# ---------------------------------------------------------------- 1. wrapper
FENS = [
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
    "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
    "8/8/4k3/8/8/4K3/4P3/8 w - - 0 1",
    "6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1",
    "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
]
def inputs_for(fen):
    b = chess.Board(fen)
    hist = deque([tokenize_board(b)], maxlen=cfg.history)
    return b, get_historical_tokens(hist, cfg, 0.0, 0.0, 0.0, 0.0).unsqueeze(0)

with torch.no_grad():
    worst = 0.0
    for fen in FENS:
        b, t = inputs_for(fen)
        lm0, lv0, _ = model(t, torch.tensor([1500]), torch.tensor([1500]))
        lm1, lv1 = w(t, torch.tensor([1500.0]), torch.tensor([1500.0]))
        worst = max(worst, float((lm0 - lm1).abs().max()), float((lv0 - lv1).abs().max()))
print(f"1. wrapper vs original : max |delta logit| = {worst:.2e}")

# ------------------------------------------------------------------ 2. export
ex_tokens = torch.zeros(1, 64, 12 * cfg.history + 1)
ex_elo = torch.tensor([1500.0])
torch.onnx.export(
    w, (ex_tokens, ex_elo, ex_elo), out_path,
    input_names=["tokens", "self_elo", "oppo_elo"],
    output_names=["move_logits", "value_logits"],
    opset_version=17, dynamo=False,
)
size_mb = os.path.getsize(out_path) / 1e6
print(f"2. ONNX fp32 ecrit : {out_path} ({size_mb:.1f} Mo)")

import onnxruntime as ort
sess = ort.InferenceSession(out_path, providers=["CPUExecutionProvider"])
def run(sess, tokens, self_elo, oppo_elo):
    o = sess.run(None, {"tokens": tokens.numpy().astype(np.float32),
                        "self_elo": np.array([self_elo], dtype=np.float32),
                        "oppo_elo": np.array([oppo_elo], dtype=np.float32)})
    return torch.tensor(o[0]).reshape(1, -1).float()

agree = tot = 0; maxd = 0.0
with torch.no_grad():
    for fen in FENS:
        for elo in (1100, 1500, 1900):
            b, t = inputs_for(fen)
            lm, _ = w(t, torch.tensor([float(elo)]), torch.tensor([float(elo)]))
            om = run(sess, t, elo, elo)
            agree += top_moves(b, lm[0], 1)[0][0] == top_moves(b, om[0], 1)[0][0]; tot += 1
            maxd = max(maxd, float((masked_probs(b, lm[0]) - masked_probs(b, om[0])).abs().max()))
print(f"3. accord top-1 torch/ONNX : {agree}/{tot}, max |delta prob| = {maxd:.2e}")

# ------------------------------------------------- 4. contre les fixtures iOS
FIX = "../../ChessLabTests/Fixtures_maia3.json"
fixtures = json.load(open(FIX))
def tokens_from_hex(rows):
    t = torch.zeros(1, 64, 12 * cfg.history + 1)
    for sq, row in enumerate(rows):
        bits = bin(int(row, 16))[2:].zfill(96)
        for j, c in enumerate(bits):
            if c == "1": t[0, sq, j] = 1.0
    return t

ok = tot2 = 0; worstp = 0.0; android = []
for c in fixtures["cases"]:
    b = chess.Board(c["startFEN"])
    for u in c["moves"]: b.push(chess.Move.from_uci(u))
    t = tokens_from_hex(c["tokens"])
    om = run(sess, t, c["selfElo"], c["oppoElo"])
    got = top_moves(b, om[0], 5)
    exp = c["top"]
    tot2 += 1
    ok += got[0][0] == exp[0]["uci"]
    by = {m: p for m, p in got}
    worstp = max(worstp, max(abs(by.get(e["uci"], 0.0) - e["p"]) for e in exp))
    mask = get_legal_moves_mask(b, idx)
    legal = [{"i": i, "uci": (mirror_move(all_moves[i]) if b.turn == chess.BLACK else all_moves[i])}
             for i in range(len(all_moves)) if bool(mask[i])]
    android.append({"label": c["startFEN"][:20] + ("+" + str(len(c["moves"])) if c["moves"] else ""),
                    "tokens": c["tokens"], "selfElo": c["selfElo"], "oppoElo": c["oppoElo"],
                    "legal": legal, "expect": exp[0]["uci"], "expectP": exp[0]["p"]})
print(f"4. accord top-1 ONNX / fixtures iOS : {ok}/{tot2}, max |delta prob| = {worstp:.4f}")

json.dump({"model": fixtures["model"], "cases": android}, open("android_fixture.json", "w"))
print(f"   android_fixture.json : {len(android)} cas, {os.path.getsize('android_fixture.json')/1e3:.0f} Ko")

# ----------------------------------------------------------------- 5. latence
inp = {"tokens": ex_tokens.numpy(), "self_elo": np.array([1500.], dtype=np.float32),
       "oppo_elo": np.array([1500.], dtype=np.float32)}
for _ in range(5): sess.run(None, inp)
t0 = time.perf_counter(); N = 30
for _ in range(N): sess.run(None, inp)
print(f"5. latence ONNX Runtime CPU sur ce Mac : {(time.perf_counter()-t0)/N*1000:.1f} ms")

# -------------------------------------------------------------------- 6. fp16
# Côté iOS le modèle embarqué est en fp16 (43 Mo). Même exigence ici : un
# fp32 de 92 Mo dans l'APK n'est pas tenable au vu du plafond de Play.
fp16_path = out_path.replace(".onnx", "_fp16.onnx")
converter = None
try:
    from onnxruntime.transformers.float16 import convert_float_to_float16
    converter = convert_float_to_float16
except ImportError:
    try:
        from onnxconverter_common.float16 import convert_float_to_float16
        converter = convert_float_to_float16
    except ImportError:
        pass

if converter is None:
    print("6. fp16 : aucun convertisseur disponible (pip install onnxconverter-common)")
else:
    import onnx
    m16 = converter(onnx.load(out_path), keep_io_types=True)
    # onnx 1.22 écrit une IR version 11 que les runtimes mobiles publiés
    # refusent encore ("Unsupported model IR version"). On la ramène à 10 :
    # le graphe, lui, est en opset 17, largement supporté.
    m16.ir_version = min(m16.ir_version, 10)
    onnx.save(m16, fp16_path)
    print(f"6. ONNX fp16 : {fp16_path} ({os.path.getsize(fp16_path)/1e6:.1f} Mo)")

    s16 = ort.InferenceSession(fp16_path, providers=["CPUExecutionProvider"])
    ok16 = tot16 = 0; worst16 = 0.0
    for c in fixtures["cases"]:
        b = chess.Board(c["startFEN"])
        for u in c["moves"]: b.push(chess.Move.from_uci(u))
        om = run(s16, tokens_from_hex(c["tokens"]), c["selfElo"], c["oppoElo"])
        got = top_moves(b, om[0], 5); exp = c["top"]
        tot16 += 1; ok16 += got[0][0] == exp[0]["uci"]
        by = {m: p for m, p in got}
        worst16 = max(worst16, max(abs(by.get(e["uci"], 0.0) - e["p"]) for e in exp))
    print(f"   accord top-1 fp16 / fixtures iOS : {ok16}/{tot16}, max |delta prob| = {worst16:.4f}")

    for _ in range(5): s16.run(None, inp)
    t0 = time.perf_counter()
    for _ in range(N): s16.run(None, inp)
    print(f"   latence fp16 CPU sur ce Mac : {(time.perf_counter()-t0)/N*1000:.1f} ms")
