# ============================================================
#  FELICITA - Entrega 2 Parte A: Backend Configuracion Tributaria
#  Tabla, defaults, endpoints, motor lee de BD + snapshot por PDT
#  Uso: .\entrega2a_config_tributaria_backend.ps1
# ============================================================

Write-Host ""
Write-Host "Entrega 2 - Parte A: Backend Configuracion Tributaria" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# 1. Agregar modelo ConfiguracionTributariaEmpresa + snapshot en PDT621
# ============================================================

Write-Host "Actualizando models/models.py..." -ForegroundColor Yellow

$modelsPath = "backend/app/models/models.py"
$modelsContent = Get-Content $modelsPath -Raw

# ── Agregar import JSON si no existe ──
if ($modelsContent -notmatch "from sqlalchemy.dialects.postgresql import JSONB") {
    $modelsContent = $modelsContent -replace "(from sqlalchemy import[^\n]+)", "`$1`r`nfrom sqlalchemy.dialects.postgresql import JSONB"
}

# ── Agregar campo config_snapshot a PDT621 ──
if ($modelsContent -notmatch "config_snapshot") {
    # Insertar el campo justo antes de las relaciones de PDT621
    $pattern = '(class PDT621\(Base\):[\s\S]*?)(\n    # Relaciones|\nclass )'
    if ($modelsContent -match $pattern) {
        $reemplazo = '$1' + "`r`n" + '    # Snapshot de la configuracion tributaria vigente al crear el PDT' + "`r`n" +
                     '    config_snapshot = Column(JSONB, nullable=True)' + "`r`n" + '$2'
        $modelsContent = $modelsContent -replace $pattern, $reemplazo
        Write-Host "  [OK] Campo config_snapshot agregado a PDT621" -ForegroundColor Green
    }
} else {
    Write-Host "  [SKIP] config_snapshot ya existe" -ForegroundColor Gray
}

# ── Agregar clase ConfiguracionTributariaEmpresa ──
if ($modelsContent -notmatch "class ConfiguracionTributariaEmpresa") {
    $nuevaTabla = @'


# ════════════════════════════════════════════════════════════
# CONFIGURACION TRIBUTARIA POR EMPRESA
# Valores legales (UIT, tasas) + seleccion de campos SIRE
# ════════════════════════════════════════════════════════════

class ConfiguracionTributariaEmpresa(Base):
    __tablename__ = "configuracion_tributaria_empresa"

    id = Column(Integer, primary_key=True, index=True)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="CASCADE"),
                        nullable=False, unique=True, index=True)

    # ── Valores legales SUNAT ──
    # UIT vigente (S/ 5,350 en 2026 por defecto)
    uit = Column(Numeric(10, 2), default=Decimal("5350.00"), nullable=False)

    # Tasa IGV (18% por defecto)
    tasa_igv = Column(Numeric(5, 4), default=Decimal("0.1800"), nullable=False)

    # Regimen General
    rg_coef_minimo = Column(Numeric(5, 4), default=Decimal("0.0150"), nullable=False)
    rg_renta_anual = Column(Numeric(5, 4), default=Decimal("0.2950"), nullable=False)

    # Regimen MYPE Tributario
    rmt_tramo1_tasa = Column(Numeric(5, 4), default=Decimal("0.0100"), nullable=False)
    rmt_tramo1_limite_uit = Column(Numeric(8, 2), default=Decimal("300.00"), nullable=False)
    rmt_tramo2_coef_minimo = Column(Numeric(5, 4), default=Decimal("0.0150"), nullable=False)
    rmt_renta_anual_hasta15uit = Column(Numeric(5, 4), default=Decimal("0.1000"), nullable=False)
    rmt_renta_anual_resto = Column(Numeric(5, 4), default=Decimal("0.2950"), nullable=False)

    # Regimen Especial de Renta
    rer_tasa = Column(Numeric(5, 4), default=Decimal("0.0150"), nullable=False)

    # Nuevo RUS (cuotas fijas)
    nrus_cat1 = Column(Numeric(8, 2), default=Decimal("20.00"), nullable=False)
    nrus_cat2 = Column(Numeric(8, 2), default=Decimal("50.00"), nullable=False)

    # ── Seleccion de campos SIRE ──
    # JSONB con estructura: {"campo_1": true, "campo_2": true, "campo_33": false, ...}
    campos_rvie = Column(JSONB, nullable=True)
    campos_rce = Column(JSONB, nullable=True)

    # ── Auditoria ──
    fecha_creacion = Column(DateTime, default=datetime.utcnow)
    fecha_modificacion = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    modificado_por_usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=True)

    # Relacion
    empresa = relationship("Empresa", back_populates="configuracion_tributaria")
'@

    $modelsContent = $modelsContent.TrimEnd() + "`r`n" + $nuevaTabla + "`r`n"

    # Agregar back_populates en Empresa
    if ($modelsContent -match "class Empresa\(Base\):") {
        if ($modelsContent -notmatch "configuracion_tributaria\s*=\s*relationship") {
            $regexEmp = [regex]'(class Empresa\(Base\):[\s\S]*?)(?=\r?\nclass |\Z)'
            $matchEmp = $regexEmp.Match($modelsContent)
            if ($matchEmp.Success) {
                $rel = "`r`n    # Configuracion tributaria (una por empresa)" + "`r`n" +
                       '    configuracion_tributaria = relationship("ConfiguracionTributariaEmpresa", back_populates="empresa", uselist=False, cascade="all, delete-orphan")' + "`r`n"
                $bloque = $matchEmp.Value.TrimEnd() + $rel
                $modelsContent = $modelsContent.Replace($matchEmp.Value, $bloque)
            }
        }
    }

    # Agregar import de Decimal si no esta
    if ($modelsContent -notmatch "from decimal import Decimal") {
        $modelsContent = "from decimal import Decimal`r`n" + $modelsContent
    }

    Set-Content $modelsPath $modelsContent -NoNewline
    Write-Host "  [OK] ConfiguracionTributariaEmpresa agregada" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] ConfiguracionTributariaEmpresa ya existe" -ForegroundColor Gray
}

# ============================================================
# 2. Servicio de configuracion + catalogo de campos SIRE
# ============================================================

Write-Host ""
Write-Host "Creando services/configuracion_tributaria_service.py..." -ForegroundColor Yellow

@'
"""
Servicio de configuracion tributaria por empresa.
Maneja valores legales (UIT, tasas) y seleccion de campos SIRE.
"""
from decimal import Decimal
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException

