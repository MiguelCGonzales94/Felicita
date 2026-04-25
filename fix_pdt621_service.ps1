# ============================================================
#  FELICITA - Fix: pdt621_service.py accede a dict correctamente
#  .\fix_pdt621_service.ps1
# ============================================================

Write-Host ""
Write-Host "Fix: pdt621_service.py - acceso a dict en lugar de objeto" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

$path = "backend\app\services\pdt621_service.py"
if (-not (Test-Path $path)) {
    Write-Host "ERROR: no se encontro $path" -ForegroundColor Red
    exit 1
}

# Backup
Copy-Item $path "$path.bak" -Force
Write-Host "  [OK] Backup: $path.bak" -ForegroundColor Green

$content = Get-Content $path -Raw

# ── Fix 1: rvie.comprobantes → rvie["comprobantes"] ──────────────────────
$content = $content -replace '(\brvie\b)\.comprobantes', '$1["comprobantes"]'
$content = $content -replace '(\brvie\b)\.fuente',        '$1["fuente"]'
$content = $content -replace '(\brvie\b)\.cantidad',      '$1["cantidad"]'
$content = $content -replace '(\brvie\b)\.periodo',       '$1["periodo"]'

# ── Fix 2: rce.comprobantes → rce["comprobantes"] ───────────────────────
$content = $content -replace '(\brce\b)\.comprobantes', '$1["comprobantes"]'
$content = $content -replace '(\brce\b)\.fuente',        '$1["fuente"]'
$content = $content -replace '(\brce\b)\.cantidad',      '$1["cantidad"]'
$content = $content -replace '(\brce\b)\.periodo',       '$1["periodo"]'

Set-Content $path $content -Encoding UTF8
Write-Host "  [OK] pdt621_service.py corregido (dict access)" -ForegroundColor Green

Write-Host ""
Write-Host "Ahora levanta uvicorn manualmente:" -ForegroundColor Yellow
Write-Host "  cd backend" -ForegroundColor White
Write-Host "  venv\Scripts\activate" -ForegroundColor White
Write-Host "  python -m uvicorn app.main:app --reload" -ForegroundColor White
Write-Host ""
Write-Host "El error ECONNREFUSED del frontend desaparece cuando uvicorn este arriba." -ForegroundColor Gray
