"""
Servicio de notificaciones de pago mensual.
Canales: in-app, email (SMTP), WhatsApp (Twilio).
"""
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List
from sqlalchemy.orm import Session

from app.models.models import (
    NotificacionPago, PDT621, Empresa, Usuario,
)

logger = logging.getLogger(__name__)

# ══ Configuracion SMTP (mover a variables de entorno en produccion) ══
SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USER = ""      # tu.email@gmail.com
SMTP_PASS = ""      # app password de Gmail
SMTP_FROM = "FELICITA <noreply@felicita.pe>"

# ══ Configuracion Twilio (mover a variables de entorno) ══
TWILIO_SID = ""
TWILIO_TOKEN = ""
TWILIO_FROM = ""     # whatsapp:+14155238886 (sandbox Twilio)


def generar_notificaciones_mes(
    db: Session, contador_id: int, ano: int, mes: int
) -> List[NotificacionPago]:
    """
    Genera notificaciones de pago para todas las empresas del contador
    que tengan PDTs en el periodo dado.
    """
    empresas = db.query(Empresa).filter_by(
        contador_id=contador_id, activa=True
    ).all()

    notificaciones = []
    for emp in empresas:
        pdt = db.query(PDT621).filter_by(
            empresa_id=emp.id, ano=ano, mes=mes
        ).first()
        if not pdt or pdt.estado == "ACCEPTED":
            continue

        # No duplicar
        existe = db.query(NotificacionPago).filter_by(
            empresa_id=emp.id, ano=ano, mes=mes, tipo="PAGO_MENSUAL"
        ).first()
        if existe:
            continue

        igv = float(pdt.c184_igv_a_pagar or 0)
        renta = float(pdt.c318_renta_a_pagar or 0)
        total = float(pdt.total_a_pagar or 0)

        titulo = f"Pago {emp.razon_social} - {_mes_label(mes)} {ano}"
        partes = []
        if igv > 0: partes.append(f"IGV: S/ {igv:,.2f}")
        if renta > 0: partes.append(f"Renta: S/ {renta:,.2f}")
        mensaje = (
            f"Empresa: {emp.razon_social} (RUC {emp.ruc})\n"
            f"Periodo: {_mes_label(mes)} {ano}\n"
            f"{'  |  '.join(partes)}\n"
            f"TOTAL A PAGAR: S/ {total:,.2f}\n"
            f"Vencimiento: {pdt.fecha_vencimiento.strftime('%d/%m/%Y')}"
        )

        notif = NotificacionPago(
            empresa_id=emp.id,
            contador_id=contador_id,
            ano=ano, mes=mes,
            igv_a_pagar=Decimal(str(igv)),
            renta_a_pagar=Decimal(str(renta)),
            total_a_pagar=Decimal(str(total)),
            fecha_vencimiento=pdt.fecha_vencimiento,
            titulo=titulo,
            mensaje=mensaje,
            tipo="PAGO_MENSUAL",
        )
        db.add(notif)
        notificaciones.append(notif)

    db.commit()
    return notificaciones


def enviar_email(destinatario: str, asunto: str, cuerpo: str) -> bool:
    """Envia email via SMTP. Retorna True si fue exitoso."""
    if not SMTP_USER or not SMTP_PASS:
        logger.warning("SMTP no configurado, saltando envio de email")
        return False
    try:
        msg = MIMEMultipart()
        msg["From"] = SMTP_FROM
        msg["To"] = destinatario
        msg["Subject"] = asunto
        msg.attach(MIMEText(cuerpo, "plain", "utf-8"))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
        logger.info(f"Email enviado a {destinatario}")
        return True
    except Exception as e:
        logger.error(f"Error enviando email a {destinatario}: {e}")
        return False


def enviar_whatsapp(telefono: str, mensaje: str) -> bool:
    """Envia WhatsApp via Twilio. Retorna True si fue exitoso."""
    if not TWILIO_SID or not TWILIO_TOKEN:
        logger.warning("Twilio no configurado, saltando envio WhatsApp")
        return False
    try:
        from twilio.rest import Client
        client = Client(TWILIO_SID, TWILIO_TOKEN)
        msg = client.messages.create(
            body=mensaje,
            from_=TWILIO_FROM,
            to=f"whatsapp:{telefono}",
        )
        logger.info(f"WhatsApp enviado a {telefono}: SID {msg.sid}")
        return True
    except Exception as e:
        logger.error(f"Error enviando WhatsApp a {telefono}: {e}")
        return False


def enviar_notificacion_multicanal(
    db: Session, notif: NotificacionPago,
    email_destino: Optional[str] = None,
    whatsapp_destino: Optional[str] = None,
) -> dict:
    """Envia una notificacion por todos los canales configurados."""
    resultado = {"app": True, "email": False, "whatsapp": False}

    # In-app siempre
    notif.enviado_app = True

    # Email
    if email_destino:
        ok = enviar_email(email_destino, notif.titulo, notif.mensaje)
        notif.enviado_email = ok
        resultado["email"] = ok

    # WhatsApp
    if whatsapp_destino:
        ok = enviar_whatsapp(whatsapp_destino, notif.mensaje)
        notif.enviado_whatsapp = ok
        resultado["whatsapp"] = ok

    db.commit()
    return resultado


def _mes_label(mes: int) -> str:
    meses = {1:"Enero",2:"Febrero",3:"Marzo",4:"Abril",5:"Mayo",6:"Junio",
             7:"Julio",8:"Agosto",9:"Septiembre",10:"Octubre",11:"Noviembre",12:"Diciembre"}
    return meses.get(mes, str(mes))
