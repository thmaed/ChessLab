#!/usr/bin/env python3
"""Exporte un catalogue .xcstrings en lots de travail (JSON) pour la traduction.

  export_catalog.py CATALOGUE.xcstrings SORTIE_DIR [--size 120] [--langs it] [--stale]

Chaque lot : [{"id": n, "fr": clé française (ou valeur fr), "en": anglais}, ...].
Le traducteur écrit un fichier SORTIE_DIR/tr-NN.json : [{"id": n, "<langue>": ...}].
--langs : les langues visées (défaut es,de). Sont exclus : les clés `shouldTranslate: false`
et celles DÉJÀ traduites dans TOUTES les langues visées.
--stale : n'exporte QUE les clés `stale` (noms de cours, familles d'ouvertures, libellés
dynamiques : « stale » ne veut PAS dire inutilisé, ce sont des clés cherchées à l'exécution) ;
sans cette option, elles sont ignorées.
"""
import json, sys, os, re

def main():
    cat, out = sys.argv[1], sys.argv[2]
    size = int(sys.argv[sys.argv.index('--size') + 1]) if '--size' in sys.argv else 120
    langs = sys.argv[sys.argv.index('--langs') + 1].split(',') if '--langs' in sys.argv else ['es', 'de']
    stale = '--stale' in sys.argv
    d = json.load(open(cat))
    items = []
    for key, v in d['strings'].items():
        if v.get('shouldTranslate') is False or (v.get('extractionState') == 'stale') != stale:
            continue
        loc = v.get('localizations', {})
        if all(l in loc for l in langs):
            continue
        fr = loc.get('fr', {}).get('stringUnit', {}).get('value', key)
        en = loc.get('en', {}).get('stringUnit', {}).get('value', '')
        if not re.search(r'[A-Za-zÀ-ÿ]', re.sub(r'%(?:\d+\$)?(?:l{0,2})[@dDiuxXfsS]', '', fr)):
            continue  # pur symbole / format : identique dans toutes les langues
        items.append({'key': key, 'fr': fr, 'en': en})
    os.makedirs(out, exist_ok=True)
    index = {}
    for n in range(0, len(items), size):
        chunk = items[n:n + size]
        rows = [{'id': n + i, 'fr': it['fr'], 'en': it['en']} for i, it in enumerate(chunk)]
        for i, it in enumerate(chunk):
            index[n + i] = it['key']
        with open(f'{out}/src-{n // size:02d}.json', 'w') as fh:
            fh.write('[\n' + ',\n'.join(json.dumps(r, ensure_ascii=False) for r in rows) + '\n]\n')
    json.dump(index, open(f'{out}/index.json', 'w'), ensure_ascii=False)
    print(len(items), 'entrées,', (len(items) + size - 1) // size, 'lots')

main()
