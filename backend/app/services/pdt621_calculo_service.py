"""
Motor de calculos del PDT 621.
Soporta los 4 regimenes: RG, RMT, RER, NRUS.
"""
from decimal import Decimal
from typing import Optional
from pydantic import BaseModel


# Constantes tributarias
TASA_IGV = Decimal("0.18")
TASA_RG = Decimal("0.015")
TASA_RMT_BAJA = Decimal("0.01")
TASA_RMT_ALTA = Decimal("0.015")
TASA_RER = Decimal("0.015")
UIT_2025 = Decimal("5350")
UIT_2026 = Decimal("5350")

CATEGORIAS_NRUS = {
    1: Decimal("20"),
    2: Decimal("50"),
}


class InputsCalculoIGV(BaseModel):
    ventas_gravadas: Decimal = Decimal("0")
    ventas_no_gravadas: Decimal = Decimal("0")
    exportaciones: Decimal = Decimal("0")
    compras_gravadas: Decimal = Decimal("0")
    compras_no_gravadas: Decimal = Decimal("0")
    saldo_favor_anterior: Decimal = Decimal("0")
    percepciones_periodo: Decimal = Decimal("0")
    percepciones_arrastre: Decimal = Decimal("0")
    retenciones_periodo: Decimal = Decimal("0")
    retenciones_arrastre: Decimal = Decimal("0")


class ResultadoCalculoIGV(BaseModel):
    subtotal_ventas: Decimal
    subtotal_compras: Decimal
    igv_debito: Decimal
    igv_credito: Decimal
    igv_resultante: Decimal
    total_creditos_aplicables: Decimal
    igv_a_pagar: Decimal
    saldo_favor_siguiente: Decimal
    percepciones_aplicadas: Decimal
    retenciones_aplicadas: Decimal
    saldo_favor_aplicado: Decimal


class InputsCalculoRenta(BaseModel):
    regimen: str
    ingresos_netos: Decimal = Decimal("0")
    coeficiente_declarado: Optional[Decimal] = None
    pagos_anticipados: Decimal = Decimal("0")
    retenciones_renta: Decimal = Decimal("0")
    saldo_favor_renta_anterior: Decimal = Decimal("0")
    categoria_nrus: Optional[int] = None
    ingresos_acumulados_ano: Decimal = Decimal("0")


class ResultadoCalculoRenta(BaseModel):
    regimen: str
    tasa_aplicada: Decimal
    base_calculo: Decimal
    renta_bruta: Decimal
    creditos_aplicados: Decimal
    renta_a_pagar: Decimal
    observaciones: str = ""


class ResultadoPDT621(BaseModel):
    igv: ResultadoCalculoIGV
    renta: ResultadoCalculoRenta
    total_a_pagar: Decimal


def calcular_igv(inputs: InputsCalculoIGV) -> ResultadoCalculoIGV:
    """Motor de calculo del IGV segun Ley del IGV (Peru)."""
    subtotal_ventas = (
        inputs.ventas_gravadas + inputs.ventas_no_gravadas + inputs.exportaciones
    )
    subtotal_compras = inputs.compras_gravadas + inputs.compras_no_gravadas

    igv_debito = (inputs.ventas_gravadas * TASA_IGV).quantize(Decimal("0.01"))
    igv_credito = (inputs.compras_gravadas * TASA_IGV).quantize(Decimal("0.01"))
    igv_resultante = igv_debito - igv_credito

    percepciones_total = inputs.percepciones_periodo + inputs.percepciones_arrastre
    retenciones_total = inputs.retenciones_periodo + inputs.retenciones_arrastre
    total_creditos = inputs.saldo_favor_anterior + percepciones_total + retenciones_total

    if igv_resultante <= 0:
        igv_a_pagar = Decimal("0")
        saldo_favor_siguiente = abs(igv_resultante) + total_creditos
        saldo_aplicado = Decimal("0")
        percep_aplicada = Decimal("0")
        retenc_aplicada = Decimal("0")
    else:
        restante = igv_resultante
        saldo_aplicado = min(restante, inputs.saldo_favor_anterior)
        restante -= saldo_aplicado
        percep_aplicada = min(restante, percepciones_total)
        restante -= percep_aplicada
        retenc_aplicada = min(restante, retenciones_total)
        restante -= retenc_aplicada
        igv_a_pagar = max(Decimal("0"), restante)
        sobrante_creditos = total_creditos - (saldo_aplicado + percep_aplicada + retenc_aplicada)
        saldo_favor_siguiente = max(Decimal("0"), sobrante_creditos)

    return ResultadoCalculoIGV(
        subtotal_ventas=subtotal_ventas.quantize(Decimal("0.01")),
        subtotal_compras=subtotal_compras.quantize(Decimal("0.01")),
        igv_debito=igv_debito,
        igv_credito=igv_credito,
        igv_resultante=igv_resultante.quantize(Decimal("0.01")),
        total_creditos_aplicables=total_creditos.quantize(Decimal("0.01")),
        igv_a_pagar=igv_a_pagar.quantize(Decimal("0.01")),
        saldo_favor_siguiente=saldo_favor_siguiente.quantize(Decimal("0.01")),
        percepciones_aplicadas=percep_aplicada.quantize(Decimal("0.01")),
        retenciones_aplicadas=retenc_aplicada.quantize(Decimal("0.01")),
        saldo_favor_aplicado=saldo_aplicado.quantize(Decimal("0.01")),
    )


