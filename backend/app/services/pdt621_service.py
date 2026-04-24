"""
Servicio de PDT 621 - Logica de negocio.
Persiste los comprobantes importados y recalcula usando solo los incluidos.
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException
from datetime import date, datetime
from decimal import Decimal
from typing import List

from app.models.models import (
    PDT621, Empresa, CronogramaSunat,
    PDT621VentaDetalle, PDT621CompraDetalle,
)
from app.services.sire_service import descargar_rvie, descargar_rce
from app.services.pdt621_calculo_service import (
    calcular_pdt621, InputsCalculoIGV, InputsCalculoRenta
)
from app.services.empresa_service import obtener_credenciales_sunat
from app.services.configuracion_tributaria_service import obtener_o_crear_configuracion, config_a_snapshot


TRANSICIONES_ESTADO = {
    "DRAFT":     ["GENERATED", "DRAFT"],
    "GENERATED": ["SUBMITTED", "DRAFT"],
    "SUBMITTED": ["ACCEPTED", "REJECTED"],
    "REJECTED":  ["DRAFT"],
    "ACCEPTED":  [],
}


def obtener_fecha_vencimiento(db: Session, empresa_ruc: str, ano: int, mes: int) -> date:
    """Fecha de vencimiento segun cronograma SUNAT. Fallback: dia 15 del mes siguiente."""
    ultimo_digito = empresa_ruc[-1]
    mes_venc = mes + 1
    ano_venc = ano
    if mes_venc > 12:
        mes_venc = 1
        ano_venc += 1

    cronograma = db.query(CronogramaSunat).filter_by(
        ano=ano_venc, mes=mes_venc, ultimo_digito_ruc=ultimo_digito
    ).first()
    if cronograma and cronograma.fecha_pdt621:
        return cronograma.fecha_pdt621
    return date(ano_venc, mes_venc, 15)


def obtener_o_crear_pdt(db: Session, empresa: Empresa, ano: int, mes: int) -> PDT621:
    pdt = db.query(PDT621).filter_by(
        empresa_id=empresa.id, ano=ano, mes=mes
    ).first()
    if pdt:
        return pdt

    fecha_venc = obtener_fecha_vencimiento(db, empresa.ruc, ano, mes)
    pdt = PDT621(
        empresa_id=empresa.id,
        ano=ano, mes=mes,
        fecha_vencimiento=fecha_venc,
        estado="DRAFT",
        config_snapshot=config_a_snapshot(obtener_o_crear_configuracion(db, empresa.id)),
    )
    db.add(pdt)
    db.commit()
    db.refresh(pdt)
    return pdt


def _fecha_from_str(fecha_str: str) -> date:
    """Convierte 'YYYY-MM-DD' a date."""
    return datetime.strptime(fecha_str, "%Y-%m-%d").date()


def importar_desde_sire(db: Session, pdt: PDT621, empresa: Empresa) -> dict:
    """
    Descarga RVIE/RCE de SUNAT (real o mock), persiste los comprobantes
    en pdt621_ventas_detalle y pdt621_compras_detalle, y recalcula el PDT
    usando solo los incluidos (todos incluidos por defecto al importar).
    """
    credenciales = obtener_credenciales_sunat(empresa)
    rvie = descargar_rvie(empresa.ruc, pdt.ano, pdt.mes, credenciales)
    rce = descargar_rce(empresa.ruc, pdt.ano, pdt.mes, credenciales)

    # Borrar detalles existentes antes de reimportar
    db.query(PDT621VentaDetalle).filter_by(pdt621_id=pdt.id).delete()
    db.query(PDT621CompraDetalle).filter_by(pdt621_id=pdt.id).delete()
    db.commit()

    # Insertar ventas
    for c in rvie.comprobantes:
        db.add(PDT621VentaDetalle(
            pdt621_id=pdt.id,
            tipo_comprobante=c.tipo_comprobante,
            serie=c.serie,
            numero=c.numero,
            fecha_emision=_fecha_from_str(c.fecha_emision),
            ruc_cliente=c.ruc_contraparte,
            razon_social_cliente=c.nombre_contraparte,
            base_gravada=c.base_gravada,
            base_no_gravada=c.base_no_gravada,
            exportacion=c.exportacion,
            igv=c.igv,
            total=c.total,
            incluido=True,
            fuente=rvie.fuente,
        ))

    # Insertar compras
    for c in rce.comprobantes:
        db.add(PDT621CompraDetalle(
            pdt621_id=pdt.id,
            tipo_comprobante=c.tipo_comprobante,
            serie=c.serie,
            numero=c.numero,
            fecha_emision=_fecha_from_str(c.fecha_emision),
            ruc_proveedor=c.ruc_contraparte,
            razon_social_proveedor=c.nombre_contraparte,
            base_gravada=c.base_gravada,
            base_no_gravada=c.base_no_gravada,
            igv=c.igv,
            total=c.total,
            tipo_destino="GRAVADA_EXCLUSIVA",
            incluido=True,
            fuente=rce.fuente,
        ))

    db.commit()

    # Recalcular PDT con los comprobantes recien insertados (todos incluidos)
    recalcular_desde_detalle(db, pdt, empresa)
    db.refresh(pdt)

    return {
        "fuente": rvie.fuente,
        "ventas": {
            "total_comprobantes": rvie.total_comprobantes,
            "ventas_gravadas": float(rvie.total_ventas_gravadas),
            "ventas_no_gravadas": float(rvie.total_ventas_no_gravadas),
            "exportaciones": float(rvie.total_exportaciones),
            "igv_debito": float(rvie.total_igv_debito),
        },
        "compras": {
            "total_comprobantes": rce.total_comprobantes,
            "compras_gravadas": float(rce.total_compras_gravadas),
            "igv_credito": float(rce.total_igv_credito),
        },
    }


def _totales_ventas_incluidas(db: Session, pdt_id: int) -> dict:
    """Suma los comprobantes de venta marcados como incluidos."""
    ventas = db.query(PDT621VentaDetalle).filter_by(
        pdt621_id=pdt_id, incluido=True
    ).all()
    return {
        "gravadas": sum((v.base_gravada or Decimal("0")) for v in ventas),
        "no_gravadas": sum((v.base_no_gravada or Decimal("0")) for v in ventas),
        "exportaciones": sum((v.exportacion or Decimal("0")) for v in ventas),
        "igv_debito": sum((v.igv or Decimal("0")) for v in ventas),
        "total": sum((v.total or Decimal("0")) for v in ventas),
    }


def _totales_compras_incluidas(db: Session, pdt_id: int) -> dict:
    """Suma los comprobantes de compra marcados como incluidos."""
    compras = db.query(PDT621CompraDetalle).filter_by(
        pdt621_id=pdt_id, incluido=True
    ).all()
    return {
        "gravadas": sum((c.base_gravada or Decimal("0")) for c in compras),
        "no_gravadas": sum((c.base_no_gravada or Decimal("0")) for c in compras),
        "igv_credito": sum((c.igv or Decimal("0")) for c in compras),
        "total": sum((c.total or Decimal("0")) for c in compras),
    }


def recalcular_desde_detalle(db: Session, pdt: PDT621, empresa: Empresa) -> PDT621:
    """
    Recalcula el PDT usando los totales de los comprobantes incluidos.
    Respeta los ajustes manuales (percepciones, retenciones, saldo a favor).
    """
    v = _totales_ventas_incluidas(db, pdt.id)
    c = _totales_compras_incluidas(db, pdt.id)

    # Actualizar campos base del PDT
    pdt.c100_ventas_gravadas = v["gravadas"]
    pdt.c104_ventas_no_gravadas = v["no_gravadas"]
    pdt.c105_exportaciones = v["exportaciones"]
    pdt.c140_subtotal_ventas = v["gravadas"] + v["no_gravadas"] + v["exportaciones"]
    pdt.c140igv_igv_debito = v["igv_debito"]
    pdt.c120_compras_gravadas = c["gravadas"]
    pdt.c180_igv_credito = c["igv_credito"]
    pdt.c301_ingresos_netos = v["gravadas"] + v["exportaciones"]

    db.commit()
    db.refresh(pdt)

    # Recalcular totales finales (IGV, renta, total)
    recalcular_pdt(db, pdt, empresa)
    return pdt


def recalcular_pdt(db: Session, pdt: PDT621, empresa: Empresa) -> PDT621:
    """Recalcula IGV y renta aplicando los ajustes actuales."""
    igv_inputs = InputsCalculoIGV(
        ventas_gravadas=pdt.c100_ventas_gravadas or Decimal("0"),
        ventas_no_gravadas=pdt.c104_ventas_no_gravadas or Decimal("0"),
        exportaciones=pdt.c105_exportaciones or Decimal("0"),
        compras_gravadas=pdt.c120_compras_gravadas or Decimal("0"),
        saldo_favor_anterior=Decimal("0"),
        percepciones_periodo=Decimal("0"),
        retenciones_periodo=pdt.c310_retenciones or Decimal("0"),
    )
    renta_inputs = InputsCalculoRenta(
        regimen=empresa.regimen_tributario,
        ingresos_netos=pdt.c301_ingresos_netos or Decimal("0"),
        coeficiente_declarado=(
            empresa.tasa_renta_pc / Decimal("100")
            if empresa.tasa_renta_pc else None
        ),
        pagos_anticipados=pdt.c311_pagos_anticipados or Decimal("0"),
    )
    resultado = calcular_pdt621(igv_inputs, renta_inputs, config=pdt.config_snapshot)

    pdt.c184_igv_a_pagar = resultado.igv.igv_a_pagar
    pdt.c309_pago_a_cuenta_renta = resultado.renta.renta_bruta
    pdt.c318_renta_a_pagar = resultado.renta.renta_a_pagar
    pdt.total_a_pagar = resultado.total_a_pagar

    db.commit()
    db.refresh(pdt)
    return pdt


def aplicar_ajustes(db: Session, pdt: PDT621, empresa: Empresa, ajustes: dict) -> dict:
    """Aplica ajustes (percepciones, retenciones, saldo a favor) y recalcula todo."""
    igv_inputs = InputsCalculoIGV(
        ventas_gravadas=pdt.c100_ventas_gravadas or Decimal("0"),
        ventas_no_gravadas=pdt.c104_ventas_no_gravadas or Decimal("0"),
        exportaciones=pdt.c105_exportaciones or Decimal("0"),
        compras_gravadas=pdt.c120_compras_gravadas or Decimal("0"),
        saldo_favor_anterior=Decimal(str(ajustes.get("saldo_favor_anterior", 0))),
        percepciones_periodo=Decimal(str(ajustes.get("percepciones_periodo", 0))),
        percepciones_arrastre=Decimal(str(ajustes.get("percepciones_arrastre", 0))),
        retenciones_periodo=Decimal(str(ajustes.get("retenciones_periodo", 0))),
        retenciones_arrastre=Decimal(str(ajustes.get("retenciones_arrastre", 0))),
    )
    renta_inputs = InputsCalculoRenta(
        regimen=empresa.regimen_tributario,
        ingresos_netos=pdt.c301_ingresos_netos or Decimal("0"),
        coeficiente_declarado=(
            empresa.tasa_renta_pc / Decimal("100")
            if empresa.tasa_renta_pc else None
        ),
        pagos_anticipados=Decimal(str(ajustes.get("pagos_anticipados", 0))),
        retenciones_renta=Decimal(str(ajustes.get("retenciones_renta", 0))),
        saldo_favor_renta_anterior=Decimal(str(ajustes.get("saldo_favor_renta_anterior", 0))),
        categoria_nrus=ajustes.get("categoria_nrus"),
        ingresos_acumulados_ano=Decimal(str(ajustes.get("ingresos_acumulados_ano", 0))),
    )
    resultado = calcular_pdt621(igv_inputs, renta_inputs, config=pdt.config_snapshot)

    pdt.c310_retenciones = Decimal(str(ajustes.get("retenciones_periodo", 0)))
    pdt.c311_pagos_anticipados = Decimal(str(ajustes.get("pagos_anticipados", 0)))
    pdt.c184_igv_a_pagar = resultado.igv.igv_a_pagar
    pdt.c309_pago_a_cuenta_renta = resultado.renta.renta_bruta
    pdt.c318_renta_a_pagar = resultado.renta.renta_a_pagar
    pdt.total_a_pagar = resultado.total_a_pagar

    db.commit()
    db.refresh(pdt)

    return {
        "igv": resultado.igv.model_dump(mode="json"),
        "renta": resultado.renta.model_dump(mode="json"),
        "total_a_pagar": float(resultado.total_a_pagar),
    }


def obtener_saldo_favor_mes_anterior(db: Session, empresa_id: int, ano: int, mes: int) -> Decimal:
    """Sugiere saldo a favor del mes anterior."""
    mes_ant = mes - 1
    ano_ant = ano
    if mes_ant == 0:
        mes_ant = 12
        ano_ant -= 1

    pdt_anterior = db.query(PDT621).filter_by(
        empresa_id=empresa_id, ano=ano_ant, mes=mes_ant
    ).first()
    if not pdt_anterior:
        return Decimal("0")

    debito = pdt_anterior.c140igv_igv_debito or Decimal("0")
    credito = pdt_anterior.c180_igv_credito or Decimal("0")
    diferencia = credito - debito
    return max(Decimal("0"), diferencia)


def aplicar_seleccion_ventas(
    db: Session, pdt: PDT621, empresa: Empresa, selecciones: List[dict]
) -> PDT621:
    """
    Aplica la seleccion de comprobantes de venta (incluir/excluir) y recalcula.
    Entrada: lista de {id, incluido}.
    """
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(
            status_code=400,
            detail=f"No se puede modificar un PDT en estado {pdt.estado}",
        )

    ids_validos = {
        d.id: d for d in db.query(PDT621VentaDetalle).filter_by(pdt621_id=pdt.id).all()
    }
    for sel in selecciones:
        detalle = ids_validos.get(sel["id"])
        if detalle:
            detalle.incluido = bool(sel["incluido"])
    db.commit()

    return recalcular_desde_detalle(db, pdt, empresa)


def aplicar_seleccion_compras(
    db: Session, pdt: PDT621, empresa: Empresa, selecciones: List[dict]
) -> PDT621:
    """Aplica la seleccion de comprobantes de compra y recalcula."""
    if pdt.estado in ("SUBMITTED", "ACCEPTED"):
        raise HTTPException(
            status_code=400,
            detail=f"No se puede modificar un PDT en estado {pdt.estado}",
        )

    ids_validos = {
        d.id: d for d in db.query(PDT621CompraDetalle).filter_by(pdt621_id=pdt.id).all()
    }
    for sel in selecciones:
        detalle = ids_validos.get(sel["id"])
        if detalle:
            detalle.incluido = bool(sel["incluido"])
    db.commit()

    return recalcular_desde_detalle(db, pdt, empresa)


def cambiar_estado(
    db: Session, pdt: PDT621, nuevo_estado: str,
    numero_operacion: str = None, mensaje: str = None
) -> PDT621:
    permitidos = TRANSICIONES_ESTADO.get(pdt.estado, [])
    if nuevo_estado not in permitidos:
        raise HTTPException(
            status_code=400,
            detail=f"Transicion no valida: {pdt.estado} -> {nuevo_estado}. Permitidos: {permitidos}",
        )

    pdt.estado = nuevo_estado
    if nuevo_estado == "SUBMITTED":
        pdt.fecha_presentacion_sunat = datetime.utcnow()
        if numero_operacion:
            pdt.numero_operacion = numero_operacion
    if nuevo_estado == "REJECTED" and mensaje:
        pdt.mensaje_error_sunat = mensaje

    db.commit()
    db.refresh(pdt)
    return pdt
