#!/usr/bin/env bash
# =============================================================================
# Inicializa el sitio: ajusta permisos, hace search-replace de URLs originales
# al WP_SITE_URL del .env, y limpia caches.
#
# Uso:
#   ./scripts/init.sh                    # dev local
#   ./scripts/init.sh --prod             # producción (docker-compose.prod.yml)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/_lib.sh
check_env

WP_SITE_URL=$(env_get WP_SITE_URL)
COMPOSE="docker compose"
WPCLI_RUN="$COMPOSE exec -T wpcli"
if [[ "${1:-}" == "--prod" ]]; then
  COMPOSE="docker compose -f docker-compose.prod.yml"
  WPCLI_RUN="$COMPOSE run --rm wpcli"
fi

ORIGINAL_URLS=(
  "https://www.mundochichin.com"
  "https://mundochichin.com"
  "http://www.mundochichin.com"
  "http://mundochichin.com"
)

echo "==> Esperando WordPress core..."
for i in $(seq 1 60); do
  if $COMPOSE exec -T wordpress test -f /var/www/html/wp-load.php 2>/dev/null; then break; fi
  sleep 2
done

echo "==> Ajustando permisos de wp-content..."
$COMPOSE exec -u root -T wordpress chown -R www-data:www-data /var/www/html/wp-content 2>/dev/null || true

echo "==> Search-replace de URLs a ${WP_SITE_URL}..."
for url in "${ORIGINAL_URLS[@]}"; do
  [[ "$url" == "$WP_SITE_URL" ]] && continue
  $WPCLI_RUN wp --path=/var/www/html search-replace \
    "$url" "$WP_SITE_URL" \
    --all-tables-with-prefix --skip-columns=guid --report-changed-only || true
done

echo "==> Limpiando transients y cache..."
$WPCLI_RUN wp --path=/var/www/html transient delete --all || true
$WPCLI_RUN wp --path=/var/www/html cache flush || true
$WPCLI_RUN wp --path=/var/www/html rewrite flush --hard || true

echo "==> Desactivando plugins no aplicables fuera del hosting LiteSpeed..."
$WPCLI_RUN wp --path=/var/www/html plugin deactivate \
  litespeed-cache updraftplus 2>/dev/null || true

echo ""
echo "✅ Inicialización completa."
echo "   Sitio: ${WP_SITE_URL}"
echo "   Admin: ${WP_SITE_URL}/wp-admin"
