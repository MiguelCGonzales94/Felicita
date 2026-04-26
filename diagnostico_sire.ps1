# ============================================================
#  FELICITA - Diagnostico SIRE: ver exactamente que se envia
#  .\diagnostico_sire.ps1
#
#  Cambios:
#  1. Logs de SIRE auth ahora son WARNING (visible en uvicorn)
#  2. Endpoint nuevo: GET /api/v1/empresas/{id}/sire/debug
#     que te muestra exactamente que se enviaria a SUNAT
#     (sin password, por seguridad)
# ============================================================

Write-Host ""
Write-Host "Aplicando diagnostico SIRE" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz del proyecto" -ForegroundColor Red
    exit 1
}

# ============================================================
# 1. sire_client.py: cambiar logger.info por logger.warning
# ============================================================
$clientPath = "backend\app\services\sire_client.py"
if (Test-Path $clientPath) {
    $content = Get-Content $clientPath -Raw
    # Solo en las lineas de auth
    $content = $content -replace 'logger\.info\(f"SIRE auth ->', 'logger.warning(f"SIRE auth ->'
    $content = $content -replace 'logger\.info\("SIRE auth OK"\)', 'logger.warning("SIRE auth OK")'
    Set-Content $clientPath $content -Encoding UTF8
    Write-Host "[OK] sire_client.py - logs subidos a WARNING" -ForegroundColor Green
}

# ============================================================
# 2. Agregar endpoint de diagnostico al router
# ============================================================
$routerPath = "backend\app\routers\pdt621.py"
$routerContent = Get-Content $routerPath -Raw

# Solo si no existe ya el endpoint
if ($routerContent -notmatch '/sire/debug') {
    $endpointDebug = @'


# ════════════════════════════════════════════════════════════
# DEBUG: Ver exactamente que se enviaria a SUNAT
# ════════════════════════════════════════════════════════════
@router.get("/empresas/{empresa_id}/sire/debug")
def debug_sire_credenciales(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """
    Endpoint de diagnostico: muestra exactamente que se enviaria a SUNAT.
    No expone la password ni el client_secret completos.
    """
    from app.services.sire_service import obtener_credenciales_sunat
    from app.models.models import Empresa

    empresa = db.query(Empresa).filter_by(id=empresa_id).first()
    if not empresa:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")

    cred = obtener_credenciales_sunat(empresa)

    if not cred:
        return {
            "configurado": False,
            "mensaje": "La empresa no tiene credenciales API SUNAT configuradas",
            "campos_requeridos": [
                "sunat_client_id",
                "sunat_client_secret",
                "usuario_sol",
                "clave_sol (en cada request)",
            ],
        }

    # Construir el username como lo hara el cliente
    ruc = empresa.ruc
    usuario = cred.get("usuario_sol", "") or ""
    username_final = f"{ruc} {usuario}" if usuario else ruc

    # Mascarar valores sensibles
    client_id = cred.get("client_id", "")
    client_secret = cred.get("client_secret", "")
    clave_sol = cred.get("clave_sol", "")

    def mask(valor, mostrar_inicio=4, mostrar_final=4):
        if not valor or len(valor) < 8:
            return "***"
        return f"{valor[:mostrar_inicio]}...{valor[-mostrar_final:]} (len={len(valor)})"

    return {
        "configurado": True,
        "empresa": {
            "id": empresa.id,
            "ruc": empresa.ruc,
            "razon_social": empresa.razon_social,
        },
        "credenciales_origen": {
            "sunat_client_id": mask(client_id),
            "sunat_client_secret": mask(client_secret) if client_secret else "VACIO",
            "usuario_sol": usuario or "VACIO",
            "clave_sol_enviada": mask(clave_sol) if clave_sol else "VACIO o no se paso",
        },
        "request_que_se_enviaria": {
            "url": f"https://api-seguridad.sunat.gob.pe/v1/clientessol/{client_id[:8]}.../oauth2/token/",
            "method": "POST",
            "content_type": "application/x-www-form-urlencoded",
            "body": {
                "grant_type": "password",
                "scope": "https://api-sire.sunat.gob.pe",
                "client_id": mask(client_id),
                "client_secret": mask(client_secret) if client_secret else "VACIO",
                "username": username_final,
                "password": mask(clave_sol) if clave_sol else "VACIO",
            },
        },
        "validaciones": {
            "ruc_es_valido": len(ruc) == 11 and ruc.isdigit(),
            "tiene_usuario_sol": bool(usuario),
            "tiene_clave_sol": bool(clave_sol),
            "tiene_client_id": bool(client_id),
            "tiene_client_secret": bool(client_secret),
            "username_format_correcto": " " in username_final if usuario else False,
        },
        "diagnostico": _diagnosticar(ruc, usuario, clave_sol, client_id, client_secret),
    }


def _diagnosticar(ruc, usuario, clave_sol, client_id, client_secret):
    """Genera mensajes de diagnostico segun los campos."""
    problemas = []

    if not usuario:
        problemas.append("CRITICO: usuario_sol esta vacio. Configurar en empresa.")
    if not clave_sol:
        problemas.append("CRITICO: clave_sol no llega al backend. Revisar como se envia desde frontend.")
    if not client_id:
        problemas.append("CRITICO: sunat_client_id vacio. Generar en Portal SOL.")
    if not client_secret:
        problemas.append("CRITICO: sunat_client_secret vacio o no se desencripta.")

    if usuario and len(usuario) < 3:
        problemas.append("WARN: usuario_sol parece muy corto. Confirmar valor.")
    if usuario and ruc in usuario:
        problemas.append("WARN: usuario_sol contiene el RUC. Debe ser solo el nombre del usuario secundario.")
    if clave_sol and len(clave_sol) < 6:
        problemas.append("WARN: clave_sol parece muy corta.")

    if not problemas:
        return ["Todos los campos parecen estar bien. El access_denied seria por credenciales incorrectas en SOL."]
    return problemas
'@

    # Agregar al final del archivo
    Add-Content $routerPath $endpointDebug -Encoding UTF8
    Write-Host "[OK] Endpoint /sire/debug agregado al router" -ForegroundColor Green
} else {
    Write-Host "[OK] Endpoint /sire/debug ya existe" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "  Diagnostico aplicado" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Uvicorn con --reload detecta los cambios solo." -ForegroundColor Yellow
Write-Host ""
Write-Host "Para diagnosticar, abre en navegador:" -ForegroundColor Cyan
Write-Host "  http://localhost:8000/docs" -ForegroundColor White
Write-Host ""
Write-Host "Busca el endpoint:" -ForegroundColor Cyan
Write-Host "  GET /api/v1/empresas/{empresa_id}/sire/debug" -ForegroundColor White
Write-Host ""
Write-Host "Ejecutalo con id=7 (tu empresa) y compartime la respuesta JSON." -ForegroundColor Yellow
Write-Host "Te dira exactamente que esta llegando al codigo." -ForegroundColor Yellow
