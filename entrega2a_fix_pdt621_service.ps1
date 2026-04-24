# ============================================================
#  FELICITA - FIX Entrega 2A: parche pdt621_service.py
#  Corrige el -replace que fallo en PowerShell
#  Uso: .\entrega2a_fix_pdt621_service.ps1
# ============================================================

Write-Host ""
Write-Host "FIX: parchando pdt621_service.py con Python..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend/app/services/pdt621_service.py")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# Usamos Python para el parche (regex multi-linea mas confiable)
@'
import re
from pathlib import Path

path = Path("backend/app/services/pdt621_service.py")
src = path.read_text(encoding="utf-8")

# 1) Asegurar import del servicio de configuracion
if "configuracion_tributaria_service" not in src:
    src = src.replace(
        "from app.services.empresa_service import obtener_credenciales_sunat",
        "from app.services.empresa_service import obtener_credenciales_sunat\n"
        "from app.services.configuracion_tributaria_service import "
        "obtener_o_crear_configuracion, config_a_snapshot",
    )

# 2) Inyectar config_snapshot al crear el PDT dentro de obtener_o_crear_pdt
#    Se busca el bloque PDT621(...) y se agrega el snapshot antes del ')' final.
patron_crear = re.compile(
    r"(pdt = PDT621\(\s*empresa_id=empresa\.id,\s*"
    r"ano=ano, mes=mes,\s*"
    r"fecha_vencimiento=fecha_venc,\s*"
    r'estado="DRAFT",)\s*\)',
    re.MULTILINE,
)
if patron_crear.search(src) and "config_snapshot=" not in src:
    src = patron_crear.sub(
        r"\1\n        config_snapshot=config_a_snapshot("
        r"obtener_o_crear_configuracion(db, empresa.id)),\n    )",
        src,
    )
    print("  [OK] Snapshot inyectado en obtener_o_crear_pdt")
else:
    print("  [SKIP] Snapshot ya presente o patron no encontrado")

# 3) Pasar config=pdt.config_snapshot al calcular_pdt621 (todas las ocurrencias)
if "calcular_pdt621(igv_inputs, renta_inputs)" in src:
    src = src.replace(
        "calcular_pdt621(igv_inputs, renta_inputs)",
        "calcular_pdt621(igv_inputs, renta_inputs, config=pdt.config_snapshot)",
    )
    print("  [OK] calcular_pdt621 ahora recibe el snapshot")
else:
    print("  [SKIP] calcular_pdt621 ya usa config o no se encontro")

path.write_text(src, encoding="utf-8")
print("  [DONE] pdt621_service.py parchado")
'@ | Set-Content "_fix_temp.py"

python _fix_temp.py
Remove-Item "_fix_temp.py"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FIX APLICADO" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Verifica manualmente que pdt621_service.py tenga:" -ForegroundColor Yellow
Write-Host "  1. El import de configuracion_tributaria_service" -ForegroundColor Gray
Write-Host "  2. config_snapshot=config_a_snapshot(...) al crear el PDT" -ForegroundColor Gray
Write-Host "  3. calcular_pdt621(igv_inputs, renta_inputs, config=pdt.config_snapshot)" -ForegroundColor Gray
Write-Host ""
Write-Host "Ahora reinicia uvicorn y prueba los endpoints en /docs" -ForegroundColor Green
Write-Host ""
