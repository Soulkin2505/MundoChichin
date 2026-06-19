#!/usr/bin/env bash
# Restaurar BD desde dump SQL (.sql o .sql.gz)
# Uso: ./scripts/restore-db.sh data/db-init/01-dump.sql[.gz]  [--prod]
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_lib.sh
check_env

FILE="${1:?Falta archivo SQL: ./scripts/restore-db.sh path/al/dump.sql[.gz]}"
COMPOSE="docker compose"
[[ "${2:-}" == "--prod" ]] && COMPOSE="docker compose -f docker-compose.prod.yml"

DB_NAME=$(env_get DB_NAME)
DB_ROOT_PASSWORD=$(env_get DB_ROOT_PASSWORD)

if [[ ! -f "$FILE" ]]; then
  echo "❌ No existe $FILE"; exit 1
fi

echo "==> Restaurando $FILE en ${DB_NAME}..."
if [[ "$FILE" == *.gz ]]; then
  gunzip -c "$FILE" | $COMPOSE exec -T db mariadb -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}"
else
  cat "$FILE" | $COMPOSE exec -T db mariadb -u root -p"${DB_ROOT_PASSWORD}" "${DB_NAME}"
fi

echo "✅ Restore OK. Ahora corre ./scripts/init.sh para search-replace."
