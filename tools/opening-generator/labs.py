"""Génère les données SIDECAR du module « Ouvertures — Labs ».

Le module Labs affiche, pour CHAQUE position d'un cours d'ouverture :
- les coups les plus joués par les MAÎTRES dans cette position, avec leurs
  pourcentages et leur bilan (Opening Explorer de Lichess, base `masters`) ;
- les trois meilleurs coups de STOCKFISH, calculés d'avance (MultiPV 3).

Pourquoi un fichier À CÔTÉ plutôt que d'enrichir `openings/<id>.json` ?

1. Les cours embarqués sont la donnée du module d'ouvertures EXISTANT, en
   production. Y ajouter des champs, c'est risquer une régression sur un module
   qui marche, pour un module en aperçu.
2. Le lecteur Labs veut TOUS les coups de maîtres de la position — y compris
   ceux que le cours ne retient pas — alors que `MoveEdge.gamesMasters` ne
   décrit que les arêtes curées du graphe. Ce n'est pas la même donnée.
3. Le sidecar se charge PARESSEUSEMENT et seulement si l'aperçu est activé :
   un utilisateur qui n'allume pas Labs ne paie rien en mémoire.

Clé d'indexation : la FEN normalisée (`fen.normalize_fen`), rigoureusement la
même que le graphe et que `OpeningFENKey.swift` — les transpositions partagent
donc leur entrée, et le sidecar survit à une régénération des arbres.

## Sources

- MAÎTRES : cache disque de `explorer.py` (partagé, clé = même signature), ou
  réseau si un jeton `LICHESS_TOKEN` est présent. Sans jeton, on travaille en
  mode CACHE SEUL : les positions absentes du cache n'ont simplement pas de
  bloc `masters`, et l'app le dit au lieu d'inventer.
- MOTEUR : n'importe quel binaire Stockfish UCI (`--engine`), MultiPV 3, à
  profondeur fixe. Cache disque dédié, indexé par (FEN, profondeur, multipv) :
  relancer ne recalcule rien.

## Usage

    export LICHESS_TOKEN=lip_xxxx      # facultatif — sinon cache seul
    python3 labs.py --engine bin/stockfish --depth 20 --workers 4

    python3 labs.py --masters-only     # top-up des maîtres, sans moteur
    python3 labs.py --engine-only      # moteur seul
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from typing import Optional

import chess

from fen import normalize_fen
from explorer import TOKEN_HELP, LichessExplorer, token_from_environment

SCHEMA_VERSION = 1

ROOT = Path(__file__).resolve().parents[2]
COURSES_DIR = ROOT / "ChessLab" / "Resources" / "openings"
OUT_DIR = ROOT / "ChessLab" / "Resources" / "openings_labs"
CACHE_DIR = Path(__file__).resolve().parent / ".cache"
ENGINE_CACHE_DIR = CACHE_DIR / "labs_engine"

# Coups de maîtres RETENUS par position. Au-delà de six, on affiche du bruit
# statistique (des coups à 0,3 % joués deux fois) et on paie des octets pour.
MASTER_MOVES_KEPT = 6
# Un coup de maître doit peser au moins ça pour être retenu : sous 0,5 %, ce
# n'est plus « ce que jouent les maîtres », c'est une curiosité.
MASTER_MIN_SHARE = 0.005
# Le prompt : « les meilleurs (maximum 3) coups de stockfish ».
ENGINE_MULTIPV = 3


# --------------------------------------------------------------------------
# Positions à couvrir
# --------------------------------------------------------------------------

def load_courses() -> list[dict]:
    """Les cours d'OUVERTURE embarqués (les finales ne sont pas concernées :
    elles n'ont ni statistiques de maîtres ni index de lignes)."""
    courses = []
    for path in sorted(COURSES_DIR.glob("*.json")):
        if path.name == "opening_catalog.json":
            continue
        try:
            course = json.loads(path.read_text())
        except (ValueError, OSError) as exc:
            print(f"⚠ {path.name} illisible : {exc}", file=sys.stderr)
            continue
        if course.get("kind") == "endgame":
            continue
        courses.append(course)
    return courses


