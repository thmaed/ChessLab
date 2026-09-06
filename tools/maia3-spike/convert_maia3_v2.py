"""Spike v2 : wrapper « exportable » de Maia3-5M (mêmes poids, forward réécrit sans
int()/embedding-lookup/boucles Python), conversion Core ML, accord, latence."""
import sys, time, math, types, subprocess
sys.path.insert(0, "maia3")
import torch, torch.nn as nn, torch.nn.functional as F, numpy as np, chess
from maia3.models import MAIA3Model
from maia3.model_registry import resolve_model_spec
from maia3.dataset import tokenize_board, get_legal_moves_mask, get_historical_tokens
from maia3.utils import get_all_possible_moves, mirror_move
from collections import deque

spec = resolve_model_spec("5m")
cfg = types.SimpleNamespace(**spec.config, device="cpu")
model = MAIA3Model(cfg)
sd = torch.load("maia3-5m.pt", map_location="cpu", weights_only=True)
sd = sd["model_state_dict"] if "model_state_dict" in sd else sd
sd = {k.replace("smolgen", "gab"): v for k, v in sd.items()}
print("load:", model.load_state_dict(sd, strict=False))
model.eval()
print(f"params: {sum(p.numel() for p in model.parameters())/1e6:.2f} M")

all_moves = get_all_possible_moves(); idx = {m: i for i, m in enumerate(all_moves)}
FENS = [
    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3",
    "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
    "rnbqkb1r/pp3ppp/2p1pn2/3p4/2PP4/2N2N2/PP2PPPP/R1BQKB1R w KQkq - 0 5",
    "r2q1rk1/ppp2ppp/2np1n2/2b1p1B1/2B1P1b1/2NP1N2/PPP2PPP/R2Q1RK1 w - - 0 8",
    "8/8/4k3/8/8/4K3/4P3/8 w - - 0 1",
    "6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1",
    "r1bqkbnr/pppp1ppp/2n5/4p3/3PP3/5N2/PPP2PPP/RNBQKB1R b KQkq d3 0 3",
    "rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2",
    "r1bq1rk1/pp2bppp/2n1pn2/2pp4/3P4/2PBPN2/PP1N1PPP/R1BQ1RK1 w - - 0 8",
    "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 6 5",
    "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4",
]

def inputs_for(fen):
    b = chess.Board(fen)
    hist = deque([tokenize_board(b)], maxlen=cfg.history)
    return b, get_historical_tokens(hist, cfg, 0.0, 0.0, 0.0, 0.0).unsqueeze(0)

def masked_probs(b, logits):
    mask = get_legal_moves_mask(b, idx)
    return torch.softmax(logits.masked_fill(~mask, float("-inf")), -1)

def top_moves(b, logits, k=5):
    p, i = torch.topk(masked_probs(b, logits), k)
    out = []
    for pp, ii in zip(p.tolist(), i.tolist()):
        m = all_moves[ii]
        if b.turn == chess.BLACK: m = mirror_move(m)
        out.append((m, round(pp, 3)))
    return out

# ---------------- wrapper exportable ----------------
class ExportMaia(nn.Module):
    def __init__(self, m):
        super().__init__(); self.m = m; self.cfg = m.cfg
        self.register_buffer("elo_low", m.elo_embedding_low.weight.detach().clone())    # (1, dim_emb)
        self.register_buffer("elo_high", m.elo_embedding_high.weight.detach().clone())
    def elo_emb(self, elo):
        w = torch.clamp(elo, 0.0, 5000.0) / 5000.0          # (B,)
        return w[:, None] * self.elo_low + (1 - w)[:, None] * self.elo_high  # (B, dim_emb)
    def rms(self, norm, x):
        if isinstance(norm, nn.RMSNorm):
            return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + (norm.eps or 1e-6)) * norm.weight
        return norm(x)
    def sq_bias(self, mha, x):
        # réimplémentation de MHA._sq_bias avec des formes LITTÉRALES (batch = 1)
        H = mha.num_heads; G = mha.gen_size
        y = torch.mean(x, dim=1)                       # (1, d_model)   (gab_per_square_dim == 0)
        y = mha.sm_act(mha.sm2(y))
        y = mha.ln1(y)
        y = mha.sm_act(mha.sm3(y))
        y = mha.ln2(y).reshape(H, G)                   # (H, gen)
        b = torch.matmul(y, mha.gab_weight.t())        # (H, 4096)
        return b.reshape(H, 64, 64)
    def attn(self, mha, x):
        H = mha.num_heads; d = mha.mha.head_dim
        bias = self.sq_bias(mha, x)                    # (H,64,64)
        m = mha.mha
        qkv = F.linear(x, m.in_proj_weight, m.in_proj_bias)   # (1,64,3d)
        q, k, v = qkv.chunk(3, dim=-1)
        q = q.reshape(64, H, d).permute(1, 0, 2)       # (H,64,d)
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
        for blk in m.transformer.layers:
            x = self.rms(blk.norm1, x + self.attn(blk.self_attn, x))
            x = self.rms(blk.norm2, x + blk.linear2(F.gelu(blk.linear1(x))))
        x = m.transformer.norm(x)
        sq_from = m.proj_sq_from(x); sq_to = m.proj_sq_to(x)
        scores = torch.bmm(sq_from, sq_to.transpose(1, 2)) / math.sqrt(c.head_hid_dim)  # (B,64,64)
        flat = scores.reshape(1, 4096)
        base = scores[:, 48:56, 56:64]                                   # (B, from_file, to_file)
        pb = m.promo_bias_proj(sq_to[:, 56:64, :]) * math.sqrt(c.head_hid_dim)  # (B, to_file, 4)
        promo = (base[:, :, :, None] + pb[:, None, :, :]).reshape(1, 256)
        logits_move = torch.cat([flat, promo], 1)
        g = m.last_ln(x.mean(1))
        logits_value = m.fc_value(F.relu(m.fc_value_hid(g)))
        return logits_move, logits_value

