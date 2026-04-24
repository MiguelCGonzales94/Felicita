# ============================================================
#  FELICITA - Entrega 2: Frontend Empresas (listado + filtros)
#  Ejecutar desde la raiz del proyecto felicita/
#  .\entrega2_empresas_frontend.ps1
# ============================================================

Write-Host ""
Write-Host "Entrega 2 - Frontend de empresas" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "frontend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# Crear carpeta si no existe
New-Item -ItemType Directory -Force -Path "frontend/src/services" | Out-Null
New-Item -ItemType Directory -Force -Path "frontend/src/hooks" | Out-Null
New-Item -ItemType Directory -Force -Path "frontend/src/types" | Out-Null

# ============================================================
# types/empresa.ts
# ============================================================
@'
export interface Empresa {
  id: number
  ruc: string
  razon_social: string
  nombre_comercial: string | null
  direccion_fiscal: string
  distrito: string | null
  provincia: string | null
  departamento: string | null
  regimen_tributario: string
  estado_sunat: string
  condicion_domicilio: string
  representante_legal: string | null
  email_empresa: string | null
  telefono_empresa: string | null
  nivel_alerta: 'VERDE' | 'AMARILLO' | 'ROJO'
  motivo_alerta: string | null
  color_identificacion: string
  tiene_clave_sol: boolean
  activa: boolean
  fecha_creacion: string
}

export interface EmpresaDetalle extends Empresa {
  total_pdt621s: number
  pdt621s_pendientes: number
  ultima_declaracion: string | null
  proximo_vencimiento: string | null
}

export interface ValidacionRUC {
  ruc: string
  es_valido: boolean
  mensaje: string
  tipo: string
  razon_social: string | null
  estado_sunat: string | null
  condicion_domicilio: string | null
  direccion_fiscal: string | null
  distrito: string | null
  provincia: string | null
  departamento: string | null
  ya_registrada: boolean
}

export interface EmpresaListFilters {
  buscar?: string
  nivel_alerta?: 'VERDE' | 'AMARILLO' | 'ROJO'
  regimen?: 'RG' | 'RMT' | 'RER' | 'NRUS'
  orden?: 'alerta' | 'nombre' | 'fecha' | 'ruc'
}

export interface EmpresaListResponse {
  total: number
  empresas: Empresa[]
}

export const REGIMENES_LABEL: Record<string, string> = {
  RG:   'Régimen General',
  RMT:  'Régimen MYPE Tributario',
  RER:  'Régimen Especial',
  NRUS: 'Nuevo RUS',
}

export const COLORES_EMPRESA = [
  '#3B82F6', '#10B981', '#F59E0B', '#EF4444',
  '#8B5CF6', '#EC4899', '#06B6D4', '#84CC16',
  '#F97316', '#6366F1',
]
'@ | Set-Content "frontend/src/types/empresa.ts"
Write-Host "  [OK] types/empresa.ts" -ForegroundColor Green

# ============================================================
# services/empresaService.ts
# ============================================================
@'
import api from './api'
import type {
  Empresa, EmpresaDetalle, ValidacionRUC,
  EmpresaListFilters, EmpresaListResponse
} from '../types/empresa'

export const empresaService = {
  async listar(filters: EmpresaListFilters = {}): Promise<EmpresaListResponse> {
    const params = Object.entries(filters)
      .filter(([_, v]) => v !== undefined && v !== '')
      .reduce((acc, [k, v]) => ({ ...acc, [k]: v }), {})
    const { data } = await api.get('/empresas', { params })
    return data
  },

  async obtener(id: number): Promise<EmpresaDetalle> {
    const { data } = await api.get(`/empresas/${id}`)
    return data
  },

  async validarRuc(ruc: string): Promise<ValidacionRUC> {
    const { data } = await api.get(`/empresas/validar-ruc/${ruc}`)
    return data
  },

  async crear(payload: any): Promise<Empresa> {
    const { data } = await api.post('/empresas', payload)
    return data
  },

  async actualizar(id: number, payload: any): Promise<Empresa> {
    const { data } = await api.put(`/empresas/${id}`, payload)
    return data
  },

  async eliminar(id: number): Promise<void> {
    await api.delete(`/empresas/${id}`)
  },

  async reactivar(id: number): Promise<Empresa> {
    const { data } = await api.post(`/empresas/${id}/reactivar`)
    return data
  },

  async recalcularAlertas(id: number): Promise<Empresa> {
    const { data } = await api.post(`/empresas/${id}/recalcular-alertas`)
    return data
  },
}
'@ | Set-Content "frontend/src/services/empresaService.ts"
Write-Host "  [OK] services/empresaService.ts" -ForegroundColor Green

# ============================================================
# hooks/useDebounce.ts
# ============================================================
@'
import { useState, useEffect } from 'react'

