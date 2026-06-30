#!/usr/bin/env bash
# restore.sh — Restaura o PostgreSQL a partir de um arquivo de backup.
# Uso: ./scripts/restore.sh <arquivo_backup.sql.gz>
# ATENÇÃO: Isso substitui os dados existentes no banco.

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOM_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$HOM_DIR/.env"

# ─── Valida argumentos ────────────────────────────────────────────────────────
if [ -z "$1" ]; then
  echo "Uso: $0 <arquivo_backup.sql.gz>"
  echo "Exemplo: $0 ./backups/fortivus_backup_20241201_120000.sql.gz"
  exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERRO: Arquivo de backup não encontrado: $BACKUP_FILE"
  exit 1
fi

# ─── Carrega variáveis ────────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo "ERRO: Arquivo .env não encontrado."
  exit 1
fi
set -a
source "$ENV_FILE"
set +a

echo "============================================================"
echo " FORTIVUS — Restauração PostgreSQL"
echo "============================================================"
echo " Arquivo: $BACKUP_FILE"
echo ""
echo " ⚠️  ATENÇÃO: Esta operação SOBRESCREVE os dados existentes!"
read -rp " Digite 'CONFIRMAR' para continuar: " CONFIRM

if [ "$CONFIRM" != "CONFIRMAR" ]; then
  echo "Restauração cancelada."
  exit 0
fi

echo ""
echo "Restaurando backup..."

# ─── Descomprime e restaura ───────────────────────────────────────────────────
if [[ "$BACKUP_FILE" == *.gz ]]; then
  gunzip -c "$BACKUP_FILE" | \
    docker compose -f "$HOM_DIR/docker-compose.yml" exec -T postgres \
    psql -U "${POSTGRES_USER}" postgres
else
  docker compose -f "$HOM_DIR/docker-compose.yml" exec -T postgres \
    psql -U "${POSTGRES_USER}" postgres < "$BACKUP_FILE"
fi

echo ""
echo "============================================================"
echo " Restauração concluída com sucesso!"
echo "============================================================"
echo ""
echo "Reiniciando aplicações para reconectar ao banco restaurado..."
docker compose -f "$HOM_DIR/docker-compose.yml" restart backend attachment fire-event-service
echo "Aplicações reiniciadas."
