"""
Motor de calculos del PDT 621.
Soporta los 4 regimenes: RG, RMT, RER, NRUS.

Ahora acepta un parametro opcional 'config' con valores personalizados por empresa
(UIT, tasas). Si no se pasa, usa los defaults legales SUNAT.

Los PDTs existentes guardan un snapshot de su config al crearse y lo usan para
recalcular, asi los cambios futuros en la configuracion no afectan PDTs viejos.
"""
from decimal import Decimal
from typing import Optional, Dict
from pydantic import BaseModel


# ════════════════════════════════════════════════════════════
# CONSTANTES LEGALES POR DEFECTO (fallback si no hay config)
# ════════════════════════════════════════════════════════════

DEFAULT_CONFIG = {
    "uit":                          Decimal("5350.00"),
    "tasa_igv":                     Decimal("0.1800"),
    "rg_coef_minimo":               Decimal("0.0150"),
    "rg_renta_anual":               Decimal("0.2950"),
    "rmt_tramo1_tasa":              Decimal("0.0100"),
    "rmt_tramo1_limite_uit":        Decimal("300.00"),
    "rmt_tramo2_coef_minimo":       Decimal("0.0150"),
    "rmt_renta_anual_hasta15uit":   Decimal("0.1000"),
    "rmt_renta_anual_resto":        Decimal("0.2950"),
    "rer_tasa":                     Decimal("0.0150"),
    "nrus_cat1":                    Decimal("20.00"),
    "nrus_cat2":                    Decimal("50.00"),
}


def _merge_config(config: Optional[Dict]) -> Dict[str, Decimal]:
    """Mezcla config del usuario con defaults. Todas las salidas son Decimal."""
    if not config:
        return dict(DEFAULT_CONFIG)
    merged = {}
    for k, v in DEFAULT_CONFIG.items():
        if k in config and config[k] is not None:
            merged[k] = Decimal(str(config[k]))
        else:
            merged[k] = v
    return merged


# ════════════════════════════════════════════════════════════
# MODELOS DE DATOS
# ════════════════════════════════════════════════════════════

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


# ════════════════════════════════════════════════════════════
# MOTOR IGV
# ════════════════════════════════════════════════════════════

def calcular_igv(
    inputs: InputsCalculoIGV, config: Optional[Dict] = None
) -> ResultadoCalculoIGV:
    """Motor de calculo del IGV. Usa tasa_igv de la config o 18% por defecto."""
    cfg = _merge_config(config)
    tasa_igv = cfg["tasa_igv"]

    subtotal_ventas = (
        inputs.ventas_gravadas + inputs.ventas_no_gravadas + inputs.exportaciones
    )
    subtotal_compras = inputs.compras_gravadas + inputs.compras_no_gravadas

    igv_debito = (inputs.ventas_gravadas * tasa_igv).quantize(Decimal("0.01"))
    igv_credito = (inputs.compras_gravadas * tasa_igv).quantize(Decimal("0.01"))
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


# ════════════════════════════════════════════════════════════
# MOTOR RENTA (4 regimenes)
# ════════════════════════════════════════════════════════════

def calcular_renta_rg(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    cfg = _merge_config(config)
    tasa = inputs.coeficiente_declarado if inputs.coeficiente_declarado else cfg["rg_coef_minimo"]
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
    else:
        obs = f"Usando coeficiente minimo de {(tasa * 100):.2f}% (RG)"
    return ResultadoCalculoRenta(
        regimen="RG",
        tasa_aplicada=tasa,
        base_calculo=base.quantize(Decimal("0.01")),
        renta_bruta=renta_bruta,
        creditos_aplicados=creditos.quantize(Decimal("0.01")),
        renta_a_pagar=renta_a_pagar.quantize(Decimal("0.01")),
        observaciones=obs,
    )


def calcular_renta_rmt(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    cfg = _merge_config(config)
    limite = cfg["rmt_tramo1_limite_uit"] * cfg["uit"]

    if inputs.ingresos_acumulados_ano <= limite:
        tasa = cfg["rmt_tramo1_tasa"]
        obs = (
            f"Ingresos acumulados ({inputs.ingresos_acumulados_ano:,.2f}) dentro de "
            f"{cfg['rmt_tramo1_limite_uit']} UIT -> {(tasa * 100):.2f}%"
        )
    else:
        tasa = cfg["rmt_tramo2_coef_minimo"]
        obs = (
            f"Ingresos acumulados ({inputs.ingresos_acumulados_ano:,.2f}) superan "
            f"{cfg['rmt_tramo1_limite_uit']} UIT -> {(tasa * 100):.2f}%"
        )

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


def calcular_renta_rer(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    cfg = _merge_config(config)
    tasa = cfg["rer_tasa"]
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
        observaciones=f"Tasa unica RER {(tasa * 100):.2f}% de ingresos netos mensuales",
    )


def calcular_renta_nrus(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    cfg = _merge_config(config)
    categoria = inputs.categoria_nrus or 1
    if categoria == 2:
        monto_fijo = cfg["nrus_cat2"]
    else:
        categoria = 1
        monto_fijo = cfg["nrus_cat1"]
    return ResultadoCalculoRenta(
        regimen="NRUS",
        tasa_aplicada=Decimal("0"),
        base_calculo=inputs.ingresos_netos.quantize(Decimal("0.01")),
        renta_bruta=monto_fijo,
        creditos_aplicados=Decimal("0"),
        renta_a_pagar=monto_fijo,
        observaciones=f"NRUS Categoria {categoria}: cuota fija de S/ {monto_fijo}",
    )


def calcular_renta(
    inputs: InputsCalculoRenta, config: Optional[Dict] = None
) -> ResultadoCalculoRenta:
    regimen = inputs.regimen.upper()
    if regimen == "RG":
        return calcular_renta_rg(inputs, config)
    elif regimen == "RMT":
        return calcular_renta_rmt(inputs, config)
    elif regimen == "RER":
        return calcular_renta_rer(inputs, config)
    elif regimen == "NRUS":
        return calcular_renta_nrus(inputs, config)
    else:
        raise ValueError(f"Regimen desconocido: {regimen}")


def calcular_pdt621(
    igv_inputs: InputsCalculoIGV,
    renta_inputs: InputsCalculoRenta,
    config: Optional[Dict] = None,
) -> ResultadoPDT621:
    """
    Calculo principal. Si config es None, usa defaults legales SUNAT.
    Para PDTs existentes, pasar su snapshot (pdt.config_snapshot).
    """
    igv = calcular_igv(igv_inputs, config)
    renta = calcular_renta(renta_inputs, config)
    total = igv.igv_a_pagar + renta.renta_a_pagar
    return ResultadoPDT621(
        igv=igv,
        renta=renta,
        total_a_pagar=total.quantize(Decimal("0.01")),
    )
