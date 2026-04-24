# ============================================================
#  FELICITA - Entrega 1 Parte A: Modelos + Mock SIRE realista
#  Agrega tablas pdt621_ventas_detalle y pdt621_compras_detalle
#  Actualiza el mock SIRE para generar comprobantes persistibles
#  Uso: .\entrega1a_detalle_comprobantes_modelos.ps1
# ============================================================

Write-Host ""
Write-Host "Entrega 1 - Parte A: Modelos + Mock SIRE realista" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# 1. models/models.py - Agregar modelos PDT621VentaDetalle y PDT621CompraDetalle
# ============================================================

Write-Host "Agregando modelos de detalle de comprobantes..." -ForegroundColor Yellow

$modelsPath = "backend/app/models/models.py"
$modelsContent = Get-Content $modelsPath -Raw

if ($modelsContent -match "class PDT621VentaDetalle") {
    Write-Host "  [SKIP] Modelos ya existen" -ForegroundColor Gray
} else {

$nuevosModelos = @'


# ════════════════════════════════════════════════════════════
# DETALLE DE COMPROBANTES IMPORTADOS DESDE SIRE
# Un registro por comprobante descargado. Permite al contador
# marcar/desmarcar cuales entran al calculo del PDT.
# ════════════════════════════════════════════════════════════

class PDT621VentaDetalle(Base):
    __tablename__ = "pdt621_ventas_detalle"

    id = Column(Integer, primary_key=True, index=True)
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="CASCADE"), nullable=False, index=True)

    # Datos del comprobante (RVIE)
    tipo_comprobante = Column(String(4), nullable=False)      # 01=Factura, 03=Boleta, 07=NC, 08=ND
    serie = Column(String(10), nullable=False)
    numero = Column(String(20), nullable=False)
    fecha_emision = Column(Date, nullable=False)
    ruc_cliente = Column(String(11))
    razon_social_cliente = Column(String(255), nullable=False)

    # Importes
    base_gravada = Column(Numeric(15, 2), default=0)
    base_no_gravada = Column(Numeric(15, 2), default=0)
    exportacion = Column(Numeric(15, 2), default=0)
    igv = Column(Numeric(15, 2), default=0)
    total = Column(Numeric(15, 2), nullable=False)

    # Control
    incluido = Column(Boolean, default=True, nullable=False)  # Si entra al calculo
    fuente = Column(String(20), default="SUNAT_SIRE")         # SUNAT_SIRE o MOCK
    fecha_importacion = Column(DateTime, default=datetime.utcnow)

    # Relacion
    pdt621 = relationship("PDT621", back_populates="ventas_detalle")


class PDT621CompraDetalle(Base):
    __tablename__ = "pdt621_compras_detalle"

    id = Column(Integer, primary_key=True, index=True)
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="CASCADE"), nullable=False, index=True)

    # Datos del comprobante (RCE)
    tipo_comprobante = Column(String(4), nullable=False)
    serie = Column(String(10), nullable=False)
    numero = Column(String(20), nullable=False)
    fecha_emision = Column(Date, nullable=False)
    ruc_proveedor = Column(String(11))
    razon_social_proveedor = Column(String(255), nullable=False)

    # Importes
    base_gravada = Column(Numeric(15, 2), default=0)
    base_no_gravada = Column(Numeric(15, 2), default=0)
    igv = Column(Numeric(15, 2), default=0)
    total = Column(Numeric(15, 2), nullable=False)

    # Clasificacion del credito (para casos mixtos)
    # GRAVADA_EXCLUSIVA, GRAVADA_Y_NO_GRAVADA, NO_GRAVADA_EXCLUSIVA
    tipo_destino = Column(String(30), default="GRAVADA_EXCLUSIVA")

    # Control
    incluido = Column(Boolean, default=True, nullable=False)
    fuente = Column(String(20), default="SUNAT_SIRE")
    fecha_importacion = Column(DateTime, default=datetime.utcnow)

    # Relacion
    pdt621 = relationship("PDT621", back_populates="compras_detalle")
