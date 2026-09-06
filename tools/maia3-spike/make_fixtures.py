"""Génère les fixtures qui prouvent l'encodeur Swift et le modèle Core ML.

Sortie : ChessLabTests/Fixtures_maia3.json — pour chaque cas :
  - startFEN, moves (UCI, depuis startFEN), selfElo, oppoElo
  - tokens : encodage attendu (64 × 96 bits, hex, une chaîne par case,
    colonnes = 8 positions d'historique × 12 plans, plus ancienne d'abord)
  - legalCount : nombre de coups légaux (promotions comptées ×4)
  - top : les 5 coups les plus probables (UCI côté plateau réel) avec probabilité
  - wdl : [win, draw, loss] du camp au trait

Usage : mlenv/bin/python make_fixtures.py  (depuis tools/maia3-spike, avec
maia3/ cloné et le checkpoint (maia3-23m.pt aujourd'hui, maia3-5m.pt pour le spike) à côté — voir README)
"""
import json, random, sys, types
sys.path.insert(0, "maia3")
# make_fixtures.py [alias] [checkpoint] [sortie]  — défaut : 23m, maia3-23m.pt
ALIAS, CKPT = (sys.argv[1:3] + ["23m", "maia3-23m.pt"])[:2] if len(sys.argv) > 2 else ("23m", "maia3-23m.pt")
import torch, chess
from collections import deque
from maia3.models import MAIA3Model
from maia3.model_registry import resolve_model_spec
from maia3.dataset import tokenize_board, get_legal_moves_mask, get_historical_tokens
from maia3.utils import get_all_possible_moves, mirror_move

random.seed(20260905)
spec = resolve_model_spec(ALIAS)
cfg = types.SimpleNamespace(**spec.config, device="cpu")
model = MAIA3Model(cfg)
sd = torch.load(CKPT, map_location="cpu", weights_only=True)
model.load_state_dict({k.replace("smolgen", "gab"): v for k, v in sd.items()}, strict=False)
model.eval()
all_moves = get_all_possible_moves(); idx = {m: i for i, m in enumerate(all_moves)}

def case(start_fen, moves, self_elo, oppo_elo):
    board = chess.Board(start_fen)
    hist = deque(maxlen=cfg.history); hist.append(tokenize_board(board))
    for u in moves:
        board.push(chess.Move.from_uci(u)); hist.append(tokenize_board(board))
    if board.is_game_over(): return None
    tokens = get_historical_tokens(hist, cfg, 0, 0, 0, 0)          # (64, 97)
    with torch.no_grad():
        lm, lv, _ = model(tokens.unsqueeze(0), torch.tensor([self_elo]), torch.tensor([oppo_elo]))
    mask = get_legal_moves_mask(board, idx)
    probs = torch.softmax(lm[0].masked_fill(~mask, float("-inf")), -1)
    top = torch.topk(probs, min(5, int(mask.sum())))
    tops = []
    for p, i in zip(top.values.tolist(), top.indices.tolist()):
        m = all_moves[i]; m = mirror_move(m) if board.turn == chess.BLACK else m
        tops.append({"uci": m, "p": round(p, 5)})
    # 96 bits par case → 24 hex, bit j = colonne j (MSB first)
    rows = []
    for sq in range(64):
        bits = "".join("1" if tokens[sq][j] > 0.5 else "0" for j in range(96))
        rows.append(f"{int(bits, 2):024x}")
    wdl = torch.softmax(lv[0], -1).tolist()   # [loss, draw, win]
    return {"startFEN": start_fen, "moves": moves, "selfElo": self_elo, "oppoElo": oppo_elo,
            "tokens": rows, "legalCount": int(mask.sum()), "top": tops,
            "wdl": [round(wdl[2], 5), round(wdl[1], 5), round(wdl[0], 5)]}

cases = []
def add(start_fen, moves, elos=((1500, 1500),)):
    for s, o in elos:
        c = case(start_fen, moves, s, o)
        if c: cases.append(c)

START = chess.STARTING_FEN
# 1. Positions de départ et historiques courts (padding), Blancs et Noirs
add(START, [], ((800, 800), (1500, 1500), (2400, 1200)))
add(START, ["e2e4"], ((1100, 1900),))
add(START, ["e2e4", "e7e5"], ((1500, 1500),))
add(START, ["e2e4", "e7e5", "g1f3"], ((1500, 1500),))
# 2. Roque, en passant, promotion, historiques longs : parties aléatoires
def random_game(plies, seed):
    rng = random.Random(seed); b = chess.Board(); moves = []
    for _ in range(plies):
        legal = list(b.legal_moves)
        if not legal: break
        # privilégier captures/roque/promotions pour couvrir les cas rares
        special = [m for m in legal if b.is_castling(m) or m.promotion or b.is_en_passant(m)]
        m = rng.choice(special) if special and rng.random() < 0.7 else rng.choice(legal)
        moves.append(m.uci()); b.push(m)
    return moves
for seed in range(40):
    plies = random.choice([5, 9, 14, 23, 40, 61, 88])
    mv = random_game(plies, seed)
    add(START, mv, ((random.choice([800, 1100, 1500, 1900, 2400]), random.choice([800, 1500, 2200])),))
# 3. Positions de promotion garanties (FEN de départ personnalisé)
add("8/P6k/8/8/8/8/7K/8 w - - 0 1", [], ((1500, 1500),))
add("8/P6k/8/8/8/8/7K/8 w - - 0 1", ["h2g3"], ((1500, 1500),))          # Noirs au trait
add("7k/8/8/8/8/8/p6K/8 b - - 0 1", [], ((1200, 1200),))                 # promotion noire
add("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", [], ((1500, 1500),))          # roques des deux côtés
add("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", ["e1g1"], ((1500, 1500),))
add("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 2", ["f7f5"], ((1500, 1500),))  # e.p. dispo
# 4. Fin de partie proche : mat en un, finales
add("6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1", [], ((800, 800), (2400, 2400)))
add("8/8/4k3/8/8/4K3/4P3/8 w - - 0 1", [], ((1500, 1500),))
add("r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4", [], ((1500, 1500),))

out = sys.argv[3] if len(sys.argv) > 3 else "../../ChessLabTests/Fixtures_maia3.json"
json.dump({"model": spec.name, "history": cfg.history, "cases": cases}, open(out, "w"))
print(len(cases), "cas écrits dans", out)
