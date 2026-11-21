#!/bin/zsh
# Pendant iOS de mesurer.sh : envoie les enregistrements synthétiques à un iPhone (version de test, DEBUG), lance le banc
# (argument -synthBench), attend la fin, récupère out.jsonl, évalue avec le lecteur de coups iOS (SynthEvalTests).
# L'iPhone doit être DÉVERROUILLÉ et ChessLab (debug) installé. Usage : tools/voix-synthese/mesurer-ios.sh <dossier> <UDID>
set -e
DIR="${1:?dossier généré par generer.py}"
UDID="${2:?UDID de l'iPhone (xcrun devicectl list devices)}"
ROOT="${0:A:h:h:h}"
BUNDLE=com.chesslab.ChessLab
dc() { xcrun devicectl device "$@"; }
dc copy to --device "$UDID" --domain-type appDataContainer --domain-identifier $BUNDLE --source "$DIR/index.jsonl" --destination Documents/synth/index.jsonl > /dev/null
dc copy to --device "$UDID" --domain-type appDataContainer --domain-identifier $BUNDLE --source "$DIR/wav" --destination Documents/synth/wav > /dev/null
dc process launch --terminate-existing --device "$UDID" $BUNDLE -- -synthBench > /dev/null
echo "banc lancé ($(grep -c . "$DIR/index.jsonl") enregistrements)…"
rm -f "$DIR/done-ios"
until dc copy from --device "$UDID" --domain-type appDataContainer --domain-identifier $BUNDLE --source Documents/synth/done --destination "$DIR/done-ios" > /dev/null 2>&1; do
  sleep 5; printf "."
done
echo
dc copy from --device "$UDID" --domain-type appDataContainer --domain-identifier $BUNDLE --source Documents/synth/out.jsonl --destination "$DIR/out-ios.jsonl" > /dev/null
echo "$(grep -c . "$DIR/out-ios.jsonl") résultats → $DIR/out-ios.jsonl"
cd "$ROOT"
TEST_RUNNER_SYNTH_DIR="$DIR" xcodebuild test -project ChessLab.xcodeproj -scheme ChessLab \
  -destination 'platform=iOS Simulator,id=55846B01-CE04-4C4C-A511-3E44B568C368' \
  -only-testing:ChessLabTests/SynthEvalTests > /dev/null 2>&1 || true
cat "$DIR/rapport-ios.txt"
