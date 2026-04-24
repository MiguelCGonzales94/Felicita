# ============================================================
#  FELICITA - Script de instalacion completa
#  Ejecutar desde PowerShell como administrador:
#  .\setup_felicita.ps1
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   FELICITA - Setup del proyecto" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Carpeta raiz
$ROOT = "felicita"
New-Item -ItemType Directory -Force -Path $ROOT | Out-Null

# ============================================================
# BACKEND - Estructura de carpetas
# ============================================================
$dirs = @(
    "$ROOT/backend/app/models",
    "$ROOT/backend/app/schemas",
    "$ROOT/backend/app/routers",
    "$ROOT/backend/app/services",
    "$ROOT/backend/app/dependencies",
    "$ROOT/backend/app/utils",
    "$ROOT/backend/app/tasks",
    "$ROOT/backend/tests",
    "$ROOT/frontend/src/pages/admin",
    "$ROOT/frontend/src/pages/contador",
    "$ROOT/frontend/src/components",
    "$ROOT/frontend/src/services",
    "$ROOT/frontend/src/hooks",
    "$ROOT/frontend/src/store",
    "$ROOT/frontend/src/types",
    "$ROOT/docs"
)
foreach ($dir in $dirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Write-Host "  [OK] Carpetas creadas" -ForegroundColor Green

# ============================================================
# .env
# ============================================================
@"
DATABASE_URL=postgresql://felicita_user:felicita2026@localhost:5432/felicita_db
SECRET_KEY=felicita-secret-key-2026-cambia-esto-en-produccion
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=480
DEBUG=True
"@ | Set-Content "$ROOT/backend/.env"

# ============================================================
# requirements.txt
# ============================================================
@"
fastapi==0.115.0
uvicorn[standard]==0.30.6
sqlalchemy==2.0.35
alembic==1.13.3
psycopg2-binary==2.9.9
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dotenv==1.0.1
pydantic-settings==2.5.2
pydantic[email]==2.9.2
python-multipart==0.0.12
"@ | Set-Content "$ROOT/backend/requirements.txt"

# ============================================================
# app/__init__.py
# ============================================================
"" | Set-Content "$ROOT/backend/app/__init__.py"
"" | Set-Content "$ROOT/backend/app/models/__init__.py"
"" | Set-Content "$ROOT/backend/app/schemas/__init__.py"
"" | Set-Content "$ROOT/backend/app/routers/__init__.py"
"" | Set-Content "$ROOT/backend/app/services/__init__.py"
"" | Set-Content "$ROOT/backend/app/dependencies/__init__.py"
"" | Set-Content "$ROOT/backend/app/utils/__init__.py"
"" | Set-Content "$ROOT/backend/app/tasks/__init__.py"

# ============================================================
# config.py
# ============================================================
@"
from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql://felicita_user:felicita2026@localhost:5432/felicita_db"
    SECRET_KEY: str = "felicita-secret-key-2026-cambia-esto-en-produccion"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480
    APP_NAME: str = "Felicita"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True
    TWILIO_ACCOUNT_SID: Optional[str] = None
    TWILIO_AUTH_TOKEN: Optional[str] = None
    TWILIO_WHATSAPP_FROM: Optional[str] = None

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
"@ | Set-Content "$ROOT/backend/app/config.py"

# ============================================================
# database.py
# ============================================================
@"
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from app.config import settings

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
"@ | Set-Content "$ROOT/backend/app/database.py"

# ============================================================
# models/enums.py
# ============================================================
@"
import enum


class RolEnum(str, enum.Enum):
    ADMIN = "ADMIN"
    CONTADOR = "CONTADOR"
    ASISTENTE = "ASISTENTE"


class PlanEnum(str, enum.Enum):
    FREE = "FREE"
    STARTER = "STARTER"
    PROFESIONAL = "PROFESIONAL"
    ESTUDIO = "ESTUDIO"


class RegimenTributarioEnum(str, enum.Enum):
    RG = "RG"
    RMT = "RMT"
    RER = "RER"
    NRUS = "NRUS"


class EstadoSunatEnum(str, enum.Enum):
    ACTIVO = "ACTIVO"
    BAJA = "BAJA"
    SUSPENDIDO = "SUSPENDIDO"
    OBSERVADO = "OBSERVADO"


class CondicionDomicilioEnum(str, enum.Enum):
    HABIDO = "HABIDO"
    NO_HABIDO = "NO_HABIDO"
    NO_HALLADO = "NO_HALLADO"


class NivelAlertaEnum(str, enum.Enum):
    VERDE = "VERDE"
    AMARILLO = "AMARILLO"
    ROJO = "ROJO"


class EstadoPDTEnum(str, enum.Enum):
    DRAFT = "DRAFT"
    GENERATED = "GENERATED"
    SUBMITTED = "SUBMITTED"
    ACCEPTED = "ACCEPTED"
    REJECTED = "REJECTED"


class TipoEventoEnum(str, enum.Enum):
    PDT_621 = "PDT_621"
    PLAME = "PLAME"
    PDT_625 = "PDT_625"
    AFP = "AFP"
    ESSALUD = "ESSALUD"
    IMPUESTO_VEHICULAR = "IMPUESTO_VEHICULAR"
    PREDIAL = "PREDIAL"
    OTROS = "OTROS"


class EstadoEventoEnum(str, enum.Enum):
    PENDIENTE = "PENDIENTE"
    EN_PROCESO = "EN_PROCESO"
    COMPLETADO = "COMPLETADO"
    VENCIDO = "VENCIDO"


class FrecuenciaEnum(str, enum.Enum):
    MENSUAL = "MENSUAL"
    ANUAL = "ANUAL"
    UNICO = "UNICO"


class EstadoSuscripcionEnum(str, enum.Enum):
    ACTIVA = "ACTIVA"
    VENCIDA = "VENCIDA"
    CANCELADA = "CANCELADA"
    SUSPENDIDA = "SUSPENDIDA"


class MetodoPagoEnum(str, enum.Enum):
    TARJETA = "TARJETA"
    TRANSFERENCIA = "TRANSFERENCIA"
    PAYPAL = "PAYPAL"
    YAPE = "YAPE"
    PLIN = "PLIN"


class EstadoNotifEnum(str, enum.Enum):
    PENDING = "PENDING"
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    FAILED = "FAILED"


class NivelLogEnum(str, enum.Enum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"
"@ | Set-Content "$ROOT/backend/app/models/enums.py"

# ============================================================
# models/models.py
# ============================================================
@"
from sqlalchemy import (
    Column, Integer, String, Boolean, Numeric, Date, DateTime,
    Text, ForeignKey, UniqueConstraint, CheckConstraint, Index
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base


class EstudioContable(Base):
    __tablename__ = "estudios_contables"
    id = Column(Integer, primary_key=True, index=True)
    razon_social = Column(String(255), nullable=False)
    ruc = Column(String(11), unique=True)
    direccion = Column(String(255))
    telefono = Column(String(15))
    email_principal = Column(String(120))
    plan_actual = Column(String(20), default="ESTUDIO")
    cantidad_max_contadores = Column(Integer, default=5)
    cantidad_max_empresas = Column(Integer, default=100)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    usuarios = relationship("Usuario", back_populates="estudio")


class Usuario(Base):
    __tablename__ = "usuarios"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(120), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    nombre = Column(String(100), nullable=False)
    apellido = Column(String(100), nullable=False)
    telefono = Column(String(15))
    rol = Column(String(20), nullable=False, index=True)
    cep_numero = Column(String(20))
    especialidad = Column(String(100))
    plan_actual = Column(String(20), default="FREE")
    fecha_inicio_plan = Column(Date)
    fecha_fin_plan = Column(Date)
    activo = Column(Boolean, default=True)
    estudio_id = Column(Integer, ForeignKey("estudios_contables.id"), nullable=True)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_ultimo_login = Column(DateTime(timezone=True))
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    estudio = relationship("EstudioContable", back_populates="usuarios")
    empresas = relationship("Empresa", back_populates="contador", cascade="all, delete-orphan")
    config_notificaciones = relationship("ConfiguracionNotificaciones", back_populates="contador", uselist=False)
    suscripciones = relationship("Suscripcion", back_populates="contador")
    eventos_calendario = relationship("CalendarioTributario", back_populates="contador")
    notificaciones = relationship("NotificacionWhatsapp", back_populates="contador")
    logs = relationship("LogEvento", back_populates="usuario")
    __table_args__ = (
        Index("idx_usuarios_email", "email"),
        Index("idx_usuarios_rol", "rol"),
        Index("idx_usuarios_estudio", "estudio_id"),
    )


class Empresa(Base):
    __tablename__ = "empresas"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="RESTRICT"), nullable=False)
    ruc = Column(String(11), nullable=False)
    razon_social = Column(String(255), nullable=False)
    nombre_comercial = Column(String(255))
    direccion_fiscal = Column(String(255), nullable=False)
    distrito = Column(String(100))
    provincia = Column(String(100))
    departamento = Column(String(100))
    regimen_tributario = Column(String(20), default="RG")
    tasa_renta_pc = Column(Numeric(5, 2), default=1.50)
    fecha_inicio_actividades = Column(Date)
    estado_sunat = Column(String(20), default="ACTIVO")
    condicion_domicilio = Column(String(20), default="HABIDO")
    representante_legal = Column(String(255))
    email_empresa = Column(String(120))
    telefono_empresa = Column(String(15))
    usuario_sol = Column(String(50))
    clave_sol_encrypted = Column(Text)
    activa = Column(Boolean, default=True)
    color_identificacion = Column(String(7), default="#3B82F6")
    notas_contador = Column(Text)
    nivel_alerta = Column(String(10), default="VERDE")
    motivo_alerta = Column(Text)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    contador = relationship("Usuario", back_populates="empresas")
    pdt621s = relationship("PDT621", back_populates="empresa", cascade="all, delete-orphan")
    eventos_calendario = relationship("CalendarioTributario", back_populates="empresa", cascade="all, delete-orphan")
    notificaciones = relationship("NotificacionWhatsapp", back_populates="empresa")
    logs = relationship("LogEvento", back_populates="empresa")
    __table_args__ = (
        UniqueConstraint("ruc", "contador_id", name="uq_empresa_ruc_contador"),
        Index("idx_empresas_contador", "contador_id"),
        Index("idx_empresas_ruc", "ruc"),
        Index("idx_empresas_alerta", "nivel_alerta"),
        Index("idx_empresas_activa", "activa"),
    )


class PDT621(Base):
    __tablename__ = "pdt621s"
    id = Column(Integer, primary_key=True, index=True)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="CASCADE"), nullable=False)
    mes = Column(Integer, nullable=False)
    ano = Column(Integer, nullable=False)
    fecha_vencimiento = Column(Date, nullable=False)
    estado = Column(String(20), default="DRAFT")
    c100_ventas_gravadas = Column(Numeric(15, 2), default=0)
    c102_descuentos = Column(Numeric(15, 2), default=0)
    c104_ventas_no_gravadas = Column(Numeric(15, 2), default=0)
    c105_exportaciones = Column(Numeric(15, 2), default=0)
    c140_subtotal_ventas = Column(Numeric(15, 2), default=0)
    c140igv_igv_debito = Column(Numeric(15, 2), default=0)
    c120_compras_gravadas = Column(Numeric(15, 2), default=0)
    c180_igv_credito = Column(Numeric(15, 2), default=0)
    c184_igv_a_pagar = Column(Numeric(15, 2), default=0)
    c301_ingresos_netos = Column(Numeric(15, 2), default=0)
    c309_pago_a_cuenta_renta = Column(Numeric(15, 2), default=0)
    c310_retenciones = Column(Numeric(15, 2), default=0)
    c311_pagos_anticipados = Column(Numeric(15, 2), default=0)
    c318_renta_a_pagar = Column(Numeric(15, 2), default=0)
    total_a_pagar = Column(Numeric(15, 2), default=0)
    nps = Column(String(20))
    numero_operacion = Column(String(20))
    codigo_rechazo_sunat = Column(String(10))
    mensaje_error_sunat = Column(Text)
    observaciones = Column(Text)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    fecha_presentacion_sunat = Column(DateTime(timezone=True))
    empresa = relationship("Empresa", back_populates="pdt621s")
    detalles = relationship("PDT621Detalle", back_populates="pdt621", cascade="all, delete-orphan")
    eventos_calendario = relationship("CalendarioTributario", back_populates="pdt621")
    __table_args__ = (
        UniqueConstraint("empresa_id", "mes", "ano", name="uq_pdt621_empresa_periodo"),
        CheckConstraint("mes >= 1 AND mes <= 12", name="chk_pdt621_mes"),
        CheckConstraint("ano >= 2020", name="chk_pdt621_ano"),
        Index("idx_pdt621_empresa", "empresa_id"),
        Index("idx_pdt621_periodo", "ano", "mes"),
        Index("idx_pdt621_estado", "estado"),
        Index("idx_pdt621_vencimiento", "fecha_vencimiento"),
    )


