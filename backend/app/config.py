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
