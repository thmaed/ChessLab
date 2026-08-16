#!/usr/bin/env python3
"""Générateur d'ouvertures ChessLab — script hors app, ré-exécutable.

Produit un fichier compact PAR ouverture (`out/openings/<id>.json`) directement
décodable par le modèle Swift `OpeningCourse`, plus un index `opening_catalog.json`.
Ni le cache ni les données brutes ne sont destinés à la cible iOS.

Exemples :
    python3 generate.py --selftest
    python3 generate.py --only scandinavian --profile core
    python3 generate.py --resume                 # (ré)génère tout ce qui manque
    python3 generate.py --dry-run                # n'utilise que le cache existant
    python3 generate.py --stockfish /usr/local/bin/stockfish

Robuste au rate limiting : cache disque + backoff 429 + reprise (voir explorer.py).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from dataclasses import replace
from pathlib import Path

from builder import PROFILES, build_course, course_stats
from eco import EcoNames
from evaluator import NullEvaluator, StockfishEvaluator
from explorer import TOKEN_HELP, LichessExplorer, token_from_environment
from models import CatalogEntry
from openings import ALL, by_id
from validate import validate_course

HERE = Path(__file__).resolve().parent


def make_evaluator(path, depth):
    """Crée l'évaluateur Stockfish, ou retombe PROPREMENT sur aucun évaluateur.

    Les évaluations sont OPTIONNELLES : un chemin absent/faux ne doit jamais
    faire échouer la génération. On accepte aussi un simple nom (« stockfish »)
    résolu via le PATH."""
    if not path:
        return NullEvaluator()
    resolved = path if os.path.isfile(path) else shutil.which(path)
    if not resolved or not os.path.isfile(resolved):
        print(f"⚠ Stockfish introuvable à « {path} » — génération SANS évaluations.")
        print("  Installe-le (brew install stockfish) puis passe --stockfish \"$(which stockfish)\".")
        return NullEvaluator()
    try:
        return StockfishEvaluator(resolved, depth=depth)
    except Exception as exc:  # noqa: BLE001
        print(f"⚠ Stockfish n'a pas démarré ({exc}) — génération SANS évaluations.")
        return NullEvaluator()


def parse_args(argv):
    p = argparse.ArgumentParser(description="Générateur d'ouvertures ChessLab")
    p.add_argument("--only", help="ids séparés par des virgules (défaut: tout)")
    p.add_argument("--profile", choices=list(PROFILES), help="force un profil pour toutes les entrées")
    p.add_argument("--out", default=str(HERE / "out"))
    p.add_argument("--cache", default=str(HERE / ".cache"))
    p.add_argument("--chess-openings-dir", help="dossier local des a.tsv..e.tsv (sinon téléchargés)")
    p.add_argument("--ratings", default="1400,1600,1800", help="tranches Elo club (base lichess)")
    p.add_argument("--speeds", default="blitz,rapid,classical")
    p.add_argument("--moves", type=int, default=12, help="nb de coups demandés à l'Explorer par position")
    p.add_argument("--min-delay", type=float, default=1.0, help="délai minimal entre requêtes (s)")
    p.add_argument("--max-depth", type=int, help="override profondeur (demi-coups)")
    p.add_argument("--max-branches", type=int, help="override branches max par nœud")
    p.add_argument("--pop-threshold", type=float, help="override seuil de popularité (fraction)")
    p.add_argument("--prune-threshold", type=float, help="override seuil de probabilité cumulée")
    p.add_argument("--stockfish", help="chemin d'un binaire Stockfish (active les évals/pièges)")
    p.add_argument("--stockfish-depth", type=int, default=16)
    p.add_argument("--dry-run", action="store_true", help="aucune requête réseau (cache seulement)")
    p.add_argument("--resume", action="store_true", help="saute les ouvertures déjà générées")
    p.add_argument("--selftest", action="store_true", help="auto-test hors ligne puis quitte")
    return p.parse_args(argv)


def config_for(opening, args):
    config = PROFILES[args.profile] if args.profile else PROFILES[opening.profile]
    overrides = {}
    if args.max_depth is not None:
        overrides["max_depth"] = args.max_depth
    if args.max_branches is not None:
        overrides["max_branches"] = args.max_branches
    if args.pop_threshold is not None:
        overrides["pop_threshold"] = args.pop_threshold
    if args.prune_threshold is not None:
        overrides["prune_threshold"] = args.prune_threshold
    return replace(config, **overrides) if overrides else config


def main(argv=None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])

    if args.selftest:
        from selftest import run_selftest
        print("selftest:", run_selftest())
        print("OK")
        return 0

    out_dir = Path(args.out)
    (out_dir / "openings").mkdir(parents=True, exist_ok=True)
    cache_dir = Path(args.cache)

    selected = ALL
    if args.only:
        ids = [s.strip() for s in args.only.split(",") if s.strip()]
        selected = [o for o in (by_id(i) for i in ids) if o]

    # Échouer AVANT de charger les noms ECO, Stockfish et 58 ouvertures : sans
    # jeton, chaque requête répondra 401 et le lot ne produirait que du vide.
    if not args.dry_run and not token_from_environment():
        print(f"\n✗ Aucun jeton Lichess. {TOKEN_HELP}\n"
              "  (ou relance avec --dry-run pour travailler sur le cache seul)",
              file=sys.stderr)
        return 2

    print(f"Chargement des noms ECO (lichess-org/chess-openings)…")
    eco = EcoNames.load(cache_dir / "eco", Path(args.chess_openings_dir) if args.chess_openings_dir else None)

    explorer = LichessExplorer(
        cache_dir=cache_dir / "explorer", speeds=args.speeds, ratings=args.ratings,
        min_delay=args.min_delay, moves=args.moves, dry_run=args.dry_run,
    )
    evaluator = make_evaluator(args.stockfish, args.stockfish_depth)

    catalog: list[CatalogEntry] = []
    report_rows = []
    try:
        for opening in selected:
            out_file = out_dir / "openings" / f"{opening.id}.json"
            if args.resume and out_file.exists():
                print(f"  = {opening.id} (déjà généré, sauté)")
                continue

            config = config_for(opening, args)
            print(f"  → {opening.id} [{opening.side}] profondeur≤{config.max_depth} branches≤{config.max_branches}")
            try:
                course = build_course(opening, explorer, eco, evaluator, config)
            except Exception as exc:  # noqa: BLE001 - une ouverture ratée n'arrête pas le lot
                print(f"    ! échec: {exc}")
                continue

            issues = validate_course(course.to_dict())
            if issues:
                print(f"    ! intégrité ({len(issues)}): {issues[:3]}")
                continue

            payload = json.dumps(course.to_dict(), ensure_ascii=False, separators=(",", ":"))
            out_file.write_text(payload)
            stats = course_stats(course)
            size = len(payload.encode("utf-8"))
            report_rows.append({"id": opening.id, "size": size, **stats})
            catalog.append(CatalogEntry(
                id=opening.id, name=opening.name, side=opening.side, level=opening.level,
                eco=opening.eco or None, summary=opening.summary,
                positionCount=stats["positions"], maxDepth=stats["max_depth_plies"],
            ))
            print(f"    ✓ {stats['positions']} positions, prof {stats['max_depth_plies']}, {size/1024:.1f} Ko")
    finally:
        if hasattr(evaluator, "close"):
            evaluator.close()

    if catalog:
        (out_dir / "opening_catalog.json").write_text(
            json.dumps([c.to_dict() for c in catalog], ensure_ascii=False, separators=(",", ":"))
        )
    explorer.dump_failures(out_dir / "failed_positions.json")
    _print_report(report_rows, explorer)
    return 0


def _print_report(rows, explorer) -> None:
    print("\n=== Rapport de génération ===")
    if not rows:
        print("(aucune ouverture générée)")
    total_positions = sum(r["positions"] for r in rows)
    total_size = sum(r["size"] for r in rows)
    total_uncommented = sum(r["moves_without_comment"] for r in rows)
    for r in rows:
        print(f"  {r['id']:<26} {r['positions']:>5} pos  prof {r['max_depth_plies']:>2}  "
              f"{r['edges']:>5} arêtes  {r['size']/1024:>7.1f} Ko  {r['moves_without_comment']} sans commentaire")
    print(f"  ----\n  TOTAL: {len(rows)} ouvertures, {total_positions} positions, "
          f"{total_size/1024/1024:.2f} Mo, {total_uncommented} coups sans commentaire")
    print(f"  Requêtes réseau: {getattr(explorer, 'request_count', 0)} "
          f"(cache: {getattr(explorer, 'cache_hits', 0)}), échecs: {len(getattr(explorer, 'failed', []))}")
    if total_size > 30 * 1024 * 1024:
        print("  ⚠ >30 Mo : envisager compression/format binaire/On-Demand Resources (voir README).")


if __name__ == "__main__":
    raise SystemExit(main())
