"""Convertit les pièces vectorielles de l'app iOS en VectorDrawable Android.

    python3 tools/svg-to-vector/convert_pieces.py [jeu]     # défaut : piece (cburnett)

Source : ChessLab/Assets.xcassets/Pieces/<jeu>_<code>.imageset/*.svg
Sortie : android/app/src/main/res/drawable/<jeu>_<code>.xml

Pourquoi un convertisseur maison plutôt qu'Android Studio : le projet se
construit en ligne de commande, et la conversion doit être REJOUABLE — le jour
où le jeu de pièces change côté iOS, une commande suffit.

Ce que le convertisseur gère, parce que c'est ce que les fichiers contiennent :
styles hérités de <g>, `translate`, `matrix` de rotation, <circle>, et les
attributs de trait. Il refuse bruyamment tout le reste plutôt que de produire
une pièce silencieusement fausse.
"""
import math, pathlib, re, sys, xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
SET = sys.argv[1] if len(sys.argv) > 1 else "piece"
SRC = ROOT / "ChessLab/Assets.xcassets/Pieces"
DST = ROOT / "android/app/src/main/res/drawable"
SVG_NS = "{http://www.w3.org/2000/svg}"

# Les licences des trois jeux, reprises de ChessLab/Board/PieceSet.swift.
# Elles doivent voyager avec les fichiers : ce sont des œuvres tierces.
CREDITS = {
    "piece": "Jeu cburnett de Colin M.L. Burnett, CC BY-SA 3.0.",
    "chessnut": "Jeu chessnut (Lichess), Apache 2.0.",
    "merida": "Jeu merida (Lichess), GPLv2 ou ultérieure.",
}


def parse_style(text):
    out = {}
    for part in (text or "").split(";"):
        if ":" in part:
            k, v = part.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def colour(value):
    """#fff -> #ffffff ; none -> None."""
    if not value or value == "none":
        return None
    v = value.strip()
    if re.fullmatch(r"#[0-9a-fA-F]{3}", v):
        return "#" + "".join(c * 2 for c in v[1:])
    if re.fullmatch(r"#[0-9a-fA-F]{6}", v):
        return v.lower()
    if v == "black":
        return "#000000"
    if v == "white":
        return "#ffffff"
    raise SystemExit(f"couleur non gérée : {value!r}")


def circle_path(cx, cy, r):
    """Un cercle en deux arcs — la syntaxe qu'accepte VectorDrawable."""
    return ellipse_path(cx, cy, r, r)


def ellipse_path(cx, cy, rx, ry):
    """Une ellipse, même principe : deux demi-arcs qui se referment."""
    return (f"M{cx - rx},{cy} a{rx},{ry} 0 1,0 {2 * rx},0 "
            f"a{rx},{ry} 0 1,0 {-2 * rx},0 z")


def collect_gradients(root):
    """Les <linearGradient> du fichier, indexés par identifiant.

    VectorDrawable sait faire un dégradé linéaire, mais dans une balise
    imbriquée (`aapt:attr`) et non dans un attribut : il faut donc les
    ramasser en amont pour les recracher au bon endroit.
    """
    out = {}
    for node in root.iter():
        if node.tag.replace(SVG_NS, "") != "linearGradient":
            continue
        # `gradientTransform` : on la replie dans les extrémités plutôt que
        # de la porter. Exact tant qu'elle est diagonale — échelle et
        # translation, ce qui est le cas du seul fichier concerné
        # (merida_wP : matrix(1 0 0 .97324 0 1.243)).
        a = d = 1.0
        e = f = 0.0
        gt = node.get("gradientTransform")
        if gt:
            m = re.fullmatch(r"matrix\(([-\d.,\s]+)\)", gt.strip())
            if not m:
                raise SystemExit(f"gradientTransform non géré : {gt}")
            a, b, c, d, e, f = [float(x) for x in re.split(r"[ ,]+", m.group(1).strip())]
            if abs(b) > 1e-9 or abs(c) > 1e-9:
                raise SystemExit(f"gradientTransform non diagonale : {gt}")
        stops = []
        for stop in node:
            style = parse_style(stop.get("style"))
            col = colour(stop.get("stop-color") or style.get("stop-color") or "#000")
            op = stop.get("stop-opacity") or style.get("stop-opacity")
            if op is not None and float(op) < 1:
                col = "#%02x%s" % (round(float(op) * 255), col[1:])
            stops.append((stop.get("offset", "0"), col))
        def px(v): return f"{a * float(v) + e:g}"
        def py(v): return f"{d * float(v) + f:g}"
        out[node.get("id")] = {
            "x1": px(node.get("x1", "0")), "y1": py(node.get("y1", "0")),
            "x2": px(node.get("x2", "0")), "y2": py(node.get("y2", "0")),
            "stops": stops,
        }
    return out


