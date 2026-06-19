#!/usr/bin/env bash
# Backup DB + uploads en data/backups/<timestamp>/
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_lib.sh
check_env

COMPOSE="docker compose"
[[ "${1:-}" == "--prod" ]] && COMPOSE="docker compose -f docker-compose.prod.yml"

DB_NAME=$(env_get DB_NAME)
DB_ROOT_PASSWORD=$(env_get DB_ROOT_PASSWORD)
TS=$(date +%Y%m%d-%H%M%S)
DEST="data/backups/$TS"
mkdir -p "$DEST"

echo "==> [$TS] Dump de base de datos..."
$COMPOSE exec -T db mariadb-dump \
  -u root -p"${DB_ROOT_PASSWORD}" \
  --single-transaction --quick --routines --triggers \
  "${DB_NAME}" | gzip -9 > "$DEST/db.sql.gz"

echo "==> [$TS] Backup uploads..."
tar -czf "$DEST/uploads.tar.gz" -C wp-content uploads/

echo ""
echo "✅ Backup en $DEST"
ls -lh "$DEST"
