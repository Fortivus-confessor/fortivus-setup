# Vault Policy — fortivus-services
# Permite que os serviços da aplicação leiam secrets do path fortivus/*
# Aplicada a todos os AppRoles: fortivus-backend, fortivus-attachment, fortivus-fire-event

# Leitura de todos os secrets do namespace fortivus
path "fortivus/data/*" {
  capabilities = ["read"]
}

# Listagem de paths (necessário para Spring Cloud Vault descobrir secrets)
path "fortivus/metadata/*" {
  capabilities = ["list", "read"]
}

# Renovação do próprio token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Lookup do próprio token (health check do Spring Cloud Vault)
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Credenciais dinâmicas do Postgres (Database Secrets Engine)
path "database/creds/*" {
  capabilities = ["read"]
}
