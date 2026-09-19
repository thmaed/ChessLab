#!/usr/bin/env bash
#
# Les captures de TABLETTE pour la fiche Play, prises sur émulateur.
#
# Google réserve deux emplacements aux tablettes (7 et 10 pouces) et signale
# une app qui n'en a pas comme « conçue pour les téléphones ». Personne n'ayant
# de tablette Android sous la main, elles se prennent en émulateur — à la
# différence des captures de TÉLÉPHONE, prises sur un vrai Galaxy.
#
#   ./tools/captures-tablette.sh chesslab-tab10 en-US large-tablet-screenshots
#
# Le clavier de Gboard s'incruste dans l'image dès qu'un champ de saisie a eu
# le focus, et rien ne l'enlève proprement : le parcours ci-dessous ne touche
# donc AUCUN champ de texte.

set -uo pipefail

AVD="${1:?usage: $0 <avd> <langue> <dossier>}"
LANGUE="${2:?}"
DOSSIER="${3:?}"

RACINE="$(cd "$(dirname "$0")/.." && pwd)"
SDK=/opt/homebrew/share/android-commandlinetools
export PATH="$SDK/platform-tools:$SDK/emulator:$PATH"
export JAVA_HOME=/opt/homebrew/opt/openjdk@21

APK="$RACINE/android/app/build/outputs/apk/release/app-release.apk"
PAQUET=com.maeder.chesslab
SORTIE="$RACINE/android/app/src/main/play/listings/$LANGUE/graphics/$DOSSIER"
PORT=5560
SERIE="emulator-$PORT"

[ -f "$APK" ] || { echo "APK introuvable : $APK"; exit 1; }
mkdir -p "$SORTIE"

echo "▸ démarrage de $AVD"
emulator -avd "$AVD" -port $PORT -no-boot-anim -no-snapshot -gpu host \
         -netdelay none -netspeed full >/dev/null 2>&1 &
EMU=$!
trap 'adb -s "$SERIE" emu kill >/dev/null 2>&1; kill $EMU 2>/dev/null' EXIT

echo "▸ attente du démarrage"
adb -s "$SERIE" wait-for-device
for _ in $(seq 1 120); do
    [ "$(adb -s "$SERIE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
    sleep 2
done
sleep 5

echo "▸ installation"
adb -s "$SERIE" install -r "$APK" >/dev/null 2>&1 || { echo "installation refusée"; exit 1; }

# Le clavier virtuel, écarté avant même qu'il puisse s'inviter.
adb -s "$SERIE" shell settings put secure show_ime_with_hard_keyboard 0 >/dev/null 2>&1
adb -s "$SERIE" shell cmd locale set-app-locales "$PAQUET" --locales "${LANGUE%%-*}" >/dev/null 2>&1

echo "▸ lancement"
adb -s "$SERIE" shell am force-stop "$PAQUET"
adb -s "$SERIE" shell am start -n "$PAQUET/com.chesslab.MainActivity" >/dev/null 2>&1
sleep 12

# La visite guidée s'ouvre sur une installation neuve et couvre l'écran : on la
# passe en touchant « Terminer » autant de fois qu'elle a d'étapes.
echo "▸ visite guidée écartée"
for _ in $(seq 1 8); do
    adb -s "$SERIE" shell uiautomator dump /sdcard/e.xml >/dev/null 2>&1
    D=$(adb -s "$SERIE" shell cat /sdcard/e.xml 2>/dev/null)
    B=$(printf '%s' "$D" | grep -oE 'text="(Terminer|Suivant|Passer|Done|Next|Skip)"[^>]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | head -1)
    [ -z "$B" ] && break
    read x1 y1 x2 y2 <<< "$(printf '%s' "$B" | grep -oE '[0-9]+' | tail -4 | tr '\n' ' ')"
    adb -s "$SERIE" shell input tap $(( (x1+x2)/2 )) $(( (y1+y2)/2 ))
    sleep 2
done
adb -s "$SERIE" shell input keyevent KEYCODE_BACK >/dev/null 2>&1
sleep 2

prendre() {   # prendre <nom> <étiquette-de-tuile> <secondes-d-attente>
    local nom="$1" tuile="$2" pause="${3:-6}"
    adb -s "$SERIE" shell am force-stop "$PAQUET"
    adb -s "$SERIE" shell am start -n "$PAQUET/com.chesslab.MainActivity" >/dev/null 2>&1
    sleep 5
    if [ -n "$tuile" ]; then
        adb -s "$SERIE" shell uiautomator dump /sdcard/e.xml >/dev/null 2>&1
        B=$(adb -s "$SERIE" shell cat /sdcard/e.xml 2>/dev/null \
            | grep -oE "text=\"$tuile\"[^>]*bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"" | head -1)
        if [ -z "$B" ]; then echo "  ✗ tuile « $tuile » introuvable"; return 1; fi
        read x1 y1 x2 y2 <<< "$(printf '%s' "$B" | grep -oE '[0-9]+' | tail -4 | tr '\n' ' ')"
        adb -s "$SERIE" shell input tap $(( (x1+x2)/2 )) $(( (y1+y2)/2 ))
        sleep "$pause"
    fi
    adb -s "$SERIE" exec-out screencap -p > "$SORTIE/$nom.png"
    printf "  ✓ %-22s %s\n" "$nom.png" "$(sips -g pixelWidth -g pixelHeight "$SORTIE/$nom.png" 2>/dev/null | awk '/pixel/{printf "%s×", $2}' | sed 's/×$//')"
}

echo "▸ captures"
case "$LANGUE" in
  fr-FR)
    prendre 1-accueil    ""              0
    prendre 2-jouer      "Ordinateur"    14
    prendre 3-analyse    "Analyser"      10
    prendre 4-ouvertures "Ouvertures"    10
    prendre 5-puzzles    "Puzzles"       12
    prendre 6-finales    "Finales"       10
    ;;
  *)
    prendre 1-home       ""              0
    prendre 2-play       "Computer"      14
    prendre 3-analysis   "Analyse"       10
    prendre 4-openings   "Openings"      10
    prendre 5-puzzles    "Puzzles"       12
    prendre 6-endgames   "Endgames"      10
    ;;
esac

echo "▸ terminé — $SORTIE"
