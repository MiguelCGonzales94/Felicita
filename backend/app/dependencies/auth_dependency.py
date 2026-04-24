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
