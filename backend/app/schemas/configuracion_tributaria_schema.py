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
