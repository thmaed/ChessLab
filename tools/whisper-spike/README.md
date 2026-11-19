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

Reste : vitesse sur l'iPhone XS (Core ML) et le Galaxy A16 (ONNX), taille, rejet des conversations (le choix
désigne toujours un coup), d'autres voix et d'autres micros.
