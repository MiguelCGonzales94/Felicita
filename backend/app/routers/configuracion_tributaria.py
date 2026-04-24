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
