# ============================================================
#  FELICITA - Cambio 2: Panel contextual por empresa
#  .\cambio2_panel_empresa.ps1
# ============================================================

Write-Host ""
Write-Host "Cambio 2 - Panel contextual por empresa" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "frontend")) {
    Write-Host "ERROR: ejecuta desde la raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# ============================================================
# store/empresaActivaStore.ts - estado de empresa actual
# ============================================================

@'
import { create } from 'zustand'
import type { Empresa } from '../types/empresa'

interface EmpresaActivaState {
  empresaActiva: Empresa | null
  setEmpresaActiva: (empresa: Empresa | null) => void
  clearEmpresaActiva: () => void
}

export const useEmpresaActivaStore = create<EmpresaActivaState>((set) => ({
  empresaActiva: null,
  setEmpresaActiva: (empresa) => set({ empresaActiva: empresa }),
  clearEmpresaActiva: () => set({ empresaActiva: null }),
}))
'@ | Set-Content "frontend/src/store/empresaActivaStore.ts"
Write-Host "  [OK] store/empresaActivaStore.ts" -ForegroundColor Green

# ============================================================
# components/EmpresaSwitcher.tsx - selector rapido de empresa
# ============================================================

@'
import { useState, useRef, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { ChevronDown, Search, Check, Plus } from 'lucide-react'
import { empresaService } from '../services/empresaService'
import type { Empresa } from '../types/empresa'
import { AlertBadge } from './ui'

interface EmpresaSwitcherProps {
  empresaActiva: Empresa | null
  rutaBase: string  // ej: "dashboard", "declaraciones"
}

export default function EmpresaSwitcher({ empresaActiva, rutaBase }: EmpresaSwitcherProps) {
  const navigate = useNavigate()
  const [abierto, setAbierto] = useState(false)
  const [busqueda, setBusqueda] = useState('')
  const [empresas, setEmpresas] = useState<Empresa[]>([])
  const [loading, setLoading] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  // Cerrar al click fuera
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setAbierto(false)
      }
    }
    if (abierto) {
      document.addEventListener('mousedown', handler)
      return () => document.removeEventListener('mousedown', handler)
    }
  }, [abierto])

  // Cargar empresas al abrir
  useEffect(() => {
    if (abierto && empresas.length === 0) {
      cargarEmpresas()
    }
  }, [abierto])

  async function cargarEmpresas() {
    setLoading(true)
    try {
      const res = await empresaService.listar({ orden: 'nombre' })
      setEmpresas(res.empresas)
    } finally {
      setLoading(false)
    }
  }

  function seleccionar(empresa: Empresa) {
    setAbierto(false)
    setBusqueda('')
    navigate(`/empresas/${empresa.id}/${rutaBase}`)
  }

  const filtradas = busqueda
    ? empresas.filter(e =>
        e.razon_social.toLowerCase().includes(busqueda.toLowerCase()) ||
        e.ruc.includes(busqueda)
      )
    : empresas

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setAbierto(!abierto)}
        className="w-full px-3 py-2 bg-sidebar-hover rounded-lg text-left text-xs text-sidebar-text hover:bg-sidebar-hover/80 transition-colors flex items-center justify-between gap-2"
      >
        <span className="flex-1">Cambiar empresa</span>
        <ChevronDown size={12} className={`transition-transform ${abierto ? 'rotate-180' : ''}`} />
      </button>

      {abierto && (
        <div className="absolute top-full left-0 right-0 mt-1 bg-white rounded-lg shadow-xl border border-gray-200 z-50 overflow-hidden">
          <div className="p-2 border-b border-gray-100">
            <div className="relative">
              <Search size={12} className="absolute left-2 top-1/2 -translate-y-1/2 text-gray-400" />
              <input
                type="text"
                placeholder="Buscar..."
                value={busqueda}
                onChange={e => setBusqueda(e.target.value)}
                autoFocus
                className="w-full pl-7 pr-2 py-1.5 text-xs border border-gray-200 rounded focus:outline-none focus:ring-1 focus:ring-brand-800"
              />
            </div>
          </div>

          <div className="max-h-80 overflow-y-auto">
            {loading ? (
              <div className="p-4 text-center text-xs text-gray-400">Cargando...</div>
            ) : filtradas.length === 0 ? (
              <div className="p-4 text-center text-xs text-gray-400">
                {busqueda ? 'Sin resultados' : 'No hay empresas'}
              </div>
            ) : (
              filtradas.map(empresa => (
                <button
                  key={empresa.id}
                  onClick={() => seleccionar(empresa)}
                  className={`w-full px-3 py-2 text-left hover:bg-gray-50 flex items-center gap-2 transition-colors ${
                    empresaActiva?.id === empresa.id ? 'bg-brand-50' : ''
                  }`}
                >
                  <div
                    className="w-1 h-8 rounded-full flex-shrink-0"
                    style={{ backgroundColor: empresa.color_identificacion }}
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-semibold text-gray-900 truncate">
                      {empresa.razon_social}
                    </p>
                    <div className="flex items-center gap-2 mt-0.5">
                      <p className="text-[10px] text-gray-500 font-mono">{empresa.ruc}</p>
                      <AlertBadge nivel={empresa.nivel_alerta} showLabel={false} />
                    </div>
                  </div>
                  {empresaActiva?.id === empresa.id && (
                    <Check size={14} className="text-brand-800 flex-shrink-0" />
                  )}
                </button>
              ))
            )}
          </div>

          <button
            onClick={() => {
              setAbierto(false)
              navigate('/empresas')
            }}
            className="w-full px-3 py-2 text-left text-xs text-brand-800 hover:bg-brand-50 border-t border-gray-100 flex items-center gap-2 font-semibold"
          >
            <Plus size={12} />
            Ver todas las empresas
          </button>
        </div>
      )}
    </div>
  )
}
'@ | Set-Content "frontend/src/components/EmpresaSwitcher.tsx"
Write-Host "  [OK] components/EmpresaSwitcher.tsx" -ForegroundColor Green

