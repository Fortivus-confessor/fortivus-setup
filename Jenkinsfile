pipeline {
    agent any

    parameters {
        string(name: 'VPS_HOST', defaultValue: '', description: 'IP ou dominio publico da VPS (ex: 192.168.1.100)')
    }

    environment {
        COMPOSE_FILE   = 'src/infra/dev/docker-compose.yml'
        ENV_FILE       = 'src/infra/dev/.env'
        WORKSPACE_ROOT = '/var/jenkins_home/workspace'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Clonar repositorios') {
            steps {
                sh '''
                    clone_or_pull() {
                        local repo=$1 dir=$2 branch=${3:-main}
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
                    clone_or_pull https://github.com/Fortivus-confessor/fire-event-service      ${WORKSPACE_ROOT}/fire-event-service  feature/role-permissions
                    clone_or_pull https://github.com/Fortivus-confessor/fire-command-center     ${WORKSPACE_ROOT}/fire-command-center
                '''
            }
        }

        stage('Carregar secrets do Vault') {
            steps {
                withVault(
                    configuration: [
                        vaultUrl: "${VAULT_ADDR}",
                        vaultCredentialId: 'vault-token'
                    ],
                    vaultSecrets: [
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
                        [path: 'fortivus/storage',    engineVersion: 2, secretValues: [
                            [envVar: 'S3_ACCESS_KEY', vaultKey: 'S3_ACCESS_KEY'],
                            [envVar: 'S3_SECRET_KEY', vaultKey: 'S3_SECRET_KEY'],
                        ]],
                        [path: 'fortivus/nasa-firms', engineVersion: 2, secretValues: [
                            [envVar: 'NASA_FIRMS_MAP_KEY', vaultKey: 'NASA_FIRMS_MAP_KEY'],
                        ]],
                    ]
                ) {
                    sh """
                        python3 -c "
import os
entries = [
    ('POSTGRES_USER',         os.environ['POSTGRES_USER']),
    ('POSTGRES_PASSWORD',     os.environ['POSTGRES_PASSWORD']),
    ('POSTGRES_DB',           os.environ['POSTGRES_DB']),
    ('KEYCLOAK_POSTGRES_DB',  os.environ['KEYCLOAK_POSTGRES_DB']),
    ('KEYCLOAK_ADMIN',        os.environ['KEYCLOAK_ADMIN']),
    ('KEYCLOAK_ADMIN_PASSWORD', os.environ['KEYCLOAK_ADMIN_PASSWORD']),
    ('RABBITMQ_USERNAME',     os.environ['RABBITMQ_USERNAME']),
    ('RABBITMQ_PASSWORD',     os.environ['RABBITMQ_PASSWORD']),
    ('S3_ACCESS_KEY',         os.environ['S3_ACCESS_KEY']),
    ('S3_SECRET_KEY',         os.environ['S3_SECRET_KEY']),
    ('NASA_FIRMS_MAP_KEY',    os.environ['NASA_FIRMS_MAP_KEY']),
    ('VPS_HOST',              '${params.VPS_HOST}'),
]
with open('${ENV_FILE}', 'w') as f:
    for k, v in entries:
        f.write(f'{k}={v}\\n')
print('Arquivo .env gerado com sucesso.')
"
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
            echo 'Deploy concluido com sucesso.'
        }
    }
}
