#!/bin/zsh
# Envoie un jeu d'enregistrements synthétiques (tools/voix-synthese/generer.py) au Galaxy, lance le banc
# (VoiceSynthBatchActivity, version de test), attend la fin, récupère out.jsonl, puis évalue avec le lecteur de coups.
# Usage : tools/voix-synthese/mesurer.sh <dossier généré> [numéro de série adb]
set -e
DIR="${1:?dossier généré par generer.py}"
SERIAL="${2:-192.168.68.66:5555}"
ADB="${ADB:-/opt/homebrew/share/android-commandlinetools/platform-tools/adb}"
PKG=com.maeder.chesslab.debug
ROOT="${0:A:h:h:h}"
"$ADB" -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP
# Les fichiers entrent par run-as : le dossier de l'app n'est pas lisible autrement.
"$ADB" -s "$SERIAL" shell "run-as $PKG sh -c 'mkdir -p files/synth && rm -f files/synth/out.jsonl files/synth/done'"
for f in index.jsonl bundle.bin; do
  "$ADB" -s "$SERIAL" shell "run-as $PKG sh -c 'cat > files/synth/$f'" < "$DIR/$f"
done
"$ADB" -s "$SERIAL" shell am start -S -n $PKG/com.chesslab.voicelab.VoiceSynthBatchActivity > /dev/null
echo "banc lancé ($(grep -c . "$DIR/index.jsonl") enregistrements)…"
until "$ADB" -s "$SERIAL" shell "run-as $PKG test -f files/synth/done" 2>/dev/null; do
  sleep 5
  printf "."
done
echo
"$ADB" -s "$SERIAL" exec-out run-as $PKG cat files/synth/out.jsonl > "$DIR/out.jsonl"
echo "$(grep -c . "$DIR/out.jsonl") résultats → $DIR/out.jsonl"
cd "$ROOT/android"
SYNTH_DIR="$DIR" JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}" \
  ./gradlew -q :app:testDebugUnitTest --tests 'com.chesslab.play.SynthEvalTest' --rerun-tasks > /dev/null || true
cat "$DIR/rapport.txt"
