# ============================================================
#  FELICITA - Cambio 3 Parte A: Backend cliente SIRE real
#  .\cambio3a_sire_backend.ps1
# ============================================================

Write-Host ""
Write-Host "Cambio 3 Parte A - Cliente SIRE real + servicio actualizado" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# Agregar dependencias a requirements.txt
# ============================================================
$reqPath = "backend/requirements.txt"
$reqContent = Get-Content $reqPath -Raw
if ($reqContent -notmatch "httpx") {
    Add-Content $reqPath "httpx==0.27.2"
    Write-Host "  [OK] httpx agregado a requirements.txt" -ForegroundColor Green
} else {
    Write-Host "  [OK] httpx ya presente" -ForegroundColor Green
}

# ============================================================
# services/sire_client.py - Cliente HTTP oficial SUNAT SIRE
# ============================================================
@'
"""
Cliente oficial SUNAT SIRE (Sistema Integrado de Registros Electronicos).

Implementa segun el manual oficial de SUNAT (v22, marzo 2024):
- Autenticacion OAuth2 Password flow
- Descarga de propuesta RCE (compras) y RVIE (ventas)
- Flujo asincrono con tickets

IMPORTANTE: Los servicios SIRE NO deben consumirse desde navegador (CORS bloqueado).
Por eso Felicita hace proxy desde el backend.
"""
import time
import json
import zipfile
import io
from typing import Optional, Dict, List
from datetime import datetime, timedelta
from decimal import Decimal
from pydantic import BaseModel
import httpx


# ── Endpoints oficiales SUNAT ────────────────────────
URL_TOKEN = "https://api-seguridad.sunat.gob.pe/v1/clientessol/{client_id}/oauth2/token/"
URL_BASE_SIRE = "https://api-sire.sunat.gob.pe"
SCOPE = "https://api-sire.sunat.gob.pe"
GRANT_TYPE = "password"


class SIREError(Exception):
    """Error del servicio SIRE."""
    def __init__(self, mensaje: str, codigo: Optional[str] = None, detalles: Optional[dict] = None):
        super().__init__(mensaje)
        self.codigo = codigo
        self.detalles = detalles or {}


class TokenCache:
    """Cache en memoria de tokens. Evita reautenticar cada request."""
    _cache: Dict[str, dict] = {}

    @classmethod
    def obtener(cls, key: str) -> Optional[str]:
        item = cls._cache.get(key)
        if not item:
            return None
        if datetime.utcnow() >= item["expira"]:
            del cls._cache[key]
            return None
        return item["token"]

    @classmethod
    def guardar(cls, key: str, token: str, expires_in: int = 3600):
        cls._cache[key] = {
            "token": token,
            "expira": datetime.utcnow() + timedelta(seconds=expires_in - 60),
        }

    @classmethod
    def limpiar(cls, key: str):
        cls._cache.pop(key, None)