def distinct_keys(courses: list[dict]) -> list[str]:
    """Les positions DISTINCTES de tous les cours réunis.

    Les transpositions font qu'un même FEN apparaît dans plusieurs cours : on
    ne l'analyse qu'une fois (5 727 entrées de cours → ~4 980 positions)."""
    keys: set[str] = set()
    for course in courses:
        keys.update(course.get("positions", {}))
    return sorted(keys)


def board_from_key(key: str) -> Optional[chess.Board]:
    """Board python-chess depuis une clé à 4 champs, ou `None` si illisible."""
    try:
        fields = key.split(" ")
        return chess.Board(key + " 0 1" if len(fields) == 4 else key)
    except ValueError:
        return None


# --------------------------------------------------------------------------
# Maîtres (Lichess Opening Explorer)
# --------------------------------------------------------------------------

def masters_block(raw: Optional[dict]) -> Optional[dict]:
    """Compacte une réponse Explorer en bloc `masters` du sidecar.

    `None` si la position n'a AUCUNE partie de maître : mieux vaut pas de bloc
    du tout qu'un bloc à zéro — l'app distingue « pas de donnée » de
    « position jamais jouée », et ne montre la section que si elle a du fond.
    """
    if not raw:
        return None
    total = (raw.get("white") or 0) + (raw.get("draws") or 0) + (raw.get("black") or 0)
    if total <= 0:
        return None

    moves = []
    for move in raw.get("moves", []):
        games = (move.get("white") or 0) + (move.get("draws") or 0) + (move.get("black") or 0)
        if games <= 0 or games / total < MASTER_MIN_SHARE:
            continue
        entry = {
            "san": move.get("san"),
            "uci": move.get("uci"),
            "g": games,
            "w": move.get("white") or 0,
            "d": move.get("draws") or 0,
            "b": move.get("black") or 0,
        }
        if move.get("averageRating"):
            entry["elo"] = int(move["averageRating"])
        # Nom ECO atteint par ce coup, quand Lichess le donne : c'est
        # gratuit ici et ça nomme les variantes dans l'index des lignes.
        opening = move.get("opening") or {}
        if opening.get("name"):
            entry["eco"] = opening.get("eco")
            entry["name"] = opening["name"]
        if entry["san"] and entry["uci"]:
            moves.append(entry)

    moves.sort(key=lambda m: -m["g"])
    if not moves:
        return None
    return {
        "w": raw.get("white") or 0,
        "d": raw.get("draws") or 0,
        "b": raw.get("black") or 0,
        "moves": moves[:MASTER_MOVES_KEPT],
    }


def collect_masters(keys: list[str], explorer: LichessExplorer, verbose: bool = True) -> dict[str, dict]:
    """Bloc `masters` par position — cache d'abord, réseau si jeton."""
    result: dict[str, dict] = {}
    for index, key in enumerate(keys, 1):
        board = board_from_key(key)
        if board is None:
            continue
        block = masters_block(explorer.masters(board))
        if block:
            result[key] = block
        if verbose and index % 250 == 0:
            print(
                f"  maîtres {index}/{len(keys)} — {len(result)} couvertes, "
                f"{explorer.cache_hits} en cache, {explorer.request_count} requêtes",
                flush=True,
            )
    return result


# --------------------------------------------------------------------------
# Moteur (Stockfish, MultiPV 3, cache disque)
# --------------------------------------------------------------------------

def engine_cache_path(key: str, depth: int) -> Path:
    import hashlib

    signature = f"{key}|{depth}|{ENGINE_MULTIPV}"
    digest = hashlib.sha1(signature.encode("utf-8")).hexdigest()[:20]
    return ENGINE_CACHE_DIR / f"mpv_{digest}.json"


