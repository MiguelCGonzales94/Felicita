"""
Servicio de PDT 621 - Logica de negocio.
Ahora usa credenciales reales de la empresa para SIRE.
"""
from sqlalchemy.orm import Session
from fastapi import HTTPException
from datetime import date
from decimal import Decimal

from app.models.models import PDT621, Empresa, CronogramaSunat
from app.services.sire_service import descargar_rvie, descargar_rce
from app.services.pdt621_calculo_service import (
    calcular_pdt621, InputsCalculoIGV, InputsCalculoRenta
)
from app.services.empresa_service import obtener_credenciales_sunat


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
    )
    db.add(pdt)
    db.commit()
    db.refresh(pdt)
    return pdt


def importar_desde_sire(db: Session, pdt: PDT621, empresa: Empresa) -> dict:
    """Descarga RVIE/RCE de SUNAT (real o mock) y actualiza el PDT."""
    # Obtener credenciales de la empresa (desencriptadas)
    credenciales = obtener_credenciales_sunat(empresa)

    # Descargar (intenta real, cae a mock si no hay creds)
    rvie = descargar_rvie(empresa.ruc, pdt.ano, pdt.mes, credenciales)
    rce = descargar_rce(empresa.ruc, pdt.ano, pdt.mes, credenciales)

    # Actualizar campos del PDT
    pdt.c100_ventas_gravadas = rvie.total_ventas_gravadas
    pdt.c104_ventas_no_gravadas = rvie.total_ventas_no_gravadas
    pdt.c105_exportaciones = rvie.total_exportaciones
    pdt.c140_subtotal_ventas = (
        rvie.total_ventas_gravadas + rvie.total_ventas_no_gravadas + rvie.total_exportaciones
    )
    pdt.c140igv_igv_debito = rvie.total_igv_debito
    pdt.c120_compras_gravadas = rce.total_compras_gravadas
    pdt.c180_igv_credito = rce.total_igv_credito
    pdt.c301_ingresos_netos = rvie.total_ventas_gravadas + rvie.total_exportaciones

    db.commit()
    db.refresh(pdt)

    recalcular_pdt(db, pdt, empresa)

    return {
        "fuente": rvie.fuente,  # "SUNAT_SIRE" o "MOCK"
        "ventas": {
            "total_comprobantes": rvie.total_comprobantes,
            "ventas_gravadas": float(rvie.total_ventas_gravadas),
            "ventas_no_gravadas": float(rvie.total_ventas_no_gravadas),
            "exportaciones": float(rvie.total_exportaciones),
            "igv_debito": float(rvie.total_igv_debito),
            "comprobantes": [c.model_dump(mode="json") for c in rvie.comprobantes[:5]],  # preview
        },
        "compras": {
            "total_comprobantes": rce.total_comprobantes,
            "compras_gravadas": float(rce.total_compras_gravadas),
            "igv_credito": float(rce.total_igv_credito),
            "comprobantes": [c.model_dump(mode="json") for c in rce.comprobantes[:5]],
        },
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


def recalcular_pdt(db: Session, pdt: PDT621, empresa: Empresa) -> PDT621:
    """Recalcula todos los totales."""
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
        coeficiente_declarado=empresa.tasa_renta_pc / Decimal("100") if empresa.tasa_renta_pc else None,
        pagos_anticipados=pdt.c311_pagos_anticipados or Decimal("0"),
    )
    resultado = calcular_pdt621(igv_inputs, renta_inputs)

    pdt.c184_igv_a_pagar = resultado.igv.igv_a_pagar
    pdt.c309_pago_a_cuenta_renta = resultado.renta.renta_bruta
    pdt.c318_renta_a_pagar = resultado.renta.renta_a_pagar
    pdt.total_a_pagar = resultado.total_a_pagar

    db.commit()
    db.refresh(pdt)
    return pdt


def aplicar_ajustes(db: Session, pdt: PDT621, empresa: Empresa, ajustes: dict) -> dict:
    """Aplica ajustes y retorna resultado completo."""
    if "retenciones_periodo" in ajustes:
        pdt.c310_retenciones = Decimal(str(ajustes["retenciones_periodo"]))
    if "pagos_anticipados" in ajustes:
        pdt.c311_pagos_anticipados = Decimal(str(ajustes["pagos_anticipados"]))
    db.commit()

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
        coeficiente_declarado=empresa.tasa_renta_pc / Decimal("100") if empresa.tasa_renta_pc else None,
        pagos_anticipados=Decimal(str(ajustes.get("pagos_anticipados", 0))),
        retenciones_renta=Decimal(str(ajustes.get("retenciones_renta", 0))),
        saldo_favor_renta_anterior=Decimal(str(ajustes.get("saldo_favor_renta_anterior", 0))),
        categoria_nrus=ajustes.get("categoria_nrus"),
        ingresos_acumulados_ano=Decimal(str(ajustes.get("ingresos_acumulados_ano", 0))),
    )
    resultado = calcular_pdt621(igv_inputs, renta_inputs)

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


def cambiar_estado(db: Session, pdt: PDT621, nuevo_estado: str,
                   numero_operacion: str = None, mensaje: str = None) -> PDT621:
    estado_actual = pdt.estado
    permitidos = TRANSICIONES_ESTADO.get(estado_actual, [])
    if nuevo_estado not in permitidos:
        raise HTTPException(
            status_code=400,
            detail=f"No se puede pasar de {estado_actual} a {nuevo_estado}. Permitidos: {permitidos}"
        )

    pdt.estado = nuevo_estado
    if nuevo_estado == "SUBMITTED":
        from datetime import datetime
        pdt.fecha_presentacion_sunat = datetime.utcnow()
        if numero_operacion:
            pdt.numero_operacion = numero_operacion
    if nuevo_estado == "REJECTED" and mensaje:
        pdt.mensaje_error_sunat = mensaje

    db.commit()
    db.refresh(pdt)
    return pdt
