"""Force du moteur bridé : l'ancienne et la nouvelle version de Stockfish, à RÉGLAGES IDENTIQUES.

Rejoue les régimes de `ChessLab/Play/EngineStrength.swift` :
  - limited(elo)        : UCI_LimitStrength + UCI_Elo, Skill Level 20, `go movetime`
  - belowMinimum(...)   : Skill Level bas, `go depth`
  - maximum             : aucune limite, `go movetime`
Chaque ouverture est jouée deux fois, couleurs échangées. Sortie : le score de la NOUVELLE version
(50 % = même force) avec son intervalle de confiance, et l'écart Elo correspondant.

    python3 strength_match.py <jeux_par_niveau> <sortie.json> [movetime_ms]
"""
import chess, chess.engine, chess.pgn, json, math, os, random, sys, time
from multiprocessing import Pool

ENGINES = os.environ.get("ENGINES_DIR", os.path.abspath("eng"))
OLD = ENGINES + "/mac-sf_17.1/src/stockfish"
NEW = ENGINES + "/mac-sf_19/src/stockfish"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")) + "/"
MOVETIME = int(sys.argv[3]) / 1000 if len(sys.argv) > 3 else 0.15

LEVELS = [
    ("Elo 1500 (bridé)",   {"UCI_LimitStrength": True, "UCI_Elo": 1500, "Skill Level": 20}, "time"),
    ("Elo 2000 (bridé)",   {"UCI_LimitStrength": True, "UCI_Elo": 2000, "Skill Level": 20}, "time"),
    ("Elo 2500 (bridé)",   {"UCI_LimitStrength": True, "UCI_Elo": 2500, "Skill Level": 20}, "time"),
    ("Elo 3000 (bridé)",   {"UCI_LimitStrength": True, "UCI_Elo": 3000, "Skill Level": 20}, "time"),
    ("Elo ~1000 (niveau bas)", {"UCI_LimitStrength": False, "Skill Level": 2}, 3),
    ("Elo ~1200 (niveau bas)", {"UCI_LimitStrength": False, "Skill Level": 4}, 5),
    ("Maximum",            {"UCI_LimitStrength": False, "Skill Level": 20}, "time"),
]

def openings(n, seed=11):
    out = []
    for path in [REPO + "ChessLabTests/Fixtures_nils.pgn", REPO + "tools/maia3-spike/calibration/camille-1100-2200.pgn"]:
        f = open(path)
        while True:
            g = chess.pgn.read_game(f)
            if g is None: break
            b = g.board(); moves = list(g.mainline_moves())
            if len(moves) < 12: continue
            for m in moves[:6]: b.push(m)
            out.append(b.fen())
    random.Random(seed).shuffle(out)
    return out[:n]

def play(args):
    fen, new_is_white, options, limit = args
    engines = {}
    for name, binary in (("old", OLD), ("new", NEW)):
        e = chess.engine.SimpleEngine.popen_uci(binary, cwd=binary.rsplit("/", 1)[0])
        e.configure({"Threads": 1, "Hash": 64, **options})
        engines[name] = e
    board = chess.Board(fen)
    white, black = ("new", "old") if new_is_white else ("old", "new")
    result = None
    try:
        while not board.is_game_over(claim_draw=True) and board.ply() < 400:
            e = engines[white if board.turn == chess.WHITE else black]
            lim = chess.engine.Limit(time=MOVETIME) if limit == "time" else chess.engine.Limit(depth=limit)
            r = e.play(board, lim)
            board.push(r.move)
        res = board.result(claim_draw=True) if board.is_game_over(claim_draw=True) else "1/2-1/2"
    finally:
        for e in engines.values(): e.quit()
    if res == "1-0": return 1.0 if new_is_white else 0.0
    if res == "0-1": return 0.0 if new_is_white else 1.0
    return 0.5

def report(scores):
    n = len(scores); p = sum(scores) / n
    var = sum((s - p) ** 2 for s in scores) / max(1, n - 1)
    ci = 1.96 * math.sqrt(var / n)
    def elo(x):
        x = min(max(x, 0.001), 0.999); return -400 * math.log10(1 / x - 1)
    return {"games": n, "score_new": round(p, 4), "ci95": round(ci, 4), "elo_diff": round(elo(p)),
            "elo_low": round(elo(p - ci)), "elo_high": round(elo(p + ci)),
            "wins": scores.count(1.0), "draws": scores.count(0.5), "losses": scores.count(0.0)}

if __name__ == "__main__":
    games = int(sys.argv[1]); out = sys.argv[2]
    ops = openings(games // 2)
    results = {}
    t0 = time.time()
    with Pool(6) as pool:
        for label, options, limit in LEVELS:
            jobs = [(fen, w, options, limit) for fen in ops for w in (True, False)]
            scores = pool.map(play, jobs, chunksize=1)
            results[label] = report(scores)
            print(label, results[label], round(time.time() - t0), "s", flush=True)
            json.dump(results, open(out, "w"), indent=1)
