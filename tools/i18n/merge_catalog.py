#!/usr/bin/env python3
"""Fusionne les traductions (es, de, it…) d'un dossier de travail dans un .xcstrings.

  merge_catalog.py CATALOGUE.xcstrings TRAVAIL_DIR [--dry] [--langs it]

Lit TRAVAIL_DIR/index.json (id → clé) et tous les tr-*.json. REFUSE (liste les
erreurs, n'écrit rien) si pour une entrée :
 - les spécificateurs de format (%@, %lld, %1$@, %d, %%) ne sont pas les MÊMES
   (multiensemble) que dans la source française ;
 - le nombre de retours à la ligne diffère ;
 - la traduction est vide, ou identique à la source alors que la source contient
   plus de 3 lettres consécutives… (signalé en AVERTISSEMENT seulement).
"""
import json, sys, os, re, glob, collections

FMT = re.compile(r'%(?:\d+\$)?(?:l{0,2}|h{0,2}|z|q)?[@dDiuUxXoOfeEgGcCsSp]|%%')
def fmts(s): return collections.Counter(re.sub(r'%\d+\$', '%', f) for f in FMT.findall(s))

def main():
    cat, work = sys.argv[1], sys.argv[2]
    dry = '--dry' in sys.argv
    langs = sys.argv[sys.argv.index('--langs') + 1].split(',') if '--langs' in sys.argv else ['es', 'de']
    d = json.load(open(cat))
    index = {int(k): v for k, v in json.load(open(f'{work}/index.json')).items()}
    errors, warns, applied = [], [], 0
    longs = []
    updates = {}
    for f in sorted(glob.glob(f'{work}/tr-*.json')):
        for row in json.load(open(f)):
            key = index[row['id']]
            v = d['strings'][key]
            loc = v.get('localizations', {})
            fr = loc.get('fr', {}).get('stringUnit', {}).get('value', key)
            for lang in langs:
                t = row.get(lang)
                if t is None:
                    continue
                if not t.strip():
                    errors.append((key, lang, 'vide')); continue
                if fmts(t) != fmts(fr):
                    errors.append((key, lang, f'format {dict(fmts(fr))} ≠ {dict(fmts(t))}: {t}')); continue
                if t.count('\n') != fr.count('\n'):
                    errors.append((key, lang, 'retours à la ligne')); continue
                if t == fr and re.search(r'[a-zA-ZÀ-ÿ]{4,}', fr):
                    warns.append((key, lang, 'identique au français'))
                en = loc.get('en', {}).get('stringUnit', {}).get('value', '')
                ref = max(len(fr), len(en))
                # Étiquettes courtes (boutons, puces, titres) : l'allemand est le
                # plus long ; au-delà de +30 % (+4 car.) le texte risque de couper.
                if ref <= 40 and len(t) > ref * (1.25 if lang == 'it' else 1.3) + 4:
                    longs.append((lang, ref, len(t), fr, t))
                updates.setdefault(key, {})[lang] = t
    for k, lang, msg in errors: print('ERREUR', lang, repr(k)[:70], msg[:160])
    for k, lang, msg in warns[:40]: print('avert.', lang, repr(k)[:70], msg)
    for lang, ref, n, fr, t in longs: print('LONG ', lang, f'{ref}->{n}', repr(fr), '=>', repr(t))
    if errors:
        print(len(errors), 'erreurs : rien écrit'); sys.exit(1)
    for key, langs in updates.items():
        loc = d['strings'][key].setdefault('localizations', {})
        for lang, t in langs.items():
            loc[lang] = {'stringUnit': {'state': 'translated', 'value': t}}
            applied += 1
    if not dry:
        with open(cat, 'w') as fh:
            json.dump(d, fh, ensure_ascii=False, indent=2, separators=(',', ': '))
            fh.write('\n')
    print(applied, 'traductions', '(simulation)' if dry else 'écrites', len(warns), 'avertissements')

main()
