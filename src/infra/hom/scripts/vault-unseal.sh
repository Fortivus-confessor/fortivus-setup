#!/usr/bin/env bash
# vault-unseal.sh — Desbloqueia o Vault após reinicialização do container.
# Uso: ./scripts/vault-unseal.sh [UNSEAL_KEY]
# Se UNSEAL_KEY não for fornecido, lê de .vault-keys.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOM_DIR="$(dirname "$SCRIPT_DIR")"
VAULT_KEYS_FILE="$HOM_DIR/.vault-keys"

# ─── Obtém a chave de unseal ──────────────────────────────────────────────────
if [ -n "$1" ]; then
  UNSEAL_KEY="$1"
elif [ -f "$VAULT_KEYS_FILE" ]; then
  UNSEAL_KEY=$(grep "^UNSEAL_KEY=" "$VAULT_KEYS_FILE" | cut -d'=' -f2-)
  if [ -z "$UNSEAL_KEY" ]; then
    echo "ERRO: UNSEAL_KEY não encontrada em $VAULT_KEYS_FILE"
    exit 1
  fi
else
  echo "ERRO: Forneça o UNSEAL_KEY como argumento ou crie o arquivo $VAULT_KEYS_FILE"
  echo "Uso: $0 <UNSEAL_KEY>"
  exit 1
fi

echo "Desbloqueando Vault..."
docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
  env VAULT_ADDR=http://127.0.0.1:8200 \
  vault operator unseal "$UNSEAL_KEY"

echo ""
echo "Status do Vault após unseal:"
docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
  env VAULT_ADDR=http://127.0.0.1:8200 \
  vault status
