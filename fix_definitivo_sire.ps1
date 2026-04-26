# ============================================================
#  FELICITA - Fix DEFINITIVO: usar empresa_service.obtener_credenciales_sunat
#  .\fix_definitivo_sire.ps1
#
#  Lo que hace:
#  1. Reescribe sire_service.py para usar empresa_service.obtener_credenciales_sunat
#     (ya existe y maneja correctamente los campos *_encrypted)
#  2. Reescribe el endpoint /sire/debug usando la funcion correcta
#  3. Restaura el formato del flujo original (con objetos Pydantic)
# ============================================================

Write-Host ""
Write-Host "Fix DEFINITIVO SIRE - usando empresa_service" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz del proyecto" -ForegroundColor Red
    exit 1
}

# ============================================================
# 1. Quitar el endpoint debug roto del router (lo agregamos al final)
# ============================================================
$routerPath = "backend\app\routers\pdt621.py"
$routerContent = Get-Content $routerPath -Raw

# Buscar y eliminar el bloque del endpoint debug si existe
if ($routerContent -match '/sire/debug') {
    Write-Host "Quitando endpoint /sire/debug viejo..." -ForegroundColor Yellow
    # Backup
    Copy-Item $routerPath "$routerPath.bak5" -Force

    # Eliminar desde el comentario "DEBUG:" hasta el final del archivo
    # asumiendo que se agrego con Add-Content al final
    $lines = Get-Content $routerPath
    $cutLine = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "DEBUG: Ver exactamente que se enviaria a SUNAT") {
            # Retroceder para incluir el separador
            $cutLine = $i - 2
            if ($cutLine -lt 0) { $cutLine = $i - 1 }
            break
        }
    }
    if ($cutLine -gt 0) {
        $lines[0..($cutLine-1)] | Set-Content $routerPath -Encoding UTF8
        Write-Host "[OK] Endpoint debug viejo eliminado" -ForegroundColor Green
    }
}

# ============================================================
# 2. Agregar el endpoint debug CORRECTO al final
# ============================================================
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
    from app.services.empresa_service import obtener_credenciales_sunat
    from app.models.models import Empresa

    empresa = db.query(Empresa).filter_by(id=empresa_id).first()
    if not empresa:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")

    cred = obtener_credenciales_sunat(empresa)
    ruc = empresa.ruc
    usuario = cred.get("usuario", "") or ""
    clave_sol = cred.get("clave_sol", "") or ""
    client_id = cred.get("client_id", "") or ""
    client_secret = cred.get("client_secret", "") or ""
    tipo_acceso = cred.get("tipo_acceso", "RUC")
    dni = cred.get("dni", "") or ""

    username_final = f"{ruc} {usuario}" if usuario else ruc

    def mask(valor, mostrar_inicio=4, mostrar_final=4):
        if not valor or len(valor) < 8:
            return "VACIO" if not valor else "***"
        return f"{valor[:mostrar_inicio]}...{valor[-mostrar_final:]} (len={len(valor)})"

    problemas = []
    if not usuario:
        problemas.append("CRITICO: usuario_sol esta vacio. Configurar en datos de empresa.")
    if not clave_sol:
        problemas.append("CRITICO: clave_sol vacia o no se desencripta correctamente.")
    if not client_id:
        problemas.append("CRITICO: sunat_client_id vacio. Generar en Portal SOL > Credenciales API SUNAT.")
    if not client_secret:
        problemas.append("CRITICO: sunat_client_secret vacio o no se desencripta.")
    if usuario and ruc in usuario:
        problemas.append("WARN: usuario_sol contiene el RUC. Usar solo el nombre del usuario secundario (ej: 'MIGUEL01').")
    if usuario and len(usuario) < 3:
        problemas.append("WARN: usuario_sol parece muy corto.")
    if usuario and " " in usuario:
        problemas.append("WARN: usuario_sol tiene espacios. Debe ser una sola palabra.")
    if not problemas:
        problemas = ["Todos los campos parecen estar bien. Si SUNAT da access_denied es problema de credenciales en Portal SOL."]

    return {
        "empresa": {
            "id": empresa.id,
            "ruc": empresa.ruc,
            "razon_social": empresa.razon_social,
            "tipo_acceso_sol": tipo_acceso,
        },
        "credenciales_desencriptadas": {
            "usuario_sol": usuario or "VACIO",
            "clave_sol": mask(clave_sol),
            "client_id": mask(client_id),
            "client_secret": mask(client_secret),
            "dni_sol": dni or "VACIO",
        },
        "request_que_se_enviaria_a_sunat": {
            "url": f"https://api-seguridad.sunat.gob.pe/v1/clientessol/{client_id[:8] if client_id else 'VACIO'}.../oauth2/token/",
            "method": "POST",
            "headers": {"Content-Type": "application/x-www-form-urlencoded"},
            "body": {
                "grant_type": "password",
                "scope": "https://api-sire.sunat.gob.pe",
                "client_id": mask(client_id),
                "client_secret": mask(client_secret),
                "username": username_final,
                "password": mask(clave_sol),
            },
        },
        "validaciones": {
            "ruc_valido": len(ruc) == 11 and ruc.isdigit(),
            "tiene_usuario": bool(usuario),
            "tiene_clave_sol": bool(clave_sol),
            "tiene_client_id": bool(client_id),
            "tiene_client_secret": bool(client_secret),
            "username_tiene_espacio": " " in username_final if usuario else False,
        },
        "diagnostico": problemas,
    }
'@

Add-Content $routerPath $endpointDebug -Encoding UTF8
Write-Host "[OK] Endpoint /sire/debug nuevo agregado (usa empresa_service)" -ForegroundColor Green

# ============================================================
# 3. Verificar que sire_service.py use empresa_service
# ============================================================
$sirePath = "backend\app\services\sire_service.py"
$sireContent = Get-Content $sirePath -Raw

if ($sireContent -match "obtener_credenciales_sunat" -and $sireContent -notmatch "from app\.services\.empresa_service import obtener_credenciales_sunat") {
    Write-Host ""
    Write-Host "Reescribiendo sire_service.py para usar empresa_service..." -ForegroundColor Yellow
    Copy-Item $sirePath "$sirePath.bak6" -Force

    # Reescribir el archivo completo
    $nuevoSire = @'
"""
Servicio SIRE - Wrapper principal.

Estrategia:
- Si la empresa tiene credenciales API SUNAT configuradas, intenta descarga real.
- Si falla o no tiene credenciales, usa datos mock (para desarrollo).
- Retorna estructura identica en ambos casos.
"""
from typing import Optional, List
from pydantic import BaseModel
from datetime import date
from decimal import Decimal
import random
import logging

from app.services.sire_client import SireClient, SIREError
from app.services.empresa_service import obtener_credenciales_sunat

logger = logging.getLogger(__name__)


# Re-export para que pdt621_service y otros puedan importarlo desde sire_service
__all__ = ["descargar_rvie", "descargar_rce", "obtener_credenciales_sunat",
           "ResumenRVIE", "ResumenRCE", "ComprobanteImportado"]


class ComprobanteImportado(BaseModel):
    tipo_comprobante: str
    serie: str
    numero: str
    fecha_emision: str
    ruc_contraparte: Optional[str] = None
    nombre_contraparte: str
    base_gravada: Decimal = Decimal("0")
    igv: Decimal = Decimal("0")
    base_no_gravada: Decimal = Decimal("0")
    exportacion: Decimal = Decimal("0")
    total: Decimal


class ResumenRVIE(BaseModel):
    periodo_ano: int
    periodo_mes: int
    total_comprobantes: int
    total_ventas_gravadas: Decimal
    total_ventas_no_gravadas: Decimal
    total_exportaciones: Decimal
    total_ventas_exoneradas: Decimal
    total_igv_debito: Decimal
    total_general: Decimal
    comprobantes: List[ComprobanteImportado]
    fuente: str = "MOCK"


class ResumenRCE(BaseModel):
    periodo_ano: int
    periodo_mes: int
    total_comprobantes: int
    total_compras_gravadas: Decimal
    total_compras_no_gravadas: Decimal
    total_igv_credito: Decimal
    total_general: Decimal
    comprobantes: List[ComprobanteImportado]
    fuente: str = "MOCK"


def _tiene_credenciales(cred: dict) -> bool:
    return bool(
        cred.get("client_id")
        and cred.get("client_secret")
        and cred.get("clave_sol")
    )


def descargar_rvie(empresa_ruc: str, ano: int, mes: int, credenciales: Optional[dict] = None) -> ResumenRVIE:
    """Descarga el Registro de Ventas Electronico."""
    if credenciales and _tiene_credenciales(credenciales):
        try:
            return _descargar_rvie_real(empresa_ruc, ano, mes, credenciales)
        except SIREError as e:
            logger.warning(f"SIRE real fallo, usando mock: {e}")
        except Exception as e:
            logger.error(f"Error inesperado SIRE: {e}, usando mock")
    return _generar_rvie_mock(empresa_ruc, ano, mes)


def descargar_rce(empresa_ruc: str, ano: int, mes: int, credenciales: Optional[dict] = None) -> ResumenRCE:
    """Descarga el Registro de Compras Electronico."""
    if credenciales and _tiene_credenciales(credenciales):
        try:
            return _descargar_rce_real(empresa_ruc, ano, mes, credenciales)
        except SIREError as e:
            logger.warning(f"SIRE real fallo, usando mock: {e}")
        except Exception as e:
            logger.error(f"Error inesperado SIRE: {e}, usando mock")
    return _generar_rce_mock(empresa_ruc, ano, mes)


def _descargar_rvie_real(ruc: str, ano: int, mes: int, cred: dict) -> ResumenRVIE:
    client = SireClient(
        client_id=cred["client_id"],
        client_secret=cred["client_secret"],
        ruc=cred.get("ruc", ruc),
        usuario=cred.get("usuario", ""),
        clave_sol=cred["clave_sol"],
    )
    periodo = f"{ano:04d}{mes:02d}"
    data = client.descargar_propuesta_rvie(periodo)
    comprobantes = [ComprobanteImportado(**c) for c in data["comprobantes"]]
    return ResumenRVIE(
        periodo_ano=data["periodo_ano"],
        periodo_mes=data["periodo_mes"],
        total_comprobantes=data["total_comprobantes"],
        total_ventas_gravadas=Decimal(str(data["total_ventas_gravadas"])),
        total_ventas_no_gravadas=Decimal(str(data["total_ventas_no_gravadas"])),
        total_exportaciones=Decimal(str(data["total_exportaciones"])),
        total_ventas_exoneradas=Decimal(str(data.get("total_ventas_exoneradas", 0))),
        total_igv_debito=Decimal(str(data["total_igv_debito"])),
        total_general=Decimal(str(data["total_general"])),
        comprobantes=comprobantes,
        fuente="SUNAT_SIRE",
    )


def _descargar_rce_real(ruc: str, ano: int, mes: int, cred: dict) -> ResumenRCE:
    client = SireClient(
        client_id=cred["client_id"],
        client_secret=cred["client_secret"],
        ruc=cred.get("ruc", ruc),
        usuario=cred.get("usuario", ""),
        clave_sol=cred["clave_sol"],
    )
    periodo = f"{ano:04d}{mes:02d}"
    data = client.descargar_propuesta_rce(periodo)
    comprobantes = [ComprobanteImportado(**c) for c in data["comprobantes"]]
    return ResumenRCE(
        periodo_ano=data["periodo_ano"],
        periodo_mes=data["periodo_mes"],
        total_comprobantes=data["total_comprobantes"],
        total_compras_gravadas=Decimal(str(data["total_compras_gravadas"])),
        total_compras_no_gravadas=Decimal(str(data["total_compras_no_gravadas"])),
        total_igv_credito=Decimal(str(data["total_igv_credito"])),
        total_general=Decimal(str(data["total_general"])),
        comprobantes=comprobantes,
        fuente="SUNAT_SIRE",
    )


def _generar_rvie_mock(ruc: str, ano: int, mes: int) -> ResumenRVIE:
    random.seed(f"ventas-{ruc}-{ano}-{mes}")
    clientes = [
        ("20100070970", "SAGA FALABELLA S.A."),
        ("20477314832", "HIPERMERCADOS TOTTUS S.A."),
        ("20546798745", "DISTRIBUIDORA CENTRAL S.A.C."),
        ("20512345678", "SERVICIOS GENERALES DEL NORTE SRL"),
        ("20601234567", "INVERSIONES EL PACIFICO S.A."),
        ("20445566778", "CORPORACION COMERCIAL LIMA SAC"),
        ("10456789012", "JUAN PEREZ MENDOZA"),
        ("10234567891", "MARIA LOPEZ TORRES"),
        ("20987654321", "TRANSPORTES RAPIDOS DEL SUR SRL"),
        ("20555666777", "CONSTRUCTORA NUEVO HORIZONTE SAC"),
        ("20334455667", "LOGISTICA INTEGRAL PERU S.A."),
        ("20778899001", "SERVICIOS INDUSTRIALES AREQUIPA SAC"),
    ]
    num_comprobantes = random.randint(12, 18)
    comprobantes = []
    for i in range(num_comprobantes):
        c = random.choice(clientes)
        es_factura = random.random() < 0.75
        tipo = "01" if es_factura else "03"
        serie_letra = "F" if es_factura else "B"
        serie = f"{serie_letra}{random.randint(1, 5):03d}"
        base = Decimal(random.randint(200, 8000)) + Decimal(random.randint(0, 99)) / Decimal(100)
        base = base.quantize(Decimal("0.01"))
        igv = (base * Decimal("0.18")).quantize(Decimal("0.01"))
        total = base + igv
        dia = random.randint(1, 28)
        comprobantes.append(ComprobanteImportado(
            tipo_comprobante=tipo, serie=serie,
            numero=str(1000 + i + random.randint(0, 500)),
            fecha_emision=f"{ano:04d}-{mes:02d}-{dia:02d}",
            ruc_contraparte=c[0], nombre_contraparte=c[1],
            base_gravada=base, igv=igv, total=total,
        ))
    comprobantes.sort(key=lambda x: x.fecha_emision)
    total_g = sum(c.base_gravada for c in comprobantes)
    total_ng = sum(c.base_no_gravada for c in comprobantes)
    total_exp = sum(c.exportacion for c in comprobantes)
    total_igv = sum(c.igv for c in comprobantes)
    total_gral = sum(c.total for c in comprobantes)
    return ResumenRVIE(
        periodo_ano=ano, periodo_mes=mes,
        total_comprobantes=len(comprobantes),
        total_ventas_gravadas=total_g,
        total_ventas_no_gravadas=total_ng,
        total_exportaciones=total_exp,
        total_ventas_exoneradas=Decimal("0"),
        total_igv_debito=total_igv,
        total_general=total_gral,
        comprobantes=comprobantes, fuente="MOCK",
    )


def _generar_rce_mock(ruc: str, ano: int, mes: int) -> ResumenRCE:
    random.seed(f"compras-{ruc}-{ano}-{mes}")
    proveedores = [
        ("20100047218", "TELEFONICA DEL PERU S.A.A."),
        ("20100030595", "LUZ DEL SUR S.A.A."),
        ("20136007044", "SEDAPAL S.A."),
        ("20100070970", "SAGA FALABELLA S.A."),
        ("20503840121", "CENCOSUD RETAIL PERU S.A."),
        ("20100128056", "SODIMAC PERU S.A."),
        ("20100039880", "CORPORACION LINDLEY S.A."),
        ("20101024645", "BACKUS Y JOHNSTON S.A.A."),
        ("20512345678", "SUMINISTROS DE OFICINA LIMA SAC"),
        ("20601234567", "IMPORTACIONES TECNICAS DEL PERU SAC"),
        ("20445566778", "SERVICIOS CONTABLES ASOCIADOS SRL"),
        ("20334455667", "TRANSPORTES Y FLETES DEL NORTE SAC"),
        ("20778899001", "MATERIALES DE CONSTRUCCION LIMA SAC"),
        ("20556677889", "SERVICIOS DE COURIER RAPIDO SAC"),
        ("20667788990", "COMBUSTIBLES Y LUBRICANTES DEL SUR SA"),
    ]
    num_comprobantes = random.randint(15, 22)
    comprobantes = []
    for i in range(num_comprobantes):
        p = random.choice(proveedores)
        base = Decimal(random.randint(80, 3500)) + Decimal(random.randint(0, 99)) / Decimal(100)
        base = base.quantize(Decimal("0.01"))
        igv = (base * Decimal("0.18")).quantize(Decimal("0.01"))
        total = base + igv
        dia = random.randint(1, 28)
        comprobantes.append(ComprobanteImportado(
            tipo_comprobante="01",
            serie=f"F{random.randint(1, 99):03d}",
            numero=str(random.randint(10000, 99999)),
            fecha_emision=f"{ano:04d}-{mes:02d}-{dia:02d}",
            ruc_contraparte=p[0], nombre_contraparte=p[1],
            base_gravada=base, igv=igv, total=total,
        ))
    comprobantes.sort(key=lambda x: x.fecha_emision)
    total_g = sum(c.base_gravada for c in comprobantes)
    total_ng = sum(c.base_no_gravada for c in comprobantes)
    total_igv = sum(c.igv for c in comprobantes)
    total_gral = sum(c.total for c in comprobantes)
    return ResumenRCE(
        periodo_ano=ano, periodo_mes=mes,
        total_comprobantes=len(comprobantes),
        total_compras_gravadas=total_g,
        total_compras_no_gravadas=total_ng,
        total_igv_credito=total_igv,
        total_general=total_gral,
        comprobantes=comprobantes, fuente="MOCK",
    )
'@

    Set-Content $sirePath $nuevoSire -Encoding UTF8
    Write-Host "[OK] sire_service.py reescrito - ahora usa empresa_service" -ForegroundColor Green
} else {
    Write-Host "[INFO] sire_service.py ya esta correcto" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "  Fix definitivo aplicado" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Uvicorn con --reload detecta los cambios solo." -ForegroundColor Yellow
Write-Host ""
Write-Host "Prueba el endpoint en http://localhost:8000/docs:" -ForegroundColor Cyan
Write-Host "  GET /api/v1/empresas/7/sire/debug" -ForegroundColor White
Write-Host ""
Write-Host "Comparte la respuesta JSON conmigo." -ForegroundColor Yellow
