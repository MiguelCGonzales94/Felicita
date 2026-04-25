"""
Servicio de consulta de ficha RUC SUNAT.
Usa decolecta.com para consulta real con fallback a mock.
"""
import httpx
import logging

logger = logging.getLogger(__name__)

# Token de decolecta.com
# En produccion esto debe ir en variables de entorno (ej. usando python-dotenv)
DECOLECTA_TOKEN = "sk_5054.rh6Zc84x2xVvK26vBNpjUpbvNM3TSvhb"
DECOLECTA_URL = "https://api.decolecta.com/v1/sunat/ruc"
TIMEOUT = 10


async def consultar_ruc_sunat(ruc: str) -> dict:
    """
    Consulta ficha RUC en SUNAT via decolecta.com.
    Retorna dict con datos del contribuyente o fallback mock.
    """
    try:
        return await _consultar_real(ruc)
    except Exception as e:
        logger.warning(f"Consulta SUNAT real fallo para {ruc}: {e}. Usando mock.")
        return _consultar_mock(ruc)


async def _consultar_real(ruc: str) -> dict:
    """Consulta real a decolecta.com con token en la URL."""
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        # Incluimos el token como parámetro en la URL como indica la documentación
        params = {
            "numero": ruc,
            "token": DECOLECTA_TOKEN 
        }
        
        response = await client.get(
            DECOLECTA_URL,
            params=params,
            headers={"accept": "application/json"} 
        )

        if response.status_code == 200:
            data = response.json()
            # Mapeamos usando las claves snake_case de Decolecta
            return {
                "ruc": data.get("numero_documento", ruc),
                "es_valido": True,
                "tipo": _tipo_contribuyente(ruc),
                "razon_social": data.get("razon_social", ""),
                "nombre_comercial": "", # Decolecta no lo devuelve en este endpoint
                "estado_sunat": _mapear_estado(data.get("estado", "")),
                "condicion_domicilio": _mapear_condicion(data.get("condicion", "")),
                "direccion_fiscal": data.get("direccion", ""),
                "distrito": data.get("distrito", ""),
                "provincia": data.get("provincia", ""),
                "departamento": data.get("departamento", ""),
                "fecha_inicio": "", # No viene en el endpoint básico
                "actividad_economica": data.get("actividad_economica", ""), 
                "fuente": "SUNAT_REAL",
                "mensaje": "Datos obtenidos de SUNAT",
            }
        elif response.status_code == 422:
            return {
                "ruc": ruc, "es_valido": False, "tipo": "",
                "razon_social": None, "estado_sunat": None,
                "condicion_domicilio": None, "direccion_fiscal": None,
                "fuente": "SUNAT_REAL",
                "mensaje": f"RUC {ruc} no encontrado o inválido",
            }
        else:
            raise Exception(f"HTTP {response.status_code}: {response.text[:200]}")


def _consultar_mock(ruc: str) -> dict:
    """Fallback mock cuando no hay conexion."""
    prefijo = ruc[:2]
    if prefijo == "20":
        razon = f"EMPRESA MOCK {ruc[-4:]} S.A.C."
        tipo = "PERSONA JURIDICA"
    elif prefijo == "10":
        razon = f"CONTRIBUYENTE MOCK {ruc[-4:]}"
        tipo = "PERSONA NATURAL"
    else:
        razon = f"ENTIDAD {ruc[-4:]}"
        tipo = "OTROS"

    return {
        "ruc": ruc,
        "es_valido": True,
        "tipo": tipo,
        "razon_social": razon,
        "nombre_comercial": None,
        "estado_sunat": "ACTIVO",
        "condicion_domicilio": "HABIDO",
        "direccion_fiscal": "AV. JAVIER PRADO 1234, SAN ISIDRO, LIMA",
        "distrito": "SAN ISIDRO",
        "provincia": "LIMA",
        "departamento": "LIMA",
        "fecha_inicio": None,
        "actividad_economica": None,
        "fuente": "MOCK",
        "mensaje": "Datos simulados (configura token para consulta real)",
    }


def _tipo_contribuyente(ruc: str) -> str:
    if ruc.startswith("20"): return "PERSONA JURIDICA"
    if ruc.startswith("10"): return "PERSONA NATURAL"
    if ruc.startswith("15"): return "GOBIERNO"
    if ruc.startswith("17"): return "NO DOMICILIADO"
    return "OTROS"


def _mapear_estado(estado: str) -> str:
    estado = str(estado).upper().strip()
    mapa = {
        "ACTIVO": "ACTIVO",
        "BAJA PROVISIONAL": "BAJA",
        "BAJA PROV.": "BAJA",
        "BAJA DEFINITIVA": "BAJA",
        "BAJA DE OFICIO": "BAJA",
        "SUSPENSION TEMPORAL": "SUSPENDIDO",
        "BAJA MULTA": "BAJA",
    }
    return mapa.get(estado, "ACTIVO")


def _mapear_condicion(condicion: str) -> str:
    condicion = str(condicion).upper().strip()
    mapa = {
        "HABIDO": "HABIDO",
        "NO HABIDO": "NO_HABIDO",
        "NO HALLADO": "NO_HALLADO",
        "PENDIENTE": "HABIDO",
    }
    return mapa.get(condicion, "HABIDO")