"""
Script de DEBUG ULTRA-DETALLADO para ver la respuesta EXACTA de SUNAT.
Ejecutar: python debug_exacto.py [empresa_id] [ticket]
"""
import sys
import os
import json
import time
import httpx

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from app.services.empresa_service import obtener_credenciales_sunat
from app.services.sire_client import SireClient, TokenCache
from app.database import SessionLocal
from app.models.models import Empresa


def debug_exacto(empresa_id: int = 7, ticket: str = None):
    """Imprime TODO lo que SUNAT devuelve."""

    print("=" * 70)
    print("  DEBUG ULTRA-DETALLADO - Respuesta exacta de SUNAT")
    print("=" * 70)

    db = SessionLocal()
    try:
        empresa = db.query(Empresa).filter(Empresa.id == empresa_id).first()
        if not empresa:
            print(f"[ERROR] Empresa {empresa_id} no encontrada")
            return
    finally:
        pass

    cred = obtener_credenciales_sunat(empresa)
    print(f"\n[INFO] Empresa: {empresa.razon_social} (RUC: {empresa.ruc})")

    # Crear cliente
    client = SireClient(
        client_id=cred['client_id'],
        client_secret=cred['client_secret'],
        ruc=cred['ruc'],
        usuario=cred['usuario'],
        clave_sol=cred['clave_sol'],
        timeout=180,
    )

    # Autenticar
    print("\n[PASO 1] Autenticando...")
    try:
        token = client._autenticar()
        print(f"[OK] Token: {token[:30]}...\n")
    except Exception as e:
        print(f"[ERROR] Autenticacion fallida: {e}")
        return

    # Si no hay ticket, solicitar uno nuevo
    if not ticket:
        print("[PASO 2] Solicitando ticket RVIE...")
        url_descarga = (
            f"https://api-sire.sunat.gob.pe/v1/contribuyente/migeigv/libros/rvie/"
            f"propuesta/web/propuesta/202512/exportapropuesta?codTipoArchivo=0"
        )
        try:
            with httpx.Client(timeout=180) as http_client:
                resp = http_client.get(
                    url_descarga,
                    headers={"Authorization": f"Bearer {token}", "Accept": "application/json"}
                )
                print(f"[INFO] Status: {resp.status_code}")
                body = resp.json()
                print(f"[INFO] Response: {json.dumps(body, indent=2, ensure_ascii=False)}")
                ticket = body.get("numTicket") or body.get("numticket")
                print(f"[OK] Ticket: {ticket}\n")
        except Exception as e:
            print(f"[ERROR] Solicitud de ticket fallida: {e}")
            return
    else:
        print(f"[INFO] Usando ticket: {ticket}")

    if not ticket:
        print("[ERROR] No se pudo obtener ticket")
        return

    # Consultar estado del ticket varias veces
    print("=" * 70)
    print(f"[PASO 3] Consultando estado del ticket {ticket}")
    print("=" * 70)

    url_estado = (
        f"https://api-sire.sunat.gob.pe/v1/contribuyente/migeigv/libros/rvie/"
        f"gestionprocesosmasivos/web/masivo/consultaestadotickets?numTicket={ticket}"
    )

    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}

    for i in range(15):
        print(f"\n{'='*70}")
        print(f"  Intento {i+1}/15")
        print("="*70)

        try:
            with httpx.Client(timeout=180) as http_client:
                resp = http_client.get(url_estado, headers=headers)
                print(f"[HTTP] Status: {resp.status_code}")

                if resp.status_code == 200:
                    body = resp.json()

                    # IMPRIMIR LA RESPUESTA COMPLETA
                    print(f"\n[RAW JSON COMPLETO]:")
                    print(json.dumps(body, indent=2, ensure_ascii=False))

                    # Analizar estructura
                    print(f"\n[ANALISIS]:")
                    print(f"  Tipo de respuesta: {type(body).__name__}")
                    print(f"  Keys en nivel superior: {list(body.keys()) if isinstance(body, dict) else 'NO ES DICT'}")

                    # Intentar encontrar registros de diferentes maneras
                    for key in ["registros", "data", "listaRegistros", "resultado", "items", "content", "respuesta"]:
                        if key in body:
                            print(f"  [{key}]: {type(body[key]).__name__}")
                            if isinstance(body[key], list):
                                print(f"    Elementos: {len(body[key])}")
                                if len(body[key]) > 0:
                                    print(f"    Primer elemento keys: {list(body[key][0].keys()) if isinstance(body[key][0], dict) else type(body[key][0])}")

                    # Buscar campos de estado
                    print(f"\n[BUSCANDO ESTADO]:")
                    estado_encontrado = False

                    # Si es un diccionario, buscar en todos los niveles
                    def buscar_estado(obj, prefijo="", profundidad=0):
                        nonlocal estado_encontrado
                        if profundidad > 3:
                            return

                        if isinstance(obj, dict):
                            for k, v in obj.items():
                                k_upper = k.upper()
                                if any(x in k_upper for x in ["ESTADO", "STATE", "STATUS", "PROCESO", "CONDICION"]):
                                    print(f"  [ENCONTRADO] '{k}': {v}")
                                    estado_encontrado = True
                                if isinstance(v, (dict, list)):
                                    buscar_estado(v, f"{prefijo}{k}.", profundidad+1)
                        elif isinstance(obj, list) and len(obj) > 0:
                            buscar_estado(obj[0], prefijo, profundidad+1)

                    buscar_estado(body)

                    if not estado_encontrado:
                        print("  [NO ENCONTRADO] No se encontro ningun campo de estado")

                else:
                    print(f"[ERROR] Response: {resp.text[:500]}")
        except Exception as e:
            print(f"[ERROR] Excepcion: {e}")
            import traceback
            traceback.print_exc()

        if i < 14:
            print("\n  Esperando 5 segundos...")
            time.sleep(5)

    db.close()


if __name__ == "__main__":
    print("\n" + "=" * 70)
    print("  DEBUG ULTRA-DETALLADO SIRE")
    print("=" * 70)

    empresa_id = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    ticket = sys.argv[2] if len(sys.argv) > 2 else None

    debug_exacto(empresa_id, ticket)