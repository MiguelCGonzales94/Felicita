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
            "client_id":     empresa.sunat_client_id,
            "client_secret": client_secret,
            "usuario_sol":   getattr(empresa, "usuario_sol", "") or "",
            "clave_sol":     clave_sol,
        }
    except Exception as e:
        logger.error(f"Error desencriptando credenciales SUNAT: {e}")
        return None


# RVIE (Ventas)
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
    return {
        "fuente":       "SUNAT_SIRE",
        "periodo":      f"{ano}{str(mes).zfill(2)}",
        "cantidad":     len(comprobantes),
        "comprobantes": comprobantes,
    }


def _mock_rvie(empresa_ruc: str, ano: int, mes: int) -> Dict:
    periodo = f"{ano}{str(mes).zfill(2)}"
    return {
        "fuente":   "MOCK",
        "periodo":  periodo,
        "cantidad": 3,
        "comprobantes": [
            {
                "periodo":           periodo,
                "cuo":               "001",
                "correlativo":       "1",
                "fecha_emision":     f"{ano}-{str(mes).zfill(2)}-05",
                "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-10",
                "tipo_cp":           "01",
                "serie":             "F001",
                "numero":            "000001",
                "tipo_doc_cliente":  "06",
                "num_doc_cliente":   "20987654321",
                "razon_social":      "CLIENTE MOCK S.A.C.",
                "base_imponible":    Decimal("10000.00"),
                "igv":               Decimal("1800.00"),
                "total":             Decimal("11800.00"),
            },
            {
                "periodo":           periodo,
                "cuo":               "002",
                "correlativo":       "2",
                "fecha_emision":     f"{ano}-{str(mes).zfill(2)}-15",
                "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-20",
                "tipo_cp":           "01",
                "serie":             "F001",
                "numero":            "000002",
                "tipo_doc_cliente":  "06",
                "num_doc_cliente":   "20111222333",
                "razon_social":      "OTRA EMPRESA S.A.C.",
                "base_imponible":    Decimal("5000.00"),
                "igv":               Decimal("900.00"),
                "total":             Decimal("5900.00"),
            },
            {
                "periodo":           periodo,
                "cuo":               "003",
                "correlativo":       "3",
                "fecha_emision":     f"{ano}-{str(mes).zfill(2)}-20",
                "fecha_vencimiento": f"{ano}-{str(mes).zfill(2)}-25",
                "tipo_cp":           "03",
                "serie":             "B001",
                "numero":            "000001",
                "tipo_doc_cliente":  "01",
                "num_doc_cliente":   "12345678",
                "razon_social":      "CONSUMIDOR FINAL",
                "base_imponible":    Decimal("2000.00"),
                "igv":               Decimal("360.00"),
                "total":             Decimal("2360.00"),
            },
        ],
    }


# RCE (Compras)
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
    return {
        "fuente":       "SUNAT_SIRE",
        "periodo":      f"{ano}{str(mes).zfill(2)}",
        "cantidad":     len(comprobantes),
        "comprobantes": comprobantes,
    }


def _mock_rce(empresa_ruc: str, ano: int, mes: int) -> Dict:
    periodo = f"{ano}{str(mes).zfill(2)}"
    return {
        "fuente":   "MOCK",
        "periodo":  periodo,
        "cantidad": 2,
        "comprobantes": [
            {
                "periodo":            periodo,
                "cuo":                "001",
                "correlativo":        "1",
                "fecha_emision":      f"{ano}-{str(mes).zfill(2)}-03",
                "fecha_vencimiento":  f"{ano}-{str(mes).zfill(2)}-08",
                "tipo_cp":            "01",
                "serie":              "FF01",
                "numero":             "000001",
                "anio_emision_dua":   "",
                "tipo_doc_proveedor": "06",
                "num_doc_proveedor":  "20555666777",
                "razon_social":       "PROVEEDOR MOCK S.A.C.",
                "base_imponible":     Decimal("8000.00"),
                "igv":                Decimal("1440.00"),
                "total":              Decimal("9440.00"),
                "tipo_cambio":        Decimal("3.60"),
            },
            {
                "periodo":            periodo,
                "cuo":                "002",
                "correlativo":        "2",
                "fecha_emision":      f"{ano}-{str(mes).zfill(2)}-10",
                "fecha_vencimiento":  f"{ano}-{str(mes).zfill(2)}-15",
                "tipo_cp":            "01",
                "serie":              "FF01",
                "numero":             "000002",
                "anio_emision_dua":   "",
                "tipo_doc_proveedor": "06",
                "num_doc_proveedor":  "20999888777",
                "razon_social":       "OTRO PROVEEDOR S.A.",
                "base_imponible":     Decimal("3000.00"),
                "igv":                Decimal("540.00"),
                "total":              Decimal("3540.00"),
                "tipo_cambio":        Decimal("3.60"),
            },
        ],
    }