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

        # SUNAT espera username en formato "RUC USUARIO" CON espacio
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

        Ver Manual SIRE Compras v28.
        """
        self._validar_periodo(periodo)

        # 1. Solicitar descarga (obtener ticket) - Usar POST según manual
        url_descarga = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rce/"
            f"propuesta/web/propuesta/{periodo}/exportapropuesta"
        )
        num_ticket = self._solicitar_ticket(url_descarga, metodo="GET")

        # 2. Esperar a que el ticket este listo
        archivo_info = self._esperar_ticket_rce(num_ticket)

        # 3. Descargar el archivo zip usando método específico para RCE
        nombre_archivo = archivo_info.get("nombre_archivo", "")
        contenido_zip = self._descargar_archivo_rce(num_ticket, nombre_archivo)

        # 4. Parsear el txt dentro del zip
        return self._parsear_rce(contenido_zip, periodo)

    # ── Descarga de propuesta RVIE (ventas) ──────
    def descargar_propuesta_rvie(self, periodo: str) -> dict:
        """
        Descarga la propuesta RVIE (Registro de Ventas Electronico).
        Ver Manual SIRE Ventas v29.
        """
        self._validar_periodo(periodo)

        # Endpoint exacto según manual SIRE Ventas v29
        url_descarga = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rvie/"
            f"propuesta/web/propuesta/{periodo}/exportapropuesta?codTipoArchivo=0"
        )
        num_ticket = self._solicitar_ticket(url_descarga, metodo="GET")
        archivo_info = self._esperar_ticket_rvie(num_ticket)

        # Descargar usando método específico para RVIE
        nombre_archivo = archivo_info.get("nombre_archivo", "")
        contenido_zip = self._descargar_archivo_rvie(num_ticket, nombre_archivo)

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

    def _esperar_ticket_rce(self, num_ticket: str, max_intentos: int = 20, delay_seg: int = 3) -> dict:
        """
        Consulta el estado del ticket para RCE hasta que este 'Terminado'.
        Ver Manual SIRE Compras v28.
        """
        # Endpoint específico para RCE
        url = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rce/"
            f"gestionprocesosmasivos/web/masivo/consultaestadotickets?numTicket={num_ticket}"
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

    def _esperar_ticket_rvie(self, num_ticket: str, max_intentos: int = 20, delay_seg: int = 3) -> dict:
        """
        Consulta el estado del ticket para RVIE hasta que este 'Terminado'.
        Ver Manual SIRE Ventas v29.
        """
        # Endpoint específico para RVIE
        url = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rvie/"
            f"gestionprocesosmasivos/web/masivo/consultaestadotickets?numTicket={num_ticket}"
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
                    f"Ticket RVIE terminado con error: {estado}",
                    codigo="TICKET_ERROR",
                    detalles=item,
                )

        raise SIREError(f"Timeout esperando ticket RVIE {num_ticket}", codigo="TICKET_TIMEOUT")

    def _descargar_archivo_rce(self, num_ticket: str, nombre_archivo: str) -> bytes:
        """
        Descarga el ZIP resultado del ticket para RCE.
        Ver Manual SIRE Compras v28.
        """
        url = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rce/"
            f"gestionprocesosmasivos/web/masivo/archivoreporte?nomArchivoReporte={nombre_archivo}"
            f"&codTipoAchivoReporte=01&numTicket={num_ticket}"
        )

        try:
            with httpx.Client(timeout=self.timeout) as client:
                resp = client.get(url, headers=self._headers_autenticados())
        except httpx.HTTPError as e:
            raise SIREError(f"Error descargando archivo RCE: {e}")

        if resp.status_code != 200:
            raise SIREError(f"Error descargando archivo RCE (HTTP {resp.status_code})")

        return resp.content

    def _descargar_archivo_rvie(self, num_ticket: str, nombre_archivo: str) -> bytes:
        """
        Descarga el ZIP resultado del ticket para RVIE.
        Ver Manual SIRE Ventas v29.
        """
        url = (
            f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rvie/"
            f"gestionprocesosmasivos/web/masivo/archivoreporte?nomArchivoReporte={nombre_archivo}"
            f"&codTipoAchivoReporte=01&numTicket={num_ticket}"
        )

        try:
            with httpx.Client(timeout=self.timeout) as client:
                resp = client.get(url, headers=self._headers_autenticados())
        except httpx.HTTPError as e:
            raise SIREError(f"Error descargando archivo RVIE: {e}")

        if resp.status_code != 200:
            raise SIREError(f"Error descargando archivo RVIE (HTTP {resp.status_code})")

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
