import { useEffect, useMemo, useState } from 'react'
import {
  Search, Loader2, FileText, TrendingUp, TrendingDown,
  AlertCircle, Save,
} from 'lucide-react'
import Modal from './Modal'
import { pdt621Service, formatoSoles } from '../services/pdt621Service'
import { configTributariaService } from '../services/configuracionTributariaService'
import { TIPO_COMPROBANTE_LABEL } from '../types/pdt621'
import type {
  VentaDetalleItem, CompraDetalleItem, SeleccionItem,
} from '../types/pdt621'
import type { CampoSireItem } from '../types/configuracionTributaria'

type TipoTabla = 'ventas' | 'compras'

interface Props {
  isOpen: boolean
  onClose: () => void
  pdtId: number
  empresaId: number
  tipo: TipoTabla
  editable: boolean
  onAplicado: () => void
}

// Mapeo: codigo de campo SIRE -> que columna del modal controla
const CAMPO_A_COLUMNA_VENTAS: Record<string, string> = {
  tipo_cp: 'tipo', fecha_emision: 'fecha', serie_cp: 'comprobante',
  nro_doc_identidad: 'ruc', razon_social: 'contraparte',
  bi_gravada: 'base', igv_ipm: 'igv', total_cp: 'total',
}
const CAMPO_A_COLUMNA_COMPRAS: Record<string, string> = {
  tipo_cp: 'tipo', fecha_emision: 'fecha', serie_cp: 'comprobante',
  nro_doc_identidad: 'ruc', razon_social: 'contraparte',
  bi_gravado_dg: 'base', igv_ipm_dg: 'igv', total_cp: 'total',
}

const TODAS_COLUMNAS = ['tipo', 'comprobante', 'fecha', 'contraparte', 'base', 'igv', 'total']

type ItemUnificado = {
  id: number; tipo_comprobante: string; serie: string; numero: string
  fecha_emision: string; ruc: string | null; razon_social: string
  base: number; igv: number; total: number; incluido: boolean
}

function mapVenta(v: VentaDetalleItem): ItemUnificado {
  return {
    id: v.id, tipo_comprobante: v.tipo_comprobante, serie: v.serie,
    numero: v.numero, fecha_emision: v.fecha_emision,
    ruc: v.ruc_cliente, razon_social: v.razon_social_cliente,
    base: Number(v.base_gravada) + Number(v.base_no_gravada) + Number(v.exportacion),
    igv: Number(v.igv), total: Number(v.total), incluido: v.incluido,
  }
}
function mapCompra(c: CompraDetalleItem): ItemUnificado {
  return {
    id: c.id, tipo_comprobante: c.tipo_comprobante, serie: c.serie,
    numero: c.numero, fecha_emision: c.fecha_emision,
    ruc: c.ruc_proveedor, razon_social: c.razon_social_proveedor,
    base: Number(c.base_gravada) + Number(c.base_no_gravada),
    igv: Number(c.igv), total: Number(c.total), incluido: c.incluido,
  }
}

