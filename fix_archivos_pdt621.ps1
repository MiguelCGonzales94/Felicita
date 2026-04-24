# ============================================================
#  FELICITA - Generar archivos faltantes del PDT 621
#  .\fix_archivos_pdt621.ps1
# ============================================================

Write-Host ""
Write-Host "Generando archivos faltantes del PDT 621..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# Asegurar que existe carpeta services
New-Item -ItemType Directory -Force -Path "backend/app/services" | Out-Null
if (-not (Test-Path "backend/app/services/__init__.py")) {
    "" | Set-Content "backend/app/services/__init__.py"
}

# ============================================================
# 1. services/pdt621_calculo_service.py - MOTOR DE CALCULOS
# ============================================================
@'
"""
Motor de calculos del PDT 621.
Soporta los 4 regimenes: RG, RMT, RER, NRUS.
"""
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel


# Constantes tributarias
TASA_IGV = Decimal("0.18")
TASA_RG = Decimal("0.015")
TASA_RMT_BAJA = Decimal("0.01")
TASA_RMT_ALTA = Decimal("0.015")
TASA_RER = Decimal("0.015")
UIT_2025 = Decimal("5350")
UIT_2026 = Decimal("5350")

CATEGORIAS_NRUS = {
    1: Decimal("20"),
    2: Decimal("50"),
}


class InputsCalculoIGV(BaseModel):
    ventas_gravadas: Decimal = Decimal("0")
    ventas_no_gravadas: Decimal = Decimal("0")
    exportaciones: Decimal = Decimal("0")
    compras_gravadas: Decimal = Decimal("0")
    compras_no_gravadas: Decimal = Decimal("0")
    saldo_favor_anterior: Decimal = Decimal("0")
    percepciones_periodo: Decimal = Decimal("0")
    percepciones_arrastre: Decimal = Decimal("0")
    retenciones_periodo: Decimal = Decimal("0")
    retenciones_arrastre: Decimal = Decimal("0")


class ResultadoCalculoIGV(BaseModel):
    subtotal_ventas: Decimal
    subtotal_compras: Decimal
    igv_debito: Decimal
    igv_credito: Decimal
    igv_resultante: Decimal
    total_creditos_aplicables: Decimal
    igv_a_pagar: Decimal
    saldo_favor_siguiente: Decimal
    percepciones_aplicadas: Decimal
    retenciones_aplicadas: Decimal
    saldo_favor_aplicado: Decimal


class InputsCalculoRenta(BaseModel):
    regimen: str
    ingresos_netos: Decimal = Decimal("0")
    coeficiente_declarado: Optional[Decimal] = None
    pagos_anticipados: Decimal = Decimal("0")
    retenciones_renta: Decimal = Decimal("0")
    saldo_favor_renta_anterior: Decimal = Decimal("0")
    categoria_nrus: Optional[int] = None
    ingresos_acumulados_ano: Decimal = Decimal("0")


class ResultadoCalculoRenta(BaseModel):
    regimen: str
    tasa_aplicada: Decimal
    base_calculo: Decimal
    renta_bruta: Decimal
    creditos_aplicados: Decimal
    renta_a_pagar: Decimal
    observaciones: str = ""


class ResultadoPDT621(BaseModel):
    igv: ResultadoCalculoIGV
    renta: ResultadoCalculoRenta
    total_a_pagar: Decimal


def calcular_igv(inputs: InputsCalculoIGV) -> ResultadoCalculoIGV:
    """Motor de calculo del IGV segun Ley del IGV (Peru)."""
    subtotal_ventas = (
        inputs.ventas_gravadas + inputs.ventas_no_gravadas + inputs.exportaciones
    )
    subtotal_compras = inputs.compras_gravadas + inputs.compras_no_gravadas

    igv_debito = (inputs.ventas_gravadas * TASA_IGV).quantize(Decimal("0.01"))
    igv_credito = (inputs.compras_gravadas * TASA_IGV).quantize(Decimal("0.01"))
    igv_resultante = igv_debito - igv_credito

    percepciones_total = inputs.percepciones_periodo + inputs.percepciones_arrastre
    retenciones_total = inputs.retenciones_periodo + inputs.retenciones_arrastre
    total_creditos = inputs.saldo_favor_anterior + percepciones_total + retenciones_total

    if igv_resultante <= 0:
        igv_a_pagar = Decimal("0")
        saldo_favor_siguiente = abs(igv_resultante) + total_creditos
        saldo_aplicado = Decimal("0")
        percep_aplicada = Decimal("0")
        retenc_aplicada = Decimal("0")
    else:
        restante = igv_resultante
        saldo_aplicado = min(restante, inputs.saldo_favor_anterior)
        restante -= saldo_aplicado
        percep_aplicada = min(restante, percepciones_total)
        restante -= percep_aplicada
        retenc_aplicada = min(restante, retenciones_total)
        restante -= retenc_aplicada
        igv_a_pagar = max(Decimal("0"), restante)
        sobrante_creditos = total_creditos - (saldo_aplicado + percep_aplicada + retenc_aplicada)
        saldo_favor_siguiente = max(Decimal("0"), sobrante_creditos)

    return ResultadoCalculoIGV(
        subtotal_ventas=subtotal_ventas.quantize(Decimal("0.01")),
        subtotal_compras=subtotal_compras.quantize(Decimal("0.01")),
        igv_debito=igv_debito,
        igv_credito=igv_credito,
        igv_resultante=igv_resultante.quantize(Decimal("0.01")),
        total_creditos_aplicables=total_creditos.quantize(Decimal("0.01")),
        igv_a_pagar=igv_a_pagar.quantize(Decimal("0.01")),
        saldo_favor_siguiente=saldo_favor_siguiente.quantize(Decimal("0.01")),
        percepciones_aplicadas=percep_aplicada.quantize(Decimal("0.01")),
        retenciones_aplicadas=retenc_aplicada.quantize(Decimal("0.01")),
        saldo_favor_aplicado=saldo_aplicado.quantize(Decimal("0.01")),
    )


