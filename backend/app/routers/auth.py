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