class PDT621Detalle(Base):
    __tablename__ = "pdt621_detalles"
    id = Column(Integer, primary_key=True, index=True)
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="CASCADE"), nullable=False)
    tipo_comprobante = Column(String(10), nullable=False)
    numero_comprobante = Column(String(20), nullable=False)
    ruc_cliente = Column(String(11))
    cliente = Column(String(255), nullable=False)
    fecha_emision = Column(Date, nullable=False)
    monto_base = Column(Numeric(15, 2), nullable=False)
    monto_igv = Column(Numeric(15, 2), nullable=False)
    monto_total = Column(Numeric(15, 2), nullable=False)
    tipo_operacion = Column(String(20), nullable=False)
    fecha_registro = Column(DateTime(timezone=True), server_default=func.now())
    pdt621 = relationship("PDT621", back_populates="detalles")


class CalendarioTributario(Base):
    __tablename__ = "calendario_tributario"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="CASCADE"), nullable=False)
    tipo_evento = Column(String(30), nullable=False)
    titulo = Column(String(255), nullable=False)
    descripcion = Column(Text)
    fecha_evento = Column(Date, nullable=False)
    fecha_vencimiento = Column(Date, nullable=False)
    estado = Column(String(20), default="PENDIENTE")
    dias_aviso_previo = Column(Integer, default=5)
    aviso_enviado = Column(Boolean, default=False)
    color = Column(String(7), default="#3B82F6")
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="SET NULL"), nullable=True)
    es_recurrente = Column(Boolean, default=True)
    frecuencia = Column(String(20))
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    contador = relationship("Usuario", back_populates="eventos_calendario")
    empresa = relationship("Empresa", back_populates="eventos_calendario")
    pdt621 = relationship("PDT621", back_populates="eventos_calendario")
    __table_args__ = (
        Index("idx_cal_contador", "contador_id"),
        Index("idx_cal_empresa", "empresa_id"),
        Index("idx_cal_fecha", "fecha_vencimiento"),
        Index("idx_cal_estado", "estado"),
    )


