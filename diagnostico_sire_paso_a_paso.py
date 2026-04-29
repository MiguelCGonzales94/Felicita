"""
Script de Diagnostico para SIRE SUNAT
Ejecutar desde la raiz del proyecto: python diagnostico_sire.py

Este script prueba cada paso del proceso SIRE para identificar donde falla.
"""
import sys
import os

# Agregar el backend al path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from app.services.empresa_service import obtener_credenciales_sunat
from app.services.sire_client import SireClient, SIREError, TokenCache
from app.database import SessionLocal
from app.models.models import Empresa


def print_separator(titulo):
    print("\n" + "=" * 60)
    print(f"  {titulo}")
    print("=" * 60)


def diagnostico_sire(empresa_id: int = 7):
    """Ejecuta el diagnostico completo paso a paso."""

    print_separator("DIAGNOSTICO SIRE - FELICITA")
    print(f"Empresa ID: {empresa_id}")

    # Paso 1: Conectar a la base de datos
    print_separator("PASO 1: Conexion a Base de Datos")
    db = SessionLocal()
    try:
        empresa = db.query(Empresa).filter(Empresa.id == empresa_id).first()
        if empresa:
            print(f"  [OK] Empresa encontrada: {empresa.razon_social}")
            print(f"  [OK] RUC: {empresa.ruc}")
            print(f"  [OK] Usuario SOL: {empresa.usuario_sol}")
        else:
            print(f"  [ERROR] Empresa {empresa_id} no encontrada")
            return
    finally:
        pass

    # Paso 2: Obtener credenciales desencriptadas
    print_separator("PASO 2: Credenciales (Desencriptadas)")
    try:
        cred = obtener_credenciales_sunat(empresa)
        print(f"  [OK] RUC: {cred['ruc']}")
        print(f"  [OK] Usuario: {cred['usuario']}")
        print(f"  [OK] Clave SOL: {cred['clave_sol'][:4]}*** (longitud: {len(cred['clave_sol'])})")
        print(f"  [OK] Client ID: {cred['client_id'][:20]}... (longitud: {len(cred['client_id'])})")
        print(f"  [OK] Client Secret: {cred['client_secret'][:10]}... (longitud: {len(cred['client_secret'])})")

        # Verificar que no esten vacias
        if not cred['clave_sol']:
            print(f"  [ERROR] Clave SOL esta VACIA!")
        if not cred['client_id']:
            print(f"  [ERROR] Client ID esta VACIO!")
        if not cred['client_secret']:
            print(f"  [ERROR] Client Secret esta VACIO!")
    except Exception as e:
        print(f"  [ERROR] Error al obtener credenciales: {e}")
        return

    # Paso 3: Construir el cliente SIRE
    print_separator("PASO 3: Construir Cliente SIRE")
    try:
        client = SireClient(
            client_id=cred['client_id'],
            client_secret=cred['client_secret'],
            ruc=cred['ruc'],
            usuario=cred['usuario'],
            clave_sol=cred['clave_sol'],
        )
        print(f"  [OK] Cliente SIRE creado")
        print(f"  [OK] Username que se enviara: {client.ruc}{client.usuario}")
        print(f"  [OK] Timeout: {client.timeout} segundos")
    except SIREError as e:
        print(f"  [ERROR] Error al crear cliente: {e}")
        return

    # Paso 4: Autenticacion
    print_separator("PASO 4: Autenticacion OAuth2 con SUNAT")
    try:
        print("  Enviando peticion de autenticacion...")
        token = client._autenticar()
        print(f"  [OK] Token recibido: {token[:50]}...")
        print(f"  [OK] Token guardado en cache")
    except SIREError as e:
        print(f"  [ERROR] Error de autenticacion: {e}")
        print(f"  [ERROR] Detalles: {e.detalles}")
        return
    except Exception as e:
        print(f"  [ERROR] Error inesperado: {e}")
        return

    # Paso 5: Descargar propuesta RVIE (Ventas)
    print_separator("PASO 5: Descargar RVIE (Ventas) - Periodo 202512")
    try:
        print("  Solicitando ticket de descarga...")
        data = client.descargar_propuesta_rvie("202512")
        print(f"  [OK] RVIE descargado exitosamente")
        print(f"  [OK] Comprobantes: {data['total_comprobantes']}")
        print(f"  [OK] Ventas gravadas: {data['total_ventas_gravadas']}")
        print(f"  [OK] IGV debito: {data['total_igv_debito']}")
    except SIREError as e:
        print(f"  [ERROR] Error al descargar RVIE: {e}")
        print(f"  [ERROR] Codigo: {e.codigo}")
        print(f"  [ERROR] Detalles: {e.detalles}")
        return
    except Exception as e:
        print(f"  [ERROR] Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        return

    # Paso 6: Descargar propuesta RCE (Compras)
    print_separator("PASO 6: Descargar RCE (Compras) - Periodo 202512")
    try:
        print("  Solicitando ticket de descarga...")
        data = client.descargar_propuesta_rce("202512")
        print(f"  [OK] RCE descargado exitosamente")
        print(f"  [OK] Comprobantes: {data['total_comprobantes']}")
        print(f"  [OK] Compras gravadas: {data['total_compras_gravadas']}")
        print(f"  [OK] IGV credito: {data['total_igv_credito']}")
    except SIREError as e:
        print(f"  [ERROR] Error al descargar RCE: {e}")
        print(f"  [ERROR] Codigo: {e.codigo}")
        print(f"  [ERROR] Detalles: {e.detalles}")
        return
    except Exception as e:
        print(f"  [ERROR] Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        return

    # Resumen final
    print_separator("RESUMEN")
    print("  [OK] TODOS LOS PASOS COMPLETADOS EXITOSAMENTE")
    print("  Tu aplicacion deberia funcionar correctamente.")
    print("  Si aun falla, el problema puede estar en:")
    print("  - El periodo seleccionado (202512) puede no tener datos en SUNAT")
    print("  - El formato de los comprobantes no es el esperado")

    db.close()


if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("  DIAGNOSTICO SIRE - Presiona Ctrl+C para cancelar")
    print("=" * 60)

    # Permitir especificar empresa por argumento
    empresa_id = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    diagnostico_sire(empresa_id)
