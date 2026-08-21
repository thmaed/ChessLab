#!/usr/bin/env python3
"""Une statistique candidate sépare-t-elle DEUX PALIERS VOISINS, ou pas ?

C'est la question qui décide si le chantier C.2 a un sens. Ajuster une courbe
est facile ; ce qui est difficile, c'est qu'une SEULE partie permette d'annoncer
une fourchette assez étroite pour dire quelque chose.

## Ce qui est mesuré

Pour chaque paire de paliers consécutifs, le **d de Cohen** : l'écart entre les
deux moyennes rapporté au bruit commun. C'est le rapport signal/bruit de la
statistique, indépendamment de l'échelle dans laquelle elle s'exprime — ce qui
permet de comparer une perte en points de pourcentage à une proportion de coups
fautifs.

Repères : d < 1 = les deux paliers se recouvrent largement ; d ≈ 1,5 = ils se
distinguent mais avec chevauchement ; d ≥ 2 = séparation nette.

## Et pourquoi le d ne suffit pas

Un d honorable entre paliers ESPACÉS DE 600 ELO ne dit encore rien de la
fourchette réelle. On traduit donc, pour chaque statistique, la dispersion
intra-palier en Elo via la pente locale : c'est la demi-largeur qu'un
utilisateur verrait à l'écran. En dessous de ±150 Elo l'annonce est utile ;
au-delà de ±300 elle ne l'est plus.

Usage :
    python3 discriminate.py mesures.csv
"""
from __future__ import annotations

import argparse
import csv
import statistics
import sys
from pathlib import Path

# Colonnes candidates : nom lisible → (colonne CSV, décroissante avec le niveau)
CANDIDATES = {
    "perte moyenne": ("averageLoss", True),
    "perte (positions indécises)": ("balancedLoss", True),
    "part de coups fautifs": ("faultRate", True),
    "précision": ("accuracy", False),
}

# La barre est posée par le produit, pas par la statistique : au-delà de
# ±150 Elo, l'annonce n'apprend rien et le chantier est abandonné (décision
# utilisateur du 21/08).
USEFUL_HALF_WIDTH = 150
# Nombre de parties de l'estimé glissant de l'écran Progrès. Moyenner divise
# l'erreur par la racine du nombre de parties : une statistique inutilisable
# sur UNE partie peut très bien tenir la barre sur dix.
ROLLING_GAMES = 10


def load(path: Path) -> dict[str, dict[int, list[float]]]:
    series: dict[str, dict[int, list[float]]] = {name: {} for name in CANDIDATES}
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            try:
                elo = int(row["elo"])
                if int(row["classifiedCount"]) < 15:
                    continue
            except (KeyError, ValueError):
                continue
            for name, (column, _) in CANDIDATES.items():
                raw = row.get(column, "")
                if raw in ("", None):
                    continue
                try:
                    series[name].setdefault(elo, []).append(float(raw))
                except ValueError:
                    continue
    return series


def cohens_d(a: list[float], b: list[float]) -> float:
    if len(a) < 2 or len(b) < 2:
        return 0.0
    pooled = ((statistics.stdev(a) ** 2 + statistics.stdev(b) ** 2) / 2) ** 0.5
    return abs(statistics.fmean(a) - statistics.fmean(b)) / pooled if pooled else 0.0


