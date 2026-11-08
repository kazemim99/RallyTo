#!/usr/bin/env bash
# Publishes the player app's builds on the production server, the way deploy/publish-landing.sh publishes the site:
# copied aside, checked by hash and file count, then swapped in, so a dropped connection changes nothing live.
#   web  rallyto-app/build/web     → /var/www/rallyto/app (app.rallyto.ir); the one it replaces stays as app.replaced-<time>
#   apk  rallyto-app/build/app/outputs/flutter-apk/app-release.apk → /var/www/rallyto/downloads/rallyto.apk
#        (rallyto.ir/download/rallyto.apk); the one it replaces stays beside it as rallyto-<time>.apk
# Build first (docs/DEPLOYMENT.md): flutter build web / flutter build apk, both with API_BASE_URL.
#   deploy/publish-app.sh web|apk|all
# With a VPN that does not reach the server: SSH_BIND=<this machine's address on the direct network> deploy/publish-app.sh …
set -euo pipefail
export MSYS_NO_PATHCONV=1

SERVER="root@45.144.17.225"
SITE=/var/www/rallyto
STAMP=$(date +%Y%m%d-%H%M%S)
OPTS=(-o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15)
[ -n "${SSH_BIND:-}" ] && OPTS+=(-o "BindAddress=$SSH_BIND")
APP="$(cd "$(dirname "$0")/../rallyto-app" && pwd)"

publish_web() {
  # From the build folder, with relative names: Windows tar would read a C: path as a remote host.
  cd "$APP/build/web"
  [ -f index.html ] && [ -f main.dart.js ] || { echo "no web build; run flutter build web" >&2; exit 1; }
  local archive="../app-web-$STAMP.tar.gz"
  tar -czf "$archive" .
  local sum files
  sum=$(sha256sum "$archive" | cut -d' ' -f1)
  files=$(find . -type f | wc -l)
  echo "web build: $files files, $(wc -c < "$archive") bytes"
  scp -q -l 16000 "${OPTS[@]}" "$archive" "$SERVER:/root/app-web-$STAMP.tar.gz"
  rm -f "$archive"
  ssh "${OPTS[@]}" "$SERVER" "set -e
    A=/root/app-web-$STAMP.tar.gz
    [ \"\$(sha256sum \$A | cut -d' ' -f1)\" = $sum ] || { echo 'hash mismatch; app unchanged' >&2; exit 1; }
    NEW=$SITE/app.new-$STAMP
    mkdir \$NEW
    tar --no-same-owner -C \$NEW -xzf \$A
    chown -R root:root \$NEW
    chmod -R a+rX \$NEW
    [ \"\$(find \$NEW -type f | wc -l)\" = $files ] || { echo 'file count differs; app unchanged' >&2; exit 1; }
    [ ! -e $SITE/app ] || mv $SITE/app $SITE/app.replaced-$STAMP
    mv \$NEW $SITE/app
    rm -f \$A
    ls -d $SITE/app*"
}

publish_apk() {
  local apk="$APP/build/app/outputs/flutter-apk/app-release.apk"
  [ -f "$apk" ] || { echo "no release APK; run flutter build apk --release" >&2; exit 1; }
  local sum
  sum=$(sha256sum "$apk" | cut -d' ' -f1)
  echo "apk: $(wc -c < "$apk") bytes, sha256 $sum"
  ssh "${OPTS[@]}" "$SERVER" "mkdir -p $SITE/downloads"
  scp -q -l 16000 "${OPTS[@]}" "$apk" "$SERVER:$SITE/downloads/rallyto-new-$STAMP.apk"
  ssh "${OPTS[@]}" "$SERVER" "set -e
    D=$SITE/downloads
    [ \"\$(sha256sum \$D/rallyto-new-$STAMP.apk | cut -d' ' -f1)\" = $sum ] || { rm -f \$D/rallyto-new-$STAMP.apk; echo 'hash mismatch; download unchanged' >&2; exit 1; }
    chmod 644 \$D/rallyto-new-$STAMP.apk
    [ ! -e \$D/rallyto.apk ] || mv \$D/rallyto.apk \$D/rallyto-$STAMP.apk
    mv \$D/rallyto-new-$STAMP.apk \$D/rallyto.apk
    ls -la \$D"
}

case "${1:-}" in
  web) publish_web ;;
  apk) publish_apk ;;
  all) publish_web; publish_apk ;;
  *) echo "usage: deploy/publish-app.sh web|apk|all" >&2; exit 2 ;;
esac
