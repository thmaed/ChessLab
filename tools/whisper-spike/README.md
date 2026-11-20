# Étude : coups à la voix avec Whisper (19/11/2026)

Question : un modèle embarqué (Whisper, MIT, rien ne sort de l'appareil) reconnaît-il mieux les coups que la
reconnaissance d'Apple d'avant iOS 26, qui rate la colonne e sur l'iPhone XS ?

    python3 -m venv .venv && .venv/bin/pip install torch transformers soundfile numpy
    HF_HUB_DISABLE_XET=1 .venv/bin/python -c "from huggingface_hub import snapshot_download as s; s('openai/whisper-base')"
    HF_HUB_OFFLINE=1 .venv/bin/python -u mesure.py <trials.jsonl> <dossier des .caf/.wav> <sortie.jsonl> tiny,base

Les essais : la mesure de l'iPhone (Réglages › Développement › Mesure de la dictée), récupérés par
`xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier com.chesslab.ChessLab
--source Documents/voice-lab`. La sortie se rejoue par le VRAI module (Kotlin) : la copier dans
`android/app/build/voice-replay/`, puis `VoiceMoveParserTest` écrit `app/build/voice-replay-report.txt`.

## Résultats du 19/11/2026 (51 essais d'iPhone3, une voix)

| | libre (module ChessLab) | CHOIX parmi les coups légaux |
| --- | --- | --- |
| Apple d'avant iOS 26 | 36-38/51 bruts | — |
| Apple iOS 26 | 42/51 bruts | — |
| Whisper tiny | 14/51 | 40/51 (e4 → a4 deux fois) |
| Whisper base | 33/51 | **48/51** ; écart ≥ 2 : 41 joués, 1 faux, 9 redemandés |

Le gain vient du CHOIX : on note chaque façon de dire chaque coup légal (log P(texte | son)) au lieu de transcrire.
Small : le calcul s'arrête sans message sur le Mac (mémoire ?) ; ~480 Mo, trop lourd pour un téléphone.

Pièges : `mps` (Metal) se bloque pour de bon dans waitUntilCompleted → processeur ; le téléchargement Xet de
Hugging Face se bloque → `HF_HUB_DISABLE_XET=1`, puis `HF_HUB_OFFLINE=1`.

## Sur le téléphone (20/11/2026) : CONCLUSION, Whisper mis de côté

`convertir.py` fait deux modèles Core ML (46 + 42 Mo, poids en demi-précision) : l'ÉCOUTE (log-mel gardé en
32 bits — en 16 bits, les sons faibles du XS tombaient à zéro — puis l'encodeur, qui rend les clés et valeurs de
l'attention croisée) et la NOTATION (le décodeur, par lots de 32 phrases de 16 jetons, la probabilité normalisée sur
le seul VOCABULAIRE des phrases d'échecs, ~100 jetons au lieu de 51 865 : sinon la demi-précision déborde, et c'est
400 fois moins de calcul). Le découpage en jetons tient dans `whisper-pretokens.json` (98 morceaux) : pas de
tokeniseur dans l'app. `verifier_coreml.py` rejoue les modèles convertis sur le Mac ; `variantes.py` compare
vocabulaire complet/réduit et nombre de graphies. Le code Swift de l'essai (`ios/`, retiré de l'app) chargeait les
modèles copiés dans Documents/whisper et les rejouait sur les essais enregistrés du labo.

21 essais de l'iPhone XS (A12, iOS 18.7), même voix :

| | justes | temps par coup |
| --- | --- | --- |
| Core ML sur le Mac | 20/21 | 0,14-0,16 s |
| XS, `.all` (moteur neuronal) | **0/21** : notes invalides ou absurdes | 4-8 s |
| XS, processeur seul | 18/21 | **1,5-6,4 s** (écoute 1,1 s, notes 0,4-5 s) |
| Apple « B » (classique + indices), mêmes essais | 18/21 | 0,3-1,2 s |

Le moteur neuronal de l'A12 fausse le calcul ; sur le processeur, Whisper est JUSTE mais n'apporte rien sur le XS
(autant de coups qu'Apple) pour un temps 3 à 5 fois plus long. Décision de l'utilisateur (20/11/2026) : Whisper
reste une étude, rien dans l'app ; on livre la reconnaissance d'Apple, améliorée le même jour (essai anticipé, fin
de phrase lissée, « petit rock », « au quatre »).

À rouvrir seulement si un téléphone visé n'a PAS de reconnaissance sur l'appareil (Android sans pack de langue,
par exemple) : alors le choix parmi les coups légaux reste la meilleure piste mesurée. Non essayés : la carte
graphique du XS (`-whisperUnits cpuAndGPU`), ONNX sur le Galaxy.
