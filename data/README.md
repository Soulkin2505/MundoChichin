# data/

Esta carpeta contiene **datos del cliente** que NO van a Git:

- `db-init/` — dump SQL inicial (`01-dump.sql` o `.sql.gz`). MariaDB lo importa la primera vez que arranca.
- `backups/` — backups generados por `scripts/backup.sh`.

Para llevar la BD a producción usa `scp` o `rsync`, no Git.