class CronogramaSunat(Base):
    __tablename__ = "cronograma_sunat"
    id = Column(Integer, primary_key=True, index=True)
    ano = Column(Integer, nullable=False)
    mes = Column(Integer, nullable=False)
    ultimo_digito_ruc = Column(String(2), nullable=False)
    fecha_pdt621 = Column(Date)
    fecha_plame = Column(Date)
    fecha_otros = Column(Date)
    __table_args__ = (
        UniqueConstraint("ano", "mes", "ultimo_digito_ruc", name="uq_cronograma_periodo_digito"),
        Index("idx_cronograma_periodo", "ano", "mes"),
        Index("idx_cronograma_digito", "ultimo_digito_ruc"),
        CheckConstraint("mes >= 1 AND mes <= 12", name="chk_cronograma_mes"),
    )


class PlanSuscripcion(Base):
    __tablename__ = "planes_suscripcion"
    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String(50), unique=True, nullable=False)
    descripcion = Column(Text)
    precio_mensual = Column(Numeric(10, 2))
    precio_anual = Column(Numeric(10, 2))
    max_empresas = Column(Integer, nullable=False)
    max_pdt621_mes = Column(Integer)
    max_contadores = Column(Integer, default=1)
    max_notificaciones_mes = Column(Integer)
    permite_ia_avanzada = Column(Boolean, default=False)
    permite_api_access = Column(Boolean, default=False)
    permite_reportes_consolidados = Column(Boolean, default=False)
    permite_multi_usuario = Column(Boolean, default=False)
    nivel_soporte = Column(String(20))
    activo = Column(Boolean, default=True)
    orden_visualizacion = Column(Integer)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    suscripciones = relationship("Suscripcion", back_populates="plan")


class Suscripcion(Base):
    __tablename__ = "suscripciones"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    plan_id = Column(Integer, ForeignKey("planes_suscripcion.id"), nullable=False)
    fecha_inicio = Column(Date, nullable=False)
    fecha_fin = Column(Date, nullable=False)
    estado = Column(String(20), default="ACTIVA")
    monto_pagado = Column(Numeric(10, 2), nullable=False)
    metodo_pago = Column(String(30))
    referencia_pago = Column(String(100))
    renovacion_automatica = Column(Boolean, default=True)
    fecha_proxima_facturacion = Column(Date)
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    contador = relationship("Usuario", back_populates="suscripciones")
    plan = relationship("PlanSuscripcion", back_populates="suscripciones")
    __table_args__ = (
        Index("idx_suscripciones_contador", "contador_id"),
        Index("idx_suscripciones_estado", "estado"),
    )


