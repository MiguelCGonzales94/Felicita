import { useEffect, useState, useMemo } from 'react'
import { useOutletContext, useSearchParams } from 'react-router-dom'
import {
  Scale, Lock, Unlock, RotateCcw, Save, Loader2,
  CheckCircle2, AlertCircle, Info, Shield, Eye, EyeOff,
  ChevronDown, ChevronRight,
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import { configTributariaService } from '../../services/configuracionTributariaService'
import {
  LABELS_LEGALES, DEFAULTS_LEGALES, CAMPOS_TASA,
} from '../../types/configuracionTributaria'
import type {
  ConfiguracionTributaria, CampoSireItem, CamposSireResponse,
} from '../../types/configuracionTributaria'
import type { EmpresaDetalle } from '../../types/empresa'

interface Ctx { empresa: EmpresaDetalle }

type Tab = 'legales' | 'sire'

export default function Tributario() {
  const { empresa } = useOutletContext<Ctx>()
  const [searchParams, setSearchParams] = useSearchParams()

  const tabInicial = (searchParams.get('tab') as Tab) || 'legales'
  const [tab, setTab] = useState<Tab>(tabInicial)

  const [config, setConfig] = useState<ConfiguracionTributaria | null>(null)
  const [loading, setLoading] = useState(true)
  const [guardando, setGuardando] = useState(false)
  const [mensaje, setMensaje] = useState<{ tipo: 'success' | 'error'; texto: string } | null>(null)

  // Tab legales
  const [valores, setValores] = useState<Record<string, number>>({})
  const [desbloqueados, setDesbloqueados] = useState<Set<string>>(new Set())

  // Tab SIRE
  const [camposRvie, setCamposRvie] = useState<CampoSireItem[]>([])
  const [camposRce, setCamposRce] = useState<CampoSireItem[]>([])
  const [loadingSire, setLoadingSire] = useState(false)
  const [cluVisible, setCluVisible] = useState<{ rvie: boolean; rce: boolean }>({ rvie: false, rce: false })

  useEffect(() => { cargar() }, [empresa.id])

  useEffect(() => {
    setSearchParams({ tab }, { replace: true })
    if (tab === 'sire' && camposRvie.length === 0) cargarCamposSire()
  }, [tab])

  async function cargar() {
    setLoading(true)
    try {
      const data = await configTributariaService.obtener(empresa.id)
      setConfig(data)
      sincronizarValores(data)
    } finally { setLoading(false) }
  }

  function sincronizarValores(c: ConfiguracionTributaria) {
    const v: Record<string, number> = {}
    for (const campo of Object.keys(LABELS_LEGALES)) {
      v[campo] = (c as any)[campo]
    }
    setValores(v)
    setDesbloqueados(new Set())
  }

  async function cargarCamposSire() {
    setLoadingSire(true)
    try {
      const [rvie, rce] = await Promise.all([
        configTributariaService.obtenerCamposSire(empresa.id, 'rvie'),
        configTributariaService.obtenerCamposSire(empresa.id, 'rce'),
      ])
      setCamposRvie(rvie.campos)
      setCamposRce(rce.campos)
    } finally { setLoadingSire(false) }
  }

  // ── Handlers legales ──

  function toggleLock(campo: string) {
    setDesbloqueados(prev => {
      const next = new Set(prev)
      if (next.has(campo)) {
        next.delete(campo)
        // Restaurar al valor original si se vuelve a bloquear
        if (config) setValores(v => ({ ...v, [campo]: (config as any)[campo] }))
      } else {
        next.add(campo)
      }
      return next
    })
  }

  function handleValorChange(campo: string, valor: string) {
    const num = parseFloat(valor)
    if (!isNaN(num)) setValores(v => ({ ...v, [campo]: num }))
  }

  const hayCambiosLegales = useMemo(() => {
    if (!config) return false
    return Object.keys(LABELS_LEGALES).some(
      campo => valores[campo] !== (config as any)[campo]
    )
  }, [valores, config])

  async function guardarLegales() {
    setGuardando(true)
    setMensaje(null)
    try {
      const payload: Record<string, number> = {}
      for (const campo of Object.keys(LABELS_LEGALES)) {
        if (valores[campo] !== undefined) payload[campo] = valores[campo]
      }
      const updated = await configTributariaService.actualizarLegales(empresa.id, payload)
      setConfig(updated)
      sincronizarValores(updated)
      setMensaje({ tipo: 'success', texto: 'Valores legales actualizados. Solo aplica a nuevos PDTs.' })
      setTimeout(() => setMensaje(null), 3000)
    } catch (err: any) {
      setMensaje({ tipo: 'error', texto: err.response?.data?.detail || 'Error al guardar' })
    } finally { setGuardando(false) }
  }

  async function restaurarLegales() {
    setGuardando(true)
    try {
      const updated = await configTributariaService.restaurar(empresa.id, 'legales')
      setConfig(updated)
      sincronizarValores(updated)
      setMensaje({ tipo: 'success', texto: 'Valores restaurados a los defaults SUNAT' })
      setTimeout(() => setMensaje(null), 3000)
    } finally { setGuardando(false) }
  }

  // ── Handlers SIRE ──

  function toggleCampoSire(tipo: 'rvie' | 'rce', codigo: string) {
    const setter = tipo === 'rvie' ? setCamposRvie : setCamposRce
    setter(prev => prev.map(c =>
      c.codigo === codigo && !c.obligatorio ? { ...c, marcado: !c.marcado } : c
    ))
  }

  function toggleTodosSire(tipo: 'rvie' | 'rce', valor: boolean) {
    const setter = tipo === 'rvie' ? setCamposRvie : setCamposRce
    setter(prev => prev.map(c =>
      c.obligatorio ? c : { ...c, marcado: valor }
    ))
  }

  async function guardarCamposSire(tipo: 'rvie' | 'rce') {
    setGuardando(true)
    setMensaje(null)
    try {
      const campos = tipo === 'rvie' ? camposRvie : camposRce
      const seleccion: Record<string, boolean> = {}
      for (const c of campos) seleccion[c.codigo] = c.marcado
      await configTributariaService.actualizarCamposSire(empresa.id, tipo, seleccion)
      setMensaje({ tipo: 'success', texto: `Campos ${tipo.toUpperCase()} actualizados` })
      setTimeout(() => setMensaje(null), 3000)
    } catch (err: any) {
      setMensaje({ tipo: 'error', texto: err.response?.data?.detail || 'Error al guardar campos' })
    } finally { setGuardando(false) }
  }

  async function restaurarCamposSire(tipo: 'rvie' | 'rce') {
    setGuardando(true)
    try {
      await configTributariaService.restaurar(empresa.id, tipo)
      await cargarCamposSire()
      setMensaje({ tipo: 'success', texto: `Campos ${tipo.toUpperCase()} restaurados a defaults` })
      setTimeout(() => setMensaje(null), 3000)
    } finally { setGuardando(false) }
  }

  if (loading || !config) {
    return (
      <div className="p-8 flex items-center justify-center text-gray-400">
        <Loader2 size={16} className="animate-spin mr-2" /> Cargando configuracion...
      </div>
    )
  }

  // Valor de display: las tasas se muestran como % (multiplicar x100)
  function displayVal(campo: string, raw: number): string {
    if (CAMPOS_TASA.has(campo)) return (raw * 100).toFixed(2)
    return raw.toString()
  }

  // Valor de input → almacenamiento: las tasas se dividen entre 100
  function parseInput(campo: string, input: string): number {
    const num = parseFloat(input)
    if (isNaN(num)) return 0
    if (CAMPOS_TASA.has(campo)) return num / 100
    return num
  }

  function esModificado(campo: string): boolean {
    return Math.abs(valores[campo] - DEFAULTS_LEGALES[campo]) > 0.0001
  }

  return (
    <>
      <PageHeader
        eyebrow={empresa.razon_social}
        title="Configuracion Tributaria"
        description="Valores legales y campos SIRE por empresa"
        actions={
          config.es_personalizada ? (
            <span className="text-[11px] bg-warning-50 text-warning-900 px-3 py-1.5 rounded-full font-semibold flex items-center gap-1">
              <AlertCircle size={12} /> Valores personalizados
            </span>
          ) : (
            <span className="text-[11px] bg-success-50 text-success-900 px-3 py-1.5 rounded-full font-semibold flex items-center gap-1">
              <Shield size={12} /> Valores SUNAT por defecto
            </span>
          )
        }
      />

      {/* Tabs */}
      <div className="px-6 lg:px-8 pt-2">
        <div className="flex gap-1 border-b border-gray-200">
          <button
            onClick={() => setTab('legales')}
            className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
              tab === 'legales'
                ? 'border-brand-800 text-brand-900'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            <Scale size={14} className="inline mr-2 -mt-0.5" />
            Valores legales
          </button>
          <button
            onClick={() => setTab('sire')}
            className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
              tab === 'sire'
                ? 'border-brand-800 text-brand-900'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            <Eye size={14} className="inline mr-2 -mt-0.5" />
            Campos SIRE
          </button>
        </div>
      </div>

      <div className="p-6 lg:p-8">
        {/* Mensaje */}
        {mensaje && (
          <div className={`rounded-lg p-3 mb-4 flex items-start gap-2 text-sm ${
            mensaje.tipo === 'success'
              ? 'bg-success-50 text-success-900 border border-success-600/30'
              : 'bg-danger-50 text-danger-900 border border-danger-600/30'
          }`}>
            {mensaje.tipo === 'success' ? <CheckCircle2 size={14} className="mt-0.5" /> : <AlertCircle size={14} className="mt-0.5" />}
            <p>{mensaje.texto}</p>
          </div>
        )}

        {/* ═══ TAB VALORES LEGALES ═══ */}
        {tab === 'legales' && (
          <div className="space-y-4">
            {/* Aviso */}
            <div className="bg-brand-50 border border-brand-600/20 rounded-lg p-3 flex gap-2 text-xs">
              <Info size={14} className="text-brand-800 flex-shrink-0 mt-0.5" />
              <div className="text-brand-900">
                <p className="font-semibold mb-0.5">Los valores estan bloqueados por defecto</p>
                <p>
                  Presiona el candado para desbloquear y editar. Los cambios solo aplican a
                  <strong> nuevos PDTs</strong>; los existentes conservan los valores con los que fueron creados.
                </p>
              </div>
            </div>

            {/* Grid de valores */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Columna izquierda: UIT + IGV + RG + RER */}
              <div className="card p-5 space-y-4">
                <h3 className="font-heading font-bold text-gray-900 text-sm">General</h3>
                {['uit', 'tasa_igv'].map(campo => (
                  <CampoLegal
                    key={campo} campo={campo}
                    valor={valores[campo]} desbloqueado={desbloqueados.has(campo)}
                    modificado={esModificado(campo)}
                    onToggleLock={() => toggleLock(campo)}
                    onChange={v => setValores(prev => ({ ...prev, [campo]: parseInput(campo, v) }))}
                  />
                ))}
                <div className="border-t border-gray-100 pt-3">
                  <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">Regimen General</h4>
                  {['rg_coef_minimo', 'rg_renta_anual'].map(campo => (
                    <CampoLegal
                      key={campo} campo={campo}
                      valor={valores[campo]} desbloqueado={desbloqueados.has(campo)}
                      modificado={esModificado(campo)}
                      onToggleLock={() => toggleLock(campo)}
                      onChange={v => setValores(prev => ({ ...prev, [campo]: parseInput(campo, v) }))}
                    />
                  ))}
                </div>
                <div className="border-t border-gray-100 pt-3">
                  <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">Regimen Especial</h4>
                  <CampoLegal
                    campo="rer_tasa" valor={valores['rer_tasa']}
                    desbloqueado={desbloqueados.has('rer_tasa')}
                    modificado={esModificado('rer_tasa')}
                    onToggleLock={() => toggleLock('rer_tasa')}
                    onChange={v => setValores(prev => ({ ...prev, rer_tasa: parseInput('rer_tasa', v) }))}
                  />
                </div>
              </div>

              {/* Columna derecha: RMT + NRUS */}
              <div className="card p-5 space-y-4">
                <h3 className="font-heading font-bold text-gray-900 text-sm">MYPE Tributario (RMT)</h3>
                {['rmt_tramo1_tasa', 'rmt_tramo1_limite_uit', 'rmt_tramo2_coef_minimo',
                  'rmt_renta_anual_hasta15uit', 'rmt_renta_anual_resto'].map(campo => (
                  <CampoLegal
                    key={campo} campo={campo}
                    valor={valores[campo]} desbloqueado={desbloqueados.has(campo)}
                    modificado={esModificado(campo)}
                    onToggleLock={() => toggleLock(campo)}
                    onChange={v => setValores(prev => ({ ...prev, [campo]: parseInput(campo, v) }))}
                  />
                ))}
                <div className="border-t border-gray-100 pt-3">
                  <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">Nuevo RUS</h4>
                  {['nrus_cat1', 'nrus_cat2'].map(campo => (
                    <CampoLegal
                      key={campo} campo={campo}
                      valor={valores[campo]} desbloqueado={desbloqueados.has(campo)}
                      modificado={esModificado(campo)}
                      onToggleLock={() => toggleLock(campo)}
                      onChange={v => setValores(prev => ({ ...prev, [campo]: parseInput(campo, v) }))}
                    />
                  ))}
                </div>
              </div>
            </div>

            {/* Acciones */}
            <div className="flex items-center justify-between pt-2">
              <button
                onClick={restaurarLegales}
                disabled={guardando || !config.es_personalizada}
                className="btn-secondary flex items-center gap-2 text-xs"
              >
                <RotateCcw size={12} /> Restaurar defaults SUNAT
              </button>
              <button
                onClick={guardarLegales}
                disabled={guardando || !hayCambiosLegales}
                className="btn-primary flex items-center gap-2"
              >
                {guardando ? <Loader2 size={14} className="animate-spin" /> : <Save size={14} />}
                Guardar cambios
              </button>
            </div>
          </div>
        )}

        {/* ═══ TAB CAMPOS SIRE ═══ */}
        {tab === 'sire' && (
          <div className="space-y-4">
            {/* Aviso */}
            <div className="bg-brand-50 border border-brand-600/20 rounded-lg p-3 flex gap-2 text-xs">
              <Info size={14} className="text-brand-800 flex-shrink-0 mt-0.5" />
              <div className="text-brand-900">
                <p className="font-semibold mb-0.5">Campos de la propuesta SIRE</p>
                <p>
                  Selecciona que campos descargar y mostrar en el detalle de comprobantes.
                  Los campos obligatorios por SUNAT no pueden desmarcarse.
                </p>
              </div>
            </div>

            {loadingSire ? (
              <div className="py-12 text-center text-gray-400">
                <Loader2 size={20} className="animate-spin mx-auto mb-2" />
                <p className="text-sm">Cargando catalogo SIRE...</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                {/* Columna RVIE */}
                <BloqueCamposSire
                  titulo="Ventas (RVIE)"
                  subtitulo="Registro de Ventas e Ingresos Electronico - Anexo 3"
                  campos={camposRvie}
                  tipo="rvie"
                  cluVisible={cluVisible.rvie}
                  onToggleClu={() => setCluVisible(p => ({ ...p, rvie: !p.rvie }))}
                  onToggle={codigo => toggleCampoSire('rvie', codigo)}
                  onSelectAll={val => toggleTodosSire('rvie', val)}
                  onGuardar={() => guardarCamposSire('rvie')}
                  onRestaurar={() => restaurarCamposSire('rvie')}
                  guardando={guardando}
                />

                {/* Columna RCE */}
                <BloqueCamposSire
                  titulo="Compras (RCE)"
                  subtitulo="Registro de Compras Electronico - Anexo 11"
                  campos={camposRce}
                  tipo="rce"
                  cluVisible={cluVisible.rce}
                  onToggleClu={() => setCluVisible(p => ({ ...p, rce: !p.rce }))}
                  onToggle={codigo => toggleCampoSire('rce', codigo)}
                  onSelectAll={val => toggleTodosSire('rce', val)}
                  onGuardar={() => guardarCamposSire('rce')}
                  onRestaurar={() => restaurarCamposSire('rce')}
                  guardando={guardando}
                />
              </div>
            )}
          </div>
        )}
      </div>
    </>
  )
}


// ════════════════════════════════════════════════════════════
// COMPONENTES INTERNOS
// ════════════════════════════════════════════════════════════

function CampoLegal({ campo, valor, desbloqueado, modificado, onToggleLock, onChange }: {
  campo: string; valor: number; desbloqueado: boolean; modificado: boolean
  onToggleLock: () => void; onChange: (v: string) => void
}) {
  const meta = LABELS_LEGALES[campo]
  if (!meta) return null
  const esTasa = CAMPOS_TASA.has(campo)
  const displayValue = esTasa ? (valor * 100).toFixed(2) : valor.toString()

  return (
    <div className="mb-3">
      <div className="flex items-center justify-between mb-1">
        <label className="text-xs font-medium text-gray-700">{meta.label}</label>
        <div className="flex items-center gap-1">
          {modificado && (
            <span className="text-[9px] bg-warning-50 text-warning-800 px-1.5 py-0.5 rounded font-semibold">
              Modificado
            </span>
          )}
          <button
            onClick={onToggleLock}
            className={`p-1 rounded transition-colors ${
              desbloqueado
                ? 'text-warning-700 bg-warning-50 hover:bg-warning-100'
                : 'text-gray-400 hover:text-gray-600 hover:bg-gray-100'
            }`}
            title={desbloqueado ? 'Bloquear (volver al valor original)' : 'Desbloquear para editar'}
          >
            {desbloqueado ? <Unlock size={12} /> : <Lock size={12} />}
          </button>
        </div>
      </div>
      <div className="relative">
        <input
          type="number"
          step={esTasa ? '0.01' : '1'}
          value={displayValue}
          onChange={e => onChange(e.target.value)}
          disabled={!desbloqueado}
          className={`input font-mono text-right pr-12 text-sm disabled:bg-gray-50 disabled:text-gray-500 ${
            modificado ? 'border-warning-400 ring-1 ring-warning-200' : ''
          }`}
        />
        <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[11px] text-gray-400 font-medium">
          {meta.sufijo}
        </span>
      </div>
      <p className="text-[10px] text-gray-400 mt-0.5">{meta.hint}</p>
      {desbloqueado && (
        <p className="text-[10px] text-warning-700 mt-0.5 flex items-center gap-1">
          <AlertCircle size={10} />
          Cambiar valores legales puede generar declaraciones incorrectas
        </p>
      )}
    </div>
  )
}


function BloqueCamposSire({ titulo, subtitulo, campos, tipo, cluVisible, guardando,
  onToggleClu, onToggle, onSelectAll, onGuardar, onRestaurar }: {
  titulo: string; subtitulo: string; campos: CampoSireItem[]; tipo: string
  cluVisible: boolean; guardando: boolean
  onToggleClu: () => void; onToggle: (codigo: string) => void
  onSelectAll: (val: boolean) => void; onGuardar: () => void; onRestaurar: () => void
}) {
  const principales = campos.filter(c => !c.es_clu)
  const clu = campos.filter(c => c.es_clu)
  const marcados = campos.filter(c => c.marcado).length
  const obligatorios = campos.filter(c => c.obligatorio).length

  return (
    <div className="card">
      <div className="px-5 py-4 border-b border-gray-100">
        <h3 className="font-heading font-bold text-gray-900 text-sm">{titulo}</h3>
        <p className="text-[11px] text-gray-500 mt-0.5">{subtitulo}</p>
        <div className="flex items-center gap-3 mt-2 text-[11px]">
          <span className="text-gray-600">
            <strong className="text-gray-900">{marcados}</strong> de {campos.length} seleccionados
          </span>
          <span className="text-gray-400">|</span>
          <span className="text-brand-800 font-medium">{obligatorios} obligatorios</span>
        </div>
      </div>

      <div className="px-5 py-3 border-b border-gray-100 flex items-center gap-2">
        <button
          onClick={() => onSelectAll(true)}
          className="text-[11px] px-2.5 py-1.5 rounded border border-gray-200 hover:bg-gray-50 font-medium"
        >
          Seleccionar todos
        </button>
        <button
          onClick={() => onSelectAll(false)}
          className="text-[11px] px-2.5 py-1.5 rounded border border-gray-200 hover:bg-gray-50 font-medium"
        >
          Solo obligatorios
        </button>
      </div>

      <div className="max-h-[55vh] overflow-y-auto">
        {/* Campos principales */}
        <div className="divide-y divide-gray-50">
          {principales.map(c => (
            <CampoSireRow key={c.codigo} campo={c} onToggle={() => onToggle(c.codigo)} />
          ))}
        </div>

        {/* CLU (colapsables) */}
        {clu.length > 0 && (
          <div className="border-t border-gray-200">
            <button
              onClick={onToggleClu}
              className="w-full flex items-center gap-2 px-5 py-3 text-xs text-gray-500 hover:bg-gray-50 font-medium"
            >
              {cluVisible ? <ChevronDown size={12} /> : <ChevronRight size={12} />}
              Campos libres del usuario ({clu.length})
            </button>
            {cluVisible && (
              <div className="divide-y divide-gray-50">
                {clu.map(c => (
                  <CampoSireRow key={c.codigo} campo={c} onToggle={() => onToggle(c.codigo)} />
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* Acciones del bloque */}
      <div className="px-5 py-3 border-t border-gray-200 flex items-center justify-between">
        <button
          onClick={onRestaurar}
          disabled={guardando}
          className="text-[11px] text-gray-500 hover:text-gray-700 flex items-center gap-1"
        >
          <RotateCcw size={11} /> Restaurar defaults
        </button>
        <button
          onClick={onGuardar}
          disabled={guardando}
          className="btn-primary text-xs flex items-center gap-2"
        >
          {guardando ? <Loader2 size={12} className="animate-spin" /> : <Save size={12} />}
          Guardar {tipo.toUpperCase()}
        </button>
      </div>
    </div>
  )
}


function CampoSireRow({ campo, onToggle }: { campo: CampoSireItem; onToggle: () => void }) {
  return (
    <label
      className={`flex items-center gap-3 px-5 py-2.5 text-xs transition-colors ${
        campo.obligatorio
          ? 'cursor-not-allowed bg-gray-50/50'
          : 'cursor-pointer hover:bg-brand-50/30'
      }`}
      onClick={e => {
        if (campo.obligatorio) e.preventDefault()
      }}
    >
      <input
        type="checkbox"
        checked={campo.marcado}
        onChange={onToggle}
        disabled={campo.obligatorio}
        className="rounded flex-shrink-0"
      />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className={`font-mono text-[10px] w-5 text-right flex-shrink-0 ${
            campo.obligatorio ? 'text-brand-800 font-bold' : 'text-gray-400'
          }`}>
            {campo.numero}
          </span>
          <span className={campo.marcado ? 'text-gray-900' : 'text-gray-400'}>
            {campo.nombre}
          </span>
        </div>
      </div>
      {campo.obligatorio && (
        <span className="flex items-center gap-0.5 text-[9px] text-brand-800 bg-brand-50 px-1.5 py-0.5 rounded font-semibold flex-shrink-0">
          <Lock size={8} /> SUNAT
        </span>
      )}
    </label>
  )
}
