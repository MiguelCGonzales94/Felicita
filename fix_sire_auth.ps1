# ============================================================
#  FELICITA - Fix: Error autenticación SIRE HTTP 400 access_denied
#  .\fix_sire_auth.ps1
#  Ejecutar desde la raíz del proyecto: C:\Users\Miguel\Documents\Proyectos\Felicita\
# ============================================================

Write-Host ""
Write-Host "Fix: Error autenticacion SIRE HTTP 400 access_denied" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "backend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# PASO 1: Mostrar la sección crítica del sire_client.py actual
# ============================================================
Write-Host "=== Verificando sire_client.py actual ===" -ForegroundColor Yellow
$clientPath = "backend\app\services\sire_client.py"
if (Test-Path $clientPath) {
    $content = Get-Content $clientPath -Raw
    # Buscar la construcción del username
    if ($content -match 'username.*ruc.*usuario|ruc.*usuario.*username') {
        Write-Host "  [INFO] Linea de username encontrada - verificar manualmente" -ForegroundColor Yellow
    }
    if ($content -match '"username".*f.*{.*ruc.*}.*{.*usuario.*}"') {
        Write-Host "  [OK] Formato username parece correcto" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Verificar formato del username en _autenticar()" -ForegroundColor Red
    }
} else {
    Write-Host "  [WARN] No se encontro sire_client.py en la ruta esperada" -ForegroundColor Red
}

# ============================================================
# PASO 2: Reescribir sire_client.py con fixes aplicados
# ============================================================
Write-Host ""
Write-Host "=== Aplicando fix al sire_client.py ===" -ForegroundColor Yellow

$sireClientContent = @'
"""
Cliente oficial SUNAT SIRE (Sistema Integrado de Registros Electronicos).

Implementado segun el Manual de Servicios Web API - SIRE Ventas v25 y Compras v22.
Fix aplicado: username debe ser "{RUC} {USUARIO}" con espacio (no concatenado).
              URL del token incluye el client_id como path param.
"""
import time
import json
import zipfile
import io
import logging
from typing import Optional, Dict, List
from datetime import datetime, timedelta
from decimal import Decimal
from pydantic import BaseModel
import httpx

logger = logging.getLogger(__name__)

# ── Endpoints oficiales SUNAT ────────────────────────────────────────────────
# IMPORTANTE: {client_id} es parte de la URL (path param), NO solo del body
URL_TOKEN   = "https://api-seguridad.sunat.gob.pe/v1/clientessol/{client_id}/oauth2/token/"
URL_BASE    = "https://api-sire.sunat.gob.pe"
SCOPE       = "https://api-sire.sunat.gob.pe"
GRANT_TYPE  = "password"


class SIREError(Exception):
    def __init__(self, mensaje: str, codigo: Optional[str] = None, detalles: Optional[dict] = None):
        super().__init__(mensaje)
        self.codigo = codigo
        self.detalles = detalles or {}


class TokenCache:
    """Cache en memoria. Evita reautenticar en cada request (tokens duran ~1h)."""
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


