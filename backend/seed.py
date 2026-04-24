import sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal, Base, engine
from app.models.models import (
    Usuario, Empresa, PlanSuscripcion,
    CronogramaSunat, ConfiguracionNotificaciones
)
from app.utils.security import hash_password
from datetime import date


def seed():
    # Crear tablas si no existen
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        print("Iniciando seed...")

        # ── Planes ───────────────────────────────────────
        planes_data = [
            dict(nombre="FREE", precio_mensual=0, precio_anual=0,
                 max_empresas=2, max_pdt621_mes=5, nivel_soporte="EMAIL",
                 activo=True, orden_visualizacion=1),
            dict(nombre="STARTER", precio_mensual=99, precio_anual=990,
                 max_empresas=10, nivel_soporte="EMAIL",
                 activo=True, orden_visualizacion=2),
            dict(nombre="PROFESIONAL", precio_mensual=249, precio_anual=2490,
                 max_empresas=30, permite_ia_avanzada=True,
                 permite_reportes_consolidados=True, nivel_soporte="CHAT",
                 activo=True, orden_visualizacion=3),
            dict(nombre="ESTUDIO", precio_mensual=499, precio_anual=4990,
                 max_empresas=100, max_contadores=5,
                 permite_ia_avanzada=True, permite_reportes_consolidados=True,
                 permite_api_access=True, permite_multi_usuario=True,
                 nivel_soporte="24_7", activo=True, orden_visualizacion=4),
        ]
        for p in planes_data:
            if not db.query(PlanSuscripcion).filter_by(nombre=p["nombre"]).first():
                db.add(PlanSuscripcion(**p))
        db.commit()
        print("  [OK] Planes creados")

        # ── Admin ─────────────────────────────────────────
        if not db.query(Usuario).filter_by(email="admin@felicita.pe").first():
            db.add(Usuario(
                email="admin@felicita.pe",
                password_hash=hash_password("admin123"),
                nombre="Admin", apellido="Felicita",
                rol="ADMIN", plan_actual="ESTUDIO", activo=True,
            ))
            db.commit()
        print("  [OK] admin@felicita.pe / admin123")

        # ── Contador ──────────────────────────────────────
        contador = db.query(Usuario).filter_by(email="ana.perez@felicita.pe").first()
        if not contador:
            contador = Usuario(
                email="ana.perez@felicita.pe",
                password_hash=hash_password("contador123"),
                nombre="Ana", apellido="Perez",
                telefono="999888777",
                rol="CONTADOR", plan_actual="PROFESIONAL", activo=True,
            )
            db.add(contador)
            db.commit()          # <-- commit para obtener el ID real
            db.refresh(contador) # <-- refrescar para leer el ID de la BD

            db.add(ConfiguracionNotificaciones(
                contador_id=contador.id,
                numero_whatsapp="+51999888777",
            ))
            db.commit()

        print(f"  [OK] ana.perez@felicita.pe / contador123 (id={contador.id})")

        # ── Empresas ──────────────────────────────────────
        empresas_data = [
            dict(ruc="20123456789", razon_social="EMPRESA ALFA SAC",
                 direccion_fiscal="Av. Javier Prado 1234, San Isidro",
                 distrito="San Isidro", provincia="Lima", departamento="Lima",
                 regimen_tributario="RG", nivel_alerta="VERDE",
                 color_identificacion="#10B981"),
            dict(ruc="10987654321", razon_social="EMPRESA BETA EIRL",
                 direccion_fiscal="Jr. Cusco 456, Miraflores",
                 distrito="Miraflores", provincia="Lima", departamento="Lima",
                 regimen_tributario="RMT", nivel_alerta="AMARILLO",
                 motivo_alerta="Declaracion pendiente",
                 color_identificacion="#F59E0B"),
            dict(ruc="20345678901", razon_social="EMPRESA GAMMA SA",
                 direccion_fiscal="Av. Arequipa 789, Lince",
                 distrito="Lince", provincia="Lima", departamento="Lima",
                 regimen_tributario="RG", nivel_alerta="ROJO",
                 estado_sunat="OBSERVADO",
                 motivo_alerta="RUC observado por SUNAT",
                 color_identificacion="#EF4444"),
            dict(ruc="20456789012", razon_social="EMPRESA DELTA SRL",
                 direccion_fiscal="Calle Los Pinos 321, Surco",
                 distrito="Santiago de Surco", provincia="Lima", departamento="Lima",
                 regimen_tributario="RER", nivel_alerta="VERDE",
                 color_identificacion="#3B82F6"),
        ]

        creadas = 0
        for data in empresas_data:
            existe = db.query(Empresa).filter_by(
                ruc=data["ruc"], contador_id=contador.id
            ).first()
            if not existe:
                db.add(Empresa(contador_id=contador.id, **data))
                creadas += 1

        db.commit()
        total = db.query(Empresa).filter_by(contador_id=contador.id).count()
        print(f"  [OK] {creadas} empresas creadas ({total} total para contador id={contador.id})")

        # ── Cronograma SUNAT ──────────────────────────────
        cronograma = [
            (4, "0",    date(2025, 5, 14)), (4, "1",    date(2025, 5, 15)),
            (4, "2",    date(2025, 5, 16)), (4, "3",    date(2025, 5, 19)),
            (4, "4",    date(2025, 5, 20)), (4, "5",    date(2025, 5, 21)),
            (4, "6",    date(2025, 5, 22)), (4, "7",    date(2025, 5, 23)),
            (4, "8",    date(2025, 5, 26)), (4, "9",    date(2025, 5, 27)),
            (4, "UESP", date(2025, 5, 28)),
            (5, "0",    date(2025, 6, 13)), (5, "1",    date(2025, 6, 16)),
            (5, "2",    date(2025, 6, 17)), (5, "3",    date(2025, 6, 18)),
            (5, "4",    date(2025, 6, 19)), (5, "5",    date(2025, 6, 20)),
            (5, "6",    date(2025, 6, 23)), (5, "7",    date(2025, 6, 24)),
            (5, "8",    date(2025, 6, 25)), (5, "9",    date(2025, 6, 26)),
            (5, "UESP", date(2025, 6, 27)),
        ]
        for mes, digito, fecha in cronograma:
            if not db.query(CronogramaSunat).filter_by(
                ano=2025, mes=mes, ultimo_digito_ruc=digito
            ).first():
                db.add(CronogramaSunat(
                    ano=2025, mes=mes,
                    ultimo_digito_ruc=digito,
                    fecha_pdt621=fecha,
                ))
        db.commit()
        print("  [OK] Cronograma SUNAT 2025")

        print("\nSeed completado!")
        print("  Admin:    admin@felicita.pe     / admin123")
        print("  Contador: ana.perez@felicita.pe / contador123")

    except Exception as e:
        db.rollback()
        print(f"\n[ERROR] {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed()