import chess, chess.engine, chess.pgn, glob, json, math, os, sys, time
from multiprocessing import Pool

# Dossier produit par build_engines.sh (binaires macOS des deux versions).
ENGINES = os.environ.get("ENGINES_DIR", os.path.abspath("eng"))
ENG = {
    "sf17": ENGINES + "/mac-sf_17.1/src/stockfish",   # l'ANCIENNE version (la référence)
    "sf19": ENGINES + "/mac-sf_19/src/stockfish",     # la NOUVELLE
}
NODES = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")) + "/"

def positions():
    out = []
    for p in [REPO + "ChessLabTests/Fixtures_nils.pgn", REPO + "tools/maia3-spike/calibration/camille-1100-2200.pgn"]:
        f = open(p)
        gi = 0
        while True:
            g = chess.pgn.read_game(f)
            if g is None: break
            b = g.board(); fens = [b.fen()]
            for m in g.mainline_moves():
                b.push(m); fens.append(b.fen())
            out.append((p.split("/")[-1], gi, fens)); gi += 1
    return out

def win(cp): return 50 + 50 * (2 / (1 + math.exp(-0.00368 * cp)) - 1)

def evaluate(args):
    name, fens = args
    eng = chess.engine.SimpleEngine.popen_uci(ENG[name], cwd=ENG[name].rsplit("/", 1)[0])
    eng.configure({"Threads": 1, "Hash": 128, "UCI_ShowWDL": True})
    res = []
    for fen in fens:
        b = chess.Board(fen)
        if b.is_game_over():
            res.append(None); continue
        info = eng.analyse(b, chess.engine.Limit(nodes=NODES))
        s = info["score"].white()
        wdl = info.get("wdl")
        w = list(info["wdl"].white()) if wdl is not None else None
        if s.is_mate():
            m = s.mate(); res.append(("m", m, w))
        else:
            res.append(("c", s.score(), w))
    eng.quit()
    return res

if __name__ == "__main__":
    games = positions()
    jobs = [(n, g[2]) for g in games for n in ("sf17", "sf19")]
    t0 = time.time()
    with Pool(6) as pool:
        results = pool.map(evaluate, jobs, chunksize=1)
    data = []
    for i, g in enumerate(games):
        data.append({"file": g[0], "game": g[1], "fens": g[2], "sf17": results[2*i], "sf19": results[2*i+1]})
    json.dump(data, open(sys.argv[2], "w"))
    print("fait en", round(time.time() - t0), "s;", sum(len(g[2]) for g in games), "positions")
