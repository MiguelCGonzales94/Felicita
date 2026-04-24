from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import extract
from typing import List, Optional
from datetime import date, timedelta
from pydantic import BaseModel

from app.database import get_db
from app.models.models import (
    CalendarioTributario, Empresa, CronogramaSunat, PDT621
)
from app.dependencies.auth_dependency import require_contador
from app.models.models import Usuario

router = APIRouter(prefix="/api/v1/calendario", tags=["Calendario"])


# ── Schemas ───────────────────────────────────────────────
class EventoCalendarioResponse(BaseModel):
    id: int
    empresa_id: int
    empresa_nombre: str
    empresa_ruc: str
    empresa_color: str
    tipo_evento: str
    titulo: str
    descripcion: Optional[str]
    fecha_vencimiento: date
    estado: str
    pdt621_id: Optional[int]

    model_config = {"from_attributes": True}


class DiaCalendario(BaseModel):
    fecha: date
    eventos: List[EventoCalendarioResponse]


class ProximoVencimiento(BaseModel):
    empresa_id: int
    empresa_nombre: str
    empresa_ruc: str
    empresa_color: str
    nivel_alerta: str
    tipo_evento: str
    fecha_vencimiento: date
    dias_restantes: int
    estado: str


# ── Helpers ───────────────────────────────────────────────
def get_fecha_vencimiento_pdt621(db: Session, ruc: str, ano: int, mes: int) -> Optional[date]:
    """Obtiene fecha de vencimiento PDT 621 según cronograma SUNAT."""
    ultimo_digito = ruc[-1] if ruc else "0"
    cronograma = db.query(CronogramaSunat).filter_by(
        ano=ano, mes=mes, ultimo_digito_ruc=ultimo_digito
    ).first()
    return cronograma.fecha_pdt621 if cronograma else None


def generar_eventos_empresa(db: Session, empresa: Empresa, meses: int = 3):
    """Genera eventos de calendario para una empresa (próximos N meses)."""
    hoy = date.today()
    eventos_creados = 0

    for i in range(meses):
        # Calcular mes/año a generar
        mes_target = (hoy.month + i - 1) % 12 + 1
        ano_target = hoy.year + ((hoy.month + i - 1) // 12)

        # Mes de declaración es el anterior
        mes_declaracion = mes_target - 1 if mes_target > 1 else 12
        ano_declaracion = ano_target if mes_target > 1 else ano_target - 1

        fecha_venc = get_fecha_vencimiento_pdt621(
            db, empresa.ruc, ano_target, mes_declaracion
        )
        if not fecha_venc:
            continue

        # Verificar si ya existe el evento
        existe = db.query(CalendarioTributario).filter_by(
            empresa_id=empresa.id,
            tipo_evento="PDT_621",
            fecha_vencimiento=fecha_venc,
        ).first()

        if not existe:
            titulo = f"PDT 621 - {empresa.razon_social[:30]}"
            descripcion = f"Declaración mensual IGV-Renta periodo {mes_declaracion:02d}/{ano_declaracion}"

            evento = CalendarioTributario(
                contador_id=empresa.contador_id,
                empresa_id=empresa.id,
                tipo_evento="PDT_621",
                titulo=titulo,
                descripcion=descripcion,
                fecha_evento=fecha_venc,
                fecha_vencimiento=fecha_venc,
                estado="PENDIENTE",
                color=empresa.color_identificacion,
                es_recurrente=True,
                frecuencia="MENSUAL",
            )
            db.add(evento)
            eventos_creados += 1

    if eventos_creados > 0:
        db.commit()

    return eventos_creados


# ── Endpoints ─────────────────────────────────────────────
@router.get("/mes/{ano}/{mes}")
def calendario_mes(
    ano: int,
    mes: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Vista mensual del calendario consolidado del contador."""
    # Auto-generar eventos si no existen
    empresas = db.query(Empresa).filter_by(
        contador_id=current_user.id, activa=True
    ).all()

    for empresa in empresas:
        generar_eventos_empresa(db, empresa, meses=4)

    # Consultar eventos del mes
    eventos = (
        db.query(CalendarioTributario, Empresa)
        .join(Empresa, CalendarioTributario.empresa_id == Empresa.id)
        .filter(
            CalendarioTributario.contador_id == current_user.id,
            extract("year", CalendarioTributario.fecha_vencimiento) == ano,
            extract("month", CalendarioTributario.fecha_vencimiento) == mes,
        )
        .order_by(CalendarioTributario.fecha_vencimiento, Empresa.razon_social)
        .all()
    )

    # Agrupar por día
    dias: dict = {}
    for evento, empresa in eventos:
        fecha_str = str(evento.fecha_vencimiento)
        if fecha_str not in dias:
            dias[fecha_str] = []
        dias[fecha_str].append({
            "id": evento.id,
            "empresa_id": empresa.id,
            "empresa_nombre": empresa.razon_social,
            "empresa_ruc": empresa.ruc,
            "empresa_color": empresa.color_identificacion,
            "tipo_evento": evento.tipo_evento,
            "titulo": evento.titulo,
            "descripcion": evento.descripcion,
            "fecha_vencimiento": str(evento.fecha_vencimiento),
            "estado": evento.estado,
            "pdt621_id": evento.pdt621_id,
            "nivel_alerta": empresa.nivel_alerta,
        })

    return {
        "ano": ano,
        "mes": mes,
        "total_eventos": len(eventos),
        "dias": dias,
    }


@router.get("/proximos")
def proximos_vencimientos(
    dias: int = 14,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Próximos vencimientos en los siguientes N días."""
    hoy = date.today()
    hasta = hoy + timedelta(days=dias)

    eventos = (
        db.query(CalendarioTributario, Empresa)
        .join(Empresa, CalendarioTributario.empresa_id == Empresa.id)
        .filter(
            CalendarioTributario.contador_id == current_user.id,
            CalendarioTributario.fecha_vencimiento >= hoy,
            CalendarioTributario.fecha_vencimiento <= hasta,
            CalendarioTributario.estado == "PENDIENTE",
        )
        .order_by(CalendarioTributario.fecha_vencimiento)
        .all()
    )

    resultado = []
    for evento, empresa in eventos:
        dias_restantes = (evento.fecha_vencimiento - hoy).days
        resultado.append({
            "empresa_id": empresa.id,
            "empresa_nombre": empresa.razon_social,
            "empresa_ruc": empresa.ruc,
            "empresa_color": empresa.color_identificacion,
            "nivel_alerta": empresa.nivel_alerta,
            "tipo_evento": evento.tipo_evento,
            "fecha_vencimiento": str(evento.fecha_vencimiento),
            "dias_restantes": dias_restantes,
            "estado": evento.estado,
            "id": evento.id,
        })

    return {"total": len(resultado), "vencimientos": resultado}


@router.put("/{evento_id}/completar")
def marcar_completado(
    evento_id: int,
    db: Session = Depends(get_db),
    current_user: Usuario = Depends(require_contador),
):
    """Marcar un evento del calendario como completado."""
    evento = db.query(CalendarioTributario).filter(
        CalendarioTributario.id == evento_id,
        CalendarioTributario.contador_id == current_user.id,
    ).first()

    if not evento:
        raise HTTPException(status_code=404, detail="Evento no encontrado")

    evento.estado = "COMPLETADO"
    db.commit()
    return {"message": "Evento marcado como completado"}