from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import Base, engine
from app.models import models  # noqa
from app.routers import auth, empresas, calendario, pdt621
from app.routers import configuracion_tributaria
from app.routers import notificaciones

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
app.include_router(calendario.router)
app.include_router(pdt621.router)
app.include_router(configuracion_tributaria.router)
app.include_router(notificaciones.router)


@app.get("/")
def root():
    return {"app": settings.APP_NAME, "version": settings.APP_VERSION, "status": "OK", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "healthy"}
