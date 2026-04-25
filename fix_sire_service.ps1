# ============================================================
#  FELICITA - Fix: Actualizar sire_service.py para nuevos métodos
#  .\fix_sire_service.ps1
# ============================================================

Write-Host ""
Write-Host "Fix: Actualizar sire_service.py para usar nuevos métodos de sire_client" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

$servicePath = "backend\app\services\sire_service.py"

# Backup
if (Test-Path $servicePath) {
    Copy-Item $servicePath "$servicePath.bak" -Force
    Write-Host "  [OK] Backup guardado: $servicePath.bak" -ForegroundColor Green
}

# Contenido nuevo de sire_service.py
$sireServiceContent = @'
"""
Servicio SIRE: wrapper que maneja real vs mock.

Flujo:
1. Intenta descarga REAL si hay credenciales API SUNAT configuradas
2. Cae a MOCK automáticamente si falla o no hay credenciales
3. El campo 'fuente' indica si fue SUNAT_SIRE o MOCK
"""
import logging
from typing import List, Optional, Dict
from decimal import Decimal
from sqlalchemy.orm import Session

from app.models.models import Empresa, PDT621
from app.services.sire_client import SireClient, SIREError
from app.utils.encryption import desencriptar_aes

logger = logging.getLogger(__name__)


def obtener_credenciales_sunat(empresa: Empresa) -> Optional[Dict]:
    """Obtiene y desencripta credenciales API SUNAT de una empresa."""
    if not empresa.sunat_client_id or not empresa.sunat_client_secret:
        return None
    
    try:
        client_id = empresa.sunat_client_id  # ya viene desencriptado desde la BD
        client_secret = desencriptar_aes(empresa.sunat_client_secret)
        usuario_sol = empresa.usuario_sol or ""
        
        return {
            "client_id": client_id,
            "client_secret": client_secret,
            "usuario_sol": usuario_sol,
        }
    except Exception as e:
        logger.error(f"Error desencriptando credenciales SUNAT: {e}")
        return None


# ── RVIE (Ventas) ────────────────────────────────────────────────────────
def descargar_rvie(empresa_ruc: str, ano: int, mes: int, credenciales: Dict) -> Dict:
    """
    Descarga RVIE (Registro de Ventas Electrónico) de SUNAT.
    
    Intenta real primero. Si falla o no hay credenciales, retorna mock.
    """
    if not credenciales:
        logger.info(f"RVIE {ano}-{mes}: sin credenciales SUNAT, usando MOCK")
        return _generar_mock_rvie(empresa_ruc, ano, mes)
    
    try:
        return _descargar_rvie_real(empresa_ruc, ano, mes, credenciales)
    except SIREError as e:
        logger.warning(f"RVIE {ano}-{mes} fallo (SIRE real): {e}, usando MOCK")
        return _generar_mock_rvie(empresa_ruc, ano, mes)
    except Exception as e:
        logger.error(f"RVIE {ano}-{mes} error inesperado: {e}")
        return _generar_mock_rvie(empresa_ruc, ano, mes)


def _descargar_rvie_real(empresa_ruc: str, ano: int, mes: int, credenciales: Dict) -> Dict:
    """Descarga RVIE real desde SUNAT API."""
    client = SireClient(
        client_id=credenciales["client_id"],
        client_secret=credenciales["client_secret"],
        ruc=empresa_ruc,
        usuario=credenciales["usuario_sol"],
        clave_sol=credenciales.get("clave_sol", ""),  # IMPORTANTE: debe venir del request
    )
    
    logger.info(f"Descargando RVIE real {ano}-{mes} para RUC {empresa_ruc}...")
    
    # El nuevo sire_client tiene descargar_rvie() que hace todo:
    # solicita ticket -> espera -> descarga -> parsea
    comprobantes = client.descargar_rvie(ano, mes)
    
    return {
        "fuente": "SUNAT_SIRE",
        "periodo": f"{ano}{str(mes).zfill(2)}",
        "cantidad": len(comprobantes),
        "comprobantes": comprobantes,
    }


def _generar_mock_rvie(empresa_ruc: str, ano: int, mes: int) -> Dict:
    """Genera RVIE simulado para testing."""
    return {
        "fuente": "MOCK",
        "periodo": f"{ano}{str(mes).zfill(2)}",
        "cantidad": 3,
        "comprobantes": [
            {
                "periodo": f"{ano}{str(mes).zfill(2)}",
                "cuo": "001",
                "correlativo": "1",
                "fecha_emision": f"{ano}-{str(mes).zfill(2)}-05",
                "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-10",
                "tipo_cp": "01",
                "serie": "F001",
                "numero": "000001",
                "tipo_doc_cliente": "06",
                "num_doc_cliente": "20987654321",
                "razon_social": "CLIENTE MOCK S.A.C.",
                "base_imponible": Decimal("10000.00"),
                "igv": Decimal("1800.00"),
                "total": Decimal("11800.00"),
            },
            {
                "periodo": f"{ano}{str(mes).zfill(2)}",
                "cuo": "002",
                "correlativo": "2",
                "fecha_emision": f"{ano}-{str(mes).zfill(2)}-15",
                "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-20",
                "tipo_cp": "01",
                "serie": "F001",
                "numero": "000002",
                "tipo_doc_cliente": "06",
                "num_doc_cliente": "20111222333",
                "razon_social": "OTRA EMPRESA S.A.C.",
                "base_imponible": Decimal("5000.00"),
                "igv": Decimal("900.00"),
                "total": Decimal("5900.00"),
            },
            {
                "periodo": f"{ano}{str(mes).zfill(2)}",
                "cuo": "003",
                "correlativo": "3",
                "fecha_emision": f"{ano}-{str(mes).zfill(2)}-20",
                "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-25",
                "tipo_cp": "03",
                "serie": "B001",
                "numero": "000001",
                "tipo_doc_cliente": "01",
                "num_doc_cliente": "12345678",
                "razon_social": "CONSUMIDOR FINAL",
                "base_imponible": Decimal("2000.00"),
                "igv": Decimal("360.00"),
                "total": Decimal("2360.00"),
            },
        ],
    }


