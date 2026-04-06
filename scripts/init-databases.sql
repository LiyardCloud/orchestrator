-- Auto-run by postgres on first container startup (docker-entrypoint-initdb.d).
-- Add one line per service database. Safe to re-run: CREATE IF NOT EXISTS is idempotent.

SELECT 'CREATE DATABASE dataroom_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'dataroom_db')\gexec

-- SELECT 'CREATE DATABASE journal_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'journal_db')\gexec
