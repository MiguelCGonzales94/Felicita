# ============================================================
#  FELICITA - Entrega 1: Backend Empresas
#  Ejecutar desde la raiz del proyecto felicita/
#  .\entrega1_empresas_backend.ps1
# ============================================================

Write-Host ""
Write-Host "Entrega 1 - Backend de empresas" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# Crear carpeta services si no existe
New-Item -ItemType Directory -Force -Path "backend/app/services" | Out-Null
"" | Set-Content "backend/app/services/__init__.py"

# ============================================================
# utils/ruc_validator.py
# ============================================================
@'
"""
Validador de RUC peruano.
Algoritmo oficial SUNAT.
"""
import re


def validar_formato_ruc(ruc: str) -> bool:
    if not ruc:
        return False
    return bool(re.match(r"^\d{11}$", ruc))


def validar_digito_verificador_ruc(ruc: str) -> bool:
    if not validar_formato_ruc(ruc):
        return False
    factores = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]
    suma = sum(int(ruc[i]) * factores[i] for i in range(10))
    resto = suma % 11
    digito_esperado = 11 - resto
    if digito_esperado == 10:
        digito_esperado = 0
    elif digito_esperado == 11:
        digito_esperado = 1
    return int(ruc[10]) == digito_esperado


def validar_tipo_ruc(ruc: str) -> str:
    if not validar_formato_ruc(ruc):
        return "INVALIDO"
    prefijo = ruc[:2]
    tipos = {
        "10": "PERSONA_NATURAL",
        "15": "PERSONA_NATURAL_NO_DOMICILIADA",
        "17": "PERSONA_NATURAL_EXTRANJERA",
        "20": "PERSONA_JURIDICA",
    }
    return tipos.get(prefijo, "OTRO")


def validar_ruc_completo(ruc: str) -> dict:
    resultado = {
        "ruc": ruc, "formato_valido": False,
        "digito_verificador_valido": False,
        "tipo": "INVALIDO", "es_valido": False, "mensaje": "",
    }
    if not validar_formato_ruc(ruc):
        resultado["mensaje"] = "El RUC debe tener exactamente 11 digitos numericos"
        return resultado
    resultado["formato_valido"] = True
    resultado["tipo"] = validar_tipo_ruc(ruc)
    if resultado["tipo"] == "OTRO":
        resultado["mensaje"] = "El RUC debe empezar con 10, 15, 17 o 20"
        return resultado
    if not validar_digito_verificador_ruc(ruc):
        resultado["mensaje"] = "El digito verificador del RUC es incorrecto"
        return resultado
    resultado["digito_verificador_valido"] = True
    resultado["es_valido"] = True
    resultado["mensaje"] = "RUC valido"
    return resultado
'@ | Set-Content "backend/app/utils/ruc_validator.py"
Write-Host "  [OK] utils/ruc_validator.py" -ForegroundColor Green

# ============================================================
# utils/encryption.py
# ============================================================
@'
"""
Encriptacion/desencriptacion de datos sensibles (Clave SOL).
"""
from cryptography.fernet import Fernet
from app.config import settings
import base64
import hashlib


def _get_cipher() -> Fernet:
    key_bytes = settings.SECRET_KEY.encode("utf-8")
    digest = hashlib.sha256(key_bytes).digest()
    fernet_key = base64.urlsafe_b64encode(digest)
    return Fernet(fernet_key)


def encrypt_text(texto: str) -> str:
    if not texto:
        return ""
    cipher = _get_cipher()
    token = cipher.encrypt(texto.encode("utf-8"))
    return token.decode("utf-8")


def decrypt_text(texto_encriptado: str) -> str:
    if not texto_encriptado:
        return ""
    try:
        cipher = _get_cipher()
        decrypted = cipher.decrypt(texto_encriptado.encode("utf-8"))
        return decrypted.decode("utf-8")
    except Exception:
        return ""
'@ | Set-Content "backend/app/utils/encryption.py"
Write-Host "  [OK] utils/encryption.py" -ForegroundColor Green

# ============================================================
# services/sunat_service.py
# ============================================================
@'
"""
Servicio de consulta de RUC en SUNAT (mock por ahora).
"""
from typing import Optional
from pydantic import BaseModel


class FichaRUC(BaseModel):
    ruc: str
    razon_social: str
    estado: str
    condicion_domicilio: str
    direccion_fiscal: Optional[str] = None
    distrito: Optional[str] = None
    provincia: Optional[str] = None
    departamento: Optional[str] = None
    ubigeo: Optional[str] = None
    tipo_via: Optional[str] = None
    fuente: str = "MOCK"