# ── Cliente SIRE ──────────────────────────────────────
class SireClient:
    """
    Cliente SIRE para una empresa especifica.
    Requiere credenciales: client_id, client_secret, ruc, usuario, clave_sol.
    """

    def __init__(
        self,
        client_id: str,
        client_secret: str,
        ruc: str,
        usuario: str,
        clave_sol: str,
        timeout: int = 60,
    ):
        if not all([client_id, client_secret, ruc, clave_sol]):
            raise SIREError("Credenciales incompletas para SIRE")

        self.client_id = client_id.strip()
        self.client_secret = client_secret.strip()
        self.ruc = ruc.strip()
        self.usuario = (usuario or "").strip()
        self.clave_sol = clave_sol.strip()
        self.timeout = timeout

        # Cache key unico por empresa
        self._cache_key = f"{client_id}:{ruc}:{usuario}"

    # ── Autenticacion ─────────────────────────────
    def _autenticar(self) -> str:
        """
        Obtiene un token OAuth2. Usa cache si existe uno vigente.
        Ver Manual SIRE v22, seccion 5.1 Servicio Api Seguridad.
        """
        token_cacheado = TokenCache.obtener(self._cache_key)
        if token_cacheado:
            return token_cacheado

        url = URL_TOKEN.format(client_id=self.client_id)

        # SUNAT espera username en formato "RUC USUARIO" separado por espacio
        username = f"{self.ruc} {self.usuario}" if self.usuario else self.ruc

        data = {
            "grant_type": GRANT_TYPE,
            "scope": SCOPE,
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "username": username,
            "password": self.clave_sol,
        }
        headers = {"Content-Type": "application/x-www-form-urlencoded"}

        try:
            with httpx.Client(timeout=self.timeout) as client:
                resp = client.post(url, data=data, headers=headers)
        except httpx.HTTPError as e:
            raise SIREError(f"Error de conexion con SUNAT: {e}")

        if resp.status_code != 200:
            raise SIREError(
                f"Autenticacion fallida (HTTP {resp.status_code}): {resp.text[:200]}",
                codigo="AUTH_FAILED",
            )

        body = resp.json()
        access_token = body.get("access_token")
        expires_in = body.get("expires_in", 3600)

        if not access_token:
            raise SIREError("SUNAT no devolvio un access_token", detalles=body)

        TokenCache.guardar(self._cache_key, access_token, expires_in)
        return access_token

    def _headers_autenticados(self) -> dict:
        return {
            "Authorization": f"Bearer {self._autenticar()}",
            "Accept": "application/json",
        }

    # ── Descarga de propuesta RCE (compras) ──────
    def descargar_propuesta_rce(self, periodo: str) -> dict:
        """
        Descarga la propuesta RCE de un periodo.
        periodo: formato 'YYYYMM' (ej: '202603')

        Proceso:
        1. POST /descargarpropuesta -> numTicket
        2. GET /consultarestadoticket -> estado y nombreArchivo
        3. GET /descargararchivo -> ZIP con .txt dentro
        4. Parsea el .txt a estructura

        Ver Manual SIRE Compras v22, seccion 5.34 y 5.32.
        """
        self._validar_periodo(periodo)

        # 1. Solicitar descarga (obtener ticket)
        url_descarga = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rce/"
            f"propuesta/web/propuesta/{periodo}/exportapropuesta"
        )
        num_ticket = self._solicitar_ticket(url_descarga, metodo="GET")

        # 2. Esperar a que el ticket este listo
        archivo_info = self._esperar_ticket(num_ticket)

        # 3. Descargar el archivo zip
        contenido_zip = self._descargar_archivo_ticket(num_ticket, archivo_info)

        # 4. Parsear el txt dentro del zip
        return self._parsear_rce(contenido_zip, periodo)

    # ── Descarga de propuesta RVIE (ventas) ──────
    def descargar_propuesta_rvie(self, periodo: str) -> dict:
        """
        Descarga la propuesta RVIE (Registro de Ventas Electronico).
        """
        self._validar_periodo(periodo)

        url_descarga = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rvie/"
            f"propuesta/web/propuesta/{periodo}/exportapropuesta"
        )
        num_ticket = self._solicitar_ticket(url_descarga, metodo="GET")
        archivo_info = self._esperar_ticket(num_ticket)
        contenido_zip = self._descargar_archivo_ticket(num_ticket, archivo_info)

        return self._parsear_rvie(contenido_zip, periodo)

    # ── Helpers internos ─────────────────────────
    def _validar_periodo(self, periodo: str):
        if not periodo or len(periodo) != 6 or not periodo.isdigit():
            raise SIREError(f"Periodo invalido: {periodo}. Debe ser YYYYMM")
        ano = int(periodo[:4])
        mes = int(periodo[4:])
        if mes < 1 or mes > 12:
            raise SIREError(f"Mes invalido: {mes}")
        if ano < 2020:
            raise SIREError(f"Ano invalido: {ano}")

    def _solicitar_ticket(self, url: str, metodo: str = "GET", data: dict = None) -> str:
        """Solicita la generacion de un archivo y retorna el numero de ticket."""
        headers = self._headers_autenticados()
        try:
            with httpx.Client(timeout=self.timeout) as client:
                if metodo == "POST":
                    resp = client.post(url, headers=headers, json=data)
                else:
                    resp = client.get(url, headers=headers)
        except httpx.HTTPError as e:
            raise SIREError(f"Error solicitando ticket: {e}")

        if resp.status_code == 401:
            TokenCache.limpiar(self._cache_key)
            raise SIREError("Token expirado o invalido", codigo="TOKEN_EXPIRED")

        if resp.status_code not in (200, 201):
            raise SIREError(
                f"Error al solicitar ticket (HTTP {resp.status_code}): {resp.text[:200]}"
            )

        body = resp.json()
        num_ticket = body.get("numTicket") or body.get("numticket")
        if not num_ticket:
            raise SIREError("No se recibio numTicket", detalles=body)
        return num_ticket

    def _esperar_ticket(self, num_ticket: str, max_intentos: int = 20, delay_seg: int = 3) -> dict:
        """
        Consulta el estado del ticket hasta que este 'Terminado'.
        Ver Manual SIRE Compras v22, seccion 5.31.
        """
        url = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rvierce/gestionprocesosmasivos/"
            f"web/masivo/consultaestadotickets?numTicket={num_ticket}"
        )

        for intento in range(max_intentos):
            time.sleep(delay_seg)
            try:
                with httpx.Client(timeout=self.timeout) as client:
                    resp = client.get(url, headers=self._headers_autenticados())
            except httpx.HTTPError as e:
                if intento == max_intentos - 1:
                    raise SIREError(f"Error consultando ticket: {e}")
                continue

            if resp.status_code != 200:
                continue

            body = resp.json()
            registros = body.get("registros") or body.get("data") or []
            if not registros:
                continue

            item = registros[0] if isinstance(registros, list) else registros
            estado = (item.get("desEstadoProceso") or item.get("estado") or "").upper()

            if "TERMINADO" in estado or "TERMINADA" in estado:
                archivo_info = (item.get("archivoReporte") or [{}])[0] if item.get("archivoReporte") else item
                return {
                    "nombre_archivo": archivo_info.get("nomArchivoReporte") or item.get("nomArchivoReporte"),
                    "cod_tipo_archivo": archivo_info.get("codTipoAchivoReporte") or "01",
                    "ticket": num_ticket,
                }

            if "ERROR" in estado or "RECHAZADO" in estado:
                raise SIREError(
                    f"Ticket terminado con error: {estado}",
                    codigo="TICKET_ERROR",
                    detalles=item,
                )

        raise SIREError(f"Timeout esperando ticket {num_ticket}", codigo="TICKET_TIMEOUT")

    def _descargar_archivo_ticket(self, num_ticket: str, archivo_info: dict) -> bytes:
        """
        Descarga el ZIP resultado del ticket.
        Ver Manual SIRE Compras v22, seccion 5.32.
        """
        nombre_archivo = archivo_info.get("nombre_archivo")
        cod_tipo = archivo_info.get("cod_tipo_archivo", "01")

        url = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rvierce/gestionprocesosmasivos/"
            f"web/masivo/archivoreporte?nomArchivoReporte={nombre_archivo}"
            f"&codTipoAchivoReporte={cod_tipo}&numTicket={num_ticket}"
        )

        try:
            with httpx.Client(timeout=self.timeout) as client:
                resp = client.get(url, headers=self._headers_autenticados())
        except httpx.HTTPError as e:
            raise SIREError(f"Error descargando archivo: {e}")

        if resp.status_code != 200:
            raise SIREError(f"Error descargando archivo (HTTP {resp.status_code})")

        return resp.content

    def _parsear_rce(self, contenido_zip: bytes, periodo: str) -> dict:
        """
        Parsea el ZIP de RCE. El archivo .txt interno tiene columnas pipe-separated
        segun estructura oficial SUNAT.
        """
        comprobantes = []
        try:
            with zipfile.ZipFile(io.BytesIO(contenido_zip)) as z:
                for nombre in z.namelist():
                    if nombre.lower().endswith(".txt"):
                        with z.open(nombre) as f:
                            contenido = f.read().decode("latin-1")
                            comprobantes = self._parsear_txt_rce(contenido)
                            break
        except zipfile.BadZipFile:
            # A veces SUNAT devuelve el txt directamente
            try:
                contenido = contenido_zip.decode("latin-1")
                comprobantes = self._parsear_txt_rce(contenido)
            except Exception as e:
                raise SIREError(f"Archivo invalido: {e}")

        return self._resumir_compras(comprobantes, periodo)

    def _parsear_rvie(self, contenido_zip: bytes, periodo: str) -> dict:
        """Parsea el ZIP de RVIE."""
        comprobantes = []
        try:
            with zipfile.ZipFile(io.BytesIO(contenido_zip)) as z:
                for nombre in z.namelist():
                    if nombre.lower().endswith(".txt"):
                        with z.open(nombre) as f:
                            contenido = f.read().decode("latin-1")
                            comprobantes = self._parsear_txt_rvie(contenido)
                            break
        except zipfile.BadZipFile:
            try:
                contenido = contenido_zip.decode("latin-1")
                comprobantes = self._parsear_txt_rvie(contenido)
            except Exception as e:
                raise SIREError(f"Archivo invalido: {e}")

        return self._resumir_ventas(comprobantes, periodo)

    def _parsear_txt_rce(self, contenido: str) -> List[dict]:
        """
        Parsea el archivo TXT de RCE (formato pipe-separated SUNAT).
        Las columnas principales son:
        0:Periodo 1:CUO 2:CorrelativoCUO 3:FechaEmision 4:FechaVencimiento
        5:TipoCP 6:SerieCP 7:AnoCP 8:NroCP 9:NroFinalCP
        10:TipoDocIdentidad 11:NroDocIdentidad 12:RazonSocial
        13:BaseImponible 14:IGV 15:BaseNoGravada ... (columnas 13-34 son montos)
        """
        comprobantes = []
        for linea in contenido.strip().split("\n"):
            if not linea.strip() or linea.startswith("#"):
                continue
            campos = linea.split("|")
            if len(campos) < 15:
                continue
            try:
                comp = {
                    "periodo": campos[0],
                    "fecha_emision": campos[3] if len(campos) > 3 else "",
                    "tipo_comprobante": campos[5] if len(campos) > 5 else "",
                    "serie": campos[6] if len(campos) > 6 else "",
                    "numero": campos[8] if len(campos) > 8 else "",
                    "ruc_contraparte": campos[11] if len(campos) > 11 else "",
                    "nombre_contraparte": campos[12] if len(campos) > 12 else "",
                    "base_gravada": self._to_decimal(campos[13] if len(campos) > 13 else "0"),
                    "igv": self._to_decimal(campos[14] if len(campos) > 14 else "0"),
                    "base_no_gravada": self._to_decimal(campos[15] if len(campos) > 15 else "0"),
                    "total": Decimal("0"),
                }
                comp["total"] = comp["base_gravada"] + comp["igv"] + comp["base_no_gravada"]
                comprobantes.append(comp)
            except (ValueError, IndexError):
                continue
        return comprobantes

    def _parsear_txt_rvie(self, contenido: str) -> List[dict]:
        """Parsea el TXT de RVIE (estructura similar al RCE pero para ventas)."""
        comprobantes = []
        for linea in contenido.strip().split("\n"):
            if not linea.strip() or linea.startswith("#"):
                continue
            campos = linea.split("|")
            if len(campos) < 15:
                continue
            try:
                comp = {
                    "periodo": campos[0],
                    "fecha_emision": campos[3] if len(campos) > 3 else "",
                    "tipo_comprobante": campos[5] if len(campos) > 5 else "",
                    "serie": campos[6] if len(campos) > 6 else "",
                    "numero": campos[8] if len(campos) > 8 else "",
                    "ruc_contraparte": campos[11] if len(campos) > 11 else "",
                    "nombre_contraparte": campos[12] if len(campos) > 12 else "",
                    "base_gravada": self._to_decimal(campos[13] if len(campos) > 13 else "0"),
                    "igv": self._to_decimal(campos[14] if len(campos) > 14 else "0"),
                    "base_no_gravada": self._to_decimal(campos[15] if len(campos) > 15 else "0"),
                    "exportacion": self._to_decimal(campos[16] if len(campos) > 16 else "0"),
                    "total": Decimal("0"),
                }
                comp["total"] = comp["base_gravada"] + comp["igv"] + comp["base_no_gravada"] + comp["exportacion"]
                comprobantes.append(comp)
            except (ValueError, IndexError):
                continue
        return comprobantes

    def _to_decimal(self, valor: str) -> Decimal:
        """Convierte string a Decimal manejando formatos SUNAT."""
        if not valor or not valor.strip():
            return Decimal("0")
        try:
            return Decimal(valor.strip().replace(",", ""))
        except Exception:
            return Decimal("0")

    def _resumir_compras(self, comprobantes: List[dict], periodo: str) -> dict:
        total_gravadas = sum(c["base_gravada"] for c in comprobantes)
        total_no_gravadas = sum(c["base_no_gravada"] for c in comprobantes)
        total_igv = sum(c["igv"] for c in comprobantes)
        total_general = sum(c["total"] for c in comprobantes)

        return {
            "periodo_ano": int(periodo[:4]),
            "periodo_mes": int(periodo[4:]),
            "total_comprobantes": len(comprobantes),
            "total_compras_gravadas": float(total_gravadas),
            "total_compras_no_gravadas": float(total_no_gravadas),
            "total_igv_credito": float(total_igv),
            "total_general": float(total_general),
            "comprobantes": [self._comprobante_to_dict(c) for c in comprobantes],
            "fuente": "SUNAT_SIRE",
        }

    def _resumir_ventas(self, comprobantes: List[dict], periodo: str) -> dict:
        total_gravadas = sum(c["base_gravada"] for c in comprobantes)
        total_no_gravadas = sum(c["base_no_gravada"] for c in comprobantes)
        total_exportaciones = sum(c.get("exportacion", Decimal("0")) for c in comprobantes)
        total_igv = sum(c["igv"] for c in comprobantes)
        total_general = sum(c["total"] for c in comprobantes)

        return {
            "periodo_ano": int(periodo[:4]),
            "periodo_mes": int(periodo[4:]),
            "total_comprobantes": len(comprobantes),
            "total_ventas_gravadas": float(total_gravadas),
            "total_ventas_no_gravadas": float(total_no_gravadas),
            "total_exportaciones": float(total_exportaciones),
            "total_ventas_exoneradas": 0.0,
            "total_igv_debito": float(total_igv),
            "total_general": float(total_general),
            "comprobantes": [self._comprobante_to_dict(c) for c in comprobantes],
            "fuente": "SUNAT_SIRE",
        }

    def _comprobante_to_dict(self, c: dict) -> dict:
        return {
            "tipo_comprobante": c.get("tipo_comprobante", ""),
            "serie": c.get("serie", ""),
            "numero": c.get("numero", ""),
            "fecha_emision": c.get("fecha_emision", ""),
            "ruc_contraparte": c.get("ruc_contraparte", ""),
            "nombre_contraparte": c.get("nombre_contraparte", ""),
            "base_gravada": float(c.get("base_gravada", 0)),
            "igv": float(c.get("igv", 0)),
            "base_no_gravada": float(c.get("base_no_gravada", 0)),
            "exportacion": float(c.get("exportacion", 0)),
            "total": float(c.get("total", 0)),
        }