from app.models.models import ConfiguracionTributariaEmpresa, Empresa


# ════════════════════════════════════════════════════════════
# VALORES LEGALES POR DEFECTO (SUNAT Peru - vigente 2026)
# ════════════════════════════════════════════════════════════

DEFAULTS_LEGALES = {
    "uit":                          Decimal("5350.00"),
    "tasa_igv":                     Decimal("0.1800"),
    "rg_coef_minimo":               Decimal("0.0150"),
    "rg_renta_anual":               Decimal("0.2950"),
    "rmt_tramo1_tasa":              Decimal("0.0100"),
    "rmt_tramo1_limite_uit":        Decimal("300.00"),
    "rmt_tramo2_coef_minimo":       Decimal("0.0150"),
    "rmt_renta_anual_hasta15uit":   Decimal("0.1000"),
    "rmt_renta_anual_resto":        Decimal("0.2950"),
    "rer_tasa":                     Decimal("0.0150"),
    "nrus_cat1":                    Decimal("20.00"),
    "nrus_cat2":                    Decimal("50.00"),
}


# ════════════════════════════════════════════════════════════
# CATALOGO DE CAMPOS SIRE
# Basado en Anexos 3 (RVIE) y 11 (RCE) de RS 112-2021/SUNAT
# ════════════════════════════════════════════════════════════

# Campos RVIE - Reemplazo de Propuesta (33 campos principales)
CATALOGO_RVIE = [
    # (numero, codigo, nombre, obligatorio, default_marcado)
    (1,  "ruc",                          "RUC del deudor",                        True,  True),
    (2,  "id",                           "ID / Identificador",                    True,  True),
    (3,  "periodo",                      "Periodo (AAAAMM)",                      True,  True),
    (4,  "car_sunat",                    "CAR SUNAT",                             False, False),
    (5,  "fecha_emision",                "Fecha de emision",                      True,  True),
    (6,  "fecha_vcto_pago",              "Fecha Vcto/Pago",                       True,  True),
    (7,  "tipo_cp",                      "Tipo de Comprobante",                   True,  True),
    (8,  "serie_cp",                     "Serie del CP",                          True,  True),
    (9,  "nro_cp",                       "Numero CP (inicial rango)",             True,  True),
    (10, "nro_cp_final",                 "Numero CP (final rango)",               False, False),
    (11, "tipo_doc_identidad",           "Tipo Doc Identidad",                    True,  True),
    (12, "nro_doc_identidad",            "Nro Doc Identidad",                     True,  True),
    (13, "razon_social",                 "Apellidos/Razon Social",                True,  True),
    (14, "valor_exportacion",            "Valor facturado exportacion",           False, True),
    (15, "bi_gravada",                   "Base Imponible Gravada",                False, True),
    (16, "dscto_bi",                     "Descuento BI",                          False, False),
    (17, "igv_ipm",                      "IGV / IPM",                             False, True),
    (18, "dscto_igv",                    "Descuento IGV",                         False, False),
    (19, "mto_exonerado",                "Monto Exonerado",                       False, True),
    (20, "mto_inafecto",                 "Monto Inafecto",                        False, True),
    (21, "isc",                          "ISC",                                   False, False),
    (22, "bi_grav_ivap",                 "BI Grav IVAP",                          False, False),
    (23, "ivap",                         "IVAP",                                  False, False),
    (24, "icbper",                       "ICBPER",                                False, False),
    (25, "otros_tributos",               "Otros Tributos",                        False, False),
    (26, "total_cp",                     "Total CP",                              True,  True),
    (27, "moneda",                       "Moneda",                                True,  True),
    (28, "tipo_cambio",                  "Tipo de Cambio",                        False, True),
    (29, "fecha_emision_mod",            "Fecha Emision Doc Modificado",          False, False),
    (30, "tipo_cp_mod",                  "Tipo CP Modificado",                    False, False),
    (31, "serie_cp_mod",                 "Serie CP Modificado",                   False, False),
    (32, "nro_cp_mod",                   "Nro CP Modificado",                     False, False),
    (33, "id_proyecto_atribucion",       "ID Proyecto Operadores Atribucion",     False, False),
]

# Campos CLU (libres del usuario) para RVIE - 18 slots
CATALOGO_RVIE_CLU = [
    (40 + i, f"clu_rvie_{i}", f"Campo libre usuario {i}", False, False) for i in range(1, 19)
]

# Campos RCE - Reemplazo de Propuesta (37 campos principales)
CATALOGO_RCE = [
    (1,  "ruc",                          "RUC del deudor",                        True,  True),
    (2,  "razon_social_deudor",          "Razon social deudor",                   True,  True),
    (3,  "periodo",                      "Periodo (AAAAMM)",                      True,  True),
    (4,  "car_sunat",                    "CAR SUNAT",                             False, False),
    (5,  "fecha_emision",                "Fecha de emision",                      True,  True),
    (6,  "fecha_vcto_pago",              "Fecha Vcto/Pago",                       True,  True),
    (7,  "tipo_cp",                      "Tipo de Comprobante",                   True,  True),
    (8,  "serie_cp",                     "Serie del CP",                          True,  True),
    (9,  "ano",                          "Ano",                                   False, True),
    (10, "nro_cp",                       "Numero CP (inicial rango)",             True,  True),
    (11, "nro_cp_final",                 "Numero CP (final rango)",               False, False),
    (12, "tipo_doc_identidad",           "Tipo Doc Identidad",                    True,  True),
    (13, "nro_doc_identidad",            "Nro Doc Identidad del proveedor",       True,  True),
    (14, "razon_social",                 "Razon Social del proveedor",            True,  True),
    (15, "bi_gravado_dg",                "BI Gravado DG (destinadas a gravadas)", False, True),
    (16, "igv_ipm_dg",                   "IGV/IPM DG",                            False, True),
    (17, "bi_gravado_dgng",              "BI Gravado DGNG (gravadas y no grav)",  False, False),
    (18, "igv_ipm_dgng",                 "IGV/IPM DGNG",                          False, False),
    (19, "bi_gravado_dng",               "BI Gravado DNG (solo no gravadas)",     False, False),
    (20, "igv_ipm_dng",                  "IGV/IPM DNG",                           False, False),
    (21, "valor_adq_ng",                 "Valor adquisiciones no gravadas",       False, False),
    (22, "isc",                          "ISC",                                   False, False),
    (23, "icbper",                       "ICBPER",                                False, False),
    (24, "otros_tributos",               "Otros Tributos / Cargos",               False, False),
    (25, "total_cp",                     "Total CP",                              True,  True),
    (26, "moneda",                       "Moneda",                                True,  True),
    (27, "tipo_cambio",                  "Tipo de Cambio",                        False, True),
    (28, "fecha_emision_mod",            "Fecha Emision Doc Modificado",          False, False),
    (29, "tipo_cp_mod",                  "Tipo CP Modificado",                    False, False),
    (30, "serie_cp_mod",                 "Serie CP Modificado",                   False, False),
    (31, "cod_dam_dsi",                  "Cod. DAM o DSI",                        False, False),
    (32, "nro_cp_mod",                   "Nro CP Modificado",                     False, False),
    (33, "clasif_bienes_serv",           "Clasificacion de Bienes y Servicios",   False, False),
    (34, "id_proyecto",                  "ID Proyecto Operadores/Participes",     False, False),
    (35, "porc_part",                    "PorcPart (Porcentaje de participacion)",False, False),
    (36, "imb",                          "IMB",                                   False, False),
    (37, "car_orig",                     "CAR Original",                          False, False),
]