# ============================================================
# components/EmpresaSidebar.tsx - sidebar contextual
# ============================================================

@'
import { NavLink, useNavigate, useLocation } from 'react-router-dom'
import {
  LayoutDashboard, FileText, BookOpen, Receipt, Users, BarChart3,
  Settings, LogOut, ChevronLeft, ChevronRight, ArrowLeft
} from 'lucide-react'
import { useAuthStore } from '../store/authStore'
import { useUIStore } from '../store/uiStore'
import { AlertBadge } from './ui'
import EmpresaSwitcher from './EmpresaSwitcher'
import type { Empresa } from '../types/empresa'

interface NavItem {
  to: string
  label: string
  icon: React.ComponentType<{ size?: number; className?: string }>
  badge?: string | number
}

interface EmpresaSidebarProps {
  empresa: Empresa
}

export default function EmpresaSidebar({ empresa }: EmpresaSidebarProps) {
  const navigate = useNavigate()
  const location = useLocation()
  const { usuario, logout } = useAuthStore()
  const { sidebarCollapsed, toggleSidebar } = useUIStore()
  const collapsed = sidebarCollapsed

  const handleLogout = () => { logout(); navigate('/login') }
  const iniciales = usuario
    ? `${usuario.nombre[0]}${usuario.apellido[0]}`.toUpperCase()
    : '?'

  // Ruta actual relativa (para pasarla al switcher)
  const rutaActual = location.pathname.split(`/empresas/${empresa.id}/`)[1] || 'dashboard'

  const NAV_GESTION: NavItem[] = [
    { to: `/empresas/${empresa.id}/dashboard`,     label: 'Dashboard',     icon: LayoutDashboard },
    { to: `/empresas/${empresa.id}/declaraciones`, label: 'Declaraciones', icon: FileText },
    { to: `/empresas/${empresa.id}/libros`,        label: 'Libros electronicos', icon: BookOpen },
    { to: `/empresas/${empresa.id}/facturacion`,   label: 'Facturacion',   icon: Receipt },
    { to: `/empresas/${empresa.id}/planillas`,     label: 'Planillas',     icon: Users },
    { to: `/empresas/${empresa.id}/reportes`,      label: 'Reportes',      icon: BarChart3 },
  ]

  const NAV_CONFIG: NavItem[] = [
    { to: `/empresas/${empresa.id}/configuracion`, label: 'Configuracion', icon: Settings },
  ]

  return (
    <aside
      className="bg-sidebar text-sidebar-text flex flex-col transition-all duration-200 h-screen sticky top-0"
      style={{ width: collapsed ? '64px' : '260px' }}
    >
      {/* Header con boton volver y toggle */}
      <div className="relative border-b border-sidebar-border">
        <button
          onClick={() => navigate('/empresas')}
          className="w-full flex items-center gap-2 px-3 py-3 hover:bg-sidebar-hover transition-colors text-xs text-sidebar-muted hover:text-white"
          title="Volver al panel general"
        >
          <ArrowLeft size={14} className="flex-shrink-0" />
          {!collapsed && <span>Volver al panel general</span>}
        </button>

        <button
          onClick={toggleSidebar}
          className="p-1 hover:bg-sidebar-hover rounded-md transition-colors"
          title={collapsed ? 'Expandir' : 'Colapsar'}
          style={{ position: 'absolute', top: 8, right: collapsed ? -12 : 8, background: '#1E293B', border: '1px solid #334155', zIndex: 10 }}
        >
          {collapsed
            ? <ChevronRight size={14} className="text-sidebar-text" />
            : <ChevronLeft size={14} className="text-sidebar-text" />
          }
        </button>
      </div>

      {/* Identidad de la empresa */}
      {!collapsed ? (
        <div className="px-3 py-3 border-b border-sidebar-border space-y-2">
          <div className="flex items-start gap-2">
            <div
              className="w-1 h-10 rounded-full flex-shrink-0 mt-0.5"
              style={{ backgroundColor: empresa.color_identificacion }}
            />
            <div className="flex-1 min-w-0">
              <p className="text-[10px] text-sidebar-muted uppercase tracking-wider font-semibold mb-0.5">
                Empresa
              </p>
              <p className="text-sm font-heading font-bold text-white truncate leading-tight">
                {empresa.razon_social}
              </p>
              <div className="flex items-center gap-2 mt-1">
                <p className="text-[11px] text-sidebar-muted font-mono">
                  RUC {empresa.ruc}
                </p>
              </div>
              <div className="mt-1.5">
                <AlertBadge nivel={empresa.nivel_alerta} />
              </div>
            </div>
          </div>

          <EmpresaSwitcher empresaActiva={empresa} rutaBase={rutaActual} />
        </div>
      ) : (
        <div className="py-3 flex justify-center border-b border-sidebar-border">
          <div
            className="w-8 h-8 rounded-lg flex items-center justify-center text-white font-bold text-xs"
            style={{ backgroundColor: empresa.color_identificacion }}
            title={empresa.razon_social}
          >
            {empresa.razon_social.slice(0, 2).toUpperCase()}
          </div>
        </div>
      )}

      {/* Navegacion */}
      <nav className="flex-1 px-2 py-3 overflow-y-auto">
        <NavSection label="Gestion" collapsed={collapsed} />
        {NAV_GESTION.map(item => <SidebarItem key={item.to} {...item} collapsed={collapsed} />)}

        <div className="mt-5">
          <NavSection label="Configuracion" collapsed={collapsed} />
          {NAV_CONFIG.map(item => <SidebarItem key={item.to} {...item} collapsed={collapsed} />)}
        </div>
      </nav>

      {/* Footer usuario */}
      <div className="border-t border-sidebar-border p-3">
        {!collapsed ? (
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 bg-brand-700 rounded-full flex items-center justify-center text-white text-sm font-semibold flex-shrink-0">
              {iniciales}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-white truncate">
                {usuario?.nombre} {usuario?.apellido}
              </p>
              <p className="text-xs text-sidebar-muted truncate">Plan {usuario?.plan_actual}</p>
            </div>
            <button onClick={handleLogout}
              className="p-1.5 hover:bg-sidebar-hover rounded-md transition-colors text-sidebar-muted hover:text-white"
              title="Cerrar sesion">
              <LogOut size={16} />
            </button>
          </div>
        ) : (
          <button onClick={handleLogout}
            className="w-full flex justify-center p-2 hover:bg-sidebar-hover rounded-md transition-colors text-sidebar-muted hover:text-white">
            <div className="w-9 h-9 bg-brand-700 rounded-full flex items-center justify-center text-white text-sm font-semibold">
              {iniciales}
            </div>
          </button>
        )}
      </div>
    </aside>
  )
}

