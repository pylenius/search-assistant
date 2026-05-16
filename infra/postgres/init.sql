-- Runs once on first container start (postgres entrypoint executes /docker-entrypoint-initdb.d/*.sql).
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
