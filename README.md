# Fortivus — Gestão de Combate a Incêndios Florestais

Sistema orientado a microsserviços e eventos para monitoramento, detecção e resposta a incêndios florestais. Este repositório (`fortivus-setup`) contém **toda a infraestrutura de orquestração** (Docker Compose, Traefik, Vault, Keycloak, RabbitMQ, CI/CD) que sobe os demais repositórios da aplicação.

> Este repositório **não contém o código-fonte das aplicações**. Ele orquestra repositórios irmãos que precisam estar clonados lado a lado (veja [Pré-requisitos](#pré-requisitos)).

---

## Arquitetura

```
                         ┌─────────────┐
                         │   Traefik   │  (proxy reverso / TLS / roteamento por Host+Path)
                         └──────┬──────┘
            ┌───────────────────┼───────────────────────┬───────────────┐
            │                   │                        │               │
      ┌─────▼─────┐      ┌──────▼──────┐          ┌──────▼─────┐  ┌──────▼──────┐
      │ frontend  │      │   backend    │          │ attachment │  │ fire-event  │
      │ (Vite/    │      │ (Fortivus V2 │          │  -service  │  │  -service   │
      │  React)   │      │  Spring Boot)│          │(Spring Boot│  │(Spring Boot │
      └───────────┘      └──┬───┬───┬───┘          └──┬───┬─────┘  └──┬───┬──────┘
                             │   │   │                 │   │           │   │
                ┌────────────┘   │   └──────┐          │   │           │   │
                │                │          │          │   │           │   │
          ┌─────▼────┐    ┌──────▼─────┐ ┌──▼──────────▼───▼───────────▼───▼──┐
          │ Postgres │    │  Keycloak  │ │            RabbitMQ                │
          │ + PostGIS│    │   (IAM)    │ │   (mensageria assíncrona/eventos)  │
          └──────────┘    └────────────┘ └─────────────────────────────────────┘
                │                                          │
          ┌─────▼────┐                              ┌──────▼──────┐
          │  Vault   │  (secrets estáticos + AppRole)│  SeaweedFS  │ (object storage S3-like)
          └──────────┘                               └─────────────┘
                                                       ┌──────────┐
                                                       │  Redis   │ (cache — ver nota abaixo)
                                                       └──────────┘
```

Todos os serviços de aplicação (`backend`, `attachment`, `fire-event-service`) publicam/consomem eventos via **RabbitMQ** (exchanges topic + filas com DLQ), autenticam usuários via **Keycloak** (OIDC/JWT) e buscam credenciais de infraestrutura no **Vault** via AppRole.

---

## Estrutura de pastas

```
fortivus-setup/
├── README.md                # este arquivo
├── CICD_GUIDE.md             # guia de configuração do pipeline de deploy
├── Jenkinsfile                # pipeline Jenkins (build + deploy)
├── Dockerfile.agent           # imagem do agente Jenkins (Docker CLI + compose plugin)
├── LICENSE
└── src/
    ├── app/                   # página estática de hub/links (não faz parte do stack Docker)
    ├── services/
    │   └── stata-core/        # apenas metadado (project-info.json) — serviço não implementado/deployado
    └── infra/
        ├── local/              # ambiente 100% local (sem TLS, com stack de observabilidade)
        ├── dev/                # ambiente com TLS (Let's Encrypt) e Vault externo (host)
        └── hom/                # ambiente de homologação/VPS — Vault containerizado + AppRole completo
```

### Detalhamento de cada pasta

| Pasta | Conteúdo | Observação |
|---|---|---|
| `src/app/` | `index.html`, `style.css`, ícones — uma página estática simples com links de atalho | Referencia portas antigas (`3001`, `8093`) que não existem mais no stack atual; não é servida por nenhum container hoje. Mantida como referência histórica. |
| `src/services/stata-core/` | Só `project-info.json` (nome, versão, descrição) | Não é um serviço real — não tem Dockerfile nem código. Parece ser um placeholder de um serviço planejado/renomeado. |
| `src/infra/local/` | `docker-compose.yml`, `keycloak/realm-export.json`, `observability/{loki,promtail}-config.yml`, `postgres/init-db.sql` | Ambiente para desenvolver na sua máquina. Builda o código-fonte dos repositórios irmãos localmente. Inclui stack de observabilidade (Loki + Promtail + Grafana) que **não existe** nos outros ambientes. |
| `src/infra/dev/` | `docker-compose.yml`, `.env.example`, `keycloak/realm-export.json`, `postgres/{Dockerfile,init.sql}` | Ambiente intermediário com TLS via Traefik/Let's Encrypt. Usa um Vault **externo ao compose** (`VAULT_ADDR=http://host.docker.internal:8200`) — ou seja, espera um Vault já rodando no host. |
| `src/infra/hom/` | `docker-compose.yml`, `.env.example`, `keycloak/`, `postgres/init.sql`, `rabbitmq/{definitions.json,rabbitmq.conf}`, `traefik/{traefik.yml,dynamic/}`, `vault/{config,policies}`, `scripts/{vault-init,vault-unseal,backup,restore}.sh` | Ambiente de **homologação/VPS** (o que roda em produção hoje). É o mais completo: Vault containerizado e inicializado via script, AppRole por serviço, definições de RabbitMQ versionadas, políticas de Traefik dinâmicas. |

---

## Tecnologias por camada

| Camada | Tecnologia | Papel |
|---|---|---|
| Proxy/Edge | **Traefik** (v3) | Roteamento HTTP por `Host`/`PathPrefix`, TLS automático via Let's Encrypt (dev/hom), dashboard protegido por Basic Auth |
| Frontend | **React + Vite** (TanStack Router/Start), servido via **Bun** | SPA do Centro de Comando |
| Backend core | **Spring Boot** (Java 21) + **Hibernate/Envers** + **Flyway** | Ordens de serviço, combatentes, recursos — "Fortivus V2" |
| Microsserviços | **Spring Boot** (attachment-service, fire-event-service) | Upload/anexos e ingestão de focos de calor (NASA FIRMS) |
| Identidade | **Keycloak** | IAM/OIDC, emissão de JWT, RBAC |
| Mensageria | **RabbitMQ** (management + prometheus + federation plugins) | Exchanges topic + filas com DLQ/TTL para desacoplar os serviços |
| Banco de dados | **PostgreSQL 16 + PostGIS** | Dados relacionais + cálculos espaciais (raio, interseção, clusterização de focos de calor) |
| Cache | **Redis** | Configurado e saudável, mas hoje **sem uso real** de cache (keyspace vazio) — investigar se o cache foi de fato implementado no backend antes de assumir que está em uso |
| Object storage | **SeaweedFS** (S3-compatible) | Armazenamento de anexos/imagens do `attachment-service` |
| Secrets | **HashiCorp Vault** | KV v2 (`fortivus/*`) para secrets estáticos + AppRole auth por serviço + Database Secrets Engine (credenciais dinâmicas do Postgres, hoje configurada mas ainda não consumida pelas aplicações) |
| CI/CD | **Jenkins** (via `Jenkinsfile` + `Dockerfile.agent`) | Pipeline de build e deploy |
| Orquestração | **Docker Compose** | Um arquivo por ambiente (`local`, `dev`, `hom`) |

---

## Pré-requisitos

1. **Docker** e **Docker Compose v2** (`docker compose version`).
2. Clonar os repositórios irmãos **no mesmo diretório pai** deste repositório (os `docker-compose.yml` usam `context: ../../../../<repo>`, relativo a `src/infra/<ambiente>/`):

```
<diretório-pai>/
├── fortivus-setup/         (este repositório)
├── fire-command-center/    (frontend)
├── fortivus-v2/             (backend core)
├── attachment-service/
└── fire-event-service/
```

Ex.: se `fortivus-setup` está em `/opt/fortivus/fortivus-setup`, os demais devem estar em `/opt/fortivus/fire-command-center`, `/opt/fortivus/fortivus-v2`, etc.

3. Para o ambiente `hom`: um domínio próprio apontando para a VPS (registros DNS `A` para `${DOMAIN}` e `auth.${DOMAIN}`, no mínimo) e `python3` disponível no host (usado pelos scripts de setup do Vault).

---

## Passo a passo — Ambiente Local

Sem TLS, todos os serviços buildados a partir do código-fonte local, ideal para desenvolvimento no dia a dia.

```bash
cd src/infra/local

# Não existe .env.example neste ambiente — crie um .env com pelo menos:
#   POSTGRES_USER=fortivus
#   POSTGRES_PASSWORD=<escolha uma senha>
#   POSTGRES_DB=fortivus
#   POSTGRES_PORT=5432
#   REDIS_PORT=6379
#   SEAWEEDFS_MASTER_PORT=9333
#   SEAWEEDFS_S3_PORT=8333
#   GRAFANA_ADMIN_PASSWORD=<escolha uma senha>

docker compose up -d --build
```

**Acessos locais:**
- Frontend: http://localhost:8000/
- Backend (direto): http://localhost:8080 — via Traefik: http://localhost:8000/combate
- Fire Event Service (direto): http://localhost:8084 — via Traefik: http://localhost:8000/api/v1/fire-events
- Traefik Dashboard: http://localhost:8080 (dashboard interno do Traefik, inseguro/sem auth — **só use localmente**)
- RabbitMQ Management: http://localhost:15672 (`guest`/`guest`)
- Keycloak: http://localhost:9000 (`admin`/`admin`)
- Grafana: http://localhost:3000
- Postgres: `localhost:5432` · Redis: `localhost:6379`

> Este é o único ambiente com **Loki + Promtail + Grafana** (observabilidade de logs). `dev` e `hom` não têm esse stack hoje.

---

## Passo a passo — Ambiente HOM (VPS / homologação)

Este é o ambiente "de produção" atual, com TLS, Vault containerizado e AppRole.

### 1. Preparar variáveis de ambiente

```bash
cd src/infra/hom
cp .env.example .env
# preencha DOMAIN, ACME_EMAIL, POSTGRES_PASSWORD, KEYCLOAK_ADMIN_PASSWORD,
# RABBITMQ_PASSWORD, S3_SECRET_KEY, NASA_FIRMS_MAP_KEY, TRAEFIK_DASHBOARD_PASSWORD_HASH
# (gere o hash do Traefik com: htpasswd -nB admin)
```

### 2. Subir a infraestrutura de apoio primeiro

```bash
docker compose up -d postgres redis rabbitmq vault
```

### 3. Inicializar o Vault (executar **uma única vez**, na primeira implantação)

```bash
./scripts/vault-init.sh
```

Esse script:
- Faz `vault operator init` (1 key-share/threshold — ajuste se quiser HA real) e salva a unseal key + root token em `.vault-keys` (`chmod 600`, **nunca commitar**).
- Faz o unseal automaticamente.
- Habilita KV v2 em `fortivus/` e grava os secrets estáticos (`database`, `keycloak`, `rabbitmq`, `storage`, `nasa-firms`) a partir do seu `.env`.
- Habilita a **Database Secrets Engine** do Postgres e cria roles dinâmicas por serviço (`fortivus-backend-db`, `fortivus-attachment-db`, `fortivus-fire-event-db`) com TTL de 1h/24h.
- Cria uma **AppRole por serviço** (`fortivus-backend`, `fortivus-attachment`, `fortivus-fire-event`) com a policy `fortivus-services`, e grava `ROLE_ID`/`SECRET_ID` de cada um em `.env.vault-credentials`.

Depois, copie os valores de `.env.vault-credentials` para as variáveis `BACKEND_VAULT_ROLE_ID`, `BACKEND_VAULT_SECRET_ID`, etc. no seu `.env`.

Se o container do Vault reiniciar (ele usa storage `file`, então **não perde os dados**, mas **sela novamente**), rode:

```bash
./scripts/vault-unseal.sh
```

### 4. Subir o restante da stack

```bash
docker compose up -d
```

Isso inclui: `keycloak`, `seaweedfs`, `traefik`, `frontend`, `backend`, `attachment`, `fire-event-service`.

### 5. Verificar saúde

```bash
docker compose ps
docker compose logs -f traefik   # confirme que as rotas foram registradas
```

### Backup e restauração do Vault

```bash
./scripts/backup.sh    # ver o script para destino/retenção
./scripts/restore.sh
```

---

## Ambiente `dev`

Intermediário entre `local` e `hom`: tem TLS via Traefik/Let's Encrypt como o `hom`, mas **espera um Vault já rodando no host** (`VAULT_ADDR=http://host.docker.internal:8200`) em vez de subir seu próprio container Vault. Use `src/infra/dev/.env.example` como referência de variáveis. Indicado para testar a stack com domínio/TLS reais sem depender do processo completo de inicialização do Vault do `hom`.

---

## Variáveis de ambiente — visão geral

Cada ambiente tem seu próprio `.env` (nunca commitado — veja `.gitignore`). Use o `.env.example` correspondente como ponto de partida (`dev` e `hom` têm; `local` não tem ainda — veja a seção acima). Categorias principais:

- **Domínio/TLS**: `DOMAIN`, `ACME_EMAIL`
- **Banco de dados**: `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `KEYCLOAK_POSTGRES_DB`
- **Keycloak**: `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`
- **RabbitMQ**: `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD`
- **SeaweedFS/S3**: `S3_ACCESS_KEY`, `S3_SECRET_KEY`
- **NASA FIRMS**: `NASA_FIRMS_MAP_KEY` (obtenha em https://firms.modaps.eosdis.nasa.gov/api/area/)
- **Vault AppRole** (só `hom`): `BACKEND_VAULT_ROLE_ID`/`SECRET_ID`, `ATTACHMENT_VAULT_ROLE_ID`/`SECRET_ID`, `FIRE_EVENT_VAULT_ROLE_ID`/`SECRET_ID`
- **Traefik dashboard**: `TRAEFIK_DASHBOARD_USER`, `TRAEFIK_DASHBOARD_PASSWORD_HASH` (hash bcrypt, gerado com `htpasswd -nB admin` — nunca a senha em texto puro)

---

## Vault — como está implementado hoje

- **Autenticação**: AppRole, uma role por serviço (`fortivus-backend`, `fortivus-attachment`, `fortivus-fire-event`), policy `fortivus-services` (`src/infra/hom/vault/policies/fortivus-services.hcl`).
- **Secrets estáticos (em uso)**: KV v2 em `fortivus/{database,keycloak,rabbitmq,storage,nasa-firms}` — os serviços leem isso na inicialização e periodicamente reconferem (`mode=ROTATE` no Spring Cloud Vault, ou seja, se você atualizar o valor no Vault, o serviço pega a mudança sem redeploy).
- **Secrets dinâmicos (configurados, mas não usados ainda)**: Database Secrets Engine do Postgres, com roles e TTL prontos. As aplicações ainda se conectam ao Postgres com a credencial estática `fortivus`, não com `database/creds/{role}`. Migrar para isso é trabalho de código nos repositórios de cada serviço (datasource dinâmico com renovação de lease), não só de infra.
- **RabbitMQ**: não tem secrets engine dinâmica — usa um único usuário estático (`fortivus`, admin total). Isso é intencional/por simplicidade, não um bug.

### ⚠️ Cuidado com nomes de container/rede

Este stack roda na rede Docker `hom_fortivus-network-hom`, compartilhada com o projeto `infra` (Portainer/Jenkins). **Não reutilize o nome de serviço `vault`** (nem `container_name: vault`) em nenhum outro `docker-compose.yml` que se conecte a essa mesma rede — o Docker Compose registra o nome do serviço como alias DNS, e dois containers com o mesmo alias causam resolução de DNS não-determinística (um serviço pode resolver `vault` para o container errado). Isso já aconteceu: o Vault standalone do projeto `infra` colidia com `fortivus-vault-hom` e quebrava silenciosamente a renovação de credenciais do `backend`/`attachment`. Foi corrigido renomeando o serviço standalone para `infra-vault`. A mesma regra vale para qualquer outro nome de serviço genérico (`postgres`, `redis` etc.) que precise coexistir na rede compartilhada.

---

## Licença

Veja [LICENSE](./LICENSE).
