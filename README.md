# Fortivus - Gestão de Combate a Incêndios Florestais

Sistema moderno orientado a microsserviços para monitoramento e resposta a incêndios florestais.

## 🏗️ Arquitetura (Fortivus Stack)

- **Proxy/SSL:** Traefik (HTTPS Automático)
- **Auth:** ZITADEL (auth-dev.seu-dominio.com)
- **Secrets:** Vault (vault-dev.seu-dominio.com)
- **Storage:** SeaweedFS (s3-dev.seu-dominio.com)
- **Observability:** Loki + Promtail + Grafana (logs-dev.seu-dominio.com)
- **GIS:** Martin (maps-dev.seu-dominio.com)
- **DB:** PostGIS (Porta 5432 interna)

## 🚀 Como Iniciar

### 1. Configurar Variáveis
Crie um arquivo `.env` em `src/infra/` com as seguintes variáveis:
```env
DOMAIN=seu-dominio.com
ACME_EMAIL=seu@email.com
DB_USER=fortivus_admin
DB_PASSWORD=senha_forte
```

### 2. Startup
```bash
docker compose -f src/infra/docker-compose-local.yml up -d
```

## 📂 Serviços
- `src/services/fortivus-core`: Núcleo de gestão de ocorrências e inteligência de combate.

