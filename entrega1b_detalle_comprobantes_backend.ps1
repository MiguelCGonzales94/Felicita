# ============================================================
#  FELICITA - Entrega 1 Parte B: Backend servicios y endpoints
#  Persiste los comprobantes importados + endpoints de detalle
#  Uso: .\entrega1b_detalle_comprobantes_backend.ps1
# ============================================================

Write-Host ""
Write-Host "Entrega 1 - Parte B: Backend servicios y endpoints" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# 1. schemas/pdt621_schema.py - Agregar schemas de detalle
# ============================================================

Write-Host "Actualizando schemas..." -ForegroundColor Yellow

@'
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, date
from decimal import Decimal


class PDT621Response(BaseModel):
    id: int
    empresa_id: int
    mes: int
    ano: int
    fecha_vencimiento: date
    estado: str
    c100_ventas_gravadas: Decimal
    c104_ventas_no_gravadas: Decimal
    c105_exportaciones: Decimal
    c140_subtotal_ventas: Decimal
    c140igv_igv_debito: Decimal
    c120_compras_gravadas: Decimal
    c180_igv_credito: Decimal
    c184_igv_a_pagar: Decimal
    c301_ingresos_netos: Decimal
    c309_pago_a_cuenta_renta: Decimal
    c310_retenciones: Decimal
    c311_pagos_anticipados: Decimal
    c318_renta_a_pagar: Decimal
    total_a_pagar: Decimal
    nps: Optional[str]
    numero_operacion: Optional[str]
    codigo_rechazo_sunat: Optional[str]
    mensaje_error_sunat: Optional[str]
    fecha_presentacion_sunat: Optional[datetime]
    fecha_creacion: datetime
    model_config = {"from_attributes": True}


class PDT621ListItem(BaseModel):
    id: int
    empresa_id: int
    empresa_nombre: str
    empresa_ruc: str
    empresa_color: str
    mes: int
    ano: int
    fecha_vencimiento: date
    estado: str
    total_a_pagar: Decimal
    igv_a_pagar: Decimal
    renta_a_pagar: Decimal
    nps: Optional[str]
    dias_para_vencer: int
    model_config = {"from_attributes": True}


class PDT621Generar(BaseModel):
    ano: int
    mes: int


class PDT621Ajustes(BaseModel):
    saldo_favor_anterior: Optional[Decimal] = Decimal("0")
    percepciones_periodo: Optional[Decimal] = Decimal("0")
    percepciones_arrastre: Optional[Decimal] = Decimal("0")
    retenciones_periodo: Optional[Decimal] = Decimal("0")
    retenciones_arrastre: Optional[Decimal] = Decimal("0")
    pagos_anticipados: Optional[Decimal] = Decimal("0")
    retenciones_renta: Optional[Decimal] = Decimal("0")
    saldo_favor_renta_anterior: Optional[Decimal] = Decimal("0")
    categoria_nrus: Optional[int] = None
    ingresos_acumulados_ano: Optional[Decimal] = Decimal("0")


class PDT621CambioEstado(BaseModel):
    nuevo_estado: str
    numero_operacion: Optional[str] = None
    mensaje: Optional[str] = None


class ImportacionSunatResponse(BaseModel):
    ventas: dict
    compras: dict


# ════════════════════════════════════════════════════════════
# SCHEMAS DE DETALLE DE COMPROBANTES
# ════════════════════════════════════════════════════════════

class VentaDetalleItem(BaseModel):
    """Un comprobante de venta en la tabla de detalle."""
    id: int
    tipo_comprobante: str
    serie: str
    numero: str
    fecha_emision: date
    ruc_cliente: Optional[str] = None
    razon_social_cliente: str
    base_gravada: Decimal
    base_no_gravada: Decimal
    exportacion: Decimal
    igv: Decimal
    total: Decimal
    incluido: bool
    fuente: str
    model_config = {"from_attributes": True}


class CompraDetalleItem(BaseModel):
    """Un comprobante de compra en la tabla de detalle."""
    id: int
    tipo_comprobante: str
    serie: str
    numero: str
    fecha_emision: date
    ruc_proveedor: Optional[str] = None
    razon_social_proveedor: str
    base_gravada: Decimal
    base_no_gravada: Decimal
    igv: Decimal
    total: Decimal
    tipo_destino: str
    incluido: bool
    fuente: str
    model_config = {"from_attributes": True}


class DetalleVentasResponse(BaseModel):
    """Respuesta al listar el detalle de ventas de un PDT."""
    total_comprobantes: int
    comprobantes_incluidos: int
    subtotal_gravadas_incluidas: Decimal
    subtotal_no_gravadas_incluidas: Decimal
    subtotal_exportaciones_incluidas: Decimal
    subtotal_igv_incluido: Decimal
    subtotal_total_incluido: Decimal
    fuente: str
    comprobantes: List[VentaDetalleItem]


