# ============================================================
#  FELICITA - Cambio 1: Clave SOL RUC/DNI + credenciales API SUNAT
#  .\cambio1_clave_sol.ps1
# ============================================================

Write-Host ""
Write-Host "Cambio 1 - Clave SOL RUC/DNI + credenciales SUNAT API" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# models/models.py - Agregar campos a Empresa
# ============================================================

Write-Host "Aplicando cambios al modelo Empresa..." -ForegroundColor Yellow

$modelsPath = "backend/app/models/models.py"
$modelsContent = Get-Content $modelsPath -Raw

# Reemplazar bloque de clave SOL por version ampliada
$antiguo = @"
    # Clave SOL (encriptada)
    usuario_sol = Column(String(50))
    clave_sol_encrypted = Column(Text)
"@

$nuevo = @"
    # Acceso SUNAT
    tipo_acceso_sol = Column(String(10), default="RUC")  # RUC o DNI
    dni_sol = Column(String(8))                          # Si accede con DNI
    usuario_sol = Column(String(50))                     # Usuario (si es RUC)
    clave_sol_encrypted = Column(Text)                   # Contrasena encriptada
    # Credenciales API SUNAT (para SIRE)
    sunat_client_id_encrypted = Column(Text)
    sunat_client_secret_encrypted = Column(Text)
"@

if ($modelsContent -match "tipo_acceso_sol") {
    Write-Host "  [SKIP] Modelo Empresa ya actualizado" -ForegroundColor Gray
} else {
    $modelsContent = $modelsContent -replace [regex]::Escape($antiguo), $nuevo
    Set-Content $modelsPath $modelsContent -NoNewline
    Write-Host "  [OK] Modelo Empresa actualizado" -ForegroundColor Green
}

# ============================================================
# Script de migracion SQL - agregar columnas nuevas
# ============================================================

$migracionSql = @"
-- Migracion manual: agregar campos de credenciales SUNAT
-- Ejecutar en pgAdmin o psql

ALTER TABLE empresas
  ADD COLUMN IF NOT EXISTS tipo_acceso_sol VARCHAR(10) DEFAULT 'RUC',
  ADD COLUMN IF NOT EXISTS dni_sol VARCHAR(8),
  ADD COLUMN IF NOT EXISTS sunat_client_id_encrypted TEXT,
  ADD COLUMN IF NOT EXISTS sunat_client_secret_encrypted TEXT;

-- Actualizar registros existentes
UPDATE empresas SET tipo_acceso_sol = 'RUC' WHERE tipo_acceso_sol IS NULL;
"@

New-Item -ItemType Directory -Force -Path "backend/migrations" | Out-Null
Set-Content "backend/migrations/001_credenciales_sunat.sql" $migracionSql
Write-Host "  [OK] Script SQL: backend/migrations/001_credenciales_sunat.sql" -ForegroundColor Green

# ============================================================
# services/empresa_service.py - Logica para las nuevas credenciales
# ============================================================

