# Guia de Configuração CI/CD - Fortivus

Este guia explica como configurar o deploy automático para o seu servidor online utilizando GitHub Actions.

## 1. Configuração do Servidor

1. Clone o repositório no servidor no diretório `/opt/fortivus-setup`:
   ```bash
   sudo mkdir -p /opt/fortivus-setup
   sudo chown $USER:$USER /opt/fortivus-setup
   git clone <URL_DO_REPOSITORIO> /opt/fortivus-setup
   ```
2. Certifique-se de que o Docker e o Docker Compose estão instalados.

## 2. Configuração do GitHub Secrets

No seu repositório no GitHub, vá em **Settings > Secrets and variables > Actions** e adicione os seguintes segredos:

| Nome do Secret | Descrição | Exemplo |
| :--- | :--- | :--- |
| `SERVER_HOST_DEV` | IP do servidor de Desenvolvimento (branch main) | `69.62.97.237` |
| `SERVER_HOST_HOM` | IP do servidor de Homologação (branch hom) | `69.62.97.238` |
| `SERVER_USER` | Usuário SSH do servidor (comum a ambos) | `root` |
| `SSH_PRIVATE_KEY` | Sua chave privada SSH | `-----BEGIN RSA PRIVATE KEY-----...` |
| `DB_USER` | Usuário administrador do Postgres | `fortivus_admin` |
| `DB_PASSWORD` | Senha forte para o Postgres | `senha_super_secreta_2026` |
| `DOMAIN` | Seu domínio principal para o sistema | `fortivus.meu-tcc.com` |
| `ACME_EMAIL` | Email para registro do certificado SSL | `admin@meu-tcc.com` |
| `VAULT_ROLE_ID` | Role ID gerado pelo setup-vault.sh | `uuid-do-vault` |
| `VAULT_SECRET_ID` | Secret ID gerado pelo setup-vault.sh | `uuid-secreto-do-vault` |

## 3. Fluxo de Trabalho (Workflow)

O sistema diferencia o deploy pelo nome da branch:
- **Branch `main`**: Faz o deploy no servidor DEV usando `docker-compose-dev.yml`.
- **Branch `hom`**: Faz o deploy no servidor HOM usando `docker-compose-hom.yml`.

---
*Nota: Para produção real, recomenda-se adicionar um Reverse Proxy (Nginx ou Traefik) na frente do ZITADEL para gerenciar certificados SSL (HTTPS).*
