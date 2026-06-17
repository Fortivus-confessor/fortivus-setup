-- Script de Inicialização Mestre (Ambiente Local Zero)
-- Este script roda apenas no primeiro boot do banco de dados

-- 1. Criar Banco do Keycloak (Identidade)
CREATE DATABASE keycloak;

-- 2. Criar Banco do FORTIVUS (Core Business)
CREATE DATABASE fortivus;

-- 3. Habilitar extensões no banco do FORTIVUS
\c fortivus
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