@'
"""
Servicio de Empresas - Logica de negocio.
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status
from datetime import date, timedelta

from app.models.models import Usuario, Empresa, PlanSuscripcion, LogEvento
from app.utils.ruc_validator import validar_ruc_completo
from app.utils.encryption import encrypt_text, decrypt_text


def validar_limite_plan(db: Session, contador: Usuario) -> None:
    plan = db.query(PlanSuscripcion).filter_by(nombre=contador.plan_actual).first()
    if not plan:
        raise HTTPException(status_code=500, detail=f"Plan {contador.plan_actual} no configurado")
    total = db.query(func.count(Empresa.id)).filter(
        Empresa.contador_id == contador.id,
        Empresa.activa == True,
    ).scalar()
    if total >= plan.max_empresas:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Has alcanzado el limite de {plan.max_empresas} empresas de tu plan {plan.nombre}. Actualiza tu plan para agregar mas."
        )


def validar_ruc_empresa(db: Session, contador: Usuario, ruc: str, empresa_id_excluir=None) -> None:
    resultado = validar_ruc_completo(ruc)
    if not resultado["es_valido"]:
        raise HTTPException(status_code=400, detail=resultado["mensaje"])
    query = db.query(Empresa).filter(
        Empresa.ruc == ruc,
        Empresa.contador_id == contador.id,
        Empresa.activa == True,
    )
    if empresa_id_excluir:
        query = query.filter(Empresa.id != empresa_id_excluir)
    if query.first():
        raise HTTPException(status_code=400, detail="Ya tienes una empresa registrada con ese RUC")


def calcular_nivel_alerta(empresa: Empresa, db: Session) -> tuple:
    from app.models.models import CalendarioTributario
    hoy = date.today()
    if empresa.estado_sunat == "OBSERVADO":
        return "ROJO", "RUC observado por SUNAT"
    if empresa.estado_sunat in ("BAJA", "SUSPENDIDO"):
        return "ROJO", f"RUC en estado {empresa.estado_sunat}"
    if empresa.condicion_domicilio == "NO_HABIDO":
        return "ROJO", "Domicilio fiscal NO HABIDO"
    vencidas = db.query(CalendarioTributario).filter(
        CalendarioTributario.empresa_id == empresa.id,
        CalendarioTributario.estado == "PENDIENTE",
        CalendarioTributario.fecha_vencimiento < hoy,
    ).count()
    if vencidas > 0:
        return "ROJO", f"{vencidas} declaracion(es) vencida(s)"
    proximas = db.query(CalendarioTributario).filter(
        CalendarioTributario.empresa_id == empresa.id,
        CalendarioTributario.estado == "PENDIENTE",
        CalendarioTributario.fecha_vencimiento >= hoy,
        CalendarioTributario.fecha_vencimiento <= hoy + timedelta(days=5),
    ).count()
    if proximas > 0:
        return "AMARILLO", f"{proximas} vencimiento(s) en los proximos 5 dias"
    return "VERDE", None


def actualizar_alertas_empresa(db: Session, empresa: Empresa) -> None:
    nivel, motivo = calcular_nivel_alerta(empresa, db)
    empresa.nivel_alerta = nivel
    empresa.motivo_alerta = motivo
    db.commit()


def registrar_log(db: Session, usuario_id: int, empresa_id, tipo: str, descripcion: str, nivel: str = "INFO") -> None:
    log = LogEvento(usuario_id=usuario_id, empresa_id=empresa_id,
                    tipo_evento=tipo, descripcion=descripcion, nivel=nivel)
    db.add(log)
    db.commit()


def preparar_datos_empresa(data: dict) -> dict:
    """Prepara los datos antes de guardar: encripta credenciales y normaliza."""
    # Clave SOL
    if "clave_sol" in data:
        if data["clave_sol"]:
            data["clave_sol_encrypted"] = encrypt_text(data["clave_sol"])
        del data["clave_sol"]

    # Client ID SUNAT
    if "sunat_client_id" in data:
        if data["sunat_client_id"]:
            data["sunat_client_id_encrypted"] = encrypt_text(data["sunat_client_id"])
        del data["sunat_client_id"]

    # Client Secret SUNAT
    if "sunat_client_secret" in data:
        if data["sunat_client_secret"]:
            data["sunat_client_secret_encrypted"] = encrypt_text(data["sunat_client_secret"])
        del data["sunat_client_secret"]

    # Razon social en mayusculas
    if "razon_social" in data and data["razon_social"]:
        data["razon_social"] = data["razon_social"].strip().upper()

    # RUC sin espacios
    if "ruc" in data and data["ruc"]:
        data["ruc"] = data["ruc"].strip()

    # DNI sin espacios, solo digitos
    if "dni_sol" in data and data["dni_sol"]:
        data["dni_sol"] = "".join(c for c in data["dni_sol"] if c.isdigit())[:8]

    # Validar tipo de acceso
    if "tipo_acceso_sol" in data:
        if data["tipo_acceso_sol"] not in ("RUC", "DNI"):
            data["tipo_acceso_sol"] = "RUC"

    return data


def obtener_credenciales_sunat(empresa: Empresa) -> dict:
    """
    Desencripta y retorna las credenciales para usar en SUNAT API.
    No incluye datos encriptados, solo los valores listos para usar.
    """
    return {
        "tipo_acceso": empresa.tipo_acceso_sol or "RUC",
        "ruc": empresa.ruc,
        "dni": empresa.dni_sol,
        "usuario": empresa.usuario_sol,
        "clave_sol": decrypt_text(empresa.clave_sol_encrypted) if empresa.clave_sol_encrypted else "",
        "client_id": decrypt_text(empresa.sunat_client_id_encrypted) if empresa.sunat_client_id_encrypted else "",
        "client_secret": decrypt_text(empresa.sunat_client_secret_encrypted) if empresa.sunat_client_secret_encrypted else "",
    }
'@ | Set-Content "backend/app/services/empresa_service.py"
Write-Host "  [OK] services/empresa_service.py actualizado" -ForegroundColor Green

# ============================================================
# schemas/empresa_schema.py - Nuevos campos
# ============================================================

@'
from pydantic import BaseModel, field_validator
from typing import Optional
from datetime import datetime, date


class EmpresaCreate(BaseModel):
    ruc: str
    razon_social: str
    nombre_comercial: Optional[str] = None
    direccion_fiscal: str
    distrito: Optional[str] = None
    provincia: Optional[str] = None
    departamento: Optional[str] = None
    regimen_tributario: str = "RG"
    fecha_inicio_actividades: Optional[date] = None
    estado_sunat: str = "ACTIVO"
    condicion_domicilio: str = "HABIDO"
    representante_legal: Optional[str] = None
    email_empresa: Optional[str] = None
    telefono_empresa: Optional[str] = None

    # Credenciales SUNAT SOL
    tipo_acceso_sol: str = "RUC"      # RUC o DNI
    dni_sol: Optional[str] = None
    usuario_sol: Optional[str] = None
    clave_sol: Optional[str] = None

    # Credenciales API SIRE (opcional)
    sunat_client_id: Optional[str] = None
    sunat_client_secret: Optional[str] = None

    color_identificacion: str = "#3B82F6"
    notas_contador: Optional[str] = None

    @field_validator("ruc")
    @classmethod
    def ruc_solo_numeros(cls, v):
        v = v.strip()
        if not v.isdigit():
            raise ValueError("El RUC debe contener solo numeros")
        if len(v) != 11:
            raise ValueError("El RUC debe tener 11 digitos")
        return v

    @field_validator("regimen_tributario")
    @classmethod
    def regimen_valido(cls, v):
        if v not in ("RG", "RMT", "RER", "NRUS"):
            raise ValueError("Regimen invalido")
        return v

    @field_validator("tipo_acceso_sol")
    @classmethod
    def tipo_acceso_valido(cls, v):
        if v not in ("RUC", "DNI"):
            raise ValueError("Tipo de acceso debe ser RUC o DNI")
        return v


class EmpresaUpdate(BaseModel):
    razon_social: Optional[str] = None
    nombre_comercial: Optional[str] = None
    direccion_fiscal: Optional[str] = None
    distrito: Optional[str] = None
    provincia: Optional[str] = None
    departamento: Optional[str] = None
    regimen_tributario: Optional[str] = None
    estado_sunat: Optional[str] = None
    condicion_domicilio: Optional[str] = None
    representante_legal: Optional[str] = None
    email_empresa: Optional[str] = None
    telefono_empresa: Optional[str] = None

    tipo_acceso_sol: Optional[str] = None
    dni_sol: Optional[str] = None
    usuario_sol: Optional[str] = None
    clave_sol: Optional[str] = None
    sunat_client_id: Optional[str] = None
    sunat_client_secret: Optional[str] = None

    color_identificacion: Optional[str] = None
    notas_contador: Optional[str] = None
    activa: Optional[bool] = None


class EmpresaResponse(BaseModel):
    id: int
    ruc: str
    razon_social: str
    nombre_comercial: Optional[str]
    direccion_fiscal: str
    distrito: Optional[str]
    provincia: Optional[str]
    departamento: Optional[str]
    regimen_tributario: str
    estado_sunat: str
    condicion_domicilio: str
    representante_legal: Optional[str]
    email_empresa: Optional[str]
    telefono_empresa: Optional[str]
    nivel_alerta: str
    motivo_alerta: Optional[str]
    color_identificacion: str

    # Indicadores (sin exponer los valores encriptados)
    tipo_acceso_sol: str = "RUC"
    dni_sol: Optional[str] = None
    usuario_sol: Optional[str] = None
    tiene_clave_sol: bool = False
    tiene_credenciales_api_sunat: bool = False

    activa: bool
    fecha_creacion: datetime
    model_config = {"from_attributes": True}


class EmpresaDetalleResponse(EmpresaResponse):
    total_pdt621s: int = 0
    pdt621s_pendientes: int = 0
    ultima_declaracion: Optional[datetime] = None
    proximo_vencimiento: Optional[date] = None


class ValidacionRUCResponse(BaseModel):
    ruc: str
    es_valido: bool
    mensaje: str
    tipo: str
    razon_social: Optional[str] = None
    estado_sunat: Optional[str] = None
    condicion_domicilio: Optional[str] = None
    direccion_fiscal: Optional[str] = None
    distrito: Optional[str] = None
    provincia: Optional[str] = None
    departamento: Optional[str] = None
    ya_registrada: bool = False


class EmpresaListResponse(BaseModel):
    total: int
    empresas: list[EmpresaResponse]
'@ | Set-Content "backend/app/schemas/empresa_schema.py"
Write-Host "  [OK] schemas/empresa_schema.py actualizado" -ForegroundColor Green

# ============================================================
# routers/empresas.py - empresa_to_response con nuevos flags
# ============================================================

@'
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
'@ | Set-Content "backend/app/routers/empresas.py"
Write-Host "  [OK] routers/empresas.py actualizado" -ForegroundColor Green

# ============================================================
# FRONTEND - types/empresa.ts
# ============================================================

@'
export interface Empresa {
  id: number
  ruc: string
  razon_social: string
  nombre_comercial: string | null
  direccion_fiscal: string
  distrito: string | null
  provincia: string | null
  departamento: string | null
  regimen_tributario: string
  estado_sunat: string
  condicion_domicilio: string
  representante_legal: string | null
  email_empresa: string | null
  telefono_empresa: string | null
  nivel_alerta: 'VERDE' | 'AMARILLO' | 'ROJO'
  motivo_alerta: string | null
  color_identificacion: string
  tipo_acceso_sol: 'RUC' | 'DNI'
  dni_sol: string | null
  usuario_sol: string | null
  tiene_clave_sol: boolean
  tiene_credenciales_api_sunat: boolean
  activa: boolean
  fecha_creacion: string
}

export interface EmpresaDetalle extends Empresa {
  total_pdt621s: number
  pdt621s_pendientes: number
  ultima_declaracion: string | null
  proximo_vencimiento: string | null
}

export interface ValidacionRUC {
  ruc: string
  es_valido: boolean
  mensaje: string
  tipo: string
  razon_social: string | null
  estado_sunat: string | null
  condicion_domicilio: string | null
  direccion_fiscal: string | null
  distrito: string | null
  provincia: string | null
  departamento: string | null
  ya_registrada: boolean
}

export interface EmpresaListFilters {
  buscar?: string
  nivel_alerta?: 'VERDE' | 'AMARILLO' | 'ROJO'
  regimen?: 'RG' | 'RMT' | 'RER' | 'NRUS'
  orden?: 'alerta' | 'nombre' | 'fecha' | 'ruc'
}

export interface EmpresaListResponse {
  total: number
  empresas: Empresa[]
}

export const REGIMENES_LABEL: Record<string, string> = {
  RG:   'Regimen General',
  RMT:  'Regimen MYPE Tributario',
  RER:  'Regimen Especial',
  NRUS: 'Nuevo RUS',
}

export const COLORES_EMPRESA = [
  '#3B82F6', '#10B981', '#F59E0B', '#EF4444',
  '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16',
  '#F97316', '#6366F1',
]
'@ | Set-Content "frontend/src/types/empresa.ts"
Write-Host "  [OK] frontend/types/empresa.ts" -ForegroundColor Green

# ============================================================
# FRONTEND - EmpresaForm.tsx con toggle RUC/DNI
# ============================================================

@'
import { useState, useEffect } from 'react'
import { Check, AlertCircle, Loader2, Search, Shield, KeyRound, Info } from 'lucide-react'
import { empresaService } from '../services/empresaService'
import { useDebounce } from '../hooks/useDebounce'
import { COLORES_EMPRESA } from '../types/empresa'
import type { Empresa, ValidacionRUC } from '../types/empresa'

interface EmpresaFormProps {
  empresa?: Empresa | null
  onSubmit: (data: any) => Promise<void>
  onCancel: () => void
  loading?: boolean
}

export default function EmpresaForm({ empresa, onSubmit, onCancel, loading }: EmpresaFormProps) {
  const esEdicion = !!empresa

  const [form, setForm] = useState({
    ruc: empresa?.ruc || '',
    razon_social: empresa?.razon_social || '',
    nombre_comercial: empresa?.nombre_comercial || '',
    direccion_fiscal: empresa?.direccion_fiscal || '',
    distrito: empresa?.distrito || '',
    provincia: empresa?.provincia || '',
    departamento: empresa?.departamento || '',
    regimen_tributario: empresa?.regimen_tributario || 'RG',
    estado_sunat: empresa?.estado_sunat || 'ACTIVO',
    condicion_domicilio: empresa?.condicion_domicilio || 'HABIDO',
    representante_legal: empresa?.representante_legal || '',
    email_empresa: empresa?.email_empresa || '',
    telefono_empresa: empresa?.telefono_empresa || '',

    // Acceso SUNAT (replica el toggle RUC/DNI de SUNAT)
    tipo_acceso_sol: empresa?.tipo_acceso_sol || 'RUC',
    dni_sol: empresa?.dni_sol || '',
    usuario_sol: empresa?.usuario_sol || '',
    clave_sol: '',

    // API SIRE (opcional)
    sunat_client_id: '',
    sunat_client_secret: '',

    color_identificacion: empresa?.color_identificacion || COLORES_EMPRESA[0],
    notas_contador: '',
  })

  const [error, setError] = useState('')
  const [validacionRuc, setValidacionRuc] = useState<ValidacionRUC | null>(null)
  const [validandoRuc, setValidandoRuc] = useState(false)
  const rucDebounced = useDebounce(form.ruc, 500)

  useEffect(() => {
    if (esEdicion) return
    if (rucDebounced.length !== 11 || !/^\d+$/.test(rucDebounced)) {
      setValidacionRuc(null)
      return
    }
    validarRucAuto(rucDebounced)
  }, [rucDebounced, esEdicion])

  async function validarRucAuto(ruc: string) {
    setValidandoRuc(true)
    try {
      const res = await empresaService.validarRuc(ruc)
      setValidacionRuc(res)
      if (res.es_valido && !res.ya_registrada) {
        setForm(f => ({
          ...f,
          razon_social: res.razon_social || f.razon_social,
          direccion_fiscal: res.direccion_fiscal || f.direccion_fiscal,
          distrito: res.distrito || f.distrito,
          provincia: res.provincia || f.provincia,
          departamento: res.departamento || f.departamento,
          estado_sunat: res.estado_sunat || f.estado_sunat,
          condicion_domicilio: res.condicion_domicilio || f.condicion_domicilio,
        }))
      }
    } finally {
      setValidandoRuc(false)
    }
  }

  function updateField(field: string, value: any) {
    setForm(f => ({ ...f, [field]: value }))
    setError('')
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    if (!esEdicion && !form.ruc) return setError('El RUC es obligatorio')
    if (!form.razon_social) return setError('La razon social es obligatoria')
    if (!form.direccion_fiscal) return setError('La direccion fiscal es obligatoria')
    if (!esEdicion && (!validacionRuc || !validacionRuc.es_valido)) {
      return setError('Verifica que el RUC sea valido')
    }
    if (!esEdicion && validacionRuc?.ya_registrada) {
      return setError('Esta empresa ya esta registrada en tu cuenta')
    }

    // Validar DNI si se eligio acceso por DNI
    if (form.tipo_acceso_sol === 'DNI' && form.dni_sol && form.dni_sol.length !== 8) {
      return setError('El DNI debe tener 8 digitos')
    }

    const payload: any = { ...form }
    if (esEdicion) delete payload.ruc
    if (!payload.clave_sol) delete payload.clave_sol
    if (!payload.usuario_sol) delete payload.usuario_sol
    if (!payload.dni_sol) delete payload.dni_sol
    if (!payload.sunat_client_id) delete payload.sunat_client_id
    if (!payload.sunat_client_secret) delete payload.sunat_client_secret
    if (!payload.notas_contador) delete payload.notas_contador

    try {
      await onSubmit(payload)
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al guardar la empresa')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      {/* Identificacion */}
      <Section title="Identificacion">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="md:col-span-1">
            <label className="label">RUC *</label>
            <div className="relative">
              <input
                type="text" value={form.ruc}
                onChange={e => updateField('ruc', e.target.value.replace(/\D/g, '').slice(0, 11))}
                className="input pr-9 font-mono" placeholder="20123456789"
                disabled={esEdicion || loading} maxLength={11}
              />
              {!esEdicion && (
                <div className="absolute right-3 top-1/2 -translate-y-1/2">
                  {validandoRuc ? <Loader2 size={14} className="text-gray-400 animate-spin" />
                    : validacionRuc?.es_valido && !validacionRuc.ya_registrada ? <Check size={14} className="text-success-600" />
                    : validacionRuc && (!validacionRuc.es_valido || validacionRuc.ya_registrada) ? <AlertCircle size={14} className="text-danger-600" />
                    : form.ruc.length === 11 ? <Search size={14} className="text-gray-400" />
                    : null}
                </div>
              )}
            </div>
            {!esEdicion && validacionRuc && (
              <p className={`text-xs mt-1 ${
                validacionRuc.es_valido && !validacionRuc.ya_registrada ? 'text-success-600' : 'text-danger-600'
              }`}>{validacionRuc.mensaje}</p>
            )}
          </div>

          <div className="md:col-span-2">
            <label className="label">Razon social *</label>
            <input type="text" value={form.razon_social}
              onChange={e => updateField('razon_social', e.target.value)}
              className="input" placeholder="EMPRESA EJEMPLO SAC" disabled={loading} />
          </div>

          <div className="md:col-span-2">
            <label className="label">Nombre comercial</label>
            <input type="text" value={form.nombre_comercial || ''}
              onChange={e => updateField('nombre_comercial', e.target.value)}
              className="input" placeholder="Opcional" disabled={loading} />
          </div>

          <div>
            <label className="label">Color</label>
            <div className="flex flex-wrap gap-1.5">
              {COLORES_EMPRESA.map(color => (
                <button key={color} type="button"
                  onClick={() => updateField('color_identificacion', color)}
                  className={`w-7 h-7 rounded-full transition-transform ${
                    form.color_identificacion === color ? 'ring-2 ring-offset-2 ring-brand-800 scale-110' : 'hover:scale-110'
                  }`}
                  style={{ backgroundColor: color }} title={color} />
              ))}
            </div>
          </div>
        </div>
      </Section>

      {/* Ubicacion */}
      <Section title="Ubicacion">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="label">Direccion fiscal *</label>
            <input type="text" value={form.direccion_fiscal}
              onChange={e => updateField('direccion_fiscal', e.target.value)}
              className="input" placeholder="Av. Principal 123, Piso 5" disabled={loading} />
          </div>
          <div>
            <label className="label">Distrito</label>
            <input type="text" value={form.distrito || ''}
              onChange={e => updateField('distrito', e.target.value)}
              className="input" placeholder="San Isidro" disabled={loading} />
          </div>
          <div>
            <label className="label">Provincia</label>
            <input type="text" value={form.provincia || ''}
              onChange={e => updateField('provincia', e.target.value)}
              className="input" placeholder="Lima" disabled={loading} />
          </div>
          <div className="md:col-span-2">
            <label className="label">Departamento</label>
            <input type="text" value={form.departamento || ''}
              onChange={e => updateField('departamento', e.target.value)}
              className="input" placeholder="Lima" disabled={loading} />
          </div>
        </div>
      </Section>

      {/* Configuracion tributaria */}
      <Section title="Configuracion tributaria">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="label">Regimen *</label>
            <select value={form.regimen_tributario}
              onChange={e => updateField('regimen_tributario', e.target.value)}
              className="input" disabled={loading}>
              <option value="RG">Regimen General</option>
              <option value="RMT">Regimen MYPE Tributario</option>
              <option value="RER">Regimen Especial</option>
              <option value="NRUS">Nuevo RUS</option>
            </select>
          </div>
          <div>
            <label className="label">Estado SUNAT</label>
            <select value={form.estado_sunat}
              onChange={e => updateField('estado_sunat', e.target.value)}
              className="input" disabled={loading}>
              <option value="ACTIVO">Activo</option>
              <option value="BAJA">Baja</option>
              <option value="SUSPENDIDO">Suspendido</option>
              <option value="OBSERVADO">Observado</option>
            </select>
          </div>
          <div>
            <label className="label">Condicion domicilio</label>
            <select value={form.condicion_domicilio}
              onChange={e => updateField('condicion_domicilio', e.target.value)}
              className="input" disabled={loading}>
              <option value="HABIDO">Habido</option>
              <option value="NO_HABIDO">No habido</option>
              <option value="NO_HALLADO">No hallado</option>
            </select>
          </div>
        </div>
      </Section>

      {/* Contacto */}
      <Section title="Contacto">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="label">Representante legal</label>
            <input type="text" value={form.representante_legal || ''}
              onChange={e => updateField('representante_legal', e.target.value)}
              className="input" placeholder="Nombres y apellidos" disabled={loading} />
          </div>
          <div>
            <label className="label">Email</label>
            <input type="email" value={form.email_empresa || ''}
              onChange={e => updateField('email_empresa', e.target.value)}
              className="input" placeholder="contacto@empresa.com" disabled={loading} />
          </div>
          <div>
            <label className="label">Telefono</label>
            <input type="tel" value={form.telefono_empresa || ''}
              onChange={e => updateField('telefono_empresa', e.target.value)}
              className="input" placeholder="(01) 234-5678" disabled={loading} />
          </div>
        </div>
      </Section>

      {/* Clave SOL - replica del diseno SUNAT */}
      <Section
        title="Acceso SUNAT Operaciones en Linea"
        description="Credenciales encriptadas para acceder a SUNAT (opcional)"
        icon={<Shield size={14} className="text-brand-800" />}
      >
        {/* Toggle RUC / DNI estilo SUNAT */}
        <div className="bg-sidebar rounded-t-lg p-3">
          <p className="text-[11px] text-slate-300 font-semibold uppercase tracking-wider mb-2">
            SUNAT Operaciones en Linea
          </p>
          <div className="inline-flex bg-white rounded-md overflow-hidden shadow-sm">
            <button type="button"
              onClick={() => updateField('tipo_acceso_sol', 'RUC')}
              className={`px-6 py-1.5 text-sm font-semibold transition-colors ${
                form.tipo_acceso_sol === 'RUC' ? 'bg-brand-700 text-white' : 'text-gray-600 hover:bg-gray-50'
              }`}>
              RUC
            </button>
            <button type="button"
              onClick={() => updateField('tipo_acceso_sol', 'DNI')}
              className={`px-6 py-1.5 text-sm font-semibold transition-colors ${
                form.tipo_acceso_sol === 'DNI' ? 'bg-brand-700 text-white' : 'text-gray-600 hover:bg-gray-50'
              }`}>
              DNI
            </button>
          </div>
        </div>

        {/* Campos segun tipo */}
        <div className="bg-gray-50 border border-gray-200 rounded-b-lg p-4 space-y-3">
          {form.tipo_acceso_sol === 'RUC' ? (
            <>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="label text-xs">RUC</label>
                  <input type="text" value={form.ruc}
                    className="input font-mono bg-gray-100" disabled
                    placeholder="RUC de la empresa" />
                  <p className="text-[11px] text-gray-500 mt-1">Se usa el RUC registrado arriba</p>
                </div>
                <div>
                  <label className="label text-xs">Usuario SOL</label>
                  <input type="text" value={form.usuario_sol}
                    onChange={e => updateField('usuario_sol', e.target.value.toUpperCase())}
                    className="input font-mono" placeholder="Ejemplo: USUARIO1" disabled={loading} />
                </div>
              </div>
            </>
          ) : (
            <div>
              <label className="label text-xs">DNI</label>
              <input type="text" value={form.dni_sol}
                onChange={e => updateField('dni_sol', e.target.value.replace(/\D/g, '').slice(0, 8))}
                className="input font-mono" placeholder="12345678" maxLength={8} disabled={loading} />
              <p className="text-[11px] text-gray-500 mt-1">8 digitos</p>
            </div>
          )}

          <div>
            <label className="label text-xs">Contrasena SOL</label>
            <input type="password" value={form.clave_sol}
              onChange={e => updateField('clave_sol', e.target.value)}
              className="input font-mono"
              placeholder={esEdicion && empresa?.tiene_clave_sol ? '(configurada - dejar vacio para no cambiar)' : 'Contrasena SOL'}
              disabled={loading} />
          </div>
        </div>
      </Section>

      {/* Credenciales API SUNAT (para SIRE) */}
      <Section
        title="Credenciales API SUNAT (para SIRE)"
        description="Necesarias para descargar propuestas RCE/RVIE automaticamente. Se obtienen en SUNAT > Credenciales API."
        icon={<KeyRound size={14} className="text-brand-800" />}
      >
        <div className="bg-brand-50 border border-brand-200 rounded-lg p-3 mb-3 flex gap-2 text-xs">
          <Info size={14} className="text-brand-800 flex-shrink-0 mt-0.5" />
          <div className="text-brand-900">
            Estas credenciales son opcionales. Si las configuras, Felicita podra descargar automaticamente
            las ventas y compras del mes desde SUNAT para prellenar el PDT 621.
            <br />
            <span className="text-[11px] text-brand-700">
              Obtenerlas: SUNAT Operaciones en Linea &gt; Mi RUC y Otros Registros &gt; Credenciales API
            </span>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="label">Client ID</label>
            <input type="text" value={form.sunat_client_id}
              onChange={e => updateField('sunat_client_id', e.target.value)}
              className="input font-mono text-xs"
              placeholder={esEdicion && empresa?.tiene_credenciales_api_sunat ? '(configurado)' : 'aabbccdd-1234-...'}
              disabled={loading} />
          </div>
          <div>
            <label className="label">Client Secret</label>
            <input type="password" value={form.sunat_client_secret}
              onChange={e => updateField('sunat_client_secret', e.target.value)}
              className="input font-mono text-xs"
              placeholder={esEdicion && empresa?.tiene_credenciales_api_sunat ? '(configurado)' : 'CLIENT SECRET'}
              disabled={loading} />
          </div>
        </div>
      </Section>

      {error && (
        <div className="bg-danger-50 border border-danger-600/20 text-danger-900 text-sm rounded-lg px-4 py-3 flex items-start gap-2">
          <AlertCircle size={16} className="flex-shrink-0 mt-0.5" />
          <span>{error}</span>
        </div>
      )}

      <div className="flex items-center justify-end gap-2 pt-4 border-t border-gray-100">
        <button type="button" onClick={onCancel} className="btn-secondary" disabled={loading}>
          Cancelar
        </button>
        <button type="submit" className="btn-primary flex items-center gap-2" disabled={loading || validandoRuc}>
          {loading && <Loader2 size={14} className="animate-spin" />}
          {esEdicion ? 'Guardar cambios' : 'Crear empresa'}
        </button>
      </div>
    </form>
  )
}

function Section({ title, description, icon, children }: {
  title: string
  description?: string
  icon?: React.ReactNode
  children: React.ReactNode
}) {
  return (
    <div>
      <div className="mb-3 flex items-start gap-2">
        {icon && <div className="pt-0.5">{icon}</div>}
        <div>
          <h3 className="font-heading font-bold text-gray-900 text-sm">{title}</h3>
          {description && <p className="text-xs text-gray-500 mt-0.5">{description}</p>}
        </div>
      </div>
      {children}
    </div>
  )
}
'@ | Set-Content "frontend/src/components/EmpresaForm.tsx"
Write-Host "  [OK] frontend/components/EmpresaForm.tsx actualizado" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Cambio 1 aplicado!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PASO MANUAL OBLIGATORIO: ejecutar en pgAdmin o psql:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  ALTER TABLE empresas" -ForegroundColor White
Write-Host "    ADD COLUMN IF NOT EXISTS tipo_acceso_sol VARCHAR(10) DEFAULT 'RUC'," -ForegroundColor White
Write-Host "    ADD COLUMN IF NOT EXISTS dni_sol VARCHAR(8)," -ForegroundColor White
Write-Host "    ADD COLUMN IF NOT EXISTS sunat_client_id_encrypted TEXT," -ForegroundColor White
Write-Host "    ADD COLUMN IF NOT EXISTS sunat_client_secret_encrypted TEXT;" -ForegroundColor White
Write-Host ""
Write-Host "Luego reinicia uvicorn (Ctrl+C y lo correrlo de nuevo)." -ForegroundColor Yellow
Write-Host ""
Write-Host "Probar:" -ForegroundColor Yellow
Write-Host "  1. Ir a /empresas" -ForegroundColor White
Write-Host "  2. Click 'Editar' en EMPRESA GAMMA SA" -ForegroundColor White
Write-Host "  3. Bajar a 'Acceso SUNAT Operaciones en Linea'" -ForegroundColor White
Write-Host "  4. Probar el toggle RUC / DNI" -ForegroundColor White
Write-Host "  5. Guardar" -ForegroundColor White
Write-Host ""
