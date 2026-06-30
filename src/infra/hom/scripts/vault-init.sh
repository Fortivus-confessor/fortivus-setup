#!/usr/bin/env bash
# vault-init.sh — Inicialização completa do HashiCorp Vault para o ambiente Fortivus HOM
# Execute uma única vez na primeira implantação.
# Pré-requisito: docker compose up -d vault (container deve estar rodando)

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOM_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$HOM_DIR/.env"
VAULT_KEYS_FILE="$HOM_DIR/.vault-keys"
VAULT_CREDS_FILE="$HOM_DIR/.env.vault-credentials"

# ─── Carrega variáveis de ambiente ────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo "ERRO: Arquivo .env não encontrado em $ENV_FILE"
  echo "Copie .env.example para .env e preencha os valores."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

VAULT_ADDR_HOST="http://localhost:8200"

echo "============================================================"
echo " FORTIVUS — Inicialização do Vault"
echo "============================================================"
echo ""

# ─── Helper para executar comandos vault no container ─────────────────────────
vault_exec() {
  docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
    env VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN="$VAULT_ROOT_TOKEN" \
    vault "$@"
}

vault_exec_no_token() {
  docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
    env VAULT_ADDR=http://127.0.0.1:8200 \
    vault "$@"
}

# ─── Verifica se o Vault está acessível ───────────────────────────────────────
echo "[1/8] Verificando conectividade com o Vault..."
MAX_RETRIES=12
for i in $(seq 1 $MAX_RETRIES); do
  if docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
      env VAULT_ADDR=http://127.0.0.1:8200 vault status > /dev/null 2>&1; then
    echo "      Vault acessível."
    break
  elif [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "ERRO: Vault não está respondendo após $MAX_RETRIES tentativas."
    echo "Verifique: docker compose logs vault"
    exit 1
  else
    echo "      Aguardando Vault... tentativa $i/$MAX_RETRIES"
    sleep 5
  fi
done

# ─── Verifica se já foi inicializado ──────────────────────────────────────────
INIT_STATUS=$(docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
  env VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json 2>/dev/null | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('initialized','false'))" 2>/dev/null || echo "false")

if [ "$INIT_STATUS" = "True" ] || [ "$INIT_STATUS" = "true" ]; then
  echo ""
  echo "AVISO: Vault já foi inicializado anteriormente."
  echo "Se precisar adicionar/atualizar secrets, use vault_exec manualmente."
  echo "Para unseal após reinicialização, use: ./scripts/vault-unseal.sh"
  exit 0
fi

# ─── Inicialização ────────────────────────────────────────────────────────────
echo ""
echo "[2/8] Inicializando o Vault (1 key share, threshold 1)..."
INIT_OUTPUT=$(docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
  env VAULT_ADDR=http://127.0.0.1:8200 \
  vault operator init -key-shares=1 -key-threshold=1 -format=json)

UNSEAL_KEY=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['unseal_keys_b64'][0])")
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['root_token'])")

# Salva chaves (com aviso de segurança)
cat > "$VAULT_KEYS_FILE" <<EOF
# VAULT KEYS — FORTIVUS HOM
# ATENÇÃO: Este arquivo contém credenciais sensíveis.
# Guarde o UNSEAL_KEY em local seguro (cofre físico, HSM, etc.)
# NÃO commite este arquivo no git.

UNSEAL_KEY=$UNSEAL_KEY
ROOT_TOKEN=$ROOT_TOKEN
EOF
chmod 600 "$VAULT_KEYS_FILE"

echo ""
echo "      ⚠️  ATENÇÃO: Unseal Key e Root Token salvos em: $VAULT_KEYS_FILE"
echo "      Guarde o UNSEAL_KEY em local seguro e separado do servidor!"
echo ""

export VAULT_ROOT_TOKEN="$ROOT_TOKEN"

# ─── Unseal ───────────────────────────────────────────────────────────────────
echo "[3/8] Desbloqueando o Vault..."
docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
  env VAULT_ADDR=http://127.0.0.1:8200 \
  vault operator unseal "$UNSEAL_KEY"
echo "      Vault desbloqueado com sucesso."

# ─── Habilita secrets engine KV v2 ───────────────────────────────────────────
echo ""
echo "[4/8] Habilitando KV v2 no path 'fortivus'..."
vault_exec secrets enable -path=fortivus -version=2 kv
echo "      KV v2 habilitado em fortivus/."

