# ============================================================
#  FELICITA - Entrega 1 Parte C: Frontend modal detalle
#  Modal de comprobantes editables + integracion en editor PDT
#  Uso: .\entrega1c_detalle_comprobantes_frontend.ps1
# ============================================================

Write-Host ""
Write-Host "Entrega 1 - Parte C: Frontend modal detalle" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "frontend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# 1. types/pdt621.ts - Agregar tipos de detalle manteniendo los existentes
# ============================================================

Write-Host "Actualizando types/pdt621.ts..." -ForegroundColor Yellow

@'
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
    comprobantes?: any[]
  }
  compras: {
    total_comprobantes: number
    compras_gravadas: number
    igv_credito: number
    comprobantes?: any[]
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

export const MESES_LABEL: Record<number, string> = {
  1: 'Enero', 2: 'Febrero', 3: 'Marzo', 4: 'Abril',
  5: 'Mayo', 6: 'Junio', 7: 'Julio', 8: 'Agosto',
  9: 'Septiembre', 10: 'Octubre', 11: 'Noviembre', 12: 'Diciembre',
}

export const ESTADO_CONFIG: Record<EstadoPDT, { label: string; color: string; bg: string }> = {
  DRAFT:     { label: 'Borrador',   color: 'text-gray-700',    bg: 'bg-gray-100' },
  GENERATED: { label: 'Generada',   color: 'text-brand-900',   bg: 'bg-brand-50' },
  SUBMITTED: { label: 'Presentada', color: 'text-warning-900', bg: 'bg-warning-50' },
  ACCEPTED:  { label: 'Aceptada',   color: 'text-success-900', bg: 'bg-success-50' },
  REJECTED:  { label: 'Rechazada',  color: 'text-danger-900',  bg: 'bg-danger-50' },
}


// ════════════════════════════════════════════════════════════
// DETALLE DE COMPROBANTES
// ════════════════════════════════════════════════════════════

export interface VentaDetalleItem {
  id: number
  tipo_comprobante: string
  serie: string
  numero: string
  fecha_emision: string
  ruc_cliente: string | null
  razon_social_cliente: string
  base_gravada: number
  base_no_gravada: number
  exportacion: number
  igv: number
  total: number
  incluido: boolean
  fuente: string
}

export interface CompraDetalleItem {
  id: number
  tipo_comprobante: string
  serie: string
  numero: string
  fecha_emision: string
  ruc_proveedor: string | null
  razon_social_proveedor: string
  base_gravada: number
  base_no_gravada: number
  igv: number
  total: number
  tipo_destino: string
  incluido: boolean
  fuente: string
}

export interface DetalleVentasResponse {
  total_comprobantes: number
  comprobantes_incluidos: number
  subtotal_gravadas_incluidas: number
  subtotal_no_gravadas_incluidas: number
  subtotal_exportaciones_incluidas: number
  subtotal_igv_incluido: number
  subtotal_total_incluido: number
  fuente: string
  comprobantes: VentaDetalleItem[]
}

export interface DetalleComprasResponse {
  total_comprobantes: number
  comprobantes_incluidos: number
  subtotal_gravadas_incluidas: number
  subtotal_igv_incluido: number
  subtotal_total_incluido: number
  fuente: string
  comprobantes: CompraDetalleItem[]
}

export interface SeleccionItem {
  id: number
  incluido: boolean
}

// Etiqueta amigable para tipo de comprobante
export const TIPO_COMPROBANTE_LABEL: Record<string, string> = {
  '01': 'Factura',
  '03': 'Boleta',
  '07': 'Nota de credito',
  '08': 'Nota de debito',
  '12': 'Ticket',
}
'@ | Set-Content "frontend/src/types/pdt621.ts"

Write-Host "  [OK] types/pdt621.ts actualizado" -ForegroundColor Green

# ============================================================
# 2. services/pdt621Service.ts - Agregar metodos de detalle
# ============================================================

Write-Host ""
Write-Host "Actualizando pdt621Service.ts..." -ForegroundColor Yellow

@'
import api from './api'
import type {
  PDT621, PDT621ListItem, ImportacionSunat, Ajustes, ResultadoCalculo, EstadoPDT,
  DetalleVentasResponse, DetalleComprasResponse, SeleccionItem,
} from '../types/pdt621'

export const pdt621Service = {
  // Listar todos los PDTs del contador
  async listar(filtros: { ano?: number; mes?: number; estado?: string; empresa_id?: number } = {}) {
    const { data } = await api.get('/pdt621', { params: filtros })
    return data as { total: number; pdts: PDT621ListItem[] }
  },

  // Listar PDTs de una empresa
  async listarPorEmpresa(empresaId: number) {
    const { data } = await api.get(`/empresas/${empresaId}/pdt621`)
    return data as {
      empresa: { id: number; ruc: string; razon_social: string }
      total: number
      pdts: PDT621ListItem[]
    }
  },

  // Obtener o crear PDT de un periodo
  async obtenerPorPeriodo(empresaId: number, ano: number, mes: number) {
    const { data } = await api.get(`/empresas/${empresaId}/pdt621/periodo/${ano}/${mes}`)
    return data as PDT621
  },

  // Obtener PDT por ID
  async obtener(pdtId: number) {
    const { data } = await api.get(`/pdt621/${pdtId}`)
    return data as PDT621
  },

  // Generar PDT
  async generar(empresaId: number, ano: number, mes: number) {
    const { data } = await api.post(`/empresas/${empresaId}/pdt621/generar`, { ano, mes })
    return data as PDT621
  },

  // Importar desde SUNAT (SIRE real o mock)
  async importarSunat(pdtId: number) {
    const { data } = await api.post(`/pdt621/${pdtId}/importar-sunat`)
    return data as ImportacionSunat
  },

  // Probar conexion con SUNAT
  async probarConexionSire(empresaId: number) {
    const { data } = await api.post(`/empresas/${empresaId}/sire/probar-conexion`)
    return data as {
      conectado: boolean
      usando_mock: boolean
      mensaje: string
      codigo?: string
    }
  },

  // Sugerir saldo a favor del mes anterior
  async sugerirSaldoFavor(empresaId: number, ano: number, mes: number) {
    const { data } = await api.get(`/empresas/${empresaId}/pdt621/saldo-favor/${ano}/${mes}`)
    return data as { saldo_sugerido: number; editable: boolean; fuente: string }
  },

  // Aplicar ajustes
  async aplicarAjustes(pdtId: number, ajustes: Ajustes) {
    const { data } = await api.put(`/pdt621/${pdtId}/ajustes`, ajustes)
    return data as ResultadoCalculo
  },

  // Recalcular
  async recalcular(pdtId: number) {
    const { data } = await api.post(`/pdt621/${pdtId}/recalcular`)
    return data as PDT621
  },

  // Cambiar estado
  async cambiarEstado(pdtId: number, nuevoEstado: EstadoPDT, numero_operacion?: string, mensaje?: string) {
    const { data } = await api.post(`/pdt621/${pdtId}/cambiar-estado`, {
      nuevo_estado: nuevoEstado, numero_operacion, mensaje,
    })
    return data as PDT621
  },

  // ── DETALLE DE COMPROBANTES ─────────────────────────

  async obtenerDetalleVentas(pdtId: number) {
    const { data } = await api.get(`/pdt621/${pdtId}/detalle-ventas`)
    return data as DetalleVentasResponse
  },

  async obtenerDetalleCompras(pdtId: number) {
    const { data } = await api.get(`/pdt621/${pdtId}/detalle-compras`)
    return data as DetalleComprasResponse
  },

  async aplicarSeleccionVentas(pdtId: number, selecciones: SeleccionItem[]) {
    const { data } = await api.post(
      `/pdt621/${pdtId}/detalle-ventas/aplicar-seleccion`,
      { selecciones }
    )
    return data as PDT621
  },

  async aplicarSeleccionCompras(pdtId: number, selecciones: SeleccionItem[]) {
    const { data } = await api.post(
      `/pdt621/${pdtId}/detalle-compras/aplicar-seleccion`,
      { selecciones }
    )
    return data as PDT621
  },
}


// Helpers
export function formatoSoles(n: number): string {
  return `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}
'@ | Set-Content "frontend/src/services/pdt621Service.ts"

Write-Host "  [OK] pdt621Service.ts con 4 metodos nuevos" -ForegroundColor Green

# ============================================================
# 3. components/DetalleComprobantesModal.tsx - El componente nuevo
# ============================================================

Write-Host ""
Write-Host "Creando DetalleComprobantesModal.tsx..." -ForegroundColor Yellow

@'
import { useEffect, useMemo, useState } from 'react'
import {
  Search, Loader2, Check, X, FileText, TrendingUp, TrendingDown,
  AlertCircle, Save,
} from 'lucide-react'
import Modal from './Modal'
import { pdt621Service, formatoSoles } from '../services/pdt621Service'
import { TIPO_COMPROBANTE_LABEL } from '../types/pdt621'
import type {
  VentaDetalleItem, CompraDetalleItem, SeleccionItem,
} from '../types/pdt621'

type TipoTabla = 'ventas' | 'compras'

interface Props {
  isOpen: boolean
  onClose: () => void
  pdtId: number
  tipo: TipoTabla
  editable: boolean             // si el PDT esta en DRAFT/REJECTED
  onAplicado: () => void        // callback tras aplicar cambios (recarga el PDT)
}

type ItemUnificado = {
  id: number
  tipo_comprobante: string
  serie: string
  numero: string
  fecha_emision: string
  ruc: string | null
  razon_social: string
  base: number
  igv: number
  total: number
  incluido: boolean
}

function mapVenta(v: VentaDetalleItem): ItemUnificado {
  return {
    id: v.id,
    tipo_comprobante: v.tipo_comprobante,
    serie: v.serie,
    numero: v.numero,
    fecha_emision: v.fecha_emision,
    ruc: v.ruc_cliente,
    razon_social: v.razon_social_cliente,
    base: Number(v.base_gravada) + Number(v.base_no_gravada) + Number(v.exportacion),
    igv: Number(v.igv),
    total: Number(v.total),
    incluido: v.incluido,
  }
}

function mapCompra(c: CompraDetalleItem): ItemUnificado {
  return {
    id: c.id,
    tipo_comprobante: c.tipo_comprobante,
    serie: c.serie,
    numero: c.numero,
    fecha_emision: c.fecha_emision,
    ruc: c.ruc_proveedor,
    razon_social: c.razon_social_proveedor,
    base: Number(c.base_gravada) + Number(c.base_no_gravada),
    igv: Number(c.igv),
    total: Number(c.total),
    incluido: c.incluido,
  }
}

export default function DetalleComprobantesModal({
  isOpen, onClose, pdtId, tipo, editable, onAplicado,
}: Props) {
  const [loading, setLoading] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [items, setItems] = useState<ItemUnificado[]>([])
  const [itemsOriginales, setItemsOriginales] = useState<ItemUnificado[]>([])
  const [fuente, setFuente] = useState<string>('')
  const [filtro, setFiltro] = useState('')
  const [error, setError] = useState<string | null>(null)

  const esVentas = tipo === 'ventas'
  const titulo = esVentas ? 'Detalle de Ventas (RVIE)' : 'Detalle de Compras (RCE)'
  const descripcion = esVentas
    ? 'Comprobantes descargados desde SUNAT. Marca cuales entran al calculo del PDT.'
    : 'Comprobantes de compras descargados desde SUNAT. Marca cuales entran al calculo.'

  useEffect(() => {
    if (isOpen) cargar()
  }, [isOpen, pdtId, tipo])

  async function cargar() {
    setLoading(true)
    setError(null)
    try {
      if (esVentas) {
        const data = await pdt621Service.obtenerDetalleVentas(pdtId)
        const mapeados = data.comprobantes.map(mapVenta)
        setItems(mapeados)
        setItemsOriginales(mapeados)
        setFuente(data.fuente)
      } else {
        const data = await pdt621Service.obtenerDetalleCompras(pdtId)
        const mapeados = data.comprobantes.map(mapCompra)
        setItems(mapeados)
        setItemsOriginales(mapeados)
        setFuente(data.fuente)
      }
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al cargar comprobantes')
    } finally {
      setLoading(false)
    }
  }

  // Filtrado por RUC / razon / numero
  const filtrados = useMemo(() => {
    if (!filtro.trim()) return items
    const q = filtro.toLowerCase()
    return items.filter(i =>
      (i.ruc || '').toLowerCase().includes(q)
      || i.razon_social.toLowerCase().includes(q)
      || `${i.serie}-${i.numero}`.toLowerCase().includes(q)
    )
  }, [items, filtro])

  // Totales de incluidos (calculo en cliente, optimista)
  const totales = useMemo(() => {
    const incluidos = items.filter(i => i.incluido)
    return {
      count: incluidos.length,
      total: items.length,
      base: incluidos.reduce((s, i) => s + i.base, 0),
      igv: incluidos.reduce((s, i) => s + i.igv, 0),
      totalImporte: incluidos.reduce((s, i) => s + i.total, 0),
    }
  }, [items])

  // Detectar cambios pendientes
  const hayCambios = useMemo(() => {
    if (items.length !== itemsOriginales.length) return false
    const originalMap = new Map(itemsOriginales.map(i => [i.id, i.incluido]))
    return items.some(i => originalMap.get(i.id) !== i.incluido)
  }, [items, itemsOriginales])

  function toggle(id: number) {
    if (!editable) return
    setItems(prev => prev.map(i => i.id === id ? { ...i, incluido: !i.incluido } : i))
  }

  function toggleTodos(valor: boolean) {
    if (!editable) return
    // Aplica a los filtrados, no a todos si hay filtro
    const idsFiltrados = new Set(filtrados.map(f => f.id))
    setItems(prev => prev.map(i =>
      idsFiltrados.has(i.id) ? { ...i, incluido: valor } : i
    ))
  }

  async function handleAplicar() {
    if (!hayCambios) return
    setGuardando(true)
    setError(null)
    try {
      const selecciones: SeleccionItem[] = items.map(i => ({
        id: i.id, incluido: i.incluido,
      }))
      if (esVentas) {
        await pdt621Service.aplicarSeleccionVentas(pdtId, selecciones)
      } else {
        await pdt621Service.aplicarSeleccionCompras(pdtId, selecciones)
      }
      // Sincronizar original con el nuevo estado
      setItemsOriginales(items)
      onAplicado()
      onClose()
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al aplicar cambios')
    } finally {
      setGuardando(false)
    }
  }

  const todosMarcados = filtrados.length > 0 && filtrados.every(i => i.incluido)
  const ningunoMarcado = filtrados.length > 0 && filtrados.every(i => !i.incluido)

  return (
    <Modal
      isOpen={isOpen}
      onClose={guardando ? () => {} : onClose}
      title={titulo}
      description={descripcion}
      size="xl"
      footer={
        <>
          <div className="flex-1 text-xs text-gray-500">
            {hayCambios ? (
              <span className="inline-flex items-center gap-1 text-warning-700 font-medium">
                <AlertCircle size={12} /> Hay cambios sin aplicar
              </span>
            ) : (
              <span>Sin cambios pendientes</span>
            )}
          </div>
          <button
            onClick={onClose}
            className="btn-secondary"
            disabled={guardando}
          >
            {hayCambios ? 'Descartar' : 'Cerrar'}
          </button>
          {editable && (
            <button
              onClick={handleAplicar}
              disabled={!hayCambios || guardando}
              className="btn-primary flex items-center gap-2"
            >
              {guardando
                ? <Loader2 size={14} className="animate-spin" />
                : <Save size={14} />}
              Aplicar cambios
            </button>
          )}
        </>
      }
    >
      {/* Barra superior: busqueda + selector masivo + badge fuente */}
      <div className="flex items-center gap-3 mb-4 flex-wrap">
        <div className="relative flex-1 min-w-[220px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={filtro}
            onChange={e => setFiltro(e.target.value)}
            placeholder="Buscar por RUC, razon social o numero..."
            className="input pl-9"
          />
        </div>

        {editable && filtrados.length > 0 && (
          <div className="flex items-center gap-1">
            <button
              onClick={() => toggleTodos(true)}
              disabled={todosMarcados}
              className="text-xs px-3 py-2 rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Seleccionar todos
            </button>
            <button
              onClick={() => toggleTodos(false)}
              disabled={ningunoMarcado}
              className="text-xs px-3 py-2 rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
            >
              Deseleccionar
            </button>
          </div>
        )}

        <span className={`text-[10px] px-2 py-1 rounded-full font-semibold ${
          fuente === 'SUNAT_SIRE'
            ? 'bg-success-50 text-success-900'
            : 'bg-warning-50 text-warning-900'
        }`}>
          {fuente === 'SUNAT_SIRE' ? 'Datos SUNAT' : fuente === 'MOCK' ? 'Datos simulados' : 'Sin datos'}
        </span>
      </div>

      {/* Contador */}
      <div className="mb-3 flex items-center justify-between text-xs">
        <p className="text-gray-600">
          <span className="font-semibold text-gray-900">{totales.count}</span>
          {' de '}
          <span className="font-semibold text-gray-900">{totales.total}</span>
          {' comprobantes incluidos'}
          {filtro && (
            <span className="text-gray-400"> - mostrando {filtrados.length}</span>
          )}
        </p>
        {!editable && (
          <span className="text-[11px] text-gray-400 italic">
            Solo lectura - el PDT esta en estado no editable
          </span>
        )}
      </div>

      {/* Tabla */}
      {loading ? (
        <div className="py-12 text-center text-gray-400">
          <Loader2 size={20} className="animate-spin mx-auto mb-2" />
          <p className="text-sm">Cargando comprobantes...</p>
        </div>
      ) : error ? (
        <div className="py-8 text-center">
          <AlertCircle size={20} className="text-danger-600 mx-auto mb-2" />
          <p className="text-sm text-danger-700">{error}</p>
        </div>
      ) : items.length === 0 ? (
        <div className="py-12 text-center text-gray-400">
          <FileText size={24} className="mx-auto mb-2" />
          <p className="text-sm text-gray-600 mb-1">No hay comprobantes importados</p>
          <p className="text-xs">
            Presiona <strong>"Descargar de SUNAT"</strong> en el editor para importar la propuesta.
          </p>
        </div>
      ) : filtrados.length === 0 ? (
        <div className="py-8 text-center text-gray-400 text-sm">
          Ningun comprobante coincide con "{filtro}"
        </div>
      ) : (
        <div className="border border-gray-200 rounded-lg overflow-hidden">
          <div className="max-h-[50vh] overflow-y-auto">
            <table className="w-full text-xs">
              <thead className="bg-gray-50 sticky top-0 z-10">
                <tr className="text-gray-600 border-b border-gray-200">
                  <th className="py-2 px-3 text-left font-semibold w-10">
                    {editable && (
                      <input
                        type="checkbox"
                        checked={todosMarcados}
                        onChange={() => toggleTodos(!todosMarcados)}
                        className="rounded"
                      />
                    )}
                  </th>
                  <th className="py-2 px-2 text-left font-semibold">Tipo</th>
                  <th className="py-2 px-2 text-left font-semibold">Comprobante</th>
                  <th className="py-2 px-2 text-left font-semibold">Fecha</th>
                  <th className="py-2 px-2 text-left font-semibold">
                    {esVentas ? 'Cliente' : 'Proveedor'}
                  </th>
                  <th className="py-2 px-2 text-right font-semibold">Base</th>
                  <th className="py-2 px-2 text-right font-semibold">IGV</th>
                  <th className="py-2 px-2 text-right font-semibold">Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtrados.map(i => (
                  <tr
                    key={i.id}
                    onClick={() => toggle(i.id)}
                    className={`transition-colors ${editable ? 'cursor-pointer' : 'cursor-default'} ${
                      i.incluido
                        ? 'hover:bg-brand-50/50'
                        : 'bg-gray-50/50 text-gray-400 hover:bg-gray-50'
                    }`}
                  >
                    <td className="py-2 px-3">
                      <input
                        type="checkbox"
                        checked={i.incluido}
                        onChange={() => toggle(i.id)}
                        onClick={(e) => e.stopPropagation()}
                        disabled={!editable}
                        className="rounded"
                      />
                    </td>
                    <td className="py-2 px-2 font-medium">
                      {TIPO_COMPROBANTE_LABEL[i.tipo_comprobante] || i.tipo_comprobante}
                    </td>
                    <td className="py-2 px-2 font-mono">
                      {i.serie}-{i.numero}
                    </td>
                    <td className="py-2 px-2">
                      {new Date(i.fecha_emision).toLocaleDateString('es-PE')}
                    </td>
                    <td className="py-2 px-2 max-w-[220px] truncate">
                      <div className="truncate">{i.razon_social}</div>
                      {i.ruc && (
                        <div className="text-[10px] text-gray-400 font-mono">{i.ruc}</div>
                      )}
                    </td>
                    <td className="py-2 px-2 text-right font-mono">{formatoSoles(i.base)}</td>
                    <td className="py-2 px-2 text-right font-mono">{formatoSoles(i.igv)}</td>
                    <td className="py-2 px-2 text-right font-mono font-semibold">
                      {formatoSoles(i.total)}
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot className="bg-gray-50 sticky bottom-0">
                <tr className="border-t-2 border-gray-200 font-semibold text-gray-800">
                  <td colSpan={5} className="py-2 px-3 text-right text-[11px] uppercase tracking-wider text-gray-600">
                    Subtotales de incluidos
                    {esVentas ? (
                      <span className="inline-flex items-center gap-1 ml-2 text-success-700">
                        <TrendingUp size={11} />
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 ml-2 text-brand-700">
                        <TrendingDown size={11} />
                      </span>
                    )}
                  </td>
                  <td className="py-2 px-2 text-right font-mono">{formatoSoles(totales.base)}</td>
                  <td className="py-2 px-2 text-right font-mono">{formatoSoles(totales.igv)}</td>
                  <td className="py-2 px-2 text-right font-mono">{formatoSoles(totales.totalImporte)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>
      )}
    </Modal>
  )
}
'@ | Set-Content "frontend/src/components/DetalleComprobantesModal.tsx"

Write-Host "  [OK] DetalleComprobantesModal.tsx creado" -ForegroundColor Green

# ============================================================
# 4. DeclaracionEditor.tsx - Agregar ojitos e integrar modal
# ============================================================

Write-Host ""
Write-Host "Actualizando DeclaracionEditor.tsx con ojitos y modal..." -ForegroundColor Yellow

@'
import { useEffect, useState, useMemo } from 'react'
import { useParams, useOutletContext, useNavigate } from 'react-router-dom'
import {
  ArrowLeft, Download, Loader2, CheckCircle2, AlertCircle,
  Save, Send, XCircle, RefreshCw, Info, Database, Cloud,
  TrendingUp, TrendingDown, FileText, Settings, Eye,
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import Modal from '../../components/Modal'
import DetalleComprobantesModal from '../../components/DetalleComprobantesModal'
import { pdt621Service, formatoSoles } from '../../services/pdt621Service'
import { useDebounce } from '../../hooks/useDebounce'
import {
  MESES_LABEL, ESTADO_CONFIG
} from '../../types/pdt621'
import type {
  PDT621, ImportacionSunat, Ajustes, ResultadoCalculo
} from '../../types/pdt621'
import type { EmpresaDetalle } from '../../types/empresa'
import { REGIMENES_LABEL } from '../../types/empresa'

interface Ctx { empresa: EmpresaDetalle }

export default function DeclaracionEditor() {
  const { pdtId } = useParams<{ pdtId: string }>()
  const { empresa } = useOutletContext<Ctx>()
  const navigate = useNavigate()

  const [pdt, setPdt] = useState<PDT621 | null>(null)
  const [loading, setLoading] = useState(true)
  const [importacion, setImportacion] = useState<ImportacionSunat | null>(null)

  const [ajustes, setAjustes] = useState<Ajustes>({
    saldo_favor_anterior: 0,
    percepciones_periodo: 0,
    retenciones_periodo: 0,
    pagos_anticipados: 0,
    retenciones_renta: 0,
  })

  const [calculo, setCalculo] = useState<ResultadoCalculo | null>(null)
  const [importando, setImportando] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [mensaje, setMensaje] = useState<{ tipo: 'success' | 'error'; texto: string } | null>(null)
  const [modalPresentar, setModalPresentar] = useState(false)
  const [modalResultado, setModalResultado] = useState(false)
  const [numOperacion, setNumOperacion] = useState('')

  // Modales de detalle de comprobantes
  const [modalDetalle, setModalDetalle] = useState<null | 'ventas' | 'compras'>(null)

  const ajustesDebounced = useDebounce(ajustes, 600)

  useEffect(() => {
    if (pdtId) cargar(Number(pdtId))
  }, [pdtId])

  useEffect(() => {
    if (pdt && !loading) {
      recalcularVivo()
    }
  }, [ajustesDebounced, pdt])

  async function cargar(id: number) {
    setLoading(true)
    try {
      const data = await pdt621Service.obtener(id)
      setPdt(data)
      const saldo = await pdt621Service.sugerirSaldoFavor(empresa.id, data.ano, data.mes)
      if (saldo.saldo_sugerido > 0) {
        setAjustes(a => ({ ...a, saldo_favor_anterior: saldo.saldo_sugerido }))
      }
    } finally { setLoading(false) }
  }

  async function recalcularVivo() {
    if (!pdt) return
    try {
      const res = await pdt621Service.aplicarAjustes(pdt.id, ajustesDebounced)
      setCalculo(res)
    } catch (err) { console.error(err) }
  }

  async function handleImportarSunat() {
    if (!pdt) return
    setImportando(true)
    setMensaje(null)
    try {
      const res = await pdt621Service.importarSunat(pdt.id)
      setImportacion(res)
      await cargar(pdt.id)
      setMensaje({
        tipo: 'success',
        texto: res.fuente === 'SUNAT_SIRE'
          ? 'Datos descargados exitosamente desde SUNAT SIRE'
          : 'Datos importados (modo simulado - configura credenciales API SUNAT para descarga real)',
      })
    } catch (err: any) {
      setMensaje({
        tipo: 'error',
        texto: err.response?.data?.detail || 'Error al importar desde SUNAT',
      })
    } finally { setImportando(false) }
  }

  async function handleGuardarBorrador() {
    if (!pdt) return
    setGuardando(true)
    try {
      await pdt621Service.aplicarAjustes(pdt.id, ajustes)
      setMensaje({ tipo: 'success', texto: 'Borrador guardado' })
      setTimeout(() => setMensaje(null), 2500)
    } finally { setGuardando(false) }
  }

  async function handleGenerar() {
    if (!pdt) return
    setGuardando(true)
    try {
      await pdt621Service.aplicarAjustes(pdt.id, ajustes)
      const actualizado = await pdt621Service.cambiarEstado(pdt.id, 'GENERATED')
      setPdt(actualizado)
      setMensaje({ tipo: 'success', texto: 'Declaracion generada correctamente' })
    } catch (err: any) {
      setMensaje({ tipo: 'error', texto: err.response?.data?.detail || 'Error al generar' })
    } finally { setGuardando(false) }
  }

  async function handlePresentar() {
    if (!pdt) return
    setGuardando(true)
    try {
      const actualizado = await pdt621Service.cambiarEstado(
        pdt.id, 'SUBMITTED', numOperacion || undefined
      )
      setPdt(actualizado)
      setModalPresentar(false)
      setMensaje({ tipo: 'success', texto: 'Declaracion marcada como presentada' })
    } finally { setGuardando(false) }
  }

  async function handleResultado(resultado: 'ACCEPTED' | 'REJECTED', mensajeErr?: string) {
    if (!pdt) return
    setGuardando(true)
    try {
      const actualizado = await pdt621Service.cambiarEstado(
        pdt.id, resultado, undefined, mensajeErr
      )
      setPdt(actualizado)
      setModalResultado(false)
      setMensaje({
        tipo: resultado === 'ACCEPTED' ? 'success' : 'error',
        texto: resultado === 'ACCEPTED'
          ? 'Declaracion aceptada por SUNAT'
          : 'Declaracion rechazada',
      })
    } finally { setGuardando(false) }
  }

  // Callback cuando se aplican cambios en el modal: recarga el PDT y recalcula
  async function onSeleccionAplicada() {
    if (!pdt) return
    setMensaje({ tipo: 'success', texto: 'Seleccion aplicada. PDT recalculado.' })
    setTimeout(() => setMensaje(null), 2500)
    await cargar(pdt.id)
  }

  if (loading || !pdt) {
    return (
      <div className="p-8 flex items-center justify-center text-gray-400">
        <Loader2 size={16} className="animate-spin mr-2" /> Cargando declaracion...
      </div>
    )
  }

  const estadoCfg = ESTADO_CONFIG[pdt.estado]
  const esEditable = pdt.estado === 'DRAFT' || pdt.estado === 'REJECTED'
  const tieneDatos = Number(pdt.c100_ventas_gravadas) > 0 || Number(pdt.c120_compras_gravadas) > 0

  const totales = calculo || {
    igv: {
      igv_debito: Number(pdt.c140igv_igv_debito),
      igv_credito: Number(pdt.c180_igv_credito),
      igv_resultante: Number(pdt.c140igv_igv_debito) - Number(pdt.c180_igv_credito),
      total_creditos_aplicables: 0,
      igv_a_pagar: Number(pdt.c184_igv_a_pagar),
      saldo_favor_siguiente: 0,
      percepciones_aplicadas: 0,
      retenciones_aplicadas: 0,
      saldo_favor_aplicado: 0,
      subtotal_ventas: 0,
      subtotal_compras: 0,
    },
    renta: {
      regimen: empresa.regimen_tributario,
      tasa_aplicada: 0.015,
      base_calculo: Number(pdt.c301_ingresos_netos),
      renta_bruta: Number(pdt.c309_pago_a_cuenta_renta),
      creditos_aplicados: 0,
      renta_a_pagar: Number(pdt.c318_renta_a_pagar),
      observaciones: '',
    },
    total_a_pagar: Number(pdt.total_a_pagar),
  }

  return (
    <>
      <PageHeader
        eyebrow={`${empresa.razon_social} - PDT 621`}
        title={`${MESES_LABEL[pdt.mes]} ${pdt.ano}`}
        description={`Declaracion mensual IGV y Renta - ${REGIMENES_LABEL[empresa.regimen_tributario]}`}
        actions={
          <div className="flex items-center gap-2">
            <button
              onClick={() => navigate(`/empresas/${empresa.id}/declaraciones`)}
              className="btn-secondary flex items-center gap-2"
            >
              <ArrowLeft size={14} /> Volver
            </button>
            <span className={`text-xs font-semibold px-3 py-1.5 rounded-full ${estadoCfg.bg} ${estadoCfg.color}`}>
              {estadoCfg.label}
            </span>
          </div>
        }
      />

      <div className="p-6 lg:p-8 grid grid-cols-1 lg:grid-cols-3 gap-6">

        {/* Columna principal */}
        <div className="lg:col-span-2 space-y-4">

          {/* Mensaje */}
          {mensaje && (
            <div className={`rounded-lg p-3 flex items-start gap-2 text-sm ${
              mensaje.tipo === 'success'
                ? 'bg-success-50 text-success-900 border border-success-600/30'
                : 'bg-danger-50 text-danger-900 border border-danger-600/30'
            }`}>
              {mensaje.tipo === 'success' ? <CheckCircle2 size={14} className="mt-0.5" /> : <AlertCircle size={14} className="mt-0.5" />}
              <p>{mensaje.texto}</p>
            </div>
          )}

          {/* Datos desde SUNAT */}
          <div className="card">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <h2 className="font-heading font-bold text-gray-900 flex items-center gap-2">
                  <Database size={14} className="text-brand-800" />
                  Datos desde SUNAT
                </h2>
                {tieneDatos && importacion && (
                  <span className={`text-[10px] px-2 py-0.5 rounded-full font-semibold ${
                    importacion.fuente === 'SUNAT_SIRE'
                      ? 'bg-success-50 text-success-900'
                      : 'bg-warning-50 text-warning-900'
                  }`}>
                    {importacion.fuente === 'SUNAT_SIRE' ? 'Datos reales' : 'Datos simulados'}
                  </span>
                )}
              </div>
              {esEditable && (
                <button
                  onClick={handleImportarSunat}
                  disabled={importando}
                  className="btn-primary flex items-center gap-2 text-xs"
                >
                  {importando
                    ? <Loader2 size={12} className="animate-spin" />
                    : <Download size={12} />}
                  {tieneDatos ? 'Volver a descargar' : 'Descargar de SUNAT'}
                </button>
              )}
            </div>

            {!tieneDatos ? (
              <div className="p-8 text-center">
                <Cloud size={32} className="text-gray-300 mx-auto mb-2" />
                <p className="text-sm text-gray-600 mb-1">No hay datos importados</p>
                <p className="text-xs text-gray-400">
                  Click en <strong>"Descargar de SUNAT"</strong> para obtener las ventas y compras del periodo
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-2 divide-x divide-gray-100">
                {/* ── VENTAS ── */}
                <div className="p-5">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2 text-xs text-gray-500 uppercase tracking-wide font-semibold">
                      <TrendingUp size={12} className="text-success-600" /> Ventas (RVIE)
                    </div>
                    <button
                      onClick={() => setModalDetalle('ventas')}
                      className="inline-flex items-center gap-1 text-[11px] text-brand-800 hover:text-brand-900 font-medium hover:underline"
                      title="Ver detalle de comprobantes"
                    >
                      <Eye size={12} /> Ver detalle
                    </button>
                  </div>
                  <div className="space-y-1 text-sm">
                    <DataRow label="Gravadas" value={formatoSoles(Number(pdt.c100_ventas_gravadas))} />
                    <DataRow label="No gravadas" value={formatoSoles(Number(pdt.c104_ventas_no_gravadas))} />
                    <DataRow label="Exportaciones" value={formatoSoles(Number(pdt.c105_exportaciones))} />
                    <div className="pt-2 mt-2 border-t border-gray-100">
                      <DataRow label="IGV debito" value={formatoSoles(Number(pdt.c140igv_igv_debito))} destacado />
                    </div>
                  </div>
                </div>

                {/* ── COMPRAS ── */}
                <div className="p-5">
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2 text-xs text-gray-500 uppercase tracking-wide font-semibold">
                      <TrendingDown size={12} className="text-brand-600" /> Compras (RCE)
                    </div>
                    <button
                      onClick={() => setModalDetalle('compras')}
                      className="inline-flex items-center gap-1 text-[11px] text-brand-800 hover:text-brand-900 font-medium hover:underline"
                      title="Ver detalle de comprobantes"
                    >
                      <Eye size={12} /> Ver detalle
                    </button>
                  </div>
                  <div className="space-y-1 text-sm">
                    <DataRow label="Gravadas" value={formatoSoles(Number(pdt.c120_compras_gravadas))} />
                    <div className="pt-2 mt-2 border-t border-gray-100">
                      <DataRow label="IGV credito" value={formatoSoles(Number(pdt.c180_igv_credito))} destacado />
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Ajustes del contador */}
          <div className="card">
            <div className="px-5 py-4 border-b border-gray-100">
              <h2 className="font-heading font-bold text-gray-900 flex items-center gap-2">
                <Settings size={14} className="text-brand-800" />
                Ajustes del contador
              </h2>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Creditos IGV</p>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <AjusteInput
                    label="Saldo a favor mes anterior"
                    value={ajustes.saldo_favor_anterior || 0}
                    onChange={v => setAjustes(a => ({ ...a, saldo_favor_anterior: v }))}
                    disabled={!esEditable}
                    hint="Sugerido del PDT anterior"
                  />
                  <AjusteInput
                    label="Percepciones del periodo"
                    value={ajustes.percepciones_periodo || 0}
                    onChange={v => setAjustes(a => ({ ...a, percepciones_periodo: v }))}
                    disabled={!esEditable}
                  />
                  <AjusteInput
                    label="Retenciones del periodo"
                    value={ajustes.retenciones_periodo || 0}
                    onChange={v => setAjustes(a => ({ ...a, retenciones_periodo: v }))}
                    disabled={!esEditable}
                  />
                </div>
              </div>

              <div>
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Creditos renta</p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <AjusteInput
                    label="Pagos anticipados"
                    value={ajustes.pagos_anticipados || 0}
                    onChange={v => setAjustes(a => ({ ...a, pagos_anticipados: v }))}
                    disabled={!esEditable}
                  />
                  <AjusteInput
                    label="Retenciones renta"
                    value={ajustes.retenciones_renta || 0}
                    onChange={v => setAjustes(a => ({ ...a, retenciones_renta: v }))}
                    disabled={!esEditable}
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Acciones segun estado */}
          {esEditable && (
            <div className="flex items-center gap-2 justify-end">
              <button
                onClick={handleGuardarBorrador}
                disabled={guardando}
                className="btn-secondary flex items-center gap-2"
              >
                {guardando ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
                Guardar borrador
              </button>
              <button
                onClick={handleGenerar}
                disabled={guardando || !tieneDatos}
                className="btn-primary flex items-center gap-2"
                title={!tieneDatos ? 'Primero descarga datos desde SUNAT' : ''}
              >
                <FileText size={14} /> Generar declaracion
              </button>
            </div>
          )}

          {pdt.estado === 'GENERATED' && (
            <div className="flex items-center gap-2 justify-end">
              <button
                onClick={() => pdt621Service.cambiarEstado(pdt.id, 'DRAFT').then(p => setPdt(p))}
                className="btn-secondary"
              >
                Volver a borrador
              </button>
              <button
                onClick={() => setModalPresentar(true)}
                className="btn-primary flex items-center gap-2"
              >
                <Send size={14} /> Marcar como presentada
              </button>
            </div>
          )}

          {pdt.estado === 'SUBMITTED' && (
            <div className="flex items-center gap-2 justify-end">
              <button
                onClick={() => setModalResultado(true)}
                className="btn-primary flex items-center gap-2"
              >
                <CheckCircle2 size={14} /> Registrar resultado
              </button>
            </div>
          )}

          {pdt.estado === 'ACCEPTED' && (
            <div className="rounded-lg bg-success-50 border border-success-600/30 p-4 flex items-start gap-3">
              <CheckCircle2 className="text-success-600 flex-shrink-0 mt-0.5" size={16} />
              <div className="text-sm">
                <p className="font-semibold text-success-900">Declaracion aceptada por SUNAT</p>
                {pdt.numero_operacion && (
                  <p className="text-success-700 text-xs mt-1">
                    Numero de operacion: <span className="font-mono font-semibold">{pdt.numero_operacion}</span>
                  </p>
                )}
              </div>
            </div>
          )}

          {pdt.estado === 'REJECTED' && pdt.mensaje_error_sunat && (
            <div className="rounded-lg bg-danger-50 border border-danger-600/30 p-4 flex items-start gap-3">
              <XCircle className="text-danger-600 flex-shrink-0 mt-0.5" size={16} />
              <div className="text-sm">
                <p className="font-semibold text-danger-900">Declaracion rechazada</p>
                <p className="text-danger-700 text-xs mt-1">{pdt.mensaje_error_sunat}</p>
              </div>
            </div>
          )}
        </div>

        {/* Sidebar: calculo vivo */}
        <div className="space-y-4">
          <div className="card sticky top-4">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
              <h2 className="font-heading font-bold text-gray-900 flex items-center gap-2">
                <RefreshCw size={14} className="text-brand-800" />
                Calculo en vivo
              </h2>
            </div>

            <div className="p-5 space-y-4">
              {/* IGV */}
              <div>
                <p className="text-[10px] font-semibold text-gray-500 uppercase tracking-wider mb-2">IGV</p>
                <div className="space-y-1 text-sm">
                  <DataRow label="Debito" value={formatoSoles(totales.igv.igv_debito)} />
                  <DataRow label="- Credito" value={formatoSoles(totales.igv.igv_credito)} />
                  <div className="pt-1 mt-1 border-t border-dashed border-gray-200">
                    <DataRow label="Sub-total" value={formatoSoles(totales.igv.igv_resultante)} />
                  </div>
                  {totales.igv.saldo_favor_aplicado > 0 && (
                    <DataRow label="- Saldo aplicado" value={formatoSoles(totales.igv.saldo_favor_aplicado)} chico />
                  )}
                  {totales.igv.percepciones_aplicadas > 0 && (
                    <DataRow label="- Percepciones" value={formatoSoles(totales.igv.percepciones_aplicadas)} chico />
                  )}
                  {totales.igv.retenciones_aplicadas > 0 && (
                    <DataRow label="- Retenciones" value={formatoSoles(totales.igv.retenciones_aplicadas)} chico />
                  )}
                  <div className={`pt-2 mt-2 border-t border-gray-200 p-2 rounded ${
                    totales.igv.igv_a_pagar > 0 ? 'bg-brand-50' : 'bg-gray-50'
                  }`}>
                    <DataRow label="IGV a pagar" value={formatoSoles(totales.igv.igv_a_pagar)} destacado />
                  </div>
                </div>
              </div>

              {/* Renta */}
              <div>
                <p className="text-[10px] font-semibold text-gray-500 uppercase tracking-wider mb-2">
                  Renta ({totales.renta.regimen})
                </p>
                <div className="space-y-1 text-sm">
                  <DataRow label="Base" value={formatoSoles(totales.renta.base_calculo)} />
                  <DataRow
                    label={`Tasa ${(totales.renta.tasa_aplicada * 100).toFixed(2)}%`}
                    value={formatoSoles(totales.renta.renta_bruta)}
                  />
                  {totales.renta.creditos_aplicados > 0 && (
                    <DataRow label="- Creditos" value={formatoSoles(totales.renta.creditos_aplicados)} chico />
                  )}
                  <div className={`pt-2 mt-2 border-t border-gray-200 p-2 rounded ${
                    totales.renta.renta_a_pagar > 0 ? 'bg-brand-50' : 'bg-gray-50'
                  }`}>
                    <DataRow label="Renta a pagar" value={formatoSoles(totales.renta.renta_a_pagar)} destacado />
                  </div>
                </div>
              </div>

              {/* Total */}
              <div className="bg-sidebar-bg text-white rounded-lg p-4">
                <p className="text-[10px] font-semibold text-sidebar-muted uppercase tracking-wider mb-1">Total a pagar</p>
                <p className="font-mono font-bold text-2xl">
                  {formatoSoles(totales.total_a_pagar)}
                </p>
              </div>
            </div>
          </div>
        </div>

      </div>

      {/* ── Modal: Marcar como presentada ── */}
      <Modal
        isOpen={modalPresentar}
        onClose={() => !guardando && setModalPresentar(false)}
        title="Marcar como presentada"
        description="Registra el numero de operacion que devolvio SUNAT"
        size="sm"
        footer={
          <>
            <button onClick={() => setModalPresentar(false)} className="btn-secondary" disabled={guardando}>
              Cancelar
            </button>
            <button onClick={handlePresentar} disabled={guardando} className="btn-primary">
              {guardando ? <Loader2 size={14} className="animate-spin" /> : 'Confirmar'}
            </button>
          </>
        }
      >
        <div className="space-y-3">
          <div>
            <label className="label">Numero de operacion (opcional)</label>
            <input
              value={numOperacion}
              onChange={e => setNumOperacion(e.target.value)}
              className="input font-mono"
              placeholder="Ejemplo: 1234567890"
            />
          </div>
          <div className="bg-warning-50 border border-warning-600/30 rounded-lg p-3 flex gap-2 text-xs">
            <Info size={14} className="text-warning-700 flex-shrink-0 mt-0.5" />
            <p className="text-warning-900">
              Asegurate de haber presentado el PDT en la plataforma de SUNAT antes de marcar como presentada.
            </p>
          </div>
        </div>
      </Modal>

      {/* ── Modal: Registrar resultado ── */}
      <Modal
        isOpen={modalResultado}
        onClose={() => !guardando && setModalResultado(false)}
        title="Registrar resultado"
        description="Indica si SUNAT acepto o rechazo la declaracion"
        size="sm"
        footer={
          <button onClick={() => setModalResultado(false)} className="btn-secondary" disabled={guardando}>
            Cerrar
          </button>
        }
      >
        <div className="space-y-3">
          <button
            onClick={() => handleResultado('ACCEPTED')}
            disabled={guardando}
            className="w-full p-4 border-2 border-success-600/30 hover:bg-success-50 rounded-lg flex items-center gap-3 transition-colors"
          >
            <CheckCircle2 className="text-success-600" size={20} />
            <div className="text-left">
              <p className="font-semibold text-success-900">Aceptada</p>
              <p className="text-xs text-success-700">SUNAT acepto la declaracion</p>
            </div>
          </button>

          <button
            onClick={() => {
              const msg = prompt('Mensaje de error de SUNAT (opcional):')
              handleResultado('REJECTED', msg || undefined)
            }}
            disabled={guardando}
            className="w-full p-4 border-2 border-danger-600/30 hover:bg-danger-50 rounded-lg flex items-center gap-3 transition-colors"
          >
            <XCircle className="text-danger-600" size={20} />
            <div className="text-left">
              <p className="font-semibold text-danger-900">Rechazada</p>
              <p className="text-xs text-danger-700">SUNAT rechazo la declaracion</p>
            </div>
          </button>
        </div>
      </Modal>

      {/* ── Modal: Detalle de comprobantes ── */}
      {modalDetalle && pdt && (
        <DetalleComprobantesModal
          isOpen={!!modalDetalle}
          onClose={() => setModalDetalle(null)}
          pdtId={pdt.id}
          tipo={modalDetalle}
          editable={esEditable}
          onAplicado={onSeleccionAplicada}
        />
      )}
    </>
  )
}


// ── Componentes internos ────────────────────────────

function DataRow({ label, value, destacado, chico }: {
  label: string; value: string; destacado?: boolean; chico?: boolean
}) {
  return (
    <div className={`flex items-center justify-between ${chico ? 'text-xs text-gray-500' : ''}`}>
      <span className={destacado ? 'font-semibold text-gray-900' : 'text-gray-600'}>{label}</span>
      <span className={`font-mono ${destacado ? 'font-bold text-gray-900' : 'text-gray-700'}`}>{value}</span>
    </div>
  )
}

function AjusteInput({ label, value, onChange, disabled, hint }: {
  label: string; value: number; onChange: (v: number) => void; disabled?: boolean; hint?: string
}) {
  return (
    <div>
      <label className="label text-xs">{label}</label>
      <div className="relative">
        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">S/</span>
        <input
          type="number"
          min="0"
          step="0.01"
          value={value || ''}
          onChange={e => onChange(Number(e.target.value) || 0)}
          disabled={disabled}
          className="input font-mono text-right pl-8 disabled:bg-gray-50 disabled:text-gray-400"
          placeholder="0.00"
        />
      </div>
      {hint && <p className="text-[11px] text-gray-500 mt-1">{hint}</p>}
    </div>
  )
}
'@ | Set-Content "frontend/src/pages/empresa/DeclaracionEditor.tsx"

Write-Host "  [OK] DeclaracionEditor.tsx actualizado" -ForegroundColor Green

# ============================================================
# 5. Resumen
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PARTE C COMPLETADA" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Archivos modificados:" -ForegroundColor Yellow
Write-Host "  [OK] frontend/src/types/pdt621.ts" -ForegroundColor Green
Write-Host "  [OK] frontend/src/services/pdt621Service.ts" -ForegroundColor Green
Write-Host "  [OK] frontend/src/components/DetalleComprobantesModal.tsx  (nuevo)" -ForegroundColor Green
Write-Host "  [OK] frontend/src/pages/empresa/DeclaracionEditor.tsx" -ForegroundColor Green
Write-Host ""
Write-Host "COMO PROBAR:" -ForegroundColor Cyan
Write-Host "  1. Vite deberia recargar solo. Si no: cd frontend && npm run dev" -ForegroundColor Yellow
Write-Host "  2. Login con ana.perez@felicita.pe / contador123" -ForegroundColor Yellow
Write-Host "  3. Entra a 'Empresa Gamma SA' > Declaraciones > PDT Marzo 2026" -ForegroundColor Yellow
Write-Host "  4. Presiona 'Descargar de SUNAT' (ahora persiste comprobantes)" -ForegroundColor Yellow
Write-Host "  5. En la tarjeta 'Ventas (RVIE)' veras un boton 'Ver detalle' con ojito" -ForegroundColor Yellow
Write-Host "  6. Al clickear abre modal con ~15 facturas/boletas" -ForegroundColor Yellow
Write-Host "  7. Desmarca algunos comprobantes - el contador muestra X de Y" -ForegroundColor Yellow
Write-Host "  8. Presiona 'Aplicar cambios' - el sidebar derecho recalcula totales" -ForegroundColor Yellow
Write-Host "  9. Repite lo mismo con 'Compras (RCE)'" -ForegroundColor Yellow
Write-Host ""
Write-Host "FUNCIONALIDADES DEL MODAL:" -ForegroundColor Cyan
Write-Host "  - Busqueda por RUC / razon social / numero" -ForegroundColor Gray
Write-Host "  - Click en fila para toggle (ademas del checkbox)" -ForegroundColor Gray
Write-Host "  - Seleccionar/deseleccionar masivo (respeta el filtro activo)" -ForegroundColor Gray
Write-Host "  - Contador en vivo de incluidos" -ForegroundColor Gray
Write-Host "  - Subtotales en el footer (solo de incluidos)" -ForegroundColor Gray
Write-Host "  - Badge 'Datos SUNAT' o 'Datos simulados'" -ForegroundColor Gray
Write-Host "  - Alerta visual 'Hay cambios sin aplicar'" -ForegroundColor Gray
Write-Host "  - Si el PDT no es editable (SUBMITTED/ACCEPTED), solo lectura" -ForegroundColor Gray
Write-Host ""
Write-Host "ENTREGA 1 COMPLETA. Pendientes del roadmap:" -ForegroundColor Cyan
Write-Host "  - Entrega 2: Configuracion tributaria por empresa (UIT, tasas, etc.)" -ForegroundColor Gray
Write-Host "  - Entrega 3: Consulta SUNAT real (estado/condicion/domicilio)" -ForegroundColor Gray
Write-Host "  - Entrega 4: Modo nocturno" -ForegroundColor Gray
Write-Host "  - Notificaciones (las 3: in-app + email + WhatsApp)" -ForegroundColor Gray
Write-Host ""
