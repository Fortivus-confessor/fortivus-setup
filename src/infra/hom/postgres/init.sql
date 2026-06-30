-- Script de Inicialização do PostgreSQL — Fortivus HOM
-- Executado apenas na primeira inicialização do container.

-- 1. Banco de dados do Keycloak
CREATE DATABASE keycloak;

-- 2. Extensões no banco principal do Fortivus
-- (PostGIS já é habilitado automaticamente pela imagem postgis/postgis no POSTGRES_DB)
\c fortivus
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
