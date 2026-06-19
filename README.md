# Mundo Chichín — WordPress

Tienda WordPress + WooCommerce de [mundochichin.com](https://mundochichin.com), dockerizada para desarrollo local y despliegue en VPS con HTTPS automático.

- **WordPress** (PHP 8.1 / Apache) + **MariaDB 10.11**
- **Caddy** como reverse proxy con TLS automático (Let's Encrypt)
- **Theme:** `bw-petito` (BZOTech) · **WooCommerce 9.7.3** (HPOS habilitado)
- **17 plugins activos** (Elementor, RevSlider, YITH Wishlist/Compare, Contact Form 7, MailChimp, Redux, Loco Translate, etc.)

> ⚠️ **El sitio original tenía malware**: un mu-plugin `server-manager-loader.php` y un plugin `SidMust-plugin-v2` que actuaban como backdoor. Ya fueron removidos. Ver [SEGURIDAD.md](#seguridad).

---

## Estructura

```
mundochichin-wp/
├── .env.example               # Plantilla de variables — cópiala a .env
├── .gitignore
├── docker-compose.yml         # Desarrollo local (HTTP, puerto 8090)
├── docker-compose.prod.yml    # Producción (Caddy + HTTPS automático)
├── caddy/
│   └── Caddyfile              # Configuración reverse proxy
├── config/
│   └── php/uploads.ini        # Límites PHP (memoria, uploads)
├── data/                      # ⛔ No va a Git — datos del cliente
│   ├── db-init/01-dump.sql    # Dump inicial (se carga al primer arranque)
│   └── backups/               # Backups generados por scripts/backup.sh
├── wp-content/                # ✅ Sí va a Git (excepto uploads/)
│   ├── plugins/
│   ├── themes/
│   ├── mu-plugins/
│   └── uploads/               # ⛔ No va a Git — sincronizar con rsync
└── scripts/
    ├── init.sh                # Search-replace URLs + cache flush
    ├── backup.sh              # Backup DB + uploads
    ├── restore-db.sh          # Restaurar dump SQL
    ├── sync-uploads.sh        # rsync push/pull de uploads
    └── wp                     # Wrapper de WP-CLI
```

---

## Desarrollo local

### 1. Pre-requisitos

- Docker Desktop o Docker Engine + Compose v2
- Puertos libres: `8090` (web) y `8091` (phpMyAdmin)

### 2. Configurar `.env`

```bash
cp .env.example .env
# Edita .env: passwords y salts (genera salts en https://api.wordpress.org/secret-key/1.1/salt/)
```

Para local, deja `WP_SITE_URL=http://localhost:8090`.

### 3. Colocar el dump SQL

Copia el dump inicial:
```bash
cp /ruta/al/backup-db.sql data/db-init/01-dump.sql
# o:
cp /ruta/al/backup-db.sql.gz data/db-init/01-dump.sql.gz
```

### 4. Arrancar

```bash
docker compose up -d
./scripts/init.sh
```

Eso levanta MariaDB (importa el dump automáticamente la primera vez), WordPress, WP-CLI y phpMyAdmin; y luego `init.sh` hace el search-replace de URLs y limpia caches.

### 5. Acceder

| Servicio        | URL                            |
|-----------------|--------------------------------|
| Frontend        | http://localhost:8090          |
| WP Admin        | http://localhost:8090/wp-admin |
| phpMyAdmin      | http://localhost:8091          |

Crea/actualiza tu admin:
```bash
./scripts/wp user create admin tu@email.com --role=administrator --user_pass='Admin123!'
```

### Comandos útiles

```bash
# WP-CLI (cualquier comando)
./scripts/wp plugin list
./scripts/wp theme list
./scripts/wp option get siteurl
./scripts/wp search-replace 'http://viejo.com' 'http://nuevo.com' --skip-columns=guid

# Backup local
./scripts/backup.sh

# Logs
docker compose logs -f wordpress

# Reset total (¡borra TODO incluyendo BD!)
docker compose down -v
```

---

## Despliegue en VPS con dominio + HTTPS

### Requisitos del VPS

- Ubuntu 22.04 o Debian 12 (4 GB RAM mínimo, 8 GB recomendado para WooCommerce)
- Docker + Docker Compose v2
- Puertos `80` y `443` abiertos
- DNS apuntando al VPS:
  ```
  A    mundochichin.com       → IP_DEL_VPS
  A    www.mundochichin.com   → IP_DEL_VPS
  ```

### 1. Instalar Docker en el VPS

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# (cierra y vuelve a entrar para que el grupo aplique)
```

### 2. Clonar el repo y configurar

```bash
sudo mkdir -p /srv/mundochichin && sudo chown $USER /srv/mundochichin
cd /srv/mundochichin
git clone <URL_DE_TU_REPO_GITHUB> .

cp .env.example .env
nano .env
```

Edita `.env` con:
```env
COMPOSE_PROJECT_NAME=mundochichin
WP_SITE_URL=https://mundochichin.com
WP_DOMAIN=mundochichin.com,www.mundochichin.com
CADDY_EMAIL=tu@email.com

DB_NAME=mundochichin
DB_USER=wpuser
DB_PASSWORD=<password fuerte>
DB_ROOT_PASSWORD=<password root fuerte>
WP_TABLE_PREFIX=wppb_

# Genera nuevos salts en https://api.wordpress.org/secret-key/1.1/salt/
WP_AUTH_KEY=...
# (etc.)
```

### 3. Subir el dump SQL y los uploads al VPS

Desde tu máquina local:
```bash
# Dump SQL
scp data/db-init/01-dump.sql user@VPS:/srv/mundochichin/data/db-init/

# Uploads (480 MB, va por rsync)
./scripts/sync-uploads.sh push user@VPS:/srv/mundochichin
```

### 4. Arrancar en producción

En el VPS:
```bash
cd /srv/mundochichin
docker compose -f docker-compose.prod.yml up -d
./scripts/init.sh --prod
```

Caddy detectará el dominio y pedirá certificado a Let's Encrypt automáticamente (1-2 min). Logs:
```bash
docker compose -f docker-compose.prod.yml logs -f caddy
```

### 5. Cron de WordPress

En producción tenemos `DISABLE_WP_CRON=true`. Agrega al crontab del VPS:
```bash
crontab -e
```
```cron
*/15 * * * * docker exec mundochichin_wp wp --path=/var/www/html cron event run --due-now --allow-root >/dev/null 2>&1
```

### 6. Backups automáticos

```bash
crontab -e
```
```cron
0 3 * * * cd /srv/mundochichin && ./scripts/backup.sh --prod >> /var/log/mundochichin-backup.log 2>&1
```

### 7. Migrar el dominio (cuando el DNS apunte aquí)

Si vas a cambiar de URL definitiva (ej. estabas en `https://staging.mundochichin.com` y pasas a `https://mundochichin.com`):

```bash
# 1. Edita .env: WP_SITE_URL=https://nuevo-dominio.com y WP_DOMAIN=...
nano .env
# 2. Re-genera URLs en BD
./scripts/wp --prod search-replace 'https://staging.mundochichin.com' 'https://mundochichin.com' \
  --all-tables-with-prefix --skip-columns=guid
# 3. Recargar Caddy y WP
docker compose -f docker-compose.prod.yml restart caddy wordpress
```

---

## Seguridad

El sitio original había sido comprometido. Acciones tomadas:

- ❌ Borrado **mu-plugin `server-manager-loader.php`** que auto-reactivaba el backdoor
- ❌ Borrado **`SidMust-plugin-v2/File-Manager.php`** (backdoor del atacante)
- ❌ Borrado plugins de gestión de archivos: `wp-file-manager`, `fileorganizer`, `filester` (vector típico de pwning)
- ❌ Borrado `wp-content/upload-back.php` y `.server-backup.php` (artefactos sospechosos)
- ❌ Borrado `wp-content/themes-old/`, `uploads-old/`, `languages-old/`, `index.php-old` (basura)

Hardening en `docker-compose.prod.yml` y `caddy/Caddyfile`:

- `DISALLOW_FILE_EDIT = true` (no editor de plugins/temas desde el admin)
- `FORCE_SSL_ADMIN = true`
- Caddy bloquea ejecución de PHP en `/wp-content/uploads/*.php`
- Caddy bloquea `xmlrpc.php`, `wp-config.php`, `readme.html`, `.git`, `.env`
- Headers de seguridad: HSTS, X-Frame-Options, nosniff, etc.
- `expose: ["80"]` en el contenedor WP — sólo Caddy puede acceder, no se expone al exterior

### Recomendaciones adicionales

1. **Cambiar TODAS las passwords de admin** después del primer login.
2. Instalar **Wordfence** o **iThemes Security** y correr un escaneo completo.
3. Revisar usuarios admin sospechosos (había 4 en el dump):
   ```bash
   ./scripts/wp --prod user list --role=administrator
   ```
4. Revisar contenido de `/_malware_quarantine/` (en `MUNDOCHICHIN/` local) si quieres analizar el backdoor.
5. Considerar migrar a CloudFlare como CDN/WAF gratuito.

---

## Stack instalado

**Plugins activos (17):**
Akismet · BZOTech Core · BZOTech Elementor · Contact Form 7 · Elementor 3.28.1 · LiteSpeed Cache · Loco Translate · MailChimp for WP · Redux Framework · RevSlider 6.7.25 · UpdraftPlus · WooCommerce 9.7.3 · WooCommerce Currency Switcher · YITH Compare · YITH Wishlist · Translator addon for Loco

**Tema activo:** `bw-petito` v1.6.2 (BZOTech)

---

## Troubleshooting

**Error "table prefix wp_" al usar WP-CLI**
- Está faltando `WORDPRESS_TABLE_PREFIX` en el env. Usa siempre `./scripts/wp ...` (que lo inyecta).

**Caddy no genera certificado**
- Verifica DNS: `dig mundochichin.com +short` debe devolver la IP del VPS.
- Verifica puerto 80/443 abiertos: `sudo ufw status` y `sudo nft list ruleset`.
- Logs: `docker compose -f docker-compose.prod.yml logs caddy`.

**Imagen rotas o estilos sin cargar**
- Hay URLs hardcoded. Ejecutar:
  ```bash
  ./scripts/wp --prod search-replace 'http://localhost:8090' 'https://mundochichin.com' \
    --all-tables-with-prefix --skip-columns=guid
  ./scripts/wp --prod cache flush
  ./scripts/wp --prod elementor flush-css
  ```

**Error 502 después de arrancar**
- WordPress puede tardar 30s en estar listo la primera vez. Espera y reintenta.
- `docker compose -f docker-compose.prod.yml logs wordpress`