class SireClient:
    """
    Cliente SIRE para una empresa especifica.
    Requiere: client_id, client_secret (de Portal SOL), ruc, usuario_sol, clave_sol.
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

        self.client_id     = client_id.strip()
        self.client_secret = client_secret.strip()
        self.ruc           = ruc.strip()
        # usuario puede ser solo el nombre (ej: "MORERA") o RUC+nombre - SUNAT acepta ambos
        # pero username en el body DEBE ser "{RUC} {USUARIO}"
        self.usuario       = (usuario or "").strip()
        self.clave_sol     = clave_sol.strip()
        self.timeout       = timeout
        self._cache_key    = f"{client_id}:{ruc}:{usuario}"

    # ── Autenticacion ────────────────────────────────────────────────────────
    def _autenticar(self) -> str:
        """
        Obtiene token OAuth2 (Password flow).

        Referencia: Manual SIRE Ventas v25, sección 5.1 Servicio Api Seguridad
        - URL incluye client_id como path param
        - username = "{RUC} {USUARIO_SOL}"  ← espacio obligatorio
        - password = clave SOL del contribuyente
        - grant_type = "password"
        - scope = "https://api-sire.sunat.gob.pe"
        """
        # Revisar cache primero
        cached = TokenCache.obtener(self._cache_key)
        if cached:
            return cached

        # Construir URL con client_id en el path (CRITICO)
        url = URL_TOKEN.format(client_id=self.client_id)

        # username = "RUC USUARIO" con espacio (segun manual)
        # Ejemplo: "20123456789 MORERA"
        username = f"{self.ruc} {self.usuario}" if self.usuario else self.ruc

        # Log de diagnóstico (sin exponer password)
        logger.info(f"SIRE auth -> URL: {url}")
        logger.info(f"SIRE auth -> username: '{username}' (RUC={self.ruc}, usuario='{self.usuario}')")
        logger.info(f"SIRE auth -> client_id: {self.client_id[:8]}...")

        payload = {
            "grant_type":    GRANT_TYPE,
            "scope":         SCOPE,
            "client_id":     self.client_id,
            "client_secret": self.client_secret,
            "username":      username,
            "password":      self.clave_sol,
        }

        try:
            with httpx.Client(timeout=self.timeout) as client:
                resp = client.post(
                    url,
                    data=payload,
                    headers={"Content-Type": "application/x-www-form-urlencoded"},
                )

            if resp.status_code != 200:
                body = resp.text
                logger.error(f"SIRE auth fallo HTTP {resp.status_code}: {body}")

                # Diagnóstico específico por código
                if resp.status_code == 400:
                    try:
                        err = resp.json()
                        if err.get("error") == "access_denied":
                            raise SIREError(
                                f"Autenticacion fallida (HTTP 400): {body}\n"
                                f"Verificar: (1) username='{username}' correcto, "
                                f"(2) clave SOL correcta, "
                                f"(3) client_id/secret generados en Portal SOL > Credenciales API SUNAT",
                                codigo="ACCESS_DENIED",
                                detalles={"username_enviado": username, "url": url},
                            )
                    except (ValueError, KeyError):
                        pass
                raise SIREError(
                    f"Autenticacion fallida (HTTP {resp.status_code}): {body}",
                    codigo=str(resp.status_code),
                )

            data = resp.json()
            token = data.get("access_token")
            if not token:
                raise SIREError(f"Token no encontrado en respuesta: {data}")

            expires_in = data.get("expires_in", 3600)
            TokenCache.guardar(self._cache_key, token, expires_in)
            logger.info("SIRE auth OK - token obtenido y cacheado")
            return token

        except httpx.TimeoutException:
            raise SIREError("Timeout conectando a api-seguridad.sunat.gob.pe", codigo="TIMEOUT")
        except httpx.ConnectError as e:
            raise SIREError(f"Error de conexion a SUNAT: {e}", codigo="CONNECTION_ERROR")

    # ── Headers autenticados ─────────────────────────────────────────────────
    def _headers(self) -> dict:
        token = self._autenticar()
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type":  "application/json",
            "Accept":        "application/json",
        }

    # ── Probar conexion ──────────────────────────────────────────────────────
    def probar_conexion(self) -> dict:
        """Valida credenciales sin descargar datos."""
        TokenCache.limpiar(self._cache_key)
        try:
            token = self._autenticar()
            return {
                "estado":    "OK",
                "mensaje":   "Conexion exitosa con SUNAT SIRE",
                "token_len": len(token),
            }
        except SIREError as e:
            return {
                "estado":   "ERROR",
                "mensaje":  str(e),
                "codigo":   e.codigo,
                "detalles": e.detalles,
            }

    # ── Periodos habilitados ─────────────────────────────────────────────────
    def obtener_periodos_rvie(self) -> List[dict]:
        """Periodos habilitados para el RVIE (Ventas). codLibro=140000"""
        url = f"{URL_BASE}/v1/contribuyente/migeigv/libros/rvierce/padron/web/omisos/140000/periodos"
        with httpx.Client(timeout=self.timeout) as client:
            resp = client.get(url, headers=self._headers())
        if resp.status_code != 200:
            raise SIREError(f"Error consultando periodos RVIE: HTTP {resp.status_code} - {resp.text}")
        return resp.json()

    def obtener_periodos_rce(self) -> List[dict]:
        """Periodos habilitados para el RCE (Compras). codLibro=080100"""
        url = f"{URL_BASE}/v1/contribuyente/migeigv/libros/rvierce/padron/web/omisos/080100/periodos"
        with httpx.Client(timeout=self.timeout) as client:
            resp = client.get(url, headers=self._headers())
        if resp.status_code != 200:
            raise SIREError(f"Error consultando periodos RCE: HTTP {resp.status_code} - {resp.text}")
        return resp.json()

    # ── Solicitar descarga propuesta ─────────────────────────────────────────
    def solicitar_propuesta_rvie(self, anio: int, mes: int) -> str:
        """Solicita descarga del RVIE (Ventas). Retorna ticket."""
        periodo = f"{anio}{str(mes).zfill(2)}"
        url = f"{URL_BASE}/v1/contribuyente/migeigv/libros/rvie/propuesta/{periodo}/descargar"
        with httpx.Client(timeout=self.timeout) as client:
            resp = client.post(url, headers=self._headers(), json={})
        if resp.status_code not in (200, 201, 202):
            raise SIREError(f"Error solicitando RVIE {periodo}: HTTP {resp.status_code} - {resp.text}")
        data = resp.json()
        ticket = data.get("numTicket") or data.get("ticket") or data.get("ticketId")
        if not ticket:
            raise SIREError(f"No se recibio ticket en respuesta RVIE: {data}")
        return str(ticket)

    def solicitar_propuesta_rce(self, anio: int, mes: int) -> str:
        """Solicita descarga del RCE (Compras). Retorna ticket."""
        periodo = f"{anio}{str(mes).zfill(2)}"
        url = f"{URL_BASE}/v1/contribuyente/migeigv/libros/rce/propuesta/{periodo}/descargar"
        with httpx.Client(timeout=self.timeout) as client:
            resp = client.post(url, headers=self._headers(), json={})
        if resp.status_code not in (200, 201, 202):
            raise SIREError(f"Error solicitando RCE {periodo}: HTTP {resp.status_code} - {resp.text}")
        data = resp.json()
        ticket = data.get("numTicket") or data.get("ticket") or data.get("ticketId")
        if not ticket:
            raise SIREError(f"No se recibio ticket en respuesta RCE: {data}")
        return str(ticket)

    # ── Consultar estado del ticket ──────────────────────────────────────────
    def consultar_ticket(self, ticket: str) -> dict:
        """Consulta el estado de un ticket de descarga. Retorna {'estado': ..., 'link': ...}"""
        url = f"{URL_BASE}/v1/contribuyente/migeigv/libros/rvierce/envios/{ticket}/validarEstadoEnvio"
        with httpx.Client(timeout=self.timeout) as client:
            resp = client.get(url, headers=self._headers())
        if resp.status_code != 200:
            raise SIREError(f"Error consultando ticket {ticket}: HTTP {resp.status_code} - {resp.text}")
        return resp.json()

    # ── Esperar y descargar ──────────────────────────────────────────────────
    def esperar_y_descargar(self, ticket: str, max_intentos: int = 20, espera_seg: int = 3) -> bytes:
        """Espera a que el ticket esté listo y descarga el ZIP."""
        for intento in range(max_intentos):
            estado = self.consultar_ticket(ticket)
            cod_estado = estado.get("codEstado") or estado.get("estado") or ""

            # Estado 4 = Finalizado/Listo para descarga
            if str(cod_estado) in ("4", "FINALIZADO", "LISTO"):
                link = estado.get("arcGzip") or estado.get("urlDescarga") or estado.get("link")
                if not link:
                    raise SIREError(f"Ticket listo pero sin link de descarga: {estado}")
                with httpx.Client(timeout=120) as client:
                    resp = client.get(link, headers=self._headers())
                if resp.status_code != 200:
                    raise SIREError(f"Error descargando archivo: HTTP {resp.status_code}")
                return resp.content

            # Estado de error
            if str(cod_estado) in ("5", "6", "ERROR"):
                raise SIREError(f"Ticket {ticket} en estado de error: {estado}")

            # Aun procesando
            logger.info(f"Ticket {ticket} estado {cod_estado}, intento {intento+1}/{max_intentos}...")
            time.sleep(espera_seg)

        raise SIREError(f"Timeout esperando ticket {ticket} despues de {max_intentos} intentos")

    # ── Parsear TXT pipe-separated de SUNAT ─────────────────────────────────
    @staticmethod
    def _parsear_zip_txt(zip_bytes: bytes) -> List[str]:
        """Extrae líneas del TXT dentro del ZIP descargado de SUNAT."""
        lineas = []
        with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
            for nombre in zf.namelist():
                if nombre.endswith(".txt"):
                    with zf.open(nombre) as f:
                        for linea in f:
                            decoded = linea.decode("utf-8", errors="replace").strip()
                            if decoded:
                                lineas.append(decoded)
        return lineas

    # ── API pública: descargar RVIE y RCE ────────────────────────────────────
    def descargar_rvie(self, anio: int, mes: int) -> List[dict]:
        """Descarga y parsea el RVIE (Ventas). Retorna lista de comprobantes."""
        ticket = self.solicitar_propuesta_rvie(anio, mes)
        zip_bytes = self.esperar_y_descargar(ticket)
        lineas = self._parsear_zip_txt(zip_bytes)
        return [self._parsear_linea_rvie(l) for l in lineas if l.startswith("14")]

    def descargar_rce(self, anio: int, mes: int) -> List[dict]:
        """Descarga y parsea el RCE (Compras). Retorna lista de comprobantes."""
        ticket = self.solicitar_propuesta_rce(anio, mes)
        zip_bytes = self.esperar_y_descargar(ticket)
        lineas = self._parsear_zip_txt(zip_bytes)
        return [self._parsear_linea_rce(l) for l in lineas if "|" in l]

    # ── Parsers de formato pipe-separated ────────────────────────────────────
    @staticmethod
    def _parsear_linea_rvie(linea: str) -> dict:
        """Parsea una línea del RVIE (14 campos pipe-separated)."""
        campos = linea.split("|")
        def d(i, default=""):
            return campos[i].strip() if i < len(campos) else default
        def dec(i):
            try: return Decimal(d(i) or "0")
            except: return Decimal("0")
        return {
            "periodo":           d(0),
            "cuo":               d(1),
            "correlativo":       d(2),
            "fecha_emision":     d(3),
            "fecha_vencimiento": d(4),
            "tipo_cp":           d(5),
            "serie":             d(6),
            "numero":            d(7),
            "tipo_doc_cliente":  d(8),
            "num_doc_cliente":   d(9),
            "razon_social":      d(10),
            "base_imponible":    dec(11),
            "igv":               dec(12),
            "total":             dec(13),
        }

    @staticmethod
    def _parsear_linea_rce(linea: str) -> dict:
        """Parsea una línea del RCE (campos pipe-separated)."""
        campos = linea.split("|")
        def d(i, default=""):
            return campos[i].strip() if i < len(campos) else default
        def dec(i):
            try: return Decimal(d(i) or "0")
            except: return Decimal("0")
        return {
            "periodo":           d(0),
            "cuo":               d(1),
            "correlativo":       d(2),
            "fecha_emision":     d(3),
            "fecha_vencimiento": d(4),
            "tipo_cp":           d(5),
            "serie":             d(6),
            "numero":            d(7),
            "anio_emision_dua":  d(8),
            "tipo_doc_proveedor":d(9),
            "num_doc_proveedor": d(10),
            "razon_social":      d(11),
            "base_imponible":    dec(12),
            "igv":               dec(13),
            "total":             dec(14),
            "tipo_cambio":       dec(15),
        }
'@

# Hacer backup del original
if (Test-Path $clientPath) {
    Copy-Item $clientPath "$clientPath.bak" -Force
    Write-Host "  [OK] Backup guardado: $clientPath.bak" -ForegroundColor Green
}

# Escribir el fix
$sireClientContent | Set-Content $clientPath -Encoding UTF8
Write-Host "  [OK] sire_client.py actualizado con fix de autenticacion" -ForegroundColor Green

# ============================================================
# PASO 3: Actualizar el logging para que muestre el username enviado
# ============================================================
Write-Host ""
Write-Host "=== Fix aplicado exitosamente ===" -ForegroundColor Green
Write-Host ""
Write-Host "LO QUE CAMBIA:" -ForegroundColor Cyan
Write-Host "  1. username ahora es: 'f`"{self.ruc} {self.usuario}`"'  (con espacio entre RUC y usuario)" -ForegroundColor White
Write-Host "  2. URL del token incluye client_id en el path param (ya estaba bien, reforzado)" -ForegroundColor White
Write-Host "  3. Logs detallados antes del request para diagnosticar" -ForegroundColor White
Write-Host "  4. Mensaje de error mas especifico con ACCESS_DENIED" -ForegroundColor White
Write-Host ""
Write-Host "PARA VERIFICAR - revisa en los logs uvicorn el mensaje:" -ForegroundColor Yellow
Write-Host "  SIRE auth -> username: '20123456789 TUUSUARIO'" -ForegroundColor White
Write-Host "  (si aparece solo el RUC sin usuario o sin espacio = ese era el bug)" -ForegroundColor White
Write-Host ""
Write-Host "CREDENCIALES A VERIFICAR EN PORTAL SOL:" -ForegroundColor Yellow
Write-Host "  Ir a: https://e-menu.sunat.gob.pe" -ForegroundColor White
Write-Host "  EMPRESAS -> Credenciales de API SUNAT -> Gestion Credenciales de API SUNAT" -ForegroundColor White
Write-Host "  Copiar exactamente el client_id y client_secret que aparecen ahi" -ForegroundColor White
Write-Host ""
Write-Host "Reinicia uvicorn y prueba el endpoint:" -ForegroundColor Yellow
Write-Host "  POST /api/v1/empresas/{id}/sire/probar-conexion" -ForegroundColor White
