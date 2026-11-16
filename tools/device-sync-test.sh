#!/bin/zsh
# Essai de la synchronisation iCloud sur DEUX VRAIS iPhone (voir ChessLabUITests/DeviceSyncUITests.swift).
#
#   tools/device-sync-test.sh build                       # une fois : app + tests pour appareil
#   tools/device-sync-test.sh <UDID> <étape> [nom-essai]  # une étape, sur un appareil
#
# Étapes, A = Blancs, B = Noirs, dans l'ordre :
#   test01_settings (A puis B) · test02_A_startGameAndPlayE4 · test03_B_seesGameAndPlaysE5 ·
#   test04_A_seesReply · test05_A_openBoardAndWaitForBanner ET test06_B_playRemoteMove EN MÊME TEMPS
#   (TEST_RUNNER_CHESSLAB_SYNC_MOVE=g1f3 TEST_RUNNER_CHESSLAB_SYNC_EXPECT=f3 par défaut : un coup de cavalier) ·
#   test07_A_resign · test08_B_seesFinishedGame
#
# Les appareils doivent être déverrouillés, sur le même compte Apple. Aucune étape ne remet l'app à zéro.
# Signature par la clé d'API (~/.private_keys/asc.env), comme tools/asc/release.sh.
set -e
DD=${DEVICE_SYNC_DD:-/tmp/chesslab-device-sync}
cd "$(dirname "$0")/.."

if [[ "$1" == "build" ]]; then
  set -a; source ~/.private_keys/asc.env; set +a
  xcodebuild build-for-testing -scheme ChessLab -configuration Debug -destination 'generic/platform=iOS' \
    -derivedDataPath "$DD" -allowProvisioningUpdates \
    -authenticationKeyPath ~/.private_keys/AuthKey_$ASC_KEY_ID.p8 \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" -quiet
  exit 0
fi

UDID=$1; STEP=$2; TAG=${3:-Essai}
XCTESTRUN=$(ls "$DD"/Build/Products/*.xctestrun | head -1)
RESULT="$DD/results/$STEP-$UDID-$(date +%H%M%S).xcresult"
TEST_RUNNER_CHESSLAB_DEVICE_SYNC=1 TEST_RUNNER_CHESSLAB_SYNC_TAG="$TAG" \
  xcodebuild test-without-building -xctestrun "$XCTESTRUN" -destination "id=$UDID" \
  -only-testing:"ChessLabUITests/DeviceSyncUITests/$STEP" -resultBundlePath "$RESULT" 2>&1 \
  | grep -E 'SYNC\||error:|Test Case .*(passed|failed)|TEST EXECUTE (SUCCEEDED|FAILED)|Testing failed|locked' || true
echo "résultat : $RESULT"