'@

    # Agregar al final del archivo
    $modelsContent = $modelsContent.TrimEnd() + "`r`n" + $nuevosModelos + "`r`n"

    # Agregar back_populates en PDT621 (buscar definicion de la clase)
    $pdtRelPattern = "class PDT621\(Base\):"
    if ($modelsContent -match $pdtRelPattern) {
        # Agregar relaciones al final de PDT621 (antes de la siguiente clase o EOF).
        # Estrategia: buscar "class PDT621" y agregar las relaciones dentro.
        # Usaremos marker: si existe "detalles = relationship" despues lo extendemos.
        if ($modelsContent -notmatch "ventas_detalle\s*=\s*relationship") {
            $rel = @'

    # Relaciones con el detalle de comprobantes
    ventas_detalle = relationship("PDT621VentaDetalle", back_populates="pdt621", cascade="all, delete-orphan")
    compras_detalle = relationship("PDT621CompraDetalle", back_populates="pdt621", cascade="all, delete-orphan")
'@
            # Insertar justo despues de la ultima columna de PDT621.
            # Heuristica: buscamos la clase PDT621 completa y le agregamos las relaciones
            # antes de la siguiente "class " o al final.
            $regex = [regex]'(class PDT621\(Base\):[\s\S]*?)(?=\r?\nclass |\Z)'
            $match = $regex.Match($modelsContent)
            if ($match.Success) {
                $bloque = $match.Value.TrimEnd() + "`r`n" + $rel + "`r`n"
                $modelsContent = $modelsContent.Replace($match.Value, $bloque)
            }
        }
    }

    Set-Content $modelsPath $modelsContent -NoNewline
    Write-Host "  [OK] models.py actualizado con PDT621VentaDetalle y PDT621CompraDetalle" -ForegroundColor Green
}

# ============================================================
# 2. Script SQL de migracion
# ============================================================

Write-Host ""
Write-Host "Creando script de migracion SQL..." -ForegroundColor Yellow

$migracionSql = @'
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
'@

New-Item -ItemType Directory -Force -Path "backend/migrations" | Out-Null
Set-Content "backend/migrations/002_detalle_comprobantes.sql" $migracionSql
Write-Host "  [OK] backend/migrations/002_detalle_comprobantes.sql" -ForegroundColor Green

# ============================================================
# 3. services/sire_service.py - Mock mejorado y realista
# ============================================================

Write-Host ""
Write-Host "Reescribiendo sire_service.py con mock realista..." -ForegroundColor Yellow

@'
"""
Servicio SIRE - Wrapper principal.

Estrategia:
- Si la empresa tiene credenciales API SUNAT configuradas, intenta descarga real.
- Si falla o no tiene credenciales, usa datos mock (para desarrollo).
- Retorna estructura identica en ambos casos.
"""
from typing import Optional, List
from pydantic import BaseModel
from datetime import date
from decimal import Decimal
import random
import logging

from app.services.sire_client import SireClient, SIREError

logger = logging.getLogger(__name__)


# ── Schemas ─────────────────────────────────────────
class ComprobanteImportado(BaseModel):
    tipo_comprobante: str
    serie: str
    numero: str
    fecha_emision: str
    ruc_contraparte: Optional[str] = None
    nombre_contraparte: str
    base_gravada: Decimal = Decimal("0")
    igv: Decimal = Decimal("0")
    base_no_gravada: Decimal = Decimal("0")
    exportacion: Decimal = Decimal("0")
    total: Decimal


class ResumenRVIE(BaseModel):
    periodo_ano: int
    periodo_mes: int
    total_comprobantes: int
    total_ventas_gravadas: Decimal
    total_ventas_no_gravadas: Decimal
    total_exportaciones: Decimal
    total_ventas_exoneradas: Decimal
    total_igv_debito: Decimal
    total_general: Decimal
    comprobantes: List[ComprobanteImportado]
    fuente: str = "MOCK"


