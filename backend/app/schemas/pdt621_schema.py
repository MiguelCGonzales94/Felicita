from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, date
from decimal import Decimal


class PDT621Response(BaseModel):
    id: int
    empresa_id: int
    mes: int
    ano: int
    fecha_vencimiento: date
    estado: str
    c100_ventas_gravadas: Decimal
    c104_ventas_no_gravadas: Decimal
    c105_exportaciones: Decimal
    c140_subtotal_ventas: Decimal
    c140igv_igv_debito: Decimal
    c120_compras_gravadas: Decimal
    c180_igv_credito: Decimal
    c184_igv_a_pagar: Decimal
    c301_ingresos_netos: Decimal
    c309_pago_a_cuenta_renta: Decimal
    c310_retenciones: Decimal
    c311_pagos_anticipados: Decimal
    c318_renta_a_pagar: Decimal
    total_a_pagar: Decimal
    nps: Optional[str]
    numero_operacion: Optional[str]
    codigo_rechazo_sunat: Optional[str]
    mensaje_error_sunat: Optional[str]
    fecha_presentacion_sunat: Optional[datetime]
    fecha_creacion: datetime
    model_config = {"from_attributes": True}


class PDT621ListItem(BaseModel):
    id: int
    empresa_id: int
    empresa_nombre: str
    empresa_ruc: str
    empresa_color: str
    mes: int
    ano: int
    fecha_vencimiento: date
    estado: str
    total_a_pagar: Decimal
    igv_a_pagar: Decimal
    renta_a_pagar: Decimal
    nps: Optional[str]
    dias_para_vencer: int
    model_config = {"from_attributes": True}


class PDT621Generar(BaseModel):
    ano: int
    mes: int


class PDT621Ajustes(BaseModel):
    saldo_favor_anterior: Optional[Decimal] = Decimal("0")
    percepciones_periodo: Optional[Decimal] = Decimal("0")
    percepciones_arrastre: Optional[Decimal] = Decimal("0")
    retenciones_periodo: Optional[Decimal] = Decimal("0")
    retenciones_arrastre: Optional[Decimal] = Decimal("0")
    pagos_anticipados: Optional[Decimal] = Decimal("0")
    retenciones_renta: Optional[Decimal] = Decimal("0")
    saldo_favor_renta_anterior: Optional[Decimal] = Decimal("0")
    categoria_nrus: Optional[int] = None
    ingresos_acumulados_ano: Optional[Decimal] = Decimal("0")


class PDT621CambioEstado(BaseModel):
    nuevo_estado: str
    numero_operacion: Optional[str] = None
    mensaje: Optional[str] = None


class ImportacionSunatResponse(BaseModel):
    ventas: dict
    compras: dict
