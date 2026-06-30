ui = true

# Desabilita o mlock (necessário em containers sem CAP_IPC_LOCK total)
# A imagem Docker do Vault tem setuid, mas disable_mlock é necessário para evitar
# falhas em ambientes que não permitem mlocking de memória.
disable_mlock = true

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr     = "http://vault:8200"
cluster_addr = "http://vault:8201"
