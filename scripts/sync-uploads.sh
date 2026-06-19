#!/usr/bin/env bash
# =============================================================================
# Sincroniza wp-content/uploads/ entre local y VPS via rsync.
# Uso:
#   ./scripts/sync-uploads.sh push user@vps:/srv/mundochichin
#   ./scripts/sync-uploads.sh pull user@vps:/srv/mundochichin
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

ACTION="${1:?Uso: push|pull <user@host:/path>}"
REMOTE="${2:?Falta destino remoto, ej: user@vps:/srv/mundochichin}"

case "$ACTION" in
  push)
    echo "==> Subiendo uploads al VPS..."
    rsync -avzP --delete wp-content/uploads/ "${REMOTE}/wp-content/uploads/"
    ;;
  pull)
    echo "==> Bajando uploads desde el VPS..."
    rsync -avzP --delete "${REMOTE}/wp-content/uploads/" wp-content/uploads/
    ;;
  *)
    echo "❌ Acción inválida: push|pull"; exit 1
    ;;
esac
