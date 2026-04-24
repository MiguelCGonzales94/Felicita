# ============================================================
#  FELICITA - Cambio 3 Parte B: Frontend modulo Declaraciones
#  .\cambio3b_declaraciones_frontend.ps1
# ============================================================

Write-Host ""
Write-Host "Cambio 3 Parte B - Frontend modulo Declaraciones" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "frontend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path "frontend/src/pages/empresa" | Out-Null

# ============================================================
# types/pdt621.ts
# ============================================================
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
'@ | Set-Content "frontend/src/types/pdt621.ts"
Write-Host "  [OK] types/pdt621.ts" -ForegroundColor Green

# ============================================================
# services/pdt621Service.ts
# ============================================================
@'
import api from './api'
import type {
  PDT621, PDT621ListItem, ImportacionSunat, Ajustes, ResultadoCalculo, EstadoPDT
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
      nuevo_estado: nuevoEstado,
      numero_operacion,
      mensaje,
    })
    return data as PDT621
  },

  // Eliminar borrador
  async eliminar(pdtId: number) {
    await api.delete(`/pdt621/${pdtId}`)
  },
}

// Helper para formatear numeros como moneda peruana
export function formatoSoles(n: number): string {
  return `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}
'@ | Set-Content "frontend/src/services/pdt621Service.ts"
Write-Host "  [OK] services/pdt621Service.ts" -ForegroundColor Green

# ============================================================
# pages/empresa/Declaraciones.tsx - Lista de PDTs
# ============================================================
@'
import { useEffect, useState } from 'react'
import { useOutletContext, useNavigate } from 'react-router-dom'
import {
  Plus, FileText, Calendar, ArrowRight, Loader2,
  Clock, CheckCircle2, AlertCircle, Trash2
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import { EmptyState } from '../../components/ui'
import Modal, { ConfirmDialog } from '../../components/Modal'
import { pdt621Service, formatoSoles } from '../../services/pdt621Service'
import { MESES_LABEL, ESTADO_CONFIG } from '../../types/pdt621'
import type { PDT621ListItem } from '../../types/pdt621'
import type { EmpresaDetalle } from '../../types/empresa'

interface Ctx { empresa: EmpresaDetalle }

export default function DeclaracionesEmpresa() {
  const { empresa } = useOutletContext<Ctx>()
  const navigate = useNavigate()

  const [pdts, setPdts] = useState<PDT621ListItem[]>([])
  const [loading, setLoading] = useState(true)
  const [modalGenerar, setModalGenerar] = useState(false)
  const [modalEliminar, setModalEliminar] = useState<PDT621ListItem | null>(null)
  const [generando, setGenerando] = useState(false)
  const [eliminando, setEliminando] = useState(false)

  const hoy = new Date()
  const [formGenerar, setFormGenerar] = useState({
    ano: hoy.getFullYear(),
    mes: hoy.getMonth() + 1,
  })

  useEffect(() => { cargar() }, [empresa.id])

  async function cargar() {
    setLoading(true)
    try {
      const res = await pdt621Service.listarPorEmpresa(empresa.id)
      setPdts(res.pdts)
    } finally { setLoading(false) }
  }

  async function handleGenerar() {
    setGenerando(true)
    try {
      const pdt = await pdt621Service.generar(empresa.id, formGenerar.ano, formGenerar.mes)
      setModalGenerar(false)
      navigate(`/empresas/${empresa.id}/declaraciones/${pdt.id}`)
    } finally { setGenerando(false) }
  }

  async function handleEliminar() {
    if (!modalEliminar) return
    setEliminando(true)
    try {
      await pdt621Service.eliminar(modalEliminar.id)
      setModalEliminar(null)
      await cargar()
    } finally { setEliminando(false) }
  }

  // Agrupar por ano
  const porAno = pdts.reduce((acc, p) => {
    if (!acc[p.ano]) acc[p.ano] = []
    acc[p.ano].push(p)
    return acc
  }, {} as Record<number, PDT621ListItem[]>)

  const anosOrdenados = Object.keys(porAno).map(Number).sort((a, b) => b - a)

  return (
    <>
      <PageHeader
        eyebrow="Obligaciones tributarias"
        title="Declaraciones"
        description="PDT 621 mensual - IGV y Renta"
        actions={
          <button
            onClick={() => setModalGenerar(true)}
            className="btn-primary flex items-center gap-2"
          >
            <Plus size={16} /> Nueva declaracion
          </button>
        }
      />

      <div className="p-6 lg:p-8 space-y-6">
        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard
            icon={<FileText size={16} />}
            label="Total declaraciones"
            value={pdts.length}
          />
          <StatCard
            icon={<Clock size={16} />}
            label="Borradores"
            value={pdts.filter(p => p.estado === 'DRAFT').length}
            accent={pdts.some(p => p.estado === 'DRAFT') ? 'warning' : 'neutral'}
          />
          <StatCard
            icon={<CheckCircle2 size={16} />}
            label="Aceptados"
            value={pdts.filter(p => p.estado === 'ACCEPTED').length}
            accent="success"
          />
          <StatCard
            icon={<AlertCircle size={16} />}
            label="Rechazados"
            value={pdts.filter(p => p.estado === 'REJECTED').length}
            accent={pdts.some(p => p.estado === 'REJECTED') ? 'danger' : 'neutral'}
          />
        </div>

        {/* Lista */}
        {loading ? (
          <div className="card p-12 text-center text-gray-400 flex items-center justify-center gap-2">
            <Loader2 size={16} className="animate-spin" /> Cargando...
          </div>
        ) : pdts.length === 0 ? (
          <div className="card">
            <EmptyState
              icon={<FileText size={40} />}
              title="Sin declaraciones"
              description="Genera la primera declaracion PDT 621 para esta empresa"
              action={
                <button
                  onClick={() => setModalGenerar(true)}
                  className="btn-primary flex items-center gap-2 mx-auto"
                >
                  <Plus size={16} /> Nueva declaracion
                </button>
              }
            />
          </div>
        ) : (
          <div className="space-y-4">
            {anosOrdenados.map(ano => (
              <div key={ano} className="card">
                <div className="px-5 py-3 border-b border-gray-100 flex items-center justify-between">
                  <h2 className="font-heading font-bold text-gray-900">Ano {ano}</h2>
                  <span className="text-xs text-gray-500">
                    {porAno[ano].length} declaracion{porAno[ano].length !== 1 ? 'es' : ''}
                  </span>
                </div>
                <div className="divide-y divide-gray-100">
                  {porAno[ano]
                    .sort((a, b) => b.mes - a.mes)
                    .map(pdt => (
                      <PDTRow
                        key={pdt.id}
                        pdt={pdt}
                        onVer={() => navigate(`/empresas/${empresa.id}/declaraciones/${pdt.id}`)}
                        onEliminar={() => setModalEliminar(pdt)}
                      />
                    ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Modal generar nueva */}
      <Modal
        isOpen={modalGenerar}
        onClose={() => !generando && setModalGenerar(false)}
        title="Nueva declaracion PDT 621"
        description="Selecciona el periodo a declarar"
        size="sm"
        footer={
          <>
            <button onClick={() => setModalGenerar(false)} className="btn-secondary" disabled={generando}>
              Cancelar
            </button>
            <button onClick={handleGenerar} className="btn-primary flex items-center gap-2" disabled={generando}>
              {generando && <Loader2 size={14} className="animate-spin" />}
              Generar borrador
            </button>
          </>
        }
      >
        <div className="space-y-4">
          <div>
            <label className="label">Ano</label>
            <select
              value={formGenerar.ano}
              onChange={e => setFormGenerar(f => ({ ...f, ano: Number(e.target.value) }))}
              className="input"
            >
              {[hoy.getFullYear(), hoy.getFullYear() - 1, hoy.getFullYear() - 2].map(a => (
                <option key={a} value={a}>{a}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="label">Mes a declarar</label>
            <select
              value={formGenerar.mes}
              onChange={e => setFormGenerar(f => ({ ...f, mes: Number(e.target.value) }))}
              className="input"
            >
              {MESES_LABEL.slice(1).map((m, i) => (
                <option key={i + 1} value={i + 1}>{m}</option>
              ))}
            </select>
          </div>
          <div className="bg-brand-50 border border-brand-200 rounded-lg p-3 text-xs text-brand-900">
            Periodo: <strong>{MESES_LABEL[formGenerar.mes]} {formGenerar.ano}</strong>
          </div>
        </div>
      </Modal>

      <ConfirmDialog
        isOpen={modalEliminar !== null}
        onClose={() => !eliminando && setModalEliminar(null)}
        onConfirm={handleEliminar}
        title="Eliminar borrador"
        message={`Eliminar la declaracion de ${modalEliminar ? MESES_LABEL[modalEliminar.mes] : ''} ${modalEliminar?.ano}? Esta accion no se puede deshacer.`}
        confirmText="Si, eliminar"
        variant="danger"
        loading={eliminando}
      />
    </>
  )
}

function StatCard({ icon, label, value, accent = 'neutral' }: {
  icon: React.ReactNode
  label: string
  value: number
  accent?: 'brand' | 'success' | 'warning' | 'danger' | 'neutral'
}) {
  const colors = {
    brand: 'text-brand-800',
    success: 'text-success-700',
    warning: 'text-warning-700',
    danger: 'text-danger-700',
    neutral: 'text-gray-900',
  }
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4 shadow-card">
      <div className="flex items-center gap-2 text-xs text-gray-500 mb-2">
        <span className="text-gray-400">{icon}</span>
        {label}
      </div>
      <p className={`text-2xl font-heading font-bold font-mono ${colors[accent]}`}>
        {value}
      </p>
    </div>
  )
}

function PDTRow({ pdt, onVer, onEliminar }: {
  pdt: PDT621ListItem
  onVer: () => void
  onEliminar: () => void
}) {
  const estadoCfg = ESTADO_CONFIG[pdt.estado]
  const fechaVenc = new Date(pdt.fecha_vencimiento + 'T00:00:00')
  const formatFecha = fechaVenc.toLocaleDateString('es-PE', {
    day: '2-digit', month: 'short', year: 'numeric'
  })

  return (
    <div
      onClick={onVer}
      className="px-5 py-4 flex items-center gap-4 hover:bg-gray-50 transition-colors cursor-pointer group"
    >
      <div className="w-10 h-10 bg-brand-50 rounded-lg flex items-center justify-center flex-shrink-0">
        <span className="text-xs font-mono font-bold text-brand-800">
          {String(pdt.mes).padStart(2, '0')}
        </span>
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-3 mb-1 flex-wrap">
          <p className="font-semibold text-gray-900">
            {MESES_LABEL[pdt.mes]} {pdt.ano}
          </p>
          <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${estadoCfg.bg} ${estadoCfg.color}`}>
            {estadoCfg.label}
          </span>
        </div>
        <div className="flex items-center gap-3 text-xs text-gray-500 flex-wrap">
          <span className="flex items-center gap-1">
            <Calendar size={11} /> Vence {formatFecha}
          </span>
          {pdt.estado === 'DRAFT' && pdt.dias_para_vencer >= 0 && (
            <span className={pdt.dias_para_vencer <= 5 ? 'text-warning-700 font-semibold' : ''}>
              {pdt.dias_para_vencer === 0 ? 'Vence hoy' :
               pdt.dias_para_vencer === 1 ? 'Vence manana' :
               `Faltan ${pdt.dias_para_vencer} dias`}
            </span>
          )}
          {pdt.nps && <span className="font-mono">NPS {pdt.nps}</span>}
        </div>
      </div>

      <div className="text-right flex-shrink-0">
        <p className="text-sm font-mono font-semibold text-gray-900">
          {formatoSoles(pdt.total_a_pagar)}
        </p>
        <p className="text-[11px] text-gray-500">Total a pagar</p>
      </div>

      <div className="flex items-center gap-1 flex-shrink-0">
        {pdt.estado === 'DRAFT' && (
          <button
            onClick={(e) => { e.stopPropagation(); onEliminar() }}
            className="opacity-0 group-hover:opacity-100 p-1.5 hover:bg-danger-50 rounded-lg transition-all text-danger-600"
            title="Eliminar borrador"
          >
            <Trash2 size={14} />
          </button>
        )}
        <ArrowRight size={14} className="text-gray-400 group-hover:text-brand-800 group-hover:translate-x-0.5 transition-all" />
      </div>
    </div>
  )
}
'@ | Set-Content "frontend/src/pages/empresa/Declaraciones.tsx"
Write-Host "  [OK] pages/empresa/Declaraciones.tsx" -ForegroundColor Green

