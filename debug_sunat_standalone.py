"""
Script DEBUG standalone - NO depende de los imports del proyecto.
Solo usa requests/httpx directamente para probar el endpoint de SUNAT.

Uso:
  python debug_sunat_standalone.py <client_id> <client_secret> <ruc> <usuario> <clave_sol> [ticket]
"""
import sys
import json
import time
import httpx

URL_TOKEN = "https://api-seguridad.sunat.gob.pe/v1/clientessol/{client_id}/oauth2/token/"
URL_BASE_SIRE = "https://api-sire.sunat.gob.pe"
SCOPE = "https://api-sire.sunat.gob.pe"
GRANT_TYPE = "password"


def autenticar(client_id, client_secret, ruc, usuario, clave_sol):
    """Autentica con SUNAT y retorna el token."""
    url = URL_TOKEN.format(client_id=client_id)

    # Formato SIN espacio
    username = f"{ruc}{usuario}" if usuario else ruc

    data = {
        "grant_type": GRANT_TYPE,
        "scope": SCOPE,
        "client_id": client_id,
        "client_secret": client_secret,
        "username": username,
        "password": clave_sol,
    }
    headers = {"Content-Type": "application/x-www-form-urlencoded"}

    print(f"\n[DEBUG] URL: {url}")
    print(f"[DEBUG] Username: '{username}'")

    resp = httpx.post(url, data=data, headers=headers, timeout=120)
    print(f"[DEBUG] Status: {resp.status_code}")
    print(f"[DEBUG] Response: {resp.text[:300]}")

    if resp.status_code != 200:
        raise Exception(f"Auth failed: {resp.text}")

    return resp.json()["access_token"]


def solicitar_ticket(token, periodo="202512"):
    """Solicita un nuevo ticket de descarga."""
    url = (
        f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rvie/"
        f"propuesta/web/propuesta/{periodo}/exportapropuesta?codTipoArchivo=0"
    )

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json"
    }

    print(f"\n[DEBUG] Solicitar ticket URL: {url}")
    resp = httpx.get(url, headers=headers, timeout=120)
    print(f"[DEBUG] Status: {resp.status_code}")
    print(f"[DEBUG] Response: {resp.text[:500]}")

    if resp.status_code not in (200, 201):
        raise Exception(f"Ticket request failed: {resp.text}")

    body = resp.json()
    return body.get("numTicket") or body.get("numticket")


def consultar_estado_ticket(token, num_ticket):
    """Consulta el estado de un ticket y retorna la respuesta COMPLETA."""
    url = (
        f"{URL_BASE_SIRE}/v1/contribuyente/migeigv/libros/rvie/"
        f"gestionprocesosmasivos/web/masivo/consultaestadotickets?numTicket={num_ticket}"
    )

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json"
    }

    print(f"\n[DEBUG] Consultar estado URL: {url}")
    resp = httpx.get(url, headers=headers, timeout=120)
    print(f"[DEBUG] Status HTTP: {resp.status_code}")

    if resp.status_code == 200:
        body = resp.json()
        print(f"[DEBUG] Response JSON:\n{json.dumps(body, indent=2, ensure_ascii=False)}")
        return body
    else:
        print(f"[DEBUG] Response (no JSON): {resp.text[:500]}")
        return None