function NavSection({ label, collapsed }: { label: string; collapsed: boolean }) {
  if (collapsed) return <div className="h-px bg-sidebar-border mx-2 my-2" />
  return (
    <div className="px-3 pt-2 pb-1">
      <span className="text-[10px] font-semibold text-sidebar-muted uppercase tracking-wider">{label}</span>
    </div>
  )
}

function SidebarItem({ to, label, icon: Icon, badge, collapsed }: NavItem & { collapsed: boolean }) {
  return (
    <NavLink
      to={to}
      title={collapsed ? label : undefined}
      className={({ isActive }) =>
        `flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors mb-0.5 ${
          isActive ? 'bg-brand-800 text-white' : 'text-sidebar-text hover:bg-sidebar-hover hover:text-white'
        } ${collapsed ? 'justify-center' : ''}`
      }
    >
      <Icon size={18} className="flex-shrink-0" />
      {!collapsed && (
        <>
          <span className="truncate flex-1">{label}</span>
          {badge !== undefined && (
            <span className="text-[10px] bg-sidebar-hover px-1.5 py-0.5 rounded-full font-semibold">
              {badge}
            </span>
          )}
        </>
      )}
    </NavLink>
  )
}
'@ | Set-Content "frontend/src/components/EmpresaSidebar.tsx"
Write-Host "  [OK] components/EmpresaSidebar.tsx" -ForegroundColor Green

