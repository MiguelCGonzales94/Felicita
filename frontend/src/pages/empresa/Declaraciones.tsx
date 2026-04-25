import { useEffect, useState } from 'react'
import { useOutletContext, useNavigate } from 'react-router-dom'
import {
  Plus, FileText, Calendar, ArrowRight, Loader2,
  Clock, CheckCircle2, AlertCircle, Trash2, Upload, Download
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
  const [modalSubir, setModalSubir] = useState<'venta' | 'compra' | null>(null)
  const [generando, setGenerando] = useState(false)
  const [eliminando, setEliminando] = useState(false)
  const [descargando, setDescargando] = useState<number | null>(null)

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

  async function handleDescargarPDT(pdtItem: PDT621ListItem, e: React.MouseEvent) {
    e.stopPropagation()
    setDescargando(pdtItem.id)
    try {
      const blob = await pdt621Service.descargarPDT(pdtItem.id)
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `PDT621_${empresa.ruc}_${pdtItem.ano}${String(pdtItem.mes).padStart(2, '0')}.txt`
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
    } catch (err) {
      console.error('Error al descargar PDT:', err)
      alert('Error al descargar el PDT')
    } finally {
      setDescargando(null)
    }
  }

  function puedeEliminar(pdt: PDT621ListItem) {
    return pdt.estado === 'DRAFT' || pdt.estado === 'ACCEPTED' || pdt.estado === 'REJECTED'
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
                        puedeEliminar={puedeEliminar}
                        onDescargarPDT={handleDescargarPDT}
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
              {Object.values(MESES_LABEL).map((m, i) => (
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

function PDTRow({ pdt, onVer, onEliminar, puedeEliminar, onDescargarPDT }: {
  pdt: PDT621ListItem
  onVer: () => void
  onEliminar: () => void
  puedeEliminar: (pdt: PDT621ListItem) => boolean
  onDescargarPDT: (pdt: PDT621ListItem, e: React.MouseEvent) => void
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
        {puedeEliminar(pdt) && (
          <button
            onClick={(e) => { e.stopPropagation(); onEliminar() }}
            className="opacity-0 group-hover:opacity-100 p-1.5 hover:bg-danger-50 rounded-lg transition-all text-danger-600"
            title={pdt.estado === 'DRAFT' ? 'Eliminar borrador' : `Eliminar ${pdt.estado === 'ACCEPTED' ? 'aceptada' : 'rechazada'}`}
          >
            <Trash2 size={14} />
          </button>
        )}
        {pdt.estado === 'ACCEPTED' && (
          <button
            onClick={(e) => { e.stopPropagation(); onDescargarPDT(pdt, e) }}
            className="opacity-0 group-hover:opacity-100 p-1.5 hover:bg-success-50 rounded-lg transition-all text-success-600"
            title="Descargar PDT"
          >
            <Download size={14} />
          </button>
        )}
        <ArrowRight size={14} className="text-gray-400 group-hover:text-brand-800 group-hover:translate-x-0.5 transition-all" />
      </div>
    </div>
  )
}