class ConfiguracionNotificaciones(Base):
    __tablename__ = "configuracion_notificaciones"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False, unique=True)
    numero_whatsapp = Column(String(20))
    numero_alternativo = Column(String(20))
    notif_cpe_aceptado = Column(Boolean, default=True)
    notif_cpe_rechazado = Column(Boolean, default=True)
    notif_pdt621_generado = Column(Boolean, default=True)
    notif_pdt621_presentado = Column(Boolean, default=True)
    notif_alertas_compliance = Column(Boolean, default=True)
    notif_recordatorio_pago = Column(Boolean, default=True)
    notif_resumen_diario = Column(Boolean, default=False)
    notif_calendario_diario = Column(Boolean, default=True)
    notif_errores = Column(Boolean, default=True)
    hora_inicio = Column(Integer, default=8)
    hora_fin = Column(Integer, default=18)
    consolidar_notificaciones = Column(Boolean, default=False)
    validado = Column(Boolean, default=False)
    codigo_verificacion = Column(String(6))
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_actualizacion = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    contador = relationship("Usuario", back_populates="config_notificaciones")
    __table_args__ = (Index("idx_config_notif_contador", "contador_id"),)


class NotificacionWhatsapp(Base):
    __tablename__ = "notificaciones_whatsapp"
    id = Column(Integer, primary_key=True, index=True)
    contador_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="SET NULL"), nullable=True)
    pdt621_id = Column(Integer, ForeignKey("pdt621s.id", ondelete="SET NULL"), nullable=True)
    tipo_notificacion = Column(String(50), nullable=False)
    asunto = Column(String(255), nullable=False)
    mensaje = Column(Text, nullable=False)
    numero_destino = Column(String(20), nullable=False)
    estado = Column(String(20), default="PENDING")
    mensaje_id_twilio = Column(String(50))
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    fecha_envio = Column(DateTime(timezone=True))
    fecha_entrega = Column(DateTime(timezone=True))
    codigo_error = Column(String(10))
    descripcion_error = Column(Text)
    reintentos = Column(Integer, default=0)
    max_reintentos = Column(Integer, default=3)
    contador = relationship("Usuario", back_populates="notificaciones")
    empresa = relationship("Empresa", back_populates="notificaciones")
    __table_args__ = (
        Index("idx_notif_contador", "contador_id"),
        Index("idx_notif_empresa", "empresa_id"),
        Index("idx_notif_estado", "estado"),
    )


class LogEvento(Base):
    __tablename__ = "log_eventos"
    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="SET NULL"), nullable=True)
    empresa_id = Column(Integer, ForeignKey("empresas.id", ondelete="SET NULL"), nullable=True)
    tipo_evento = Column(String(50), nullable=False)
    descripcion = Column(Text, nullable=False)
    datos_json = Column(Text)
    nivel = Column(String(10), default="INFO")
    ip_address = Column(String(45))
    user_agent = Column(Text)
    fecha_evento = Column(DateTime(timezone=True), server_default=func.now())
    usuario = relationship("Usuario", back_populates="logs")
    empresa = relationship("Empresa", back_populates="logs")
    __table_args__ = (
        Index("idx_log_usuario", "usuario_id"),
        Index("idx_log_empresa", "empresa_id"),
        Index("idx_log_tipo", "tipo_evento"),
    )
"@ | Set-Content "$ROOT/backend/app/models/models.py"

# ============================================================
# utils/security.py
# ============================================================
@"
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        return None
"@ | Set-Content "$ROOT/backend/app/utils/security.py"

# ============================================================
# dependencies/auth_dependency.py
# ============================================================
@"
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.database import get_db
from app.models.models import Usuario
from app.utils.security import decode_access_token

bearer_scheme = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> Usuario:
    token = credentials.credentials
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token invalido o expirado")
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token invalido")
    user = db.query(Usuario).filter(Usuario.id == int(user_id), Usuario.activo == True).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Usuario no encontrado o inactivo")
    return user


def require_admin(current_user: Usuario = Depends(get_current_user)) -> Usuario:
    if current_user.rol != "ADMIN":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Se requiere rol ADMIN")
    return current_user


def require_contador(current_user: Usuario = Depends(get_current_user)) -> Usuario:
    if current_user.rol not in ("CONTADOR", "ADMIN"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Acceso no autorizado")
    return current_user
"@ | Set-Content "$ROOT/backend/app/dependencies/auth_dependency.py"

# ============================================================
# schemas/auth_schema.py
# ============================================================
@"
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from datetime import datetime


class RegistroRequest(BaseModel):
    email: EmailStr
    password: str
    nombre: str
    apellido: str
    telefono: Optional[str] = None
    cep_numero: Optional[str] = None

    @field_validator("password")
    @classmethod
    def password_minimo(cls, v):
        if len(v) < 6:
            raise ValueError("La contrasena debe tener al menos 6 caracteres")
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UsuarioResponse(BaseModel):
    id: int
    email: str
    nombre: str
    apellido: str
    rol: str
    plan_actual: str
    activo: bool
    fecha_creacion: datetime
    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioResponse


class CambiarPasswordRequest(BaseModel):
    password_actual: str
    password_nuevo: str
"@ | Set-Content "$ROOT/backend/app/schemas/auth_schema.py"

# ============================================================
# schemas/empresa_schema.py
# ============================================================
@"
from pydantic import BaseModel
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
    representante_legal: Optional[str] = None
    email_empresa: Optional[str] = None
    telefono_empresa: Optional[str] = None
    color_identificacion: Optional[str] = "#3B82F6"
    notas_contador: Optional[str] = None


class EmpresaUpdate(BaseModel):
    razon_social: Optional[str] = None
    nombre_comercial: Optional[str] = None
    direccion_fiscal: Optional[str] = None
    distrito: Optional[str] = None
    provincia: Optional[str] = None
    departamento: Optional[str] = None
    regimen_tributario: Optional[str] = None
    representante_legal: Optional[str] = None
    email_empresa: Optional[str] = None
    telefono_empresa: Optional[str] = None
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
    nivel_alerta: str
    motivo_alerta: Optional[str]
    color_identificacion: str
    activa: bool
    fecha_creacion: datetime
    model_config = {"from_attributes": True}
"@ | Set-Content "$ROOT/backend/app/schemas/empresa_schema.py"

# ============================================================
# routers/auth.py
# ============================================================
@"
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from app.database import get_db
from app.models.models import Usuario, ConfiguracionNotificaciones
from app.schemas.auth_schema import (
    RegistroRequest, LoginRequest, TokenResponse, UsuarioResponse, CambiarPasswordRequest
)
from app.utils.security import hash_password, verify_password, create_access_token
from app.dependencies.auth_dependency import get_current_user

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])


