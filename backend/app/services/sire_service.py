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

logger = logging.getLogger(__name__)


# ── Schemas ─────────────────────────────────────────
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


# ── API publica ─────────────────────────────────────
def descargar_rvie(empresa_ruc: str, ano: int, mes: int, credenciales: Optional[dict] = None) -> ResumenRVIE:
    """
    Descarga el Registro de Ventas Electronico.

    Args:
        empresa_ruc: RUC de la empresa
        ano, mes: periodo
        credenciales: dict con client_id, client_secret, usuario, clave_sol (opcional)
                      Si no viene, usa mock.
    """
    if credenciales and _tiene_credenciales(credenciales):
        try:
            return _descargar_rvie_real(empresa_ruc, ano, mes, credenciales)
        except SIREError as e:
            logger.warning(f"SIRE real fallo, usando mock: {e}")

    return _generar_rvie_mock(empresa_ruc, ano, mes)


def descargar_rce(empresa_ruc: str, ano: int, mes: int, credenciales: Optional[dict] = None) -> ResumenRCE:
    """Descarga el Registro de Compras Electronico."""
    if credenciales and _tiene_credenciales(credenciales):
        try:
            return _descargar_rce_real(empresa_ruc, ano, mes, credenciales)
        except SIREError as e:
            logger.warning(f"SIRE real fallo, usando mock: {e}")

    return _generar_rce_mock(empresa_ruc, ano, mes)


def _tiene_credenciales(cred: dict) -> bool:
    return bool(
        cred.get("client_id") and
        cred.get("client_secret") and
        cred.get("clave_sol")
    )


def _descargar_rvie_real(ruc: str, ano: int, mes: int, cred: dict) -> ResumenRVIE:
    """Llamada real al SIRE de SUNAT."""
    client = SireClient(
        client_id=cred["client_id"],
        client_secret=cred["client_secret"],
        ruc=cred["ruc"],
        usuario=cred.get("usuario", ""),
        clave_sol=cred["clave_sol"],
    )
    periodo = f"{ano:04d}{mes:02d}"
    data = client.descargar_propuesta_rvie(periodo)

    # Convertir dicts a ComprobanteImportado
    comprobantes = [ComprobanteImportado(**c) for c in data["comprobantes"]]
    return ResumenRVIE(
        periodo_ano=data["periodo_ano"],
        periodo_mes=data["periodo_mes"],
        total_comprobantes=data["total_comprobantes"],
        total_ventas_gravadas=Decimal(str(data["total_ventas_gravadas"])),
        total_ventas_no_gravadas=Decimal(str(data["total_ventas_no_gravadas"])),
        total_exportaciones=Decimal(str(data["total_exportaciones"])),
        total_ventas_exoneradas=Decimal(str(data["total_ventas_exoneradas"])),
        total_igv_debito=Decimal(str(data["total_igv_debito"])),
        total_general=Decimal(str(data["total_general"])),
        comprobantes=comprobantes,
        fuente="SUNAT_SIRE",
    )


def _descargar_rce_real(ruc: str, ano: int, mes: int, cred: dict) -> ResumenRCE:
    """Llamada real al SIRE de SUNAT."""
    client = SireClient(
        client_id=cred["client_id"],
        client_secret=cred["client_secret"],
        ruc=cred["ruc"],
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


# ── MOCKS (para desarrollo) ─────────────────────────
def _generar_rvie_mock(ruc: str, ano: int, mes: int) -> ResumenRVIE:
    random.seed(f"ventas-{ruc}-{ano}-{mes}")
    clientes = [
        ("20100070970", "SAGA FALABELLA S.A."),
        ("20477314832", "HIPERMERCADOS TOTTUS S.A."),
        ("20546798745", "CLIENTE RECURRENTE SAC"),
        ("10456789012", "JUAN PEREZ MENDOZA"),
        ("20987654321", "DISTRIBUIDORA CENTRAL SRL"),
    ]

    num = random.randint(8, 18)
    comprobantes = []
    for i in range(num):
        c = random.choice(clientes)
        base = Decimal(random.randint(500, 15000)).quantize(Decimal("0.01"))
        igv = (base * Decimal("0.18")).quantize(Decimal("0.01"))
        total = base + igv

        comprobantes.append(ComprobanteImportado(
            tipo_comprobante=random.choice(["01", "03"]),
            serie=f"F{random.randint(1, 99):03d}",
            numero=str(random.randint(1000, 9999) + i),
            fecha_emision=f"{ano:04d}-{mes:02d}-{random.randint(1, 28):02d}",
            ruc_contraparte=c[0], nombre_contraparte=c[1],
            base_gravada=base, igv=igv, total=total,
        ))

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
        comprobantes=comprobantes,
        fuente="MOCK",
    )


def _generar_rce_mock(ruc: str, ano: int, mes: int) -> ResumenRCE:
    random.seed(f"compras-{ruc}-{ano}-{mes}")
    proveedores = [
        ("20100047218", "TELEFONICA DEL PERU S.A.A."),
        ("20100030595", "LUZ DEL SUR S.A.A."),
        ("20512869481", "SEDAPAL S.A."),
        ("20100017491", "PLAZA VEA SAC"),
        ("20298910273", "SERVICENTROS DEL PERU SAC"),
        ("20505989327", "IMPORTADORA DE SUMINISTROS SRL"),
    ]

    num = random.randint(5, 12)
    comprobantes = []
    for i in range(num):
        p = random.choice(proveedores)
        base = Decimal(random.randint(100, 8000)).quantize(Decimal("0.01"))
        igv = (base * Decimal("0.18")).quantize(Decimal("0.01"))
        total = base + igv

        comprobantes.append(ComprobanteImportado(
            tipo_comprobante="01",
            serie=f"F{random.randint(1, 99):03d}",
            numero=str(random.randint(10000, 99999) + i),
            fecha_emision=f"{ano:04d}-{mes:02d}-{random.randint(1, 28):02d}",
            ruc_contraparte=p[0], nombre_contraparte=p[1],
            base_gravada=base, igv=igv, total=total,
        ))

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
        comprobantes=comprobantes,
        fuente="MOCK",
    )
