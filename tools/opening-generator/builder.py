"""Construction du graphe d'un cours à partir des données Explorer.

Stratégie (brief) :
- Ligne d'ENTRÉE forcée (les coups qui définissent l'ouverture), puis
  expansion BFS avec branchement.
- À chaque nœud, jusqu'à `max_branches` coups au-dessus du seuil de popularité
  (le coup le plus joué reste toujours gardé, même sous le seuil).
- ÉLAGAGE INTELLIGENT : on n'approfondit pas une branche dont la probabilité
  CUMULÉE d'occurrence (produit des popularités le long du chemin) descend sous
  `prune_threshold` — c'est ce qui évite l'explosion combinatoire tout en
  gardant ce qui arrive vraiment sur l'échiquier.
- Double pondération conservée (stats maîtres ET club).
- Pièges détectés par chute d'évaluation (si un moteur est fourni).
"""
from __future__ import annotations

from collections import deque
from dataclasses import dataclass

import chess

from fen import normalize_fen
from models import MoveEdge, OpeningChapter, OpeningCourse, PositionNode


@dataclass
class BuildConfig:
    max_depth: int          # demi-coups depuis le début (ligne d'entrée incluse)
    max_branches: int
    pop_threshold: float    # fraction (0.02 = 2 %)
    prune_threshold: float  # probabilité cumulée minimale pour approfondir
    trap_cp: float = 150.0
    inaccuracy_cp: float = 70.0
    trap_pop: float = 0.05


PROFILES = {
    "core": BuildConfig(max_depth=18, max_branches=4, pop_threshold=0.02, prune_threshold=0.005),
    "extended": BuildConfig(max_depth=10, max_branches=2, pop_threshold=0.05, prune_threshold=0.01),
    "trap": BuildConfig(max_depth=14, max_branches=3, pop_threshold=0.03, prune_threshold=0.005),
}


def _ingest(data, kind, out):
    if not data:
        return
    moves = data.get("moves", [])
    total = sum(m["white"] + m["draws"] + m["black"] for m in moves)
    for m in moves:
        t = m["white"] + m["draws"] + m["black"]
        e = out.setdefault(m["uci"], {
            "san": m.get("san"), "master": None, "club": None,
            "master_pop": 0.0, "club_pop": 0.0,
            "score_w": None, "score_d": None, "score_b": None,
        })
        if not e["san"]:
            e["san"] = m.get("san")
        e[kind] = (m["white"], m["draws"], m["black"])
        e[kind + "_pop"] = (t / total) if total else 0.0
        if kind == "club" and t:
            e["score_w"], e["score_d"], e["score_b"] = m["white"] / t, m["draws"] / t, m["black"] / t


def merge_stats(masters, lichess) -> dict:
    """{uci -> stats fusionnées maîtres/club} pour une position."""
    out: dict = {}
    _ingest(masters, "master", out)
    _ingest(lichess, "club", out)
    for e in out.values():  # score de repli sur la base maîtres si pas de club
        if e["score_w"] is None and e["master"]:
            mw, md, mb = e["master"]
            t = mw + md + mb
            if t:
                e["score_w"], e["score_d"], e["score_b"] = mw / t, md / t, mb / t
    return out


def _pop(stat) -> float:
    return stat["club_pop"] if stat["club_pop"] else stat["master_pop"]


def _select_branches(stats: dict, config: BuildConfig):
    ranked = sorted(stats.items(), key=lambda kv: _pop(kv[1]), reverse=True)
    chosen = []
    for uci, s in ranked:
        if _pop(s) < config.pop_threshold and chosen:
            continue  # on garde toujours au moins le coup le plus joué
        chosen.append((uci, s))
        if len(chosen) >= config.max_branches:
            break
    return chosen


def _make_edge(board: chess.Board, move: chess.Move, to_key: str, s, evaluator, role: str) -> MoveEdge:
    edge = MoveEdge(san=board.san(move), uci=move.uci(), toFEN=to_key, role=role)
    if s:
        if s["master"]:
            edge.gamesMasters = sum(s["master"])
        if s["club"]:
            edge.gamesClub = sum(s["club"])
        edge.popularityMasters = round(s["master_pop"], 4) or None
        edge.popularityClub = round(s["club_pop"], 4) or None
        if s["score_w"] is not None:
            edge.scoreWhite = round(s["score_w"], 4)
            edge.scoreDraw = round(s["score_d"], 4)
            edge.scoreBlack = round(s["score_b"], 4)
    child = board.copy()
    child.push(move)
    ev = evaluator.eval_cp(child)
    if ev is not None:
        edge.eval = ev
    return edge