class ResumenRCE(BaseModel):
    periodo_ano: int
    periodo_mes: int
    total_comprobantes: int
    total_compras_gravadas: Decimal
    total_compras_no_gravadas: Decimal
    total_igv_credito: Decimal
    total_general: Decimal
    comprobantes: List[ComprobanteImportado]
    fuente: str = "MOCK"


# ── API publica ─────────────────────────────────────
def descargar_rvie(empresa_ruc: str, ano: int, mes: int, credenciales: Optional[dict] = None) -> ResumenRVIE:
    """Descarga el Registro de Ventas Electronico."""
    if credenciales and _tiene_credenciales(credenciales):
        try:
            return _descargar_rvie_real(empresa_ruc, ano, mes, credenciales)
        except SIREError as e:
            logger.warning(f"SIRE real fallo, usando mock: {e}")
    return _generar_rvie_mock(empresa_ruc, ano, mes)


def descargar_rce(empresa_ruc: str, ano: int, mes: int, credenciales: Optional[dict] = None) -> ResumenRCE:
    """Descarga el Registro de Compras Electronico."""
    if credenciales and _tiene_credenciales(credenciales):
        try:
            return _descargar_rce_real(empresa_ruc, ano, mes, credenciales)
        except SIREError as e:
            logger.warning(f"SIRE real fallo, usando mock: {e}")
    return _generar_rce_mock(empresa_ruc, ano, mes)


def _tiene_credenciales(cred: dict) -> bool:
    return bool(
        cred.get("client_id")
        and cred.get("client_secret")
        and cred.get("clave_sol")
    )


# ── Descarga real via SireClient ─────────────────────
def _descargar_rvie_real(ruc: str, ano: int, mes: int, cred: dict) -> ResumenRVIE:
    client = SireClient(
        client_id=cred["client_id"],
        client_secret=cred["client_secret"],
        ruc=cred["ruc"],
        usuario=cred.get("usuario", ""),
        clave_sol=cred["clave_sol"],
    )
    periodo = f"{ano:04d}{mes:02d}"
    data = client.descargar_propuesta_rvie(periodo)
    comprobantes = [ComprobanteImportado(**c) for c in data["comprobantes"]]
    return ResumenRVIE(
        periodo_ano=data["periodo_ano"],
        periodo_mes=data["periodo_mes"],
        total_comprobantes=data["total_comprobantes"],
        total_ventas_gravadas=Decimal(str(data["total_ventas_gravadas"])),
        total_ventas_no_gravadas=Decimal(str(data["total_ventas_no_gravadas"])),
        total_exportaciones=Decimal(str(data["total_exportaciones"])),
        total_ventas_exoneradas=Decimal(str(data.get("total_ventas_exoneradas", 0))),
        total_igv_debito=Decimal(str(data["total_igv_debito"])),
        total_general=Decimal(str(data["total_general"])),
        comprobantes=comprobantes,
        fuente="SUNAT_SIRE",
    )


def _descargar_rce_real(ruc: str, ano: int, mes: int, cred: dict) -> ResumenRCE:
    client = SireClient(
        client_id=cred["client_id"],
        client_secret=cred["client_secret"],
        ruc=cred["ruc"],
        usuario=cred.get("usuario", ""),
        clave_sol=cred["clave_sol"],
    )
    periodo = f"{ano:04d}{mes:02d}"
    data = client.descargar_propuesta_rce(periodo)
    comprobantes = [ComprobanteImportado(**c) for c in data["comprobantes"]]
    return ResumenRCE(
        periodo_ano=data["periodo_ano"],
        periodo_mes=data["periodo_mes"],
        total_comprobantes=data["total_comprobantes"],
        total_compras_gravadas=Decimal(str(data["total_compras_gravadas"])),
        total_compras_no_gravadas=Decimal(str(data["total_compras_no_gravadas"])),
        total_igv_credito=Decimal(str(data["total_igv_credito"])),
        total_general=Decimal(str(data["total_general"])),
        comprobantes=comprobantes,
        fuente="SUNAT_SIRE",
    )