'@ | Set-Content "backend/app/services/sire_client.py"
Write-Host "  [OK] services/sire_client.py (cliente SIRE real)" -ForegroundColor Green

# ============================================================
# services/sire_service.py - Wrapper que intenta real, cae a mock
# ============================================================
@'
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
'@ | Set-Content "backend/app/services/sire_service.py"
Write-Host "  [OK] services/sire_service.py (con fallback real/mock)" -ForegroundColor Green

# ============================================================
# services/pdt621_service.py - usar credenciales de la empresa
# ============================================================
@'
"""
Servicio de PDT 621 - Logica de negocio.
Ahora usa credenciales reales de la empresa para SIRE.
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException
from datetime import date
from decimal import Decimal

from app.models.models import PDT621, Empresa, CronogramaSunat
from app.services.sire_service import descargar_rvie, descargar_rce
from app.services.pdt621_calculo_service import (
    calcular_pdt621, InputsCalculoIGV, InputsCalculoRenta
)
from app.services.empresa_service import obtener_credenciales_sunat


TRANSICIONES_ESTADO = {
    "DRAFT":     ["GENERATED", "DRAFT"],
    "GENERATED": ["SUBMITTED", "DRAFT"],
    "SUBMITTED": ["ACCEPTED", "REJECTED"],
    "REJECTED":  ["DRAFT"],
    "ACCEPTED":  [],
}


def obtener_fecha_vencimiento(db: Session, empresa_ruc: str, ano: int, mes: int) -> date:
    """Fecha de vencimiento segun cronograma SUNAT. Fallback: dia 15 del mes siguiente."""
    ultimo_digito = empresa_ruc[-1]
    mes_venc = mes + 1
    ano_venc = ano
    if mes_venc > 12:
        mes_venc = 1
        ano_venc += 1

    cronograma = db.query(CronogramaSunat).filter_by(
        ano=ano_venc, mes=mes_venc, ultimo_digito_ruc=ultimo_digito
    ).first()
    if cronograma and cronograma.fecha_pdt621:
        return cronograma.fecha_pdt621
    return date(ano_venc, mes_venc, 15)


def obtener_o_crear_pdt(db: Session, empresa: Empresa, ano: int, mes: int) -> PDT621:
    pdt = db.query(PDT621).filter_by(
        empresa_id=empresa.id, ano=ano, mes=mes
    ).first()
    if pdt:
        return pdt

    fecha_venc = obtener_fecha_vencimiento(db, empresa.ruc, ano, mes)
    pdt = PDT621(
        empresa_id=empresa.id,
        ano=ano, mes=mes,
        fecha_vencimiento=fecha_venc,
        estado="DRAFT",
    )
    db.add(pdt)
    db.commit()
    db.refresh(pdt)
    return pdt


def importar_desde_sire(db: Session, pdt: PDT621, empresa: Empresa) -> dict:
    """Descarga RVIE/RCE de SUNAT (real o mock) y actualiza el PDT."""
    # Obtener credenciales de la empresa (desencriptadas)
    credenciales = obtener_credenciales_sunat(empresa)

    # Descargar (intenta real, cae a mock si no hay creds)
    rvie = descargar_rvie(empresa.ruc, pdt.ano, pdt.mes, credenciales)
    rce = descargar_rce(empresa.ruc, pdt.ano, pdt.mes, credenciales)

    # Actualizar campos del PDT
    pdt.c100_ventas_gravadas = rvie.total_ventas_gravadas
    pdt.c104_ventas_no_gravadas = rvie.total_ventas_no_gravadas
    pdt.c105_exportaciones = rvie.total_exportaciones
    pdt.c140_subtotal_ventas = (
        rvie.total_ventas_gravadas + rvie.total_ventas_no_gravadas + rvie.total_exportaciones
    )
    pdt.c140igv_igv_debito = rvie.total_igv_debito
    pdt.c120_compras_gravadas = rce.total_compras_gravadas
    pdt.c180_igv_credito = rce.total_igv_credito
    pdt.c301_ingresos_netos = rvie.total_ventas_gravadas + rvie.total_exportaciones

    db.commit()
    db.refresh(pdt)

    recalcular_pdt(db, pdt, empresa)

    return {
        "fuente": rvie.fuente,  # "SUNAT_SIRE" o "MOCK"
        "ventas": {
            "total_comprobantes": rvie.total_comprobantes,
            "ventas_gravadas": float(rvie.total_ventas_gravadas),
            "ventas_no_gravadas": float(rvie.total_ventas_no_gravadas),
            "exportaciones": float(rvie.total_exportaciones),
            "igv_debito": float(rvie.total_igv_debito),
            "comprobantes": [c.model_dump(mode="json") for c in rvie.comprobantes[:5]],  # preview
        },
        "compras": {
            "total_comprobantes": rce.total_comprobantes,
            "compras_gravadas": float(rce.total_compras_gravadas),
            "igv_credito": float(rce.total_igv_credito),
            "comprobantes": [c.model_dump(mode="json") for c in rce.comprobantes[:5]],
        },
    }


def obtener_saldo_favor_mes_anterior(db: Session, empresa_id: int, ano: int, mes: int) -> Decimal:
    """Sugiere saldo a favor del mes anterior."""
    mes_ant = mes - 1
    ano_ant = ano
    if mes_ant == 0:
        mes_ant = 12
        ano_ant -= 1

    pdt_anterior = db.query(PDT621).filter_by(
        empresa_id=empresa_id, ano=ano_ant, mes=mes_ant
    ).first()
    if not pdt_anterior:
        return Decimal("0")

    debito = pdt_anterior.c140igv_igv_debito or Decimal("0")
    credito = pdt_anterior.c180_igv_credito or Decimal("0")
    diferencia = credito - debito
    return max(Decimal("0"), diferencia)


def recalcular_pdt(db: Session, pdt: PDT621, empresa: Empresa) -> PDT621:
    """Recalcula todos los totales."""
    igv_inputs = InputsCalculoIGV(
        ventas_gravadas=pdt.c100_ventas_gravadas or Decimal("0"),
        ventas_no_gravadas=pdt.c104_ventas_no_gravadas or Decimal("0"),
        exportaciones=pdt.c105_exportaciones or Decimal("0"),
        compras_gravadas=pdt.c120_compras_gravadas or Decimal("0"),
        saldo_favor_anterior=Decimal("0"),
        percepciones_periodo=Decimal("0"),
        retenciones_periodo=pdt.c310_retenciones or Decimal("0"),
    )
    renta_inputs = InputsCalculoRenta(
        regimen=empresa.regimen_tributario,
        ingresos_netos=pdt.c301_ingresos_netos or Decimal("0"),
        coeficiente_declarado=empresa.tasa_renta_pc / Decimal("100") if empresa.tasa_renta_pc else None,
        pagos_anticipados=pdt.c311_pagos_anticipados or Decimal("0"),
    )
    resultado = calcular_pdt621(igv_inputs, renta_inputs)

    pdt.c184_igv_a_pagar = resultado.igv.igv_a_pagar
    pdt.c309_pago_a_cuenta_renta = resultado.renta.renta_bruta
    pdt.c318_renta_a_pagar = resultado.renta.renta_a_pagar
    pdt.total_a_pagar = resultado.total_a_pagar

    db.commit()
    db.refresh(pdt)
    return pdt


def aplicar_ajustes(db: Session, pdt: PDT621, empresa: Empresa, ajustes: dict) -> dict:
    """Aplica ajustes y retorna resultado completo."""
    if "retenciones_periodo" in ajustes:
        pdt.c310_retenciones = Decimal(str(ajustes["retenciones_periodo"]))
    if "pagos_anticipados" in ajustes:
        pdt.c311_pagos_anticipados = Decimal(str(ajustes["pagos_anticipados"]))
    db.commit()

    igv_inputs = InputsCalculoIGV(
        ventas_gravadas=pdt.c100_ventas_gravadas or Decimal("0"),
        ventas_no_gravadas=pdt.c104_ventas_no_gravadas or Decimal("0"),
        exportaciones=pdt.c105_exportaciones or Decimal("0"),
        compras_gravadas=pdt.c120_compras_gravadas or Decimal("0"),
        saldo_favor_anterior=Decimal(str(ajustes.get("saldo_favor_anterior", 0))),
        percepciones_periodo=Decimal(str(ajustes.get("percepciones_periodo", 0))),
        percepciones_arrastre=Decimal(str(ajustes.get("percepciones_arrastre", 0))),
        retenciones_periodo=Decimal(str(ajustes.get("retenciones_periodo", 0))),
        retenciones_arrastre=Decimal(str(ajustes.get("retenciones_arrastre", 0))),
    )
    renta_inputs = InputsCalculoRenta(
        regimen=empresa.regimen_tributario,
        ingresos_netos=pdt.c301_ingresos_netos or Decimal("0"),
        coeficiente_declarado=empresa.tasa_renta_pc / Decimal("100") if empresa.tasa_renta_pc else None,
        pagos_anticipados=Decimal(str(ajustes.get("pagos_anticipados", 0))),
        retenciones_renta=Decimal(str(ajustes.get("retenciones_renta", 0))),
        saldo_favor_renta_anterior=Decimal(str(ajustes.get("saldo_favor_renta_anterior", 0))),
        categoria_nrus=ajustes.get("categoria_nrus"),
        ingresos_acumulados_ano=Decimal(str(ajustes.get("ingresos_acumulados_ano", 0))),
    )
    resultado = calcular_pdt621(igv_inputs, renta_inputs)

    pdt.c184_igv_a_pagar = resultado.igv.igv_a_pagar
    pdt.c309_pago_a_cuenta_renta = resultado.renta.renta_bruta
    pdt.c318_renta_a_pagar = resultado.renta.renta_a_pagar
    pdt.total_a_pagar = resultado.total_a_pagar
    db.commit()
    db.refresh(pdt)

    return {
        "igv": resultado.igv.model_dump(mode="json"),
        "renta": resultado.renta.model_dump(mode="json"),
        "total_a_pagar": float(resultado.total_a_pagar),
    }


def cambiar_estado(db: Session, pdt: PDT621, nuevo_estado: str,
                   numero_operacion: str = None, mensaje: str = None) -> PDT621:
    estado_actual = pdt.estado
    permitidos = TRANSICIONES_ESTADO.get(estado_actual, [])
    if nuevo_estado not in permitidos:
        raise HTTPException(
            status_code=400,
            detail=f"No se puede pasar de {estado_actual} a {nuevo_estado}. Permitidos: {permitidos}"
        )

    pdt.estado = nuevo_estado
    if nuevo_estado == "SUBMITTED":
        from datetime import datetime
        pdt.fecha_presentacion_sunat = datetime.utcnow()
        if numero_operacion:
            pdt.numero_operacion = numero_operacion
    if nuevo_estado == "REJECTED" and mensaje:
        pdt.mensaje_error_sunat = mensaje

    db.commit()
    db.refresh(pdt)
    return pdt
'@ | Set-Content "backend/app/services/pdt621_service.py"
Write-Host "  [OK] services/pdt621_service.py (con credenciales reales)" -ForegroundColor Green

# ============================================================
# routers/pdt621.py - probar conexion SUNAT + endpoint por periodo
# ============================================================
@'
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc, case
from typing import Optional
from datetime import date

from app.database import get_db
from app.models.models import Usuario, Empresa, PDT621
from app.schemas.pdt621_schema import (
    PDT621Response, PDT621Generar, PDT621Ajustes, PDT621CambioEstado
)
from app.dependencies.auth_dependency import require_contador
from app.services.pdt621_service import (
    obtener_o_crear_pdt, importar_desde_sire, aplicar_ajustes,
    cambiar_estado, recalcular_pdt, obtener_saldo_favor_mes_anterior
)
from app.services.empresa_service import obtener_credenciales_sunat
from app.services.sire_client import SireClient, SIREError

router = APIRouter(prefix="/api/v1", tags=["PDT 621"])


def get_empresa_or_404(empresa_id: int, contador: Usuario, db: Session) -> Empresa:
    emp = db.query(Empresa).filter(
        Empresa.id == empresa_id,
        Empresa.contador_id == contador.id,
    ).first()
    if not emp:
        raise HTTPException(status_code=404, detail="Empresa no encontrada")
    return emp


def get_pdt_or_404(pdt_id: int, contador: Usuario, db: Session):
    pdt = db.query(PDT621).filter(PDT621.id == pdt_id).first()
    if not pdt:
        raise HTTPException(status_code=404, detail="PDT 621 no encontrado")
    empresa = get_empresa_or_404(pdt.empresa_id, contador, db)
    return pdt, empresa


def pdt_list_item(pdt: PDT621, empresa: Empresa) -> dict:
    hoy = date.today()
    dias = (pdt.fecha_vencimiento - hoy).days
    return {
        "id": pdt.id,
        "empresa_id": empresa.id,
        "empresa_nombre": empresa.razon_social,
        "empresa_ruc": empresa.ruc,
        "empresa_color": empresa.color_identificacion,
        "mes": pdt.mes, "ano": pdt.ano,
        "fecha_vencimiento": pdt.fecha_vencimiento,
        "estado": pdt.estado,
        "total_a_pagar": pdt.total_a_pagar or 0,
        "igv_a_pagar": pdt.c184_igv_a_pagar or 0,
        "renta_a_pagar": pdt.c318_renta_a_pagar or 0,
        "nps": pdt.nps,
        "dias_para_vencer": dias,
    }


# ── Listar PDTs (consolidado) ──────────────────────────
@router.get("/pdt621")
def listar_pdts(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
    ano: Optional[int] = Query(None),
    mes: Optional[int] = Query(None),
    estado: Optional[str] = Query(None),
    empresa_id: Optional[int] = Query(None),
):
    query = db.query(PDT621, Empresa).join(Empresa, PDT621.empresa_id == Empresa.id).filter(
        Empresa.contador_id == current_user.id,
    )
    if ano: query = query.filter(PDT621.ano == ano)
    if mes: query = query.filter(PDT621.mes == mes)
    if estado: query = query.filter(PDT621.estado == estado)
    if empresa_id: query = query.filter(PDT621.empresa_id == empresa_id)

    orden_estado = case(
        (PDT621.estado == "DRAFT", 0),
        (PDT621.estado == "GENERATED", 1),
        (PDT621.estado == "REJECTED", 2),
        (PDT621.estado == "SUBMITTED", 3),
        (PDT621.estado == "ACCEPTED", 4),
        else_=5,
    )
    query = query.order_by(orden_estado, PDT621.fecha_vencimiento)
    results = query.all()
    items = [pdt_list_item(pdt, emp) for pdt, emp in results]
    return {"total": len(items), "pdts": items}


# ── Listar PDTs de una empresa ─────────────────────────
@router.get("/empresas/{empresa_id}/pdt621")
def listar_pdts_empresa(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    pdts = db.query(PDT621).filter_by(empresa_id=empresa.id).order_by(
        desc(PDT621.ano), desc(PDT621.mes)
    ).all()
    return {
        "empresa": {
            "id": empresa.id, "ruc": empresa.ruc,
            "razon_social": empresa.razon_social,
        },
        "total": len(pdts),
        "pdts": [pdt_list_item(p, empresa) for p in pdts],
    }


# ── Buscar PDT por periodo ─────────────────────────────
@router.get("/empresas/{empresa_id}/pdt621/periodo/{ano}/{mes}", response_model=PDT621Response)
def obtener_pdt_por_periodo(
    empresa_id: int, ano: int, mes: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Obtiene o crea el PDT de un periodo especifico."""
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    if mes < 1 or mes > 12:
        raise HTTPException(status_code=400, detail="Mes invalido")
    pdt = obtener_o_crear_pdt(db, empresa, ano, mes)
    return pdt


