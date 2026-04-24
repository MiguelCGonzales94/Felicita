"""
Servicio de Empresas - Logica de negocio.
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status
from datetime import date, timedelta

from app.models.models import Usuario, Empresa, PlanSuscripcion, LogEvento
from app.utils.ruc_validator import validar_ruc_completo
from app.utils.encryption import encrypt_text, decrypt_text


def validar_limite_plan(db: Session, contador: Usuario) -> None:
    plan = db.query(PlanSuscripcion).filter_by(nombre=contador.plan_actual).first()
    if not plan:
        raise HTTPException(status_code=500, detail=f"Plan {contador.plan_actual} no configurado")
    total = db.query(func.count(Empresa.id)).filter(
        Empresa.contador_id == contador.id,
        Empresa.activa == True,
    ).scalar()
    if total >= plan.max_empresas:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Has alcanzado el limite de {plan.max_empresas} empresas de tu plan {plan.nombre}. Actualiza tu plan para agregar mas."
        )


def validar_ruc_empresa(db: Session, contador: Usuario, ruc: str, empresa_id_excluir=None) -> None:
    resultado = validar_ruc_completo(ruc)
    if not resultado["es_valido"]:
        raise HTTPException(status_code=400, detail=resultado["mensaje"])
    query = db.query(Empresa).filter(
        Empresa.ruc == ruc,
        Empresa.contador_id == contador.id,
        Empresa.activa == True,
    )
    if empresa_id_excluir:
        query = query.filter(Empresa.id != empresa_id_excluir)
    if query.first():
        raise HTTPException(status_code=400, detail="Ya tienes una empresa registrada con ese RUC")


def calcular_nivel_alerta(empresa: Empresa, db: Session) -> tuple:
    from app.models.models import CalendarioTributario
    hoy = date.today()
    if empresa.estado_sunat == "OBSERVADO":
        return "ROJO", "RUC observado por SUNAT"
    if empresa.estado_sunat in ("BAJA", "SUSPENDIDO"):
        return "ROJO", f"RUC en estado {empresa.estado_sunat}"
    if empresa.condicion_domicilio == "NO_HABIDO":
        return "ROJO", "Domicilio fiscal NO HABIDO"
    vencidas = db.query(CalendarioTributario).filter(
        CalendarioTributario.empresa_id == empresa.id,
        CalendarioTributario.estado == "PENDIENTE",
        CalendarioTributario.fecha_vencimiento < hoy,
    ).count()
    if vencidas > 0:
        return "ROJO", f"{vencidas} declaracion(es) vencida(s)"
    proximas = db.query(CalendarioTributario).filter(
        CalendarioTributario.empresa_id == empresa.id,
        CalendarioTributario.estado == "PENDIENTE",
        CalendarioTributario.fecha_vencimiento >= hoy,
        CalendarioTributario.fecha_vencimiento <= hoy + timedelta(days=5),
    ).count()
    if proximas > 0:
        return "AMARILLO", f"{proximas} vencimiento(s) en los proximos 5 dias"
    return "VERDE", None


def actualizar_alertas_empresa(db: Session, empresa: Empresa) -> None:
    nivel, motivo = calcular_nivel_alerta(empresa, db)
    empresa.nivel_alerta = nivel
    empresa.motivo_alerta = motivo
    db.commit()


def registrar_log(db: Session, usuario_id: int, empresa_id, tipo: str, descripcion: str, nivel: str = "INFO") -> None:
    log = LogEvento(usuario_id=usuario_id, empresa_id=empresa_id,
                    tipo_evento=tipo, descripcion=descripcion, nivel=nivel)
    db.add(log)
    db.commit()


def preparar_datos_empresa(data: dict) -> dict:
    """Prepara los datos antes de guardar: encripta credenciales y normaliza."""
    # Clave SOL
    if "clave_sol" in data:
        if data["clave_sol"]:
            data["clave_sol_encrypted"] = encrypt_text(data["clave_sol"])
        del data["clave_sol"]

    # Client ID SUNAT
    if "sunat_client_id" in data:
        if data["sunat_client_id"]:
            data["sunat_client_id_encrypted"] = encrypt_text(data["sunat_client_id"])
        del data["sunat_client_id"]

    # Client Secret SUNAT
    if "sunat_client_secret" in data:
        if data["sunat_client_secret"]:
            data["sunat_client_secret_encrypted"] = encrypt_text(data["sunat_client_secret"])
        del data["sunat_client_secret"]

    # Razon social en mayusculas
    if "razon_social" in data and data["razon_social"]:
        data["razon_social"] = data["razon_social"].strip().upper()

    # RUC sin espacios
    if "ruc" in data and data["ruc"]:
        data["ruc"] = data["ruc"].strip()

    # DNI sin espacios, solo digitos
    if "dni_sol" in data and data["dni_sol"]:
        data["dni_sol"] = "".join(c for c in data["dni_sol"] if c.isdigit())[:8]

    # Validar tipo de acceso
    if "tipo_acceso_sol" in data:
        if data["tipo_acceso_sol"] not in ("RUC", "DNI"):
            data["tipo_acceso_sol"] = "RUC"

    return data


def obtener_credenciales_sunat(empresa: Empresa) -> dict:
    """
    Desencripta y retorna las credenciales para usar en SUNAT API.
    No incluye datos encriptados, solo los valores listos para usar.
    """
    return {
        "tipo_acceso": empresa.tipo_acceso_sol or "RUC",
        "ruc": empresa.ruc,
        "dni": empresa.dni_sol,
        "usuario": empresa.usuario_sol,
        "clave_sol": decrypt_text(empresa.clave_sol_encrypted) if empresa.clave_sol_encrypted else "",
        "client_id": decrypt_text(empresa.sunat_client_id_encrypted) if empresa.sunat_client_id_encrypted else "",
        "client_secret": decrypt_text(empresa.sunat_client_secret_encrypted) if empresa.sunat_client_secret_encrypted else "",
    }