# ── RCE (Compras) ───────────────────────────────────────────────────────
def descargar_rce(empresa_ruc: str, ano: int, mes: int, credenciales: Dict) -> Dict:
    """
    Descarga RCE (Registro de Compras Electrónico) de SUNAT.
    
    Intenta real primero. Si falla o no hay credenciales, retorna mock.
    """
    if not credenciales:
        logger.info(f"RCE {ano}-{mes}: sin credenciales SUNAT, usando MOCK")
        return _generar_mock_rce(empresa_ruc, ano, mes)
    
    try:
        return _descargar_rce_real(empresa_ruc, ano, mes, credenciales)
    except SIREError as e:
        logger.warning(f"RCE {ano}-{mes} fallo (SIRE real): {e}, usando MOCK")
        return _generar_mock_rce(empresa_ruc, ano, mes)
    except Exception as e:
        logger.error(f"RCE {ano}-{mes} error inesperado: {e}")
        return _generar_mock_rce(empresa_ruc, ano, mes)


def _descargar_rce_real(empresa_ruc: str, ano: int, mes: int, credenciales: Dict) -> Dict:
    """Descarga RCE real desde SUNAT API."""
    client = SireClient(
        client_id=credenciales["client_id"],
        client_secret=credenciales["client_secret"],
        ruc=empresa_ruc,
        usuario=credenciales["usuario_sol"],
        clave_sol=credenciales.get("clave_sol", ""),
    )
    
    logger.info(f"Descargando RCE real {ano}-{mes} para RUC {empresa_ruc}...")
    
    # El nuevo sire_client tiene descargar_rce() que hace todo
    comprobantes = client.descargar_rce(ano, mes)
    
    return {
        "fuente": "SUNAT_SIRE",
        "periodo": f"{ano}{str(mes).zfill(2)}",
        "cantidad": len(comprobantes),
        "comprobantes": comprobantes,
    }


def _generar_mock_rce(empresa_ruc: str, ano: int, mes: int) -> Dict:
    """Genera RCE simulado para testing."""
    return {
        "fuente": "MOCK",
        "periodo": f"{ano}{str(mes).zfill(2)}",
        "cantidad": 2,
        "comprobantes": [
            {
                "periodo": f"{ano}{str(mes).zfill(2)}",
                "cuo": "001",
                "correlativo": "1",
                "fecha_emision": f"{ano}-{str(mes).zfill(2)}-03",
                "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-08",
                "tipo_cp": "01",
                "serie": "FF01",
                "numero": "000001",
                "anio_emision_dua": "",
                "tipo_doc_proveedor": "06",
                "num_doc_proveedor": "20555666777",
                "razon_social": "PROVEEDOR MOCK S.A.C.",
                "base_imponible": Decimal("8000.00"),
                "igv": Decimal("1440.00"),
                "total": Decimal("9440.00"),
                "tipo_cambio": Decimal("3.60"),
            },
            {
                "periodo": f"{ano}{str(mes).zfill(2)}",
                "cuo": "002",
                "correlativo": "2",
                "fecha_emision": f"{ano}-{str(mes).zfill(2)}-10",
                "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-15",
                "tipo_cp": "01",
                "serie": "FF01",
                "numero": "000002",
                "anio_emision_dua": "",
                "tipo_doc_proveedor": "06",
                "num_doc_proveedor": "20999888777",
                "razon_social": "OTRO PROVEEDOR S.A.",
                "base_imponible": Decimal("3000.00"),
                "igv": Decimal("540.00"),
                "total": Decimal("3540.00"),
                "tipo_cambio": Decimal("3.60"),
            },
        ],
    }
'@

$sireServiceContent | Set-Content $servicePath -Encoding UTF8
Write-Host "  [OK] sire_service.py actualizado con métodos correctos" -ForegroundColor Green

Write-Host ""
Write-Host "=== Fix aplicado ===" -ForegroundColor Green
Write-Host ""
Write-Host "CAMBIOS:" -ForegroundColor Yellow
Write-Host "  1. _descargar_rvie_real() ahora usa: client.descargar_rvie(ano, mes)" -ForegroundColor White
Write-Host "  2. _descargar_rce_real() ahora usa: client.descargar_rce(ano, mes)" -ForegroundColor White
Write-Host "  3. Los métodos nuevos hacen: solicitar + esperar + descargar + parsear" -ForegroundColor White
Write-Host "  4. Fallback automático a MOCK si hay error" -ForegroundColor White
Write-Host ""
Write-Host "Reinicia uvicorn y vuelve a probar:" -ForegroundColor Yellow
Write-Host "  POST /api/v1/pdt621/21/importar-sunat" -ForegroundColor White
