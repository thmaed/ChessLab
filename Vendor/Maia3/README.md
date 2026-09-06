# Maia-3 (poids 5M) — provenance et licence

`ChessLab/Maia3_5M.mlpackage` est la conversion Core ML (fp16, batch 1) du
checkpoint `maia3-5m.pt` publié par le CSSLab de l'Université de Toronto :
https://huggingface.co/UofTCSSLab/Maia3-5M — code d'inférence :
https://github.com/CSSLab/maia3

Licence : **GNU Affero General Public License v3.0** (code et poids), texte
intégral dans `LICENSE`. Compatible avec la distribution de ChessLab sous GPLv3
(GPLv3 §13) ; l'app ne fournit aucun service réseau.

Le script de conversion et les mesures d'accord sont dans
`tools/maia3-spike/`. L'encodeur d'entrée et le décodeur de politique sont
réécrits en Swift dans `ChessLab/Maia/`, vérifiés contre des fixtures générées
par l'implémentation de référence.

Citation :

> Monroe, Eilender, Chalmers, Tang, Anderson. *Chessformer: A Unified
> Architecture for Chess Modeling.* ICLR 2026. https://arxiv.org/abs/2605.19091
