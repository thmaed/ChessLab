#!/bin/zsh
# Récupère les essais de la « Mesure dictée » du Galaxy (version de test com.maeder.chesslab.debug), les range dans
# les ressources de test Android et affiche le rapport : chaque reconnaissance rejouée par le lecteur de coups actuel,
# face aux chiffres de l'iPhone. Usage : tools/mesure-dictee-galaxy.sh [numéro de série adb]
set -e
SERIAL="${1:-RFGL329Z5EY}"
ADB="${ADB:-/opt/homebrew/share/android-commandlinetools/platform-tools/adb}"
ROOT="${0:A:h:h}"
OUT="$ROOT/android/app/src/test/resources/voice/trials-$(date +%Y-%m-%d)-galaxy.jsonl"
if ! "$ADB" -s "$SERIAL" shell run-as com.maeder.chesslab.debug test -s files/voice-lab/trials.jsonl; then
  echo "Aucun essai sur le téléphone $SERIAL (écran « Mesure dictée » de ChessLab test)."
  exit 1
fi
"$ADB" -s "$SERIAL" exec-out run-as com.maeder.chesslab.debug cat files/voice-lab/trials.jsonl > "$OUT"
echo "$(grep -c . "$OUT") essais → $OUT"
cd "$ROOT/android"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}" ./gradlew -q :app:testDebugUnitTest \
  --tests 'com.chesslab.play.VoiceMoveParserTest' --rerun-tasks > /dev/null
cat app/build/voice-lab-report.txt
