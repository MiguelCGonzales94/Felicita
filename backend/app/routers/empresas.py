from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, func, desc, case
from typing import Optional

from app.database import get_db
from app.models.models import Usuario, Empresa, PDT621, CalendarioTributario
from app.schemas.empresa_schema import (
    EmpresaCreate, EmpresaUpdate, EmpresaResponse,
    EmpresaDetalleResponse, ValidacionRUCResponse, EmpresaListResponse
)
from app.dependencies.auth_dependency import require_contador
from app.services.empresa_service import (
    validar_limite_plan, validar_ruc_empresa,
    preparar_datos_empresa, registrar_log,
    actualizar_alertas_empresa
)
from app.services.sunat_service import consultar_ruc
from app.utils.ruc_validator import validar_ruc_completo

router = APIRouter(prefix="/api/v1/empresas", tags=["Empresas"])


def get_empresa_or_404(empresa_id: int, contador: Usuario, db: Session) -> Empresa:
    empresa = db.query(Empresa).filter(
        Empresa.id == empresa_id,
        Empresa.contador_id == contador.id,
    ).first()
    if not empresa:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")
    return empresa


def empresa_to_response(empresa: Empresa) -> dict:
    return {
        "id": empresa.id,
        "ruc": empresa.ruc,
        "razon_social": empresa.razon_social,
        "nombre_comercial": empresa.nombre_comercial,
        "direccion_fiscal": empresa.direccion_fiscal,
        "distrito": empresa.distrito,
        "provincia": empresa.provincia,
        "departamento": empresa.departamento,
        "regimen_tributario": empresa.regimen_tributario,
        "estado_sunat": empresa.estado_sunat,
        "condicion_domicilio": empresa.condicion_domicilio,
        "representante_legal": empresa.representante_legal,
        "email_empresa": empresa.email_empresa,
        "telefono_empresa": empresa.telefono_empresa,
        "nivel_alerta": empresa.nivel_alerta,
        "motivo_alerta": empresa.motivo_alerta,
        "color_identificacion": empresa.color_identificacion,
        "tipo_acceso_sol": empresa.tipo_acceso_sol or "RUC",
        "dni_sol": empresa.dni_sol,
        "usuario_sol": empresa.usuario_sol,
        "tiene_clave_sol": bool(empresa.clave_sol_encrypted),
        "tiene_credenciales_api_sunat": bool(empresa.sunat_client_id_encrypted and empresa.sunat_client_secret_encrypted),
        "activa": empresa.activa,
        "fecha_creacion": empresa.fecha_creacion,
    }


