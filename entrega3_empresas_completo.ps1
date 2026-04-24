# ============================================================
#  FELICITA - Entrega 3: Modales + Detalle de empresa
#  Ejecutar desde la raiz del proyecto felicita/
#  .\entrega3_empresas_completo.ps1
# ============================================================

Write-Host ""
Write-Host "Entrega 3 - Modales y detalle de empresa" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "frontend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# components/Modal.tsx - Componente base modal
# ============================================================
@'
import { ReactNode, useEffect } from 'react'
import { X } from 'lucide-react'

interface ModalProps {
  isOpen: boolean
  onClose: () => void
  title: string
  description?: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  children: ReactNode
  footer?: ReactNode
}

const SIZES = {
  sm: 'max-w-md',
  md: 'max-w-lg',
  lg: 'max-w-2xl',
  xl: 'max-w-4xl',
}

export default function Modal({
  isOpen, onClose, title, description, size = 'md', children, footer
}: ModalProps) {
  useEffect(() => {
    if (!isOpen) return
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', handleEsc)
    return () => {
      document.body.style.overflow = ''
      window.removeEventListener('keydown', handleEsc)
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  return (
    <div
      className="fixed inset-0 z-50 overflow-y-auto"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
    >
      {/* Backdrop */}
      <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm" />

      {/* Dialog */}
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className={`relative w-full ${SIZES[size]} bg-white rounded-xl shadow-xl transform transition-all`}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-start justify-between px-6 py-4 border-b border-gray-100">
            <div>
              <h2 className="font-heading font-bold text-gray-900 text-lg">{title}</h2>
              {description && (
                <p className="text-sm text-gray-500 mt-0.5">{description}</p>
              )}
            </div>
            <button
              onClick={onClose}
              className="p-1 hover:bg-gray-100 rounded-lg transition-colors text-gray-500"
              aria-label="Cerrar"
            >
              <X size={18} />
            </button>
          </div>

          {/* Body */}
          <div className="px-6 py-5 max-h-[70vh] overflow-y-auto">
            {children}
          </div>

          {/* Footer */}
          {footer && (
            <div className="px-6 py-4 border-t border-gray-100 bg-gray-50 rounded-b-xl flex items-center justify-end gap-2">
              {footer}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ── ConfirmDialog ────────────────────────────────────
interface ConfirmDialogProps {
  isOpen: boolean
  onClose: () => void
  onConfirm: () => void
  title: string
  message: string
  confirmText?: string
  cancelText?: string
  variant?: 'danger' | 'warning' | 'info'
  loading?: boolean
}

export function ConfirmDialog({
  isOpen, onClose, onConfirm, title, message,
  confirmText = 'Confirmar', cancelText = 'Cancelar',
  variant = 'danger', loading = false
}: ConfirmDialogProps) {
  const btnClass = {
    danger:  'bg-danger-600 hover:bg-danger-700 text-white',
    warning: 'bg-warning-600 hover:bg-warning-700 text-white',
    info:    'bg-brand-800 hover:bg-brand-900 text-white',
  }[variant]

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      size="sm"
      footer={
        <>
          <button onClick={onClose} className="btn-secondary" disabled={loading}>
            {cancelText}
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            className={`px-4 py-2 rounded-lg font-medium text-sm transition-colors disabled:opacity-50 ${btnClass}`}
          >
            {loading ? 'Procesando...' : confirmText}
          </button>
        </>
      }
    >
      <p className="text-sm text-gray-600 leading-relaxed">{message}</p>
    </Modal>
  )
}
'@ | Set-Content "frontend/src/components/Modal.tsx"
Write-Host "  [OK] components/Modal.tsx" -ForegroundColor Green

# ============================================================
# components/EmpresaForm.tsx - Formulario compartido crear/editar
# ============================================================
@'
import { useState, useEffect } from 'react'
import { Check, AlertCircle, Loader2, Search } from 'lucide-react'
import { empresaService } from '../services/empresaService'
import { useDebounce } from '../hooks/useDebounce'
import { COLORES_EMPRESA } from '../types/empresa'
import type { Empresa, ValidacionRUC } from '../types/empresa'

interface EmpresaFormProps {
  empresa?: Empresa | null     // Si viene, es edicion
  onSubmit: (data: any) => Promise<void>
  onCancel: () => void
  loading?: boolean
}

export default function EmpresaForm({ empresa, onSubmit, onCancel, loading }: EmpresaFormProps) {
  const esEdicion = !!empresa

  const [form, setForm] = useState({
    ruc:                       empresa?.ruc || '',
    razon_social:              empresa?.razon_social || '',
    nombre_comercial:          empresa?.nombre_comercial || '',
    direccion_fiscal:          empresa?.direccion_fiscal || '',
    distrito:                  empresa?.distrito || '',
    provincia:                 empresa?.provincia || '',
    departamento:              empresa?.departamento || '',
    regimen_tributario:        empresa?.regimen_tributario || 'RG',
    estado_sunat:              empresa?.estado_sunat || 'ACTIVO',
    condicion_domicilio:       empresa?.condicion_domicilio || 'HABIDO',
    representante_legal:       empresa?.representante_legal || '',
    email_empresa:             empresa?.email_empresa || '',
    telefono_empresa:          empresa?.telefono_empresa || '',
    usuario_sol:               '',
    clave_sol:                 '',
    color_identificacion:      empresa?.color_identificacion || COLORES_EMPRESA[0],
    notas_contador:            '',
  })

  const [error, setError] = useState('')
  const [validacionRuc, setValidacionRuc] = useState<ValidacionRUC | null>(null)
  const [validandoRuc, setValidandoRuc] = useState(false)
  const rucDebounced = useDebounce(form.ruc, 500)

  // Validar RUC automaticamente mientras escribe (solo en creacion)
  useEffect(() => {
    if (esEdicion) return
    if (rucDebounced.length !== 11 || !/^\d+$/.test(rucDebounced)) {
      setValidacionRuc(null)
      return
    }
    validarRucAuto(rucDebounced)
  }, [rucDebounced, esEdicion])

  async function validarRucAuto(ruc: string) {
    setValidandoRuc(true)
    try {
      const res = await empresaService.validarRuc(ruc)
      setValidacionRuc(res)

      // Auto-rellenar si es valido y no esta registrada
      if (res.es_valido && !res.ya_registrada) {
        setForm(f => ({
          ...f,
          razon_social:        res.razon_social || f.razon_social,
          direccion_fiscal:    res.direccion_fiscal || f.direccion_fiscal,
          distrito:            res.distrito || f.distrito,
          provincia:           res.provincia || f.provincia,
          departamento:        res.departamento || f.departamento,
          estado_sunat:        res.estado_sunat || f.estado_sunat,
          condicion_domicilio: res.condicion_domicilio || f.condicion_domicilio,
        }))
      }
    } catch (err) {
      console.error(err)
    } finally {
      setValidandoRuc(false)
    }
  }

  function updateField(field: string, value: any) {
    setForm(f => ({ ...f, [field]: value }))
    setError('')
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    // Validacion basica
    if (!esEdicion && !form.ruc) return setError('El RUC es obligatorio')
    if (!form.razon_social) return setError('La razon social es obligatoria')
    if (!form.direccion_fiscal) return setError('La direccion fiscal es obligatoria')

    // En creacion, el RUC debe estar validado
    if (!esEdicion && (!validacionRuc || !validacionRuc.es_valido)) {
      return setError('Verifica que el RUC sea valido')
    }
    if (!esEdicion && validacionRuc?.ya_registrada) {
      return setError('Esta empresa ya esta registrada en tu cuenta')
    }

    // Limpiar campos vacios opcionales
    const payload: any = { ...form }
    if (esEdicion) delete payload.ruc
    if (!payload.clave_sol) delete payload.clave_sol
    if (!payload.usuario_sol) delete payload.usuario_sol
    if (!payload.notas_contador) delete payload.notas_contador

    try {
      await onSubmit(payload)
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al guardar la empresa')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      {/* ── Seccion 1: Identificacion ── */}
      <Section title="Identificacion">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* RUC con validacion en tiempo real */}
          <div className="md:col-span-1">
            <label className="label">RUC *</label>
            <div className="relative">
              <input
                type="text"
                value={form.ruc}
                onChange={e => updateField('ruc', e.target.value.replace(/\D/g, '').slice(0, 11))}
                className="input pr-9 font-mono"
                placeholder="20123456789"
                disabled={esEdicion || loading}
                maxLength={11}
              />
              {!esEdicion && (
                <div className="absolute right-3 top-1/2 -translate-y-1/2">
                  {validandoRuc ? (
                    <Loader2 size={14} className="text-gray-400 animate-spin" />
                  ) : validacionRuc?.es_valido && !validacionRuc.ya_registrada ? (
                    <Check size={14} className="text-success-600" />
                  ) : validacionRuc && (!validacionRuc.es_valido || validacionRuc.ya_registrada) ? (
                    <AlertCircle size={14} className="text-danger-600" />
                  ) : form.ruc.length === 11 ? (
                    <Search size={14} className="text-gray-400" />
                  ) : null}
                </div>
              )}
            </div>
            {!esEdicion && validacionRuc && (
              <p className={`text-xs mt-1 ${
                validacionRuc.es_valido && !validacionRuc.ya_registrada
                  ? 'text-success-600'
                  : 'text-danger-600'
              }`}>
                {validacionRuc.mensaje}
              </p>
            )}
          </div>

          <div className="md:col-span-2">
            <label className="label">Razon social *</label>
            <input
              type="text"
              value={form.razon_social}
              onChange={e => updateField('razon_social', e.target.value)}
              className="input"
              placeholder="EMPRESA EJEMPLO SAC"
              disabled={loading}
            />
          </div>

          <div className="md:col-span-2">
            <label className="label">Nombre comercial</label>
            <input
              type="text"
              value={form.nombre_comercial || ''}
              onChange={e => updateField('nombre_comercial', e.target.value)}
              className="input"
              placeholder="Opcional"
              disabled={loading}
            />
          </div>

          <div>
            <label className="label">Color</label>
            <div className="flex flex-wrap gap-1.5">
              {COLORES_EMPRESA.map(color => (
                <button
                  key={color}
                  type="button"
                  onClick={() => updateField('color_identificacion', color)}
                  className={`w-7 h-7 rounded-full transition-transform ${
                    form.color_identificacion === color
                      ? 'ring-2 ring-offset-2 ring-brand-800 scale-110'
                      : 'hover:scale-110'
                  }`}
                  style={{ backgroundColor: color }}
                  title={color}
                />
              ))}
            </div>
          </div>
        </div>
      </Section>

      {/* ── Seccion 2: Ubicacion ── */}
      <Section title="Ubicacion">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="label">Direccion fiscal *</label>
            <input
              type="text"
              value={form.direccion_fiscal}
              onChange={e => updateField('direccion_fiscal', e.target.value)}
              className="input"
              placeholder="Av. Principal 123, Piso 5"
              disabled={loading}
            />
          </div>
          <div>
            <label className="label">Distrito</label>
            <input
              type="text" value={form.distrito || ''}
              onChange={e => updateField('distrito', e.target.value)}
              className="input" placeholder="San Isidro" disabled={loading}
            />
          </div>
          <div>
            <label className="label">Provincia</label>
            <input
              type="text" value={form.provincia || ''}
              onChange={e => updateField('provincia', e.target.value)}
              className="input" placeholder="Lima" disabled={loading}
            />
          </div>
          <div className="md:col-span-2">
            <label className="label">Departamento</label>
            <input
              type="text" value={form.departamento || ''}
              onChange={e => updateField('departamento', e.target.value)}
              className="input" placeholder="Lima" disabled={loading}
            />
          </div>
        </div>
      </Section>

      {/* ── Seccion 3: Configuracion tributaria ── */}
      <Section title="Configuracion tributaria">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="label">Regimen *</label>
            <select
              value={form.regimen_tributario}
              onChange={e => updateField('regimen_tributario', e.target.value)}
              className="input" disabled={loading}
            >
              <option value="RG">Regimen General</option>
              <option value="RMT">Regimen MYPE Tributario</option>
              <option value="RER">Regimen Especial</option>
              <option value="NRUS">Nuevo RUS</option>
            </select>
          </div>
          <div>
            <label className="label">Estado SUNAT</label>
            <select
              value={form.estado_sunat}
              onChange={e => updateField('estado_sunat', e.target.value)}
              className="input" disabled={loading}
            >
              <option value="ACTIVO">Activo</option>
              <option value="BAJA">Baja</option>
              <option value="SUSPENDIDO">Suspendido</option>
              <option value="OBSERVADO">Observado</option>
            </select>
          </div>
          <div>
            <label className="label">Condicion domicilio</label>
            <select
              value={form.condicion_domicilio}
              onChange={e => updateField('condicion_domicilio', e.target.value)}
              className="input" disabled={loading}
            >
              <option value="HABIDO">Habido</option>
              <option value="NO_HABIDO">No habido</option>
              <option value="NO_HALLADO">No hallado</option>
            </select>
          </div>
        </div>
      </Section>

      {/* ── Seccion 4: Contacto ── */}
      <Section title="Contacto">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="label">Representante legal</label>
            <input
              type="text" value={form.representante_legal || ''}
              onChange={e => updateField('representante_legal', e.target.value)}
              className="input" placeholder="Nombres y apellidos" disabled={loading}
            />
          </div>
          <div>
            <label className="label">Email</label>
            <input
              type="email" value={form.email_empresa || ''}
              onChange={e => updateField('email_empresa', e.target.value)}
              className="input" placeholder="contacto@empresa.com" disabled={loading}
            />
          </div>
          <div>
            <label className="label">Telefono</label>
            <input
              type="tel" value={form.telefono_empresa || ''}
              onChange={e => updateField('telefono_empresa', e.target.value)}
              className="input" placeholder="(01) 234-5678" disabled={loading}
            />
          </div>
        </div>
      </Section>

      {/* ── Seccion 5: Clave SOL ── */}
      <Section
        title="Clave SOL"
        description="Credenciales encriptadas para acceder a SUNAT en nombre de la empresa (opcional)"
      >
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="label">Usuario SOL</label>
            <input
              type="text" value={form.usuario_sol}
              onChange={e => updateField('usuario_sol', e.target.value)}
              className="input font-mono" placeholder="Usuario SUNAT" disabled={loading}
            />
          </div>
          <div>
            <label className="label">Clave SOL</label>
            <input
              type="password" value={form.clave_sol}
              onChange={e => updateField('clave_sol', e.target.value)}
              className="input font-mono"
              placeholder={esEdicion && empresa?.tiene_clave_sol ? '(configurada - dejar vacio para no cambiar)' : '........'}
              disabled={loading}
            />
          </div>
        </div>
      </Section>

      {/* Error global */}
      {error && (
        <div className="bg-danger-50 border border-danger-600/20 text-danger-900 text-sm rounded-lg px-4 py-3 flex items-start gap-2">
          <AlertCircle size={16} className="flex-shrink-0 mt-0.5" />
          <span>{error}</span>
        </div>
      )}

      {/* Acciones */}
      <div className="flex items-center justify-end gap-2 pt-4 border-t border-gray-100">
        <button
          type="button" onClick={onCancel}
          className="btn-secondary" disabled={loading}
        >
          Cancelar
        </button>
        <button
          type="submit"
          className="btn-primary flex items-center gap-2"
          disabled={loading || validandoRuc}
        >
          {loading && <Loader2 size={14} className="animate-spin" />}
          {esEdicion ? 'Guardar cambios' : 'Crear empresa'}
        </button>
      </div>
    </form>
  )
}

// ── Subcomponente: Seccion del formulario ──
function Section({
  title, description, children
}: {
  title: string
  description?: string
  children: React.ReactNode
}) {
  return (
    <div>
      <div className="mb-3">
        <h3 className="font-heading font-bold text-gray-900 text-sm">{title}</h3>
        {description && (
          <p className="text-xs text-gray-500 mt-0.5">{description}</p>
        )}
      </div>
      {children}
    </div>
  )
}
'@ | Set-Content "frontend/src/components/EmpresaForm.tsx"
Write-Host "  [OK] components/EmpresaForm.tsx" -ForegroundColor Green

# ============================================================
# pages/contador/Empresas.tsx - PAGINA CON MODALES INTEGRADOS
# ============================================================
@'
import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Plus, Search, Filter, Building2, MoreVertical,
  AlertCircle, CheckCircle2, ArrowUpDown, RefreshCw, X,
  Pencil, Trash2, Eye
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import { MetricCard, AlertBadge, EmptyState } from '../../components/ui'
import FilterChip from '../../components/FilterChip'
import Modal, { ConfirmDialog } from '../../components/Modal'
import EmpresaForm from '../../components/EmpresaForm'
import { empresaService } from '../../services/empresaService'
import { useDebounce } from '../../hooks/useDebounce'
import type { Empresa, EmpresaListFilters } from '../../types/empresa'
import { REGIMENES_LABEL } from '../../types/empresa'

export default function EmpresasPage() {
  const navigate = useNavigate()
  const [empresas, setEmpresas] = useState<Empresa[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [busqueda, setBusqueda] = useState('')
  const busquedaDebounced = useDebounce(busqueda, 300)
  const [filtros, setFiltros] = useState<EmpresaListFilters>({ orden: 'alerta' })
  const [contadores, setContadores] = useState({ verde: 0, amarillo: 0, rojo: 0, total: 0 })

  // Estado de modales
  const [modalCrearAbierto, setModalCrearAbierto]   = useState(false)
  const [modalEditarAbierto, setModalEditarAbierto] = useState(false)
  const [modalEliminarAbierto, setModalEliminarAbierto] = useState(false)
  const [empresaActual, setEmpresaActual] = useState<Empresa | null>(null)
  const [guardando, setGuardando] = useState(false)

  // Menu de acciones por fila
  const [menuAbierto, setMenuAbierto] = useState<number | null>(null)

  useEffect(() => { cargarContadoresGlobales() }, [])
  useEffect(() => { cargar() }, [busquedaDebounced, filtros])

  // Cerrar menu al hacer click fuera
  useEffect(() => {
    const handleClick = () => setMenuAbierto(null)
    if (menuAbierto !== null) {
      window.addEventListener('click', handleClick)
      return () => window.removeEventListener('click', handleClick)
    }
  }, [menuAbierto])

  async function cargarContadoresGlobales() {
    try {
      const { empresas: todas, total } = await empresaService.listar({})
      setContadores({
        total,
        verde:    todas.filter(e => e.nivel_alerta === 'VERDE').length,
        amarillo: todas.filter(e => e.nivel_alerta === 'AMARILLO').length,
        rojo:     todas.filter(e => e.nivel_alerta === 'ROJO').length,
      })
    } catch (err) { console.error(err) }
  }

  async function cargar() {
    setLoading(true)
    try {
      const res = await empresaService.listar({
        ...filtros,
        buscar: busquedaDebounced || undefined,
      })
      setEmpresas(res.empresas)
      setTotal(res.total)
    } finally {
      setLoading(false)
    }
  }

  async function handleCrear(data: any) {
    setGuardando(true)
    try {
      await empresaService.crear(data)
      setModalCrearAbierto(false)
      await Promise.all([cargar(), cargarContadoresGlobales()])
    } finally {
      setGuardando(false)
    }
  }

  async function handleEditar(data: any) {
    if (!empresaActual) return
    setGuardando(true)
    try {
      await empresaService.actualizar(empresaActual.id, data)
      setModalEditarAbierto(false)
      setEmpresaActual(null)
      await Promise.all([cargar(), cargarContadoresGlobales()])
    } finally {
      setGuardando(false)
    }
  }

  async function handleEliminar() {
    if (!empresaActual) return
    setGuardando(true)
    try {
      await empresaService.eliminar(empresaActual.id)
      setModalEliminarAbierto(false)
      setEmpresaActual(null)
      await Promise.all([cargar(), cargarContadoresGlobales()])
    } finally {
      setGuardando(false)
    }
  }

  function toggleAlerta(nivel: 'VERDE' | 'AMARILLO' | 'ROJO') {
    setFiltros(f => ({ ...f, nivel_alerta: f.nivel_alerta === nivel ? undefined : nivel }))
  }
  function toggleRegimen(reg: 'RG' | 'RMT' | 'RER' | 'NRUS') {
    setFiltros(f => ({ ...f, regimen: f.regimen === reg ? undefined : reg }))
  }
  function limpiarFiltros() {
    setFiltros({ orden: 'alerta' })
    setBusqueda('')
  }

  const hayFiltrosActivos = useMemo(
    () => !!(filtros.nivel_alerta || filtros.regimen || busqueda),
    [filtros, busqueda]
  )

  return (
    <>
      <PageHeader
        eyebrow="Gestion"
        title="Empresas"
        description="Administra todas las empresas a tu cargo"
        actions={
          <button
            onClick={() => setModalCrearAbierto(true)}
            className="btn-primary flex items-center gap-2"
          >
            <Plus size={16} /> Nueva Empresa
          </button>
        }
      />

      <div className="p-6 lg:p-8">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <MetricCard label="Total empresas" value={contadores.total} accent="brand" icon={<Building2 size={24} />} />
          <MetricCard label="Al dia" value={contadores.verde} accent="success" icon={<CheckCircle2 size={24} />} />
          <MetricCard label="Atencion" value={contadores.amarillo} accent="warning" icon={<AlertCircle size={24} />} />
          <MetricCard label="Criticas" value={contadores.rojo} accent="danger" icon={<AlertCircle size={24} />} />
        </div>

        <div className="card p-4 mb-4">
          <div className="flex flex-col lg:flex-row gap-3 mb-4">
            <div className="relative flex-1">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text" value={busqueda}
                onChange={e => setBusqueda(e.target.value)}
                placeholder="Buscar por RUC, razon social o nombre comercial..."
                className="input pl-9"
              />
              {busqueda && (
                <button
                  onClick={() => setBusqueda('')}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  <X size={14} />
                </button>
              )}
            </div>

            <select
              value={filtros.orden || 'alerta'}
              onChange={e => setFiltros(f => ({ ...f, orden: e.target.value as any }))}
              className="input lg:max-w-[200px]"
            >
              <option value="alerta">Ordenar por alerta</option>
              <option value="nombre">Ordenar por nombre</option>
              <option value="fecha">Mas recientes</option>
              <option value="ruc">Ordenar por RUC</option>
            </select>

            <button onClick={cargar} className="btn-secondary flex items-center gap-1" title="Recargar">
              <RefreshCw size={14} />
            </button>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider mr-1">
              <Filter size={12} className="inline mr-1" /> Alerta:
            </span>
            <FilterChip label="Al dia" variant="success" count={contadores.verde}
              active={filtros.nivel_alerta === 'VERDE'} onClick={() => toggleAlerta('VERDE')} />
            <FilterChip label="Atencion" variant="warning" count={contadores.amarillo}
              active={filtros.nivel_alerta === 'AMARILLO'} onClick={() => toggleAlerta('AMARILLO')} />
            <FilterChip label="Critico" variant="danger" count={contadores.rojo}
              active={filtros.nivel_alerta === 'ROJO'} onClick={() => toggleAlerta('ROJO')} />

            <span className="w-px h-4 bg-gray-200 mx-2" />

            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider mr-1">Regimen:</span>
            {(['RG','RMT','RER','NRUS'] as const).map(r => (
              <FilterChip key={r} label={r} active={filtros.regimen === r} onClick={() => toggleRegimen(r)} />
            ))}

            {hayFiltrosActivos && (
              <button onClick={limpiarFiltros} className="text-xs text-brand-800 hover:text-brand-900 font-semibold ml-auto flex items-center gap-1">
                <X size={12} /> Limpiar filtros
              </button>
            )}
          </div>
        </div>

        <div className="card">
          <div className="px-5 py-3 border-b border-gray-100 flex items-center justify-between">
            <div className="text-sm text-gray-500">
              {loading ? 'Cargando...' :
                total === 0 ? 'Sin resultados' :
                `Mostrando ${empresas.length} de ${total} empresa${total !== 1 ? 's' : ''}`}
            </div>
            <div className="flex items-center gap-1 text-xs text-gray-400">
              <ArrowUpDown size={12} />
              <span>
                {filtros.orden === 'alerta' ? 'Por prioridad de alerta' :
                 filtros.orden === 'nombre' ? 'Por razon social' :
                 filtros.orden === 'fecha'  ? 'Mas recientes primero' : 'Por RUC'}
              </span>
            </div>
          </div>

          {loading ? (
            <LoadingRows />
          ) : empresas.length === 0 ? (
            hayFiltrosActivos ? (
              <EmptyState
                icon={<Search size={40} />}
                title="Sin resultados"
                description="Prueba ajustar los filtros o cambiar tu busqueda"
                action={<button onClick={limpiarFiltros} className="btn-secondary">Limpiar filtros</button>}
              />
            ) : (
              <EmptyState
                icon={<Building2 size={40} />}
                title="No tienes empresas registradas"
                description="Agrega tu primera empresa para comenzar"
                action={
                  <button onClick={() => setModalCrearAbierto(true)} className="btn-primary flex items-center gap-2 mx-auto">
                    <Plus size={16} /> Agregar empresa
                  </button>
                }
              />
            )
          ) : (
            <div className="divide-y divide-gray-100">
              {empresas.map(empresa => (
                <EmpresaRow
                  key={empresa.id}
                  empresa={empresa}
                  menuAbierto={menuAbierto === empresa.id}
                  onMenuToggle={() => setMenuAbierto(menuAbierto === empresa.id ? null : empresa.id)}
                  onVer={() => navigate(`/empresas/${empresa.id}`)}
                  onEditar={() => {
                    setEmpresaActual(empresa)
                    setModalEditarAbierto(true)
                    setMenuAbierto(null)
                  }}
                  onEliminar={() => {
                    setEmpresaActual(empresa)
                    setModalEliminarAbierto(true)
                    setMenuAbierto(null)
                  }}
                />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* ── Modal: Crear Empresa ── */}
      <Modal
        isOpen={modalCrearAbierto}
        onClose={() => !guardando && setModalCrearAbierto(false)}
        title="Nueva Empresa"
        description="Ingresa el RUC y autocompletaremos los datos desde SUNAT"
        size="xl"
      >
        <EmpresaForm
          onSubmit={handleCrear}
          onCancel={() => setModalCrearAbierto(false)}
          loading={guardando}
        />
      </Modal>

      {/* ── Modal: Editar Empresa ── */}
      <Modal
        isOpen={modalEditarAbierto}
        onClose={() => !guardando && setModalEditarAbierto(false)}
        title={`Editar ${empresaActual?.razon_social || ''}`}
        description="Modifica los datos de la empresa"
        size="xl"
      >
        {empresaActual && (
          <EmpresaForm
            empresa={empresaActual}
            onSubmit={handleEditar}
            onCancel={() => {
              setModalEditarAbierto(false)
              setEmpresaActual(null)
            }}
            loading={guardando}
          />
        )}
      </Modal>

      {/* ── Confirm: Eliminar ── */}
      <ConfirmDialog
        isOpen={modalEliminarAbierto}
        onClose={() => !guardando && setModalEliminarAbierto(false)}
        onConfirm={handleEliminar}
        title="Eliminar empresa"
        message={`Estas seguro de eliminar "${empresaActual?.razon_social}"? La empresa se marcara como inactiva. Puedes reactivarla mas tarde si lo necesitas.`}
        confirmText="Si, eliminar"
        variant="danger"
        loading={guardando}
      />
    </>
  )
}

// ── Fila de empresa con menu ─────────────────────────
function EmpresaRow({
  empresa, menuAbierto, onMenuToggle, onVer, onEditar, onEliminar
}: {
  empresa: Empresa
  menuAbierto: boolean
  onMenuToggle: () => void
  onVer: () => void
  onEditar: () => void
  onEliminar: () => void
}) {
  return (
    <div
      onClick={onVer}
      className="px-5 py-4 flex items-center gap-4 hover:bg-gray-50 transition-colors cursor-pointer group relative"
    >
      <div className="w-1 h-14 rounded-full flex-shrink-0" style={{ backgroundColor: empresa.color_identificacion }} />

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-3 mb-1 flex-wrap">
          <p className="font-semibold text-gray-900 truncate">{empresa.razon_social}</p>
          <AlertBadge nivel={empresa.nivel_alerta} />
          {empresa.tiene_clave_sol && (
            <span className="text-[10px] bg-brand-50 text-brand-900 px-1.5 py-0.5 rounded font-semibold">
              SOL configurada
            </span>
          )}
        </div>

        <div className="flex items-center gap-3 text-sm text-gray-500 flex-wrap">
          <span className="font-mono">RUC {empresa.ruc}</span>
          <span className="text-gray-300">-</span>
          <span className="font-medium">{REGIMENES_LABEL[empresa.regimen_tributario] || empresa.regimen_tributario}</span>
          <span className="text-gray-300">-</span>
          <span>{empresa.estado_sunat}</span>
          {empresa.distrito && (
            <>
              <span className="text-gray-300">-</span>
              <span>{empresa.distrito}</span>
            </>
          )}
        </div>

        {empresa.motivo_alerta && (
          <p className="text-xs text-danger-600 mt-1 font-medium">! {empresa.motivo_alerta}</p>
        )}
      </div>

      <div className="flex-shrink-0 relative" onClick={(e) => e.stopPropagation()}>
        <button
          onClick={onMenuToggle}
          className={`p-1.5 hover:bg-gray-200 rounded-lg transition-all ${
            menuAbierto ? 'bg-gray-100 opacity-100' : 'opacity-0 group-hover:opacity-100'
          }`}
          title="Acciones"
        >
          <MoreVertical size={16} className="text-gray-500" />
        </button>

        {menuAbierto && (
          <div className="absolute right-0 top-full mt-1 w-44 bg-white rounded-lg border border-gray-200 shadow-lg z-10 py-1">
            <button onClick={onVer} className="w-full px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2">
              <Eye size={14} /> Ver detalle
            </button>
            <button onClick={onEditar} className="w-full px-3 py-2 text-left text-sm text-gray-700 hover:bg-gray-50 flex items-center gap-2">
              <Pencil size={14} /> Editar
            </button>
            <div className="my-1 border-t border-gray-100" />
            <button onClick={onEliminar} className="w-full px-3 py-2 text-left text-sm text-danger-600 hover:bg-danger-50 flex items-center gap-2">
              <Trash2 size={14} /> Eliminar
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

function LoadingRows() {
  return (
    <div className="divide-y divide-gray-100">
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="px-5 py-4 flex items-center gap-4">
          <div className="w-1 h-14 bg-gray-200 rounded-full animate-pulse" />
          <div className="flex-1">
            <div className="flex items-center gap-3 mb-2">
              <div className="h-4 bg-gray-200 rounded w-48 animate-pulse" />
              <div className="h-5 bg-gray-200 rounded-full w-20 animate-pulse" />
            </div>
            <div className="h-3 bg-gray-100 rounded w-72 animate-pulse" />
          </div>
        </div>
      ))}
    </div>
  )
}
'@ | Set-Content "frontend/src/pages/contador/Empresas.tsx"
Write-Host "  [OK] pages/contador/Empresas.tsx" -ForegroundColor Green

# ============================================================
# pages/contador/EmpresaDetalle.tsx - PANEL INDIVIDUAL
# ============================================================
@'
import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  ArrowLeft, Pencil, RefreshCw, Building2, Calendar, FileText,
  AlertCircle, MapPin, User, Mail, Phone, Clock, Shield,
  TrendingUp, Inbox, Trash2
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import { AlertBadge } from '../../components/ui'
import Modal, { ConfirmDialog } from '../../components/Modal'
import EmpresaForm from '../../components/EmpresaForm'
import { empresaService } from '../../services/empresaService'
import { REGIMENES_LABEL } from '../../types/empresa'
import type { EmpresaDetalle } from '../../types/empresa'

export default function EmpresaDetallePage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [empresa, setEmpresa] = useState<EmpresaDetalle | null>(null)
  const [loading, setLoading] = useState(true)
  const [modalEditar, setModalEditar] = useState(false)
  const [modalEliminar, setModalEliminar] = useState(false)
  const [guardando, setGuardando] = useState(false)

  useEffect(() => { cargar() }, [id])

  async function cargar() {
    if (!id) return
    setLoading(true)
    try {
      const data = await empresaService.obtener(Number(id))
      setEmpresa(data)
    } catch (err) {
      console.error(err)
      navigate('/empresas')
    } finally {
      setLoading(false)
    }
  }

  async function handleRecalcular() {
    if (!empresa) return
    setGuardando(true)
    try {
      const actualizada = await empresaService.recalcularAlertas(empresa.id)
      setEmpresa(e => e ? { ...e, ...actualizada } : null)
    } finally {
      setGuardando(false)
    }
  }

  async function handleEditar(data: any) {
    if (!empresa) return
    setGuardando(true)
    try {
      await empresaService.actualizar(empresa.id, data)
      setModalEditar(false)
      await cargar()
    } finally {
      setGuardando(false)
    }
  }

  async function handleEliminar() {
    if (!empresa) return
    setGuardando(true)
    try {
      await empresaService.eliminar(empresa.id)
      navigate('/empresas')
    } finally {
      setGuardando(false)
    }
  }

  if (loading) {
    return (
      <div className="p-8">
        <div className="animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-64" />
          <div className="h-32 bg-gray-200 rounded" />
          <div className="h-64 bg-gray-200 rounded" />
        </div>
      </div>
    )
  }

  if (!empresa) return null

  const formatFecha = (f: string | null) => {
    if (!f) return '-'
    const d = new Date(f)
    return d.toLocaleDateString('es-PE', { day: '2-digit', month: 'short', year: 'numeric' })
  }

  return (
    <>
      <PageHeader
        eyebrow={`RUC ${empresa.ruc}`}
        title={empresa.razon_social}
        description={empresa.nombre_comercial || REGIMENES_LABEL[empresa.regimen_tributario]}
        actions={
          <div className="flex items-center gap-2">
            <button
              onClick={() => navigate('/empresas')}
              className="btn-secondary flex items-center gap-2"
            >
              <ArrowLeft size={14} /> Volver
            </button>
            <button
              onClick={handleRecalcular}
              disabled={guardando}
              className="btn-secondary flex items-center gap-2"
            >
              <RefreshCw size={14} className={guardando ? 'animate-spin' : ''} />
              Recalcular alertas
            </button>
            <button
              onClick={() => setModalEditar(true)}
              className="btn-primary flex items-center gap-2"
            >
              <Pencil size={14} /> Editar
            </button>
          </div>
        }
      />

      <div className="p-6 lg:p-8 space-y-6">

        {/* Banner de alerta */}
        {empresa.motivo_alerta && (
          <div className={`rounded-xl p-4 flex items-start gap-3 border ${
            empresa.nivel_alerta === 'ROJO'
              ? 'bg-danger-50 border-danger-600/30'
              : 'bg-warning-50 border-warning-600/30'
          }`}>
            <AlertCircle size={18} className={
              empresa.nivel_alerta === 'ROJO' ? 'text-danger-600' : 'text-warning-600'
            } />
            <div>
              <p className={`font-semibold text-sm ${
                empresa.nivel_alerta === 'ROJO' ? 'text-danger-900' : 'text-warning-900'
              }`}>
                {empresa.nivel_alerta === 'ROJO' ? 'Atencion urgente requerida' : 'Atencion necesaria'}
              </p>
              <p className={`text-sm mt-0.5 ${
                empresa.nivel_alerta === 'ROJO' ? 'text-danger-700' : 'text-warning-700'
              }`}>
                {empresa.motivo_alerta}
              </p>
            </div>
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

          {/* Col principal */}
          <div className="lg:col-span-2 space-y-6">

            {/* Estadisticas */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <StatMini
                icon={<FileText size={16} />}
                label="Declaraciones"
                value={empresa.total_pdt621s}
              />
              <StatMini
                icon={<Inbox size={16} />}
                label="Pendientes"
                value={empresa.pdt621s_pendientes}
                accent={empresa.pdt621s_pendientes > 0 ? 'warning' : 'neutral'}
              />
              <StatMini
                icon={<Clock size={16} />}
                label="Ultima"
                value={formatFecha(empresa.ultima_declaracion)}
                isText
              />
              <StatMini
                icon={<Calendar size={16} />}
                label="Proximo venc."
                value={formatFecha(empresa.proximo_vencimiento)}
                isText
                accent={empresa.proximo_vencimiento ? 'brand' : 'neutral'}
              />
            </div>

            {/* Datos fiscales */}
            <Card title="Informacion fiscal" icon={<Building2 size={16} />}>
              <DataGrid>
                <DataField label="RUC" value={empresa.ruc} mono />
                <DataField label="Razon social" value={empresa.razon_social} />
                <DataField label="Nombre comercial" value={empresa.nombre_comercial || '-'} />
                <DataField label="Regimen tributario" value={REGIMENES_LABEL[empresa.regimen_tributario] || empresa.regimen_tributario} />
                <DataField label="Estado SUNAT"
                  value={<span className={`font-semibold ${
                    empresa.estado_sunat === 'ACTIVO'  ? 'text-success-700' :
                    empresa.estado_sunat === 'OBSERVADO' ? 'text-danger-700' :
                    'text-gray-700'
                  }`}>{empresa.estado_sunat}</span>}
                />
                <DataField label="Condicion domicilio"
                  value={<span className={`font-semibold ${
                    empresa.condicion_domicilio === 'HABIDO' ? 'text-success-700' : 'text-danger-700'
                  }`}>{empresa.condicion_domicilio}</span>}
                />
              </DataGrid>
            </Card>

            {/* Ubicacion */}
            <Card title="Ubicacion" icon={<MapPin size={16} />}>
              <DataGrid>
                <DataField label="Direccion fiscal" value={empresa.direccion_fiscal} cols={2} />
                <DataField label="Distrito" value={empresa.distrito || '-'} />
                <DataField label="Provincia" value={empresa.provincia || '-'} />
                <DataField label="Departamento" value={empresa.departamento || '-'} />
              </DataGrid>
            </Card>

            {/* Contacto */}
            <Card title="Contacto" icon={<User size={16} />}>
              <DataGrid>
                <DataField label="Representante legal" value={empresa.representante_legal || '-'} cols={2} />
                <DataField label="Email" value={empresa.email_empresa || '-'} icon={<Mail size={12} />} />
                <DataField label="Telefono" value={empresa.telefono_empresa || '-'} icon={<Phone size={12} />} />
              </DataGrid>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-4">
            <Card title="Estado" icon={<TrendingUp size={16} />}>
              <div className="flex items-center justify-center py-3">
                <AlertBadge nivel={empresa.nivel_alerta} />
              </div>
              <div className="text-center text-xs text-gray-500 mt-1">
                Color identificador:
                <span className="inline-block w-3 h-3 rounded-full ml-1.5 align-middle"
                  style={{ backgroundColor: empresa.color_identificacion }} />
              </div>
            </Card>

            <Card title="Credenciales SOL" icon={<Shield size={16} />}>
              <div className="text-center py-2">
                {empresa.tiene_clave_sol ? (
                  <div className="space-y-1">
                    <div className="text-success-600 text-2xl">&#10003;</div>
                    <p className="text-sm font-semibold text-success-900">Configurada</p>
                    <p className="text-xs text-gray-500">Credenciales encriptadas</p>
                  </div>
                ) : (
                  <div className="space-y-1">
                    <div className="text-gray-400 text-2xl">-</div>
                    <p className="text-sm font-semibold text-gray-600">No configurada</p>
                    <button onClick={() => setModalEditar(true)} className="text-xs text-brand-800 hover:underline">
                      Configurar ahora
                    </button>
                  </div>
                )}
              </div>
            </Card>

            <Card title="Acciones rapidas">
              <div className="space-y-2">
                <button
                  onClick={() => navigate('/calendario')}
                  className="btn-secondary w-full flex items-center justify-start gap-2 text-sm"
                >
                  <Calendar size={14} /> Ver calendario
                </button>
                <button
                  onClick={() => navigate('/declaraciones')}
                  className="btn-secondary w-full flex items-center justify-start gap-2 text-sm"
                >
                  <FileText size={14} /> Ver declaraciones
                </button>
                <button
                  onClick={() => setModalEliminar(true)}
                  className="w-full flex items-center justify-start gap-2 text-sm px-4 py-2 rounded-lg text-danger-600 hover:bg-danger-50 transition-colors"
                >
                  <Trash2 size={14} /> Eliminar empresa
                </button>
              </div>
            </Card>

            <div className="text-xs text-gray-400 text-center">
              Registrada el {formatFecha(empresa.fecha_creacion)}
            </div>
          </div>
        </div>
      </div>

      {/* Modal editar */}
      <Modal
        isOpen={modalEditar}
        onClose={() => !guardando && setModalEditar(false)}
        title={`Editar ${empresa.razon_social}`}
        size="xl"
      >
        <EmpresaForm
          empresa={empresa}
          onSubmit={handleEditar}
          onCancel={() => setModalEditar(false)}
          loading={guardando}
        />
      </Modal>

      <ConfirmDialog
        isOpen={modalEliminar}
        onClose={() => !guardando && setModalEliminar(false)}
        onConfirm={handleEliminar}
        title="Eliminar empresa"
        message={`Estas seguro de eliminar "${empresa.razon_social}"? La empresa se marcara como inactiva.`}
        confirmText="Si, eliminar"
        variant="danger"
        loading={guardando}
      />
    </>
  )
}

// ── Subcomponentes ─────────────────────────────────────

function Card({ title, icon, children }: { title: string; icon?: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="card">
      <div className="px-5 py-3 border-b border-gray-100 flex items-center gap-2">
        {icon && <span className="text-brand-800">{icon}</span>}
        <h3 className="font-heading font-bold text-gray-900 text-sm">{title}</h3>
      </div>
      <div className="p-5">{children}</div>
    </div>
  )
}

function DataGrid({ children }: { children: React.ReactNode }) {
  return <div className="grid grid-cols-1 md:grid-cols-2 gap-4">{children}</div>
}

function DataField({
  label, value, mono, cols, icon
}: {
  label: string
  value: React.ReactNode
  mono?: boolean
  cols?: number
  icon?: React.ReactNode
}) {
  return (
    <div className={cols === 2 ? 'md:col-span-2' : ''}>
      <dt className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1">{label}</dt>
      <dd className={`text-sm text-gray-900 flex items-center gap-1.5 ${mono ? 'font-mono' : ''}`}>
        {icon && <span className="text-gray-400">{icon}</span>}
        {value}
      </dd>
    </div>
  )
}

function StatMini({
  icon, label, value, accent = 'neutral', isText
}: {
  icon: React.ReactNode
  label: string
  value: React.ReactNode
  accent?: 'brand' | 'success' | 'warning' | 'danger' | 'neutral'
  isText?: boolean
}) {
  const colors = {
    brand:   'text-brand-800',
    success: 'text-success-700',
    warning: 'text-warning-700',
    danger:  'text-danger-700',
    neutral: 'text-gray-900',
  }
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-4 shadow-card">
      <div className="flex items-center gap-2 text-xs text-gray-500 mb-2">
        <span className="text-gray-400">{icon}</span>
        {label}
      </div>
      <p className={`${isText ? 'text-sm font-semibold' : 'text-2xl font-heading font-bold font-mono'} ${colors[accent]}`}>
        {value}
      </p>
    </div>
  )
}
'@ | Set-Content "frontend/src/pages/contador/EmpresaDetalle.tsx"
Write-Host "  [OK] pages/contador/EmpresaDetalle.tsx" -ForegroundColor Green

# ============================================================
# App.tsx - actualizar ruta a la pagina real
# ============================================================
@'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from './store/authStore'
import LoginPage from './pages/Login'
import AppLayout from './components/AppLayout'
import DashboardContador from './pages/contador/Dashboard'
import CalendarioPage from './pages/contador/Calendario'
import EmpresasPage from './pages/contador/Empresas'
import EmpresaDetallePage from './pages/contador/EmpresaDetalle'

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuthStore()
  return isAuthenticated() ? <>{children}</> : <Navigate to="/login" replace />
}

function PlaceholderPage({ title }: { title: string }) {
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
          <Route path="/empresas/:id" element={<EmpresaDetallePage />} />
          <Route path="/calendario" element={<CalendarioPage />} />
          <Route path="/declaraciones" element={<PlaceholderPage title="Declaraciones" />} />
          <Route path="/configuracion" element={<PlaceholderPage title="Configuracion" />} />
        </Route>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
'@ | Set-Content "frontend/src/App.tsx"
Write-Host "  [OK] App.tsx actualizado" -ForegroundColor Green

# ============================================================
# Dashboard.tsx - boton nueva empresa funcional + click en fila
# ============================================================
@'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Building2, AlertCircle, CheckCircle2, ArrowRight } from 'lucide-react'
import { useAuthStore } from '../../store/authStore'
import api from '../../services/api'
import PageHeader from '../../components/PageHeader'
import { MetricCard, AlertBadge, EmptyState } from '../../components/ui'

interface Empresa {
  id: number
  ruc: string
  razon_social: string
  regimen_tributario: string
  nivel_alerta: 'VERDE' | 'AMARILLO' | 'ROJO'
  motivo_alerta: string | null
  color_identificacion: string
  estado_sunat: string
}

export default function DashboardContador() {
  const navigate = useNavigate()
  const { usuario } = useAuthStore()
  const [empresas, setEmpresas] = useState<Empresa[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.get('/empresas').then(r => setEmpresas(r.data.empresas || r.data)).finally(() => setLoading(false))
  }, [])

  const totales = {
    verde:    empresas.filter(e => e.nivel_alerta === 'VERDE').length,
    amarillo: empresas.filter(e => e.nivel_alerta === 'AMARILLO').length,
    rojo:     empresas.filter(e => e.nivel_alerta === 'ROJO').length,
  }

  const empresasOrdenadas = [...empresas].sort((a, b) => {
    const orden = { ROJO: 0, AMARILLO: 1, VERDE: 2 }
    return orden[a.nivel_alerta] - orden[b.nivel_alerta]
  })

  return (
    <>
      <PageHeader
        eyebrow="Panel contable"
        title={`Buen dia, ${usuario?.nombre || ''}`}
        description="Vista consolidada de todas las empresas a tu cargo"
        actions={
          <button onClick={() => navigate('/empresas')} className="btn-primary flex items-center gap-2">
            <Plus size={16} /> Nueva Empresa
          </button>
        }
      />

      <div className="p-6 lg:p-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          <MetricCard label="Total empresas" value={empresas.length} accent="brand" icon={<Building2 size={24} />} />
          <MetricCard label="Al dia" value={totales.verde} accent="success" icon={<CheckCircle2 size={24} />} />
          <MetricCard label="Atencion" value={totales.amarillo} accent="warning" icon={<AlertCircle size={24} />} />
          <MetricCard label="Criticas" value={totales.rojo} accent="danger" icon={<AlertCircle size={24} />} />
        </div>

        <div className="card">
          <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
            <div>
              <h2 className="font-heading font-bold text-gray-900">Mis Empresas</h2>
              <p className="text-xs text-gray-500 mt-0.5">
                {empresas.length} empresa{empresas.length !== 1 ? 's' : ''} - Plan {usuario?.plan_actual}
              </p>
            </div>
            <button onClick={() => navigate('/calendario')} className="text-sm text-brand-800 hover:text-brand-900 font-medium flex items-center gap-1">
              Ver calendario <ArrowRight size={14} />
            </button>
          </div>

          {loading ? (
            <div className="p-12 text-center text-gray-400">Cargando empresas...</div>
          ) : empresas.length === 0 ? (
            <EmptyState
              icon={<Building2 size={40} />}
              title="No tienes empresas registradas"
              description="Agrega tu primera empresa para comenzar"
              action={
                <button onClick={() => navigate('/empresas')} className="btn-primary flex items-center gap-2 mx-auto">
                  <Plus size={16} /> Agregar empresa
                </button>
              }
            />
          ) : (
            <div className="divide-y divide-gray-100">
              {empresasOrdenadas.map(empresa => (
                <div
                  key={empresa.id}
                  onClick={() => navigate(`/empresas/${empresa.id}`)}
                  className="px-5 py-4 flex items-center justify-between hover:bg-gray-50 transition-colors group cursor-pointer"
                >
                  <div className="flex items-center gap-4 flex-1 min-w-0">
                    <div className="w-1 h-12 rounded-full flex-shrink-0" style={{ backgroundColor: empresa.color_identificacion }} />
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-3 mb-0.5">
                        <p className="font-semibold text-gray-900 truncate">{empresa.razon_social}</p>
                        <AlertBadge nivel={empresa.nivel_alerta} />
                      </div>
                      <p className="text-sm text-gray-500">
                        RUC <span className="font-mono">{empresa.ruc}</span> -
                        <span className="ml-1 font-medium">{empresa.regimen_tributario}</span> -
                        <span className="ml-1">{empresa.estado_sunat}</span>
                      </p>
                      {empresa.motivo_alerta && (
                        <p className="text-xs text-danger-600 mt-0.5 font-medium">! {empresa.motivo_alerta}</p>
                      )}
                    </div>
                  </div>
                  <button className="opacity-0 group-hover:opacity-100 transition-opacity text-sm text-brand-800 hover:text-brand-900 font-medium flex items-center gap-1 flex-shrink-0">
                    Entrar <ArrowRight size={14} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </>
  )
}
'@ | Set-Content "frontend/src/pages/contador/Dashboard.tsx"
Write-Host "  [OK] Dashboard.tsx actualizado (soporta nueva respuesta de API)" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Entrega 3 completa!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Lo nuevo:" -ForegroundColor Yellow
Write-Host "  - Modal 'Nueva Empresa' con validacion de RUC en tiempo real" -ForegroundColor White
Write-Host "  - Auto-completado de datos desde SUNAT al escribir RUC" -ForegroundColor White
Write-Host "  - Modal 'Editar empresa' con mismo formulario" -ForegroundColor White
Write-Host "  - Menu contextual por fila (ver/editar/eliminar)" -ForegroundColor White
Write-Host "  - Confirmacion de eliminacion" -ForegroundColor White
Write-Host "  - Pagina de detalle completa con 4 stats + info fiscal + ubicacion + contacto" -ForegroundColor White
Write-Host "  - Boton 'Recalcular alertas'" -ForegroundColor White
Write-Host "  - Sidebar con estado SOL, color, acciones rapidas" -ForegroundColor White
Write-Host ""
Write-Host "Prueba:" -ForegroundColor Yellow
Write-Host "  1. Click 'Nueva Empresa' en /empresas" -ForegroundColor White
Write-Host "  2. Escribe RUC: 20100070970 (Saga Falabella - autocompleta)" -ForegroundColor White
Write-Host "  3. Elige color, agrega contacto, guarda" -ForegroundColor White
Write-Host "  4. Click en fila para ir al detalle" -ForegroundColor White
Write-Host "  5. Edita desde el detalle" -ForegroundColor White
Write-Host ""