@router.post("/registro", response_model=TokenResponse, status_code=201)
def registro(payload: RegistroRequest, db: Session = Depends(get_db)):
    if db.query(Usuario).filter(Usuario.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Ya existe una cuenta con ese email")
    usuario = Usuario(
        email=payload.email,
        password_hash=hash_password(payload.password),
        nombre=payload.nombre,
        apellido=payload.apellido,
        telefono=payload.telefono,
        cep_numero=payload.cep_numero,
        rol="CONTADOR",
        plan_actual="FREE",
        activo=True,
    )
    db.add(usuario)
    db.flush()
    db.add(ConfiguracionNotificaciones(contador_id=usuario.id))
    db.commit()
    db.refresh(usuario)
    token = create_access_token({"sub": str(usuario.id), "rol": usuario.rol})
    return TokenResponse(access_token=token, usuario=UsuarioResponse.model_validate(usuario))


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    usuario = db.query(Usuario).filter(Usuario.email == payload.email).first()
    if not usuario or not verify_password(payload.password, usuario.password_hash):
        raise HTTPException(status_code=401, detail="Email o contrasena incorrectos")
    if not usuario.activo:
        raise HTTPException(status_code=403, detail="Cuenta suspendida")
    usuario.fecha_ultimo_login = datetime.utcnow()
    db.commit()
    db.refresh(usuario)
    token = create_access_token({"sub": str(usuario.id), "rol": usuario.rol})
    return TokenResponse(access_token=token, usuario=UsuarioResponse.model_validate(usuario))


@router.get("/me", response_model=UsuarioResponse)
def me(current_user: Usuario = Depends(get_current_user)):
    return UsuarioResponse.model_validate(current_user)


@router.post("/cambiar-password")
def cambiar_password(
    payload: CambiarPasswordRequest,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(get_current_user),
):
    if not verify_password(payload.password_actual, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Contrasena actual incorrecta")
    current_user.password_hash = hash_password(payload.password_nuevo)
    db.commit()
    return {"message": "Contrasena actualizada correctamente"}
"@ | Set-Content "$ROOT/backend/app/routers/auth.py"

# ============================================================
# routers/empresas.py
# ============================================================
@"
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.models import Usuario, Empresa
from app.schemas.empresa_schema import EmpresaCreate, EmpresaUpdate, EmpresaResponse
from app.dependencies.auth_dependency import require_contador

router = APIRouter(prefix="/api/v1/empresas", tags=["Empresas"])


def get_empresa_or_404(empresa_id: int, contador: Usuario, db: Session) -> Empresa:
    empresa = db.query(Empresa).filter(
        Empresa.id == empresa_id,
        Empresa.contador_id == contador.id
    ).first()
    if not empresa:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")
    return empresa


@router.get("", response_model=List[EmpresaResponse])
def listar_empresas(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresas = db.query(Empresa).filter(
        Empresa.contador_id == current_user.id,
        Empresa.activa == True
    ).order_by(Empresa.nivel_alerta, Empresa.razon_social).all()
    return empresas


@router.post("", response_model=EmpresaResponse, status_code=201)
def crear_empresa(
    payload: EmpresaCreate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    if db.query(Empresa).filter_by(ruc=payload.ruc, contador_id=current_user.id).first():
        raise HTTPException(status_code=400, detail="Ya tienes esta empresa registrada")
    empresa = Empresa(contador_id=current_user.id, **payload.model_dump())
    db.add(empresa)
    db.commit()
    db.refresh(empresa)
    return empresa


@router.get("/{empresa_id}", response_model=EmpresaResponse)
def obtener_empresa(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    return get_empresa_or_404(empresa_id, current_user, db)


@router.put("/{empresa_id}", response_model=EmpresaResponse)
def actualizar_empresa(
    empresa_id: int,
    payload: EmpresaUpdate,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(empresa, field, value)
    db.commit()
    db.refresh(empresa)
    return empresa


@router.delete("/{empresa_id}", status_code=204)
def eliminar_empresa(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    empresa.activa = False
    db.commit()
"@ | Set-Content "$ROOT/backend/app/routers/empresas.py"

# ============================================================
# main.py
# ============================================================
@"
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import Base, engine
from app.models import models  # noqa - registrar tablas
from app.routers import auth, empresas

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Plataforma SaaS para contadores - Gestion multi-empresa",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(empresas.router)


@app.get("/")
def root():
    return {"app": settings.APP_NAME, "version": settings.APP_VERSION, "status": "OK", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "healthy"}
"@ | Set-Content "$ROOT/backend/app/main.py"

# ============================================================
# seed.py
# ============================================================
@"
import sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app.database import SessionLocal
from app.models.models import Usuario, Empresa, PlanSuscripcion, CronogramaSunat, ConfiguracionNotificaciones
from app.utils.security import hash_password
from datetime import date


def seed():
    db = SessionLocal()
    print("Iniciando seed...")

    planes = [
        PlanSuscripcion(nombre="FREE", precio_mensual=0, precio_anual=0, max_empresas=2, max_pdt621_mes=5, nivel_soporte="EMAIL", activo=True, orden_visualizacion=1),
        PlanSuscripcion(nombre="STARTER", precio_mensual=99, precio_anual=990, max_empresas=10, nivel_soporte="EMAIL", activo=True, orden_visualizacion=2),
        PlanSuscripcion(nombre="PROFESIONAL", precio_mensual=249, precio_anual=2490, max_empresas=30, permite_ia_avanzada=True, permite_reportes_consolidados=True, nivel_soporte="CHAT", activo=True, orden_visualizacion=3),
        PlanSuscripcion(nombre="ESTUDIO", precio_mensual=499, precio_anual=4990, max_empresas=100, max_contadores=5, permite_ia_avanzada=True, permite_reportes_consolidados=True, permite_api_access=True, permite_multi_usuario=True, nivel_soporte="24_7", activo=True, orden_visualizacion=4),
    ]
    for p in planes:
        if not db.query(PlanSuscripcion).filter_by(nombre=p.nombre).first():
            db.add(p)
    db.flush()
    print("  [OK] Planes creados")

    if not db.query(Usuario).filter_by(email="admin@felicita.pe").first():
        db.add(Usuario(email="admin@felicita.pe", password_hash=hash_password("admin123"), nombre="Admin", apellido="Felicita", rol="ADMIN", plan_actual="ESTUDIO", activo=True))
    print("  [OK] admin@felicita.pe / admin123")

    contador = db.query(Usuario).filter_by(email="ana.perez@felicita.pe").first()
    if not contador:
        contador = Usuario(email="ana.perez@felicita.pe", password_hash=hash_password("contador123"), nombre="Ana", apellido="Perez", telefono="999888777", rol="CONTADOR", plan_actual="PROFESIONAL", activo=True)
        db.add(contador)
        db.flush()
        db.add(ConfiguracionNotificaciones(contador_id=contador.id, numero_whatsapp="+51999888777"))
    print("  [OK] ana.perez@felicita.pe / contador123")
    db.flush()

    empresas_data = [
        {"ruc": "20123456789", "razon_social": "EMPRESA ALFA SAC", "direccion_fiscal": "Av. Javier Prado 1234, San Isidro", "distrito": "San Isidro", "provincia": "Lima", "departamento": "Lima", "regimen_tributario": "RG", "nivel_alerta": "VERDE", "color_identificacion": "#10B981"},
        {"ruc": "10987654321", "razon_social": "EMPRESA BETA EIRL", "direccion_fiscal": "Jr. Cusco 456, Miraflores", "distrito": "Miraflores", "provincia": "Lima", "departamento": "Lima", "regimen_tributario": "RMT", "nivel_alerta": "AMARILLO", "motivo_alerta": "Declaracion pendiente", "color_identificacion": "#F59E0B"},
        {"ruc": "20345678901", "razon_social": "EMPRESA GAMMA SA", "direccion_fiscal": "Av. Arequipa 789, Lince", "distrito": "Lince", "provincia": "Lima", "departamento": "Lima", "regimen_tributario": "RG", "nivel_alerta": "ROJO", "estado_sunat": "OBSERVADO", "motivo_alerta": "RUC observado por SUNAT", "color_identificacion": "#EF4444"},
        {"ruc": "20456789012", "razon_social": "EMPRESA DELTA SRL", "direccion_fiscal": "Calle Los Pinos 321, Surco", "distrito": "Santiago de Surco", "provincia": "Lima", "departamento": "Lima", "regimen_tributario": "RER", "nivel_alerta": "VERDE", "color_identificacion": "#3B82F6"},
    ]
    for data in empresas_data:
        if not db.query(Empresa).filter_by(ruc=data["ruc"], contador_id=contador.id).first():
            db.add(Empresa(contador_id=contador.id, **data))
    print("  [OK] 4 empresas de prueba")

    cronograma = [
        (4,"0",date(2025,5,14)),(4,"1",date(2025,5,15)),(4,"2",date(2025,5,16)),(4,"3",date(2025,5,19)),
        (4,"4",date(2025,5,20)),(4,"5",date(2025,5,21)),(4,"6",date(2025,5,22)),(4,"7",date(2025,5,23)),
        (4,"8",date(2025,5,26)),(4,"9",date(2025,5,27)),(4,"UESP",date(2025,5,28)),
        (5,"0",date(2025,6,13)),(5,"1",date(2025,6,16)),(5,"2",date(2025,6,17)),(5,"3",date(2025,6,18)),
        (5,"4",date(2025,6,19)),(5,"5",date(2025,6,20)),(5,"6",date(2025,6,23)),(5,"7",date(2025,6,24)),
        (5,"8",date(2025,6,25)),(5,"9",date(2025,6,26)),(5,"UESP",date(2025,6,27)),
    ]
    for mes, digito, fecha in cronograma:
        if not db.query(CronogramaSunat).filter_by(ano=2025, mes=mes, ultimo_digito_ruc=digito).first():
            db.add(CronogramaSunat(ano=2025, mes=mes, ultimo_digito_ruc=digito, fecha_pdt621=fecha))
    print("  [OK] Cronograma SUNAT 2025")

    db.commit()
    print("")
    print("Seed completado!")
    print("  Admin:    admin@felicita.pe     / admin123")
    print("  Contador: ana.perez@felicita.pe / contador123")
    db.close()


if __name__ == "__main__":
    seed()
"@ | Set-Content "$ROOT/backend/seed.py"

Write-Host "  [OK] Backend generado" -ForegroundColor Green

# ============================================================
# FRONTEND - package.json
# ============================================================
@"
{
  "name": "felicita-frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.26.2",
    "axios": "^1.7.7",
    "@tanstack/react-query": "^5.56.2",
    "zustand": "^5.0.0",
    "lucide-react": "^0.453.0",
    "date-fns": "^4.1.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.10",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.2",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.13",
    "typescript": "^5.5.3",
    "vite": "^5.4.8"
  }
}
"@ | Set-Content "$ROOT/frontend/package.json"

# ============================================================
# FRONTEND - vite.config.ts
# ============================================================
@"
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      }
    }
  }
})
"@ | Set-Content "$ROOT/frontend/vite.config.ts"

# ============================================================
# FRONTEND - tailwind.config.js
# ============================================================
@"
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0fdf4',
          100: '#dcfce7',
          500: '#22c55e',
          600: '#16a34a',
          700: '#15803d',
          900: '#14532d',
        }
      }
    }
  },
  plugins: []
}
"@ | Set-Content "$ROOT/frontend/tailwind.config.js"

