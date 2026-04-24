-- Migracion: configuracion tributaria por empresa + snapshot en PDT621
-- Se ejecuta automaticamente al reiniciar el backend via Base.metadata.create_all.
-- Solo corre esto a mano si tienes problemas con la creacion automatica.

-- 1. Snapshot en PDT621 (no afecta registros existentes, queda en NULL)
ALTER TABLE pdt621s ADD COLUMN IF NOT EXISTS config_snapshot JSONB;

-- 2. Tabla de configuracion tributaria
CREATE TABLE IF NOT EXISTS configuracion_tributaria_empresa (
    id                              SERIAL PRIMARY KEY,
    empresa_id                      INTEGER NOT NULL UNIQUE REFERENCES empresas(id) ON DELETE CASCADE,

    uit                             NUMERIC(10,2) DEFAULT 5350.00 NOT NULL,
    tasa_igv                        NUMERIC(5,4)  DEFAULT 0.1800 NOT NULL,
    rg_coef_minimo                  NUMERIC(5,4)  DEFAULT 0.0150 NOT NULL,
    rg_renta_anual                  NUMERIC(5,4)  DEFAULT 0.2950 NOT NULL,
    rmt_tramo1_tasa                 NUMERIC(5,4)  DEFAULT 0.0100 NOT NULL,
    rmt_tramo1_limite_uit           NUMERIC(8,2)  DEFAULT 300.00 NOT NULL,
    rmt_tramo2_coef_minimo          NUMERIC(5,4)  DEFAULT 0.0150 NOT NULL,
    rmt_renta_anual_hasta15uit      NUMERIC(5,4)  DEFAULT 0.1000 NOT NULL,
    rmt_renta_anual_resto           NUMERIC(5,4)  DEFAULT 0.2950 NOT NULL,
    rer_tasa                        NUMERIC(5,4)  DEFAULT 0.0150 NOT NULL,
    nrus_cat1                       NUMERIC(8,2)  DEFAULT 20.00 NOT NULL,
    nrus_cat2                       NUMERIC(8,2)  DEFAULT 50.00 NOT NULL,

    campos_rvie                     JSONB,
    campos_rce                      JSONB,

    fecha_creacion                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modificado_por_usuario_id       INTEGER REFERENCES usuarios(id)
);

CREATE INDEX IF NOT EXISTS idx_config_tributaria_empresa ON configuracion_tributaria_empresa(empresa_id);
