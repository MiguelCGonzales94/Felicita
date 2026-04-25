-- Migracion consolidada: notificaciones + consulta SUNAT
CREATE TABLE IF NOT EXISTS notificaciones_pago (
    id                  SERIAL PRIMARY KEY,
    empresa_id          INTEGER NOT NULL REFERENCES empresas(id) ON DELETE CASCADE,
    contador_id         INTEGER NOT NULL REFERENCES usuarios(id),
    ano                 INTEGER NOT NULL,
    mes                 INTEGER NOT NULL,
    igv_a_pagar         NUMERIC(15,2) DEFAULT 0,
    renta_a_pagar       NUMERIC(15,2) DEFAULT 0,
    total_a_pagar       NUMERIC(15,2) DEFAULT 0,
    fecha_vencimiento   DATE NOT NULL,
    enviado_app         BOOLEAN DEFAULT FALSE,
    enviado_email       BOOLEAN DEFAULT FALSE,
    enviado_whatsapp    BOOLEAN DEFAULT FALSE,
    leido               BOOLEAN DEFAULT FALSE,
    fecha_envio         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_lectura       TIMESTAMP,
    titulo              VARCHAR(255) NOT NULL,
    mensaje             TEXT,
    tipo                VARCHAR(30) DEFAULT 'PAGO_MENSUAL'
);
CREATE INDEX IF NOT EXISTS idx_notif_pago_contador ON notificaciones_pago(contador_id);
CREATE INDEX IF NOT EXISTS idx_notif_pago_empresa ON notificaciones_pago(empresa_id);
