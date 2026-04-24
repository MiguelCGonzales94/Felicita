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
