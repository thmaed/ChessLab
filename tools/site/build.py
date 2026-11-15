#!/usr/bin/env python3
"""Génère le site (docs/) : une page d'accueil par langue, l'anglais par défaut.

    python3 tools/site/images.py     # une fois : les images, par langue
    python3 tools/site/build.py      # le HTML, sitemap.xml, robots.txt

  docs/index.html     → anglais (par défaut)        docs/fr/index.html → français
  docs/es|de|it/…     → espagnol, allemand, italien

Les sections « fonctionnalités » sont LUES dans AppStoreSubmission/METADATA.md (la description de chaque
langue) : le site et les fiches des stores disent la même chose, et un changement de fiche se répercute ici
en relançant ce script. Le reste du texte est dans contenu.py. Pas de JavaScript tiers, pas de police ni de
script distants : le site tient la même promesse que l'app (aucun pistage).
"""
import html
import json
import re
from pathlib import Path

from contenu import T, TAGLINE, CREDITS

RACINE = Path(__file__).resolve().parents[2]
DOCS = RACINE / "docs"
BASE = "https://thmaed.github.io/ChessLab/"
APPSTORE = "https://apps.apple.com/app/id6793097336"
GITHUB = "https://github.com/thmaed/ChessLab"
EMAIL = "thmaed@icloud.com"
ORDRE = ["en", "fr", "es", "de", "it"]

NOMS = ["01-seance", "02-coach", "03-puzzles-offre", "04-adversaires", "05-puzzles-ecran",
        "06-ouvertures", "07-lecteur", "08-puzzle-cote", "09-finales", "10-variantes"]
GALERIE = ["04-adversaires", "02-coach", "01-seance", "07-lecteur", "06-ouvertures", "09-finales",
           "03-puzzles-offre", "08-puzzle-cote", "05-puzzles-ecran", "10-variantes"]
# Les sept premières sections de la description, dans l'ordre de la fiche, et la capture qui les illustre.
FONCTIONS = ["04-adversaires", "02-coach", "01-seance", "06-ouvertures", "09-finales", "08-puzzle-cote", "10-variantes"]
SECTION_METADATA = {"fr": 107, "en": 172, "es": 232, "de": 292, "it": 352}
FIN_METADATA = {"fr": 172, "en": 232, "es": 292, "de": 352, "it": 412}

# Page racine (anglais) seulement : envoie le visiteur vers sa langue, SAUF s'il en a déjà choisi une au sélecteur
# (mémorisée dans le navigateur, sur l'appareil — rien ne part nulle part). La première langue prise en charge,
# dans l'ordre de préférence du navigateur, l'emporte ; si c'est l'anglais, on reste. Les moteurs de recherche
# n'exécutent pas ce script : ils indexent la racine, et les pages de langue via hreflang.
DETECTION = """<script>(function () {
  try {
    var L = ["fr", "es", "de", "it"], p = null;
    try { p = localStorage.getItem("chesslab-lang"); } catch (e) {}
    if (p) { if (L.indexOf(p) > -1) location.replace(p + "/" + location.hash); return; }
    var l = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || "en"];
    for (var i = 0; i < l.length; i++) {
      var c = String(l[i]).toLowerCase().slice(0, 2);
      if (c === "en") return;
      if (L.indexOf(c) > -1) { location.replace(c + "/" + location.hash); return; }
    }
  } catch (e) {}
})();</script>
"""

ICONES = {
    "plane": '<path d="M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z"/>',
    "lock": '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    "code": '<path d="m16 18 6-6-6-6M8 6l-6 6 6 6"/>',
}


def esc(s):
    return html.escape(s, quote=True)


def fonctions(lang):
    """Les sections de la description de la fiche : [(titre, texte)], lues dans METADATA.md."""
    lignes = (RACINE / "AppStoreSubmission/METADATA.md").read_text(encoding="utf-8").split("\n")
    section = "\n".join(lignes[SECTION_METADATA[lang]:FIN_METADATA[lang]])
    blocs = re.findall(r"```\n(.*?)\n```", section, re.S)
    paras = blocs[4].split("\n\n")
    assert len(paras) == 12, (lang, len(paras))
    sorties = []
    for p in paras[2:9]:
        titre, *corps = p.split("\n")
        assert titre == titre.upper(), (lang, titre)
        titre = titre[0] + titre[1:].lower()
        sorties.append((titre, " ".join(corps).strip()))
    return sorties


def chemin(depuis, vers):
    """Lien relatif d'une page de langue à une autre."""
    if depuis == vers:
        return "./"
    if depuis == "en":
        return f"{vers}/"
    return "../" if vers == "en" else f"../{vers}/"


def image(pre, lang, nom, alt, w, h, eager=False, cls=""):
    return (f'<img src="{pre}img/{lang}/{nom}.jpg" alt="{esc(alt)}" width="{w}" height="{h}" '
            f'{"fetchpriority=\"high\"" if eager else "loading=\"lazy\" decoding=\"async\""}'
            f'{f" class=\"{cls}\"" if cls else ""}>')


def page(lang):
    t = T[lang]
    pre = "" if lang == "en" else "../"
    url = BASE if lang == "en" else f"{BASE}{lang}/"
    feats = fonctions(lang)
    ia = lambda i: t["alt_shots"][i]
    alt = {n: ia(NOMS.index(n)) for n in NOMS}
    H = 1385

    langues = "".join(
        f'<li><a href="{chemin(lang, l)}" hreflang="{T[l]["html"]}" lang="{T[l]["html"]}"'
        f'{" aria-current=\"true\"" if l == lang else ""}>{esc(T[l]["name"])}</a></li>' for l in ORDRE)
    nav = "".join(f'<a href="#{k}">{esc(v)}</a>' for k, v in t["nav"].items())
    alternates = "".join(
        f'<link rel="alternate" hreflang="{T[l]["html"]}" href="{BASE if l == "en" else f"{BASE}{l}/"}">' for l in ORDRE)
    alternates += f'<link rel="alternate" hreflang="x-default" href="{BASE}">'

    def boutons(extra=""):
        return (f'<div class="stores{extra}">'
                f'<a class="store" href="{APPSTORE}"><span class="s1">{esc(t["appstore_small"])}</span><span class="s2">{esc(t["appstore"])}</span></a>'
                f'</div>')

    stats = "".join(f'<li><strong>{esc(n)}</strong><span>{esc(l)}</span></li>' for n, l in t["stats"])
    piliers = "".join(
        f'<li class="reveal"><svg viewBox="0 0 24 24" aria-hidden="true">{ICONES[i]}</svg><h3>{esc(ti)}</h3><p>{esc(tx)}</p></li>'
        for i, ti, tx in t["pillars"])
    qui = "".join(f'<li class="reveal"><h3>{esc(ti)}</h3><p>{esc(tx)}</p></li>' for ti, tx in t["who"])

    lignes = []
    for i, ((titre, texte), nom) in enumerate(zip(feats, FONCTIONS)):
        lignes.append(
            f'<article class="feature reveal{" alt" if i % 2 else ""}" id="f{i + 1}">'
            f'<div class="feature-text"><span class="num">{i + 1:02d}</span><h3>{esc(titre)}</h3><p>{esc(texte)}</p></div>'
            f'<div class="feature-shot">{image(pre, lang, nom, alt[nom], 640, H)}</div></article>')
    fonctions_html = "\n".join(lignes)

    galerie = "".join(f'<li>{image(pre, lang, n, alt[n], 640, H)}</li>' for n in GALERIE)

    appareils = [
        f'<article class="device reveal"><div class="device-media iphone">{image(pre, lang, "07-lecteur", alt["07-lecteur"], 640, H)}</div>'
        f'<h3>{esc(t["devices"][0][0])}</h3><p>{esc(t["devices"][0][1])}</p></article>',
        f'<article class="device reveal"><div class="device-media">{image(pre, lang, "ipad", t["alt_ipad"], 1000, 1333)}</div>'
        f'<h3>{esc(t["devices"][1][0])}</h3><p>{esc(t["devices"][1][1])}</p></article>',
        f'<article class="device reveal"><div class="device-media duo">{image(pre, lang, "duo-inner", t["alt_duo_inner"], 1300, 914)}'
        f'{image(pre, lang, "duo-outer", t["alt_duo_outer"], 560, 815)}</div>'
        f'<h3>{esc(t["devices"][2][0])}</h3><p>{esc(t["devices"][2][1])}</p></article>',
    ]

    credits = "".join(
        f'<tr><td><a href="{esc(u)}" rel="noopener">{esc(n)}</a></td><td>{esc(l)}</td></tr>' for n, l, u in CREDITS)
    credits += f'<tr><td><a href="{GITHUB}" rel="noopener">ChessLab</a></td><td>GPLv3</td></tr>'

    faq = "".join(f'<details class="reveal"><summary>{esc(q)}</summary><p>{esc(r)}</p></details>' for q, r in t["faq"])
    maker = "".join(f'<p>{esc(p)}</p>' for p in t["maker_text"])

    donnees = {
        "@context": "https://schema.org", "@type": "SoftwareApplication", "name": "ChessLab",
        "applicationCategory": "GameApplication", "operatingSystem": "iOS, iPadOS",
        "description": t["desc"], "inLanguage": ORDRE, "url": url,
        "image": f"{BASE}img/{lang}/partage.jpg",
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "EUR"},
        "downloadUrl": APPSTORE, "license": "https://www.gnu.org/licenses/gpl-3.0.html",
        "isAccessibleForFree": True,
    }

    detection = DETECTION if lang == "en" else ""
    return f"""<!doctype html>
<html lang="{t["html"]}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(t["title"])}</title>
<meta name="description" content="{esc(t["desc"])}">
<link rel="canonical" href="{url}">
{alternates}
<meta name="theme-color" content="#0d1512">
<meta property="og:type" content="website">
<meta property="og:site_name" content="ChessLab">
<meta property="og:locale" content="{t["og_locale"]}">
<meta property="og:url" content="{url}">
<meta property="og:title" content="{esc(t["og_title"])}">
<meta property="og:description" content="{esc(TAGLINE[lang])} {esc(t["sub"])}">
<meta property="og:image" content="{BASE}img/{lang}/partage.jpg">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<meta name="apple-itunes-app" content="app-id=6793097336">
<link rel="stylesheet" href="{pre}site.css">
<script type="application/ld+json">{json.dumps(donnees, ensure_ascii=False)}</script>
{detection}<script>document.documentElement.classList.add("js")</script>
</head>
<body id="top">
<a class="skip" href="#main">{esc(t["skip"])}</a>

<header class="bar">
<div class="bar-in">
<a class="logo" href="#top" aria-label="ChessLab">Chess<span>Lab</span></a>
<nav aria-label="Menu">{nav}</nav>
<details class="lang"><summary aria-label="{esc(t["switch"])}"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>{lang.upper()}</summary><ul>{langues}</ul></details>
</div>
</header>

<main id="main">

<section class="hero">
<div class="hero-in">
<div class="hero-text">
<p class="kicker">{esc(t["kicker"])}</p>
<h1>{esc(TAGLINE[lang])}</h1>
<p class="lead">{esc(t["sub"])}</p>
{boutons()}
<p class="platforms">{esc(t["platforms"])}</p>
</div>
<div class="hero-phones" aria-hidden="false">
{image(pre, lang, "02-coach", alt["02-coach"], 640, H, True, "p1")}
{image(pre, lang, "04-adversaires", alt["04-adversaires"], 640, H, True, "p2")}
{image(pre, lang, "01-seance", alt["01-seance"], 640, H, True, "p3")}
</div>
</div>
</section>

<section class="stats" aria-label="ChessLab"><ul>{stats}</ul></section>

<section class="promise" id="privacy">
<div class="wrap">
<p class="eyebrow">{esc(t["nav"]["privacy"])}</p>
<h2>{esc(t["promise_title"])}</h2>
<p class="intro">{esc(t["promise_lead"])}</p>
<ul class="pillars">{piliers}</ul>
<p class="more"><a href="{pre}{t["privacy_href"]}">{esc(t["privacy_link"])} →</a></p>
</div>
</section>

<section class="who">
<div class="wrap">
<h2>{esc(t["who_title"])}</h2>
<p class="intro">{esc(t["who_lead"])}</p>
<ul class="cards">{qui}</ul>
</div>
</section>

<section class="features" id="features">
<div class="wrap">
<p class="eyebrow">{esc(t["nav"]["features"])}</p>
<h2>{esc(t["features_title"])}</h2>
<p class="intro">{esc(t["features_lead"])}</p>
{fonctions_html}
</div>
</section>

<section class="screens" id="screens">
<div class="wrap">
<p class="eyebrow">{esc(t["nav"]["screens"])}</p>
<h2>{esc(t["shots_title"])}</h2>
<p class="intro">{esc(t["shots_lead"])}</p>
</div>
<ul class="strip" tabindex="0" aria-label="{esc(t["shots_title"])}">{galerie}</ul>
</section>

<section class="devices" id="devices">
<div class="wrap">
<p class="eyebrow">{esc(t["nav"]["devices"])}</p>
<h2>{esc(t["devices_title"])}</h2>
<p class="intro">{esc(t["devices_lead"])}</p>
<div class="family reveal">{image(pre, lang, "banniere", t["devices_title"], 1800, 771)}</div>
<div class="device-grid">
{"".join(appareils)}
</div>
</div>
</section>

<section class="maker">
<div class="wrap narrow">
<h2>{esc(t["maker_title"])}</h2>
{maker}
</div>
</section>

<section class="credits">
<div class="wrap narrow">
<h2>{esc(t["credits_title"])}</h2>
<p class="intro">{esc(t["credits_lead"])}</p>
<table class="reveal"><thead><tr><th>{esc(t["credits_cols"][0])}</th><th>{esc(t["credits_cols"][1])}</th></tr></thead><tbody>{credits}</tbody></table>
</div>
</section>

<section class="faq" id="faq">
<div class="wrap narrow">
<p class="eyebrow">{esc(t["nav"]["faq"])}</p>
<h2>{esc(t["faq_title"])}</h2>
{faq}
</div>
</section>

<section class="cta">
<div class="wrap narrow center">
<h2>{esc(t["cta_title"])}</h2>
<p class="intro">{esc(t["cta_text"])}</p>
{boutons(" center")}
</div>
</section>

</main>

<footer class="foot">
<div class="wrap">
<div class="foot-top">
<a class="logo" href="#top">Chess<span>Lab</span></a>
<ul>
<li><a href="{pre}{t["privacy_href"]}">{esc(t["foot_privacy"])}</a></li>
<li><a href="{pre}support.html">{esc(t["foot_support"])}</a></li>
<li><a href="{GITHUB}" rel="noopener">{esc(t["foot_source"])} — GPLv3</a></li>
<li><a href="mailto:{EMAIL}">{esc(t["foot_contact"])}</a></li>
</ul>
</div>
<p class="note">{esc(t["foot_note"])}</p>
<p class="note"><a href="#top">↑ {esc(t["back_top"])}</a></p>
</div>
</footer>

<script>
(function () {{
  var els = document.querySelectorAll(".reveal");
  if (!("IntersectionObserver" in window) || matchMedia("(prefers-reduced-motion: reduce)").matches) {{
    els.forEach(function (e) {{ e.classList.add("in"); }}); return;
  }}
  var io = new IntersectionObserver(function (es) {{
    es.forEach(function (e) {{ if (e.isIntersecting) {{ e.target.classList.add("in"); io.unobserve(e.target); }} }});
  }}, {{ rootMargin: "0px 0px -8% 0px" }});
  els.forEach(function (e) {{ io.observe(e); }});
  document.querySelectorAll(".lang a").forEach(function (a) {{
    a.addEventListener("click", function () {{
      try {{ localStorage.setItem("chesslab-lang", (a.getAttribute("lang") || "en").slice(0, 2)); }} catch (e) {{}}
    }});
  }});
  document.addEventListener("click", function (ev) {{
    var d = document.querySelector(".lang[open]");
    if (d && !d.contains(ev.target)) d.removeAttribute("open");
  }});
}})();
</script>
</body>
</html>
"""


def main():
    for lang in ORDRE:
        sortie = DOCS / ("index.html" if lang == "en" else f"{lang}/index.html")
        sortie.parent.mkdir(parents=True, exist_ok=True)
        sortie.write_text(page(lang), encoding="utf-8")
        print("  ", sortie.relative_to(RACINE), sortie.stat().st_size, "octets")
    urls = "".join(
        f'<url><loc>{BASE if l == "en" else f"{BASE}{l}/"}</loc>'
        + "".join(f'<xhtml:link rel="alternate" hreflang="{T[x]["html"]}" href="{BASE if x == "en" else f"{BASE}{x}/"}"/>' for x in ORDRE)
        + f'<xhtml:link rel="alternate" hreflang="x-default" href="{BASE}"/></url>' for l in ORDRE)
    urls += f'<url><loc>{BASE}privacy-policy.html</loc></url><url><loc>{BASE}support.html</loc></url>'
    (DOCS / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
        f'xmlns:xhtml="http://www.w3.org/1999/xhtml">{urls}</urlset>\n', encoding="utf-8")
    (DOCS / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {BASE}sitemap.xml\n", encoding="utf-8")


if __name__ == "__main__":
    main()