# ── Generar PDT ────────────────────────────────────────
@router.post("/empresas/{empresa_id}/pdt621/generar", response_model=PDT621Response)
def generar_pdt(
    empresa_id: int,
    payload: PDT621Generar,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    if payload.mes < 1 or payload.mes > 12:
        raise HTTPException(status_code=400, detail="Mes invalido")
    pdt = obtener_o_crear_pdt(db, empresa, payload.ano, payload.mes)
    return pdt


# ── Obtener PDT por ID ─────────────────────────────────
@router.get("/pdt621/{pdt_id}", response_model=PDT621Response)
def obtener_pdt(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)
    return pdt


# ── Importar desde SUNAT ───────────────────────────────
@router.post("/pdt621/{pdt_id}/importar-sunat")
def importar_sunat(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Descarga RVIE/RCE de SUNAT (real o mock) y pre-llena el PDT."""
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(status_code=400,
            detail=f"No se puede importar: el PDT esta en estado {pdt.estado}")
    resumen = importar_desde_sire(db, pdt, empresa)
    return resumen


# ── Probar conexion SIRE ───────────────────────────────
@router.post("/empresas/{empresa_id}/sire/probar-conexion")
def probar_conexion_sire(
    empresa_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """
    Prueba la conexion con SUNAT usando las credenciales de la empresa.
    Util para validar credenciales antes de hacer descargas.
    """
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    cred = obtener_credenciales_sunat(empresa)

    if not (cred.get("client_id") and cred.get("client_secret") and cred.get("clave_sol")):
        return {
            "conectado": False,
            "usando_mock": True,
            "mensaje": "No hay credenciales API SUNAT configuradas. Usando modo simulado.",
        }

    try:
        client = SireClient(
            client_id=cred["client_id"],
            client_secret=cred["client_secret"],
            ruc=cred["ruc"],
            usuario=cred.get("usuario", ""),
            clave_sol=cred["clave_sol"],
        )
        # Intenta autenticar (esto valida credenciales)
        client._autenticar()
        return {
            "conectado": True,
            "usando_mock": False,
            "mensaje": "Conexion exitosa con SUNAT SIRE",
        }
    except SIREError as e:
        return {
            "conectado": False,
            "usando_mock": False,
            "mensaje": str(e),
            "codigo": e.codigo,
        }


# ── Sugerir saldo a favor mes anterior ─────────────────
@router.get("/empresas/{empresa_id}/pdt621/saldo-favor/{ano}/{mes}")
def sugerir_saldo_favor(
    empresa_id: int, ano: int, mes: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    empresa = get_empresa_or_404(empresa_id, current_user, db)
    saldo = obtener_saldo_favor_mes_anterior(db, empresa.id, ano, mes)
    return {
        "saldo_sugerido": float(saldo),
        "editable": True,
        "fuente": "PDT 621 del mes anterior" if saldo > 0 else "Sin saldo previo",
    }


# ── Aplicar ajustes ────────────────────────────────────
@router.put("/pdt621/{pdt_id}/ajustes")
def aplicar_ajustes_endpoint(
    pdt_id: int,
    payload: PDT621Ajustes,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(status_code=400, detail=f"No editable: estado {pdt.estado}")
    ajustes = payload.model_dump(exclude_none=True)
    resultado = aplicar_ajustes(db, pdt, empresa, ajustes)
    return resultado


# ── Recalcular ─────────────────────────────────────────
@router.post("/pdt621/{pdt_id}/recalcular", response_model=PDT621Response)
def recalcular_endpoint(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, empresa = get_pdt_or_404(pdt_id, current_user, db)
    return recalcular_pdt(db, pdt, empresa)


# ── Cambiar estado ─────────────────────────────────────
@router.post("/pdt621/{pdt_id}/cambiar-estado", response_model=PDT621Response)
def cambiar_estado_endpoint(
    pdt_id: int,
    payload: PDT621CambioEstado,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)
    pdt = cambiar_estado(db, pdt, payload.nuevo_estado, payload.numero_operacion, payload.mensaje)
    return pdt


# ── Eliminar borrador ──────────────────────────────────
@router.delete("/pdt621/{pdt_id}", status_code=204)
def eliminar_pdt(
    pdt_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    pdt, _ = get_pdt_or_404(pdt_id, current_user, db)
    if pdt.estado != "DRAFT":
        raise HTTPException(status_code=400,
            detail=f"Solo se pueden eliminar borradores. Estado actual: {pdt.estado}")
    db.delete(pdt)
    db.commit()
'@ | Set-Content "backend/app/routers/pdt621.py"
Write-Host "  [OK] routers/pdt621.py (con probar-conexion SIRE)" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Parte A aplicada!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "PASOS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Instalar httpx:" -ForegroundColor White
Write-Host "     cd backend" -ForegroundColor Gray
Write-Host "     venv\Scripts\activate" -ForegroundColor Gray
Write-Host "     pip install httpx==0.27.2" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Reiniciar uvicorn (Ctrl+C y volver a correrlo)" -ForegroundColor White
Write-Host ""
Write-Host "  3. Probar en http://localhost:8000/docs :" -ForegroundColor White
Write-Host "     POST /empresas/{id}/sire/probar-conexion" -ForegroundColor Gray
Write-Host "         (valida credenciales API SUNAT)" -ForegroundColor Gray
Write-Host "     POST /pdt621/{id}/importar-sunat" -ForegroundColor Gray
Write-Host "         (descarga real o mock segun credenciales)" -ForegroundColor Gray
Write-Host ""
Write-Host "Luego te paso la Parte B: frontend modulo Declaraciones" -ForegroundColor Yellow
Write-Host ""
