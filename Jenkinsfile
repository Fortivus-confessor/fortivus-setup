pipeline {
    agent any

    environment {
        COMPOSE_FILE = 'src/infra/dev/docker-compose.yml'
        ENV_FILE     = 'src/infra/dev/.env'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
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
                        [path: 'secret/fortivus/database',   secretValues: [
                            [envVar: 'POSTGRES_USER',         vaultKey: 'POSTGRES_USER'],
                            [envVar: 'POSTGRES_PASSWORD',     vaultKey: 'POSTGRES_PASSWORD'],
                            [envVar: 'POSTGRES_DB',           vaultKey: 'POSTGRES_DB'],
                            [envVar: 'KEYCLOAK_POSTGRES_DB',  vaultKey: 'keycloak_database'],
                        ]],
                        [path: 'secret/fortivus/keycloak',   secretValues: [
                            [envVar: 'KEYCLOAK_ADMIN',          vaultKey: 'KEYCLOAK_ADMIN'],
                            [envVar: 'KEYCLOAK_ADMIN_PASSWORD', vaultKey: 'KEYCLOAK_ADMIN_PASSWORD'],
                        ]],
                        [path: 'secret/fortivus/rabbitmq',   secretValues: [
                            [envVar: 'RABBITMQ_USERNAME', vaultKey: 'RABBITMQ_USERNAME'],
                            [envVar: 'RABBITMQ_PASSWORD', vaultKey: 'RABBITMQ_PASSWORD'],
                        ]],
                        [path: 'secret/fortivus/storage',    secretValues: [
                            [envVar: 'S3_ACCESS_KEY', vaultKey: 'S3_ACCESS_KEY'],
                            [envVar: 'S3_SECRET_KEY', vaultKey: 'S3_SECRET_KEY'],
                        ]],
                        [path: 'secret/fortivus/nasa-firms', secretValues: [
                            [envVar: 'NASA_FIRMS_MAP_KEY', vaultKey: 'NASA_FIRMS_MAP_KEY'],
                        ]],
                    ]
                ) {
                    sh '''
                        cat > ${ENV_FILE} <<EOF
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB}
KEYCLOAK_POSTGRES_DB=${KEYCLOAK_POSTGRES_DB}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}
RABBITMQ_USERNAME=${RABBITMQ_USERNAME}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
S3_ACCESS_KEY=${S3_ACCESS_KEY}
S3_SECRET_KEY=${S3_SECRET_KEY}
NASA_FIRMS_MAP_KEY=${NASA_FIRMS_MAP_KEY}
EOF
                    '''
                }
            }
        }

        stage('Build e Deploy') {
            steps {
                sh 'docker compose -f ${COMPOSE_FILE} --env-file ${ENV_FILE} pull --ignore-pull-failures || true'
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
