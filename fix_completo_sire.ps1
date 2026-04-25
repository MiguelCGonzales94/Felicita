# ============================================================
#  FELICITA - Fix completo: pdt621_service.py + sire_service.py
#  .\fix_completo_sire.ps1
#  Resuelve TODOS los errores de una sola vez:
#   1. 'usuario_sol' KeyError → clave_sol faltante en credenciales
#   2. c.tipo_comprobante → c["tipo_cp"] (los comprobantes son dicts)
#   3. Cualquier otro acceso .atributo sobre dicts del sire
# ============================================================

Write-Host ""
Write-Host "Fix completo SIRE - todos los errores de una vez" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# 1. sire_service.py — fix clave_sol faltante en credenciales
# ============================================================
$sireServicePath = "backend\app\services\sire_service.py"
Copy-Item $sireServicePath "$sireServicePath.bak2" -Force

@'
"""
Servicio SIRE: wrapper real vs mock.
- Intenta descarga REAL si hay credenciales API SUNAT
- Cae a MOCK si falla o no hay credenciales
- 'fuente' en respuesta indica SUNAT_SIRE o MOCK
"""
import logging
from typing import List, Optional, Dict
from decimal import Decimal

from app.models.models import Empresa
from app.services.sire_client import SireClient, SIREError
from app.utils.encryption import decrypt_text

logger = logging.getLogger(__name__)


def obtener_credenciales_sunat(empresa: Empresa, clave_sol: str = "") -> Optional[Dict]:
    """
    Obtiene y desencripta credenciales API SUNAT de una empresa.
    clave_sol viene del request (nunca se guarda en texto plano).
    """
    if not empresa.sunat_client_id or not empresa.sunat_client_secret:
        return None
    try:
        client_secret = decrypt_text(empresa.sunat_client_secret)
        return {
            "client_id":    empresa.sunat_client_id,
            "client_secret": client_secret,
            "usuario_sol":  getattr(empresa, "usuario_sol", "") or "",
            "clave_sol":    clave_sol,
        }
    except Exception as e:
        logger.error(f"Error desencriptando credenciales SUNAT: {e}")
        return None


# ── RVIE (Ventas) ─────────────────────────────────────────────────────────
def descargar_rvie(empresa_ruc: str, ano: int, mes: int, credenciales) -> Dict:
    if not credenciales:
        logger.info(f"RVIE {ano}-{mes}: sin credenciales, usando MOCK")
        return _mock_rvie(empresa_ruc, ano, mes)
    try:
        return _real_rvie(empresa_ruc, ano, mes, credenciales)
    except SIREError as e:
        logger.warning(f"SIRE real fallo, usando mock: {e}")
        return _mock_rvie(empresa_ruc, ano, mes)
    except Exception as e:
        logger.error(f"RVIE {ano}-{mes} error inesperado: {e}")
        return _mock_rvie(empresa_ruc, ano, mes)


def _real_rvie(empresa_ruc: str, ano: int, mes: int, creds: Dict) -> Dict:
    client = SireClient(
        client_id=creds["client_id"],
        client_secret=creds["client_secret"],
        ruc=empresa_ruc,
        usuario=creds["usuario_sol"],
        clave_sol=creds["clave_sol"],
    )
    comprobantes = client.descargar_rvie(ano, mes)
    return {"fuente": "SUNAT_SIRE", "periodo": f"{ano}{str(mes).zfill(2)}",
            "cantidad": len(comprobantes), "comprobantes": comprobantes}


def _mock_rvie(empresa_ruc: str, ano: int, mes: int) -> Dict:
    periodo = f"{ano}{str(mes).zfill(2)}"
    return {
        "fuente": "MOCK", "periodo": periodo, "cantidad": 3,
        "comprobantes": [
            {"periodo": periodo, "cuo": "001", "correlativo": "1",
             "fecha_emision": f"{ano}-{str(mes).zfill(2)}-05",
             "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-10",
             "tipo_cp": "01", "serie": "F001", "numero": "000001",
             "tipo_doc_cliente": "06", "num_doc_cliente": "20987654321",
             "razon_social": "CLIENTE MOCK S.A.C.",
             "base_imponible": Decimal("10000.00"), "igv": Decimal("1800.00"),
             "total": Decimal("11800.00")},
            {"periodo": periodo, "cuo": "002", "correlativo": "2",
             "fecha_emision": f"{ano}-{str(mes).zfill(2)}-15",
             "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-20",
             "tipo_cp": "01", "serie": "F001", "numero": "000002",
             "tipo_doc_cliente": "06", "num_doc_cliente": "20111222333",
             "razon_social": "OTRA EMPRESA S.A.C.",
             "base_imponible": Decimal("5000.00"), "igv": Decimal("900.00"),
             "total": Decimal("5900.00")},
            {"periodo": periodo, "cuo": "003", "correlativo": "3",
             "fecha_emision": f"{ano}-{str(mes).zfill(2)}-20",
             "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-25",
             "tipo_cp": "03", "serie": "B001", "numero": "000001",
             "tipo_doc_cliente": "01", "num_doc_cliente": "12345678",
             "razon_social": "CONSUMIDOR FINAL",
             "base_imponible": Decimal("2000.00"), "igv": Decimal("360.00"),
             "total": Decimal("2360.00")},
        ],
    }