def group_attrs(transform):
    """Traduit un transform SVG en attributs de <group>.

    VectorDrawable applique translate ∘ rotate ∘ scale ; `matrix(a,b,c,d,e,f)`
    n'est donc acceptée que si elle EST une rotation suivie d'une translation,
    ce qui est le cas des deux seules présentes (les naseaux des cavaliers).
    """
    if not transform:
        return {}
    m = re.fullmatch(r"translate\(([-\d.]+)[ ,]+([-\d.]+)\)", transform.strip())
    if m:
        return {"android:translateX": m.group(1), "android:translateY": m.group(2)}
    m = re.fullmatch(r"matrix\(([-\d.,\s]+)\)", transform.strip())
    if m:
        a, b, c, d, e, f = [float(x) for x in re.split(r"[ ,]+", m.group(1).strip())]
        if abs(a - d) > 1e-6 or abs(b + c) > 1e-6:
            raise SystemExit(f"matrice non décomposable en rotation : {transform}")
        scale = math.hypot(a, b)
        angle = math.degrees(math.atan2(b, a))
        attrs = {
            "android:translateX": f"{e:g}", "android:translateY": f"{f:g}",
            "android:rotation": f"{angle:g}", "android:pivotX": "0", "android:pivotY": "0",
        }
        if abs(scale - 1) > 1e-6:
            attrs["android:scaleX"] = f"{scale:g}"
            attrs["android:scaleY"] = f"{scale:g}"
        return attrs
    raise SystemExit(f"transform non géré : {transform}")


def gradient_block(gradient, indent):
    pad = " " * indent
    lines = [f'{pad}<aapt:attr name="android:fillColor">\n',
             f'{pad}    <gradient\n',
             f'{pad}        android:type="linear"\n',
             f'{pad}        android:startX="{gradient["x1"]}"\n',
             f'{pad}        android:startY="{gradient["y1"]}"\n',
             f'{pad}        android:endX="{gradient["x2"]}"\n',
             f'{pad}        android:endY="{gradient["y2"]}"\n',
             f'{pad}        >\n']
    for offset, col in gradient["stops"]:
        lines.append(f'{pad}        <item android:offset="{offset}" android:color="{col}" />\n')
    lines += [f'{pad}    </gradient>\n', f'{pad}</aapt:attr>\n']
    return "".join(lines)


def path_element(d, style, indent, gradients=None):
    raw_fill = style.get("fill") or ""
    gradient = None
    if raw_fill.startswith("url(#"):
        gradient = (gradients or {}).get(raw_fill[5:].rstrip(")"))
        if gradient is None:
            raise SystemExit(f"dégradé introuvable : {raw_fill}")
        style = dict(style)
        style.pop("fill")
    # PIÈGE : un <path> sans `fill` vaut NOIR en SVG (valeur initiale de la
    # propriété), alors qu'un VectorDrawable sans `fillColor` ne peint RIEN.
    # Sans ce repli, les pièces noires du jeu « chessnut » disparaissaient.
    # Avec un dégradé, la couleur est portée par une balise imbriquée : la
    # poser AUSSI en attribut fait échouer la compilation des ressources.
    fill = None if gradient is not None else (
        colour(style["fill"]) if "fill" in style else "#000000"
    )
    stroke = colour(style.get("stroke"))
    attrs = [f'android:pathData="{d}"']
    if fill:
        attrs.append(f'android:fillColor="{fill}"')
    if stroke:
        attrs.append(f'android:strokeColor="{stroke}"')
        attrs.append(f'android:strokeWidth="{style.get("stroke-width", "1")}"')
        if "stroke-linecap" in style:
            attrs.append(f'android:strokeLineCap="{style["stroke-linecap"]}"')
        if "stroke-linejoin" in style:
            attrs.append(f'android:strokeLineJoin="{style["stroke-linejoin"]}"')
        if "stroke-miterlimit" in style:
            attrs.append(f'android:strokeMiterLimit="{style["stroke-miterlimit"]}"')
    if style.get("fill-rule") == "evenodd":
        attrs.append('android:fillType="evenOdd"')
    pad = " " * indent
    head = pad + "<path\n" + "".join(f"{pad}    {a}\n" for a in attrs)
    if gradient is None:
        return head + pad + "    />\n"
    return head + pad + "    >\n" + gradient_block(gradient, indent + 4) + pad + "</path>\n"


