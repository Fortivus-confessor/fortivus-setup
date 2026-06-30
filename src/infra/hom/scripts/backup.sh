#!/usr/bin/env bash
# backup.sh — Backup completo do PostgreSQL (todos os bancos).
# Uso: ./scripts/backup.sh
# Os backups são salvos em ./backups/

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOM_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$HOM_DIR/.env"
BACKUP_DIR="$HOM_DIR/backups"

# ─── Carrega variáveis ────────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo "ERRO: Arquivo .env não encontrado."
  exit 1
fi
set -a
source "$ENV_FILE"
set +a

# ─── Prepara diretório de backup ──────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/fortivus_backup_${TIMESTAMP}.sql"

echo "============================================================"
echo " FORTIVUS — Backup PostgreSQL"
echo "============================================================"
echo " Destino: $BACKUP_FILE.gz"
echo ""

# ─── Dump de todos os bancos ──────────────────────────────────────────────────
echo "Executando pg_dumpall..."
docker compose -f "$HOM_DIR/docker-compose.yml" exec -T postgres \
  pg_dumpall -U "${POSTGRES_USER}" > "$BACKUP_FILE"

# ─── Comprime ─────────────────────────────────────────────────────────────────
echo "Comprimindo backup..."
gzip "$BACKUP_FILE"

BACKUP_SIZE=$(du -sh "${BACKUP_FILE}.gz" | cut -f1)

echo ""
echo "============================================================"
echo " Backup concluído com sucesso!"
echo " Arquivo: ${BACKUP_FILE}.gz ($BACKUP_SIZE)"
echo "============================================================"

# ─── Remove backups mais antigos que 30 dias ──────────────────────────────────
echo ""
echo "Removendo backups com mais de 30 dias..."
find "$BACKUP_DIR" -name "fortivus_backup_*.sql.gz" -mtime +30 -delete
echo "Limpeza concluída."
