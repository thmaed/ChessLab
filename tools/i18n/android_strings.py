#!/usr/bin/env python3
"""Génère android/app/src/main/res/values-{es,de,it}/strings_app.xml.

Principe : le texte français d'une chaîne Android est cherché dans le catalogue iOS
(clé = texte français) ; s'il y est, on reprend sa traduction (es, de, it…) (mêmes mots des
deux côtés — c'est la règle iOS fait foi). Le reste est lu dans un fichier
`android-extra*.json` {nom: {es, de, it}} (chaînes propres à Android, traduites à la main).

  android_strings.py report [langues]   → liste ce qui n'est pas couvert (défaut : es,de,it)
  android_strings.py write  [langues]   → écrit values-<langue> pour chaque langue (ex. : write it)
"""
import json, re, sys, os, xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
RES = f'{ROOT}/android/app/src/main/res'
CAT = json.load(open(f'{ROOT}/ChessLab/Localizable.xcstrings'))['strings']
import glob
EXTRA = {}
for _p in sorted(glob.glob(f'{ROOT}/tools/i18n/work/android-extra*.json')):
    for _k, _v in json.load(open(_p)).items():
        EXTRA.setdefault(_k, {}).update(_v)      # fusion PAR LANGUE : un fichier peut n'apporter que « it »

def unescape(t):
    t = t.replace('\\n', '\n').replace("\\'", "'").replace('\\"', '"').replace('\\@', '@').replace('\\?', '?')
    t = t.replace('\\\\', '\\')
    return re.sub(r'\\u([0-9a-fA-F]{4})', lambda m: chr(int(m.group(1), 16)), t)

def escape(t):
    wrap = (t != t.strip())          # espace en tête ou en queue : Android veut des guillemets
    t = t.replace('\\', '\\\\').replace("'", "\\'").replace('"', '\\"').replace('\n', '\\n')
    t = t.replace('&', '&amp;').replace('<', '&lt;')
    if t.startswith('@') or t.startswith('?'): t = '\\' + t
    return '"' + t + '"' if wrap else t

PH = re.compile(r'%(?:(\d+)\$)?(?:l{0,2})(@|d|s|f|\.\d+f|\.\df|i|%)')
def canon(t):
    """Texte avec les spécificateurs réduits à %S/%D (comparaison indépendante de la plateforme)."""
    def r(m):
        k = m.group(2)
        return '%%' if k == '%' else ('%D' if k in ('d', 'i') else '%S')
    return PH.sub(r, t)

LANGS = ['es', 'de', 'it']

def ios_index():
    """texte français canonique → {langue: traduction}, pour toutes les langues de LANGS ; les clés
    `stale` (noms de cours, libellés dynamiques) comptent en second rang : stale ≠ inutilisé."""
    idx = {}
    for stale in (False, True):
        for key, v in CAT.items():
            if (v.get('extractionState') == 'stale') != stale: continue
            loc = v.get('localizations', {})
            fr = loc.get('fr', {}).get('stringUnit', {}).get('value', key)
            tr = {l: loc.get(l, {}).get('stringUnit', {}).get('value') for l in LANGS}
            if all(tr.values()):
                idx.setdefault(canon(fr), (tr, fr))
                idx.setdefault(canon(key), (tr, key))
    return idx

def to_android(tr, android_fr):
    """Spécificateurs iOS → Android. Les positions sont celles du texte iOS (positionnelles si > 1)."""
    ph = list(PH.finditer(tr))
    multi = sum(1 for m in ph if m.group(2) != '%') > 1
    n = 0
    def r(m):
        nonlocal n
        k = m.group(2)
        if k == '%': return '%%'
        n += 1
        pos = m.group(1) or (str(n) if multi else None)
        conv = 'd' if (k == 'd' or 'l' in m.group(0)) else 's'
        # %lld → d ; %@ → s ; garder les décimales éventuelles
        return f'%{pos}${conv}' if pos else f'%{conv}'
    out = PH.sub(r, tr)
    # Un « % » isolé doit être doublé SI la chaîne Android est formatée (le français
    # de référence porte un %% ou un %s) ; sinon elle est lue telle quelle, sans format.
    if not re.search(r'%(?:\d+\$)?[sdf]|%%', android_fr):
        return out
    return re.sub(r'%%|%(?:\d+\$)?[sdf]|%', lambda m: m.group(0) if len(m.group(0)) > 1 else '%%', out)