def _analyse_chunk(payload: tuple[list[str], str, int, int]) -> int:
    """Analyse un paquet de positions dans un processus dédié, en écrivant
    chaque résultat dans le cache disque. Renvoie le nombre de positions
    RÉELLEMENT calculées (les autres étaient déjà en cache).

    Un processus par travailleur, avec son propre Stockfish : `SimpleEngine`
    n'est pas partageable, et un moteur relancé par position paierait
    l'initialisation (NNUE) des milliers de fois.
    """
    import chess.engine

    keys, engine_path, depth, hash_mb = payload
    pending = [k for k in keys if not engine_cache_path(k, depth).exists()]
    if not pending:
        return 0

    engine = chess.engine.SimpleEngine.popen_uci(engine_path)
    try:
        engine.configure({"Threads": 1, "Hash": hash_mb})
    except Exception:  # noqa: BLE001 — options « best effort »
        pass

    limit = chess.engine.Limit(depth=depth)
    computed = 0
    try:
        for key in pending:
            board = board_from_key(key)
            if board is None or board.is_game_over():
                engine_cache_path(key, depth).write_text("[]")
                continue
            try:
                infos = engine.analyse(board, limit, multipv=ENGINE_MULTIPV)
            except Exception:  # noqa: BLE001 — une position ne doit pas tuer le lot
                continue
            lines = []
            for info in infos:
                pv = info.get("pv") or []
                if not pv:
                    continue
                move = pv[0]
                score = info["score"].white()
                line = {"san": board.san(move), "uci": move.uci()}
                if score.is_mate():
                    line["mate"] = score.mate()
                else:
                    line["cp"] = score.score()
                lines.append(line)
            engine_cache_path(key, depth).write_text(json.dumps(lines))
            computed += 1
    finally:
        engine.quit()
    return computed


def collect_engine(
    keys: list[str], engine_path: str, depth: int, workers: int, hash_mb: int
) -> dict[str, list]:
    """Trois meilleurs coups par position, calculés d'AVANCE.

    C'est la partie longue (≈2 s par position à profondeur 20 sur un M2) : elle
    est parallélisée et intégralement mise en cache, si bien qu'une reprise
    après interruption ne recalcule que ce qui manque.
    """
    ENGINE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    todo = [k for k in keys if not engine_cache_path(k, depth).exists()]
    print(
        f"  moteur : {len(keys) - len(todo)}/{len(keys)} déjà en cache, "
        f"{len(todo)} à calculer (profondeur {depth}, {workers} travailleurs)",
        flush=True,
    )

    if todo:
        # Paquets ENTRELACÉS : les positions voisines dans l'ordre trié se
        # ressemblent (même ouverture) et coûtent le même temps. En donnant à
        # chaque travailleur une position sur N, tous finissent ensemble au
        # lieu que l'un traîne sur les milieux de jeu complexes.
        chunks = [todo[i::workers] for i in range(workers)]
        started = time.time()
        with ProcessPoolExecutor(max_workers=workers) as pool:
            payloads = [(chunk, engine_path, depth, hash_mb) for chunk in chunks if chunk]
            done = 0
            for computed in pool.map(_analyse_chunk, payloads):
                done += computed
        elapsed = time.time() - started
        print(f"  moteur : {done} positions calculées en {elapsed / 60:.1f} min", flush=True)

    result: dict[str, list] = {}
    for key in keys:
        path = engine_cache_path(key, depth)
        if not path.exists():
            continue
        try:
            lines = json.loads(path.read_text())
        except ValueError:
            continue
        if lines:
            result[key] = lines
    return result


# --------------------------------------------------------------------------
# Écriture des sidecars
# --------------------------------------------------------------------------