# ============================================================
# pages/empresa/DeclaracionEditor.tsx - Editor completo del PDT
# ============================================================
@'
import { useEffect, useState, useMemo } from 'react'
import { useParams, useOutletContext, useNavigate } from 'react-router-dom'
import {
  ArrowLeft, Download, Loader2, CheckCircle2, AlertCircle,
  Save, Send, XCircle, RefreshCw, Info, Database, Cloud,
  TrendingUp, TrendingDown, FileText, Settings
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import Modal from '../../components/Modal'
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

      // Sugerir saldo a favor del mes anterior
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

  // Calculos en vivo (si hay) o del PDT guardado
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
                ? 'bg-success-50 border border-success-600/20 text-success-900'
                : 'bg-danger-50 border border-danger-600/20 text-danger-900'
            }`}>
              {mensaje.tipo === 'success'
                ? <CheckCircle2 size={16} className="flex-shrink-0 mt-0.5" />
                : <AlertCircle size={16} className="flex-shrink-0 mt-0.5" />}
              <span>{mensaje.texto}</span>
            </div>
          )}

          {/* Datos SUNAT */}
          <div className="card">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Database size={16} className="text-brand-800" />
                <h2 className="font-heading font-bold text-gray-900">Datos desde SUNAT</h2>
                {importacion && (
                  <span className={`text-xs font-semibold px-2 py-0.5 rounded-full flex items-center gap-1 ${
                    importacion.fuente === 'SUNAT_SIRE'
                      ? 'bg-success-50 text-success-900'
                      : 'bg-warning-50 text-warning-900'
                  }`}>
                    {importacion.fuente === 'SUNAT_SIRE'
                      ? <><Cloud size={10} /> SUNAT SIRE real</>
                      : <><Database size={10} /> Datos simulados</>}
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
                <div className="p-5">
                  <div className="flex items-center gap-2 text-xs text-gray-500 uppercase tracking-wide font-semibold mb-3">
                    <TrendingUp size={12} className="text-success-600" /> Ventas (RVIE)
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
                <div className="p-5">
                  <div className="flex items-center gap-2 text-xs text-gray-500 uppercase tracking-wide font-semibold mb-3">
                    <TrendingDown size={12} className="text-brand-600" /> Compras (RCE)
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

          {/* Ajustes */}
          {tieneDatos && (
            <div className="card">
              <div className="px-5 py-4 border-b border-gray-100 flex items-center gap-2">
                <Settings size={16} className="text-brand-800" />
                <h2 className="font-heading font-bold text-gray-900">Ajustes del contador</h2>
              </div>

              <div className="p-5 space-y-5">
                {/* IGV */}
                <div>
                  <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                    Creditos IGV
                  </h3>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <NumericField
                      label="Saldo a favor mes anterior"
                      value={ajustes.saldo_favor_anterior || 0}
                      onChange={v => setAjustes(a => ({ ...a, saldo_favor_anterior: v }))}
                      disabled={!esEditable}
                      hint="Sugerido del PDT anterior"
                    />
                    <NumericField
                      label="Percepciones del periodo"
                      value={ajustes.percepciones_periodo || 0}
                      onChange={v => setAjustes(a => ({ ...a, percepciones_periodo: v }))}
                      disabled={!esEditable}
                    />
                    <NumericField
                      label="Retenciones del periodo"
                      value={ajustes.retenciones_periodo || 0}
                      onChange={v => setAjustes(a => ({ ...a, retenciones_periodo: v }))}
                      disabled={!esEditable}
                    />
                  </div>
                </div>

                {/* Renta */}
                <div>
                  <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                    Creditos Renta
                  </h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <NumericField
                      label="Pagos anticipados"
                      value={ajustes.pagos_anticipados || 0}
                      onChange={v => setAjustes(a => ({ ...a, pagos_anticipados: v }))}
                      disabled={!esEditable}
                    />
                    <NumericField
                      label="Retenciones renta"
                      value={ajustes.retenciones_renta || 0}
                      onChange={v => setAjustes(a => ({ ...a, retenciones_renta: v }))}
                      disabled={!esEditable}
                    />
                  </div>
                </div>

                {/* NRUS categoria */}
                {empresa.regimen_tributario === 'NRUS' && (
                  <div>
                    <h3 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">
                      NRUS
                    </h3>
                    <div>
                      <label className="label">Categoria NRUS</label>
                      <select
                        value={ajustes.categoria_nrus || 1}
                        onChange={e => setAjustes(a => ({ ...a, categoria_nrus: Number(e.target.value) }))}
                        className="input max-w-xs"
                        disabled={!esEditable}
                      >
                        <option value={1}>Categoria 1 - Hasta S/ 5,000 / mes (cuota S/ 20)</option>
                        <option value={2}>Categoria 2 - Hasta S/ 8,000 / mes (cuota S/ 50)</option>
                      </select>
                    </div>
                  </div>
                )}
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
                    totales.igv.igv_a_pagar > 0 ? 'bg-brand-50' : 'bg-success-50'
                  }`}>
                    <DataRow
                      label="IGV a pagar"
                      value={formatoSoles(totales.igv.igv_a_pagar)}
                      destacado
                    />
                  </div>
                  {totales.igv.saldo_favor_siguiente > 0 && (
                    <div className="bg-success-50 p-2 rounded text-xs text-success-900 flex items-start gap-1.5">
                      <Info size={12} className="flex-shrink-0 mt-0.5" />
                      <span>Saldo a favor prox mes: <strong>{formatoSoles(totales.igv.saldo_favor_siguiente)}</strong></span>
                    </div>
                  )}
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
                  <div className="pt-2 mt-2 border-t border-gray-200 bg-brand-50 p-2 rounded">
                    <DataRow
                      label="Renta a pagar"
                      value={formatoSoles(totales.renta.renta_a_pagar)}
                      destacado
                    />
                  </div>
                </div>
              </div>

              {/* Total */}
              <div className="bg-sidebar rounded-lg p-4 text-white">
                <p className="text-[10px] font-semibold text-slate-300 uppercase tracking-wider mb-1">
                  Total a pagar
                </p>
                <p className="text-2xl font-heading font-bold font-mono">
                  {formatoSoles(totales.total_a_pagar)}
                </p>
              </div>

              {/* Acciones segun estado */}
              {esEditable && (
                <div className="space-y-2 pt-2 border-t border-gray-100">
                  <button
                    onClick={handleGuardarBorrador}
                    disabled={guardando}
                    className="btn-secondary w-full flex items-center justify-center gap-2 text-sm"
                  >
                    {guardando
                      ? <Loader2 size={14} className="animate-spin" />
                      : <Save size={14} />}
                    Guardar borrador
                  </button>
                  <button
                    onClick={handleGenerar}
                    disabled={guardando || !tieneDatos}
                    className="btn-primary w-full flex items-center justify-center gap-2 text-sm"
                  >
                    <FileText size={14} />
                    Generar declaracion
                  </button>
                </div>
              )}

              {pdt.estado === 'GENERATED' && (
                <div className="space-y-2 pt-2 border-t border-gray-100">
                  <button
                    onClick={() => setModalPresentar(true)}
                    className="btn-primary w-full flex items-center justify-center gap-2 text-sm"
                  >
                    <Send size={14} />
                    Marcar como presentada
                  </button>
                </div>
              )}

              {pdt.estado === 'SUBMITTED' && (
                <div className="space-y-2 pt-2 border-t border-gray-100">
                  <button
                    onClick={() => setModalResultado(true)}
                    className="btn-secondary w-full flex items-center justify-center gap-2 text-sm"
                  >
                    Registrar resultado SUNAT
                  </button>
                </div>
              )}

              {pdt.estado === 'ACCEPTED' && (
                <div className="bg-success-50 border border-success-600/20 rounded-lg p-3 text-xs text-success-900 flex items-start gap-2">
                  <CheckCircle2 size={14} className="flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="font-semibold">Declaracion aceptada</p>
                    {pdt.numero_operacion && (
                      <p className="font-mono mt-1">Op. {pdt.numero_operacion}</p>
                    )}
                  </div>
                </div>
              )}

              {pdt.estado === 'REJECTED' && pdt.mensaje_error_sunat && (
                <div className="bg-danger-50 border border-danger-600/20 rounded-lg p-3 text-xs text-danger-900 flex items-start gap-2">
                  <XCircle size={14} className="flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="font-semibold mb-1">Rechazada por SUNAT</p>
                    <p>{pdt.mensaje_error_sunat}</p>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Modal presentar */}
      <Modal
        isOpen={modalPresentar}
        onClose={() => !guardando && setModalPresentar(false)}
        title="Marcar como presentada"
        description="Registra el numero de operacion que SUNAT te devuelva"
        size="sm"
        footer={
          <>
            <button onClick={() => setModalPresentar(false)} className="btn-secondary" disabled={guardando}>
              Cancelar
            </button>
            <button onClick={handlePresentar} className="btn-primary flex items-center gap-2" disabled={guardando}>
              {guardando && <Loader2 size={14} className="animate-spin" />}
              Marcar presentada
            </button>
          </>
        }
      >
        <div>
          <label className="label">Numero de operacion (opcional)</label>
          <input
            type="text"
            value={numOperacion}
            onChange={e => setNumOperacion(e.target.value)}
            className="input font-mono"
            placeholder="Ej: 123456789"
          />
          <p className="text-xs text-gray-500 mt-2">
            Podras ingresarlo despues si aun no lo tienes
          </p>
        </div>
      </Modal>

      {/* Modal resultado */}
      <Modal
        isOpen={modalResultado}
        onClose={() => !guardando && setModalResultado(false)}
        title="Resultado de SUNAT"
        description="Que devolvio SUNAT sobre esta declaracion?"
        size="sm"
      >
        <div className="space-y-3">
          <button
            onClick={() => handleResultado('ACCEPTED')}
            disabled={guardando}
            className="w-full p-4 bg-success-50 hover:bg-success-100 border border-success-600/30 rounded-lg flex items-center gap-3 transition-colors"
          >
            <CheckCircle2 size={20} className="text-success-600" />
            <div className="text-left">
              <p className="font-semibold text-success-900 text-sm">Aceptada</p>
              <p className="text-xs text-success-700">SUNAT acepto la declaracion correctamente</p>
            </div>
          </button>

          <button
            onClick={() => {
              const msg = prompt('Mensaje de rechazo (opcional):')
              handleResultado('REJECTED', msg || undefined)
            }}
            disabled={guardando}
            className="w-full p-4 bg-danger-50 hover:bg-danger-100 border border-danger-600/30 rounded-lg flex items-center gap-3 transition-colors"
          >
            <XCircle size={20} className="text-danger-600" />
            <div className="text-left">
              <p className="font-semibold text-danger-900 text-sm">Rechazada</p>
              <p className="text-xs text-danger-700">SUNAT rechazo la declaracion</p>
            </div>
          </button>
        </div>
      </Modal>
    </>
  )
}