# Campos CLU para RCE - 39 slots (se empieza en 42)
CATALOGO_RCE_CLU = [
    (41 + i, f"clu_rce_{i}", f"Campo libre usuario {i}", False, False) for i in range(1, 40)
]


def catalogo_rvie_completo():
    """Retorna el catalogo completo de RVIE con CLU."""
    items = []
    for (num, codigo, nombre, obligatorio, default) in CATALOGO_RVIE + CATALOGO_RVIE_CLU:
        items.append({
            "numero": num,
            "codigo": codigo,
            "nombre": nombre,
            "obligatorio": obligatorio,
            "default_marcado": default,
            "es_clu": codigo.startswith("clu_"),
        })
    return items


def catalogo_rce_completo():
    items = []
    for (num, codigo, nombre, obligatorio, default) in CATALOGO_RCE + CATALOGO_RCE_CLU:
        items.append({
            "numero": num,
            "codigo": codigo,
            "nombre": nombre,
            "obligatorio": obligatorio,
            "default_marcado": default,
            "es_clu": codigo.startswith("clu_"),
        })
    return items


def defaults_campos_rvie() -> dict:
    """Diccionario {codigo_campo: bool} con los defaults de RVIE."""
    return {c["codigo"]: c["default_marcado"] for c in catalogo_rvie_completo()}


def defaults_campos_rce() -> dict:
    return {c["codigo"]: c["default_marcado"] for c in catalogo_rce_completo()}


# ════════════════════════════════════════════════════════════
# CRUD DE CONFIGURACION
# ════════════════════════════════════════════════════════════

def obtener_o_crear_configuracion(
    db: Session, empresa_id: int
) -> ConfiguracionTributariaEmpresa:
    """
    Obtiene la config de la empresa. Si no existe, la crea con defaults.
    """
    config = db.query(ConfiguracionTributariaEmpresa).filter_by(
        empresa_id=empresa_id
    ).first()

    if config:
        # Asegurar que tenga los JSON de campos (por si la tabla se creo vacia)
        if not config.campos_rvie:
            config.campos_rvie = defaults_campos_rvie()
        if not config.campos_rce:
            config.campos_rce = defaults_campos_rce()
        db.commit()
        return config

    # Crear con defaults
    config = ConfiguracionTributariaEmpresa(
        empresa_id=empresa_id,
        campos_rvie=defaults_campos_rvie(),
        campos_rce=defaults_campos_rce(),
        **{k: v for k, v in DEFAULTS_LEGALES.items()},
    )
    db.add(config)
    db.commit()
    db.refresh(config)
    return config


def actualizar_valores_legales(
    db: Session, empresa_id: int, datos: dict, usuario_id: Optional[int] = None
) -> ConfiguracionTributariaEmpresa:
    """Actualiza solo los valores legales (UIT, tasas). Ignora campos SIRE."""
    config = obtener_o_crear_configuracion(db, empresa_id)

    campos_permitidos = set(DEFAULTS_LEGALES.keys())
    for campo, valor in datos.items():
        if campo in campos_permitidos and valor is not None:
            try:
                setattr(config, campo, Decimal(str(valor)))
            except Exception:
                raise HTTPException(400, f"Valor invalido para {campo}: {valor}")

    if usuario_id:
        config.modificado_por_usuario_id = usuario_id
    db.commit()
    db.refresh(config)
    return config


def actualizar_campos_sire(
    db: Session, empresa_id: int, tipo: str, seleccion: dict,
    usuario_id: Optional[int] = None,
) -> ConfiguracionTributariaEmpresa:
    """
    Actualiza la seleccion de campos SIRE.
    tipo: 'rvie' o 'rce'
    seleccion: {codigo_campo: bool}
    Valida que los obligatorios esten siempre en True.
    """
    if tipo not in ("rvie", "rce"):
        raise HTTPException(400, "tipo debe ser 'rvie' o 'rce'")

    catalogo = catalogo_rvie_completo() if tipo == "rvie" else catalogo_rce_completo()
    obligatorios = {c["codigo"] for c in catalogo if c["obligatorio"]}

    # Validar: todos los obligatorios deben estar en True
    for codigo_ob in obligatorios:
        if seleccion.get(codigo_ob) is False:
            raise HTTPException(
                400,
                f"El campo '{codigo_ob}' es obligatorio por SUNAT "
                f"(Anexo {3 if tipo == 'rvie' else 11} RS 112-2021) y no puede desmarcarse",
            )

    # Construir el dict final merged con defaults (campos no enviados = default)
    codigos_validos = {c["codigo"] for c in catalogo}
    defaults = defaults_campos_rvie() if tipo == "rvie" else defaults_campos_rce()

    final = {}
    for codigo in codigos_validos:
        if codigo in obligatorios:
            final[codigo] = True  # Forzar obligatorios siempre True
        elif codigo in seleccion:
            final[codigo] = bool(seleccion[codigo])
        else:
            final[codigo] = defaults.get(codigo, False)

    config = obtener_o_crear_configuracion(db, empresa_id)
    if tipo == "rvie":
        config.campos_rvie = final
    else:
        config.campos_rce = final

    if usuario_id:
        config.modificado_por_usuario_id = usuario_id
    db.commit()
    db.refresh(config)
    return config


def restaurar_defaults(
    db: Session, empresa_id: int, seccion: str, usuario_id: Optional[int] = None
) -> ConfiguracionTributariaEmpresa:
    """
    Restaura los defaults legales o los defaults de campos SIRE.
    seccion: 'legales', 'rvie', 'rce', 'todo'
    """
    config = obtener_o_crear_configuracion(db, empresa_id)
    if seccion in ("legales", "todo"):
        for campo, valor in DEFAULTS_LEGALES.items():
            setattr(config, campo, valor)
    if seccion in ("rvie", "todo"):
        config.campos_rvie = defaults_campos_rvie()
    if seccion in ("rce", "todo"):
        config.campos_rce = defaults_campos_rce()

    if usuario_id:
        config.modificado_por_usuario_id = usuario_id
    db.commit()
    db.refresh(config)
    return config


def config_a_snapshot(config: ConfiguracionTributariaEmpresa) -> dict:
    """
    Convierte una configuracion a dict (JSONB) para guardar como snapshot en PDT621.
    Los PDTs existentes NUNCA se recalculan cuando cambia la config; usan su snapshot.
    """
    return {
        "uit":                        float(config.uit),
        "tasa_igv":                   float(config.tasa_igv),
        "rg_coef_minimo":             float(config.rg_coef_minimo),
        "rg_renta_anual":             float(config.rg_renta_anual),
        "rmt_tramo1_tasa":            float(config.rmt_tramo1_tasa),
        "rmt_tramo1_limite_uit":      float(config.rmt_tramo1_limite_uit),
        "rmt_tramo2_coef_minimo":     float(config.rmt_tramo2_coef_minimo),
        "rmt_renta_anual_hasta15uit": float(config.rmt_renta_anual_hasta15uit),
        "rmt_renta_anual_resto":      float(config.rmt_renta_anual_resto),
        "rer_tasa":                   float(config.rer_tasa),
        "nrus_cat1":                  float(config.nrus_cat1),
        "nrus_cat2":                  float(config.nrus_cat2),
    }


def snapshot_a_decimales(snapshot: Optional[dict]) -> dict:
    """
    Convierte un snapshot (dict) a Decimales. Si no hay snapshot, usa DEFAULTS_LEGALES.
    """
    if not snapshot:
        return dict(DEFAULTS_LEGALES)
    out = {}
    for k, v in DEFAULTS_LEGALES.items():
        out[k] = Decimal(str(snapshot.get(k, v)))
    return out
'@ | Set-Content "backend/app/services/configuracion_tributaria_service.py"

Write-Host "  [OK] configuracion_tributaria_service.py creado" -ForegroundColor Green

# ============================================================
# 3. Schemas para configuracion
# ============================================================

Write-Host ""
Write-Host "Creando schemas/configuracion_tributaria_schema.py..." -ForegroundColor Yellow

@'
from pydantic import BaseModel, Field
from typing import Optional, Dict, List
from datetime import datetime
from decimal import Decimal


class ValoresLegales(BaseModel):
    """Valores legales editables."""
    uit: Optional[Decimal] = None
    tasa_igv: Optional[Decimal] = None
    rg_coef_minimo: Optional[Decimal] = None
    rg_renta_anual: Optional[Decimal] = None
    rmt_tramo1_tasa: Optional[Decimal] = None
    rmt_tramo1_limite_uit: Optional[Decimal] = None
    rmt_tramo2_coef_minimo: Optional[Decimal] = None
    rmt_renta_anual_hasta15uit: Optional[Decimal] = None
    rmt_renta_anual_resto: Optional[Decimal] = None
    rer_tasa: Optional[Decimal] = None
    nrus_cat1: Optional[Decimal] = None
    nrus_cat2: Optional[Decimal] = None


class CampoSireItem(BaseModel):
    """Un campo del catalogo SIRE con metadata."""
    numero: int
    codigo: str
    nombre: str
    obligatorio: bool
    default_marcado: bool
    es_clu: bool
    marcado: bool


class ActualizarCamposSire(BaseModel):
    """Payload para actualizar seleccion de campos."""
    seleccion: Dict[str, bool]


class ConfiguracionTributariaResponse(BaseModel):
    id: int
    empresa_id: int

    # Valores legales
    uit: Decimal
    tasa_igv: Decimal
    rg_coef_minimo: Decimal
    rg_renta_anual: Decimal
    rmt_tramo1_tasa: Decimal
    rmt_tramo1_limite_uit: Decimal
    rmt_tramo2_coef_minimo: Decimal
    rmt_renta_anual_hasta15uit: Decimal
    rmt_renta_anual_resto: Decimal
    rer_tasa: Decimal
    nrus_cat1: Decimal
    nrus_cat2: Decimal

    # Campos SIRE
    campos_rvie: Dict[str, bool]
    campos_rce: Dict[str, bool]

    # Auditoria
    fecha_creacion: datetime
    fecha_modificacion: datetime
    es_personalizada: bool = Field(
        default=False,
        description="True si difiere de los defaults legales SUNAT",
    )

    model_config = {"from_attributes": True}


class CamposSireResponse(BaseModel):
    """Lista completa del catalogo + estado actual."""
    tipo: str  # 'rvie' o 'rce'
    campos: List[CampoSireItem]
    total_obligatorios: int
    total_marcados: int
    total_campos: int


class RestaurarDefaultsRequest(BaseModel):
    seccion: str = Field(..., pattern="^(legales|rvie|rce|todo)$")
'@ | Set-Content "backend/app/schemas/configuracion_tributaria_schema.py"

Write-Host "  [OK] configuracion_tributaria_schema.py creado" -ForegroundColor Green

# ============================================================
# 4. Router de configuracion tributaria
# ============================================================

Write-Host ""
Write-Host "Creando routers/configuracion_tributaria.py..." -ForegroundColor Yellow

@'
"""
Endpoints de configuracion tributaria por empresa.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from decimal import Decimal

from app.database import get_db
from app.models.models import Usuario, Empresa
from app.dependencies.auth_dependency import require_contador
from app.schemas.configuracion_tributaria_schema import (
    ValoresLegales, ActualizarCamposSire, ConfiguracionTributariaResponse,
    CamposSireResponse, RestaurarDefaultsRequest, CampoSireItem,
)
from app.services.configuracion_tributaria_service import (
    obtener_o_crear_configuracion, actualizar_valores_legales,
    actualizar_campos_sire, restaurar_defaults,
    catalogo_rvie_completo, catalogo_rce_completo,
    DEFAULTS_LEGALES,
)

router = APIRouter(prefix="/api/v1", tags=["Configuracion Tributaria"])


def get_empresa_or_404(empresa_id: int, contador: Usuario, db: Session) -> Empresa:
    emp = db.query(Empresa).filter(
        Empresa.id == empresa_id,
        Empresa.contador_id == contador.id,
    ).first()
    if not emp:
        raise HTTPException(404, "Empresa no encontrada")
    return emp


def _es_personalizada(config) -> bool:
    """Detecta si los valores legales difieren de los defaults SUNAT."""
    for campo, default in DEFAULTS_LEGALES.items():
        if Decimal(str(getattr(config, campo))) != default:
            return True
    return False


def _config_to_response(config) -> dict:
    """Arma el response incluyendo la flag es_personalizada."""
    return {
        "id": config.id,
        "empresa_id": config.empresa_id,
        "uit": config.uit,
        "tasa_igv": config.tasa_igv,
        "rg_coef_minimo": config.rg_coef_minimo,
        "rg_renta_anual": config.rg_renta_anual,
        "rmt_tramo1_tasa": config.rmt_tramo1_tasa,
        "rmt_tramo1_limite_uit": config.rmt_tramo1_limite_uit,
        "rmt_tramo2_coef_minimo": config.rmt_tramo2_coef_minimo,
        "rmt_renta_anual_hasta15uit": config.rmt_renta_anual_hasta15uit,
        "rmt_renta_anual_resto": config.rmt_renta_anual_resto,
        "rer_tasa": config.rer_tasa,
        "nrus_cat1": config.nrus_cat1,
        "nrus_cat2": config.nrus_cat2,
        "campos_rvie": config.campos_rvie or {},
        "campos_rce": config.campos_rce or {},
        "fecha_creacion": config.fecha_creacion,
        "fecha_modificacion": config.fecha_modificacion,
        "es_personalizada": _es_personalizada(config),
    }


# ── GET configuracion completa ─────────────────────────
@router.get(
    "/empresas/{empresa_id}/configuracion-tributaria",
    response_model=ConfiguracionTributariaResponse,
)
def obtener_configuracion(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Devuelve la configuracion tributaria de la empresa (crea con defaults si no existe)."""
    get_empresa_or_404(empresa_id, current_user, db)
    config = obtener_o_crear_configuracion(db, empresa_id)
    return _config_to_response(config)


# ── PUT valores legales ────────────────────────────────
@router.put(
    "/empresas/{empresa_id}/configuracion-tributaria/valores-legales",
    response_model=ConfiguracionTributariaResponse,
)
def actualizar_legales(
    empresa_id: int,
    datos: ValoresLegales,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Actualiza UIT, tasas IGV/RG/RMT/RER/NRUS."""
    get_empresa_or_404(empresa_id, current_user, db)
    payload = {k: v for k, v in datos.model_dump().items() if v is not None}
    config = actualizar_valores_legales(db, empresa_id, payload, current_user.id)
    return _config_to_response(config)


# ── GET catalogo de campos RVIE con estado ─────────────
@router.get(
    "/empresas/{empresa_id}/configuracion-tributaria/campos/rvie",
    response_model=CamposSireResponse,
)
def obtener_campos_rvie(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    get_empresa_or_404(empresa_id, current_user, db)
    config = obtener_o_crear_configuracion(db, empresa_id)
    estado = config.campos_rvie or {}

    items = []
    marcados = 0
    obligatorios = 0
    for c in catalogo_rvie_completo():
        marcado = bool(estado.get(c["codigo"], c["default_marcado"]))
        if c["obligatorio"]:
            marcado = True
            obligatorios += 1
        if marcado:
            marcados += 1
        items.append(CampoSireItem(**c, marcado=marcado))

    return CamposSireResponse(
        tipo="rvie",
        campos=items,
        total_obligatorios=obligatorios,
        total_marcados=marcados,
        total_campos=len(items),
    )


# ── GET catalogo de campos RCE ─────────────────────────
@router.get(
    "/empresas/{empresa_id}/configuracion-tributaria/campos/rce",
    response_model=CamposSireResponse,
)
def obtener_campos_rce(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    get_empresa_or_404(empresa_id, current_user, db)
    config = obtener_o_crear_configuracion(db, empresa_id)
    estado = config.campos_rce or {}

    items = []
    marcados = 0
    obligatorios = 0
    for c in catalogo_rce_completo():
        marcado = bool(estado.get(c["codigo"], c["default_marcado"]))
        if c["obligatorio"]:
            marcado = True
            obligatorios += 1
        if marcado:
            marcados += 1
        items.append(CampoSireItem(**c, marcado=marcado))

    return CamposSireResponse(
        tipo="rce",
        campos=items,
        total_obligatorios=obligatorios,
        total_marcados=marcados,
        total_campos=len(items),
    )


# ── PUT seleccion de campos RVIE ───────────────────────
@router.put(
    "/empresas/{empresa_id}/configuracion-tributaria/campos/rvie",
    response_model=ConfiguracionTributariaResponse,
)
def actualizar_rvie(
    empresa_id: int,
    payload: ActualizarCamposSire,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    get_empresa_or_404(empresa_id, current_user, db)
    config = actualizar_campos_sire(db, empresa_id, "rvie", payload.seleccion, current_user.id)
    return _config_to_response(config)


# ── PUT seleccion de campos RCE ────────────────────────
@router.put(
    "/empresas/{empresa_id}/configuracion-tributaria/campos/rce",
    response_model=ConfiguracionTributariaResponse,
)
def actualizar_rce(
    empresa_id: int,
    payload: ActualizarCamposSire,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    get_empresa_or_404(empresa_id, current_user, db)
    config = actualizar_campos_sire(db, empresa_id, "rce", payload.seleccion, current_user.id)
    return _config_to_response(config)


# ── POST restaurar defaults ────────────────────────────
@router.post(
    "/empresas/{empresa_id}/configuracion-tributaria/restaurar",
    response_model=ConfiguracionTributariaResponse,
)
def restaurar(
    empresa_id: int,
    payload: RestaurarDefaultsRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Restaura defaults SUNAT. seccion: 'legales' | 'rvie' | 'rce' | 'todo'"""
    get_empresa_or_404(empresa_id, current_user, db)
    config = restaurar_defaults(db, empresa_id, payload.seccion, current_user.id)
    return _config_to_response(config)
'@ | Set-Content "backend/app/routers/configuracion_tributaria.py"

Write-Host "  [OK] routers/configuracion_tributaria.py creado" -ForegroundColor Green

# ============================================================
# 5. Actualizar main.py para registrar el nuevo router
# ============================================================

Write-Host ""
Write-Host "Registrando router en main.py..." -ForegroundColor Yellow

$mainPath = "backend/app/main.py"
$mainContent = Get-Content $mainPath -Raw

if ($mainContent -notmatch "configuracion_tributaria") {
    # Agregar import
    $mainContent = $mainContent -replace `
        "(from app\.routers import[^\n]+)",
        "`$1`r`nfrom app.routers import configuracion_tributaria"

    # Agregar include_router al final de la seccion de routers
    $mainContent = $mainContent -replace `
        "(app\.include_router\(pdt621\.router\))",
        "`$1`r`napp.include_router(configuracion_tributaria.router)"

    Set-Content $mainPath $mainContent -NoNewline
    Write-Host "  [OK] Router registrado" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] Router ya registrado" -ForegroundColor Gray
}