export function useDebounce<T>(value: T, delay: number = 300): T {
  const [debounced, setDebounced] = useState<T>(value)

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay)
    return () => clearTimeout(timer)
  }, [value, delay])

  return debounced
}
'@ | Set-Content "frontend/src/hooks/useDebounce.ts"
Write-Host "  [OK] hooks/useDebounce.ts" -ForegroundColor Green

# ============================================================
# components/FilterChip.tsx - Componente reutilizable
# ============================================================
@'
interface FilterChipProps {
  label: string
  value: string | number
  active?: boolean
  count?: number
  onClick: () => void
  variant?: 'default' | 'success' | 'warning' | 'danger'
}

const VARIANTS = {
  default: 'border-gray-200 text-gray-700 hover:border-gray-300',
  success: 'border-success-600/30 text-success-900 hover:bg-success-50',
  warning: 'border-warning-600/30 text-warning-900 hover:bg-warning-50',
  danger:  'border-danger-600/30 text-danger-900 hover:bg-danger-50',
}

const VARIANTS_ACTIVE = {
  default: 'bg-brand-800 border-brand-800 text-white',
  success: 'bg-success-600 border-success-600 text-white',
  warning: 'bg-warning-600 border-warning-600 text-white',
  danger:  'bg-danger-600 border-danger-600 text-white',
}