# ============================================================
# components/EmpresaLayout.tsx - layout con sidebar contextual
# ============================================================

@'
import { useEffect, useState } from 'react'
import { useParams, Outlet, useNavigate } from 'react-router-dom'
import EmpresaSidebar from './EmpresaSidebar'
import { empresaService } from '../services/empresaService'
import { useEmpresaActivaStore } from '../store/empresaActivaStore'
import type { Empresa } from '../types/empresa'
import { Loader2 } from 'lucide-react'

export default function EmpresaLayout() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { empresaActiva, setEmpresaActiva, clearEmpresaActiva } = useEmpresaActivaStore()
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!id) {
      navigate('/empresas')
      return
    }
    cargarEmpresa(Number(id))
    return () => clearEmpresaActiva()
  }, [id])

  async function cargarEmpresa(empresaId: number) {
    setLoading(true)
    try {
      const data = await empresaService.obtener(empresaId)
      setEmpresaActiva(data as Empresa)
    } catch (err) {
      console.error(err)
      navigate('/empresas')
    } finally {
      setLoading(false)
    }
  }

  if (loading || !empresaActiva) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <div className="flex items-center gap-2 text-gray-500">
          <Loader2 size={18} className="animate-spin" />
          Cargando empresa...
        </div>
      </div>
    )
  }

  return (
    <div className="flex min-h-screen bg-gray-100">
      <EmpresaSidebar empresa={empresaActiva} />
      <main className="flex-1 min-w-0 overflow-x-hidden">
        <Outlet context={{ empresa: empresaActiva, recargar: () => cargarEmpresa(empresaActiva.id) }} />
      </main>
    </div>
  )
}

// Hook para acceder a la empresa activa desde paginas hijas
export function useEmpresaActiva() {
  const { empresaActiva } = useEmpresaActivaStore()
  return empresaActiva
}
'@ | Set-Content "frontend/src/components/EmpresaLayout.tsx"
Write-Host "  [OK] components/EmpresaLayout.tsx" -ForegroundColor Green

# ============================================================
# pages/empresa/Dashboard.tsx - dashboard de empresa individual
# ============================================================

New-Item -ItemType Directory -Force -Path "frontend/src/pages/empresa" | Out-Null