class DetalleComprasResponse(BaseModel):
    """Respuesta al listar el detalle de compras de un PDT."""
    total_comprobantes: int
    comprobantes_incluidos: int
    subtotal_gravadas_incluidas: Decimal
    subtotal_igv_incluido: Decimal
    subtotal_total_incluido: Decimal
    fuente: str
    comprobantes: List[CompraDetalleItem]


class SeleccionItem(BaseModel):
    """Entrada para aplicar seleccion: {id, incluido}."""
    id: int
    incluido: bool


class AplicarSeleccionRequest(BaseModel):
    """Body del endpoint aplicar-seleccion."""
    selecciones: List[SeleccionItem]
'@ | Set-Content "backend/app/schemas/pdt621_schema.py"

Write-Host "  [OK] schemas/pdt621_schema.py actualizado" -ForegroundColor Green

# ============================================================
# 2. services/pdt621_service.py - Reescribir con persistencia de detalles
# ============================================================

Write-Host ""
Write-Host "Reescribiendo pdt621_service.py..." -ForegroundColor Yellow

@'
"""
Servicio de PDT 621 - Logica de negocio.
Persiste los comprobantes importados y recalcula usando solo los incluidos.
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException
from datetime import date, datetime
from decimal import Decimal
from typing import List

from app.models.models import (
    PDT621, Empresa, CronogramaSunat,
    PDT621VentaDetalle, PDT621CompraDetalle,
)
from app.services.sire_service import descargar_rvie, descargar_rce
from app.services.pdt621_calculo_service import (
    calcular_pdt621, InputsCalculoIGV, InputsCalculoRenta
)
from app.services.empresa_service import obtener_credenciales_sunat


TRANSICIONES_ESTADO = {
    "DRAFT":     ["GENERATED", "DRAFT"],
    "GENERATED": ["SUBMITTED", "DRAFT"],
    "SUBMITTED": ["ACCEPTED", "REJECTED"],
    "REJECTED":  ["DRAFT"],
    "ACCEPTED":  [],
}


def obtener_fecha_vencimiento(db: Session, empresa_ruc: str, ano: int, mes: int) -> date:
    """Fecha de vencimiento segun cronograma SUNAT. Fallback: dia 15 del mes siguiente."""
    ultimo_digito = empresa_ruc[-1]
    mes_venc = mes + 1
    ano_venc = ano
    if mes_venc > 12:
        mes_venc = 1
        ano_venc += 1

    cronograma = db.query(CronogramaSunat).filter_by(
        ano=ano_venc, mes=mes_venc, ultimo_digito_ruc=ultimo_digito
    ).first()
    if cronograma and cronograma.fecha_pdt621:
        return cronograma.fecha_pdt621
    return date(ano_venc, mes_venc, 15)


def obtener_o_crear_pdt(db: Session, empresa: Empresa, ano: int, mes: int) -> PDT621:
    pdt = db.query(PDT621).filter_by(
        empresa_id=empresa.id, ano=ano, mes=mes
    ).first()
    if pdt:
        return pdt

    fecha_venc = obtener_fecha_vencimiento(db, empresa.ruc, ano, mes)
    pdt = PDT621(
        empresa_id=empresa.id,
        ano=ano, mes=mes,
        fecha_vencimiento=fecha_venc,
        estado="DRAFT",
    )
    db.add(pdt)
    db.commit()
    db.refresh(pdt)
    return pdt


def _fecha_from_str(fecha_str: str) -> date:
    """Convierte 'YYYY-MM-DD' a date."""
    return datetime.strptime(fecha_str, "%Y-%m-%d").date()


def importar_desde_sire(db: Session, pdt: PDT621, empresa: Empresa) -> dict:
    """
    Descarga RVIE/RCE de SUNAT (real o mock), persiste los comprobantes
    en pdt621_ventas_detalle y pdt621_compras_detalle, y recalcula el PDT
    usando solo los incluidos (todos incluidos por defecto al importar).
    """
    credenciales = obtener_credenciales_sunat(empresa)
    rvie = descargar_rvie(empresa.ruc, pdt.ano, pdt.mes, credenciales)
    rce = descargar_rce(empresa.ruc, pdt.ano, pdt.mes, credenciales)

    # Borrar detalles existentes antes de reimportar
    db.query(PDT621VentaDetalle).filter_by(pdt621_id=pdt.id).delete()
    db.query(PDT621CompraDetalle).filter_by(pdt621_id=pdt.id).delete()
    db.commit()

    # Insertar ventas
    for c in rvie.comprobantes:
        db.add(PDT621VentaDetalle(
            pdt621_id=pdt.id,
            tipo_comprobante=c.tipo_comprobante,
            serie=c.serie,
            numero=c.numero,
            fecha_emision=_fecha_from_str(c.fecha_emision),
            ruc_cliente=c.ruc_contraparte,
            razon_social_cliente=c.nombre_contraparte,
            base_gravada=c.base_gravada,
            base_no_gravada=c.base_no_gravada,
            exportacion=c.exportacion,
            igv=c.igv,
            total=c.total,
            incluido=True,
            fuente=rvie.fuente,
        ))

    # Insertar compras
    for c in rce.comprobantes:
        db.add(PDT621CompraDetalle(
            pdt621_id=pdt.id,
            tipo_comprobante=c.tipo_comprobante,
            serie=c.serie,
            numero=c.numero,
            fecha_emision=_fecha_from_str(c.fecha_emision),
            ruc_proveedor=c.ruc_contraparte,
            razon_social_proveedor=c.nombre_contraparte,
            base_gravada=c.base_gravada,
            base_no_gravada=c.base_no_gravada,
            igv=c.igv,
            total=c.total,
            tipo_destino="GRAVADA_EXCLUSIVA",
            incluido=True,
            fuente=rce.fuente,
        ))

    db.commit()

    # Recalcular PDT con los comprobantes recien insertados (todos incluidos)
    recalcular_desde_detalle(db, pdt, empresa)
    db.refresh(pdt)

    return {
        "fuente": rvie.fuente,
        "ventas": {
            "total_comprobantes": rvie.total_comprobantes,
            "ventas_gravadas": float(rvie.total_ventas_gravadas),
            "ventas_no_gravadas": float(rvie.total_ventas_no_gravadas),
            "exportaciones": float(rvie.total_exportaciones),
            "igv_debito": float(rvie.total_igv_debito),
        },
        "compras": {
            "total_comprobantes": rce.total_comprobantes,
            "compras_gravadas": float(rce.total_compras_gravadas),
            "igv_credito": float(rce.total_igv_credito),
        },
    }


def _totales_ventas_incluidas(db: Session, pdt_id: int) -> dict:
    """Suma los comprobantes de venta marcados como incluidos."""
    ventas = db.query(PDT621VentaDetalle).filter_by(
        pdt621_id=pdt_id, incluido=True
    ).all()
    return {
        "gravadas": sum((v.base_gravada or Decimal("0")) for v in ventas),
        "no_gravadas": sum((v.base_no_gravada or Decimal("0")) for v in ventas),
        "exportaciones": sum((v.exportacion or Decimal("0")) for v in ventas),
        "igv_debito": sum((v.igv or Decimal("0")) for v in ventas),
        "total": sum((v.total or Decimal("0")) for v in ventas),
    }


def _totales_compras_incluidas(db: Session, pdt_id: int) -> dict:
    """Suma los comprobantes de compra marcados como incluidos."""
    compras = db.query(PDT621CompraDetalle).filter_by(
        pdt621_id=pdt_id, incluido=True
    ).all()
    return {
        "gravadas": sum((c.base_gravada or Decimal("0")) for c in compras),
        "no_gravadas": sum((c.base_no_gravada or Decimal("0")) for c in compras),
        "igv_credito": sum((c.igv or Decimal("0")) for c in compras),
        "total": sum((c.total or Decimal("0")) for c in compras),
    }


def recalcular_desde_detalle(db: Session, pdt: PDT621, empresa: Empresa) -> PDT621:
    """
    Recalcula el PDT usando los totales de los comprobantes incluidos.
    Respeta los ajustes manuales (percepciones, retenciones, saldo a favor).
    """
    v = _totales_ventas_incluidas(db, pdt.id)
    c = _totales_compras_incluidas(db, pdt.id)

    # Actualizar campos base del PDT
    pdt.c100_ventas_gravadas = v["gravadas"]
    pdt.c104_ventas_no_gravadas = v["no_gravadas"]
    pdt.c105_exportaciones = v["exportaciones"]
    pdt.c140_subtotal_ventas = v["gravadas"] + v["no_gravadas"] + v["exportaciones"]
    pdt.c140igv_igv_debito = v["igv_debito"]
    pdt.c120_compras_gravadas = c["gravadas"]
    pdt.c180_igv_credito = c["igv_credito"]
    pdt.c301_ingresos_netos = v["gravadas"] + v["exportaciones"]

    db.commit()
    db.refresh(pdt)

    # Recalcular totales finales (IGV, renta, total)
    recalcular_pdt(db, pdt, empresa)
    return pdt


def recalcular_pdt(db: Session, pdt: PDT621, empresa: Empresa) -> PDT621:
    """Recalcula IGV y renta aplicando los ajustes actuales."""
    igv_inputs = InputsCalculoIGV(
        ventas_gravadas=pdt.c100_ventas_gravadas or Decimal("0"),
        ventas_no_gravadas=pdt.c104_ventas_no_gravadas or Decimal("0"),
        exportaciones=pdt.c105_exportaciones or Decimal("0"),
        compras_gravadas=pdt.c120_compras_gravadas or Decimal("0"),
        saldo_favor_anterior=Decimal("0"),
        percepciones_periodo=Decimal("0"),
        retenciones_periodo=pdt.c310_retenciones or Decimal("0"),
    )
    renta_inputs = InputsCalculoRenta(
        regimen=empresa.regimen_tributario,
        ingresos_netos=pdt.c301_ingresos_netos or Decimal("0"),
        coeficiente_declarado=(
            empresa.tasa_renta_pc / Decimal("100")
            if empresa.tasa_renta_pc else None
        ),
        pagos_anticipados=pdt.c311_pagos_anticipados or Decimal("0"),
    )
    resultado = calcular_pdt621(igv_inputs, renta_inputs)

    pdt.c184_igv_a_pagar = resultado.igv.igv_a_pagar
    pdt.c309_pago_a_cuenta_renta = resultado.renta.renta_bruta
    pdt.c318_renta_a_pagar = resultado.renta.renta_a_pagar
    pdt.total_a_pagar = resultado.total_a_pagar

    db.commit()
    db.refresh(pdt)
    return pdt


def aplicar_ajustes(db: Session, pdt: PDT621, empresa: Empresa, ajustes: dict) -> dict:
    """Aplica ajustes (percepciones, retenciones, saldo a favor) y recalcula todo."""
    igv_inputs = InputsCalculoIGV(
        ventas_gravadas=pdt.c100_ventas_gravadas or Decimal("0"),
        ventas_no_gravadas=pdt.c104_ventas_no_gravadas or Decimal("0"),
        exportaciones=pdt.c105_exportaciones or Decimal("0"),
        compras_gravadas=pdt.c120_compras_gravadas or Decimal("0"),
        saldo_favor_anterior=Decimal(str(ajustes.get("saldo_favor_anterior", 0))),
        percepciones_periodo=Decimal(str(ajustes.get("percepciones_periodo", 0))),
        percepciones_arrastre=Decimal(str(ajustes.get("percepciones_arrastre", 0))),
        retenciones_periodo=Decimal(str(ajustes.get("retenciones_periodo", 0))),
        retenciones_arrastre=Decimal(str(ajustes.get("retenciones_arrastre", 0))),
    )
    renta_inputs = InputsCalculoRenta(
        regimen=empresa.regimen_tributario,
        ingresos_netos=pdt.c301_ingresos_netos or Decimal("0"),
        coeficiente_declarado=(
            empresa.tasa_renta_pc / Decimal("100")
            if empresa.tasa_renta_pc else None
        ),
        pagos_anticipados=Decimal(str(ajustes.get("pagos_anticipados", 0))),
        retenciones_renta=Decimal(str(ajustes.get("retenciones_renta", 0))),
        saldo_favor_renta_anterior=Decimal(str(ajustes.get("saldo_favor_renta_anterior", 0))),
        categoria_nrus=ajustes.get("categoria_nrus"),
        ingresos_acumulados_ano=Decimal(str(ajustes.get("ingresos_acumulados_ano", 0))),
    )
    resultado = calcular_pdt621(igv_inputs, renta_inputs)

    pdt.c310_retenciones = Decimal(str(ajustes.get("retenciones_periodo", 0)))
    pdt.c311_pagos_anticipados = Decimal(str(ajustes.get("pagos_anticipados", 0)))
    pdt.c184_igv_a_pagar = resultado.igv.igv_a_pagar
    pdt.c309_pago_a_cuenta_renta = resultado.renta.renta_bruta
    pdt.c318_renta_a_pagar = resultado.renta.renta_a_pagar
    pdt.total_a_pagar = resultado.total_a_pagar

    db.commit()
    db.refresh(pdt)

    return {
        "igv": resultado.igv.model_dump(mode="json"),
        "renta": resultado.renta.model_dump(mode="json"),
        "total_a_pagar": float(resultado.total_a_pagar),
    }


def obtener_saldo_favor_mes_anterior(db: Session, empresa_id: int, ano: int, mes: int) -> Decimal:
    """Sugiere saldo a favor del mes anterior."""
    mes_ant = mes - 1
    ano_ant = ano
    if mes_ant == 0:
        mes_ant = 12
        ano_ant -= 1

    pdt_anterior = db.query(PDT621).filter_by(
        empresa_id=empresa_id, ano=ano_ant, mes=mes_ant
    ).first()
    if not pdt_anterior:
        return Decimal("0")

    debito = pdt_anterior.c140igv_igv_debito or Decimal("0")
    credito = pdt_anterior.c180_igv_credito or Decimal("0")
    diferencia = credito - debito
    return max(Decimal("0"), diferencia)


def aplicar_seleccion_ventas(
    db: Session, pdt: PDT621, empresa: Empresa, selecciones: List[dict]
) -> PDT621:
    """
    Aplica la seleccion de comprobantes de venta (incluir/excluir) y recalcula.
    Entrada: lista de {id, incluido}.
    """
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(
            status_code=400,
            detail=f"No se puede modificar un PDT en estado {pdt.estado}",
        )

    ids_validos = {
        d.id: d for d in db.query(PDT621VentaDetalle).filter_by(pdt621_id=pdt.id).all()
    }
    for sel in selecciones:
        detalle = ids_validos.get(sel["id"])
        if detalle:
            detalle.incluido = bool(sel["incluido"])
    db.commit()

    return recalcular_desde_detalle(db, pdt, empresa)


def aplicar_seleccion_compras(
    db: Session, pdt: PDT621, empresa: Empresa, selecciones: List[dict]
) -> PDT621:
    """Aplica la seleccion de comprobantes de compra y recalcula."""
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(
            status_code=400,
            detail=f"No se puede modificar un PDT en estado {pdt.estado}",
        )

    ids_validos = {
        d.id: d for d in db.query(PDT621CompraDetalle).filter_by(pdt621_id=pdt.id).all()
    }
    for sel in selecciones:
        detalle = ids_validos.get(sel["id"])
        if detalle:
            detalle.incluido = bool(sel["incluido"])
    db.commit()

    return recalcular_desde_detalle(db, pdt, empresa)


def cambiar_estado(
    db: Session, pdt: PDT621, nuevo_estado: str,
    numero_operacion: str = None, mensaje: str = None
) -> PDT621:
    permitidos = TRANSICIONES_ESTADO.get(pdt.estado, [])
    if nuevo_estado not in permitidos:
        raise HTTPException(
            status_code=400,
            detail=f"Transicion no valida: {pdt.estado} -> {nuevo_estado}. Permitidos: {permitidos}",
        )

    pdt.estado = nuevo_estado
    if nuevo_estado == "SUBMITTED":
        pdt.fecha_presentacion_sunat = datetime.utcnow()
        if numero_operacion:
            pdt.numero_operacion = numero_operacion
    if nuevo_estado == "REJECTED" and mensaje:
        pdt.mensaje_error_sunat = mensaje

    db.commit()
    db.refresh(pdt)
    return pdt
'@ | Set-Content "backend/app/services/pdt621_service.py"

Write-Host "  [OK] services/pdt621_service.py (con persistencia de detalles)" -ForegroundColor Green

# ============================================================
# 3. routers/pdt621.py - Agregar endpoints de detalle
# ============================================================

Write-Host ""
Write-Host "Actualizando routers/pdt621.py..." -ForegroundColor Yellow

@'
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc, case
from typing import Optional
from datetime import date
from decimal import Decimal

from app.database import get_db
from app.models.models import (
    Usuario, Empresa, PDT621,
    PDT621VentaDetalle, PDT621CompraDetalle,
)
from app.schemas.pdt621_schema import (
    PDT621Response, PDT621Generar, PDT621Ajustes, PDT621CambioEstado,
    DetalleVentasResponse, DetalleComprasResponse,
    VentaDetalleItem, CompraDetalleItem,
    AplicarSeleccionRequest,
)
from app.dependencies.auth_dependency import require_contador
from app.services.pdt621_service import (
    obtener_o_crear_pdt, importar_desde_sire, aplicar_ajustes,
    cambiar_estado, recalcular_pdt, obtener_saldo_favor_mes_anterior,
    aplicar_seleccion_ventas, aplicar_seleccion_compras,
)
from app.services.empresa_service import obtener_credenciales_sunat
from app.services.sire_client import SireClient, SIREError

router = APIRouter(prefix="/api/v1", tags=["PDT 621"])


def get_empresa_or_404(empresa_id: int, contador: Usuario, db: Session) -> Empresa:
    emp = db.query(Empresa).filter(
        Empresa.id == empresa_id,
        Empresa.contador_id == contador.id,
    ).first()
    if not emp:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")
    return emp


def get_pdt_or_404(pdt_id: int, contador: Usuario, db: Session):
    pdt = db.query(PDT621).filter(PDT621.id == pdt_id).first()
    if not pdt:
        raise HTTPException(status_code=404, detail="PDT 621 no encontrado")
    empresa = get_empresa_or_404(pdt.empresa_id, contador, db)
    return pdt, empresa


def pdt_list_item(pdt: PDT621, empresa: Empresa) -> dict:
    hoy = date.today()
    dias = (pdt.fecha_vencimiento - hoy).days
    return {
        "id": pdt.id,
        "empresa_id": empresa.id,
        "empresa_nombre": empresa.razon_social,
        "empresa_ruc": empresa.ruc,
        "empresa_color": empresa.color_identificacion,
        "mes": pdt.mes, "ano": pdt.ano,
        "fecha_vencimiento": pdt.fecha_vencimiento,
        "estado": pdt.estado,
        "total_a_pagar": pdt.total_a_pagar or 0,
        "igv_a_pagar": pdt.c184_igv_a_pagar or 0,
        "renta_a_pagar": pdt.c318_renta_a_pagar or 0,
        "nps": pdt.nps,
        "dias_para_vencer": dias,
    }


# ── Listar PDTs (consolidado) ──────────────────────────
@router.get("/pdt621")
def listar_pdts(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
    ano: Optional[int] = Query(None),
    mes: Optional[int] = Query(None),
    estado: Optional[str] = Query(None),
    empresa_id: Optional[int] = Query(None),
):
    query = db.query(PDT621, Empresa).join(Empresa, PDT621.empresa_id == Empresa.id).filter(
        Empresa.contador_id == current_user.id,
    )
    if ano: query = query.filter(PDT621.ano == ano)
    if mes: query = query.filter(PDT621.mes == mes)
    if estado: query = query.filter(PDT621.estado == estado)
    if empresa_id: query = query.filter(PDT621.empresa_id == empresa_id)

    orden_estado = case(
        (PDT621.estado == "DRAFT", 0),
        (PDT621.estado == "GENERATED", 1),
        (PDT621.estado == "REJECTED", 2),
        (PDT621.estado == "SUBMITTED", 3),
        (PDT621.estado == "ACCEPTED", 4),
        else_=5,
    )
    query = query.order_by(orden_estado, PDT621.fecha_vencimiento)
    results = query.all()
    items = [pdt_list_item(pdt, emp) for pdt, emp in results]
    return {"total": len(items), "pdts": items}


# ── Listar PDTs de una empresa ─────────────────────────
@router.get("/empresas/{empresa_id}/pdt621")
def listar_pdts_empresa(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    pdts = db.query(PDT621).filter_by(empresa_id=empresa.id).order_by(
        desc(PDT621.ano), desc(PDT621.mes)
    ).all()
    return {
        "empresa": {
            "id": empresa.id, "ruc": empresa.ruc,
            "razon_social": empresa.razon_social,
        },
        "total": len(pdts),
        "pdts": [pdt_list_item(p, empresa) for p in pdts],
    }


# ── Buscar PDT por periodo ─────────────────────────────
@router.get("/empresas/{empresa_id}/pdt621/periodo/{ano}/{mes}", response_model=PDT621Response)
def obtener_pdt_por_periodo(
    empresa_id: int, ano: int, mes: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    if mes < 1 or mes > 12:
        raise HTTPException(status_code=400, detail="Mes invalido")
    pdt = obtener_o_crear_pdt(db, empresa, ano, mes)
    return pdt


# ── Generar PDT ────────────────────────────────────────
@router.post("/empresas/{empresa_id}/pdt621/generar", response_model=PDT621Response)
def generar_pdt(
    empresa_id: int,
    payload: PDT621Generar,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    if payload.mes < 1 or payload.mes > 12:
        raise HTTPException(status_code=400, detail="Mes invalido")
    pdt = obtener_o_crear_pdt(db, empresa, payload.ano, payload.mes)
    return pdt


# ── Obtener PDT por ID ─────────────────────────────────
@router.get("/pdt621/{pdt_id}", response_model=PDT621Response)
def obtener_pdt(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)
    return pdt


# ── Importar desde SUNAT ───────────────────────────────
@router.post("/pdt621/{pdt_id}/importar-sunat")
def importar_sunat(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Descarga RVIE/RCE de SUNAT y persiste los comprobantes en el detalle."""
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(
            status_code=400,
            detail=f"No se puede importar: el PDT esta en estado {pdt.estado}",
        )
    resumen = importar_desde_sire(db, pdt, empresa)
    return resumen


