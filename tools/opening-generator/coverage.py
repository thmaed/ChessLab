#!/usr/bin/env python3
"""Rapport de COUVERTURE : ce que l'adversaire joue et que le cours n'explique pas.

`audit.py` demande à Stockfish si les coups écrits sont bons. Ce script pose la
question inverse, et c'est la seule que l'Explorer Lichess sache trancher :
**parmi ce que le joueur va réellement affronter, qu'est-ce que le cours laisse
sans réponse ?**

## Pourquoi il ne « génère » rien

Les 58 cours sont écrits à la main (`content/*.py`, compilés par `author.py`) :
lignes d'enseignement, chapitres, commentaires bilingues. Les régénérer depuis
l'Explorer les remplacerait par des statistiques sans un mot d'explication.
Ce script ne touche donc à aucun cours : il produit une LISTE DE PRIORITÉS
d'écriture, à traiter à la main dans `content/`.

## La seule asymétrie qui compte

Un répertoire n'a pas à proposer tous les coups de SON camp — il en prescrit
un, c'est le principe. Mais il doit répondre à tout ce que l'ADVERSAIRE joue
souvent, sinon l'élève est livré à lui-même dès le premier écart.

Une lacune n'est donc relevée que sur un coup adverse. C'est ce qui sépare ce
rapport d'une liste de variantes sans fin.

## Priorité = probabilité d'ARRIVER là × fréquence du coup manquant

Une lacune à 40 % au 3e coup vaut bien plus qu'une lacune à 40 % au 12e, où
presque personne n'arrive. La probabilité d'atteinte est le produit des parts
des coups ADVERSES le long du chemin ; nos propres coups valent 1, puisque
c'est nous qui les choisissons.

Usage :
    export LICHESS_TOKEN=lip_xxxx
    python3 coverage.py --only scandinavian
    python3 coverage.py --threshold 0.08 --json rapport.json
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path

from explorer import TOKEN_HELP, LichessExplorer, token_from_environment
from fen import board_from_key, side_to_move

DEFAULT_COURSES = Path(__file__).resolve().parents[2] / "ChessLab" / "Resources" / "openings"

# Jusqu'à ce demi-coup inclus, un coup adverse non traité relève de la PORTÉE
# du cours, pas d'un trou : c'est lui qui décide de quelle ouverture on parle.
# Répertoire noir → le 1er coup blanc (racine, demi-coup 0) ; répertoire blanc
# → la 1re réponse noire (demi-coup 1). Une seule constante couvre les deux.
SCOPE_PLY = 1


def parse_args(argv):
    p = argparse.ArgumentParser(description="Lacunes de couverture des cours d'ouverture")
    p.add_argument("--courses", default=str(DEFAULT_COURSES),
                   help="dossier des cours compilés (défaut : les cours livrés)")
    p.add_argument("--only", help="identifiants séparés par des virgules")
    p.add_argument("--threshold", type=float, default=0.10,
                   help="part minimale d'un coup adverse pour être une lacune (défaut 0.10)")
    p.add_argument("--min-reach", type=float, default=0.01,
                   help="on cesse de descendre sous cette probabilité d'atteinte (défaut 0.01)")
    p.add_argument("--ratings", default="1400,1600,1800",
                   help="tranches Elo club — ce que le joueur affronte vraiment")
    p.add_argument("--speeds", default="blitz,rapid,classical")
    p.add_argument("--min-delay", type=float, default=1.0)
    p.add_argument("--cache", default=".cache", help="dossier de cache (partagé avec generate.py)")
    p.add_argument("--offline", action="store_true",
                   help="n'utiliser QUE le cache local : aucune requête réseau, aucun jeton requis. "
                        "Les positions absentes du cache sont traitées comme « donnée manquante », "
                        "donc le rapport ne peut que SOUS-estimer la dette — jamais l'inverse.")
    p.add_argument("--json", help="écrit le rapport complet en JSON")
    p.add_argument("--max-positions", type=int, default=400,
                   help="garde-fou par cours, pour ne pas partir en requêtes sans fin")
    return p.parse_args(argv)


def course_files(folder: Path, only):
    wanted = {s.strip() for s in only.split(",")} if only else None
    for path in sorted(folder.glob("*.json")):
        if path.name == "opening_catalog.json":
            continue
        if wanted and path.stem not in wanted:
            continue
        yield path


def move_shares(data: dict) -> tuple[dict, int]:
    """(part de chaque coup par uci, total de parties) d'après une réponse
    Explorer. Le total est recalculé depuis les coups : c'est lui qui fait
    somme 1, alors que les totaux de tête incluent des parties écartées."""
    moves = data.get("moves") or []
    counts = {}
    for m in moves:
        uci = m.get("uci")
        if not uci:
            continue
        counts[uci] = {
            "san": m.get("san") or uci,
            "games": (m.get("white") or 0) + (m.get("draws") or 0) + (m.get("black") or 0),
        }
    total = sum(c["games"] for c in counts.values())
    if total <= 0:
        return {}, 0
    for c in counts.values():
        c["share"] = c["games"] / total
    return counts, total


def audit_course(path: Path, explorer: LichessExplorer, args) -> dict:
    course = json.loads(path.read_text())
    positions = course.get("positions") or {}
    side = course.get("side", "white")
    root = course.get("rootFEN")
    if not root or root not in positions:
        return {"id": course.get("id", path.stem), "error": "rootFEN absent du graphe"}

    gaps = []
    seen = set()
    queried = 0
    # File d'attente : (clé de position, probabilité d'y arriver, demi-coups
    # depuis la racine). La profondeur sert à reconnaître le coup adverse qui
    # CHOISIT l'ouverture — voir `SCOPE_PLY`.
    queue = deque([(root, 1.0, 0)])
    # Une position atteinte par deux chemins cumule ses probabilités ; on la
    # traite au premier passage et on ignore les suivants — sous-estimation
    # assumée, très inférieure au bruit des arrondis de l'Explorer.
    while queue:
        key, reach, ply = queue.popleft()
        if key in seen or reach < args.min_reach:
            continue
        seen.add(key)
        entry = positions.get(key)
        if not entry:
            continue
        course_moves = entry.get("moves") or []
        covered = {m.get("uci") for m in course_moves if m.get("uci")}

        if side_to_move(key) == side:
            # Notre camp : le cours prescrit, il ne subit pas. On descend sans
            # rien reprocher et sans dépenser une requête.
            for m in course_moves:
                if m.get("toFEN"):
                    queue.append((m["toFEN"], reach, ply + 1))
            continue

        # Camp adverse : c'est ici, et seulement ici, qu'une lacune existe.
        if queried >= args.max_positions:
            continue
        board = board_from_key(key)
        data = explorer.lichess(board)
        queried += 1
        if not data:
            continue
        shares, total = move_shares(data)
        if not shares:
            continue

        # Trois natures très différentes, qu'il ne faut pas mélanger :
        # - « portée » : le coup adverse qui CHOISIT l'ouverture. Contre 1…d5,
        #   un Trompowsky (1.d4 Cf6 2.Fg5) n'existe pas — c'est un autre cours,
        #   pas un trou dans celui-ci. Même raison que pour la position de
        #   départ d'un répertoire noir, décalée d'un demi-coup ;
        # - « trou » : le cours CONTINUE par d'autres coups mais ignore
        #   celui-ci — l'élève suit sa leçon et tombe dans le vide ;
        # - « fin » : le cours s'arrête là, ce qui est un choix d'auteur
        #   légitime. L'étendre a de la valeur, mais ce n'est pas un défaut.
        if ply <= SCOPE_PLY:
            kind = "portée"
        else:
            kind = "trou" if covered else "fin"
        for uci, info in shares.items():
            if uci in covered:
                continue
            if info["share"] < args.threshold:
                continue
            gaps.append({
                "fen": key,
                "san": info["san"],
                "uci": uci,
                "share": info["share"],
                "games": info["games"],
                "reach": reach,
                "priority": reach * info["share"],
                "kind": kind,
            })

        # On ne descend que dans ce que le cours traite : le reste est
        # justement ce qu'on vient de signaler, et il n'a pas de suite écrite.
        for m in course_moves:
            uci = m.get("uci")
            to_fen = m.get("toFEN")
            if not to_fen:
                continue
            # Dans la zone de PORTÉE, la probabilité reste 1 : le rapport dit
            # « sachant qu'on joue bien cette ouverture », sinon tout serait
            # pondéré par la fréquence de 1.e4 et les cours deviendraient
            # incomparables entre eux.
            share = 1.0 if ply <= SCOPE_PLY else shares.get(uci, {}).get("share", 0.0)
            queue.append((to_fen, reach * share, ply + 1))

    gaps.sort(key=lambda g: g["priority"], reverse=True)
    holes = [g for g in gaps if g["kind"] == "trou"]
    return {
        "id": course.get("id", path.stem),
        "name": course.get("name", path.stem),
        "side": side,
        "positions": len(positions),
        "queried": queried,
        "gaps": gaps,
        "holes": holes,
        "endings": [g for g in gaps if g["kind"] == "fin"],
        "scope": [g for g in gaps if g["kind"] == "portée"],
    }


def print_report(reports, threshold):
    """Les TROUS d'abord, cours par cours ; les fins de cours seulement
    comptées. Un rapport qui mélange les deux se lit comme une liste de
    reproches et finit ignoré."""
    total_holes = total_endings = 0
    print(f"\n=== Trous de couverture (coups adverses ≥ {threshold:.0%}) ===\n")
    for r in reports:
        if r.get("error"):
            print(f"  {r['id']:<28} ⚠ {r['error']}")
            continue
        holes, endings = r["holes"], r["endings"]
        total_holes += len(holes)
        total_endings += len(endings)
        head = f"{r['id']:<28} {r['positions']:>4} pos | {r['queried']:>3} interrogées"
        if not holes:
            print(f"  {head} | ✓ aucun trou | {len(endings)} suite(s) possible(s)")
            continue
        print(f"  {head} | {len(holes)} trou(s) | {len(endings)} suite(s) possible(s)")
        for g in holes[:6]:
            print(f"      {g['san']:<8} {g['share']:>5.1%} des parties "
                  f"| atteinte {g['reach']:>5.1%} | priorité {g['priority']:.4f}")
            print(f"          après {g['fen']}")
        if len(holes) > 6:
            print(f"      … et {len(holes) - 6} autre(s)")
    print(f"\n  TOTAL : {total_holes} trou(s) — à écrire en priorité")
    print(f"          {total_endings} prolongement(s) possible(s) en fin de ligne\n")
    return total_holes


def main(argv=None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])

    if not args.offline and not token_from_environment():
        print(f"\n✗ Aucun jeton Lichess. {TOKEN_HELP}\n", file=sys.stderr)
        print("  (ou relancer avec --offline pour n'exploiter que le cache local)\n", file=sys.stderr)
        return 2

    folder = Path(args.courses)
    if not folder.is_dir():
        print(f"✗ Dossier de cours introuvable : {folder}", file=sys.stderr)
        return 2

    explorer = LichessExplorer(
        cache_dir=Path(args.cache) / "explorer", speeds=args.speeds,
        ratings=args.ratings, min_delay=args.min_delay, dry_run=args.offline,
    )

    reports = []
    for path in course_files(folder, args.only):
        report = audit_course(path, explorer, args)
        reports.append(report)
        gaps = len(report.get("gaps", []))
        print(f"  · {report['id']:<28} {gaps} lacune(s)", flush=True)

    total = print_report(reports, args.threshold)
    print(f"  Requêtes réseau : {explorer.request_count} "
          f"(cache : {explorer.cache_hits}), échecs : {len(explorer.failed)}")

    if args.json:
        Path(args.json).write_text(json.dumps(reports, ensure_ascii=False, indent=2))
        print(f"  Rapport écrit : {args.json}")

    # Volontairement 0 même avec des lacunes : c'est un rapport de priorités,
    # pas un test. `audit.py` reste la seule étape bloquante.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
