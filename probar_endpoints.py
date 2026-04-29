"""
Script para probar diferentes variaciones del endpoint de consulta de tickets.
"""
import sys
import os
import json
import time
import httpx

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from app.services.empresa_service import obtener_credenciales_sunat
from app.services.sire_client import SireClient
from app.database import SessionLocal
from app.models.models import Empresa


def probar_endpoints(empresa_id: int = 7, ticket: str = None):
    """Prueba diferentes variaciones del endpoint."""

    print("=" * 70)
    print("  PROBANDO DIFERENTES ENDPOINTS DE CONSULTA")
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

    # Headers base
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}

    # Diferentes endpoints a probar
    endpoints = [
        # Endpoint actual (con query param)
        f"https://api-sire.sunat.gob.pe/v1/contribuyente/migeigv/libros/rvie/gestionprocesosmasivos/web/masivo/consultaestadotickets?numTicket={ticket}",

        # Alternativa con slash
        f"https://api-sire.sunat.gob.pe/v1/contribuyente/migeigv/libros/rvie/gestionprocesosmasivos/web/masivo/consultaestadotickets/?numTicket={ticket}",

        # Version alternativa del path
        f"https://api-sire.sunat.gob.pe/v1/contribuyente/migeigv/libros/rvie/gestionprocesos/web/masivo/consultaestadotickets?numTicket={ticket}",
    ]

    for idx, url in enumerate(endpoints):
        print(f"\n{'='*70}")
        print(f"  Probando endpoint {idx+1}/{len(endpoints)}")
        print(f"  URL: {url}")
        print("="*70)

        try:
            with httpx.Client(timeout=180, follow_redirects=True) as http_client:
                resp = http_client.get(url, headers=headers)
                print(f"[HTTP] Status: {resp.status_code}")

                # Intentar parsear como JSON
                try:
                    body = resp.json()
                    print(f"[JSON] {json.dumps(body, indent=2, ensure_ascii=False)[:500]}")
                except:
                    print(f"[TEXT] {resp.text[:500]}")

        except Exception as e:
            print(f"[ERROR] Excepcion: {e}")

        time.sleep(2)

    # Ahora probar con POST y JSON body
    print(f"\n{'='*70}")
    print("  Probando con POST + JSON body")
    print("="*70)

    post_endpoints = [
        {
            "url": "https://api-sire.sunat.gob.pe/v1/contribuyente/migeigv/libros/rvie/gestionprocesosmasivos/web/masivo/consultaestadotickets",
            "body": {"numTicket": ticket}
        },
        {
            "url": "https://api-sire.sunat.gob.pe/v1/contribuyente/migeigv/libros/rvie/gestionprocesos/web/masivo/consultaestadotickets",
            "body": {"numTicket": ticket}
        },
    ]

    for idx, ep in enumerate(post_endpoints):
        print(f"\n  POST endpoint {idx+1}/{len(post_endpoints)}")
        print(f"  URL: {ep['url']}")
        print(f"  Body: {json.dumps(ep['body'])}")

        try:
            with httpx.Client(timeout=180, follow_redirects=True) as http_client:
                resp = http_client.post(
                    ep["url"],
                    headers={**headers, "Content-Type": "application/json"},
                    json=ep["body"]
                )
                print(f"  [HTTP] Status: {resp.status_code}")

                try:
                    body = resp.json()
                    print(f"  [JSON] {json.dumps(body, indent=2, ensure_ascii=False)[:500]}")
                except:
                    print(f"  [TEXT] {resp.text[:500]}")

        except Exception as e:
            print(f"  [ERROR] Excepcion: {e}")

        time.sleep(2)

    # Verificar el token - mostrar los primeros 100 caracteres
    print(f"\n{'='*70}")
    print("  VERIFICACION DEL TOKEN")
    print("="*70)
    print(f"  Token (primeros 100 chars): {token[:100]}...")
    print(f"  Longitud: {len(token)}")

    db.close()


if __name__ == "__main__":
    empresa_id = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    ticket = sys.argv[2] if len(sys.argv) > 2 else None

    probar_endpoints(empresa_id, ticket)