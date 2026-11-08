#!/usr/bin/env bash
# Moves the venue catalog and its photos from the local stack to the production server (docs/DEPLOYMENT.md).
# Only catalog.venues, venue_sports and venue_images travel: no accounts, matches or other data.
#   ./transfer.sh bundle   builds output/transfer/ from the local database and uploads folder
#   ./transfer.sh check    read-only: the server's containers, disk, migrations and catalog counts
#   ./transfer.sh load     backs up the server's database, loads the bundle, copies the photos
# The load refuses a non-empty catalog and rolls back on any mismatch (transfer_load.sql). Needs only postgres running:
# on a new database it first creates the catalog schema with its migration history, sports and cities (catalog_base.sql),
# so the API can start later and migrate the other contexts.
set -euo pipefail
export MSYS_NO_PATHCONV=1

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/output/transfer"
UPLOADS="$HERE/../../src/Host/Rallyto.Host/uploads"
SERVER="root@45.144.17.225"
DB="rallyto-postgres-1"

export_table() { # name, query
  docker exec "$DB" psql -U rallyto -d rallyto -v ON_ERROR_STOP=1 -c "\\copy ($2) to stdout csv header" > "$OUT/$1.csv"
}

bundle() {
  mkdir -p "$OUT"
  export_table venues "select id, name, normalized_name, city_id, address, phone, latitude, longitude, status, google_place_id, created_at, created_by, last_modified_at, last_modified_by, amenities, court_types, description, instagram, source_ref, source_url, tagline, telegram, website, working_hours, google_rating, google_review_count from catalog.venues order by id"
  export_table venue_sports "select id, sport_id, court_count, setting, surface, has_lighting, venue_id from catalog.venue_sports order by id"
  export_table venue_images "select id, path, sort_order, venue_id from catalog.venue_images order by id"
  export_table sports "select id, code from catalog.sports order by id"
  export_table cities "select c.id, c.name from catalog.cities c where c.id in (select city_id from catalog.venues) order by c.id"
  docker exec "$DB" pg_dump -U rallyto -d rallyto -n catalog --no-owner --exclude-table-data=catalog.venues     --exclude-table-data=catalog.venue_sports --exclude-table-data=catalog.venue_images --exclude-table-data=catalog.venue_candidates > "$OUT/catalog_base.sql"
  cp "$HERE/transfer_load.sql" "$OUT/load.sql"
  tar -C "$UPLOADS" -czf "$OUT/photos.tar.gz" venues
  ls -la "$OUT"
}

check() {
  ssh "$SERVER" "df -h / | tail -1; free -m | sed -n 2p
    docker ps -a --filter name=rallyto --format '{{.Names}} | {{.Status}}'
    docker logs --tail 5 rallyto-rallyto-api-1 2>&1 | cut -c1-200
    docker exec $DB psql -U rallyto -d rallyto -At -c \"select migration_id from catalog.__ef_migrations_history order by 1 desc limit 1\" -c \"select count(*) from catalog.venues\" -c \"select count(*) from catalog.cities\""
}

load() {
  [ -f "$OUT/venues.csv" ] || bundle
  # shellcheck disable=SC2016 # expanded on the server
  ssh "$SERVER" 'docker exec '"$DB"' pg_dump -U rallyto -Fc rallyto > /opt/rallyto/backup-$(date +%F-%H%M).dump && ls -la /opt/rallyto/*.dump | tail -1'
  tar -C "$OUT" --exclude=photos.tar.gz -czf - . | ssh "$SERVER" "rm -rf /tmp/rallyto-transfer && mkdir -p /tmp/rallyto-transfer && tar -xzf - -C /tmp/rallyto-transfer \
    && docker exec $DB rm -rf /tmp/rallyto-transfer && docker cp /tmp/rallyto-transfer $DB:/tmp/rallyto-transfer \
    && { [ \"\$(docker exec $DB psql -U rallyto -d rallyto -At -c \"select to_regclass('catalog.venues')\")\" = catalog.venues ]          || docker exec $DB psql -q -U rallyto -d rallyto -v ON_ERROR_STOP=1 -f /tmp/rallyto-transfer/catalog_base.sql; }     && docker exec $DB psql -U rallyto -d rallyto -f /tmp/rallyto-transfer/load.sql; rc=\$?; docker exec $DB rm -rf /tmp/rallyto-transfer; rm -rf /tmp/rallyto-transfer; exit \$rc"
  # 1654 is the app user of the .NET images ($APP_UID in the Dockerfile); the API needs it to delete a photo later.
  ssh "$SERVER" "docker volume inspect rallyto_uploads >/dev/null 2>&1 || docker volume create --label com.docker.compose.project=rallyto --label com.docker.compose.volume=uploads rallyto_uploads >/dev/null"
  ssh "$SERVER" "docker run --rm -i -v rallyto_uploads:/u --entrypoint sh postgres:16-alpine -c 'tar -xzf - -C /u --no-same-owner && chown -R 1654:1654 /u/venues && find /u/venues -type f | wc -l'" < "$OUT/photos.tar.gz"
  # The directory query is cached, and this load went around the API.
  ssh "$SERVER" "docker exec rallyto-redis-1 redis-cli FLUSHALL; [ -z \"\$(docker ps -q --filter name=rallyto-rallyto-api-1)\" ] || docker restart rallyto-rallyto-api-1"
}

"${1:?usage: transfer.sh bundle|check|load}"
