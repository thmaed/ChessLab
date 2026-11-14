#!/usr/bin/env python3
"""Exporte les textes localisés (fr/en) des cours en lots de travail.

  export_courses.py RESOURCES_OPENINGS_DIR SORTIE_DIR [--chars 22000] [--langs it]

Clé de dédoublonnage : le texte ANGLAIS (on traduit depuis l'anglais, dont la
notation des coups est la notation standard). Écrit SORTIE_DIR/src-NN.json
[{id, en}] et index.json (id → texte anglais). Ne propose que les textes qui n'ont
pas encore à la fois es et de.
"""
import json, sys, glob, os

def walk(o, fn):
    if isinstance(o, dict):
        if 'en' in o and isinstance(o.get('en'), str) and ('fr' in o or 'es' in o):
            fn(o); return
        for v in o.values(): walk(v, fn)
    elif isinstance(o, list):
        for v in o: walk(v, fn)

def main():
    src, out = sys.argv[1], sys.argv[2]
    limit = int(sys.argv[sys.argv.index('--chars') + 1]) if '--chars' in sys.argv else 22000
    langs = sys.argv[sys.argv.index('--langs') + 1].split(',') if '--langs' in sys.argv else ['es', 'de']
    seen, order = {}, []
    for f in sorted(glob.glob(f'{src}/*.json')):
        def visit(o, f=f):
            if all(o.get(l) for l in langs): return
            en = o['en']
            if en not in seen:
                seen[en] = len(order); order.append((en, os.path.basename(f)))
        walk(json.load(open(f)), visit)
    os.makedirs(out, exist_ok=True)
    index = {i: en for i, (en, _) in enumerate(order)}
    json.dump(index, open(f'{out}/index.json', 'w'), ensure_ascii=False)
    batch, size, n = [], 0, 0
    def flush():
        nonlocal batch, size, n
        if not batch: return
        with open(f'{out}/src-{n:02d}.json', 'w') as fh:
            fh.write('[\n' + ',\n'.join(json.dumps(r, ensure_ascii=False) for r in batch) + '\n]\n')
        n += 1; batch, size = [], 0
    for i, (en, fname) in enumerate(order):
        batch.append({'id': i, 'en': en, 'c': fname[:-5]}); size += len(en) + 40
        if size >= limit: flush()
    flush()
    print(len(order), 'textes uniques,', n, 'lots')

main()