# ============================================================
# 6. Actualizar motor de calculo para aceptar config personalizada
# ============================================================

Write-Host ""
Write-Host "Actualizando motor de calculo (acepta snapshot)..." -ForegroundColor Yellow

@'
"""
Motor de calculos del PDT 621.
Soporta los 4 regimenes: RG, RMT, RER, NRUS.

Ahora acepta un parametro opcional 'config' con valores personalizados por empresa
(UIT, tasas). Si no se pasa, usa los defaults legales SUNAT.

Los PDTs existentes guardan un snapshot de su config al crearse y lo usan para
recalcular, asi los cambios futuros en la configuracion no afectan PDTs viejos.
"""
from decimal import Decimal
from typing import Optional, Dict
from pydantic import BaseModel


# ════════════════════════════════════════════════════════════
# CONSTANTES LEGALES POR DEFECTO (fallback si no hay config)
# ════════════════════════════════════════════════════════════

DEFAULT_CONFIG = {
    "uit":                          Decimal("5350.00"),
    "tasa_igv":                     Decimal("0.1800"),
    "rg_coef_minimo":               Decimal("0.0150"),
    "rg_renta_anual":               Decimal("0.2950"),
    "rmt_tramo1_tasa":              Decimal("0.0100"),
    "rmt_tramo1_limite_uit":        Decimal("300.00"),
    "rmt_tramo2_coef_minimo":       Decimal("0.0150"),
    "rmt_renta_anual_hasta15uit":   Decimal("0.1000"),
    "rmt_renta_anual_resto":        Decimal("0.2950"),
    "rer_tasa":                     Decimal("0.0150"),
    "nrus_cat1":                    Decimal("20.00"),
    "nrus_cat2":                    Decimal("50.00"),
}


def _merge_config(config: Optional[Dict]) -> Dict[str, Decimal]:
    """Mezcla config del usuario con defaults. Todas las salidas son Decimal."""
    if not config:
        return dict(DEFAULT_CONFIG)
    merged = {}
    for k, v in DEFAULT_CONFIG.items():
        if k in config and config[k] is not None:
            merged[k] = Decimal(str(config[k]))
        else:
            merged[k] = v
    return merged


# ════════════════════════════════════════════════════════════
# MODELOS DE DATOS
# ════════════════════════════════════════════════════════════

class InputsCalculoIGV(BaseModel):
    ventas_gravadas: Decimal = Decimal("0")
    ventas_no_gravadas: Decimal = Decimal("0")
    exportaciones: Decimal = Decimal("0")
    compras_gravadas: Decimal = Decimal("0")
    compras_no_gravadas: Decimal = Decimal("0")
    saldo_favor_anterior: Decimal = Decimal("0")
    percepciones_periodo: Decimal = Decimal("0")
    percepciones_arrastre: Decimal = Decimal("0")
    retenciones_periodo: Decimal = Decimal("0")
    retenciones_arrastre: Decimal = Decimal("0")


class ResultadoCalculoIGV(BaseModel):
    subtotal_ventas: Decimal
    subtotal_compras: Decimal
    igv_debito: Decimal
    igv_credito: Decimal
    igv_resultante: Decimal
    total_creditos_aplicables: Decimal
    igv_a_pagar: Decimal
    saldo_favor_siguiente: Decimal
    percepciones_aplicadas: Decimal
    retenciones_aplicadas: Decimal
    saldo_favor_aplicado: Decimal


class InputsCalculoRenta(BaseModel):
    regimen: str
    ingresos_netos: Decimal = Decimal("0")
    coeficiente_declarado: Optional[Decimal] = None
    pagos_anticipados: Decimal = Decimal("0")
    retenciones_renta: Decimal = Decimal("0")
    saldo_favor_renta_anterior: Decimal = Decimal("0")
    categoria_nrus: Optional[int] = None
    ingresos_acumulados_ano: Decimal = Decimal("0")


class ResultadoCalculoRenta(BaseModel):
    regimen: str
    tasa_aplicada: Decimal
    base_calculo: Decimal
    renta_bruta: Decimal
    creditos_aplicados: Decimal
    renta_a_pagar: Decimal
    observaciones: str = ""


class ResultadoPDT621(BaseModel):
    igv: ResultadoCalculoIGV
    renta: ResultadoCalculoRenta
    total_a_pagar: Decimal


# ════════════════════════════════════════════════════════════
# MOTOR IGV
# ════════════════════════════════════════════════════════════

