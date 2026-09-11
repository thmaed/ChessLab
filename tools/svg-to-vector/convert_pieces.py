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
    return (f"M{cx - r},{cy} a{r},{r} 0 1,0 {2 * r},0 a{r},{r} 0 1,0 {-2 * r},0 z")


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


def path_element(d, style, indent):
    fill = colour(style.get("fill"))
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
    return pad + "<path\n" + "".join(f"{pad}    {a}\n" for a in attrs) + pad + "    />\n"


def walk(node, style, indent, out):
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
        out.append(path_element(node.get("d").replace("\n", " ").strip(), inherited, indent))
    elif tag == "circle":
        d = circle_path(float(node.get("cx")), float(node.get("cy")), float(node.get("r")))
        out.append(path_element(d, inherited, indent))
    elif tag not in ("svg", "g"):
        raise SystemExit(f"élément non géré : <{tag}>")

    for child in node:
        walk(child, inherited, indent, out)

    if attrs:
        indent -= 4
        out.append(" " * indent + "</group>\n")


def convert(svg_path, out_path):
    text = re.sub(r"<!DOCTYPE[^>]*>", "", svg_path.read_text())
    root = ET.fromstring(text)
    width = root.get("width", "45").replace("px", "")
    height = root.get("height", "45").replace("px", "")
    if root.get("viewBox"):
        _, _, vw, vh = re.split(r"[ ,]+", root.get("viewBox").strip())
    else:
        vw, vh = width, height

    body = []
    walk(root, {}, 4, body)

    xml = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Généré par tools/svg-to-vector/convert_pieces.py — ne pas éditer à la main.\n'
        f'     Source : {svg_path.relative_to(ROOT)}\n'
        '     Jeu cburnett de Colin M.L. Burnett, CC BY-SA 3.0. -->\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
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
