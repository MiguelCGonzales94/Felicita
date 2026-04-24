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