// ── Helpers ─────────────────────────────────────────
function DataRow({ label, value, destacado, chico }: {
  label: string
  value: string
  destacado?: boolean
  chico?: boolean
}) {
  return (
    <div className={`flex items-center justify-between ${chico ? 'text-xs text-gray-500' : ''}`}>
      <span className={destacado ? 'font-semibold' : chico ? '' : 'text-gray-600'}>{label}</span>
      <span className={`font-mono ${destacado ? 'font-bold' : ''}`}>{value}</span>
    </div>
  )
}

function NumericField({ label, value, onChange, disabled, hint }: {
  label: string
  value: number
  onChange: (v: number) => void
  disabled?: boolean
  hint?: string
}) {
  return (
    <div>
      <label className="label text-xs">{label}</label>
      <div className="relative">
        <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs text-gray-400">S/</span>
        <input
          type="number"
          step="0.01"
          min="0"
          value={value || ''}
          onChange={e => onChange(Number(e.target.value) || 0)}
          disabled={disabled}
          className="input pl-8 font-mono text-right"
          placeholder="0.00"
        />
      </div>
      {hint && <p className="text-[10px] text-gray-400 mt-1">{hint}</p>}
    </div>
  )
}
'@ | Set-Content "frontend/src/pages/empresa/DeclaracionEditor.tsx"
Write-Host "  [OK] pages/empresa/DeclaracionEditor.tsx" -ForegroundColor Green

