#!/usr/bin/env python3
"""Ajuste la courbe « perte moyenne → Elo estimé » sur les mesures du pilote.

Entrée : le CSV produit par le harnais de calibrage (une ligne par CAMP de
chaque partie jouée à un palier connu) :

    tier,elo,side,averageLoss,classifiedCount,bookCount,accuracy,version

Sortie : un JSON versionné, embarquable dans `Resources/`, qui donne pour une
perte moyenne l'Elo central et la demi-largeur de la fourchette.

## Pourquoi une régression MONOTONE

La relation est monotone par nature : perdre davantage à chaque coup ne peut
pas correspondre à un meilleur joueur. Un polynôme libre, lui, ondulerait entre
les paliers mesurés et produirait des inversions absurdes (« 12 points de perte
= 1500, 13 points = 1560 »). On ajuste donc une courbe à forme imposée, et on
vérifie la monotonie avant d'écrire quoi que ce soit.

La forme retenue est une exponentielle décroissante,

    elo(perte) = plancher + amplitude * exp(-taux * perte)

qui a trois qualités ici : elle est monotone par construction, elle s'aplatit
en haut (entre 2600 et 2900, la perte moyenne se distingue à peine — c'est un
fait, pas un défaut d'ajustement), et elle n'explose pas en bas.

## Ce que la dispersion devient

L'écart-type des pertes DANS un palier ne se transporte pas tel quel en Elo :
c'est sa traduction par la pente locale de la courbe qui donne la fourchette.
Là où la courbe est plate (haut de l'échelle), un même écart de perte vaut
beaucoup plus d'Elo — la fourchette s'élargit d'elle-même, ce qui est honnête.

Usage :
    python3 fit_curve.py mesures.csv --out curve.json
    python3 fit_curve.py mesures.csv --min-samples 8
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
import sys
from pathlib import Path

# Bornes d'affichage : hors de la plage mesurée, on n'extrapole pas, on borne.
DISPLAY_FLOOR = 800
DISPLAY_CEILING = 2900
# Demi-largeur minimale : une fourchette de ±20 Elo donnerait une fausse
# impression de précision, quelle que soit la qualité de l'ajustement.
MIN_HALF_WIDTH = 75


def read_rows(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    parsed = []
    for row in rows:
        try:
            loss = float(row["averageLoss"])
            elo = int(row["elo"])
            moves = int(row["classifiedCount"])
        except (KeyError, ValueError):
            continue
        # Le garde-fou du produit s'applique DÈS le calibrage : une partie qui
        # ne serait pas estimée en production ne doit pas servir à caler la
        # courbe qui l'estimera.
        if moves < 15:
            continue
        parsed.append({"elo": elo, "loss": loss, "moves": moves,
                       "version": row.get("version", "")})
    return parsed


def group_by_tier(rows: list[dict]) -> dict[int, list[float]]:
    tiers: dict[int, list[float]] = {}
    for row in rows:
        tiers.setdefault(row["elo"], []).append(row["loss"])
    return dict(sorted(tiers.items()))


def fit_exponential(points: list[tuple[float, float]]) -> tuple[float, float, float]:
    """Ajuste elo = plancher + amplitude * exp(-taux * perte).

    Le plancher est balayé sur une grille (il n'entre pas linéairement dans le
    modèle) ; pour chaque valeur, le reste devient une régression linéaire sur
    le logarithme, qui se résout exactement. On garde le meilleur résidu.
    """
    best = None
    max_elo = max(elo for _, elo in points)
    for floor in range(0, min(1200, int(min(elo for _, elo in points))), 25):
        xs, ys = [], []
        for loss, elo in points:
            residual = elo - floor
            if residual <= 0:
                break
            xs.append(loss)
            ys.append(math.log(residual))
        else:
            n = len(xs)
            mean_x = sum(xs) / n
            mean_y = sum(ys) / n
            denominator = sum((x - mean_x) ** 2 for x in xs)
            if denominator == 0:
                continue
            slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / denominator
            intercept = mean_y - slope * mean_x
            amplitude = math.exp(intercept)
            rate = -slope
            if rate <= 0 or amplitude <= 0:
                continue
            error = sum((floor + amplitude * math.exp(-rate * loss) - elo) ** 2
                        for loss, elo in points)
            if best is None or error < best[0]:
                best = (error, floor, amplitude, rate)
    if best is None:
        raise SystemExit("✗ Ajustement impossible : les mesures ne décroissent pas.")
    _, floor, amplitude, rate = best
    if floor + amplitude > max_elo * 3:
        print("  ⚠ amplitude très supérieure aux mesures : peu de paliers ?", file=sys.stderr)
    return floor, amplitude, rate


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path)
    parser.add_argument("--out", type=Path, default=Path("curve.json"))
    parser.add_argument("--min-samples", type=int, default=8,
                        help="parties minimum par palier pour qu'il compte")
    args = parser.parse_args(argv)

    rows = read_rows(args.csv)
    if not rows:
        raise SystemExit("✗ Aucune mesure exploitable (≥ 15 coups classés) dans le CSV.")

    versions = {row["version"] for row in rows if row["version"]}
    if len(versions) > 1:
        raise SystemExit(f"✗ Deux barèmes mélangés dans le CSV : {sorted(versions)}. "
                         "Ne jamais ajuster sur des mesures incomparables.")

    tiers = group_by_tier(rows)
    usable = {elo: losses for elo, losses in tiers.items() if len(losses) >= args.min_samples}
    print(f"{len(rows)} mesures, {len(tiers)} paliers "
          f"({len(usable)} retenus à ≥ {args.min_samples} parties)\n")

    print(f"{'palier':>7} {'n':>4} {'perte moy':>10} {'écart-type':>11}")
    points, spreads = [], {}
    for elo, losses in usable.items():
        mean = statistics.fmean(losses)
        spread = statistics.stdev(losses) if len(losses) > 1 else 0.0
        print(f"{elo:7d} {len(losses):4d} {mean:10.2f} {spread:11.2f}")
        points.append((mean, float(elo)))
        spreads[elo] = spread

    if len(points) < 3:
        raise SystemExit("\n✗ Moins de trois paliers exploitables : pas de courbe. "
                         "Augmenter le nombre de parties, ou baisser --min-samples.")

    # Monotonie des mesures elles-mêmes : si elle manque ICI, ce n'est pas
    # l'ajustement qui est en cause, c'est la campagne.
    ordered = sorted(points, key=lambda p: p[1])
    for (loss_a, elo_a), (loss_b, elo_b) in zip(ordered, ordered[1:]):
        if loss_b > loss_a:
            print(f"\n⚠ NON MONOTONE : le palier {int(elo_b)} perd plus que {int(elo_a)} "
                  f"({loss_b:.2f} > {loss_a:.2f}). Échantillon trop petit, "
                  "ou les deux paliers sont indiscernables.", file=sys.stderr)

    floor, amplitude, rate = fit_exponential(points)
    print(f"\nCourbe : elo = {floor:.0f} + {amplitude:.0f} × exp(−{rate:.4f} × perte)")

    # Fourchette : l'écart-type des pertes traduit en Elo par la pente locale.
    half_widths = {}
    for elo, spread in spreads.items():
        mean_loss = statistics.fmean(usable[elo])
        slope = amplitude * rate * math.exp(-rate * mean_loss)  # |d(elo)/d(perte)|
        half_widths[elo] = max(MIN_HALF_WIDTH, round(spread * slope))
    typical = round(statistics.fmean(half_widths.values()))
    print(f"Demi-largeur : {min(half_widths.values())}–{max(half_widths.values())} Elo "
          f"(moyenne {typical})")

    curve = {
        "version": 1,
        "model": "floor + amplitude * exp(-rate * averageLoss)",
        "floor": round(floor, 2),
        "amplitude": round(amplitude, 2),
        "rate": round(rate, 6),
        "halfWidthByTier": {str(elo): width for elo, width in sorted(half_widths.items())},
        "defaultHalfWidth": typical,
        "displayFloor": DISPLAY_FLOOR,
        "displayCeiling": DISPLAY_CEILING,
        "minClassifiedMoves": 15,
        "measuredTiers": sorted(usable),
        "samplesPerTier": {str(elo): len(losses) for elo, losses in sorted(usable.items())},
    }
    args.out.write_text(json.dumps(curve, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\n✓ Courbe écrite : {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