def _annotate_traps(node: PositionNode, board: chess.Board, config: BuildConfig) -> None:
    graded = [e for e in node.moves if e.eval is not None]
    if len(graded) < 2:
        return
    white_to_move = board.turn == chess.WHITE

    def mover_cp(e):
        return e.eval if white_to_move else -e.eval

    best = max(mover_cp(e) for e in graded)
    for e in graded:
        loss = best - mover_cp(e)
        pop = e.popularityClub or 0.0
        if loss >= config.trap_cp and pop >= config.trap_pop:
            e.role, e.isCritical = "trap", True
        elif loss >= config.inaccuracy_cp and pop >= config.trap_pop and e.role == "sideline":
            e.role = "inaccuracy"


def _ensure_node(positions, key, eco_names):
    if key not in positions:
        name = eco_names.lookup(key) if eco_names else None
        positions[key] = PositionNode(fen=key, ecoName=name)


def _add_edge_once(node: PositionNode, edge: MoveEdge) -> None:
    if not any(existing.uci == edge.uci for existing in node.moves):
        node.moves.append(edge)


def build_course(opening, explorer, eco_names, evaluator, config: BuildConfig) -> OpeningCourse:
    positions: dict = {}
    board = chess.Board()
    root_key = normalize_fen(board)
    _ensure_node(positions, root_key, eco_names)

    # 1) Ligne d'entrée forcée.
    spine = [root_key]
    for san in opening.entry_moves:
        parent_key = normalize_fen(board)
        stats = merge_stats(explorer.masters(board), explorer.lichess(board))
        move = board.parse_san(san)
        to_key_board = board.copy()
        to_key_board.push(move)
        to_key = normalize_fen(to_key_board)
        edge = _make_edge(board, move, to_key, stats.get(move.uci()), evaluator, role="mainLine")
        board.push(move)
        _ensure_node(positions, to_key, eco_names)
        _add_edge_once(positions[parent_key], edge)
        spine.append(to_key)

    # 2) Expansion BFS depuis la position d'entrée.
    visited: set = set()
    frontier = deque([(board.copy(), 1.0)])
    while frontier:
        b, cumprob = frontier.popleft()
        key = normalize_fen(b)
        if key in visited:
            continue
        visited.add(key)
        if len(b.move_stack) >= config.max_depth:
            continue
        stats = merge_stats(explorer.masters(b), explorer.lichess(b))
        if not stats:
            continue
        for i, (uci, s) in enumerate(_select_branches(stats, config)):
            move = chess.Move.from_uci(uci)
            if move not in b.legal_moves:
                continue
            child = b.copy()
            child.push(move)
            to_key = normalize_fen(child)
            _ensure_node(positions, to_key, eco_names)
            edge = _make_edge(b, move, to_key, s, evaluator, role="mainLine" if i == 0 else "sideline")
            _add_edge_once(positions[key], edge)
            child_cumprob = cumprob * _pop(s)
            if child_cumprob >= config.prune_threshold and len(child.move_stack) < config.max_depth:
                frontier.append((child, child_cumprob))
        _annotate_traps(positions[key], b, config)

    chapter = OpeningChapter(id="main", title="Ligne principale", positionFENs=spine)
    return OpeningCourse(
        id=opening.id, name=opening.name, rootFEN=root_key, side=opening.side,
        level=opening.level, eco=opening.eco, summary=opening.summary,
        chapters=[chapter], positions=positions,
    )


def course_stats(course: OpeningCourse) -> dict:
    positions = course.positions
    edges = sum(len(n.moves) for n in positions.values())
    without_comment = sum(
        1 for n in positions.values() for e in n.moves
        if not (e.comment and e.commentStatus == "validated")
    )
    return {
        "positions": len(positions),
        "edges": edges,
        "moves_without_comment": without_comment,
        "max_depth_plies": _measure_depth(course),
    }


def _measure_depth(course: OpeningCourse) -> int:
    """Profondeur max en demi-coups depuis la racine, par BFS sur le graphe."""
    positions = course.positions
    seen = {course.rootFEN: 0}
    queue = deque([course.rootFEN])
    best = 0
    while queue:
        key = queue.popleft()
        d = seen[key]
        best = max(best, d)
        node = positions.get(key)
        if not node:
            continue
        for e in node.moves:
            if e.toFEN not in seen:
                seen[e.toFEN] = d + 1
                queue.append(e.toFEN)
    return best