def calcular_igv(
    inputs: InputsCalculoIGV, config: Optional[Dict] = None
) -> ResultadoCalculoIGV:
    """Motor de calculo del IGV. Usa tasa_igv de la config o 18% por defecto."""
    cfg = _merge_config(config)
    tasa_igv = cfg["tasa_igv"]

    subtotal_ventas = (
        inputs.ventas_gravadas + inputs.ventas_no_gravadas + inputs.exportaciones
    )
    subtotal_compras = inputs.compras_gravadas + inputs.compras_no_gravadas

    igv_debito = (inputs.ventas_gravadas * tasa_igv).quantize(Decimal("0.01"))
    igv_credito = (inputs.compras_gravadas * tasa_igv).quantize(Decimal("0.01"))
    igv_resultante = igv_debito - igv_credito

    percepciones_total = inputs.percepciones_periodo + inputs.percepciones_arrastre
    retenciones_total = inputs.retenciones_periodo + inputs.retenciones_arrastre
    total_creditos = inputs.saldo_favor_anterior + percepciones_total + retenciones_total

    if igv_resultante <= 0:
        igv_a_pagar = Decimal("0")
        saldo_favor_siguiente = abs(igv_resultante) + total_creditos
        saldo_aplicado = Decimal("0")
        percep_aplicada = Decimal("0")
        retenc_aplicada = Decimal("0")
    else:
        restante = igv_resultante
        saldo_aplicado = min(restante, inputs.saldo_favor_anterior)
        restante -= saldo_aplicado
        percep_aplicada = min(restante, percepciones_total)
        restante -= percep_aplicada
        retenc_aplicada = min(restante, retenciones_total)
        restante -= retenc_aplicada
        igv_a_pagar = max(Decimal("0"), restante)
        sobrante_creditos = total_creditos - (saldo_aplicado + percep_aplicada + retenc_aplicada)
        saldo_favor_siguiente = max(Decimal("0"), sobrante_creditos)

    return ResultadoCalculoIGV(
        subtotal_ventas=subtotal_ventas.quantize(Decimal("0.01")),
        subtotal_compras=subtotal_compras.quantize(Decimal("0.01")),
        igv_debito=igv_debito,
        igv_credito=igv_credito,
        igv_resultante=igv_resultante.quantize(Decimal("0.01")),
        total_creditos_aplicables=total_creditos.quantize(Decimal("0.01")),
        igv_a_pagar=igv_a_pagar.quantize(Decimal("0.01")),
        saldo_favor_siguiente=saldo_favor_siguiente.quantize(Decimal("0.01")),
        percepciones_aplicadas=percep_aplicada.quantize(Decimal("0.01")),
        retenciones_aplicadas=retenc_aplicada.quantize(Decimal("0.01")),
        saldo_favor_aplicado=saldo_aplicado.quantize(Decimal("0.01")),
    )


# ════════════════════════════════════════════════════════════
# MOTOR RENTA (4 regimenes)
# ════════════════════════════════════════════════════════════

