from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc, case
from typing import Optional
from datetime import date

from app.database import get_db
from app.models.models import Usuario, Empresa, PDT621
from app.schemas.pdt621_schema import (
    PDT621Response, PDT621Generar, PDT621Ajustes, PDT621CambioEstado
)
from app.dependencies.auth_dependency import require_contador
from app.services.pdt621_service import (
    obtener_o_crear_pdt, importar_desde_sire, aplicar_ajustes,
    cambiar_estado, recalcular_pdt, obtener_saldo_favor_mes_anterior
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
    """Obtiene o crea el PDT de un periodo especifico."""
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
    """Descarga RVIE/RCE de SUNAT (real o mock) y pre-llena el PDT."""
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(status_code=400,
            detail=f"No se puede importar: el PDT esta en estado {pdt.estado}")
    resumen = importar_desde_sire(db, pdt, empresa)
    return resumen


# ── Probar conexion SIRE ───────────────────────────────
@router.post("/empresas/{empresa_id}/sire/probar-conexion")
def probar_conexion_sire(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """
    Prueba la conexion con SUNAT usando las credenciales de la empresa.
    Util para validar credenciales antes de hacer descargas.
    """
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
        # Intenta autenticar (esto valida credenciales)
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


# ── Sugerir saldo a favor mes anterior ─────────────────
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
        "fuente": "PDT 621 del mes anterior" if saldo > 0 else "Sin saldo previo",
    }


# ── Aplicar ajustes ────────────────────────────────────
@router.put("/pdt621/{pdt_id}/ajustes")
def aplicar_ajustes_endpoint(
    pdt_id: int,
    payload: PDT621Ajustes,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(status_code=400, detail=f"No editable: estado {pdt.estado}")
    ajustes = payload.model_dump(exclude_none=True)
    resultado = aplicar_ajustes(db, pdt, empresa, ajustes)
    return resultado


# ── Recalcular ─────────────────────────────────────────
@router.post("/pdt621/{pdt_id}/recalcular", response_model=PDT621Response)
def recalcular_endpoint(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    return recalcular_pdt(db, pdt, empresa)


# ── Cambiar estado ─────────────────────────────────────
@router.post("/pdt621/{pdt_id}/cambiar-estado", response_model=PDT621Response)
def cambiar_estado_endpoint(
    pdt_id: int,
    payload: PDT621CambioEstado,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)
    pdt = cambiar_estado(db, pdt, payload.nuevo_estado, payload.numero_operacion, payload.mensaje)
    return pdt


# ── Eliminar borrador ──────────────────────────────────
@router.delete("/pdt621/{pdt_id}", status_code=204)
def eliminar_pdt(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)
    if pdt.estado != "DRAFT":
        raise HTTPException(status_code=400,
            detail=f"Solo se pueden eliminar borradores. Estado actual: {pdt.estado}")
    db.delete(pdt)
    db.commit()