# ── RCE (Compras) ─────────────────────────────────────────────────────────
def descargar_rce(empresa_ruc: str, ano: int, mes: int, credenciales) -> Dict:
    if not credenciales:
        logger.info(f"RCE {ano}-{mes}: sin credenciales, usando MOCK")
        return _mock_rce(empresa_ruc, ano, mes)
    try:
        return _real_rce(empresa_ruc, ano, mes, credenciales)
    except SIREError as e:
        logger.warning(f"SIRE real fallo, usando mock: {e}")
        return _mock_rce(empresa_ruc, ano, mes)
    except Exception as e:
        logger.error(f"RCE {ano}-{mes} error inesperado: {e}")
        return _mock_rce(empresa_ruc, ano, mes)


def _real_rce(empresa_ruc: str, ano: int, mes: int, creds: Dict) -> Dict:
    client = SireClient(
        client_id=creds["client_id"],
        client_secret=creds["client_secret"],
        ruc=empresa_ruc,
        usuario=creds["usuario_sol"],
        clave_sol=creds["clave_sol"],
    )
    comprobantes = client.descargar_rce(ano, mes)
    return {"fuente": "SUNAT_SIRE", "periodo": f"{ano}{str(mes).zfill(2)}",
            "cantidad": len(comprobantes), "comprobantes": comprobantes}


def _mock_rce(empresa_ruc: str, ano: int, mes: int) -> Dict:
    periodo = f"{ano}{str(mes).zfill(2)}"
    return {
        "fuente": "MOCK", "periodo": periodo, "cantidad": 2,
        "comprobantes": [
            {"periodo": periodo, "cuo": "001", "correlativo": "1",
             "fecha_emision": f"{ano}-{str(mes).zfill(2)}-03",
             "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-08",
             "tipo_cp": "01", "serie": "FF01", "numero": "000001",
             "anio_emision_dua": "", "tipo_doc_proveedor": "06",
             "num_doc_proveedor": "20555666777",
             "razon_social": "PROVEEDOR MOCK S.A.C.",
             "base_imponible": Decimal("8000.00"), "igv": Decimal("1440.00"),
             "total": Decimal("9440.00"), "tipo_cambio": Decimal("3.60")},
            {"periodo": periodo, "cuo": "002", "correlativo": "2",
             "fecha_emision": f"{ano}-{str(mes).zfill(2)}-10",
             "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-15",
             "tipo_cp": "01", "serie": "FF01", "numero": "000002",
             "anio_emision_dua": "", "tipo_doc_proveedor": "06",
             "num_doc_proveedor": "20999888777",
             "razon_social": "OTRO PROVEEDOR S.A.",
             "base_imponible": Decimal("3000.00"), "igv": Decimal("540.00"),
             "total": Decimal("3540.00"), "tipo_cambio": Decimal("3.60")},
        ],
    }
'@ | Set-Content $sireServicePath -Encoding UTF8
Write-Host "  [OK] sire_service.py — fix clave_sol + estructura limpia" -ForegroundColor Green

# ============================================================
# 2. pdt621_service.py — reescribir importar_desde_sire
#    para que trabaje 100% con dicts (no con objetos)
# ============================================================
$pdt621Path = "backend\app\services\pdt621_service.py"
Copy-Item $pdt621Path "$pdt621Path.bak2" -Force

# Leer el archivo actual
$pdt621Content = Get-Content $pdt621Path -Raw

# Reemplazar la función importar_desde_sire completa
# Buscamos desde "def importar_desde_sire" hasta la siguiente función "def "
$nuevaFuncion = @'

