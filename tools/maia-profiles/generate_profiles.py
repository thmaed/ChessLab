"""Génère la galerie des neuf personnages Maia, depuis la source Swift.

    python3 tools/maia-profiles/generate_profiles.py

Lit `ChessLab/Maia/OpponentProfile.swift` et écrit
`android/maia/src/main/java/com/chesslab/maia/OpponentGallery.kt`.

Pourquoi générer plutôt que recopier : ce sont des DONNÉES — neuf profils,
chacun avec une dizaine de poids de style et un tempérament. Les recopier à la
main garantit une divergence silencieuse le jour où un poids change côté iOS.
Ici, une commande suffit.
"""
import pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "ChessLab/Maia/OpponentProfile.swift"
DST = ROOT / "android/maia/src/main/java/com/chesslab/maia/OpponentGallery.kt"


def blocks(text):
    """Les corps des « static let X = OpponentProfile( … ) », parenthèses équilibrées."""
    for m in re.finditer(r"static let (\w+) = OpponentProfile\(", text):
        start = m.end() - 1
        depth = 0
        for i in range(start, len(text)):
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
                if depth == 0:
                    yield m.group(1), text[m.end():i]
                    break


def weights(swift):
    """« .check: 0.3, .capture: 0.15 » → « StyleTrait.check to 0.3, … »."""
    pairs = re.findall(r"\.(\w+):\s*(-?[\d.]+)", swift)
    return ", ".join(f"StyleTrait.{name} to {value}" for name, value in pairs)


def field(body, name):
    """La valeur brute d'un champ nommé, jusqu'à la virgule de même niveau."""
    m = re.search(rf"\b{name}:\s*", body)
    if not m:
        return None
    i = m.end()
    depth = 0
    in_string = False
    for j in range(i, len(body)):
        c = body[j]
        # Les virgules DANS une chaîne ne séparent rien : une accroche de
        # personnage en contient, et les ignorer tronquait le texte.
        if c == '"' and body[j - 1] != "\\":
            in_string = not in_string
        elif in_string:
            continue
        elif c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif c == "," and depth == 0:
            return body[i:j].strip()
    return body[i:].strip()


DOUBLE_ARGS = ("pace", "temperatureWhenWinning", "temperatureWhenLosing")


def kotlin_args(swift_args):
    """Convertit « a: 1, b: nil » en « a = 1, b = null », StyleTrait compris."""
    out = re.sub(r"\bnil\b", "null", swift_args)
    out = re.sub(r"\[(\s*\.\w+:[^\]]*)\]",
                 lambda m: "mapOf(" + weights(m.group(1)) + ")", out)
    out = re.sub(r"(\w+):\s*", r"\1 = ", out)
    out = re.sub(r"\s+", " ", out).strip().rstrip(",")
    for name in DOUBLE_ARGS:
        out = re.sub(rf"\b{name} = (-?\d+)(?![\d.])", lambda m: f"{name} = {m.group(1)}.0", out)
    return out


def dbl(value):
    """Kotlin ne promeut pas Int en Double : « 0 » doit s'écrire « 0.0 »."""
    v = (value or "0").strip()
    return v if ("." in v or v == "null") else v + ".0"


def convert(name, body):
    style = field(body, "style") or "StyleProfile(weights: [:], strength: 0)"
    style_weights = weights(style[style.index("["):style.rindex("]") + 1]) if "[" in style else ""
    strength = re.search(r"strength:\s*(-?[\d.]+)", style)
    temperament = field(body, "temperament") or "Temperament()"
    safety = field(body, "safetyNet") or "SafetyNetPolicy()"
    levels = field(body, "recommendedLevels").replace("...", "..")
    tags = field(body, "tags").replace("[", "listOf(").replace("]", ")")
    book = field(body, "bookID")

    return f'''    val {name} = OpponentProfile(
        id = {field(body, "id")},
        firstName = {field(body, "firstName")},
        nickname = {field(body, "nickname")},
        tagline = {field(body, "tagline")},
        tags = {tags},
        tint = OpponentTint.{field(body, "tint").lstrip(".")},
        temperature = {dbl(field(body, "temperature"))},
        topP = {dbl(field(body, "topP"))},
        recommendedLevels = {levels},
        safetyNet = {re.sub(r"^SafetyNetPolicy\((.*)\)$", lambda m: "SafetyNetPolicy(" + kotlin_args(m.group(1)) + ")", safety, flags=re.S)},
        style = StyleProfile(mapOf({style_weights}), strength = {dbl(strength.group(1) if strength else "0")}),
        temperament = {re.sub(r"^Temperament\((.*)\)$", lambda m: "Temperament(" + kotlin_args(m.group(1)) + ")", temperament, flags=re.S)},
        bookId = {"null" if book in (None, "nil") else book},
    )
'''


def main():
    text = SRC.read_text()
    found = list(blocks(text))
    if len(found) != 9:
        raise SystemExit(f"9 personnages attendus, {len(found)} trouvés")

    body = "\n".join(convert(name, block) for name, block in found)
    names = ", ".join(name for name, _ in found)

    DST.write_text(f'''package com.chesslab.maia

/**
 * Les neuf personnages, GÉNÉRÉS depuis `ChessLab/Maia/OpponentProfile.swift`
 * par `tools/maia-profiles/generate_profiles.py` — ne pas éditer à la main.
 *
 * Ce sont des données : neuf profils, une dizaine de poids de style chacun,
 * et un tempérament. Les recopier garantirait une divergence silencieuse le
 * jour où un poids change côté iOS.
 */
object OpponentGallery {{

{body}
    /** Dans l'ordre de la galerie iOS. */
    val all = listOf({names})

    fun byId(id: String): OpponentProfile? = all.firstOrNull {{ it.id == id }}
}}
''')
    print(f"{len(found)} personnages écrits dans {DST.relative_to(ROOT)}")


main()