@router.get("/validar-ruc/{ruc}", response_model=ValidacionRUCResponse)
def validar_ruc(
    ruc: str,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    validacion = validar_ruc_completo(ruc)
    if not validacion["es_valido"]:
        return ValidacionRUCResponse(
            ruc=ruc, es_valido=False,
            mensaje=validacion["mensaje"], tipo=validacion["tipo"],
        )

    ya_registrada = db.query(Empresa).filter(
        Empresa.ruc == ruc,
        Empresa.contador_id == current_user.id,
        Empresa.activa == True,
    ).first() is not None

    ficha = consultar_ruc(ruc)
    return ValidacionRUCResponse(
        ruc=ruc, es_valido=True,
        mensaje="RUC valido" + (" (ya registrada)" if ya_registrada else ""),
        tipo=validacion["tipo"],
        ya_registrada=ya_registrada,
        razon_social=ficha.razon_social if ficha else None,
        estado_sunat=ficha.estado if ficha else None,
        condicion_domicilio=ficha.condicion_domicilio if ficha else None,
        direccion_fiscal=ficha.direccion_fiscal if ficha else None,
        distrito=ficha.distrito if ficha else None,
        provincia=ficha.provincia if ficha else None,
        departamento=ficha.departamento if ficha else None,
    )


@router.get("", response_model=EmpresaListResponse)
def listar_empresas(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
    buscar: Optional[str] = Query(None),
    nivel_alerta: Optional[str] = Query(None),
    regimen: Optional[str] = Query(None),
    estado_sunat: Optional[str] = Query(None),
    activa: bool = Query(True),
    orden: str = Query("alerta"),
    limit: int = Query(100, le=500),
    offset: int = Query(0, ge=0),
):
    query = db.query(Empresa).filter(Empresa.contador_id == current_user.id)
    if activa:
        query = query.filter(Empresa.activa == True)
    if buscar:
        term = f"%{buscar.strip().upper()}%"
        query = query.filter(or_(
            Empresa.razon_social.ilike(term),
            Empresa.ruc.ilike(f"%{buscar.strip()}%"),
            Empresa.nombre_comercial.ilike(term),
        ))
    if nivel_alerta: query = query.filter(Empresa.nivel_alerta == nivel_alerta)
    if regimen: query = query.filter(Empresa.regimen_tributario == regimen)
    if estado_sunat: query = query.filter(Empresa.estado_sunat == estado_sunat)

    if orden == "nombre":
        query = query.order_by(Empresa.razon_social)
    elif orden == "fecha":
        query = query.order_by(desc(Empresa.fecha_creacion))
    elif orden == "ruc":
        query = query.order_by(Empresa.ruc)
    else:
        orden_alerta = case(
            (Empresa.nivel_alerta == "ROJO", 0),
            (Empresa.nivel_alerta == "AMARILLO", 1),
            (Empresa.nivel_alerta == "VERDE", 2),
            else_=3,
        )
        query = query.order_by(orden_alerta, Empresa.razon_social)

    total = query.count()
    empresas = query.offset(offset).limit(limit).all()
    return EmpresaListResponse(total=total, empresas=[empresa_to_response(e) for e in empresas])


@router.post("", response_model=EmpresaResponse, status_code=201)
def crear_empresa(
    payload: EmpresaCreate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    validar_limite_plan(db, current_user)
    validar_ruc_empresa(db, current_user, payload.ruc)
    data = preparar_datos_empresa(payload.model_dump())
    empresa = Empresa(contador_id=current_user.id, **data)
    db.add(empresa)
    db.commit()
    db.refresh(empresa)
    registrar_log(db, current_user.id, empresa.id, "EMPRESA_CREADA",
                  f"Empresa {empresa.razon_social} (RUC {empresa.ruc}) creada")
    return empresa_to_response(empresa)


@router.get("/{empresa_id}", response_model=EmpresaDetalleResponse)
def obtener_empresa(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    total_pdt = db.query(func.count(PDT621.id)).filter_by(empresa_id=empresa.id).scalar()
    pdt_pendientes = db.query(func.count(PDT621.id)).filter(
        PDT621.empresa_id == empresa.id,
        PDT621.estado.in_(["DRAFT", "GENERATED"]),
    ).scalar()
    ultima = db.query(PDT621.fecha_presentacion_sunat).filter(
        PDT621.empresa_id == empresa.id,
        PDT621.estado == "ACCEPTED",
    ).order_by(desc(PDT621.fecha_presentacion_sunat)).first()
    proximo = db.query(CalendarioTributario.fecha_vencimiento).filter(
        CalendarioTributario.empresa_id == empresa.id,
        CalendarioTributario.estado == "PENDIENTE",
    ).order_by(CalendarioTributario.fecha_vencimiento).first()

    base = empresa_to_response(empresa)
    return EmpresaDetalleResponse(
        **base,
        total_pdt621s=total_pdt or 0,
        pdt621s_pendientes=pdt_pendientes or 0,
        ultima_declaracion=ultima[0] if ultima else None,
        proximo_vencimiento=proximo[0] if proximo else None,
    )


@router.put("/{empresa_id}", response_model=EmpresaResponse)
def actualizar_empresa(
    empresa_id: int,
    payload: EmpresaUpdate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    data = preparar_datos_empresa(payload.model_dump(exclude_unset=True))
    for field, value in data.items():
        setattr(empresa, field, value)
    db.commit()
    db.refresh(empresa)
    registrar_log(db, current_user.id, empresa.id, "EMPRESA_ACTUALIZADA",
                  f"Empresa {empresa.razon_social} actualizada")
    return empresa_to_response(empresa)


@router.delete("/{empresa_id}", status_code=204)
def eliminar_empresa(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    empresa.activa = False
    db.commit()
    registrar_log(db, current_user.id, empresa.id, "EMPRESA_ELIMINADA",
                  f"Empresa {empresa.razon_social} (RUC {empresa.ruc}) eliminada",
                  nivel="WARNING")


@router.post("/{empresa_id}/reactivar", response_model=EmpresaResponse)
def reactivar_empresa(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    if empresa.activa:
        raise HTTPException(status_code=400, detail="La empresa ya esta activa")
    validar_limite_plan(db, current_user)
    empresa.activa = True
    db.commit()
    db.refresh(empresa)
    return empresa_to_response(empresa)


@router.post("/{empresa_id}/recalcular-alertas", response_model=EmpresaResponse)
def recalcular_alertas(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    actualizar_alertas_empresa(db, empresa)
    db.refresh(empresa)
    return empresa_to_response(empresa)