def calcular_renta_rg(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    tasa = inputs.coeficiente_declarado if inputs.coeficiente_declarado else TASA_RG
    base = inputs.ingresos_netos
    renta_bruta = (base * tasa).quantize(Decimal("0.01"))
    creditos = (
        inputs.pagos_anticipados
        + inputs.retenciones_renta
        + inputs.saldo_favor_renta_anterior
    )
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    obs = ""
    if inputs.coeficiente_declarado:
        obs = f"Usando coeficiente declarado de {(tasa * 100):.4f}%"
    return ResultadoCalculoRenta(
        regimen="RG",
        tasa_aplicada=tasa,
        base_calculo=base.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones=obs,
    )


def calcular_renta_rmt(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    limite = Decimal("300") * UIT_2026
    if inputs.ingresos_acumulados_ano <= limite:
        tasa = TASA_RMT_BAJA
        obs = f"Ingresos acumulados ({inputs.ingresos_acumulados_ano:,.2f}) dentro de 300 UIT -> 1%"
    else:
        tasa = TASA_RMT_ALTA
        obs = f"Ingresos acumulados ({inputs.ingresos_acumulados_ano:,.2f}) superan 300 UIT -> 1.5%"
    if inputs.coeficiente_declarado:
        tasa = inputs.coeficiente_declarado
        obs = f"Usando coeficiente declarado de {(tasa * 100):.4f}%"
    renta_bruta = (inputs.ingresos_netos * tasa).quantize(Decimal("0.01"))
    creditos = (
        inputs.pagos_anticipados
        + inputs.retenciones_renta
        + inputs.saldo_favor_renta_anterior
    )
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    return ResultadoCalculoRenta(
        regimen="RMT",
        tasa_aplicada=tasa,
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones=obs,
    )


def calcular_renta_rer(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    tasa = TASA_RER
    renta_bruta = (inputs.ingresos_netos * tasa).quantize(Decimal("0.01"))
    creditos = inputs.pagos_anticipados + inputs.retenciones_renta
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    return ResultadoCalculoRenta(
        regimen="RER",
        tasa_aplicada=tasa,
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones="Tasa unica RER 1.5% de ingresos netos mensuales",
    )


def calcular_renta_nrus(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    categoria = inputs.categoria_nrus or 1
    if categoria not in CATEGORIAS_NRUS:
        categoria = 1
    monto_fijo = CATEGORIAS_NRUS[categoria]
    return ResultadoCalculoRenta(
        regimen="NRUS",
        tasa_aplicada=Decimal("0"),
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=monto_fijo,
        creditos_aplicados=Decimal("0"),
        renta_a_pagar=monto_fijo,
        observaciones=f"NRUS Categoria {categoria}: cuota fija de S/ {monto_fijo}",
    )


def calcular_renta(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    regimen = inputs.regimen.upper()
    if regimen == "RG":
        return calcular_renta_rg(inputs)
    elif regimen == "RMT":
        return calcular_renta_rmt(inputs)
    elif regimen == "RER":
        return calcular_renta_rer(inputs)
    elif regimen == "NRUS":
        return calcular_renta_nrus(inputs)
    else:
        raise ValueError(f"Regimen desconocido: {regimen}")


def calcular_pdt621(
    igv_inputs: InputsCalculoIGV,
    renta_inputs: InputsCalculoRenta,
) -> ResultadoPDT621:
    igv = calcular_igv(igv_inputs)
    renta = calcular_renta(renta_inputs)
    total = igv.igv_a_pagar + renta.renta_a_pagar
    return ResultadoPDT621(
        igv=igv,
        renta=renta,
        total_a_pagar=total.quantize(Decimal("0.01")),
    )
'@ | Set-Content "backend/app/services/pdt621_calculo_service.py"
Write-Host "  [OK] services/pdt621_calculo_service.py" -ForegroundColor Green

# ============================================================
# 2. schemas/pdt621_schema.py (por si tambien falta)
# ============================================================
if (-not (Test-Path "backend/app/schemas/pdt621_schema.py")) {
@'
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, date
from decimal import Decimal


class PDT621Response(BaseModel):
    id: int
    empresa_id: int
    mes: int
    ano: int
    fecha_vencimiento: date
    estado: str
    c100_ventas_gravadas: Decimal
    c104_ventas_no_gravadas: Decimal
    c105_exportaciones: Decimal
    c140_subtotal_ventas: Decimal
    c140igv_igv_debito: Decimal
    c120_compras_gravadas: Decimal
    c180_igv_credito: Decimal
    c184_igv_a_pagar: Decimal
    c301_ingresos_netos: Decimal
    c309_pago_a_cuenta_renta: Decimal
    c310_retenciones: Decimal
    c311_pagos_anticipados: Decimal
    c318_renta_a_pagar: Decimal
    total_a_pagar: Decimal
    nps: Optional[str]
    numero_operacion: Optional[str]
    codigo_rechazo_sunat: Optional[str]
    mensaje_error_sunat: Optional[str]
    fecha_presentacion_sunat: Optional[datetime]
    fecha_creacion: datetime
    model_config = {"from_attributes": True}


class PDT621ListItem(BaseModel):
    id: int
    empresa_id: int
    empresa_nombre: str
    empresa_ruc: str
    empresa_color: str
    mes: int
    ano: int
    fecha_vencimiento: date
    estado: str
    total_a_pagar: Decimal
    igv_a_pagar: Decimal
    renta_a_pagar: Decimal
    nps: Optional[str]
    dias_para_vencer: int
    model_config = {"from_attributes": True}


class PDT621Generar(BaseModel):
    ano: int
    mes: int


class PDT621Ajustes(BaseModel):
    saldo_favor_anterior: Optional[Decimal] = Decimal("0")
    percepciones_periodo: Optional[Decimal] = Decimal("0")
    percepciones_arrastre: Optional[Decimal] = Decimal("0")
    retenciones_periodo: Optional[Decimal] = Decimal("0")
    retenciones_arrastre: Optional[Decimal] = Decimal("0")
    pagos_anticipados: Optional[Decimal] = Decimal("0")
    retenciones_renta: Optional[Decimal] = Decimal("0")
    saldo_favor_renta_anterior: Optional[Decimal] = Decimal("0")
    categoria_nrus: Optional[int] = None
    ingresos_acumulados_ano: Optional[Decimal] = Decimal("0")


class PDT621CambioEstado(BaseModel):
    nuevo_estado: str
    numero_operacion: Optional[str] = None
    mensaje: Optional[str] = None


class ImportacionSunatResponse(BaseModel):
    ventas: dict
    compras: dict
'@ | Set-Content "backend/app/schemas/pdt621_schema.py"
    Write-Host "  [OK] schemas/pdt621_schema.py" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] schemas/pdt621_schema.py ya existe" -ForegroundColor Gray
}

# ============================================================
# Ahora arreglar main.py
# ============================================================
@'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import Base, engine
from app.models import models  # noqa
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
Write-Host "  [OK] main.py con los 4 routers" -ForegroundColor Green

# Verificar que todos los archivos del PDT 621 esten
Write-Host ""
Write-Host "Verificando archivos del PDT 621..." -ForegroundColor Yellow
$archivosRequeridos = @(
    "backend/app/services/sire_client.py",
    "backend/app/services/sire_service.py",
    "backend/app/services/pdt621_service.py",
    "backend/app/services/pdt621_calculo_service.py",
    "backend/app/schemas/pdt621_schema.py",
    "backend/app/routers/pdt621.py"
)
$todosOk = $true
foreach ($archivo in $archivosRequeridos) {
    if (Test-Path $archivo) {
        Write-Host "  [OK] $archivo" -ForegroundColor Green
    } else {
        Write-Host "  [FALTA] $archivo" -ForegroundColor Red
        $todosOk = $false
    }
}

Write-Host ""
if ($todosOk) {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   Todo listo!" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "SIGUIENTE PASO:" -ForegroundColor Yellow
    Write-Host "  1. Asegurate de haber instalado httpx:" -ForegroundColor White
    Write-Host "     cd backend" -ForegroundColor Gray
    Write-Host "     venv\Scripts\activate" -ForegroundColor Gray
    Write-Host "     pip install httpx==0.27.2" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Detener uvicorn (Ctrl+C) y volver a correrlo:" -ForegroundColor White
    Write-Host "     uvicorn app.main:app --reload" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  3. Abrir http://localhost:8000/docs" -ForegroundColor White
    Write-Host "     Deberias ver la seccion 'PDT 621' con varios endpoints" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Faltan archivos. Necesitas ejecutar:" -ForegroundColor Red
    Write-Host "  .\cambio3a_sire_backend.ps1" -ForegroundColor Yellow
}
