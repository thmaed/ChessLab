"""Produit le catalogue ECO bilingue embarqué par l'app Android.

Source : `ChessLab/Resources/eco_openings.json`, la base que l'app iOS
embarque déjà — mêmes codes, mêmes lignes, mêmes noms. Elle n'a qu'un défaut
pour Android : ses noms sont EN FRANÇAIS seulement, alors que l'app Android
est bilingue et qu'un « Défense sicilienne » affiché en anglais serait une
faute visible.

Le script ajoute donc une colonne `name_en` à partir de la table ci-dessous
(les noms standard de l'Encyclopaedia of Chess Openings), et écrit le tout
dans les assets Android. Rejouable : le fichier produit est versionné, mais se
régénère à l'identique.

    python3 tools/android-eco/make_eco.py
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "ChessLab/Resources/eco_openings.json"
OUT = ROOT / "android/app/src/main/assets/eco_openings.json"

EN = {
    "Anglaise, anglo-indienne": "English, Anglo-Indian",
    "Anglaise, système symétrique": "English, Symmetrical",
    "Attaque Trompowsky": "Trompowsky Attack",
    "Attaque indienne du roi": "King's Indian Attack",
    "Caro-Kann, variante d'avance": "Caro-Kann, Advance",
    "Caro-Kann, variante d'échange": "Caro-Kann, Exchange",
    "Défense Alekhine": "Alekhine Defence",
    "Défense Benoni": "Benoni Defence",
    "Défense Caro-Kann": "Caro-Kann Defence",
    "Défense Grünfeld": "Grünfeld Defence",
    "Défense Nimzo-indienne": "Nimzo-Indian Defence",
    "Défense Petrov": "Petrov Defence",
    "Défense Philidor": "Philidor Defence",
    "Défense Pirc": "Pirc Defence",
    "Défense est-indienne": "King's Indian Defence",
    "Défense française": "French Defence",
    "Défense hollandaise": "Dutch Defence",
    "Défense indienne de la dame": "Queen's Indian Defence",
    "Défense moderne": "Modern Defence",
    "Défense scandinave": "Scandinavian Defence",
    "Défense sicilienne": "Sicilian Defence",
    "Défense slave": "Slav Defence",
    "Espagnole, défense Morphy": "Ruy Lopez, Morphy Defence",
    "Espagnole, défense berlinoise": "Ruy Lopez, Berlin Defence",
    "Espagnole, variante d'échange": "Ruy Lopez, Exchange",
    "Espagnole, variante fermée": "Ruy Lopez, Closed",
    "Est-indienne": "King's Indian",
    "Est-indienne, variante classique": "King's Indian, Classical",
    "Française, variante Rubinstein": "French, Rubinstein",
    "Française, variante Winawer": "French, Winawer",
    "Française, variante classique": "French, Classical",
    "Française, variante d'avance": "French, Advance",
    "Française, variante d'échange": "French, Exchange",
    "Gambit Benko": "Benko Gambit",
    "Gambit dame": "Queen's Gambit",
    "Gambit dame accepté": "Queen's Gambit Accepted",
    "Gambit dame refusé": "Queen's Gambit Declined",
    "Gambit dame refusé, défense Chigorine": "Queen's Gambit Declined, Chigorin Defence",
    "Gambit dame refusé, variante d'échange": "Queen's Gambit Declined, Exchange",
    "Gambit du roi": "King's Gambit",
    "Grünfeld, variante d'échange": "Grünfeld, Exchange",
    "Italienne, Giuoco Piano": "Italian, Giuoco Piano",
    "Italienne, défense des deux cavaliers": "Italian, Two Knights Defence",
    "Néo-indienne": "Neo-Indian",
    "Ouverture Réti": "Réti Opening",
    "Ouverture catalane": "Catalan Opening",
    "Ouverture du fou": "Bishop's Opening",
    "Partie anglaise": "English Opening",
    "Partie de pion dame": "Queen's Pawn Game",
    "Partie de pion roi": "King's Pawn Game",
    "Partie des quatre cavaliers": "Four Knights Game",
    "Partie des trois cavaliers": "Three Knights Game",
    "Partie espagnole": "Ruy Lopez",
    "Partie espagnole (Ruy Lopez)": "Ruy Lopez",
    "Partie italienne": "Italian Game",
    "Partie viennoise": "Vienna Game",
    "Partie écossaise": "Scotch Game",
    "Semi-slave": "Semi-Slav",
    "Sicilienne fermée": "Sicilian, Closed",
    "Sicilienne, Lasker-Pelikan": "Sicilian, Lasker-Pelikan",
    "Sicilienne, gambit Smith-Morra": "Sicilian, Smith-Morra Gambit",
    "Sicilienne, variante Alapine": "Sicilian, Alapin",
    "Sicilienne, variante Dragon": "Sicilian, Dragon",
    "Sicilienne, variante Najdorf": "Sicilian, Najdorf",
    "Sicilienne, variante Sveshnikov": "Sicilian, Sveshnikov",
    "Sicilienne, vieille sicilienne": "Sicilian, Old Sicilian",
    "Système Londres": "London System",
    "Écossaise, variante principale": "Scotch, Main Line",
}

entries = json.loads(SRC.read_text())
missing = sorted({e["name"] for e in entries} - EN.keys())
if missing:
    sys.exit("noms sans traduction anglaise : " + ", ".join(missing))

out = [{"eco": e["eco"], "name": e["name"], "name_en": EN[e["name"]], "moves": e["moves"]}
       for e in entries]
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n")
print(len(out), "ouvertures écrites dans", OUT.relative_to(ROOT))