w = ExportMaia(model).eval()

with torch.no_grad():
    # équivalence wrapper vs original
    worst = 0.0
    for fen in FENS:
        b, t = inputs_for(fen)
        lm0, lv0, _ = model(t, torch.tensor([1500]), torch.tensor([1500]))
        lm1, lv1 = w(t, torch.tensor([1500.0]), torch.tensor([1500.0]))
        worst = max(worst, float((lm0 - lm1).abs().max()), float((lv0 - lv1).abs().max()))
    print(f"wrapper vs original, max |Δlogit| = {worst:.2e}")
    for elo in (800, 1500, 2400):
        b, t = inputs_for(FENS[11])
        lm, lv = w(t, torch.tensor([float(elo)]), torch.tensor([float(elo)]))
        print(f"  elo {elo} (mat du berger dispo Qxf7#): top {top_moves(b, lm[0])}  wdl(l,d,w)={torch.softmax(lv[0],-1).numpy().round(3)}")
    for elo in (800, 1500, 2400):
        b, t = inputs_for(FENS[3])
        lm, lv = w(t, torch.tensor([float(elo)]), torch.tensor([float(elo)]))
        print(f"  elo {elo} (Semi-Slav move 5): top {top_moves(b, lm[0])}")
    b, t = inputs_for(FENS[0])
    for _ in range(5): w(t, torch.tensor([1500.0]), torch.tensor([1500.0]))
    t0 = time.perf_counter(); N = 30
    for _ in range(N): w(t, torch.tensor([1500.0]), torch.tensor([1500.0]))
    print(f"torch cpu latency (M2, 1 thread pool): {(time.perf_counter()-t0)/N*1000:.1f} ms")

import coremltools as ct
ex_tokens = torch.zeros(1, 64, 12 * cfg.history + 1); ex_elo = torch.tensor([1500.0])
traced = torch.jit.trace(w, (ex_tokens, ex_elo, ex_elo))
mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="tokens", shape=ex_tokens.shape, dtype=np.float32),
            ct.TensorType(name="self_elo", shape=(1,), dtype=np.float32),
            ct.TensorType(name="oppo_elo", shape=(1,), dtype=np.float32)],
    outputs=[ct.TensorType(name="move_logits"), ct.TensorType(name="value_logits")],
    convert_to="mlprogram", compute_precision=ct.precision.FLOAT16,
    minimum_deployment_target=ct.target.iOS17,
)
mlmodel.save("Maia3_5M.mlpackage")
print("mlpackage:", subprocess.run(["du", "-sh", "Maia3_5M.mlpackage"], capture_output=True, text=True).stdout.strip())

agree = 0; total = 0; maxdiff = 0.0
with torch.no_grad():
    for fen in FENS:
        for elo in (1100, 1500, 1900):
            b, t = inputs_for(fen)
            lm, _ = w(t, torch.tensor([float(elo)]), torch.tensor([float(elo)]))
            out = mlmodel.predict({"tokens": t.numpy().astype(np.float32),
                                   "self_elo": np.array([elo], dtype=np.float32),
                                   "oppo_elo": np.array([elo], dtype=np.float32)})
            cm = torch.tensor(np.asarray(out["move_logits"])).reshape(1, -1).float()
            agree += top_moves(b, lm[0], 1)[0][0] == top_moves(b, cm[0], 1)[0][0]; total += 1
            maxdiff = max(maxdiff, float((masked_probs(b, lm[0]) - masked_probs(b, cm[0])).abs().max()))
print(f"top-1 agreement torch/coreml fp16: {agree}/{total}, max |Δprob| = {maxdiff:.4f}")
inp = {"tokens": ex_tokens.numpy(), "self_elo": np.array([1500.], dtype=np.float32), "oppo_elo": np.array([1500.], dtype=np.float32)}
for _ in range(5): mlmodel.predict(inp)
t0 = time.perf_counter(); N = 50
for _ in range(N): mlmodel.predict(inp)
print(f"coreml latency on this Mac (M2): {(time.perf_counter()-t0)/N*1000:.1f} ms")
