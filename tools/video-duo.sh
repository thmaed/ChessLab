#!/bin/zsh
# Enregistre le parcours d'un aperçu iPhone Duo : l'app se rouvre sur chaque écran (`-openRoute`, Debug) pendant
# que `simctl` filme l'écran voulu. Écrit la prise brute et un fichier .marques (écran, seconde de lancement,
# attente) pour découper les fenêtres stables avec tools/appstore-preview/make_preview.swift.
# Usage : tools/video-duo.sh <udid> <uuid de l'écran> <fr|en> <prise.mov>
set -eu
UDID=$1 DISPLAY_ID=$2 LANG_=$3 OUT=$4
BUNDLE=com.chesslab.ChessLab
LOCALE=$([[ $LANG_ == fr ]] && echo fr_FR || echo en_US)
: > "$OUT.marques"
xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
xcrun simctl io "$UDID" recordVideo --codec=h264 --force --display "$DISPLAY_ID" "$OUT" >/dev/null 2>&1 &
REC=$!
sleep 3
T0=$(python3 -c 'import time;print(time.time())')
scene() { # nom route attente [args...]
  local name=$1 route=$2 wait=$3; shift 3
  local -a launch=(-resetPlaySettings -discoveryTourSeen -AppleLanguages "($LANG_)" -AppleLocale $LOCALE)
  [[ -n $route ]] && launch+=(-openRoute $route)
  xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" $BUNDLE "${launch[@]}" "$@" >/dev/null
  python3 -c "import time;print('$name', round(time.time()-$T0,2), $wait)" >> "$OUT.marques"
  sleep "$wait"
}
scene seance        ""             7
scene coach         analysisCoach  11 -analysisPly 10
scene offre         puzzleOffer    7  puzzleOffer
scene ouvertures    openings       7
scene lecteur       endgameReader  7
scene puzzle        puzzleSession  7
scene variantes     variants       7
kill -INT $REC 2>/dev/null || true
wait $REC 2>/dev/null || true
echo "prise : $OUT"; cat "$OUT.marques"