# ─── Habilita AppRole auth ────────────────────────────────────────────────────
echo ""
echo "[5/8] Habilitando AppRole auth..."
vault_exec auth enable approle
echo "      AppRole auth habilitado."

# ─── Cria policy ──────────────────────────────────────────────────────────────
echo ""
echo "[6/8] Criando policy 'fortivus-services'..."
docker compose -f "$HOM_DIR/docker-compose.yml" exec -T vault \
  env VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN="$VAULT_ROOT_TOKEN" \
  vault policy write fortivus-services - <<'POLICY'
path "fortivus/data/*" {
  capabilities = ["read"]
}
path "fortivus/metadata/*" {
  capabilities = ["list", "read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
POLICY
echo "      Policy 'fortivus-services' criada."

# ─── Armazena secrets ─────────────────────────────────────────────────────────
echo ""
echo "[7/8] Armazenando secrets no Vault..."

vault_exec kv put fortivus/database \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
echo "      ✓ fortivus/database"

vault_exec kv put fortivus/keycloak \
  KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN}" \
  KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
echo "      ✓ fortivus/keycloak"

vault_exec kv put fortivus/rabbitmq \
  RABBITMQ_USERNAME="${RABBITMQ_USERNAME}" \
  RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD}"
echo "      ✓ fortivus/rabbitmq"

vault_exec kv put fortivus/storage \
  S3_ACCESS_KEY="${S3_ACCESS_KEY}" \
  S3_SECRET_KEY="${S3_SECRET_KEY}"
echo "      ✓ fortivus/storage"

vault_exec kv put fortivus/nasa-firms \
  NASA_FIRMS_MAP_KEY="${NASA_FIRMS_MAP_KEY}"
echo "      ✓ fortivus/nasa-firms"

# ─── Cria AppRoles e coleta credenciais ───────────────────────────────────────
echo ""
echo "[8/8] Criando AppRoles e coletando credenciais..."

create_approle_and_get_creds() {
  local ROLE_NAME="$1"
  local ENV_PREFIX="$2"

  vault_exec write "auth/approle/role/${ROLE_NAME}" \
    token_policies="fortivus-services" \
    token_ttl=1h \
    token_max_ttl=24h \
    secret_id_ttl=0 \
    > /dev/null

  local ROLE_ID
  ROLE_ID=$(vault_exec read -field=role_id "auth/approle/role/${ROLE_NAME}/role-id")

  local SECRET_ID
  SECRET_ID=$(vault_exec write -f -field=secret_id "auth/approle/role/${ROLE_NAME}/secret-id")

  echo "${ENV_PREFIX}_VAULT_ROLE_ID=${ROLE_ID}"
  echo "${ENV_PREFIX}_VAULT_SECRET_ID=${SECRET_ID}"

  echo "      ✓ Role '${ROLE_NAME}' criada"
}

# Gera credenciais para cada serviço
{
  echo "# Fortivus — Credenciais Vault AppRole (geradas por vault-init.sh)"
  echo "# Copie estes valores para o arquivo .env"
  echo ""
  create_approle_and_get_creds "fortivus-backend"    "BACKEND"
  create_approle_and_get_creds "fortivus-attachment" "ATTACHMENT"
  create_approle_and_get_creds "fortivus-fire-event" "FIRE_EVENT"
} > "$VAULT_CREDS_FILE"

chmod 600 "$VAULT_CREDS_FILE"

echo ""
echo "============================================================"
echo " INICIALIZAÇÃO CONCLUÍDA COM SUCESSO"
echo "============================================================"
echo ""
echo " Credenciais AppRole salvas em: $VAULT_CREDS_FILE"
echo ""
echo " Próximos passos:"
echo "   1. Abra $VAULT_CREDS_FILE"
echo "   2. Copie os valores BACKEND_VAULT_ROLE_ID, BACKEND_VAULT_SECRET_ID, etc."
echo "      para o arquivo .env"
echo "   3. Execute: docker compose up -d backend attachment fire-event-service frontend"
echo ""
echo " Para unseal após reinicialização do container Vault:"
echo "   ./scripts/vault-unseal.sh"
echo ""
cat "$VAULT_CREDS_FILE"
