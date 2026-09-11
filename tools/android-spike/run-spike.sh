#!/bin/bash
# Construit le spike, démarre l'émulateur si besoin, installe et lance l'app.
#   ./run-spike.sh          — build + émulateur + install + lancement
#   ./run-spike.sh build    — build seulement
set -euo pipefail

export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@21}
export ANDROID_HOME=${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

cd "$(dirname "$0")"
AVD=chesslab-spike

./gradlew --no-daemon assembleDebug
APK=app/build/outputs/apk/debug/app-debug.apk
echo "APK : $(du -h "$APK" | cut -f1)"
[ "${1:-}" = "build" ] && exit 0

if ! adb devices | grep -q emulator; then
    echo "Démarrage de l'émulateur $AVD…"
    emulator -avd "$AVD" -no-snapshot -no-boot-anim >/dev/null 2>&1 &
    adb wait-for-device
    until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
fi

adb install -r "$APK"
adb shell am start -n com.chesslab.spike/.MainActivity
echo "Lancé. Trace : adb logcat -s chesslab"
