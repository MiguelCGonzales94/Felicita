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
    """Descarga el Registro de Ventas Electronico."""
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
        cred.get("client_id")
        and cred.get("client_secret")
        and cred.get("clave_sol")
    )


# ── Descarga real via SireClient ─────────────────────
def _descargar_rvie_real(ruc: str, ano: int, mes: int, cred: dict) -> ResumenRVIE:
    client = SireClient(
        client_id=cred["client_id"],
        client_secret=cred["client_secret"],
        ruc=cred["ruc"],
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


# ── MOCKS REALISTAS (basados en casos reales de contabilidad peruana) ──
def _generar_rvie_mock(ruc: str, ano: int, mes: int) -> ResumenRVIE:
    """
    Genera ~15 comprobantes de venta realistas. Mezcla facturas y boletas.
    Semilla determinista para que el mismo periodo devuelva los mismos datos.
    """
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

    # Configuracion: entre 12 y 18 ventas, mayoria facturas
    num_comprobantes = random.randint(12, 18)
    comprobantes = []

    # Montos tipicos de una PYME peruana (entre S/ 200 y S/ 8000 por comprobante)
    for i in range(num_comprobantes):
        c = random.choice(clientes)
        es_factura = random.random() < 0.75  # 75% facturas, 25% boletas
        tipo = "01" if es_factura else "03"
        serie_letra = "F" if es_factura else "B"
        serie = f"{serie_letra}{random.randint(1, 5):03d}"

        base = Decimal(random.randint(200, 8000)) + Decimal(random.randint(0, 99)) / Decimal(100)
        base = base.quantize(Decimal("0.01"))
        igv = (base * Decimal("0.18")).quantize(Decimal("0.01"))
        total = base + igv

        dia = random.randint(1, 28)
        comprobantes.append(ComprobanteImportado(
            tipo_comprobante=tipo,
            serie=serie,
            numero=str(1000 + i + random.randint(0, 500)),
            fecha_emision=f"{ano:04d}-{mes:02d}-{dia:02d}",
            ruc_contraparte=c[0],
            nombre_contraparte=c[1],
            base_gravada=base,
            igv=igv,
            total=total,
        ))

    # Ordenar por fecha
    comprobantes.sort(key=lambda x: x.fecha_emision)

    total_g = sum(c.base_gravada for c in comprobantes)
    total_ng = sum(c.base_no_gravada for c in comprobantes)
    total_exp = sum(c.exportacion for c in comprobantes)
    total_igv = sum(c.igv for c in comprobantes)
    total_gral = sum(c.total for c in comprobantes)

    return ResumenRVIE(
        periodo_ano=ano,
        periodo_mes=mes,
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
    """Genera ~20 comprobantes de compra realistas de proveedores tipicos."""
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
        # Las compras suelen ser montos menores y mas repartidos
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
            ruc_contraparte=p[0],
            nombre_contraparte=p[1],
            base_gravada=base,
            igv=igv,
            total=total,
        ))

    comprobantes.sort(key=lambda x: x.fecha_emision)

    total_g = sum(c.base_gravada for c in comprobantes)
    total_ng = sum(c.base_no_gravada for c in comprobantes)
    total_igv = sum(c.igv for c in comprobantes)
    total_gral = sum(c.total for c in comprobantes)

    return ResumenRCE(
        periodo_ano=ano,
        periodo_mes=mes,
        total_comprobantes=len(comprobantes),
        total_compras_gravadas=total_g,
        total_compras_no_gravadas=total_ng,
        total_igv_credito=total_igv,
        total_general=total_gral,
        comprobantes=comprobantes,
        fuente="MOCK",
    )
