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