# ============================================================
# App.tsx - registrar rutas de declaraciones
# ============================================================
@'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { BookOpen, Receipt, Users, BarChart3 } from 'lucide-react'
import { useAuthStore } from './store/authStore'
import LoginPage from './pages/Login'
import AppLayout from './components/AppLayout'
import EmpresaLayout from './components/EmpresaLayout'
import DashboardContador from './pages/contador/Dashboard'
import CalendarioPage from './pages/contador/Calendario'
import EmpresasPage from './pages/contador/Empresas'
import DashboardEmpresa from './pages/empresa/Dashboard'
import ConfiguracionEmpresa from './pages/empresa/Configuracion'
import DeclaracionesEmpresa from './pages/empresa/Declaraciones'
import DeclaracionEditor from './pages/empresa/DeclaracionEditor'
import ModuloPlaceholder from './pages/empresa/Placeholder'

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore()
  return isAuthenticated() ? <>{children}</> : <Navigate to="/login" replace />
}

function ContadorPlaceholder({ title }: { title: string }) {
  return (
    <div className="p-8">
      <h1 className="text-2xl font-heading font-bold">{title}</h1>
      <p className="text-gray-500 mt-2">Modulo en construccion</p>
    </div>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<LoginPage />} />

        <Route element={<PrivateRoute><AppLayout /></PrivateRoute>}>
          <Route path="/dashboard" element={<DashboardContador />} />
          <Route path="/empresas" element={<EmpresasPage />} />
          <Route path="/calendario" element={<CalendarioPage />} />
          <Route path="/declaraciones" element={<ContadorPlaceholder title="Declaraciones" />} />
          <Route path="/configuracion" element={<ContadorPlaceholder title="Configuracion del contador" />} />
        </Route>

        <Route path="/empresas/:id" element={<PrivateRoute><EmpresaLayout /></PrivateRoute>}>
          <Route index element={<Navigate to="dashboard" replace />} />
          <Route path="dashboard" element={<DashboardEmpresa />} />
          <Route path="declaraciones" element={<DeclaracionesEmpresa />} />
          <Route path="declaraciones/:pdtId" element={<DeclaracionEditor />} />
          <Route path="libros" element={
            <ModuloPlaceholder
              titulo="Libros electronicos (SIRE)"
              descripcion="Registro de Ventas y Registro de Compras"
              icono={BookOpen}
              eyebrow="SIRE SUNAT"
            />
          } />
          <Route path="facturacion" element={
            <ModuloPlaceholder
              titulo="Facturacion"
              descripcion="Emision de comprobantes electronicos"
              icono={Receipt}
              eyebrow="CPE"
            />
          } />
          <Route path="planillas" element={
            <ModuloPlaceholder
              titulo="Planillas (PLAME)"
              descripcion="Gestion de planillas mensuales"
              icono={Users}
              eyebrow="Recursos humanos"
            />
          } />
          <Route path="reportes" element={
            <ModuloPlaceholder
              titulo="Reportes financieros"
              descripcion="Estados financieros y analisis"
              icono={BarChart3}
              eyebrow="Reporteria"
            />
          } />
          <Route path="configuracion" element={<ConfiguracionEmpresa />} />
        </Route>

        <Route path="/" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
'@ | Set-Content "frontend/src/App.tsx"
Write-Host "  [OK] App.tsx con rutas de declaraciones" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Cambio 3 Parte B aplicada!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vite recarga solo. Si no: cd frontend && npm run dev" -ForegroundColor Yellow
Write-Host ""
Write-Host "Probar:" -ForegroundColor Yellow
Write-Host "  1. Entra a una empresa: /empresas/1" -ForegroundColor White
Write-Host "  2. Sidebar - click en 'Declaraciones'" -ForegroundColor White
Write-Host "  3. Click '+ Nueva declaracion'" -ForegroundColor White
Write-Host "  4. Elige ano y mes - 'Generar borrador'" -ForegroundColor White
Write-Host "  5. En el editor click 'Descargar de SUNAT'" -ForegroundColor White
Write-Host "     (descarga datos reales si hay creds, o mock)" -ForegroundColor Gray
Write-Host "  6. Edita percepciones/retenciones y mira el calculo vivo" -ForegroundColor White
Write-Host "  7. 'Generar declaracion' - cambia estado a GENERATED" -ForegroundColor White
Write-Host "  8. 'Marcar como presentada' - registra numero operacion" -ForegroundColor White
Write-Host "  9. 'Registrar resultado' - Aceptada / Rechazada" -ForegroundColor White
Write-Host ""
