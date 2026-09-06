import sys, types, math
sys.path.insert(0, "maia3")
import torch, chess
from maia3.models import MAIA3Model
from maia3.model_registry import resolve_model_spec
from maia3.dataset import tokenize_board, get_legal_moves_mask, get_historical_tokens
from maia3.utils import get_all_possible_moves, mirror_move
from collections import deque
spec = resolve_model_spec("5m"); cfg = types.SimpleNamespace(**spec.config, device="cpu")
model = MAIA3Model(cfg); sd = torch.load("maia3-5m.pt", map_location="cpu", weights_only=True)
model.load_state_dict({k.replace("smolgen","gab"):v for k,v in sd.items()}, strict=False); model.eval()
all_moves = get_all_possible_moves(); idx = {m:i for i,m in enumerate(all_moves)}
def probe(name, fen, elos=(800,1100,1500,1900,2400), k=4):
    b = chess.Board(fen); hist = deque([tokenize_board(b)], maxlen=cfg.history)
    t = get_historical_tokens(hist, cfg, 0,0,0,0).unsqueeze(0)
    print(f"\n{name}\n  {fen}")
    for elo in elos:
        with torch.no_grad(): lm, lv, _ = model(t, torch.tensor([elo]), torch.tensor([elo]))
        mask = get_legal_moves_mask(b, idx)
        p = torch.softmax(lm[0].masked_fill(~mask, float('-inf')), -1)
        ent = float(-(p[p>0]*p[p>0].log()).sum())
        top = torch.topk(p, k)
        items = []
        for pp, ii in zip(top.values.tolist(), top.indices.tolist()):
            m = all_moves[ii]; m = mirror_move(m) if b.turn == chess.BLACK else m
            items.append(f"{b.san(chess.Move.from_uci(m))} {pp*100:.0f}%")
        wdl = torch.softmax(lv[0], -1).tolist()
        print(f"  {elo:>4}: {', '.join(items):<52} H={ent:.2f}  W/D/L={wdl[2]*100:.0f}/{wdl[1]*100:.0f}/{wdl[0]*100:.0f}")
probe("Cavalier en prise (1.e4 e5 2.Cf3 d6 3.Cxe5?? — dxe5 gagne une pièce)", "rnbqkbnr/ppp2ppp/3p4/4N3/4P3/8/PPPP1PPP/RNBQKB1R b KQkq - 0 3")
probe("Mat du couloir disponible (Ta8#)", "6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1")
probe("Menace de mat du berger : Noirs au trait, Cf6?? perd sur Dxf7#", "r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR b KQkq - 3 3")
probe("Dame en prise gratuite (Dd4 attaquée par Cc6, non défendue)", "r1bqkbnr/pppp1ppp/2n5/8/3QP3/8/PPP2PPP/RNB1KBNR b KQkq - 0 4")
probe("Finale T+R vs R : technique (position de Lucena simplifiée)", "1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1")
probe("Position calme (Italienne, coup 6, Blancs)", "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 6 5")
probe("Sacrifice thématique Fxh7+ (attaque grecque) disponible", "r1bq1rk1/ppp2ppp/2n1pn2/3p4/1bPP4/2NBPN2/PP3PPP/R2QK2R w KQ - 0 8")