def main():
    if len(sys.argv) < 6:
        print("""
╔══════════════════════════════════════════════════════════════╗
║  DEBUG SIRE - Script Standalone                              ║
╠══════════════════════════════════════════════════════════════╣
║  Uso:                                                         ║
║  python debug_sunat_standalone.py \\                           ║
║      <client_id> <client_secret> \\                           ║
║      <ruc> <usuario> <clave_sol> [ticket]                   ║
║                                                               ║
║  Ejemplo:                                                     ║
║  python debug_sunat_standalone.py \\                          ║
║      abc123xyz MILLAECONSECRET \\                             ║
║      20556082619 ALOPICHS miclave                            ║
╚══════════════════════════════════════════════════════════════╝
        """)
        sys.exit(1)

    client_id = sys.argv[1]
    client_secret = sys.argv[2]
    ruc = sys.argv[3]
    usuario = sys.argv[4]
    clave_sol = sys.argv[5]
    ticket_existente = sys.argv[6] if len(sys.argv) > 6 else None

    print("=" * 70)
    print("  DEBUG SIRE - Ver respuesta exacta de SUNAT")
    print("=" * 70)
    print(f"\nRUC: {ruc}")
    print(f"Usuario: {usuario}")
    print(f"Client ID: {client_id[:20]}...")

    # 1. Autenticar
    print("\n" + "=" * 70)
    print("  PASO 1: Autenticacion")
    print("=" * 70)
    try:
        token = autenticar(client_id, client_secret, ruc, usuario, clave_sol)
        print(f"\n[OK] Token obtenido: {token[:30]}...")
    except Exception as e:
        print(f"\n[ERROR] Autenticacion fallida: {e}")
        sys.exit(1)

    # 2. Obtener ticket o usar el existente
    if ticket_existente:
        print(f"\n[INFO] Usando ticket existente: {ticket_existente}")
        num_ticket = ticket_existente
    else:
        print("\n" + "=" * 70)
        print("  PASO 2: Solicitar ticket RVIE")
        print("=" * 70)
        try:
            num_ticket = solicitar_ticket(token, "202512")
            print(f"\n[OK] Ticket obtenido: {num_ticket}")
        except Exception as e:
            print(f"\n[ERROR] Solicitud de ticket fallida: {e}")
            sys.exit(1)

    # 3. Consultar estado varias veces
    print("\n" + "=" * 70)
    print(f"  PASO 3: Consultar estado del ticket {num_ticket}")
    print("=" * 70)

    for i in range(10):
        print(f"\n{'='*70}")
        print(f"  Intento {i+1}/10")
        print("="*70)

        body = consultar_estado_ticket(token, num_ticket)

        if body:
            # Analizar la estructura
            print("\n[ANALISIS]:")
            print(f"  Keys en respuesta: {list(body.keys())}")

            # Buscar 'registros' o 'data'
            registros = body.get("registros") or body.get("data") or body.get("listaRegistros") or []
            print(f"  Registros encontrados: {type(registros).__name__} ({len(registros) if isinstance(registros, list) else 'N/A'})")

            if isinstance(registros, list) and len(registros) > 0:
                item = registros[0]
                print(f"\n  [PRIMER REGISTRO]:")
                if isinstance(item, dict):
                    for k, v in item.items():
                        print(f"    {k}: {v}")

                    # Buscar campo de estado
                    for estado_key in ['desEstadoProceso', 'estado', 'estadoProceso', 'descripcionEstado', 'descripcion']:
                        if estado_key in item:
                            print(f"\n  *** CAMPO ESTADO ENCONTRADO: {estado_key} = '{item[estado_key]}' ***")

            # Verificar si ya terminó
            if isinstance(registros, list) and len(registros) > 0:
                item = registros[0]
                estado = (
                    item.get('desEstadoProceso') or
                    item.get('estado') or
                    item.get('estadoProceso') or
                    item.get('descripcionEstado') or
                    ""
                ).upper()

                if "TERMINADO" in estado or "TERMINADA" in estado:
                    print(f"\n{'='*70}")
                    print(f"  [SUCCESS] Ticket TERMINADO! Estado: {estado}")
                    print("="*70)
                    break
                elif "ERROR" in estado or "RECHAZADO" in estado:
                    print(f"\n{'='*70}")
                    print(f"  [ERROR] Ticket con error: {estado}")
                    print("="*70)
                    break

        if i < 9:
            print("\n  Esperando 5 segundos antes del siguiente intento...")
            time.sleep(5)

    print("\n" + "=" * 70)
    print("  FIN DEL DEBUG")
    print("=" * 70)


if __name__ == "__main__":
    main()
