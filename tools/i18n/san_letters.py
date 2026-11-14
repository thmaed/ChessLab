"""Conversion des lettres de pièces dans un texte rédigé avec la notation ANGLAISE.

Le texte d'un cours est écrit dans la notation de sa langue (« Cf3 » en français,
« Nf3 » en anglais). On traduit en gardant la notation anglaise, puis on convertit
ici — de façon mécanique, donc sans faute de frappe possible sur les coups.
"""
import re

TABLES = {
    'es': {'K': 'R', 'Q': 'D', 'R': 'T', 'B': 'A', 'N': 'C'},
    'de': {'K': 'K', 'Q': 'D', 'R': 'T', 'B': 'L', 'N': 'S'},
    'it': {'K': 'R', 'Q': 'D', 'R': 'T', 'B': 'A', 'N': 'C'},   # Re Donna Torre Alfiere Cavallo
    'fr': {'K': 'R', 'Q': 'D', 'R': 'T', 'B': 'F', 'N': 'C'},
}

# Un coup SAN en notation anglaise : lettre de pièce, désambiguïsation éventuelle,
# x éventuel, case d'arrivée ; promotion éventuelle. Précédé et suivi d'un
# non-alphanumérique : « Bb5 » oui, « Black », « Rubinstein » non.
SAN = re.compile(r'(?<![A-Za-z0-9])([KQRBN])([a-h]?[1-8]?x?[a-h][1-8])(?![A-Za-z0-9])')
PROMO = re.compile(r'=([QRBN])(?![A-Za-z])')

def san_tokens(text):
    """Les coups (avec pièce) trouvés dans un texte en notation anglaise."""
    return [m.group(0) for m in SAN.finditer(text)] + [m.group(0) for m in PROMO.finditer(text)]

def convert(text, lang):
    t = TABLES[lang]
    text = SAN.sub(lambda m: t[m.group(1)] + m.group(2), text)
    return PROMO.sub(lambda m: '=' + t[m.group(1)], text)

if __name__ == '__main__':
    for s in ['Main — 3.dxe5 d4 4.Nf3', '4…Bg4 and Qxd5+, then Rad1 or N1d2=Q', 'Black plays Rubinstein: Bb5']:
        print(convert(s, 'es'), '|', convert(s, 'de'))
