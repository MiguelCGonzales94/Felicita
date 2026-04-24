-- Migracion manual: agregar campos de credenciales SUNAT
-- Ejecutar en pgAdmin o psql

ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS tipo_acceso_sol VARCHAR(10) DEFAULT 'RUC',
  ADD COLUMN IF NOT EXISTS dni_sol VARCHAR(8),
  ADD COLUMN IF NOT EXISTS sunat_client_id_encrypted TEXT,
  ADD COLUMN IF NOT EXISTS sunat_client_secret_encrypted TEXT;

-- Actualizar registros existentes
UPDATE empresas SET tipo_acceso_sol = 'RUC' WHERE tipo_acceso_sol IS NULL;
