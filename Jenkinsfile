pipeline {
    agent any

    parameters {
        string(name: 'DOMAIN', defaultValue: '', description: 'Dominio publico da VPS (ex: fortivus.xyz)')
    }

    environment {
        COMPOSE_FILE   = 'src/infra/dev/docker-compose.yml'
        ENV_FILE       = 'src/infra/dev/.env'
        WORKSPACE_ROOT = '/var/jenkins_home/workspace'
        ACME_EMAIL     = 'theravishgamer@gmail.com'
        DEPLOY_DOMAIN  = "${params.DOMAIN}"
    }

    stages {

        stage('Validar parametros') {
            steps {
                script {
                    if (!env.DEPLOY_DOMAIN?.trim()) {
                        error 'Parametro DOMAIN e obrigatorio. Ex: fortivus.xyz'
                    }
                    echo "Dominio: ${env.DEPLOY_DOMAIN}"
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Clonar repositorios') {
            steps {
                sh '''#!/bin/bash
                    set -x
                    trap 'sleep 2' EXIT

                    clone_or_pull() {
                        local repo=$1 dir=$2 branch=${3:-main}
                        if [ -d "$dir/.git" ]; then
                            # Verifica se o repo não está corrompido, se estiver, remove
                            if ! git -C "$dir" status > /dev/null 2>&1; then
                                echo "Repositorio corrompido em $dir. Removendo..."
                                rm -rf "$dir"
                            fi
                        fi
                        
                        if [ -d "$dir/.git" ]; then
                            git -C "$dir" fetch origin "$branch"
                            git -C "$dir" checkout "$branch"
                            git -C "$dir" pull origin "$branch"
                        else
                            git clone --depth 1 -b "$branch" "$repo" "$dir"
                        fi
                    }

                    clone_or_pull https://github.com/Fortivus-confessor/fortivus-backend        ${WORKSPACE_ROOT}/fortivus-v2
                    clone_or_pull https://github.com/Fortivus-confessor/attachment-service      ${WORKSPACE_ROOT}/attachment-service
                    clone_or_pull https://github.com/Fortivus-confessor/fire-event-service      ${WORKSPACE_ROOT}/fire-event-service  main
                    clone_or_pull https://github.com/Fortivus-confessor/fire-command-center     ${WORKSPACE_ROOT}/fire-command-center
                    
                    # Evita race condition do Jenkins plugin (Durable Task) em falhas rápidas
                    sleep 2
                '''
            }
        }

        stage('Carregar secrets do Vault') {
            steps {
                withVault(
                    configuration: [
                        vaultUrl: "${VAULT_ADDR}",
                        vaultCredentialId: 'vault-approle',
                        engineVersion: 2
                    ],
                    vaultSecrets: [
                        // Secrets para containers de infraestrutura (PostgreSQL, Keycloak, RabbitMQ)
                        [path: 'fortivus/database',   engineVersion: 2, secretValues: [
                            [envVar: 'POSTGRES_USER',         vaultKey: 'POSTGRES_USER'],
                            [envVar: 'POSTGRES_PASSWORD',     vaultKey: 'POSTGRES_PASSWORD'],
                            [envVar: 'POSTGRES_DB',           vaultKey: 'POSTGRES_DB'],
                            [envVar: 'KEYCLOAK_POSTGRES_DB',  vaultKey: 'keycloak_database'],
                        ]],
                        [path: 'fortivus/keycloak',   engineVersion: 2, secretValues: [
                            [envVar: 'KEYCLOAK_ADMIN',          vaultKey: 'KEYCLOAK_ADMIN'],
                            [envVar: 'KEYCLOAK_ADMIN_PASSWORD', vaultKey: 'KEYCLOAK_ADMIN_PASSWORD'],
                        ]],
                        [path: 'fortivus/rabbitmq',   engineVersion: 2, secretValues: [
                            [envVar: 'RABBITMQ_USERNAME', vaultKey: 'RABBITMQ_USERNAME'],
                            [envVar: 'RABBITMQ_PASSWORD', vaultKey: 'RABBITMQ_PASSWORD'],
                        ]],
                        // AppRole para que os servicos Spring se autentiquem no Vault em runtime
                        [path: 'fortivus/approle',    engineVersion: 2, secretValues: [
                            [envVar: 'SVC_VAULT_ROLE_ID',   vaultKey: 'role_id'],
                            [envVar: 'SVC_VAULT_SECRET_ID', vaultKey: 'secret_id'],
                        ]],
                    ]
                ) {
                    sh """
                        {
                        printf "%s='%s'\\n" 'POSTGRES_USER'           "\${POSTGRES_USER}"
                        printf "%s='%s'\\n" 'POSTGRES_PASSWORD'       "\${POSTGRES_PASSWORD}"
                        printf "%s='%s'\\n" 'POSTGRES_DB'             "\${POSTGRES_DB}"
                        printf "%s='%s'\\n" 'KEYCLOAK_POSTGRES_DB'    "\${KEYCLOAK_POSTGRES_DB}"
                        printf "%s='%s'\\n" 'KEYCLOAK_ADMIN'          "\${KEYCLOAK_ADMIN}"
                        printf "%s='%s'\\n" 'KEYCLOAK_ADMIN_PASSWORD' "\${KEYCLOAK_ADMIN_PASSWORD}"
                        printf "%s='%s'\\n" 'RABBITMQ_USERNAME'       "\${RABBITMQ_USERNAME}"
                        printf "%s='%s'\\n" 'RABBITMQ_PASSWORD'       "\${RABBITMQ_PASSWORD}"
                        printf "%s='%s'\\n" 'VAULT_ROLE_ID'           "\${SVC_VAULT_ROLE_ID}"
                        printf "%s='%s'\\n" 'VAULT_SECRET_ID'         "\${SVC_VAULT_SECRET_ID}"
                        printf "%s='%s'\\n" 'VAULT_ADDR'              "http://host.docker.internal:8200"
                        printf "%s='%s'\\n" 'DOMAIN'                  "\${DEPLOY_DOMAIN}"
                        printf "%s='%s'\\n" 'ACME_EMAIL'              "\${ACME_EMAIL}"
                        } > "\${ENV_FILE}"
                        echo "Arquivo .env gerado para dominio: \${DEPLOY_DOMAIN}"
                    """
                }
            }
        }

        stage('Build e Deploy') {
            steps {
                sh 'docker compose -f ${COMPOSE_FILE} --env-file ${ENV_FILE} up -d --build'
            }
        }

        stage('Healthcheck') {
            steps {
                sh 'docker compose -f ${COMPOSE_FILE} ps'
            }
        }
    }

    post {
        always {
            sh 'rm -f ${ENV_FILE}'
        }
        failure {
            echo 'Deploy falhou. Verifique os logs acima.'
        }
        success {
            echo "Deploy concluido com sucesso em https://${env.DEPLOY_DOMAIN}"
        }
    }
}