def calcular_renta_rg(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    cfg = _merge_config(config)
    tasa = inputs.coeficiente_declarado if inputs.coeficiente_declarado else cfg["rg_coef_minimo"]
    base = inputs.ingresos_netos
    renta_bruta = (base * tasa).quantize(Decimal("0.01"))
    creditos = (
        inputs.pagos_anticipados
        + inputs.retenciones_renta
        + inputs.saldo_favor_renta_anterior
    )
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    obs = ""
    if inputs.coeficiente_declarado:
        obs = f"Usando coeficiente declarado de {(tasa * 100):.4f}%"
    else:
        obs = f"Usando coeficiente minimo de {(tasa * 100):.2f}% (RG)"
    return ResultadoCalculoRenta(
        regimen="RG",
        tasa_aplicada=tasa,
        base_calculo=base.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones=obs,
    )


def calcular_renta_rmt(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    cfg = _merge_config(config)
    limite = cfg["rmt_tramo1_limite_uit"] * cfg["uit"]

    if inputs.ingresos_acumulados_ano <= limite:
        tasa = cfg["rmt_tramo1_tasa"]
        obs = (
            f"Ingresos acumulados ({inputs.ingresos_acumulados_ano:,.2f}) dentro de "
            f"{cfg['rmt_tramo1_limite_uit']} UIT -> {(tasa * 100):.2f}%"
        )
    else:
        tasa = cfg["rmt_tramo2_coef_minimo"]
        obs = (
            f"Ingresos acumulados ({inputs.ingresos_acumulados_ano:,.2f}) superan "
            f"{cfg['rmt_tramo1_limite_uit']} UIT -> {(tasa * 100):.2f}%"
        )

    if inputs.coeficiente_declarado:
        tasa = inputs.coeficiente_declarado
        obs = f"Usando coeficiente declarado de {(tasa * 100):.4f}%"

    renta_bruta = (inputs.ingresos_netos * tasa).quantize(Decimal("0.01"))
    creditos = (
        inputs.pagos_anticipados
        + inputs.retenciones_renta
        + inputs.saldo_favor_renta_anterior
    )
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    return ResultadoCalculoRenta(
        regimen="RMT",
        tasa_aplicada=tasa,
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones=obs,
    )


def calcular_renta_rer(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    cfg = _merge_config(config)
    tasa = cfg["rer_tasa"]
    renta_bruta = (inputs.ingresos_netos * tasa).quantize(Decimal("0.01"))
    creditos = inputs.pagos_anticipados + inputs.retenciones_renta
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    return ResultadoCalculoRenta(
        regimen="RER",
        tasa_aplicada=tasa,
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones=f"Tasa unica RER {(tasa * 100):.2f}% de ingresos netos mensuales",
    )


def calcular_renta_nrus(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    cfg = _merge_config(config)
    categoria = inputs.categoria_nrus or 1
    if categoria == 2:
        monto_fijo = cfg["nrus_cat2"]
    else:
        categoria = 1
        monto_fijo = cfg["nrus_cat1"]
    return ResultadoCalculoRenta(
        regimen="NRUS",
        tasa_aplicada=Decimal("0"),
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=monto_fijo,
        creditos_aplicados=Decimal("0"),
        renta_a_pagar=monto_fijo,
        observaciones=f"NRUS Categoria {categoria}: cuota fija de S/ {monto_fijo}",
    )


def calcular_renta(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    regimen = inputs.regimen.upper()
    if regimen == "RG":
        return calcular_renta_rg(inputs, config)
    elif regimen == "RMT":
        return calcular_renta_rmt(inputs, config)
    elif regimen == "RER":
        return calcular_renta_rer(inputs, config)
    elif regimen == "NRUS":
        return calcular_renta_nrus(inputs, config)
    else:
        raise ValueError(f"Regimen desconocido: {regimen}")


def calcular_pdt621(
    igv_inputs: InputsCalculoIGV,
    renta_inputs: InputsCalculoRenta,
    config: Optional[Dict] = None,
) -> ResultadoPDT621:
    """
    Calculo principal. Si config es None, usa defaults legales SUNAT.
    Para PDTs existentes, pasar su snapshot (pdt.config_snapshot).
    """
    igv = calcular_igv(igv_inputs, config)
    renta = calcular_renta(renta_inputs, config)
    total = igv.igv_a_pagar + renta.renta_a_pagar
    return ResultadoPDT621(
        igv=igv,
        renta=renta,
        total_a_pagar=total.quantize(Decimal("0.01")),
    )
'@ | Set-Content "backend/app/services/pdt621_calculo_service.py"

Write-Host "  [OK] pdt621_calculo_service.py actualizado" -ForegroundColor Green

# ============================================================
# 7. Actualizar pdt621_service para guardar snapshot al crear PDT
#    y usar el snapshot al recalcular
# ============================================================

Write-Host ""
Write-Host "Actualizando pdt621_service.py para manejar snapshot..." -ForegroundColor Yellow

$servicePath = "backend/app/services/pdt621_service.py"
$serviceContent = Get-Content $servicePath -Raw

# Agregar import del servicio de configuracion si no esta
if ($serviceContent -notmatch "from app.services.configuracion_tributaria_service") {
    $serviceContent = $serviceContent -replace `
        "(from app\.services\.empresa_service import obtener_credenciales_sunat)",
        "`$1`r`nfrom app.services.configuracion_tributaria_service import obtener_o_crear_configuracion, config_a_snapshot"
}

# Reemplazar obtener_o_crear_pdt para que guarde snapshot al crear
$serviceContent = $serviceContent -replace `
    '(def obtener_o_crear_pdt[\s\S]*?pdt = PDT621\()([\s\S]*?)(\s+\)\s+db\.add\(pdt\))',
    '$1$2,' + "`r`n        config_snapshot=config_a_snapshot(obtener_o_crear_configuracion(db, empresa.id))$3"

# Ajustar recalcular_pdt y recalcular_desde_detalle para pasar el snapshot al motor
$serviceContent = $serviceContent -replace `
    'resultado = calcular_pdt621\(igv_inputs, renta_inputs\)',
    'resultado = calcular_pdt621(igv_inputs, renta_inputs, config=pdt.config_snapshot)'

Set-Content $servicePath $serviceContent -NoNewline
Write-Host "  [OK] pdt621_service.py usa snapshot por PDT" -ForegroundColor Green

# ============================================================
# 8. Script SQL de migracion (opcional - SQLAlchemy la crea sola)
# ============================================================

Write-Host ""
Write-Host "Creando migracion SQL..." -ForegroundColor Yellow

@'
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
'@ | Set-Content "backend/migrations/003_configuracion_tributaria.sql"

Write-Host "  [OK] migrations/003_configuracion_tributaria.sql" -ForegroundColor Green

# ============================================================
# Resumen
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PARTE A COMPLETADA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Archivos modificados/creados:" -ForegroundColor Yellow
Write-Host "  [MOD] backend/app/models/models.py (nueva tabla + campo snapshot)" -ForegroundColor Green
Write-Host "  [NEW] backend/app/services/configuracion_tributaria_service.py" -ForegroundColor Green
Write-Host "  [NEW] backend/app/schemas/configuracion_tributaria_schema.py" -ForegroundColor Green
Write-Host "  [NEW] backend/app/routers/configuracion_tributaria.py" -ForegroundColor Green
Write-Host "  [MOD] backend/app/main.py (registro router)" -ForegroundColor Green
Write-Host "  [MOD] backend/app/services/pdt621_calculo_service.py (acepta config)" -ForegroundColor Green
Write-Host "  [MOD] backend/app/services/pdt621_service.py (snapshot)" -ForegroundColor Green
Write-Host "  [NEW] backend/migrations/003_configuracion_tributaria.sql" -ForegroundColor Green
Write-Host ""
Write-Host "Endpoints nuevos:" -ForegroundColor Yellow
Write-Host "  GET  /api/v1/empresas/:id/configuracion-tributaria" -ForegroundColor Gray
Write-Host "  PUT  /api/v1/empresas/:id/configuracion-tributaria/valores-legales" -ForegroundColor Gray
Write-Host "  GET  /api/v1/empresas/:id/configuracion-tributaria/campos/rvie" -ForegroundColor Gray
Write-Host "  GET  /api/v1/empresas/:id/configuracion-tributaria/campos/rce" -ForegroundColor Gray
Write-Host "  PUT  /api/v1/empresas/:id/configuracion-tributaria/campos/rvie" -ForegroundColor Gray
Write-Host "  PUT  /api/v1/empresas/:id/configuracion-tributaria/campos/rce" -ForegroundColor Gray
Write-Host "  POST /api/v1/empresas/:id/configuracion-tributaria/restaurar" -ForegroundColor Gray
Write-Host ""
Write-Host "CARACTERISTICAS CLAVE:" -ForegroundColor Cyan
Write-Host "  - Snapshot por PDT: los PDTs viejos NUNCA se afectan por cambios" -ForegroundColor Gray
Write-Host "  - Solo nuevos PDTs usan los valores actualizados" -ForegroundColor Gray
Write-Host "  - Campos obligatorios SUNAT NO pueden desmarcarse (error 400)" -ForegroundColor Gray
Write-Host "  - Catalogo RVIE: 33 principales + 18 CLU" -ForegroundColor Gray
Write-Host "  - Catalogo RCE: 37 principales + 39 CLU" -ForegroundColor Gray
Write-Host ""
Write-Host "PROBAR:" -ForegroundColor Cyan
Write-Host "  1. Reinicia uvicorn" -ForegroundColor Yellow
Write-Host "  2. Abre http://localhost:8000/docs" -ForegroundColor Yellow
Write-Host "  3. Login como ana.perez@felicita.pe / contador123" -ForegroundColor Yellow
Write-Host "  4. GET /empresas/1/configuracion-tributaria (devuelve defaults)" -ForegroundColor Yellow
Write-Host "  5. GET /empresas/1/configuracion-tributaria/campos/rvie" -ForegroundColor Yellow
Write-Host "     Veras 51 campos (33 + 18 CLU)" -ForegroundColor Gray
Write-Host "  6. PUT .../valores-legales con body { 'uit': 5500 } -> personaliza UIT" -ForegroundColor Yellow
Write-Host "  7. Intenta PUT .../campos/rvie con { 'ruc': false } -> error 400" -ForegroundColor Yellow
Write-Host ""
Write-Host "SIGUIENTE: Avisame y genero la Parte B (Frontend)" -ForegroundColor Cyan
Write-Host ""