def half_width_elo(tiers: dict[int, list[float]]) -> float | None:
    """Demi-largeur typique, en Elo, qu'un utilisateur verrait.

    La pente locale est estimée entre paliers voisins : combien d'Elo vaut une
    unité de la statistique, là où elle se trouve. L'écart-type intra-palier,
    multiplié par cette pente, donne la fourchette d'UNE partie.
    """
    ordered = sorted(tiers)
    if len(ordered) < 2:
        return None
    widths = []
    for lower, upper in zip(ordered, ordered[1:]):
        mean_low = statistics.fmean(tiers[lower])
        mean_high = statistics.fmean(tiers[upper])
        span = abs(mean_high - mean_low)
        if span == 0:
            continue
        elo_per_unit = abs(upper - lower) / span
        for tier in (lower, upper):
            values = tiers[tier]
            if len(values) > 1:
                widths.append(statistics.stdev(values) * elo_per_unit)
    return statistics.fmean(widths) if widths else None


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path)
    args = parser.parse_args(argv)

    series = load(args.csv)
    verdicts = []

    for name, (column, decreasing) in CANDIDATES.items():
        tiers = {elo: values for elo, values in series[name].items() if len(values) >= 2}
        if len(tiers) < 2:
            print(f"\n=== {name} : pas assez de données (colonne « {column} » absente ?)")
            continue

        print(f"\n=== {name}")
        print(f"{'palier':>7} {'n':>4} {'moyenne':>9} {'écart-type':>11}")
        ordered = sorted(tiers)
        for elo in ordered:
            values = tiers[elo]
            spread = statistics.stdev(values) if len(values) > 1 else 0.0
            print(f"{elo:7d} {len(values):4d} {statistics.fmean(values):9.3f} {spread:11.3f}")

        # Monotonie : sans elle, aucune courbe n'a de sens.
        means = [statistics.fmean(tiers[elo]) for elo in ordered]
        monotone = all(
            (b < a) if decreasing else (b > a) for a, b in zip(means, means[1:])
        )
        print(f"  monotone : {'oui' if monotone else 'NON'}")

        print("  séparation des paliers voisins :")
        ds = []
        for lower, upper in zip(ordered, ordered[1:]):
            d = cohens_d(tiers[lower], tiers[upper])
            ds.append(d)
            label = "nette" if d >= 2 else ("limite" if d >= 1.5 else "insuffisante")
            print(f"    {lower}→{upper:<5} d = {d:5.2f}  ({label})")

        width = half_width_elo(tiers)
        weakest = min(ds) if ds else 0.0
        rolling = None
        if width is not None:
            rolling = width / (ROLLING_GAMES ** 0.5)
            verdict_one = "tient la barre" if width <= USEFUL_HALF_WIDTH else "hors barre"
            verdict_ten = "tient la barre" if rolling <= USEFUL_HALF_WIDTH else "hors barre"
            print(f"  fourchette — 1 partie   : ±{width:.0f} Elo ({verdict_one})")
            print(f"             — {ROLLING_GAMES} parties : ±{rolling:.0f} Elo ({verdict_ten})")
        verdicts.append((name, monotone, weakest, width, rolling))

    print("\n" + "=" * 70)
    print(f"VERDICT — barre produit : ±{USEFUL_HALF_WIDTH} Elo, sinon on abandonne.")
    print("=" * 70)
    print(f"  {'statistique':<30} {'d min':>6} {'1 partie':>10} {'10 parties':>12}")
    per_game, rolling_only = [], []
    for name, monotone, weakest, width, rolling in verdicts:
        one_ok = monotone and width is not None and width <= USEFUL_HALF_WIDTH
        ten_ok = monotone and rolling is not None and rolling <= USEFUL_HALF_WIDTH
        mark = "✓" if one_ok else ("~" if ten_ok else "✗")
        w = f"±{width:.0f}" if width is not None else "—"
        r = f"±{rolling:.0f}" if rolling is not None else "—"
        print(f"  {mark} {name:<28} {weakest:6.2f} {w:>10} {r:>12}")
        if one_ok:
            per_game.append(name)
        elif ten_ok:
            rolling_only.append(name)

    if per_game:
        print(f"\n→ Tient la barre PAR PARTIE : {', '.join(per_game)}.")
        print("  L'affichage par partie ET l'estimé glissant sont tous deux fondés.")
    elif rolling_only:
        print(f"\n→ Hors barre par partie, mais tient sur {ROLLING_GAMES} parties :")
        print(f"  {', '.join(rolling_only)}.")
        print("  Conclusion produit : renoncer au chiffre par partie, ne garder que")
        print("  l'estimé glissant de l'écran Progrès — qui est justement celui")
        print("  qu'un joueur regarde pour se situer.")
    else:
        print("\n→ AUCUNE candidate ne passe, même en moyennant dix parties.")
        print("  Plus de parties resserrent la MOYENNE d'un palier, pas la")
        print("  dispersion d'une partie : la campagne complète n'y changerait")
        print("  rien. Le chantier C.2 s'arrête ici, et c'est un résultat.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