export default function FilterChip({
  label, count, active, onClick, variant = 'default'
}: FilterChipProps) {
  const styles = active ? VARIANTS_ACTIVE[variant] : VARIANTS[variant]

  return (
    <button
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-xs font-semibold transition-colors ${styles}`}
    >
      {label}
      {count !== undefined && (
        <span className={`px-1.5 py-0 rounded-full text-[10px] ${
          active ? 'bg-white/20' : 'bg-gray-100 text-gray-600'
        }`}>
          {count}
        </span>
      )}
    </button>
  )
}
'@ | Set-Content "frontend/src/components/FilterChip.tsx"
Write-Host "  [OK] components/FilterChip.tsx" -ForegroundColor Green

# ============================================================
# pages/contador/Empresas.tsx - PAGINA PRINCIPAL
# ============================================================
@'
import { useState, useEffect, useMemo } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Plus, Search, Filter, Building2, MoreVertical,
  AlertCircle, CheckCircle2, ArrowUpDown, RefreshCw, X
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import { MetricCard, AlertBadge, EmptyState } from '../../components/ui'
import FilterChip from '../../components/FilterChip'
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

  const [filtros, setFiltros] = useState<EmpresaListFilters>({
    orden: 'alerta',
  })

  // Contadores globales (sin filtros) para los chips
  const [contadores, setContadores] = useState({ verde: 0, amarillo: 0, rojo: 0, total: 0 })

  useEffect(() => { cargarContadoresGlobales() }, [])
  useEffect(() => { cargar() }, [busquedaDebounced, filtros])

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
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  function toggleAlerta(nivel: 'VERDE' | 'AMARILLO' | 'ROJO') {
    setFiltros(f => ({
      ...f,
      nivel_alerta: f.nivel_alerta === nivel ? undefined : nivel,
    }))
  }

  function toggleRegimen(reg: 'RG' | 'RMT' | 'RER' | 'NRUS') {
    setFiltros(f => ({
      ...f,
      regimen: f.regimen === reg ? undefined : reg,
    }))
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
          <button className="btn-primary flex items-center gap-2">
            <Plus size={16} /> Nueva Empresa
          </button>
        }
      />

      <div className="p-6 lg:p-8">
        {/* Metricas */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <MetricCard label="Total empresas" value={contadores.total} accent="brand" icon={<Building2 size={24} />} />
          <MetricCard label="Al dia" value={contadores.verde} accent="success" icon={<CheckCircle2 size={24} />} />
          <MetricCard label="Atencion" value={contadores.amarillo} accent="warning" icon={<AlertCircle size={24} />} />
          <MetricCard label="Criticas" value={contadores.rojo} accent="danger" icon={<AlertCircle size={24} />} />
        </div>

        {/* Filtros */}
        <div className="card p-4 mb-4">
          {/* Barra de busqueda */}
          <div className="flex flex-col lg:flex-row gap-3 mb-4">
            <div className="relative flex-1">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text"
                value={busqueda}
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

            <button
              onClick={cargar}
              className="btn-secondary flex items-center gap-1"
              title="Recargar"
            >
              <RefreshCw size={14} />
            </button>
          </div>

          {/* Chips de filtro */}
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider mr-1">
              <Filter size={12} className="inline mr-1" /> Alerta:
            </span>
            <FilterChip
              label="Al dia"
              variant="success"
              count={contadores.verde}
              active={filtros.nivel_alerta === 'VERDE'}
              onClick={() => toggleAlerta('VERDE')}
            />
            <FilterChip
              label="Atencion"
              variant="warning"
              count={contadores.amarillo}
              active={filtros.nivel_alerta === 'AMARILLO'}
              onClick={() => toggleAlerta('AMARILLO')}
            />
            <FilterChip
              label="Critico"
              variant="danger"
              count={contadores.rojo}
              active={filtros.nivel_alerta === 'ROJO'}
              onClick={() => toggleAlerta('ROJO')}
            />

            <span className="w-px h-4 bg-gray-200 mx-2" />

            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider mr-1">
              Regimen:
            </span>
            {(['RG','RMT','RER','NRUS'] as const).map(r => (
              <FilterChip
                key={r}
                label={r}
                active={filtros.regimen === r}
                onClick={() => toggleRegimen(r)}
              />
            ))}

            {hayFiltrosActivos && (
              <button
                onClick={limpiarFiltros}
                className="text-xs text-brand-800 hover:text-brand-900 font-semibold ml-auto flex items-center gap-1"
              >
                <X size={12} /> Limpiar filtros
              </button>
            )}
          </div>
        </div>

        {/* Resultados */}
        <div className="card">
          <div className="px-5 py-3 border-b border-gray-100 flex items-center justify-between">
            <div className="text-sm text-gray-500">
              {loading ? 'Cargando...' :
                total === 0 ? 'Sin resultados' :
                `Mostrando ${empresas.length} de ${total} empresa${total !== 1 ? 's' : ''}`
              }
            </div>
            <div className="flex items-center gap-1 text-xs text-gray-400">
              <ArrowUpDown size={12} />
              <span>
                {filtros.orden === 'alerta' ? 'Por prioridad de alerta' :
                 filtros.orden === 'nombre' ? 'Por razon social' :
                 filtros.orden === 'fecha'  ? 'Mas recientes primero' :
                                              'Por RUC'}
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
                action={
                  <button onClick={limpiarFiltros} className="btn-secondary">
                    Limpiar filtros
                  </button>
                }
              />
            ) : (
              <EmptyState
                icon={<Building2 size={40} />}
                title="No tienes empresas registradas"
                description="Agrega tu primera empresa para comenzar"
                action={
                  <button className="btn-primary flex items-center gap-2 mx-auto">
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
                  onClick={() => navigate(`/empresas/${empresa.id}`)}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </>
  )
}

// ── Subcomponente: Fila de empresa ─────────────────────
function EmpresaRow({
  empresa, onClick
}: { empresa: Empresa; onClick: () => void }) {
  return (
    <div
      onClick={onClick}
      className="px-5 py-4 flex items-center gap-4 hover:bg-gray-50 transition-colors cursor-pointer group"
    >
      <div
        className="w-1 h-14 rounded-full flex-shrink-0"
        style={{ backgroundColor: empresa.color_identificacion }}
      />

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
          <p className="text-xs text-danger-600 mt-1 font-medium">
            ! {empresa.motivo_alerta}
          </p>
        )}
      </div>

      <button
        onClick={(e) => { e.stopPropagation() }}
        className="opacity-0 group-hover:opacity-100 transition-opacity p-1.5 hover:bg-gray-100 rounded-lg flex-shrink-0"
        title="Mas opciones"
      >
        <MoreVertical size={16} className="text-gray-500" />
      </button>
    </div>
  )
}

// ── Skeleton de carga ─────────────────────────────────
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
# App.tsx - Actualizar rutas
# ============================================================
@'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from './store/authStore'
import LoginPage from './pages/Login'
import AppLayout from './components/AppLayout'
import DashboardContador from './pages/contador/Dashboard'
import CalendarioPage from './pages/contador/Calendario'
import EmpresasPage from './pages/contador/Empresas'

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
          <Route path="/empresas/:id" element={<PlaceholderPage title="Detalle empresa" />} />
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

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Entrega 2 aplicada!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vite se recarga solo. Si no, reinicia:" -ForegroundColor Yellow
Write-Host "  cd frontend && npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "Ve a: http://localhost:5173/empresas" -ForegroundColor Yellow
Write-Host ""
Write-Host "Lo nuevo:" -ForegroundColor Yellow
Write-Host "  - Buscador en tiempo real (debounce 300ms)" -ForegroundColor White
Write-Host "  - Filtros por alerta (Verde/Amarillo/Rojo)" -ForegroundColor White
Write-Host "  - Filtros por regimen (RG/RMT/RER/NRUS)" -ForegroundColor White
Write-Host "  - Ordenamiento (alerta/nombre/fecha/RUC)" -ForegroundColor White
Write-Host "  - Metricas en tiempo real" -ForegroundColor White
Write-Host "  - Skeleton de carga" -ForegroundColor White
Write-Host "  - Click en fila navega a detalle" -ForegroundColor White
Write-Host ""
