"""
Servicio de configuracion tributaria por empresa.
Maneja valores legales (UIT, tasas) y seleccion de campos SIRE.
"""
from decimal import Decimal
from typing import Optional
from sqlalchemy.orm import Session
from fastapi import HTTPException

from app.models.models import ConfiguracionTributariaEmpresa, Empresa


# ════════════════════════════════════════════════════════════
# VALORES LEGALES POR DEFECTO (SUNAT Peru - vigente 2026)
# ════════════════════════════════════════════════════════════

DEFAULTS_LEGALES = {
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


# ════════════════════════════════════════════════════════════
# CATALOGO DE CAMPOS SIRE
# Basado en Anexos 3 (RVIE) y 11 (RCE) de RS 112-2021/SUNAT
# ════════════════════════════════════════════════════════════

# Campos RVIE - Reemplazo de Propuesta (33 campos principales)
CATALOGO_RVIE = [
    # (numero, codigo, nombre, obligatorio, default_marcado)
    (1,  "ruc",                          "RUC del deudor",                        True,  True),
    (2,  "id",                           "ID / Identificador",                    True,  True),
    (3,  "periodo",                      "Periodo (AAAAMM)",                      True,  True),
    (4,  "car_sunat",                    "CAR SUNAT",                             False, False),
    (5,  "fecha_emision",                "Fecha de emision",                      True,  True),
    (6,  "fecha_vcto_pago",              "Fecha Vcto/Pago",                       True,  True),
    (7,  "tipo_cp",                      "Tipo de Comprobante",                   True,  True),
    (8,  "serie_cp",                     "Serie del CP",                          True,  True),
    (9,  "nro_cp",                       "Numero CP (inicial rango)",             True,  True),
    (10, "nro_cp_final",                 "Numero CP (final rango)",               False, False),
    (11, "tipo_doc_identidad",           "Tipo Doc Identidad",                    True,  True),
    (12, "nro_doc_identidad",            "Nro Doc Identidad",                     True,  True),
    (13, "razon_social",                 "Apellidos/Razon Social",                True,  True),
    (14, "valor_exportacion",            "Valor facturado exportacion",           False, True),
    (15, "bi_gravada",                   "Base Imponible Gravada",                False, True),
    (16, "dscto_bi",                     "Descuento BI",                          False, False),
    (17, "igv_ipm",                      "IGV / IPM",                             False, True),
    (18, "dscto_igv",                    "Descuento IGV",                         False, False),
    (19, "mto_exonerado",                "Monto Exonerado",                       False, True),
    (20, "mto_inafecto",                 "Monto Inafecto",                        False, True),
    (21, "isc",                          "ISC",                                   False, False),
    (22, "bi_grav_ivap",                 "BI Grav IVAP",                          False, False),
    (23, "ivap",                         "IVAP",                                  False, False),
    (24, "icbper",                       "ICBPER",                                False, False),
    (25, "otros_tributos",               "Otros Tributos",                        False, False),
    (26, "total_cp",                     "Total CP",                              True,  True),
    (27, "moneda",                       "Moneda",                                True,  True),
    (28, "tipo_cambio",                  "Tipo de Cambio",                        False, True),
    (29, "fecha_emision_mod",            "Fecha Emision Doc Modificado",          False, False),
    (30, "tipo_cp_mod",                  "Tipo CP Modificado",                    False, False),
    (31, "serie_cp_mod",                 "Serie CP Modificado",                   False, False),
    (32, "nro_cp_mod",                   "Nro CP Modificado",                     False, False),
    (33, "id_proyecto_atribucion",       "ID Proyecto Operadores Atribucion",     False, False),
]

# Campos CLU (libres del usuario) para RVIE - 18 slots
CATALOGO_RVIE_CLU = [
    (40 + i, f"clu_rvie_{i}", f"Campo libre usuario {i}", False, False) for i in range(1, 19)
]

# Campos RCE - Reemplazo de Propuesta (37 campos principales)
CATALOGO_RCE = [
    (1,  "ruc",                          "RUC del deudor",                        True,  True),
    (2,  "razon_social_deudor",          "Razon social deudor",                   True,  True),
    (3,  "periodo",                      "Periodo (AAAAMM)",                      True,  True),
    (4,  "car_sunat",                    "CAR SUNAT",                             False, False),
    (5,  "fecha_emision",                "Fecha de emision",                      True,  True),
    (6,  "fecha_vcto_pago",              "Fecha Vcto/Pago",                       True,  True),
    (7,  "tipo_cp",                      "Tipo de Comprobante",                   True,  True),
    (8,  "serie_cp",                     "Serie del CP",                          True,  True),
    (9,  "ano",                          "Ano",                                   False, True),
    (10, "nro_cp",                       "Numero CP (inicial rango)",             True,  True),
    (11, "nro_cp_final",                 "Numero CP (final rango)",               False, False),
    (12, "tipo_doc_identidad",           "Tipo Doc Identidad",                    True,  True),
    (13, "nro_doc_identidad",            "Nro Doc Identidad del proveedor",       True,  True),
    (14, "razon_social",                 "Razon Social del proveedor",            True,  True),
    (15, "bi_gravado_dg",                "BI Gravado DG (destinadas a gravadas)", False, True),
    (16, "igv_ipm_dg",                   "IGV/IPM DG",                            False, True),
    (17, "bi_gravado_dgng",              "BI Gravado DGNG (gravadas y no grav)",  False, False),
    (18, "igv_ipm_dgng",                 "IGV/IPM DGNG",                          False, False),
    (19, "bi_gravado_dng",               "BI Gravado DNG (solo no gravadas)",     False, False),
    (20, "igv_ipm_dng",                  "IGV/IPM DNG",                           False, False),
    (21, "valor_adq_ng",                 "Valor adquisiciones no gravadas",       False, False),
    (22, "isc",                          "ISC",                                   False, False),
    (23, "icbper",                       "ICBPER",                                False, False),
    (24, "otros_tributos",               "Otros Tributos / Cargos",               False, False),
    (25, "total_cp",                     "Total CP",                              True,  True),
    (26, "moneda",                       "Moneda",                                True,  True),
    (27, "tipo_cambio",                  "Tipo de Cambio",                        False, True),
    (28, "fecha_emision_mod",            "Fecha Emision Doc Modificado",          False, False),
    (29, "tipo_cp_mod",                  "Tipo CP Modificado",                    False, False),
    (30, "serie_cp_mod",                 "Serie CP Modificado",                   False, False),
    (31, "cod_dam_dsi",                  "Cod. DAM o DSI",                        False, False),
    (32, "nro_cp_mod",                   "Nro CP Modificado",                     False, False),
    (33, "clasif_bienes_serv",           "Clasificacion de Bienes y Servicios",   False, False),
    (34, "id_proyecto",                  "ID Proyecto Operadores/Participes",     False, False),
    (35, "porc_part",                    "PorcPart (Porcentaje de participacion)",False, False),
    (36, "imb",                          "IMB",                                   False, False),
    (37, "car_orig",                     "CAR Original",                          False, False),
]

# Campos CLU para RCE - 39 slots (se empieza en 42)
CATALOGO_RCE_CLU = [
    (41 + i, f"clu_rce_{i}", f"Campo libre usuario {i}", False, False) for i in range(1, 40)
]


def catalogo_rvie_completo():
    """Retorna el catalogo completo de RVIE con CLU."""
    items = []
    for (num, codigo, nombre, obligatorio, default) in CATALOGO_RVIE + CATALOGO_RVIE_CLU:
        items.append({
            "numero": num,
            "codigo": codigo,
            "nombre": nombre,
            "obligatorio": obligatorio,
            "default_marcado": default,
            "es_clu": codigo.startswith("clu_"),
        })
    return items


def catalogo_rce_completo():
    items = []
    for (num, codigo, nombre, obligatorio, default) in CATALOGO_RCE + CATALOGO_RCE_CLU:
        items.append({
            "numero": num,
            "codigo": codigo,
            "nombre": nombre,
            "obligatorio": obligatorio,
            "default_marcado": default,
            "es_clu": codigo.startswith("clu_"),
        })
    return items


def defaults_campos_rvie() -> dict:
    """Diccionario {codigo_campo: bool} con los defaults de RVIE."""
    return {c["codigo"]: c["default_marcado"] for c in catalogo_rvie_completo()}


def defaults_campos_rce() -> dict:
    return {c["codigo"]: c["default_marcado"] for c in catalogo_rce_completo()}


# ════════════════════════════════════════════════════════════
# CRUD DE CONFIGURACION
# ════════════════════════════════════════════════════════════

def obtener_o_crear_configuracion(
    db: Session, empresa_id: int
) -> ConfiguracionTributariaEmpresa:
    """
    Obtiene la config de la empresa. Si no existe, la crea con defaults.
    """
    config = db.query(ConfiguracionTributariaEmpresa).filter_by(
        empresa_id=empresa_id
    ).first()

    if config:
        # Asegurar que tenga los JSON de campos (por si la tabla se creo vacia)
        if not config.campos_rvie:
            config.campos_rvie = defaults_campos_rvie()
        if not config.campos_rce:
            config.campos_rce = defaults_campos_rce()
        db.commit()
        return config

    # Crear con defaults
    config = ConfiguracionTributariaEmpresa(
        empresa_id=empresa_id,
        campos_rvie=defaults_campos_rvie(),
        campos_rce=defaults_campos_rce(),
        **{k: v for k, v in DEFAULTS_LEGALES.items()},
    )
    db.add(config)
    db.commit()
    db.refresh(config)
    return config


def actualizar_valores_legales(
    db: Session, empresa_id: int, datos: dict, usuario_id: Optional[int] = None
) -> ConfiguracionTributariaEmpresa:
    """Actualiza solo los valores legales (UIT, tasas). Ignora campos SIRE."""
    config = obtener_o_crear_configuracion(db, empresa_id)

    campos_permitidos = set(DEFAULTS_LEGALES.keys())
    for campo, valor in datos.items():
        if campo in campos_permitidos and valor is not None:
            try:
                setattr(config, campo, Decimal(str(valor)))
            except Exception:
                raise HTTPException(400, f"Valor invalido para {campo}: {valor}")

    if usuario_id:
        config.modificado_por_usuario_id = usuario_id
    db.commit()
    db.refresh(config)
    return config


def actualizar_campos_sire(
    db: Session, empresa_id: int, tipo: str, seleccion: dict,
    usuario_id: Optional[int] = None,
) -> ConfiguracionTributariaEmpresa:
    """
    Actualiza la seleccion de campos SIRE.
    tipo: 'rvie' o 'rce'
    seleccion: {codigo_campo: bool}
    Valida que los obligatorios esten siempre en True.
    """
    if tipo not in ("rvie", "rce"):
        raise HTTPException(400, "tipo debe ser 'rvie' o 'rce'")

    catalogo = catalogo_rvie_completo() if tipo == "rvie" else catalogo_rce_completo()
    obligatorios = {c["codigo"] for c in catalogo if c["obligatorio"]}

    # Validar: todos los obligatorios deben estar en True
    for codigo_ob in obligatorios:
        if seleccion.get(codigo_ob) is False:
            raise HTTPException(
                400,
                f"El campo '{codigo_ob}' es obligatorio por SUNAT "
                f"(Anexo {3 if tipo == 'rvie' else 11} RS 112-2021) y no puede desmarcarse",
            )

    # Construir el dict final merged con defaults (campos no enviados = default)
    codigos_validos = {c["codigo"] for c in catalogo}
    defaults = defaults_campos_rvie() if tipo == "rvie" else defaults_campos_rce()

    final = {}
    for codigo in codigos_validos:
        if codigo in obligatorios:
            final[codigo] = True  # Forzar obligatorios siempre True
        elif codigo in seleccion:
            final[codigo] = bool(seleccion[codigo])
        else:
            final[codigo] = defaults.get(codigo, False)

    config = obtener_o_crear_configuracion(db, empresa_id)
    if tipo == "rvie":
        config.campos_rvie = final
    else:
        config.campos_rce = final

    if usuario_id:
        config.modificado_por_usuario_id = usuario_id
    db.commit()
    db.refresh(config)
    return config


def restaurar_defaults(
    db: Session, empresa_id: int, seccion: str, usuario_id: Optional[int] = None
) -> ConfiguracionTributariaEmpresa:
    """
    Restaura los defaults legales o los defaults de campos SIRE.
    seccion: 'legales', 'rvie', 'rce', 'todo'
    """
    config = obtener_o_crear_configuracion(db, empresa_id)
    if seccion in ("legales", "todo"):
        for campo, valor in DEFAULTS_LEGALES.items():
            setattr(config, campo, valor)
    if seccion in ("rvie", "todo"):
        config.campos_rvie = defaults_campos_rvie()
    if seccion in ("rce", "todo"):
        config.campos_rce = defaults_campos_rce()

    if usuario_id:
        config.modificado_por_usuario_id = usuario_id
    db.commit()
    db.refresh(config)
    return config


def config_a_snapshot(config: ConfiguracionTributariaEmpresa) -> dict:
    """
    Convierte una configuracion a dict (JSONB) para guardar como snapshot en PDT621.
    Los PDTs existentes NUNCA se recalculan cuando cambia la config; usan su snapshot.
    """
    return {
        "uit":                        float(config.uit),
        "tasa_igv":                   float(config.tasa_igv),
        "rg_coef_minimo":             float(config.rg_coef_minimo),
        "rg_renta_anual":             float(config.rg_renta_anual),
        "rmt_tramo1_tasa":            float(config.rmt_tramo1_tasa),
        "rmt_tramo1_limite_uit":      float(config.rmt_tramo1_limite_uit),
        "rmt_tramo2_coef_minimo":     float(config.rmt_tramo2_coef_minimo),
        "rmt_renta_anual_hasta15uit": float(config.rmt_renta_anual_hasta15uit),
        "rmt_renta_anual_resto":      float(config.rmt_renta_anual_resto),
        "rer_tasa":                   float(config.rer_tasa),
        "nrus_cat1":                  float(config.nrus_cat1),
        "nrus_cat2":                  float(config.nrus_cat2),
    }


def snapshot_a_decimales(snapshot: Optional[dict]) -> dict:
    """
    Convierte un snapshot (dict) a Decimales. Si no hay snapshot, usa DEFAULTS_LEGALES.
    """
    if not snapshot:
        return dict(DEFAULTS_LEGALES)
    out = {}
    for k, v in DEFAULTS_LEGALES.items():
        out[k] = Decimal(str(snapshot.get(k, v)))
    return out
