export interface ValoresLegales {
  uit?: number
  tasa_igv?: number
  rg_coef_minimo?: number
  rg_renta_anual?: number
  rmt_tramo1_tasa?: number
  rmt_tramo1_limite_uit?: number
  rmt_tramo2_coef_minimo?: number
  rmt_renta_anual_hasta15uit?: number
  rmt_renta_anual_resto?: number
  rer_tasa?: number
  nrus_cat1?: number
  nrus_cat2?: number
}

export interface CampoSireItem {
  numero: number
  codigo: string
  nombre: string
  obligatorio: boolean
  default_marcado: boolean
  es_clu: boolean
  marcado: boolean
}

export interface CamposSireResponse {
  tipo: 'rvie' | 'rce'
  campos: CampoSireItem[]
  total_obligatorios: number
  total_marcados: number
  total_campos: number
}

export interface ConfiguracionTributaria {
  id: number
  empresa_id: number
  uit: number
  tasa_igv: number
  rg_coef_minimo: number
  rg_renta_anual: number
  rmt_tramo1_tasa: number
  rmt_tramo1_limite_uit: number
  rmt_tramo2_coef_minimo: number
  rmt_renta_anual_hasta15uit: number
  rmt_renta_anual_resto: number
  rer_tasa: number
  nrus_cat1: number
  nrus_cat2: number
  campos_rvie: Record<string, boolean>
  campos_rce: Record<string, boolean>
  fecha_creacion: string
  fecha_modificacion: string
  es_personalizada: boolean
}

// Labels amigables para cada campo legal
export const LABELS_LEGALES: Record<string, { label: string; hint: string; sufijo: string }> = {
  uit:                        { label: 'UIT vigente',                      hint: 'Unidad Impositiva Tributaria',              sufijo: 'S/' },
  tasa_igv:                   { label: 'Tasa IGV',                         hint: 'Impuesto General a las Ventas',             sufijo: '%' },
  rg_coef_minimo:             { label: 'RG - Coef. minimo pago a cuenta',  hint: 'Regimen General, pago mensual minimo',      sufijo: '%' },
  rg_renta_anual:             { label: 'RG - Tasa renta anual',            hint: 'Regimen General, impuesto anual',           sufijo: '%' },
  rmt_tramo1_tasa:            { label: 'RMT - Tasa tramo 1',              hint: 'Hasta 300 UIT de ingresos acumulados',       sufijo: '%' },
  rmt_tramo1_limite_uit:      { label: 'RMT - Limite tramo 1',            hint: 'En UITs',                                   sufijo: 'UIT' },
  rmt_tramo2_coef_minimo:     { label: 'RMT - Coef. minimo tramo 2',      hint: 'De 300 a 1,700 UIT',                        sufijo: '%' },
  rmt_renta_anual_hasta15uit: { label: 'RMT - Renta anual hasta 15 UIT',  hint: 'Primer tramo del impuesto anual',           sufijo: '%' },
  rmt_renta_anual_resto:      { label: 'RMT - Renta anual exceso 15 UIT', hint: 'Segundo tramo del impuesto anual',          sufijo: '%' },
  rer_tasa:                   { label: 'RER - Tasa mensual',              hint: 'Regimen Especial de Renta',                  sufijo: '%' },
  nrus_cat1:                  { label: 'NRUS - Cuota categoria 1',        hint: 'Hasta S/ 5,000 ingresos/compras',            sufijo: 'S/' },
  nrus_cat2:                  { label: 'NRUS - Cuota categoria 2',        hint: 'Hasta S/ 8,000 ingresos/compras',            sufijo: 'S/' },
}

// Defaults legales SUNAT (para comparar si fue personalizado)
export const DEFAULTS_LEGALES: Record<string, number> = {
  uit: 5350,
  tasa_igv: 0.18,
  rg_coef_minimo: 0.015,
  rg_renta_anual: 0.295,
  rmt_tramo1_tasa: 0.01,
  rmt_tramo1_limite_uit: 300,
  rmt_tramo2_coef_minimo: 0.015,
  rmt_renta_anual_hasta15uit: 0.10,
  rmt_renta_anual_resto: 0.295,
  rer_tasa: 0.015,
  nrus_cat1: 20,
  nrus_cat2: 50,
}

// Que campos son tasas (se muestran como %) vs montos absolutos
export const CAMPOS_TASA = new Set([
  'tasa_igv', 'rg_coef_minimo', 'rg_renta_anual',
  'rmt_tramo1_tasa', 'rmt_tramo2_coef_minimo',
  'rmt_renta_anual_hasta15uit', 'rmt_renta_anual_resto', 'rer_tasa',
])
