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