# ============================================================
# FRONTEND - postcss.config.js
# ============================================================
@"
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
"@ | Set-Content "$ROOT/frontend/postcss.config.js"

# ============================================================
# FRONTEND - index.html
# ============================================================
@"
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Felicita - Plataforma Contable</title>
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
"@ | Set-Content "$ROOT/frontend/index.html"

# ============================================================
# FRONTEND - src/main.tsx
# ============================================================
@"
import React from 'react'
import ReactDOM from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import App from './App'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: 1, staleTime: 30_000 }
  }
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </React.StrictMode>
)
"@ | Set-Content "$ROOT/frontend/src/main.tsx"

# ============================================================
# FRONTEND - src/index.css
# ============================================================
@"
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  font-family: 'Inter', system-ui, sans-serif;
  background-color: #f9fafb;
}
"@ | Set-Content "$ROOT/frontend/src/index.css"

# ============================================================
# FRONTEND - src/services/api.ts
# ============================================================
@"
import axios from 'axios'

const api = axios.create({
  baseURL: '/api/v1',
  headers: { 'Content-Type': 'application/json' },
})

// Inyectar token en cada request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('felicita_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Redirigir a login si el token expira
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('felicita_token')
      localStorage.removeItem('felicita_user')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default api
"@ | Set-Content "$ROOT/frontend/src/services/api.ts"

