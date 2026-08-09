"""Round-trip de l'outil d'édition des commentaires + règle « brouillon ».

    python3 tests/test_comments.py
"""
import csv
import io
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from comments import displayable_comment, export_csv, import_csv  # noqa: E402


def _sample_course():
    return {
        "id": "t",
        "rootFEN": "K0",
        "positions": {
            "K0": {"fen": "K0", "moves": [{"san": "e4", "uci": "e2e4", "toFEN": "K1", "role": "mainLine"}]},
            "K1": {"fen": "K1", "moves": [{"san": "d5", "uci": "d7d5", "toFEN": "K2", "role": "mainLine"}]},
            "K2": {"fen": "K2", "moves": []},
        },
    }


def test_roundtrip_and_draft_rule():
    course = _sample_course()
    rows = list(csv.DictReader(io.StringIO(export_csv(course))))
    assert len(rows) == 2  # deux arêtes

    for r in rows:
        if r["uci"] == "e2e4":
            r["comment"], r["status"] = "Contrôle le centre.", "validated"
        elif r["uci"] == "d7d5":
            r["comment"], r["status"] = "Contre-attaque immédiate.", ""  # pas de statut

    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
    stats = import_csv(course, out.getvalue())

    e4 = course["positions"]["K0"]["moves"][0]
    assert e4["comment"] == "Contrôle le centre."
    assert e4["commentStatus"] == "validated"
    assert displayable_comment(e4) == "Contrôle le centre."

    d5 = course["positions"]["K1"]["moves"][0]
    assert d5["comment"] == "Contre-attaque immédiate."
    assert d5["commentStatus"] == "draft"          # JAMAIS validé automatiquement
    assert displayable_comment(d5) is None          # un brouillon n'est pas affichable

    assert stats == {"updated": 2, "validated": 1, "drafts": 1, "unmatched": 0}


def test_empty_comment_clears_edge():
    course = _sample_course()
    course["positions"]["K0"]["moves"][0]["comment"] = "à retirer"
    course["positions"]["K0"]["moves"][0]["commentStatus"] = "draft"

    csv_text = "course_id,from_fen,uci,san,status,comment\nt,K0,e2e4,e4,,\n"
    import_csv(course, csv_text)
    edge = course["positions"]["K0"]["moves"][0]
    assert "comment" not in edge and "commentStatus" not in edge


if __name__ == "__main__":
    test_roundtrip_and_draft_rule()
    test_empty_comment_clears_edge()
    print("comments tests OK")