# ── MOCKS REALISTAS (basados en casos reales de contabilidad peruana) ──
def _generar_rvie_mock(ruc: str, ano: int, mes: int) -> ResumenRVIE:
    """
    Genera ~15 comprobantes de venta realistas. Mezcla facturas y boletas.
    Semilla determinista para que el mismo periodo devuelva los mismos datos.
    """
    random.seed(f"ventas-{ruc}-{ano}-{mes}")

    clientes = [
        ("20100070970", "SAGA FALABELLA S.A."),
        ("20477314832", "HIPERMERCADOS TOTTUS S.A."),
        ("20546798745", "DISTRIBUIDORA CENTRAL S.A.C."),
        ("20512345678", "SERVICIOS GENERALES DEL NORTE SRL"),
        ("20601234567", "INVERSIONES EL PACIFICO S.A."),
        ("20445566778", "CORPORACION COMERCIAL LIMA SAC"),
        ("10456789012", "JUAN PEREZ MENDOZA"),
        ("10234567891", "MARIA LOPEZ TORRES"),
        ("20987654321", "TRANSPORTES RAPIDOS DEL SUR SRL"),
        ("20555666777", "CONSTRUCTORA NUEVO HORIZONTE SAC"),
        ("20334455667", "LOGISTICA INTEGRAL PERU S.A."),
        ("20778899001", "SERVICIOS INDUSTRIALES AREQUIPA SAC"),
    ]

    # Configuracion: entre 12 y 18 ventas, mayoria facturas
    num_comprobantes = random.randint(12, 18)
    comprobantes = []

    # Montos tipicos de una PYME peruana (entre S/ 200 y S/ 8000 por comprobante)
    for i in range(num_comprobantes):
        c = random.choice(clientes)
        es_factura = random.random() < 0.75  # 75% facturas, 25% boletas
        tipo = "01" if es_factura else "03"
        serie_letra = "F" if es_factura else "B"
        serie = f"{serie_letra}{random.randint(1, 5):03d}"

        base = Decimal(random.randint(200, 8000)) + Decimal(random.randint(0, 99)) / Decimal(100)
        base = base.quantize(Decimal("0.01"))
        igv = (base * Decimal("0.18")).quantize(Decimal("0.01"))
        total = base + igv

        dia = random.randint(1, 28)
        comprobantes.append(ComprobanteImportado(
            tipo_comprobante=tipo,
            serie=serie,
            numero=str(1000 + i + random.randint(0, 500)),
            fecha_emision=f"{ano:04d}-{mes:02d}-{dia:02d}",
            ruc_contraparte=c[0],
            nombre_contraparte=c[1],
            base_gravada=base,
            igv=igv,
            total=total,
        ))

    # Ordenar por fecha
    comprobantes.sort(key=lambda x: x.fecha_emision)

    total_g = sum(c.base_gravada for c in comprobantes)
    total_ng = sum(c.base_no_gravada for c in comprobantes)
    total_exp = sum(c.exportacion for c in comprobantes)
    total_igv = sum(c.igv for c in comprobantes)
    total_gral = sum(c.total for c in comprobantes)

    return ResumenRVIE(
        periodo_ano=ano,
        periodo_mes=mes,
        total_comprobantes=len(comprobantes),
        total_ventas_gravadas=total_g,
        total_ventas_no_gravadas=total_ng,
        total_exportaciones=total_exp,
        total_ventas_exoneradas=Decimal("0"),
        total_igv_debito=total_igv,
        total_general=total_gral,
        comprobantes=comprobantes,
        fuente="MOCK",
    )


