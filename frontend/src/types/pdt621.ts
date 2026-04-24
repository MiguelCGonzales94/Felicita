export type EstadoPDT = 'DRAFT' | 'GENERATED' | 'SUBMITTED' | 'ACCEPTED' | 'REJECTED'

export interface PDT621 {
  id: number
  empresa_id: number
  mes: number
  ano: number
  fecha_vencimiento: string
  estado: EstadoPDT
  c100_ventas_gravadas: number
  c104_ventas_no_gravadas: number
  c105_exportaciones: number
  c140_subtotal_ventas: number
  c140igv_igv_debito: number
  c120_compras_gravadas: number
  c180_igv_credito: number
  c184_igv_a_pagar: number
  c301_ingresos_netos: number
  c309_pago_a_cuenta_renta: number
  c310_retenciones: number
  c311_pagos_anticipados: number
  c318_renta_a_pagar: number
  total_a_pagar: number
  nps: string | null
  numero_operacion: string | null
  codigo_rechazo_sunat: string | null
  mensaje_error_sunat: string | null
  fecha_presentacion_sunat: string | null
  fecha_creacion: string
}

export interface PDT621ListItem {
  id: number
  empresa_id: number
  empresa_nombre: string
  empresa_ruc: string
  empresa_color: string
  mes: number
  ano: number
  fecha_vencimiento: string
  estado: EstadoPDT
  total_a_pagar: number
  igv_a_pagar: number
  renta_a_pagar: number
  nps: string | null
  dias_para_vencer: number
}

export interface ImportacionSunat {
  fuente: 'SUNAT_SIRE' | 'MOCK'
  ventas: {
    total_comprobantes: number
    ventas_gravadas: number
    ventas_no_gravadas: number
    exportaciones: number
    igv_debito: number
    comprobantes: any[]
  }
  compras: {
    total_comprobantes: number
    compras_gravadas: number
    igv_credito: number
    comprobantes: any[]
  }
}

export interface Ajustes {
  saldo_favor_anterior?: number
  percepciones_periodo?: number
  percepciones_arrastre?: number
  retenciones_periodo?: number
  retenciones_arrastre?: number
  pagos_anticipados?: number
  retenciones_renta?: number
  saldo_favor_renta_anterior?: number
  categoria_nrus?: number
  ingresos_acumulados_ano?: number
}

export interface ResultadoCalculo {
  igv: {
    subtotal_ventas: number
    subtotal_compras: number
    igv_debito: number
    igv_credito: number
    igv_resultante: number
    total_creditos_aplicables: number
    igv_a_pagar: number
    saldo_favor_siguiente: number
    percepciones_aplicadas: number
    retenciones_aplicadas: number
    saldo_favor_aplicado: number
  }
  renta: {
    regimen: string
    tasa_aplicada: number
    base_calculo: number
    renta_bruta: number
    creditos_aplicados: number
    renta_a_pagar: number
    observaciones: string
  }
  total_a_pagar: number
}

export const MESES_LABEL = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
]

export const ESTADO_CONFIG: Record<EstadoPDT, { label: string; color: string; bg: string }> = {
  DRAFT:     { label: 'Borrador',   color: 'text-gray-700',    bg: 'bg-gray-100' },
  GENERATED: { label: 'Generado',   color: 'text-brand-900',   bg: 'bg-brand-50' },
  SUBMITTED: { label: 'Presentado', color: 'text-warning-900', bg: 'bg-warning-50' },
  ACCEPTED:  { label: 'Aceptado',   color: 'text-success-900', bg: 'bg-success-50' },
  REJECTED:  { label: 'Rechazado',  color: 'text-danger-900',  bg: 'bg-danger-50' },
}
