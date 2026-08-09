"""Auto-test HORS LIGNE du pipeline : construit un petit cours avec un Explorer
SYNTHÉTIQUE (aucun réseau), valide l'intégrité du graphe et le round-trip JSON.

Vérifie ce qui est critique pour la compatibilité avec l'app :
- la normalisation FEN (mêmes clés que Swift, testé séparément dans fen) ;
- aucune arête orpheline, tous les coups rejouables → toFEN (miroir du
  validateur Swift) ;
- la sérialisation produit bien le format attendu par le modèle Codable.
"""
from __future__ import annotations

import json

import chess

from builder import BuildConfig, build_course, course_stats
from eco import EcoNames
from evaluator import NullEvaluator
from fen import normalize_fen
from openings import by_id
from validate import validate_course


class SyntheticExplorer:
    """Explorer déterministe sans réseau : pour chaque position, renvoie les
    quelques premiers coups légaux avec des compteurs décroissants plausibles.
    Suffit à exercer tout le pipeline (branchement, élagage, stats, dédup)."""

    def _response(self, board: chess.Board) -> dict:
        moves = sorted(board.legal_moves, key=lambda m: m.uci())[:6]
        entries = []
        w_total = d_total = b_total = 0
        for i, m in enumerate(moves):
            white = max(1200 - i * 180, 20)
            draws = 200
            black = max(1000 - i * 150, 20)
            w_total += white
            d_total += draws
            b_total += black
            entries.append({
                "uci": m.uci(), "san": board.san(m),
                "white": white, "draws": draws, "black": black,
            })
        return {"white": w_total, "draws": d_total, "black": b_total, "moves": entries}

    def masters(self, board):
        return self._response(board)

    def lichess(self, board):
        return self._response(board)

    def dump_failures(self, path):
        pass


def run_selftest() -> dict:
    explorer = SyntheticExplorer()
    eco = EcoNames(by_fen={})
    evaluator = NullEvaluator()
    config = BuildConfig(max_depth=8, max_branches=2, pop_threshold=0.05, prune_threshold=0.05)

    opening = by_id("italian-game")
    course = build_course(opening, explorer, eco, evaluator, config)

    course_dict = course.to_dict()

    # 1) Intégrité du graphe.
    issues = validate_course(course_dict)
    assert not issues, f"validation échouée: {issues[:5]}"

    # 2) Racine = position initiale, présente ; graphe non trivial.
    assert course_dict["rootFEN"] == normalize_fen(chess.Board())
    assert course_dict["rootFEN"] in course_dict["positions"]
    assert len(course_dict["positions"]) > len(opening.entry_moves)

    # 3) Round-trip JSON (le format doit survivre à une sérialisation stricte).
    reloaded = json.loads(json.dumps(course_dict, ensure_ascii=False))
    assert not validate_course(reloaded), "round-trip JSON a cassé l'intégrité"

    # 4) La ligne d'entrée est bien une chaîne d'arêtes mainLine.
    key = course_dict["rootFEN"]
    for _ in opening.entry_moves:
        node = course_dict["positions"][key]
        main = [e for e in node["moves"] if e["role"] == "mainLine"]
        assert main, f"pas de mainLine au nœud {key}"
        key = main[0]["toFEN"]

    stats = course_stats(course)
    return stats


if __name__ == "__main__":
    print("selftest:", run_selftest())
    print("OK")
