# Shared lib for scripts — usado vía: source "$(dirname "$0")/_lib.sh"
# Lee variables del .env de forma segura (sin ejecutar el archivo).

env_get() {
  local key="$1"
  grep -E "^${key}=" .env 2>/dev/null | head -1 | cut -d= -f2- | sed 's/^"//;s/"$//'
}

check_env() {
  if [[ ! -f .env ]]; then
    echo "❌ No existe .env. Copia .env.example a .env y edita los valores."
    exit 1
  fi
}
