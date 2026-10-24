"""S2 — estimer le niveau d'un joueur par la VRAISEMBLANCE de ses coups sous Maia-3.

Question : à partir des seules parties d'un joueur, peut-on retrouver sa cote
Lichess, et avec quelle précision selon le nombre de parties ?

Méthode : pour chaque coup d'un joueur, Maia-3 (23M) donne la probabilité de
chaque coup légal à un niveau N. La vraisemblance d'une partie au niveau N est
la somme des log-probabilités des coups réellement joués. L'estimation est le
N qui la maximise (grille 700-2600, pas de 100, affinée par une parabole).

Données : parties cotées de la base ouverte Lichess (CC0), un mois de 2013.

    python s2_elo_estimate.py PGN.zst [--games 600] [--skip 8]
"""
import argparse, io, json, random, subprocess, sys, types
from collections import defaultdict, deque

sys.path.insert(0, "maia3")
import chess, chess.pgn, numpy as np, torch
from maia3.dataset import get_historical_tokens, get_legal_moves_mask, tokenize_board
from maia3.model_registry import resolve_model_spec
from maia3.models import MAIA3Model
from maia3.utils import get_all_possible_moves, mirror_move

GRID = list(range(700, 2701, 100))

spec = resolve_model_spec("23m")
cfg = types.SimpleNamespace(**spec.config, device="cpu")
model = MAIA3Model(cfg)
sd = torch.load("maia3-23m.pt", map_location="cpu", weights_only=True)
model.load_state_dict({k.replace("smolgen", "gab"): v for k, v in sd.items()}, strict=False)
model.eval()
ALL = get_all_possible_moves()
IDX = {m: i for i, m in enumerate(ALL)}


def player_loglik(game, color, oppo_elo, skip):
    """Log-vraisemblance des coups de `color`, pour chaque niveau de GRID."""
    board = game.board()
    history = deque(maxlen=cfg.history)
    history.append(tokenize_board(board))
    rows, targets, masks, ply = [], [], [], 0
    for move in game.mainline_moves():
        mover = board.turn
        if mover == color and ply // 2 >= skip:
            uci = move.uci() if mover == chess.WHITE else mirror_move(move.uci())
            if uci in IDX:
                rows.append(get_historical_tokens(history, cfg, 0, 0, 0, 0))
                targets.append(IDX[uci])
                masks.append(get_legal_moves_mask(board, IDX))
        board.push(move)
        history.append(tokenize_board(board))
        ply += 1
    if len(rows) < 8:
        return None
    x = torch.stack(rows)
    m = torch.stack(masks)
    t = torch.tensor(targets)
    out = np.zeros(len(GRID))
    with torch.no_grad():
        for gi, elo in enumerate(GRID):
            e = torch.full((len(rows),), float(elo))
            o = torch.full((len(rows),), float(oppo_elo))
            logits, _, _ = model(x, e, o)
            logits = logits.masked_fill(~m, float("-inf"))
            logp = torch.log_softmax(logits, -1)
            out[gi] = logp[torch.arange(len(rows)), t].sum().item()
    return out, len(rows)


def argmax_elo(ll):
    i = int(np.argmax(ll))
    if 0 < i < len(GRID) - 1:
        y0, y1, y2 = ll[i - 1], ll[i], ll[i + 1]
        denom = y0 - 2 * y1 + y2
        if denom < 0:
            return GRID[i] + 100 * 0.5 * (y0 - y2) / denom
    return float(GRID[i])


def read_games(path, wanted):
    z = subprocess.Popen(["zstdcat", path], stdout=subprocess.PIPE)
    stream = io.TextIOWrapper(z.stdout, encoding="utf-8", errors="replace")
    games = []
    while len(games) < wanted:
        g = chess.pgn.read_game(stream)
        if g is None:
            break
        h = g.headers
        try:
            w, b = int(h["WhiteElo"]), int(h["BlackElo"])
        except (KeyError, ValueError):
            continue
        if "?" in (h.get("WhiteElo", "?"), h.get("BlackElo", "?")):
            continue
        # Pas de bullet (le temps y décide plus que la qualité des coups).
        if h.get("Termination") != "Normal" or "Bullet" in h.get("Event", ""):
            continue
        n = sum(1 for _ in g.mainline_moves())
        if n < 40:
            continue
        games.append((g, w, b))
    z.kill()
    return games


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pgn")
    ap.add_argument("--games", type=int, default=4000, help="parties lues")
    ap.add_argument("--skip", type=int, default=8, help="coups d'ouverture ignorés par camp")
    ap.add_argument("--min-games", type=int, default=6)
    ap.add_argument("--out", default="s2_results.json")
    a = ap.parse_args()

    games = read_games(a.pgn, a.games)
    print(f"{len(games)} parties lues", file=sys.stderr)
    by_player = defaultdict(list)
    for g, w, b in games:
        by_player[g.headers["White"]].append((g, chess.WHITE, w, b))
        by_player[g.headers["Black"]].append((g, chess.BLACK, b, w))
    players = [p for p, gs in by_player.items() if len(gs) >= a.min_games]
    random.Random(1).shuffle(players)
    print(f"{len(players)} joueurs avec >= {a.min_games} parties", file=sys.stderr)

    results = []
    for name in players[:60]:
        entries = by_player[name]
        per_game, true = [], []
        for g, color, own, opp in entries:
            r = player_loglik(g, color, opp, a.skip)
            if r is None:
                continue
            per_game.append(r[0])
            true.append(own)
        if len(per_game) < a.min_games:
            continue
        results.append({"player": name, "true": float(np.mean(true)), "spread": float(np.std(true)),
                        "ll": [x.tolist() for x in per_game]})
        print(f"  {name}: {len(per_game)} parties, cote moyenne {np.mean(true):.0f}", file=sys.stderr)
    json.dump(results, open(a.out, "w"))
    print(f"-> {a.out} ({len(results)} joueurs)", file=sys.stderr)


if __name__ == "__main__":
    main()
