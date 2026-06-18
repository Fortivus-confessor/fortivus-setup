# Fortivus - Gestão de Combate a Incêndios Florestais

Sistema moderno orientado a microsserviços para monitoramento, detecção e resposta a incêndios florestais.

## 🚀 Como Iniciar (Ambiente Local)

### 1. Configurar Variáveis
Certifique-se de que possui o arquivo `.env` na pasta `src/infra/local/` (ou configuradas diretamente no seu ambiente).

### 2. Startup
O ambiente completo é orquestrado via Docker Compose.
Para subir todos os serviços e recompilar o código fonte das APIs em Java simultaneamente:
```bash
docker-compose -f src/infra/local/docker-compose.yml up -d --build
```

---

## 🌐 Links Rápidos (Acessos Locais)

O projeto usa o **Traefik** como proxy reverso na porta `8000`. Isso significa que a maioria das APIs e o Frontend passam por ele.

### 🛡️ Aplicações Principais
*   **Frontend (Centro de Comando SPA):** [http://localhost:8000/](http://localhost:8000/)
*   **Fortivus V2 (API Backend Core):** `http://localhost:8000/combate` (Ou porta direta: `8080`)
*   **Fire Event Service (API Ingestão NASA):** `http://localhost:8000/api/v1/fire-events` (Ou porta direta: `8084`)

### 🛠️ Ferramentas de Infraestrutura e Monitoramento
*   **Traefik Dashboard:** [http://localhost:8080](http://localhost:8080) (Métricas de roteamento da infra)
*   **RabbitMQ Management:** [http://localhost:15672](http://localhost:15672) (Credenciais: `guest` / `guest`)
*   **Keycloak (Autenticação):** [http://localhost:9000](http://localhost:9000) (Admin local: `admin` / `admin`)
*   **Grafana (Dashboards e Logs):** [http://localhost:3000](http://localhost:3000)
*   **Martin (Tile Server GIS):** [http://localhost:3001](http://localhost:3001)

### 💾 Bancos de Dados (Conexão via SGBD/DBeaver)
*   **PostgreSQL / PostGIS:** `localhost:5432` 
*   **Redis:** `localhost:6379`

---

## 🏗️ Catálogo de Microsserviços e Contêineres

Abaixo está o detalhamento da função de cada serviço ativo no ecossistema atual:

### 1. Core e Negócios
*   **`backend` (Fortivus V2):** É o monolito/ERP central. Gerencia as Ordens de Serviço, recursos logísticos, combatentes e o ciclo de vida da extinção do fogo. É ele quem "escuta" os alertas severos que chegam do RabbitMQ.
*   **`fire-event-service`:** Microsserviço focado em motor de regras espaciais. Busca focos de calor na API da NASA FIRMS, faz clusterização matemática via PostGIS e calcula a severidade por energia radiativa (FRP). Se crítico, dispara o alerta de mensageria.
*   **`frontend` (Centro de Comando):** Interface web desenvolvida em React. Consome o Backend e exibe mapas táticos, cria chamados e mostra o placar em tempo real ao operador na sala de situação.

### 2. Infraestrutura de Apoio
*   **`attachment-service`:** Microsserviço especializado em upload, compressão e tratamento de imagens e documentos probatórios atrelados às ocorrências.
*   **`auth` (Keycloak):** Servidor de Identidade e Acesso (IAM). Cuida dos cadastros de usuários, RBAC (Role-Based Access Control) e emite os tokens JWT de autenticação para as APIs.
*   **`rabbitmq`:** Message Broker. Orquestra a comunicação assíncrona, desacoplando os sistemas (Ex: `fire-event` manda o alerta sem se importar se o `backend` está rápido ou devagar no momento).

### 3. Persistência de Dados
*   **`postgres`:** Banco de Dados relacional central do projeto. Com a extensão PostGIS ativada de fábrica, realiza os cálculos espaciais de raio, distâncias e intersecções. Cada serviço usa um "Schema" isolado dele.
*   **`redis`:** Armazenamento em memória (cache) ultra-rápido usado para tokens de sessão, limites de taxa (rate-limiting) e entidades pesadas do backend.
*   **`seaweedfs`:** Object Storage (compatível com S3). Onde os arquivos binários pesados (imagens enviadas ao `attachment-service`) ficam guardados, imitando a infra da AWS.
*   **`martin`:** Servidor ultraleve escrito em Rust para transformar as geometrias do PostGIS em blocos desenháveis de mapa, entregando direto para o Frontend via protocolo MVT.

### 4. Observabilidade (Logging)
*   **`loki`:** Banco de dados de série temporal construído especialmente para guardar strings de texto (Logs).
*   **`promtail`:** "Agente de campo". Ele lê o arquivo de log console de todos os outros contêineres Docker da máquina e despacha centralizadamente para o Loki.
*   **`grafana`:** Painel de controle visual onde o arquiteto pode cruzar logs, ver qual microsserviço está caindo e acompanhar a performance em tempo real.

### 5. Proxy
*   **`traefik`:** O portão de entrada do projeto inteiro. Ele recebe todo o tráfego HTTP na porta `8000` e decide, com base no prefixo da URL (ex: `/combate` ou `/api`), para qual contêiner Docker deve redirecionar o acesso sem expor suas portas originais.