export default function DetalleComprobantesModal({
  isOpen, onClose, pdtId, empresaId, tipo, editable, onAplicado,
}: Props) {
  const [loading, setLoading] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [items, setItems] = useState<ItemUnificado[]>([])
  const [itemsOriginales, setItemsOriginales] = useState<ItemUnificado[]>([])
  const [fuente, setFuente] = useState('')
  const [filtro, setFiltro] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [columnasVisibles, setColumnasVisibles] = useState<Set<string>>(new Set(TODAS_COLUMNAS))

  const esVentas = tipo === 'ventas'
  const titulo = esVentas ? 'Detalle de Ventas (RVIE)' : 'Detalle de Compras (RCE)'

  useEffect(() => {
    if (isOpen) { cargar(); cargarCamposConfig() }
  }, [isOpen, pdtId, tipo])

  async function cargar() {
    setLoading(true); setError(null)
    try {
      if (esVentas) {
        const data = await pdt621Service.obtenerDetalleVentas(pdtId)
        const m = data.comprobantes.map(mapVenta)
        setItems(m); setItemsOriginales(m); setFuente(data.fuente)
      } else {
        const data = await pdt621Service.obtenerDetalleCompras(pdtId)
        const m = data.comprobantes.map(mapCompra)
        setItems(m); setItemsOriginales(m); setFuente(data.fuente)
      }
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al cargar comprobantes')
    } finally { setLoading(false) }
  }

  async function cargarCamposConfig() {
    try {
      const tipoSire = esVentas ? 'rvie' : 'rce'
      const data = await configTributariaService.obtenerCamposSire(empresaId, tipoSire)
      const mapa = esVentas ? CAMPO_A_COLUMNA_VENTAS : CAMPO_A_COLUMNA_COMPRAS
      const visibles = new Set<string>()
      // Siempre mostrar checkbox
      for (const campo of data.campos) {
        if (campo.marcado && mapa[campo.codigo]) visibles.add(mapa[campo.codigo])
      }
      // Siempre mostrar al menos tipo, comprobante, total (minimo util)
      visibles.add('tipo'); visibles.add('comprobante'); visibles.add('total')
      setColumnasVisibles(visibles)
    } catch { setColumnasVisibles(new Set(TODAS_COLUMNAS)) }
  }

  const filtrados = useMemo(() => {
    if (!filtro.trim()) return items
    const q = filtro.toLowerCase()
    return items.filter(i =>
      (i.ruc || '').includes(q) || i.razon_social.toLowerCase().includes(q)
      || `${i.serie}-${i.numero}`.includes(q)
    )
  }, [items, filtro])

  const totales = useMemo(() => {
    const inc = items.filter(i => i.incluido)
    return {
      count: inc.length, total: items.length,
      base: inc.reduce((s, i) => s + i.base, 0),
      igv: inc.reduce((s, i) => s + i.igv, 0),
      totalImporte: inc.reduce((s, i) => s + i.total, 0),
    }
  }, [items])

  const hayCambios = useMemo(() => {
    const m = new Map(itemsOriginales.map(i => [i.id, i.incluido]))
    return items.some(i => m.get(i.id) !== i.incluido)
  }, [items, itemsOriginales])

  function toggle(id: number) { if (!editable) return; setItems(p => p.map(i => i.id === id ? { ...i, incluido: !i.incluido } : i)) }
  function toggleTodos(v: boolean) {
    if (!editable) return
    const ids = new Set(filtrados.map(f => f.id))
    setItems(p => p.map(i => ids.has(i.id) ? { ...i, incluido: v } : i))
  }

  async function handleAplicar() {
    if (!hayCambios) return; setGuardando(true); setError(null)
    try {
      const sel: SeleccionItem[] = items.map(i => ({ id: i.id, incluido: i.incluido }))
      esVentas ? await pdt621Service.aplicarSeleccionVentas(pdtId, sel) : await pdt621Service.aplicarSeleccionCompras(pdtId, sel)
      setItemsOriginales(items); onAplicado(); onClose()
    } catch (err: any) { setError(err.response?.data?.detail || 'Error') } finally { setGuardando(false) }
  }

  const col = (c: string) => columnasVisibles.has(c)
  const todosMarcados = filtrados.length > 0 && filtrados.every(i => i.incluido)

  return (
    <Modal isOpen={isOpen} onClose={guardando ? () => {} : onClose} title={titulo}
      description="Selecciona que comprobantes entran al calculo" size="xl"
      footer={<>
        <div className="flex-1 text-xs text-gray-500 dark:text-gray-400">
          {hayCambios ? <span className="text-warning-700 font-medium flex items-center gap-1"><AlertCircle size={12} /> Cambios sin aplicar</span> : 'Sin cambios'}
        </div>
        <button onClick={onClose} className="btn-secondary" disabled={guardando}>{hayCambios ? 'Descartar' : 'Cerrar'}</button>
        {editable && <button onClick={handleAplicar} disabled={!hayCambios || guardando} className="btn-primary flex items-center gap-2">
          {guardando ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />} Aplicar cambios
        </button>}
      </>}>

      {/* Barra superior */}
      <div className="flex items-center gap-3 mb-4 flex-wrap">
        <div className="relative flex-1 min-w-[220px]">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input type="text" value={filtro} onChange={e => setFiltro(e.target.value)}
            placeholder="Buscar por RUC, razon social o numero..." className="input pl-9" />
        </div>
        {editable && filtrados.length > 0 && <div className="flex gap-1">
          <button onClick={() => toggleTodos(true)} disabled={todosMarcados} className="text-xs px-3 py-2 rounded-lg border border-gray-200 hover:bg-gray-50 disabled:opacity-40">Seleccionar todos</button>
          <button onClick={() => toggleTodos(false)} className="text-xs px-3 py-2 rounded-lg border border-gray-200 hover:bg-gray-50">Deseleccionar</button>
        </div>}
        <span className={`text-[10px] px-2 py-1 rounded-full font-semibold ${fuente === 'SUNAT_SIRE' ? 'bg-success-50 text-success-900' : 'bg-warning-50 text-warning-900'}`}>
          {fuente === 'SUNAT_SIRE' ? 'Datos SUNAT' : 'Datos simulados'}
        </span>
      </div>

      <p className="mb-3 text-xs text-gray-600"><strong>{totales.count}</strong> de <strong>{totales.total}</strong> incluidos</p>

      {loading ? <div className="py-12 text-center text-gray-400"><Loader2 size={20} className="animate-spin mx-auto mb-2" /><p className="text-sm">Cargando...</p></div>
      : error ? <div className="py-8 text-center"><AlertCircle size={20} className="text-danger-600 mx-auto mb-2" /><p className="text-sm text-danger-700">{error}</p></div>
      : items.length === 0 ? <div className="py-12 text-center text-gray-400"><FileText size={24} className="mx-auto mb-2" /><p className="text-sm">No hay comprobantes. Presiona "Descargar de SUNAT".</p></div>
      : <div className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
          <div className="max-h-[50vh] overflow-y-auto">
            <table className="w-full text-xs">
              <thead className="bg-gray-50 dark:bg-gray-800 sticky top-0 z-10">
                <tr className="text-gray-600 dark:text-gray-300 border-b">
                  <th className="py-2 px-3 text-left w-10"><input type="checkbox" checked={todosMarcados} onChange={() => toggleTodos(!todosMarcados)} className="rounded" /></th>
                  {col('tipo') && <th className="py-2 px-2 text-left font-semibold">Tipo</th>}
                  {col('comprobante') && <th className="py-2 px-2 text-left font-semibold">Comprobante</th>}
                  {col('fecha') && <th className="py-2 px-2 text-left font-semibold">Fecha</th>}
                  {col('contraparte') && <th className="py-2 px-2 text-left font-semibold">{esVentas ? 'Cliente' : 'Proveedor'}</th>}
                  {col('base') && <th className="py-2 px-2 text-right font-semibold">Base</th>}
                  {col('igv') && <th className="py-2 px-2 text-right font-semibold">IGV</th>}
                  {col('total') && <th className="py-2 px-2 text-right font-semibold">Total</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                {filtrados.map(i => (
                  <tr key={i.id} onClick={() => toggle(i.id)} className={`transition-colors ${editable ? 'cursor-pointer' : ''} ${i.incluido ? 'hover:bg-brand-50/50 dark:hover:bg-brand-900/20' : 'bg-gray-50/50 dark:bg-gray-800/50 text-gray-400'}`}>
                    <td className="py-2 px-3"><input type="checkbox" checked={i.incluido} onChange={() => toggle(i.id)} onClick={e => e.stopPropagation()} disabled={!editable} className="rounded" /></td>
                    {col('tipo') && <td className="py-2 px-2 font-medium">{TIPO_COMPROBANTE_LABEL[i.tipo_comprobante] || i.tipo_comprobante}</td>}
                    {col('comprobante') && <td className="py-2 px-2 font-mono">{i.serie}-{i.numero}</td>}
                    {col('fecha') && <td className="py-2 px-2">{new Date(i.fecha_emision).toLocaleDateString('es-PE')}</td>}
                    {col('contraparte') && <td className="py-2 px-2 max-w-[200px] truncate"><div className="truncate">{i.razon_social}</div>{i.ruc && <div className="text-[10px] text-gray-400 font-mono">{i.ruc}</div>}</td>}
                    {col('base') && <td className="py-2 px-2 text-right font-mono">{formatoSoles(i.base)}</td>}
                    {col('igv') && <td className="py-2 px-2 text-right font-mono">{formatoSoles(i.igv)}</td>}
                    {col('total') && <td className="py-2 px-2 text-right font-mono font-semibold">{formatoSoles(i.total)}</td>}
                  </tr>
                ))}
              </tbody>
              <tfoot className="bg-gray-50 dark:bg-gray-800 sticky bottom-0">
                <tr className="border-t-2 font-semibold text-gray-800 dark:text-gray-200">
                  <td colSpan={col('contraparte') ? 5 : 4} className="py-2 px-3 text-right text-[11px] uppercase tracking-wider text-gray-600">
                    Subtotales incluidos {esVentas ? <TrendingUp size={11} className="inline text-success-700" /> : <TrendingDown size={11} className="inline text-brand-700" />}
                  </td>
                  {col('base') && <td className="py-2 px-2 text-right font-mono">{formatoSoles(totales.base)}</td>}
                  {col('igv') && <td className="py-2 px-2 text-right font-mono">{formatoSoles(totales.igv)}</td>}
                  {col('total') && <td className="py-2 px-2 text-right font-mono">{formatoSoles(totales.totalImporte)}</td>}
                </tr>
              </tfoot>
            </table>
          </div>
        </div>}
    </Modal>
  )
}