def calcular_renta_rg(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    tasa = inputs.coeficiente_declarado if inputs.coeficiente_declarado else TASA_RG
    base = inputs.ingresos_netos
    renta_bruta = (base * tasa).quantize(Decimal("0.01"))
    creditos = (
        inputs.pagos_anticipados
        + inputs.retenciones_renta
        + inputs.saldo_favor_renta_anterior
    )
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    obs = ""
    if inputs.coeficiente_declarado:
        obs = f"Usando coeficiente declarado de {(tasa * 100):.4f}%"
    return ResultadoCalculoRenta(
        regimen="RG",
        tasa_aplicada=tasa,
        base_calculo=base.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones=obs,
    )


def calcular_renta_rmt(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    limite = Decimal("300") * UIT_2026
    if inputs.ingresos_acumulados_ano <= limite:
        tasa = TASA_RMT_BAJA
        obs = f"Ingresos acumulados ({inputs.ingresos_acumulados_ano:,.2f}) dentro de 300 UIT -> 1%"
    else:
        tasa = TASA_RMT_ALTA
        obs = f"Ingresos acumulados ({inputs.ingresos_acumulados_ano:,.2f}) superan 300 UIT -> 1.5%"
    if inputs.coeficiente_declarado:
        tasa = inputs.coeficiente_declarado
        obs = f"Usando coeficiente declarado de {(tasa * 100):.4f}%"
    renta_bruta = (inputs.ingresos_netos * tasa).quantize(Decimal("0.01"))
    creditos = (
        inputs.pagos_anticipados
        + inputs.retenciones_renta
        + inputs.saldo_favor_renta_anterior
    )
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    return ResultadoCalculoRenta(
        regimen="RMT",
        tasa_aplicada=tasa,
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones=obs,
    )


def calcular_renta_rer(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    tasa = TASA_RER
    renta_bruta = (inputs.ingresos_netos * tasa).quantize(Decimal("0.01"))
    creditos = inputs.pagos_anticipados + inputs.retenciones_renta
    renta_a_pagar = max(Decimal("0"), renta_bruta - creditos)
    return ResultadoCalculoRenta(
        regimen="RER",
        tasa_aplicada=tasa,
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones="Tasa unica RER 1.5% de ingresos netos mensuales",
    )


def calcular_renta_nrus(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    categoria = inputs.categoria_nrus or 1
    if categoria not in CATEGORIAS_NRUS:
        categoria = 1
    monto_fijo = CATEGORIAS_NRUS[categoria]
    return ResultadoCalculoRenta(
        regimen="NRUS",
        tasa_aplicada=Decimal("0"),
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=monto_fijo,
        creditos_aplicados=Decimal("0"),
        renta_a_pagar=monto_fijo,
        observaciones=f"NRUS Categoria {categoria}: cuota fija de S/ {monto_fijo}",
    )


def calcular_renta(inputs: InputsCalculoRenta) -> ResultadoCalculoRenta:
    regimen = inputs.regimen.upper()
    if regimen == "RG":
        return calcular_renta_rg(inputs)
    elif regimen == "RMT":
        return calcular_renta_rmt(inputs)
    elif regimen == "RER":
        return calcular_renta_rer(inputs)
    elif regimen == "NRUS":
        return calcular_renta_nrus(inputs)
    else:
        raise ValueError(f"Regimen desconocido: {regimen}")


def calcular_pdt621(
    igv_inputs: InputsCalculoIGV,
    renta_inputs: InputsCalculoRenta,
) -> ResultadoPDT621:
    igv = calcular_igv(igv_inputs)
    renta = calcular_renta(renta_inputs)
    total = igv.igv_a_pagar + renta.renta_a_pagar
    return ResultadoPDT621(
        igv=igv,
        renta=renta,
        total_a_pagar=total.quantize(Decimal("0.01")),
    )