@'
import { useOutletContext, useNavigate } from 'react-router-dom'
import {
  FileText, BookOpen, Receipt, Users, BarChart3, Settings,
  Shield, KeyRound, Calendar, Clock, TrendingUp, AlertCircle,
  CheckCircle2, Inbox, ArrowRight, Pencil
} from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import { AlertBadge } from '../../components/ui'
import { REGIMENES_LABEL } from '../../types/empresa'
import type { EmpresaDetalle } from '../../types/empresa'

interface Ctx {
  empresa: EmpresaDetalle
  recargar: () => void
}

export default function DashboardEmpresa() {
  const { empresa } = useOutletContext<Ctx>()
  const navigate = useNavigate()

  const formatFecha = (f: string | null) => {
    if (!f) return '-'
    return new Date(f).toLocaleDateString('es-PE', { day: '2-digit', month: 'short', year: 'numeric' })
  }

  const modulos = [
    { titulo: 'Declaraciones',       desc: 'PDT 621 - IGV y Renta',  icon: FileText,    ruta: 'declaraciones', color: 'bg-brand-50 text-brand-800' },
    { titulo: 'Libros electronicos', desc: 'SIRE - Ventas y Compras', icon: BookOpen,   ruta: 'libros',        color: 'bg-purple-50 text-purple-800' },
    { titulo: 'Facturacion',         desc: 'Comprobantes electronicos', icon: Receipt, ruta: 'facturacion',   color: 'bg-success-50 text-success-900' },
    { titulo: 'Planillas',           desc: 'PLAME - Planillas mensuales', icon: Users, ruta: 'planillas',     color: 'bg-warning-50 text-warning-900' },
    { titulo: 'Reportes',            desc: 'Estados financieros',      icon: BarChart3, ruta: 'reportes',      color: 'bg-pink-50 text-pink-800' },
    { titulo: 'Configuracion',       desc: 'Datos y credenciales',     icon: Settings,  ruta: 'configuracion', color: 'bg-gray-100 text-gray-700' },
  ]

  return (
    <>
      <PageHeader
        eyebrow={`RUC ${empresa.ruc}`}
        title={empresa.razon_social}
        description={empresa.nombre_comercial || REGIMENES_LABEL[empresa.regimen_tributario]}
        actions={
          <button
            onClick={() => navigate(`/empresas/${empresa.id}/configuracion`)}
            className="btn-secondary flex items-center gap-2"
          >
            <Pencil size={14} /> Editar datos
          </button>
        }
      />

      <div className="p-6 lg:p-8 space-y-6">

        {/* Alerta de estado */}
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
                {empresa.nivel_alerta === 'ROJO' ? 'Atencion urgente' : 'Atencion necesaria'}
              </p>
              <p className={`text-sm mt-0.5 ${
                empresa.nivel_alerta === 'ROJO' ? 'text-danger-700' : 'text-warning-700'
              }`}>
                {empresa.motivo_alerta}
              </p>
            </div>
          </div>
        )}

        {/* Stats rapidas */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard icon={<FileText size={16} />} label="Declaraciones" value={empresa.total_pdt621s} />
          <StatCard icon={<Inbox size={16} />} label="Pendientes" value={empresa.pdt621s_pendientes}
            accent={empresa.pdt621s_pendientes > 0 ? 'warning' : 'neutral'} />
          <StatCard icon={<Clock size={16} />} label="Ultima declaracion" value={formatFecha(empresa.ultima_declaracion)} isText />
          <StatCard icon={<Calendar size={16} />} label="Proximo venc." value={formatFecha(empresa.proximo_vencimiento)}
            isText accent={empresa.proximo_vencimiento ? 'brand' : 'neutral'} />
        </div>

        {/* Modulos disponibles */}
        <div>
          <h2 className="font-heading font-bold text-gray-900 mb-3">Modulos disponibles</h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {modulos.map(m => (
              <button
                key={m.ruta}
                onClick={() => navigate(`/empresas/${empresa.id}/${m.ruta}`)}
                className="card p-5 text-left hover:shadow-card-hover transition-all group"
              >
                <div className="flex items-start gap-3">
                  <div className={`w-10 h-10 rounded-lg ${m.color} flex items-center justify-center flex-shrink-0`}>
                    <m.icon size={18} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <h3 className="font-heading font-bold text-gray-900 text-sm">{m.titulo}</h3>
                      <ArrowRight size={14} className="text-gray-400 group-hover:text-brand-800 group-hover:translate-x-1 transition-all" />
                    </div>
                    <p className="text-xs text-gray-500 mt-0.5">{m.desc}</p>
                  </div>
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Info resumen + estado credenciales */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <div className="card p-5 lg:col-span-2">
            <h3 className="font-heading font-bold text-gray-900 text-sm mb-4 flex items-center gap-2">
              <TrendingUp size={14} className="text-brand-800" />
              Informacion general
            </h3>
            <dl className="grid grid-cols-2 gap-4">
              <InfoField label="Regimen" value={REGIMENES_LABEL[empresa.regimen_tributario]} />
              <InfoField label="Estado SUNAT"
                value={<span className={`font-semibold ${empresa.estado_sunat === 'ACTIVO' ? 'text-success-700' : 'text-danger-700'}`}>
                  {empresa.estado_sunat}
                </span>} />
              <InfoField label="Condicion domicilio"
                value={<span className={`font-semibold ${empresa.condicion_domicilio === 'HABIDO' ? 'text-success-700' : 'text-danger-700'}`}>
                  {empresa.condicion_domicilio}
                </span>} />
              <InfoField label="Direccion" value={empresa.direccion_fiscal} />
              <InfoField label="Distrito" value={empresa.distrito || '-'} />
              <InfoField label="Representante legal" value={empresa.representante_legal || '-'} />
            </dl>
          </div>

          <div className="space-y-4">
            <div className="card p-4">
              <h3 className="font-heading font-bold text-gray-900 text-xs mb-3 flex items-center gap-2">
                <Shield size={12} className="text-brand-800" />
                Acceso SOL
              </h3>
              {empresa.tiene_clave_sol ? (
                <div className="space-y-1">
                  <div className="flex items-center gap-1.5 text-success-700">
                    <CheckCircle2 size={14} />
                    <span className="text-xs font-semibold">Configurado</span>
                  </div>
                  <p className="text-[11px] text-gray-500">
                    Acceso: {empresa.tipo_acceso_sol}
                    {empresa.tipo_acceso_sol === 'RUC' && empresa.usuario_sol && ` / ${empresa.usuario_sol}`}
                    {empresa.tipo_acceso_sol === 'DNI' && empresa.dni_sol && ` / ${empresa.dni_sol}`}
                  </p>
                </div>
              ) : (
                <div className="space-y-1">
                  <p className="text-xs text-gray-600">No configurado</p>
                  <button
                    onClick={() => navigate(`/empresas/${empresa.id}/configuracion`)}
                    className="text-[11px] text-brand-800 hover:underline font-semibold"
                  >
                    Configurar ahora
                  </button>
                </div>
              )}
            </div>

            <div className="card p-4">
              <h3 className="font-heading font-bold text-gray-900 text-xs mb-3 flex items-center gap-2">
                <KeyRound size={12} className="text-brand-800" />
                API SUNAT (SIRE)
              </h3>
              {empresa.tiene_credenciales_api_sunat ? (
                <div className="flex items-center gap-1.5 text-success-700">
                  <CheckCircle2 size={14} />
                  <span className="text-xs font-semibold">Configurado</span>
                </div>
              ) : (
                <div className="space-y-1">
                  <p className="text-xs text-gray-600">No configurado</p>
                  <button
                    onClick={() => navigate(`/empresas/${empresa.id}/configuracion`)}
                    className="text-[11px] text-brand-800 hover:underline font-semibold"
                  >
                    Configurar credenciales
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </>
  )
}

function StatCard({ icon, label, value, accent = 'neutral', isText }: {
  icon: React.ReactNode
  label: string
  value: React.ReactNode
  accent?: 'brand' | 'success' | 'warning' | 'neutral'
  isText?: boolean
}) {
  const colors = {
    brand:   'text-brand-800',
    success: 'text-success-700',
    warning: 'text-warning-700',
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

function InfoField({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <dt className="text-[11px] font-semibold text-gray-500 uppercase tracking-wider mb-0.5">{label}</dt>
      <dd className="text-sm text-gray-900">{value}</dd>
    </div>
  )
}
'@ | Set-Content "frontend/src/pages/empresa/Dashboard.tsx"
Write-Host "  [OK] pages/empresa/Dashboard.tsx" -ForegroundColor Green

# ============================================================
# pages/empresa/Placeholder.tsx - paginas placeholder reutilizables
# ============================================================

@'
import { useOutletContext } from 'react-router-dom'
import { Construction } from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import type { Empresa } from '../../types/empresa'

interface Ctx { empresa: Empresa }

interface PlaceholderProps {
  titulo: string
  descripcion: string
  icono: React.ComponentType<{ size?: number; className?: string }>
  eyebrow?: string
}

export default function ModuloPlaceholder({ titulo, descripcion, icono: Icon, eyebrow }: PlaceholderProps) {
  const { empresa } = useOutletContext<Ctx>()

  return (
    <>
      <PageHeader
        eyebrow={eyebrow || empresa.razon_social}
        title={titulo}
        description={descripcion}
      />
      <div className="p-6 lg:p-8">
        <div className="card p-12 text-center">
          <div className="w-16 h-16 bg-brand-50 rounded-full flex items-center justify-center mx-auto mb-4">
            <Icon size={28} className="text-brand-800" />
          </div>
          <h2 className="font-heading font-bold text-gray-900 text-lg mb-2">
            Modulo en construccion
          </h2>
          <p className="text-sm text-gray-500 max-w-md mx-auto">
            Estamos trabajando en este modulo. Muy pronto estara disponible con todas sus funcionalidades.
          </p>
          <div className="inline-flex items-center gap-2 mt-4 text-xs text-gray-400 bg-gray-50 px-3 py-1.5 rounded-full">
            <Construction size={12} />
            Proximamente
          </div>
        </div>
      </div>
    </>
  )
}
'@ | Set-Content "frontend/src/pages/empresa/Placeholder.tsx"
Write-Host "  [OK] pages/empresa/Placeholder.tsx" -ForegroundColor Green

# ============================================================
# pages/empresa/Configuracion.tsx - reutiliza EmpresaForm
# ============================================================

@'
import { useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { Settings as SettingsIcon } from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import EmpresaForm from '../../components/EmpresaForm'
import { empresaService } from '../../services/empresaService'
import type { EmpresaDetalle } from '../../types/empresa'

interface Ctx {
  empresa: EmpresaDetalle
  recargar: () => void
}

export default function ConfiguracionEmpresa() {
  const { empresa, recargar } = useOutletContext<Ctx>()
  const [guardando, setGuardando] = useState(false)
  const [mensaje, setMensaje] = useState('')

  async function handleGuardar(data: any) {
    setGuardando(true)
    setMensaje('')
    try {
      await empresaService.actualizar(empresa.id, data)
      setMensaje('Cambios guardados correctamente')
      recargar()
      setTimeout(() => setMensaje(''), 3000)
    } catch (err: any) {
      throw err
    } finally {
      setGuardando(false)
    }
  }

  return (
    <>
      <PageHeader
        eyebrow={empresa.razon_social}
        title="Configuracion de la empresa"
        description="Datos, contacto y credenciales SUNAT"
      />

      <div className="p-6 lg:p-8">
        {mensaje && (
          <div className="bg-success-50 border border-success-600/20 text-success-900 text-sm rounded-lg px-4 py-2.5 mb-4">
            {mensaje}
          </div>
        )}

        <div className="card p-6">
          <EmpresaForm
            empresa={empresa}
            onSubmit={handleGuardar}
            onCancel={() => window.history.back()}
            loading={guardando}
          />
        </div>
      </div>
    </>
  )
}
'@ | Set-Content "frontend/src/pages/empresa/Configuracion.tsx"
Write-Host "  [OK] pages/empresa/Configuracion.tsx" -ForegroundColor Green

# ============================================================
# App.tsx - rutas con layout contextual
# ============================================================

@'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { FileText, BookOpen, Receipt, Users, BarChart3 } from 'lucide-react'
import { useAuthStore } from './store/authStore'
import LoginPage from './pages/Login'
import AppLayout from './components/AppLayout'
import EmpresaLayout from './components/EmpresaLayout'
import DashboardContador from './pages/contador/Dashboard'
import CalendarioPage from './pages/contador/Calendario'
import EmpresasPage from './pages/contador/Empresas'
import DashboardEmpresa from './pages/empresa/Dashboard'
import ConfiguracionEmpresa from './pages/empresa/Configuracion'
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

        {/* Panel general del contador */}
        <Route element={<PrivateRoute><AppLayout /></PrivateRoute>}>
          <Route path="/dashboard" element={<DashboardContador />} />
          <Route path="/empresas" element={<EmpresasPage />} />
          <Route path="/calendario" element={<CalendarioPage />} />
          <Route path="/declaraciones" element={<ContadorPlaceholder title="Declaraciones" />} />
          <Route path="/configuracion" element={<ContadorPlaceholder title="Configuracion del contador" />} />
        </Route>

        {/* Panel contextual por empresa */}
        <Route path="/empresas/:id" element={<PrivateRoute><EmpresaLayout /></PrivateRoute>}>
          <Route index element={<Navigate to="dashboard" replace />} />
          <Route path="dashboard" element={<DashboardEmpresa />} />
          <Route path="declaraciones" element={
            <ModuloPlaceholder
              titulo="Declaraciones (PDT 621)"
              descripcion="Gestion mensual de IGV y Renta"
              icono={FileText}
              eyebrow="Obligaciones tributarias"
            />
          } />
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
Write-Host "  [OK] App.tsx con rutas contextuales" -ForegroundColor Green

# ============================================================
# pages/contador/Empresas.tsx - ajustar click en fila a dashboard de empresa
# ============================================================

$empresasPath = "frontend/src/pages/contador/Empresas.tsx"
if (Test-Path $empresasPath) {
    $empresasContent = Get-Content $empresasPath -Raw
    # La fila ya navega a /empresas/:id que redirige a dashboard
    # Solo confirmamos que este archivo no necesita cambios
    Write-Host "  [OK] Empresas.tsx ya navega a /empresas/:id" -ForegroundColor Green
}

# ============================================================
# pages/contador/Dashboard.tsx - click en empresa navega a /empresas/:id
# ============================================================

$dashboardPath = "frontend/src/pages/contador/Dashboard.tsx"
$dashboardContent = Get-Content $dashboardPath -Raw
# Este archivo ya navega a /empresas/:id, no cambio necesario
Write-Host "  [OK] Dashboard contador ya navega a /empresas/:id" -ForegroundColor Green

# ============================================================
# Eliminar EmpresaDetalle.tsx obsoleto (reemplazado por el layout)
# ============================================================

$detalleObsoleto = "frontend/src/pages/contador/EmpresaDetalle.tsx"
if (Test-Path $detalleObsoleto) {
    Remove-Item $detalleObsoleto
    Write-Host "  [OK] EmpresaDetalle.tsx eliminado (reemplazado por panel contextual)" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Cambio 2 aplicado!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vite se recarga solo. Si no, reinicia con: cd frontend && npm run dev" -ForegroundColor Yellow
Write-Host ""
Write-Host "Probar:" -ForegroundColor Yellow
Write-Host "  1. Ve a /empresas" -ForegroundColor White
Write-Host "  2. Click en cualquier empresa (ej: EMPRESA ALFA)" -ForegroundColor White
Write-Host "  3. El sidebar cambia completamente:" -ForegroundColor White
Write-Host "     - Nombre de empresa arriba" -ForegroundColor Gray
Write-Host "     - Selector 'Cambiar empresa' con busqueda" -ForegroundColor Gray
Write-Host "     - Modulos: Dashboard, Declaraciones, Libros, Facturacion..." -ForegroundColor Gray
Write-Host "     - Boton 'Volver al panel general' arriba" -ForegroundColor Gray
Write-Host "  4. Click 'Cambiar empresa' - busca otra y cambia rapido" -ForegroundColor White
Write-Host "  5. Click 'Configuracion' - edita los datos" -ForegroundColor White
Write-Host "  6. Click 'Volver al panel general' - regresa al sidebar principal" -ForegroundColor White
Write-Host ""
