# ============================================================
#  FELICITA - Arreglar main.py para incluir router PDT 621
#  .\fix_main.ps1
# ============================================================

Write-Host ""
Write-Host "Arreglando main.py..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# Verificar que exista el archivo del router
if (-not (Test-Path "backend/app/routers/pdt621.py")) {
    Write-Host "ERROR: No existe backend/app/routers/pdt621.py" -ForegroundColor Red
    Write-Host "Primero ejecuta cambio3a_sire_backend.ps1" -ForegroundColor Yellow
    exit 1
}

# Verificar que existan los servicios
$archivosRequeridos = @(
    "backend/app/services/sire_client.py",
    "backend/app/services/sire_service.py",
    "backend/app/services/pdt621_service.py",
    "backend/app/services/pdt621_calculo_service.py",
    "backend/app/schemas/pdt621_schema.py"
)
foreach ($archivo in $archivosRequeridos) {
    if (-not (Test-Path $archivo)) {
        Write-Host "ERROR: Falta archivo $archivo" -ForegroundColor Red
        exit 1
    }
}

Write-Host "  [OK] Todos los archivos del PDT 621 existen" -ForegroundColor Green

# Sobrescribir main.py con la version correcta
@'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import Base, engine
from app.models import models  # noqa - registrar tablas
from app.routers import auth, empresas, calendario, pdt621

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


@app.get("/")
def root():
    return {"app": settings.APP_NAME, "version": settings.APP_VERSION, "status": "OK", "docs": "/docs"}


@app.get("/health")
def health():
    return {"status": "healthy"}
'@ | Set-Content "backend/app/main.py"

Write-Host "  [OK] main.py sobrescrito con los 4 routers" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PRUEBA AHORA:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Detener uvicorn (Ctrl+C)" -ForegroundColor Yellow
Write-Host "  2. Volver a correrlo:  uvicorn app.main:app --reload" -ForegroundColor Yellow
Write-Host "  3. Si NO arranca, mira el error que salga en rojo" -ForegroundColor Yellow
Write-Host "     y pegamelo para diagnosticar" -ForegroundColor Yellow
Write-Host ""
Write-Host "  4. Si arranca bien:" -ForegroundColor Yellow
Write-Host "     - Recarga http://localhost:8000/docs" -ForegroundColor Yellow
Write-Host "     - Deberias ver nueva seccion 'PDT 621' con endpoints:" -ForegroundColor Yellow
Write-Host "         GET  /api/v1/pdt621" -ForegroundColor Gray
Write-Host "         GET  /api/v1/empresas/{id}/pdt621" -ForegroundColor Gray
Write-Host "         POST /api/v1/pdt621/{id}/importar-sunat" -ForegroundColor Gray
Write-Host "         POST /api/v1/empresas/{id}/sire/probar-conexion" -ForegroundColor Gray
Write-Host ""