# ============================================================
# FRONTEND - src/store/authStore.ts
# ============================================================
@"
import { create } from 'zustand'

interface Usuario {
  id: number
  email: string
  nombre: string
  apellido: string
  rol: string
  plan_actual: string
}

interface AuthState {
  token: string | null
  usuario: Usuario | null
  login: (token: string, usuario: Usuario) => void
  logout: () => void
  isAuthenticated: () => boolean
}

export const useAuthStore = create<AuthState>((set, get) => ({
  token: localStorage.getItem('felicita_token'),
  usuario: JSON.parse(localStorage.getItem('felicita_user') || 'null'),

  login: (token, usuario) => {
    localStorage.setItem('felicita_token', token)
    localStorage.setItem('felicita_user', JSON.stringify(usuario))
    set({ token, usuario })
  },

  logout: () => {
    localStorage.removeItem('felicita_token')
    localStorage.removeItem('felicita_user')
    set({ token: null, usuario: null })
  },

  isAuthenticated: () => !!get().token,
}))
"@ | Set-Content "$ROOT/frontend/src/store/authStore.ts"

# ============================================================
# FRONTEND - src/App.tsx
# ============================================================
@"
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from './store/authStore'
import LoginPage from './pages/Login'
import DashboardContador from './pages/contador/Dashboard'

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore()
  return isAuthenticated() ? <>{children}</> : <Navigate to="/login" replace />
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/dashboard" element={<PrivateRoute><DashboardContador /></PrivateRoute>} />
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
"@ | Set-Content "$ROOT/frontend/src/App.tsx"

# ============================================================
# FRONTEND - src/pages/Login.tsx
# ============================================================
@"
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../services/api'
import { useAuthStore } from '../store/authStore'