# ── Probar conexion SIRE ───────────────────────────────
@router.post("/empresas/{empresa_id}/sire/probar-conexion")
def probar_conexion_sire(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    cred = obtener_credenciales_sunat(empresa)

    if not (cred.get("client_id") and cred.get("client_secret") and cred.get("clave_sol")):
        return {
            "conectado": False,
            "usando_mock": True,
            "mensaje": "No hay credenciales API SUNAT configuradas. Usando modo simulado.",
        }

    try:
        client = SireClient(
            client_id=cred["client_id"],
            client_secret=cred["client_secret"],
            ruc=cred["ruc"],
            usuario=cred.get("usuario", ""),
            clave_sol=cred["clave_sol"],
        )
        client._autenticar()
        return {
            "conectado": True,
            "usando_mock": False,
            "mensaje": "Conexion exitosa con SUNAT SIRE",
        }
    except SIREError as e:
        return {
            "conectado": False,
            "usando_mock": False,
            "mensaje": str(e),
            "codigo": e.codigo,
        }


# ── Sugerir saldo a favor ──────────────────────────────
@router.get("/empresas/{empresa_id}/pdt621/saldo-favor/{ano}/{mes}")
def sugerir_saldo_favor(
    empresa_id: int, ano: int, mes: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    saldo = obtener_saldo_favor_mes_anterior(db, empresa.id, ano, mes)
    return {
        "saldo_sugerido": float(saldo),
        "editable": True,
        "fuente": "PDT mes anterior" if saldo > 0 else "Sin saldo",
    }


# ── Aplicar ajustes ────────────────────────────────────
@router.put("/pdt621/{pdt_id}/ajustes")
def aplicar_ajustes_pdt(
    pdt_id: int,
    ajustes: PDT621Ajustes,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(
            status_code=400,
            detail=f"No se puede ajustar un PDT en estado {pdt.estado}",
        )
    return aplicar_ajustes(db, pdt, empresa, ajustes.model_dump())


# ── Recalcular ─────────────────────────────────────────
@router.post("/pdt621/{pdt_id}/recalcular", response_model=PDT621Response)
def recalcular(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    return recalcular_pdt(db, pdt, empresa)


# ── Cambiar estado ─────────────────────────────────────
@router.post("/pdt621/{pdt_id}/cambiar-estado", response_model=PDT621Response)
def cambiar_estado_pdt(
    pdt_id: int,
    payload: PDT621CambioEstado,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)
    return cambiar_estado(db, pdt, payload.nuevo_estado, payload.numero_operacion, payload.mensaje)


# ════════════════════════════════════════════════════════════
# DETALLE DE COMPROBANTES (nuevos endpoints)
# ════════════════════════════════════════════════════════════

def _build_detalle_ventas_response(
    comprobantes: list, fuente_principal: str
) -> dict:
    """Arma el response de detalle de ventas con totales de incluidos."""
    incluidos = [c for c in comprobantes if c.incluido]
    return {
        "total_comprobantes": len(comprobantes),
        "comprobantes_incluidos": len(incluidos),
        "subtotal_gravadas_incluidas": sum((c.base_gravada or Decimal("0")) for c in incluidos),
        "subtotal_no_gravadas_incluidas": sum((c.base_no_gravada or Decimal("0")) for c in incluidos),
        "subtotal_exportaciones_incluidas": sum((c.exportacion or Decimal("0")) for c in incluidos),
        "subtotal_igv_incluido": sum((c.igv or Decimal("0")) for c in incluidos),
        "subtotal_total_incluido": sum((c.total or Decimal("0")) for c in incluidos),
        "fuente": fuente_principal,
        "comprobantes": [VentaDetalleItem.model_validate(c) for c in comprobantes],
    }


def _build_detalle_compras_response(
    comprobantes: list, fuente_principal: str
) -> dict:
    incluidos = [c for c in comprobantes if c.incluido]
    return {
        "total_comprobantes": len(comprobantes),
        "comprobantes_incluidos": len(incluidos),
        "subtotal_gravadas_incluidas": sum((c.base_gravada or Decimal("0")) for c in incluidos),
        "subtotal_igv_incluido": sum((c.igv or Decimal("0")) for c in incluidos),
        "subtotal_total_incluido": sum((c.total or Decimal("0")) for c in incluidos),
        "fuente": fuente_principal,
        "comprobantes": [CompraDetalleItem.model_validate(c) for c in comprobantes],
    }


@router.get("/pdt621/{pdt_id}/detalle-ventas", response_model=DetalleVentasResponse)
def listar_detalle_ventas(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Lista todos los comprobantes de venta importados para este PDT."""
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)

    comprobantes = db.query(PDT621VentaDetalle).filter_by(
        pdt621_id=pdt.id
    ).order_by(PDT621VentaDetalle.fecha_emision, PDT621VentaDetalle.id).all()

    fuente = comprobantes[0].fuente if comprobantes else "SIN_DATOS"
    return _build_detalle_ventas_response(comprobantes, fuente)


@router.get("/pdt621/{pdt_id}/detalle-compras", response_model=DetalleComprasResponse)
def listar_detalle_compras(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Lista todos los comprobantes de compra importados para este PDT."""
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)

    comprobantes = db.query(PDT621CompraDetalle).filter_by(
        pdt621_id=pdt.id
    ).order_by(PDT621CompraDetalle.fecha_emision, PDT621CompraDetalle.id).all()

    fuente = comprobantes[0].fuente if comprobantes else "SIN_DATOS"
    return _build_detalle_compras_response(comprobantes, fuente)


@router.post("/pdt621/{pdt_id}/detalle-ventas/aplicar-seleccion", response_model=PDT621Response)
def aplicar_seleccion_ventas_endpoint(
    pdt_id: int,
    payload: AplicarSeleccionRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """
    Aplica la seleccion de comprobantes de venta (incluir/excluir) y recalcula el PDT.
    Recibe: { selecciones: [{ id, incluido }, ...] }
    """
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    selecciones = [s.model_dump() for s in payload.selecciones]
    return aplicar_seleccion_ventas(db, pdt, empresa, selecciones)


@router.post("/pdt621/{pdt_id}/detalle-compras/aplicar-seleccion", response_model=PDT621Response)
def aplicar_seleccion_compras_endpoint(
    pdt_id: int,
    payload: AplicarSeleccionRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Aplica la seleccion de comprobantes de compra y recalcula el PDT."""
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    selecciones = [s.model_dump() for s in payload.selecciones]
    return aplicar_seleccion_compras(db, pdt, empresa, selecciones)
'@ | Set-Content "backend/app/routers/pdt621.py"

Write-Host "  [OK] routers/pdt621.py (con endpoints de detalle)" -ForegroundColor Green

# ============================================================
# 4. Resumen
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PARTE B COMPLETADA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Archivos modificados:" -ForegroundColor Yellow
Write-Host "  [OK] backend/app/schemas/pdt621_schema.py" -ForegroundColor Green
Write-Host "  [OK] backend/app/services/pdt621_service.py" -ForegroundColor Green
Write-Host "  [OK] backend/app/routers/pdt621.py" -ForegroundColor Green
Write-Host ""
Write-Host "Endpoints nuevos:" -ForegroundColor Yellow
Write-Host "  GET  /api/v1/pdt621/:id/detalle-ventas" -ForegroundColor Gray
Write-Host "  GET  /api/v1/pdt621/:id/detalle-compras" -ForegroundColor Gray
Write-Host "  POST /api/v1/pdt621/:id/detalle-ventas/aplicar-seleccion" -ForegroundColor Gray
Write-Host "  POST /api/v1/pdt621/:id/detalle-compras/aplicar-seleccion" -ForegroundColor Gray
Write-Host ""
Write-Host "PARA PROBAR AHORA:" -ForegroundColor Cyan
Write-Host "  1. Reinicia uvicorn (Ctrl+C y vuelve a correrlo)" -ForegroundColor Yellow
Write-Host "  2. Abre http://localhost:8000/docs" -ForegroundColor Yellow
Write-Host "  3. Login como ana.perez@felicita.pe / contador123" -ForegroundColor Yellow
Write-Host "  4. Entra a una empresa, genera PDT de marzo 2026, presiona Descargar SUNAT" -ForegroundColor Yellow
Write-Host "  5. Prueba el endpoint GET /pdt621/:id/detalle-ventas" -ForegroundColor Yellow
Write-Host "     Deberias ver ~15 ventas con campo 'incluido': true" -ForegroundColor Yellow
Write-Host ""
Write-Host "PROBAR el toggle manual (opcional via Swagger):" -ForegroundColor Cyan
Write-Host "  POST /pdt621/:id/detalle-ventas/aplicar-seleccion" -ForegroundColor Gray
Write-Host "  Body: { 'selecciones': [{'id': 1, 'incluido': false}] }" -ForegroundColor Gray
Write-Host "  El PDT debe recalcularse quitando ese comprobante" -ForegroundColor Gray
Write-Host ""
Write-Host "SIGUIENTE PASO:" -ForegroundColor Cyan
Write-Host "  Confirmame que funciona y te genero la PARTE C (frontend: modal + UI)" -ForegroundColor Yellow
Write-Host ""
