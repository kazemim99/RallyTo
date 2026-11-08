#!/usr/bin/env bash
# Publishes rallyto-landing/dist on the production server without a moment of empty site: the build is copied aside and
# checked by hash and file count, then swapped in. A dropped connection leaves the live site as it was. The site it
# replaces stays on the server as landing.replaced-<time>; nothing is deleted, so clearing old ones is a separate choice.
#   npm run build (in rallyto-landing), then: deploy/publish-landing.sh
# With a VPN that does not reach the server: SSH_BIND=<this machine's address on the direct network> deploy/publish-landing.sh
set -euo pipefail
export MSYS_NO_PATHCONV=1

SERVER="root@45.144.17.225"
SITE=/var/www/rallyto
STAMP=$(date +%Y%m%d-%H%M%S)
OPTS=(-o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15)
[ -n "${SSH_BIND:-}" ] && OPTS+=(-o "BindAddress=$SSH_BIND")

# From the build folder, with relative names: Windows tar would read a C: path as a remote host.
cd "$(dirname "$0")/../rallyto-landing/dist"
[ -f index.html ] || { echo "no build in dist; run npm run build" >&2; exit 1; }
ARCHIVE="../landing-$STAMP.tar.gz"
tar -czf "$ARCHIVE" .
trap 'rm -f "$ARCHIVE"' EXIT
SUM=$(sha256sum "$ARCHIVE" | cut -d' ' -f1)
FILES=$(find . -type f | wc -l)
echo "build: $FILES files, $(wc -c < "$ARCHIVE") bytes"

REMOTE_ARCHIVE="/root/landing-$STAMP.tar.gz"
scp -q -l 16000 "${OPTS[@]}" "$ARCHIVE" "$SERVER:$REMOTE_ARCHIVE"
ssh "${OPTS[@]}" "$SERVER" "set -e
  [ \"\$(sha256sum $REMOTE_ARCHIVE | cut -d' ' -f1)\" = $SUM ] || { echo 'hash mismatch; site unchanged' >&2; exit 1; }
  NEW=$SITE/landing.new-$STAMP
  mkdir \$NEW
  tar --no-same-owner -C \$NEW -xzf $REMOTE_ARCHIVE
  chown -R root:root \$NEW
  chmod -R a+rX \$NEW
  [ \"\$(find \$NEW -type f | wc -l)\" = $FILES ] || { echo 'file count differs; site unchanged' >&2; exit 1; }
  [ -f \$NEW/index.html ] || { echo 'no index.html; site unchanged' >&2; exit 1; }
  mv $SITE/landing $SITE/landing.replaced-$STAMP
  mv \$NEW $SITE/landing
  rm -f $REMOTE_ARCHIVE
  ls -d $SITE/landing*"
echo "published; the previous site is $SITE/landing.replaced-$STAMP"