def importar_desde_sire(db, pdt, empresa):
    """
    Descarga RVIE y RCE de SUNAT (o mock) y actualiza el PDT 621.
    Los comprobantes llegan como lista de dicts con claves snake_case.
    """
    from app.services.sire_service import (
        descargar_rvie, descargar_rce, obtener_credenciales_sunat
    )
    from app.services.pdt621_calculo_service import recalcular_pdt

    credenciales = obtener_credenciales_sunat(empresa)

    rvie = descargar_rvie(empresa.ruc, pdt.ano, pdt.mes, credenciales)
    rce  = descargar_rce(empresa.ruc,  pdt.ano, pdt.mes, credenciales)

    # ── Calcular totales desde los dicts ──────────────────────────────────
    ventas_base  = sum(c.get("base_imponible", 0) for c in rvie["comprobantes"])
    ventas_igv   = sum(c.get("igv", 0)            for c in rvie["comprobantes"])
    ventas_total = sum(c.get("total", 0)           for c in rvie["comprobantes"])

    compras_base  = sum(c.get("base_imponible", 0) for c in rce["comprobantes"])
    compras_igv   = sum(c.get("igv", 0)            for c in rce["comprobantes"])
    compras_total = sum(c.get("total", 0)           for c in rce["comprobantes"])

    # ── Guardar detalle de ventas ─────────────────────────────────────────
    from app.models.models import PDT621Detalle
    # Limpiar detalles anteriores
    db.query(PDT621Detalle).filter(PDT621Detalle.pdt621_id == pdt.id).delete()

    for c in rvie["comprobantes"]:
        detalle = PDT621Detalle(
            pdt621_id         = pdt.id,
            tipo_registro     = "VENTA",
            tipo_comprobante  = c.get("tipo_cp", ""),
            serie             = c.get("serie", ""),
            numero            = c.get("numero", ""),
            fecha_emision     = c.get("fecha_emision", ""),
            ruc_cliente       = c.get("num_doc_cliente", ""),
            razon_social      = c.get("razon_social", ""),
            base_imponible    = c.get("base_imponible", 0),
            igv               = c.get("igv", 0),
            total             = c.get("total", 0),
        )
        db.add(detalle)

    for c in rce["comprobantes"]:
        detalle = PDT621Detalle(
            pdt621_id         = pdt.id,
            tipo_registro     = "COMPRA",
            tipo_comprobante  = c.get("tipo_cp", ""),
            serie             = c.get("serie", ""),
            numero            = c.get("numero", ""),
            fecha_emision     = c.get("fecha_emision", ""),
            ruc_cliente       = c.get("num_doc_proveedor", ""),
            razon_social      = c.get("razon_social", ""),
            base_imponible    = c.get("base_imponible", 0),
            igv               = c.get("igv", 0),
            total             = c.get("total", 0),
        )
        db.add(detalle)

    # ── Actualizar cabecera del PDT ───────────────────────────────────────
    pdt.ventas_base_imponible  = float(ventas_base)
    pdt.ventas_igv             = float(ventas_igv)
    pdt.compras_base_imponible = float(compras_base)
    pdt.compras_igv            = float(compras_igv)
    pdt.fuente_datos           = rvie["fuente"]

    db.commit()
    db.refresh(pdt)

    # Recalcular impuestos con los nuevos totales
    recalcular_pdt(db, pdt)

    return {
        "ok": True,
        "fuente": rvie["fuente"],
        "ventas": {
            "cantidad": rvie["cantidad"],
            "base_imponible": float(ventas_base),
            "igv": float(ventas_igv),
            "total": float(ventas_total),
        },
        "compras": {
            "cantidad": rce["cantidad"],
            "base_imponible": float(compras_base),
            "igv": float(compras_igv),
            "total": float(compras_total),
        },
    }

'@

# Reemplazar la función importar_desde_sire con regex multilinea
# Buscar el patrón "def importar_desde_sire(...):...hasta la próxima def o fin de archivo"
$pattern = '(?s)(def importar_desde_sire\b.*?)(?=\ndef |\Z)'
if ($pdt621Content -match 'def importar_desde_sire') {
    # Reemplazar usando un enfoque más seguro: split por la función
    $lines = Get-Content $pdt621Path
    $startLine = -1
    $endLine = $lines.Count

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^def importar_desde_sire') {
            $startLine = $i
        }
        if ($startLine -ge 0 -and $i -gt $startLine -and $lines[$i] -match '^def ') {
            $endLine = $i
            break
        }
    }

    if ($startLine -ge 0) {
        $before = $lines[0..($startLine-1)] -join "`n"
        $after  = if ($endLine -lt $lines.Count) { $lines[$endLine..($lines.Count-1)] -join "`n" } else { "" }
        $newContent = $before + "`n" + $nuevaFuncion + "`n" + $after
        Set-Content $pdt621Path $newContent -Encoding UTF8
        Write-Host "  [OK] pdt621_service.py — importar_desde_sire reescrita con dict access" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] No se encontro importar_desde_sire - agregando al final" -ForegroundColor Yellow
        Add-Content $pdt621Path $nuevaFuncion -Encoding UTF8
    }
} else {
    Write-Host "  [INFO] importar_desde_sire no existia - agregando" -ForegroundColor Yellow
    Add-Content $pdt621Path $nuevaFuncion -Encoding UTF8
    Write-Host "  [OK] Funcion agregada a pdt621_service.py" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Todos los fixes aplicados ===" -ForegroundColor Green
Write-Host ""
Write-Host "Uvicorn con --reload detecta los cambios automaticamente." -ForegroundColor Yellow
Write-Host "Si no recargas, reinicia manualmente:" -ForegroundColor Yellow
Write-Host "  Ctrl+C → python -m uvicorn app.main:app --reload" -ForegroundColor White
Write-Host ""
Write-Host "Luego prueba en Swagger:" -ForegroundColor Yellow
Write-Host "  POST /api/v1/pdt621/21/importar-sunat" -ForegroundColor White
Write-Host "  Respuesta esperada: { ok: true, fuente: 'MOCK', ventas: {...}, compras: {...} }" -ForegroundColor White
