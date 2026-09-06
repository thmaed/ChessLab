# Spike Maia-3 → Core ML (05/09/2026)

Scripts du spike de faisabilité « Maia-3 joue, Stockfish analyse ». Rien n'est
branché dans l'app : ce dossier documente une mesure, rejouable.

## Reproduire

```bash
python3 -m venv mlenv && ./mlenv/bin/pip install "torch==2.7.0" coremltools numpy python-chess
git clone --depth 1 https://github.com/CSSLab/maia3
curl -L -o maia3-5m.pt https://huggingface.co/UofTCSSLab/Maia3-5M/resolve/main/maia3-5m.pt
./mlenv/bin/python convert_maia3_v2.py   # conversion + accord + latence
./mlenv/bin/python probe_maia3.py        # comportement par Elo sur positions choisies
./mlenv/bin/python probe2.py
./mlenv/bin/python bench_cpu.py          # unités de calcul + palettisation 8 bits
```

torch 2.14 échoue à la conversion (`aten::Int` sur une forme), 2.7.0 passe.
Le wrapper `ExportMaia` réécrit le forward avec des formes littérales (batch 1)
et sans lookup d'embedding : équivalent à l'original à 1,7e-4 près.

## Mesuré sur Mac M2

| Mesure | Valeur |
|---|---|
| Paramètres Maia3-5M | 5,23 M |
| `.mlpackage` fp16 | 10 Mo (5,1 Mo en palettisation 8 bits, Δlogit max 0,16) |
| Accord top-1 torch / Core ML fp16 | 35 / 36 positions×Elo, Δprob max 0,0034 |
| Latence Core ML (toutes unités / CPU seul / CPU+ANE) | 3,8 / 1,4 / 0,8 ms |
| Latence torch CPU | 7,2 ms |

## Comportement observé (probabilités du coup, par Elo de conditionnement)

- Pièce en prise (dxe5 gagne un cavalier) : 96 % à 800, 98 % dès 1100.
- Mat du couloir Ta8# : 80-85 % à tous les niveaux.
- Défense du mat du berger (1.e4 e5 2.Fc4 Cc6 3.Dh5) : Cf6?? joué 20 % à 800,
  9 % à 1100, 7 % à 1500, 2 % à 2400. Gradient humain net.
- Attaque grecque Fxh7+ gagnante : jamais dans le top 4, à aucun niveau. Maia
  ne calcule pas ; à 2400 il joue h4 (85 %).
- Finale de pions élémentaire : trois coups à ~40 % sans différenciation par
  niveau ; la tête de valeur, elle, passe de 20 % à 65 % de gain entre 800 et
  2400.

## Calibrage de Camille contre Stockfish bridé (05/09/2026, `calibration/`)

Harnais : `ChessLabTests/MaiaCalibrationHarness.swift` (camp A = Camille à la
CONSIGNE m avec son filet au NIVEAU N, camp B = Stockfish bridé à N, couleurs
alternées, livres éteints, 300 ms/coup, 30 parties par point).

| Niveau N (Stockfish) | Consigne m (Maia) | Score de Camille | Écart Elo (IC 95 %) |
|---|---|---|---|
| 1100 | 1400 | 5 % | −512 (−2400 ; −306) |
| 1100 | 1800 | 13 % | −325 (−783 ; −186) |
| 1100 | 2200 | 18 % | −260 (−591 ; −120) |
| 1500 | 1600 | 17 % | −280 (−708 ; −134) |
| 1500 | 2000 | 33 % | −120 (−301 ; +11) |

Pilote à 150 ms (6 parties, bruité) : consigne 2000 vs 1500 → +58.

**Lecture.** Stockfish bridé à « 1100 » (Skill Level 3, profondeur 4) écrase
Maia consigne 2200 : les deux échelles ne sont pas comparables, et aucune
consigne ne rattrape les paliers bas. Décision : le niveau d'un personnage
suit l'échelle humaine de Maia (proche de Lichess) et l'écran le dit ; le
mode « Niveau Elo » garde l'échelle Stockfish. La courbe m(N) n'est donc
pas appliquée. Le harnais reste pour mesurer les personnages entre eux
(camp A = personnage, camp B = Camille) — le lot D.1.d de l'étude d'août.
