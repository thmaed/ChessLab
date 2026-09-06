#!/bin/zsh
# ChessLab → App Store Connect, jusqu'au seuil de la soumission.
#
#   tools/asc/release.sh            archive, téléverse le build, remplit la fiche
#   tools/asc/release.sh --no-build fiche seulement (build déjà téléversé)
#
# À la fin, tout est en place dans App Store Connect ; il reste à relire et à
# cliquer « Soumettre pour révision ». Le script refuse de partir si `main`
# n'est pas poussé : le binaire est GPLv3, ses sources publiées doivent être
# celles du build.
set -euo pipefail
ROOT=${0:A:h:h:h}
cd "$ROOT"
PY=tools/asc/.venv/bin/python
set -a; source ~/.private_keys/asc.env; set +a

if [[ "${1:-}" != "--allow-unpushed" && "${2:-}" != "--allow-unpushed" ]]; then
  git fetch -q origin main
  if (( $(git log --oneline origin/main..HEAD | wc -l) > 0 )); then
    echo "main a des commits non poussés : pousser d'abord (obligation GPLv3), ou --allow-unpushed pour un essai." >&2
    exit 1
  fi
fi

VERSION=$($PY tools/asc/asc.py version | sed -E 's/version ([0-9.]+) .*/\1/')
BUILD=$(sed -nE 's/.*CURRENT_PROJECT_VERSION = ([0-9.]+);.*/\1/p' ChessLab.xcodeproj/project.pbxproj | sort -u | sort -n | tail -1)
echo "→ version $VERSION, build $BUILD"

if [[ "${1:-}" != "--no-build" ]]; then
  WORK=/tmp/claude-501/asc
  mkdir -p "$WORK"
  ARCHIVE="$WORK/ChessLab-$VERSION-$BUILD.xcarchive"
  rm -rf "$ARCHIVE" "$WORK/export"
  echo "→ archive"
  xcodebuild archive -project ChessLab.xcodeproj -scheme ChessLab -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates -quiet
  echo "→ export et téléversement"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist tools/asc/ExportOptions.plist \
    -exportPath "$WORK/export" \
    -authenticationKeyPath ~/.private_keys/AuthKey_$ASC_KEY_ID.p8 \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" -quiet
fi

echo "→ fiche"
$PY tools/asc/asc.py all