def write_sidecars(
    courses: list[dict], masters: dict[str, dict], engine: dict[str, list], depth: int
) -> tuple[int, int]:
    """Un fichier par cours, ne portant QUE ses propres positions.

    Le chargement est paresseux côté app : c'est ce découpage qui le permet.
    Renvoie (fichiers écrits, octets totaux).
    """
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    written = 0
    total_bytes = 0
    for course in courses:
        positions = {}
        for key in course.get("positions", {}):
            entry = {}
            if key in masters:
                entry["masters"] = masters[key]
            if key in engine:
                entry["engine"] = engine[key]
            if entry:
                positions[key] = entry
        if not positions:
            continue
        payload = {
            "schemaVersion": SCHEMA_VERSION,
            "id": course["id"],
            "engineDepth": depth,
            "positions": positions,
        }
        path = OUT_DIR / f"{course['id']}.labs.json"
        # `separators` sans espaces : sur 58 fichiers et ~5 000 positions, les
        # espaces d'indentation pèsent plus que la lisibilité ne vaut — le
        # fichier est généré, jamais relu à la main.
        text = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
        path.write_text(text)
        written += 1
        total_bytes += len(text.encode("utf-8"))
    return written, total_bytes


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--engine", default="bin/stockfish", help="binaire Stockfish UCI")
    parser.add_argument("--depth", type=int, default=20, help="profondeur d'analyse (défaut 20)")
    parser.add_argument("--workers", type=int, default=4, help="processus moteur en parallèle")
    parser.add_argument("--hash", type=int, default=128, help="table de transposition par travailleur (Mo)")
    parser.add_argument("--masters-only", action="store_true", help="ne recalcule pas le moteur")
    parser.add_argument("--engine-only", action="store_true", help="ne réinterroge pas l'Explorer")
    parser.add_argument("--only", help="limiter à un identifiant de cours (mise au point)")
    args = parser.parse_args()

    courses = load_courses()
    if args.only:
        courses = [c for c in courses if c["id"] == args.only]
    if not courses:
        print("✗ Aucun cours d'ouverture trouvé.", file=sys.stderr)
        return 1

    keys = distinct_keys(courses)
    print(f"{len(courses)} ouvertures, {len(keys)} positions distinctes.", flush=True)

    # --- Maîtres ---------------------------------------------------------
    masters: dict[str, dict] = {}
    if not args.engine_only:
        token = token_from_environment()
        if not token:
            print(f"\n⚠ Aucun jeton Lichess — mode CACHE SEUL.\n  {TOKEN_HELP}\n", file=sys.stderr)
        explorer = LichessExplorer(
            cache_dir=CACHE_DIR / "explorer",
            min_delay=1.0,
            moves=12,
            dry_run=not token,
            token=token,
        )
        masters = collect_masters(keys, explorer)
        covered = 100 * len(masters) / max(1, len(keys))
        print(f"  maîtres : {len(masters)}/{len(keys)} positions couvertes ({covered:.1f} %)", flush=True)
    else:
        # `--engine-only` ne doit pas EFFACER les maîtres déjà écrits : on les
        # relit des sidecars existants au lieu de repartir de rien.
        masters = reload_existing(courses, "masters")

    # --- Moteur ----------------------------------------------------------
    engine: dict[str, list] = {}
    if not args.masters_only:
        engine_path = args.engine
        if not Path(engine_path).exists():
            print(f"✗ Binaire moteur introuvable : {engine_path}", file=sys.stderr)
            return 1
        engine = collect_engine(keys, engine_path, args.depth, args.workers, args.hash)
        covered = 100 * len(engine) / max(1, len(keys))
        print(f"  moteur : {len(engine)}/{len(keys)} positions couvertes ({covered:.1f} %)", flush=True)
    else:
        engine = reload_existing(courses, "engine")

    written, total_bytes = write_sidecars(courses, masters, engine, args.depth)
    print(f"\n✓ {written} fichiers écrits dans {OUT_DIR} — {total_bytes / 1_048_576:.1f} Mo au total.")
    return 0


def reload_existing(courses: list[dict], field: str) -> dict:
    """Relit un champ des sidecars déjà écrits, pour qu'une passe partielle
    (`--engine-only`/`--masters-only`) n'écrase pas le travail de l'autre."""
    out: dict = {}
    for course in courses:
        path = OUT_DIR / f"{course['id']}.labs.json"
        if not path.exists():
            continue
        try:
            data = json.loads(path.read_text())
        except ValueError:
            continue
        for key, entry in data.get("positions", {}).items():
            if field in entry:
                out[key] = entry[field]
    return out


if __name__ == "__main__":
    raise SystemExit(main())
