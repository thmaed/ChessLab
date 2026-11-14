#!/usr/bin/env python3
"""Fusionne les traductions es/de dans les cours (ChessLab/Resources/openings/*.json).

  merge_courses.py OPENINGS_DIR TRAVAIL_DIR [--dry] [--langs it]

Lit TRAVAIL_DIR/index.json (id → texte anglais) et tous les tr-*.json
([{id, es, de}], coups écrits en notation ANGLAISE). Contrôles bloquants :
 - mêmes cases (a1…h8) et mêmes coups SAN (avec pièce) que le texte anglais, en
   multiensemble — donc aucun coup altéré, perdu ou inventé ;
 - texte non vide.
Puis convertit les lettres de pièces (es : R D T A C ; de : K D T L S) et ajoute
les clés `es` et `de` juste après `en`. Avertit pour les étiquettes trop longues.
"""
import json, sys, glob, re, collections, os
sys.path.insert(0, os.path.dirname(__file__))
from san_letters import convert, san_tokens

SQ = re.compile(r'(?<![A-Za-z0-9])[a-h][1-8](?![A-Za-z0-9])')
def squares(t): return collections.Counter(SQ.findall(t))

LANGS = ['es', 'de']

def load(work):
    idx = {int(k): v for k, v in json.load(open(f'{work}/index.json')).items()}
    tr = {}
    for f in sorted(glob.glob(f'{work}/tr-*.json')):
        for r in json.load(open(f)): tr[idx[r['id']]] = (r['id'], {l: r[l] for l in LANGS})
    return idx, tr

def check(tr, errs, warns):
    for en, (i, texts) in tr.items():
        for lang, t in texts.items():
            if not t or not t.strip(): errs.append((i, lang, 'vide')); continue
            if collections.Counter(san_tokens(t)) != collections.Counter(san_tokens(en)):
                errs.append((i, lang, f'coups {san_tokens(en)} ≠ {san_tokens(t)} : {t[:90]}'))
            if squares(t) != squares(en):
                errs.append((i, lang, f'cases {dict(squares(en))} ≠ {dict(squares(t))} : {t[:90]}'))
            if len(en) <= 45 and len(t) > len(en) * 1.4 + 6:
                warns.append((i, lang, len(en), len(t), en, t))

def insert(o, tr):
    """Reconstruit le dict avec les nouvelles langues juste après la dernière langue déjà présente
    (ordre fr, en, es, de, it)."""
    if o.get('en') not in tr: return o
    add = {lang: convert(text, lang) for lang, text in tr[o['en']][1].items()}
    keys = list(o)
    last = max(i for i, k in enumerate(keys) if k in ('en', 'es', 'de', 'it'))
    new = {}
    for i, k in enumerate(keys):
        new[k] = o[k]
        if i == last:
            for lang, text in add.items():
                new[lang] = text          # écrase une valeur existante : la clé garde sa place
    return new

def walk(o, tr):
    if isinstance(o, dict):
        if 'en' in o and isinstance(o.get('en'), str) and ('fr' in o):
            return insert(o, tr)
        return {k: walk(v, tr) for k, v in o.items()}
    if isinstance(o, list): return [walk(v, tr) for v in o]
    return o

def main():
    global LANGS
    src, work = sys.argv[1], sys.argv[2]; dry = '--dry' in sys.argv
    if '--langs' in sys.argv: LANGS = sys.argv[sys.argv.index('--langs') + 1].split(',')
    idx, tr = load(work); errs, warns = [], []
    check(tr, errs, warns)
    for i, l, m in errs: print('ERREUR', i, l, m)
    for i, l, a, b, en, t in warns: print('LONG ', i, l, f'{a}->{b}', repr(en), '=>', repr(t))
    if errs: print(len(errs), 'erreurs : rien écrit'); sys.exit(1)
    changed = 0
    for f in sorted(glob.glob(f'{src}/*.json')):
        raw = open(f).read(); d = json.loads(raw)
        for sep in [(',', ':'), (', ', ': ')]:
            if json.dumps(d, ensure_ascii=False, separators=sep) in (raw, raw.rstrip('\n')): break
        else: print('format inconnu', f); sys.exit(1)
        tail = '\n' if raw.endswith('\n') else ''
        out = json.dumps(walk(d, tr), ensure_ascii=False, separators=sep) + tail
        if out != raw:
            changed += 1
            if not dry: open(f, 'w').write(out)
    print(len(tr), 'textes,', changed, 'fichiers', 'à modifier' if dry else 'modifiés')

main()
