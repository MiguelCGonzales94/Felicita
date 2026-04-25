"""
Endpoints de notificaciones de pago mensual.
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import Optional

from app.database import get_db
from app.models.models import Usuario, NotificacionPago
from app.dependencies.auth_dependency import require_contador
from app.services.notificacion_service import (
    generar_notificaciones_mes, enviar_notificacion_multicanal,
)

router = APIRouter(prefix="/api/v1", tags=["Notificaciones"])


@router.get("/notificaciones")
def listar_notificaciones(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
    leido: Optional[bool] = Query(None),
    tipo: Optional[str] = Query(None),
    limit: int = Query(20, le=100),
):
    """Lista notificaciones del contador, mas recientes primero."""
    query = db.query(NotificacionPago).filter_by(
        contador_id=current_user.id
    )
    if leido is not None:
        query = query.filter_by(leido=leido)
    if tipo:
        query = query.filter_by(tipo=tipo)

    notifs = query.order_by(desc(NotificacionPago.fecha_envio)).limit(limit).all()
    no_leidas = db.query(NotificacionPago).filter_by(
        contador_id=current_user.id, leido=False
    ).count()

    return {
        "total": len(notifs),
        "no_leidas": no_leidas,
        "notificaciones": [
            {
                "id": n.id,
                "empresa_id": n.empresa_id,
                "titulo": n.titulo,
                "mensaje": n.mensaje,
                "tipo": n.tipo,
                "ano": n.ano, "mes": n.mes,
                "igv_a_pagar": float(n.igv_a_pagar or 0),
                "renta_a_pagar": float(n.renta_a_pagar or 0),
                "total_a_pagar": float(n.total_a_pagar or 0),
                "fecha_vencimiento": str(n.fecha_vencimiento),
                "leido": n.leido,
                "enviado_app": n.enviado_app,
                "enviado_email": n.enviado_email,
                "enviado_whatsapp": n.enviado_whatsapp,
                "fecha_envio": str(n.fecha_envio),
            }
            for n in notifs
        ],
    }


@router.post("/notificaciones/generar")
def generar_notificaciones(
    ano: int = Query(...),
    mes: int = Query(...),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Genera notificaciones de pago para el periodo dado."""
    if mes < 1 or mes > 12:
        raise HTTPException(400, "Mes invalido")
    notifs = generar_notificaciones_mes(db, current_user.id, ano, mes)
    return {
        "generadas": len(notifs),
        "mensaje": f"Se generaron {len(notifs)} notificaciones para {mes}/{ano}",
    }


@router.post("/notificaciones/{notif_id}/enviar")
def enviar_notificacion(
    notif_id: int,
    email: Optional[str] = Query(None),
    whatsapp: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Envia una notificacion por los canales indicados."""
    notif = db.query(NotificacionPago).filter_by(
        id=notif_id, contador_id=current_user.id
    ).first()
    if not notif:
        raise HTTPException(404, "Notificacion no encontrada")

    resultado = enviar_notificacion_multicanal(db, notif, email, whatsapp)
    return resultado


@router.patch("/notificaciones/{notif_id}/leer")
def marcar_leida(
    notif_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    notif = db.query(NotificacionPago).filter_by(
        id=notif_id, contador_id=current_user.id
    ).first()
    if not notif:
        raise HTTPException(404, "Notificacion no encontrada")
    from datetime import datetime
    notif.leido = True
    notif.fecha_lectura = datetime.utcnow()
    db.commit()
    return {"ok": True}


@router.patch("/notificaciones/leer-todas")
def marcar_todas_leidas(
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    from datetime import datetime
    db.query(NotificacionPago).filter_by(
        contador_id=current_user.id, leido=False
    ).update({"leido": True, "fecha_lectura": datetime.utcnow()})
    db.commit()
    return {"ok": True}