def texts(path):
    tree = ET.parse(path)
    out = []
    for el in tree.getroot():
        if el.tag == 'string':
            out.append(('string', el.get('name'), ''.join(el.itertext()), el.attrib))
        elif el.tag == 'plurals':
            items = [(i.get('quantity'), ''.join(i.itertext())) for i in el]
            out.append(('plurals', el.get('name'), items, el.attrib))
        elif el.tag == 'string-array':
            items = [''.join(i.itertext()) for i in el]
            out.append(('array', el.get('name'), items, el.attrib))
    return out

def main():
    global LANGS
    mode = sys.argv[1]
    if len(sys.argv) > 2: LANGS = sys.argv[2].split(',')
    idx = ios_index()
    fr = texts(f'{RES}/values-fr/strings_app.xml')
    en = {n: t for k, n, t, a in texts(f'{RES}/values/strings_app.xml') if k == 'string'}
    missing, out = [], {l: [] for l in LANGS}
    def lookup(name, frtxt, which):
        u = unescape(frtxt)
        hit = idx.get(canon(u))
        if hit: return to_android(hit[0][which], frtxt)
        ex = EXTRA.get(name, {}).get(which)
        if ex: return ex
        return None
    for kind, name, val, attrs in fr:
        if kind == 'string':
            row = {}
            for lang in LANGS:
                t = lookup(name, val, lang)
                if t is None: missing.append((name, unescape(val), en.get(name))); break
                row[lang] = t
            else:
                for lang in LANGS: out[lang].append(('string', name, row[lang], attrs))
        elif kind == 'plurals':
            rows = {l: [] for l in LANGS}; ok = True
            for q, t in val:
                for lang in LANGS:
                    tr = lookup(f'{name}#{q}', t, lang)
                    if tr is None: missing.append((f'{name}#{q}', unescape(t), None)); ok = False; break
                    rows[lang].append((q, tr))
            if ok:
                for lang in LANGS: out[lang].append(('plurals', name, rows[lang], attrs))
        else:
            missing.append((name, f'<array {val}>', None))
    if mode == 'report':
        seen = set()
        for n, f, e in missing:
            print(n, '|', f.replace('\n', '\\n')[:150], '|', (e or '')[:80].replace('\n', '\\n'))
        print(len(missing), 'non couverts sur', len(fr))
        return
    if missing:
        print('NON COUVERT, rien écrit :', len(missing)); sys.exit(1)
    for lang in LANGS:
        os.makedirs(f'{RES}/values-{lang}', exist_ok=True)
        label = {'es': 'espagnol', 'de': 'allemand', 'it': 'italien'}[lang]
        lines = ['<?xml version="1.0" encoding="utf-8"?>',
                 f'<!-- Les textes de l\'app, en {label}. Généré par tools/i18n/android_strings.py depuis le catalogue iOS (iOS fait foi) + android-extra.json. -->',
                 '<resources>']
        for kind, name, val, attrs in out[lang]:
            extra = ''.join(f' {k}="{v}"' for k, v in attrs.items() if k != 'name')
            if kind == 'string':
                lines.append(f'    <string name="{name}"{extra}>{escape(val)}</string>')
            else:
                lines.append(f'    <plurals name="{name}"{extra}>')
                qs = dict(val)
                order = [q for q, _ in val]
                if lang in ('es', 'it') and 'many' not in qs and 'other' in qs:
                    val = list(val) + [('many', qs['other'])]
                for q, t in val:
                    lines.append(f'        <item quantity="{q}">{escape(t)}</item>')
                lines.append('    </plurals>')
        lines.append('</resources>')
        open(f'{RES}/values-{lang}/strings_app.xml', 'w').write('\n'.join(lines) + '\n')
        print(lang, len(out[lang]), 'éléments')

main()
