"""Audit des cours de FINALES — par tablebase, donc par preuve.

Pour les ouvertures, `audit.py` estime (moteur, seuil en centipions). Ici, la
tablebase Syzygy donne le verdict EXACT de chaque position ≤ 7 pièces : cet
audit ne tolère donc AUCUNE approximation sur ce périmètre.

## Les règles

Pour chaque arête d'un cours `kind == "endgame"` :

1. **Coup du camp étudié** (celui de `side`) : il doit PRÉSERVER le verdict de
   la position — un gain reste un gain, une nulle reste une nulle. Sous jeu
   optimal, un coup ne peut jamais AMÉLIORER son propre verdict ; tout écart
   est donc une dégradation, et une dégradation enseignée est une faute
   d'audit… sauf si l'arête est marquée `role: "trap"` ou `"inaccuracy"` — la
   faute est alors LA leçon (le pat classique, par exemple), et on vérifie
   même l'inverse : qu'elle dégrade bien le verdict, sinon le « piège » n'en
   est pas un.

2. **Coup de l'adversaire** : il ne peut pas améliorer son sort (théorème) ;
   il peut le dégrader (défense naturelle mais fautive, qu'on a le droit
   d'enseigner à punir). On SIGNALE ces défenses sous-optimales à titre
   d'information — elles doivent être un choix pédagogique, pas un accident.

3. **Position > 7 pièces** (hors tablebase) : repli sur Stockfish à forte
   profondeur, même logique de seuil que `audit.py`. Signalé comme
   « vérifié moteur » et non « prouvé » — l'honnêteté du rapport compte.

Sortie : rapport lisible + code retour non nul si une arête enseignée casse
son verdict.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import chess

from fen import board_from_key, side_to_move
from tablebase import Tablebase

HERE = Path(__file__).resolve().parent
COURSES_DIR = HERE.parents[1] / "ChessLab" / "Resources" / "openings"

# Au-delà de 7 pièces la tablebase ne dit rien : moteur, profondeur élevée.
ENGINE_DEPTH = 28
ENGINE_WIN_CP = 250  # au-delà : « gagnant » au sens pratique


def piece_count(key: str) -> int:
    return sum(1 for c in key.split(" ")[0] if c.isalpha())


def audit_course(course: dict, tb: Tablebase, engine=None) -> dict:
    """Rapport d'un cours : {taught_breaks, weak_defenses, engine_checked,
    fake_traps, missed_wins, early_stops}."""
    side = course.get("side", "white")
    report = {"taught_breaks": [], "weak_defenses": [], "engine_checked": [],
              "fake_traps": [], "missed_wins": [], "early_stops": []}

    for key, node in course["positions"].items():
        edges = node.get("moves", [])
        if not edges:
            _check_early_stop(key, side, tb, report)
            continue
        if piece_count(key) > 7:
            mover_here = side_to_move(key)
            for edge in edges:
                # Les pièges assument leur chute d'évaluation — comme côté
                # tablebase. On les note sans les compter en échec.
                excused = edge.get("role") in ("trap", "inaccuracy") or mover_here != side
                note = _engine_note(key, edge, engine)
                if excused:
                    note += " [assumé]" if "⚠" in note else ""
                    note = note.replace("⚠", "signalé :")
                report["engine_checked"].append(note)
            continue

        parent_verdict = tb.category(key)          # POV camp au trait
        move_verdicts = tb.move_categories(key)     # POV camp qui joue
        mover = side_to_move(key)

        for edge in edges:
            verdict = move_verdicts.get(edge["uci"])
            if verdict is None:
                report["taught_breaks"].append(
                    f"{edge['san']} depuis {key} : coup inconnu de la tablebase")
                continue
            preserved = (verdict == parent_verdict)

            if mover == side:
                role = edge.get("role")
                if role == "trap":
                    # Un piège doit VRAIMENT dégrader, sinon il ment.
                    if preserved:
                        report["fake_traps"].append(
                            f"{edge['san']} depuis {key} : marqué piège mais préserve {parent_verdict}")
                elif role == "inaccuracy":
                    # « Imprécision » en finale : garde le verdict mais ne
                    # progresse pas (le Kc7 sans pont de la Lucena). Ni
                    # obligation de dégrader, ni faute si ça dégrade — mais on
                    # le SIGNALE si ça dégrade, pour que ce soit un choix.
                    if not preserved:
                        report["weak_defenses"].append(
                            f"{edge['san']} depuis {key} : imprécision qui dégrade "
                            f"{parent_verdict} → {verdict} (piège plutôt ?)")
                elif not preserved:
                    report["taught_breaks"].append(
                        f"{edge['san']} depuis {key} : {parent_verdict} → {verdict}")
                else:
                    _check_missed_win(key, edge, tb, report)
            else:
                # L'adversaire qui joue moins bien que l'optimal : information.
                if not preserved:
                    report["weak_defenses"].append(
                        f"{edge['san']} depuis {key} : l'adversaire concède {parent_verdict} → {verdict}")
    return report


def _check_missed_win(key: str, edge: dict, tb: Tablebase, report: dict) -> None:
    """Le cours enseigne-t-il un coup correct EN IGNORANT un gain immédiat ?

    🐛 C'est le défaut qui a échappé à cet audit sur le pion passé éloigné : la
    ligne faisait jouer 3.Re6 dans une position où a8=D promouvait sur-le-champ.
    Le verdict était préservé — donc l'audit se taisait — mais la leçon perdait
    tout son sens, puisque la technique enseignée n'était plus nécessaire.

    On ne juge PAS la longueur : un coup un peu plus lent peut être plus
    instructif, et c'est légitime. On ne signale que l'évidence ignorée — un mat
    en un, ou une promotion en dame QUE L'ADVERSAIRE NE PEUT PAS REPRENDRE.

    Cette dernière condition n'est pas un détail : une dame reprise au coup
    suivant reste « gagnante » pour la tablebase, alors que c'est souvent le
    coup thématique du cours (les pions liés qui se donnent l'un pour l'autre).
    Sans elle, ce contrôle criait au loup sur la moitié des finales de pions.
    """
    # Un coup enseigné qui mate ou promeut EST l'évidence : il ne peut rien
    # « ignorer ». Sans ce retrait, le premier passage du contrôle réparé
    # criait au loup sur trois mats du catalogue — Db1# « ignorant » Dd2#.
    if edge["san"].endswith("#") or "=Q" in edge["san"]:
        return
    board = board_from_key(key)
    verdicts = tb.move_categories(key)
    obvious = []
    for move in board.legal_moves:
        uci = move.uci()
        if uci == edge["uci"]:
            continue
        # `move_categories` parle du POINT DE VUE DU JOUEUR : « win » = ce
        # coup gagne. La première version testait `!= "loss"` — l'API brute
        # parle, elle, du point de vue de l'adversaire — et gardait donc les
        # coups PERDANTS : le contrôle était un no-op silencieux pour le
        # défaut même qu'il documente (revue du 24/08).
        if verdicts.get(uci) != "win":        # ne gagne pas : sans intérêt
            continue
        san = board.san(move)
        if san.endswith("#"):
            obvious.append(san)
            continue
        if "=Q" not in san:
            continue
        after = board.copy()
        after.push(move)
        if any(after.is_capture(reply) and reply.to_square == move.to_square
               for reply in after.legal_moves):
            continue                          # dame reprise : pas une évidence
        obvious.append(san)
    if obvious:
        report["missed_wins"].append(
            f"{edge['san']} depuis {key} : ignore {', '.join(sorted(set(obvious))[:3])} "
            f"qui gagne sur-le-champ")


# Au-delà, une ligne qui s'arrête laisse l'élève sans la conversion.
EARLY_STOP_DTM = 8


def _check_early_stop(key: str, side: str, tb: Tablebase, report: dict) -> None:
    """La ligne s'arrête-t-elle AVANT d'avoir montré le gain ?

    Retour utilisateur sur la triangulation : « s'arrête trop tôt dans
    l'évaluation des coups ». Le cours concluait « la conversion est désormais
    mécanique » — une phrase facile à écrire, et que l'élève ne voit jamais.

    On signale une feuille encore GAGNANTE pour le camp étudié, à plus de
    `EARLY_STOP_DTM` coups du mat, ET où l'adversaire a encore du matériel.

    Cette dernière condition fait toute la différence : une ligne qui s'achève
    sur un roi nu a fini son travail, quel que soit le nombre de coups qui
    restent — mater avec deux pions ou avec une tour est élémentaire, et
    l'imposer allongerait tous les cours pour rien. Une ligne qui s'arrête
    alors que l'adversaire a encore de quoi se battre, elle, laisse l'élève au
    milieu du gué : c'est exactement ce que faisait la triangulation, qui
    s'arrêtait sur « la conversion est mécanique » sans jamais la montrer.
    """
    if piece_count(key) > 7:
        return
    # Les éliminations GRATUITES d'abord : la sonde coûte une lecture disque,
    # voire une requête réseau throttlée — la plupart des feuilles finissent
    # sur une promotion et sortent ici sans rien coûter.
    placement = key.split(" ")[0]
    if "Q" in placement or "q" in placement:
        return
    probe = tb.probe(key)
    if not probe:
        return
    mover = side_to_move(key)
    # Les catégories « cursed-win »/« maybe-win » SONT des gains (règle des
    # 50 coups mise à part) : sans ce repli, les positions à 6-7 pièces
    # passaient sous le radar.
    category = {"cursed-win": "win", "maybe-win": "win",
                "blessed-loss": "loss", "maybe-loss": "loss"}.get(
        probe.get("category"), probe.get("category"))
    # Verdict du POINT DE VUE du camp étudié.
    winning_for_side = (category == "win") if mover == side else (category == "loss")
    if not winning_for_side:
        return
    # L'adversaire a-t-il encore du matériel ? Roi nu = travail terminé.
    #
    # Le DÉFENSEUR est le camp qui n'est pas étudié — le trait n'entre pas
    # dans la question. Une première version le déduisait du trait et se
    # trompait de camp : elle comptait les pions de l'attaquant comme du
    # matériel de défense, et signalait donc des lignes qui s'achevaient
    # pourtant sur un roi nu.
    defender_white = (side != "white")
    defender_men = [ch for ch in placement
                    if ch.isalpha() and (ch.isupper() == defender_white) and ch.upper() != "K"]
    if not defender_men:
        return
    dtm = probe.get("dtm")
    if dtm is None:
        # L'API ne donne pas de DTM aux positions à 6-7 pièces. Repli sur le
        # DTZ (distance au prochain coup de pion / prise) : ce n'est PAS la
        # distance au mat, mais un DTZ élevé prouve à lui seul que la
        # conversion est loin — le cas inverse (DTZ court, mat lointain)
        # échappe au contrôle, et c'est assumé : mieux vaut un filet à
        # grosses mailles qu'un contrôle qui se tait sur toute la famille.
        dtz = probe.get("dtz")
        if dtz is None or abs(dtz) <= EARLY_STOP_DTM:
            return
        report["early_stops"].append(
            f"{key} : la ligne s'arrête sur un gain encore à {abs(dtz)} coups "
            f"de la prochaine conversion (DTZ, position sans DTM)")
        return
    if abs(dtm) <= EARLY_STOP_DTM:
        return
    report["early_stops"].append(
        f"{key} : la ligne s'arrête sur un gain encore à {abs(dtm)} coups du mat")


def _band(cp: int) -> str:
    """Le VERDICT pratique d'une évaluation : gain, nulle, ou perte.

    Le contrôle moteur juge désormais comme le contrôle tablebase — « le
    verdict a-t-il changé ? » — et non « combien de centipions ont été
    perdus ? ». Motif : sur les positions à plus de sept pièces des finales,
    l'évaluation est presque toujours un mat annoncé, et la valeur numérique
    d'un mat n'a aucune stabilité. La MÊME arête du cours « percée » a été
    notée +6502 → +9967 (OK), puis +8308 → +9970 (OK), puis +1344 → +1189
    (⚠ perd 155 cp) sur trois exécutions du même audit : le verdict de l'outil
    basculait d'un lancement à l'autre. Un garde-fou qui clignote est pire
    qu'aucun garde-fou.
    """
    if cp >= ENGINE_WIN_CP:
        return "gain"
    if cp <= -ENGINE_WIN_CP:
        return "perte"
    return "nulle"


def _engine_note(key: str, edge: dict, engine) -> str:
    if engine is None:
        return f"{edge['san']} depuis {key} : > 7 pièces, NON vérifié (pas de moteur fourni)"
    board = board_from_key(key)
    import chess.engine as ce
    before = engine.analyse(board, ce.Limit(depth=ENGINE_DEPTH))
    before_cp = before["score"].pov(board.turn).score(mate_score=10000)
    board.push(chess.Move.from_uci(edge["uci"]))
    after = engine.analyse(board, ce.Limit(depth=ENGINE_DEPTH))
    after_cp = -after["score"].pov(board.turn).score(mate_score=10000)
    before_band, after_band = _band(before_cp), _band(after_cp)
    status = "OK" if before_band == after_band else f"⚠ {before_band} → {after_band}"
    return (f"{edge['san']} depuis {key} : moteur d{ENGINE_DEPTH} "
            f"{before_cp:+} → {after_cp:+} ({status})")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Audit tablebase des cours de finales")
    parser.add_argument("--dir", default=str(COURSES_DIR))
    parser.add_argument("--only", help="ids séparés par des virgules")
    parser.add_argument("--stockfish", help="binaire pour les positions > 7 pièces")
    args = parser.parse_args(argv)

    tb = Tablebase()
    engine = None
    if args.stockfish:
        import chess.engine as ce
        engine = ce.SimpleEngine.popen_uci(args.stockfish)
        engine.configure({"Threads": 4, "Hash": 1024})

    wanted = {s.strip() for s in args.only.split(",")} if args.only else None
    failures = 0
    warnings = 0
    audited = 0
    try:
        for path in sorted(Path(args.dir).glob("*.json")):
            if path.name == "opening_catalog.json":
                continue
            course = json.loads(path.read_text())
            if course.get("kind") != "endgame":
                continue
            if wanted and course["id"] not in wanted:
                continue
            audited += 1
            report = audit_course(course, tb, engine)
            edge_count = sum(len(n.get("moves", [])) for n in course["positions"].values())
            print(f"\n· {course['id']:<28} {len(course['positions'])} positions, {edge_count} arêtes")
            for line in report["taught_breaks"]:
                print(f"  ✗ ENSEIGNÉ CASSE LE VERDICT : {line}")
                failures += 1
            for line in report["fake_traps"]:
                print(f"  ✗ FAUX PIÈGE : {line}")
                failures += 1
            for line in report["missed_wins"]:
                print(f"  ⚠ GAIN IMMÉDIAT IGNORÉ : {line}")
                warnings += 1
            for line in report["early_stops"]:
                print(f"  ⚠ LIGNE INTERROMPUE : {line}")
                warnings += 1
            for line in report["weak_defenses"]:
                print(f"  ℹ défense sous-optimale (voulue ?) : {line}")
            for line in report["engine_checked"]:
                print(f"  ~ {line}")
                if "⚠" in line:
                    failures += 1
    finally:
        if engine is not None:
            engine.quit()

    print(f"\n{audited} cours de finales audités — "
          f"{tb.requests} requêtes tablebase ({tb.cache_hits} en cache)")
    if failures:
        print(f"✗ {failures} problème(s) prouvé(s)")
        return 1
    print("✓ Chaque coup enseigné préserve son verdict théorique (tablebase).")
    if warnings:
        # PAS bloquant : ces deux contrôles jugent la pédagogie, pas la
        # vérité. Un gain immédiat peut être délibérément écarté, une ligne
        # peut s'arrêter là où l'auteur estime que l'élève sait finir. Mais ce
        # doit être un CHOIX, et il doit se voir.
        print(f"⚠ {warnings} avertissement(s) pédagogique(s) — à relire, non bloquants")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