def _generar_rce_mock(ruc: str, ano: int, mes: int) -> ResumenRCE:
    """Genera ~20 comprobantes de compra realistas de proveedores tipicos."""
    random.seed(f"compras-{ruc}-{ano}-{mes}")

    proveedores = [
        ("20100047218", "TELEFONICA DEL PERU S.A.A."),
        ("20100030595", "LUZ DEL SUR S.A.A."),
        ("20136007044", "SEDAPAL S.A."),
        ("20100070970", "SAGA FALABELLA S.A."),
        ("20503840121", "CENCOSUD RETAIL PERU S.A."),
        ("20100128056", "SODIMAC PERU S.A."),
        ("20100039880", "CORPORACION LINDLEY S.A."),
        ("20101024645", "BACKUS Y JOHNSTON S.A.A."),
        ("20512345678", "SUMINISTROS DE OFICINA LIMA SAC"),
        ("20601234567", "IMPORTACIONES TECNICAS DEL PERU SAC"),
        ("20445566778", "SERVICIOS CONTABLES ASOCIADOS SRL"),
        ("20334455667", "TRANSPORTES Y FLETES DEL NORTE SAC"),
        ("20778899001", "MATERIALES DE CONSTRUCCION LIMA SAC"),
        ("20556677889", "SERVICIOS DE COURIER RAPIDO SAC"),
        ("20667788990", "COMBUSTIBLES Y LUBRICANTES DEL SUR SA"),
    ]

    num_comprobantes = random.randint(15, 22)
    comprobantes = []

    for i in range(num_comprobantes):
        p = random.choice(proveedores)
        # Las compras suelen ser montos menores y mas repartidos
        base = Decimal(random.randint(80, 3500)) + Decimal(random.randint(0, 99)) / Decimal(100)
        base = base.quantize(Decimal("0.01"))
        igv = (base * Decimal("0.18")).quantize(Decimal("0.01"))
        total = base + igv

        dia = random.randint(1, 28)
        comprobantes.append(ComprobanteImportado(
            tipo_comprobante="01",
            serie=f"F{random.randint(1, 99):03d}",
            numero=str(random.randint(10000, 99999)),
            fecha_emision=f"{ano:04d}-{mes:02d}-{dia:02d}",
            ruc_contraparte=p[0],
            nombre_contraparte=p[1],
            base_gravada=base,
            igv=igv,
            total=total,
        ))

    comprobantes.sort(key=lambda x: x.fecha_emision)

    total_g = sum(c.base_gravada for c in comprobantes)
    total_ng = sum(c.base_no_gravada for c in comprobantes)
    total_igv = sum(c.igv for c in comprobantes)
    total_gral = sum(c.total for c in comprobantes)

    return ResumenRCE(
        periodo_ano=ano,
        periodo_mes=mes,
        total_comprobantes=len(comprobantes),
        total_compras_gravadas=total_g,
        total_compras_no_gravadas=total_ng,
        total_igv_credito=total_igv,
        total_general=total_gral,
        comprobantes=comprobantes,
        fuente="MOCK",
    )
'@ | Set-Content "backend/app/services/sire_service.py"

Write-Host "  [OK] sire_service.py reescrito (mocks realistas con 12-18 ventas y 15-22 compras)" -ForegroundColor Green

# ============================================================
# 4. Resumen
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PARTE A COMPLETADA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Archivos modificados:" -ForegroundColor Yellow
Write-Host "  [OK] backend/app/models/models.py" -ForegroundColor Green
Write-Host "  [OK] backend/app/services/sire_service.py" -ForegroundColor Green
Write-Host "  [OK] backend/migrations/002_detalle_comprobantes.sql" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANTE: al reiniciar el backend, SQLAlchemy creara las tablas automaticamente" -ForegroundColor Yellow
Write-Host "via Base.metadata.create_all(). No necesitas correr el SQL a mano." -ForegroundColor Gray
Write-Host ""
Write-Host "SIGUIENTE PASO:" -ForegroundColor Cyan
Write-Host "  1. Reinicia uvicorn (Ctrl+C y vuelve a correrlo) para crear las tablas" -ForegroundColor Yellow
Write-Host "  2. Luego avisame para generar la PARTE B (servicios + endpoints)" -ForegroundColor Yellow
Write-Host ""
