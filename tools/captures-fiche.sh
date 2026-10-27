#!/bin/zsh
# Captures de la fiche App Store (2.0) par `simctl` : l'app s'ouvre sur l'écran voulu (`-openRoute`, Debug),
# on attend, on photographie. Usage : tools/captures-fiche.sh <udid> <iphone|ipad|duo> <fr|en> <dossier de sortie>
# Le build Debug doit être installé sur le simulateur (voir CAPTURES dans AppStoreSubmission/README.md).
set -eu
UDID=$1 KIND=$2 LANG_=$3 OUT=$4
BUNDLE=com.chesslab.ChessLab
LOCALE=$([[ $LANG_ == fr ]] && echo fr_FR || echo en_US)
mkdir -p "$OUT"

shoot() { # nom route attente [args...]
  local name=$1 route=$2 wait=$3; shift 3
  [[ -n ${ONLY:-} && $name != *$ONLY* ]] && return 0   # ONLY=07 ne refait que la septième
  xcrun simctl terminate "$UDID" $BUNDLE >/dev/null 2>&1 || true
  local -a launch=(-resetPlaySettings -discoveryTourSeen -AppleLanguages "($LANG_)" -AppleLocale $LOCALE)
  [[ -n $route ]] && launch+=(-openRoute $route)   # un tableau : zsh ne découpe pas une variable non quotée
  xcrun simctl launch "$UDID" $BUNDLE "${launch[@]}" "$@" >/dev/null
  sleep "$wait"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null
  echo "  $name"
}

shoot 01-seance        ""             20
shoot 02-coach         analysisCoach  100 -analysisPly 10
shoot 03-puzzles-offre  puzzleOffer   6   puzzleOffer
shoot 04-adversaires   newGame        6
shoot 06-ouvertures    openings       6
shoot 07-lecteur       endgameReader  9
shoot 08-puzzle-cote   puzzleSession  8
shoot 09-finales       endgames       6
shoot 10-variantes     variants       6