export default function LoginPage() {
  const navigate = useNavigate()
  const { login } = useAuthStore()
  const [form, setForm] = useState({ email: '', password: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      const { data } = await api.post('/auth/login', form)
      login(data.access_token, data.usuario)
      navigate('/dashboard')
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al iniciar sesion')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-green-50 to-emerald-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-8">
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-green-600 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <span className="text-white text-2xl font-bold">F</span>
          </div>
          <h1 className="text-2xl font-bold text-gray-900">Felicita</h1>
          <p className="text-gray-500 text-sm mt-1">Plataforma contable para profesionales</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input
              type="email"
              value={form.email}
              onChange={e => setForm({ ...form, email: e.target.value })}
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:outline-none focus:ring-2 focus:ring-green-500"
              placeholder="contador@email.com"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Contrasena</label>
            <input
              type="password"
              value={form.password}
              onChange={e => setForm({ ...form, password: e.target.value })}
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:outline-none focus:ring-2 focus:ring-green-500"
              placeholder="••••••••"
              required
            />
          </div>

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-4 py-3">
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-green-600 hover:bg-green-700 text-white font-semibold py-2.5 rounded-lg transition-colors disabled:opacity-50"
          >
            {loading ? 'Ingresando...' : 'Iniciar Sesion'}
          </button>
        </form>

        <p className="text-center text-xs text-gray-400 mt-6">
          Prueba: ana.perez@felicita.pe / contador123
        </p>
      </div>
    </div>
  )
}
"@ | Set-Content "$ROOT/frontend/src/pages/Login.tsx"

# ============================================================
# FRONTEND - src/pages/contador/Dashboard.tsx
# ============================================================
@"
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '../../store/authStore'
import api from '../../services/api'

interface Empresa {
  id: number
  ruc: string
  razon_social: string
  regimen_tributario: string
  nivel_alerta: string
  motivo_alerta: string | null
  color_identificacion: string
  estado_sunat: string
}

const ALERTA_CONFIG: Record<string, { emoji: string; clase: string }> = {
  VERDE:    { emoji: '🟢', clase: 'bg-green-50 border-green-200' },
  AMARILLO: { emoji: '🟡', clase: 'bg-yellow-50 border-yellow-200' },
  ROJO:     { emoji: '🔴', clase: 'bg-red-50 border-red-200' },
}

export default function DashboardContador() {
  const navigate = useNavigate()
  const { usuario, logout } = useAuthStore()
  const [empresas, setEmpresas] = useState<Empresa[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/empresas').then(r => setEmpresas(r.data)).finally(() => setLoading(false))
  }, [])

  const handleLogout = () => { logout(); navigate('/login') }

  const totales = {
    verde: empresas.filter(e => e.nivel_alerta === 'VERDE').length,
    amarillo: empresas.filter(e => e.nivel_alerta === 'AMARILLO').length,
    rojo: empresas.filter(e => e.nivel_alerta === 'ROJO').length,
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 bg-green-600 rounded-xl flex items-center justify-center">
            <span className="text-white font-bold text-sm">F</span>
          </div>
          <span className="font-bold text-gray-900 text-lg">Felicita</span>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-sm text-gray-600">{usuario?.nombre} {usuario?.apellido}</span>
          <span className="text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full font-medium">{usuario?.plan_actual}</span>
          <button onClick={handleLogout} className="text-sm text-gray-500 hover:text-red-600 transition-colors">
            Salir
          </button>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-6 py-8">
        {/* KPIs */}
        <div className="grid grid-cols-4 gap-4 mb-8">
          <div className="bg-white rounded-xl border border-gray-200 p-4">
            <p className="text-sm text-gray-500">Total empresas</p>
            <p className="text-3xl font-bold text-gray-900 mt-1">{empresas.length}</p>
          </div>
          <div className="bg-green-50 rounded-xl border border-green-200 p-4">
            <p className="text-sm text-green-700">Al dia</p>
            <p className="text-3xl font-bold text-green-700 mt-1">{totales.verde}</p>
          </div>
          <div className="bg-yellow-50 rounded-xl border border-yellow-200 p-4">
            <p className="text-sm text-yellow-700">Atencion</p>
            <p className="text-3xl font-bold text-yellow-700 mt-1">{totales.amarillo}</p>
          </div>
          <div className="bg-red-50 rounded-xl border border-red-200 p-4">
            <p className="text-sm text-red-700">Critico</p>
            <p className="text-3xl font-bold text-red-700 mt-1">{totales.rojo}</p>
          </div>
        </div>

        {/* Lista de empresas */}
        <div className="bg-white rounded-xl border border-gray-200">
          <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
            <h2 className="font-semibold text-gray-900">Mis Empresas</h2>
            <button className="bg-green-600 hover:bg-green-700 text-white text-sm px-4 py-2 rounded-lg transition-colors">
              + Nueva Empresa
            </button>
          </div>

          {loading ? (
            <div className="p-12 text-center text-gray-400">Cargando empresas...</div>
          ) : empresas.length === 0 ? (
            <div className="p-12 text-center text-gray-400">
              <p className="text-lg mb-2">No tienes empresas registradas</p>
              <p className="text-sm">Agrega tu primera empresa para comenzar</p>
            </div>
          ) : (
            <div className="divide-y divide-gray-100">
              {empresas.map(empresa => {
                const alerta = ALERTA_CONFIG[empresa.nivel_alerta] || ALERTA_CONFIG.VERDE
                return (
                  <div key={empresa.id} className={`px-6 py-4 flex items-center justify-between hover:bg-gray-50 transition-colors`}>
                    <div className="flex items-center gap-4">
                      <div className="w-3 h-3 rounded-full" style={{ backgroundColor: empresa.color_identificacion }} />
                      <div>
                        <p className="font-medium text-gray-900">{empresa.razon_social}</p>
                        <p className="text-sm text-gray-500">RUC: {empresa.ruc} · {empresa.regimen_tributario}</p>
                        {empresa.motivo_alerta && (
                          <p className="text-xs text-red-600 mt-0.5">{empresa.motivo_alerta}</p>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className="text-lg">{alerta.emoji}</span>
                      <button className="text-sm text-green-600 hover:text-green-700 font-medium">
                        Entrar →
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </main>
    </div>
  )
}
"@ | Set-Content "$ROOT/frontend/src/pages/contador/Dashboard.tsx"

Write-Host "  [OK] Frontend generado" -ForegroundColor Green

# ============================================================
# tsconfig.json
# ============================================================
@"
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
"@ | Set-Content "$ROOT/frontend/tsconfig.json"

@"
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
"@ | Set-Content "$ROOT/frontend/tsconfig.node.json"

# ============================================================
# .gitignore raiz
# ============================================================
@"
# Python
__pycache__/
*.py[cod]
venv/
.env

# Node
node_modules/
dist/
.env.local

# IDEs
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
"@ | Set-Content "$ROOT/.gitignore"

# ============================================================
# README.md
# ============================================================
@"
# Felicita - Plataforma Contable SaaS

Plataforma multi-tenant para contadores que gestionan multiples empresas.

## Inicio rapido

### 1. Base de datos (PostgreSQL)
```sql
CREATE DATABASE felicita_db;
CREATE USER felicita_user WITH PASSWORD 'felicita2026';
GRANT ALL PRIVILEGES ON DATABASE felicita_db TO felicita_user;
```

### 2. Backend
```powershell
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### 3. Datos de prueba
```powershell
python seed.py
```

### 4. Frontend (nueva terminal)
```powershell
cd frontend
npm install
npm run dev
```

## Acceso
- Backend API: http://localhost:8000/docs
- Frontend: http://localhost:5173
- Admin: admin@felicita.pe / admin123
- Contador: ana.perez@felicita.pe / contador123
"@ | Set-Content "$ROOT/README.md"

# ============================================================
# RESUMEN FINAL
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Proyecto creado exitosamente!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Estructura:" -ForegroundColor Yellow
Write-Host "  felicita/"
Write-Host "  ├── backend/   (FastAPI + SQLAlchemy)"
Write-Host "  ├── frontend/  (React + Vite + Tailwind)"
Write-Host "  └── README.md"
Write-Host ""
Write-Host "Siguiente paso - BACKEND:" -ForegroundColor Yellow
Write-Host "  cd felicita\backend"
Write-Host "  python -m venv venv"
Write-Host "  venv\Scripts\activate"
Write-Host "  pip install -r requirements.txt"
Write-Host "  uvicorn app.main:app --reload"
Write-Host ""
Write-Host "Siguiente paso - FRONTEND (otra terminal):" -ForegroundColor Yellow
Write-Host "  cd felicita\frontend"
Write-Host "  npm install"
Write-Host "  npm run dev"
Write-Host ""
Write-Host "Cuentas de prueba:" -ForegroundColor Yellow
Write-Host "  Admin:    admin@felicita.pe     / admin123"
Write-Host "  Contador: ana.perez@felicita.pe / contador123"
Write-Host ""
