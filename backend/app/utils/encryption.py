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