_MOCK_DATA = {
    "20100070970": {
        "razon_social": "SAGA FALABELLA S.A.",
        "estado": "ACTIVO", "condicion_domicilio": "HABIDO",
        "direccion_fiscal": "AV. PASEO DE LA REPUBLICA NRO. 3220",
        "distrito": "San Isidro", "provincia": "Lima", "departamento": "Lima",
    },
    "20477314832": {
        "razon_social": "HIPERMERCADOS TOTTUS S.A.",
        "estado": "ACTIVO", "condicion_domicilio": "HABIDO",
        "direccion_fiscal": "AV. ANGAMOS ESTE NRO. 1805",
        "distrito": "Surquillo", "provincia": "Lima", "departamento": "Lima",
    },
    "20100047218": {
        "razon_social": "TELEFONICA DEL PERU S.A.A.",
        "estado": "ACTIVO", "condicion_domicilio": "HABIDO",
        "direccion_fiscal": "AV. ESCUELA MILITAR NRO. 798",
        "distrito": "Chorrillos", "provincia": "Lima", "departamento": "Lima",
    },
}


def consultar_ruc(ruc: str) -> Optional[FichaRUC]:
    if ruc in _MOCK_DATA:
        data = _MOCK_DATA[ruc]
        return FichaRUC(ruc=ruc, **data)
    return FichaRUC(
        ruc=ruc,
        razon_social=f"EMPRESA {ruc[-4:]} SAC",
        estado="ACTIVO", condicion_domicilio="HABIDO",
        direccion_fiscal="Direccion fiscal no disponible",
        distrito="Lima", provincia="Lima", departamento="Lima",
        fuente="GENERICO",
    )
'@ | Set-Content "backend/app/services/sunat_service.py"
Write-Host "  [OK] services/sunat_service.py" -ForegroundColor Green

# ============================================================
# services/empresa_service.py
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
from app.utils.encryption import encrypt_text


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


def validar_ruc_empresa(db: Session, contador: Usuario, ruc: str, empresa_id_excluir: int | None = None) -> None:
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
    log = LogEvento(
        usuario_id=usuario_id,
        empresa_id=empresa_id,
        tipo_evento=tipo,
        descripcion=descripcion,
        nivel=nivel,
    )
    db.add(log)
    db.commit()


def preparar_datos_empresa(data: dict) -> dict:
    if "clave_sol" in data and data["clave_sol"]:
        data["clave_sol_encrypted"] = encrypt_text(data["clave_sol"])
        del data["clave_sol"]
    elif "clave_sol" in data:
        del data["clave_sol"]

    if "razon_social" in data and data["razon_social"]:
        data["razon_social"] = data["razon_social"].strip().upper()

    if "ruc" in data and data["ruc"]:
        data["ruc"] = data["ruc"].strip()

    return data
'@ | Set-Content "backend/app/services/empresa_service.py"
Write-Host "  [OK] services/empresa_service.py" -ForegroundColor Green

# ============================================================
# schemas/empresa_schema.py
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
    usuario_sol: Optional[str] = None
    clave_sol: Optional[str] = None
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
    usuario_sol: Optional[str] = None
    clave_sol: Optional[str] = None
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
    tiene_clave_sol: bool = False
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
Write-Host "  [OK] schemas/empresa_schema.py" -ForegroundColor Green

# ============================================================
# routers/empresas.py
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
        "tiene_clave_sol": bool(empresa.clave_sol_encrypted),
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
    if nivel_alerta:
        query = query.filter(Empresa.nivel_alerta == nivel_alerta)
    if regimen:
        query = query.filter(Empresa.regimen_tributario == regimen)
    if estado_sunat:
        query = query.filter(Empresa.estado_sunat == estado_sunat)

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
    return EmpresaListResponse(
        total=total,
        empresas=[empresa_to_response(e) for e in empresas],
    )


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
Write-Host "  [OK] routers/empresas.py" -ForegroundColor Green

Write-Host ""
Write-Host "Agregando cryptography a requirements.txt..." -ForegroundColor Yellow

$reqPath = "backend/requirements.txt"
$reqContent = Get-Content $reqPath -Raw
if ($reqContent -notmatch "cryptography") {
    Add-Content $reqPath "cryptography==43.0.1"
    Write-Host "  [OK] cryptography agregada" -ForegroundColor Green
} else {
    Write-Host "  [OK] cryptography ya presente" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Entrega 1 aplicada!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Siguiente paso:" -ForegroundColor Yellow
Write-Host "  1. cd backend" -ForegroundColor White
Write-Host "  2. venv\Scripts\activate" -ForegroundColor White
Write-Host "  3. pip install cryptography" -ForegroundColor White
Write-Host "  4. Reiniciar uvicorn (Ctrl+C y correrlo otra vez)" -ForegroundColor White
Write-Host ""
Write-Host "Probar en http://localhost:8000/docs los nuevos endpoints:" -ForegroundColor Yellow
Write-Host "  GET    /api/v1/empresas/validar-ruc/20100070970" -ForegroundColor White
Write-Host "  GET    /api/v1/empresas?buscar=ALFA&nivel_alerta=VERDE" -ForegroundColor White
Write-Host "  POST   /api/v1/empresas (crear con validaciones)" -ForegroundColor White
Write-Host "  GET    /api/v1/empresas/1  (detalle con estadisticas)" -ForegroundColor White
Write-Host ""
