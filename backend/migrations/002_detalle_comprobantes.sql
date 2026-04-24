-- Migracion: detalle de comprobantes RVIE/RCE para el PDT 621
-- Se ejecuta automaticamente al reiniciar el backend (Base.metadata.create_all),
-- pero si prefieres ejecutarlo manualmente desde pgAdmin o psql, aqui esta.

CREATE TABLE IF NOT EXISTS pdt621_ventas_detalle (
    id                     SERIAL PRIMARY KEY,
    pdt621_id              INTEGER NOT NULL REFERENCES pdt621s(id) ON DELETE CASCADE,
    tipo_comprobante       VARCHAR(4) NOT NULL,
    serie                  VARCHAR(10) NOT NULL,
    numero                 VARCHAR(20) NOT NULL,
    fecha_emision          DATE NOT NULL,
    ruc_cliente            VARCHAR(11),
    razon_social_cliente   VARCHAR(255) NOT NULL,
    base_gravada           NUMERIC(15,2) DEFAULT 0,
    base_no_gravada        NUMERIC(15,2) DEFAULT 0,
    exportacion            NUMERIC(15,2) DEFAULT 0,
    igv                    NUMERIC(15,2) DEFAULT 0,
    total                  NUMERIC(15,2) NOT NULL,
    incluido               BOOLEAN DEFAULT TRUE NOT NULL,
    fuente                 VARCHAR(20) DEFAULT 'SUNAT_SIRE',
    fecha_importacion      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pdt621_ventas_detalle_pdt ON pdt621_ventas_detalle(pdt621_id);

CREATE TABLE IF NOT EXISTS pdt621_compras_detalle (
    id                       SERIAL PRIMARY KEY,
    pdt621_id                INTEGER NOT NULL REFERENCES pdt621s(id) ON DELETE CASCADE,
    tipo_comprobante         VARCHAR(4) NOT NULL,
    serie                    VARCHAR(10) NOT NULL,
    numero                   VARCHAR(20) NOT NULL,
    fecha_emision            DATE NOT NULL,
    ruc_proveedor            VARCHAR(11),
    razon_social_proveedor   VARCHAR(255) NOT NULL,
    base_gravada             NUMERIC(15,2) DEFAULT 0,
    base_no_gravada          NUMERIC(15,2) DEFAULT 0,
    igv                      NUMERIC(15,2) DEFAULT 0,
    total                    NUMERIC(15,2) NOT NULL,
    tipo_destino             VARCHAR(30) DEFAULT 'GRAVADA_EXCLUSIVA',
    incluido                 BOOLEAN DEFAULT TRUE NOT NULL,
    fuente                   VARCHAR(20) DEFAULT 'SUNAT_SIRE',
    fecha_importacion        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pdt621_compras_detalle_pdt ON pdt621_compras_detalle(pdt621_id);