def walk(node, style, indent, out, gradients=None):
    tag = node.tag.replace(SVG_NS, "")
    inherited = dict(style)
    inherited.update(parse_style(node.get("style")))
    for k in ("fill", "stroke", "stroke-width", "fill-rule", "stroke-linecap",
              "stroke-linejoin", "stroke-miterlimit"):
        if node.get(k) is not None:
            inherited[k] = node.get(k)

    transform = node.get("transform")
    attrs = group_attrs(transform)
    pad = " " * indent
    if attrs:
        out.append(pad + "<group\n" + "".join(f"{pad}    {k}=\"{v}\"\n" for k, v in attrs.items()) + pad + "    >\n")
        indent += 4

    if tag == "path":
        out.append(path_element(node.get("d").replace("\n", " ").strip(), inherited, indent, gradients))
    elif tag == "circle":
        d = circle_path(float(node.get("cx")), float(node.get("cy")), float(node.get("r")))
        out.append(path_element(d, inherited, indent, gradients))
    elif tag == "ellipse":
        d = ellipse_path(float(node.get("cx")), float(node.get("cy")),
                         float(node.get("rx")), float(node.get("ry")))
        out.append(path_element(d, inherited, indent, gradients))
    elif tag in ("linearGradient", "stop", "defs"):
        return          # ramassés en amont par collect_gradients
    elif tag not in ("svg", "g"):
        raise SystemExit(f"élément non géré : <{tag}>")

    for child in node:
        walk(child, inherited, indent, out, gradients)

    if attrs:
        indent -= 4
        out.append(" " * indent + "</group>\n")


def convert(svg_path, out_path):
    text = re.sub(r"<!DOCTYPE[^>]*>", "", svg_path.read_text())
    root = ET.fromstring(text)
    # La taille du SVG peut être exprimée en n'importe quelle unité (merida
    # est en millimètres) ; seule la valeur numérique nous intéresse, le dp
    # d'un VectorDrawable n'étant qu'une taille intrinsèque — c'est le
    # viewBox qui fixe le repère du dessin.
    def number(value, fallback):
        m = re.match(r"[\d.]+", (value or "").strip())
        return m.group(0) if m else fallback

    if root.get("viewBox"):
        _, _, vw, vh = re.split(r"[ ,]+", root.get("viewBox").strip())
    else:
        vw = number(root.get("width"), "45")
        vh = number(root.get("height"), "45")
    # Taille intrinsèque normalisée : une pièce est toujours dessinée à la
    # taille de sa case. La laisser à 800 dp (merida) ferait allouer des
    # rendus inutilement grands.
    width = height = "45"

    gradients = collect_gradients(root)
    body = []
    walk(root, {}, 4, body, gradients)

    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Généré par tools/svg-to-vector/convert_pieces.py — ne pas éditer à la main.\n'
        f'     Source : {svg_path.relative_to(ROOT)}\n'
        f'     {CREDITS.get(SET, SET)} -->\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    xmlns:aapt="http://schemas.android.com/aapt"\n'
        f'    android:width="{width}dp"\n'
        f'    android:height="{height}dp"\n'
        f'    android:viewportWidth="{vw}"\n'
        f'    android:viewportHeight="{vh}">\n'
        + "".join(body) +
        "</vector>\n"
    )
    out_path.write_text(xml)


def main():
    DST.mkdir(parents=True, exist_ok=True)
    sources = sorted(SRC.glob(f"{SET}_*.imageset/*.svg"))
    if not sources:
        raise SystemExit(f"aucun SVG pour le jeu « {SET} »")
    for svg in sources:
        code = svg.parent.name.replace(".imageset", "")      # piece_wK
        name = code.lower()                                   # piece_wk
        out = DST / f"{name}.xml"
        convert(svg, out)
        print(f"  {svg.parent.name:24s} -> res/drawable/{out.name}")
    print(f"{len(sources)} pièces converties")


main()
