# ============================================================
#  FELICITA - Aplicar rediseño completo (Opción B - Corporativo)
#  Ejecutar desde la raiz del proyecto felicita/
#  .\aplicar_rediseno.ps1
# ============================================================

Write-Host ""
Write-Host "Aplicando rediseno corporativo..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "frontend")) {
    Write-Host "ERROR: ejecuta este script desde la carpeta raiz 'felicita/'" -ForegroundColor Red
    exit 1
}

# Crear carpeta components si no existe
New-Item -ItemType Directory -Force -Path "frontend/src/components" | Out-Null

# ============================================================
# tailwind.config.js
# ============================================================
@"
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        heading: ['Manrope', 'system-ui', 'sans-serif'],
        sans:    ['Inter', 'system-ui', 'sans-serif'],
        mono:    ['JetBrains Mono', 'ui-monospace', 'monospace'],
      },
      colors: {
        brand: {
          50:  '#EFF6FF', 100: '#DBEAFE', 200: '#BFDBFE',
          500: '#3B82F6', 600: '#2563EB', 700: '#1D4ED8',
          800: '#1E40AF', 900: '#1E3A8A',
        },
        sidebar: {
          DEFAULT: '#0F172A', hover: '#1E293B', active: '#1E40AF',
          border: '#1E293B', text: '#CBD5E1', muted: '#64748B',
        },
        success: { 50: '#ECFDF5', 600: '#059669', 700: '#047857', 900: '#065F46' },
        warning: { 50: '#FFFBEB', 600: '#D97706', 700: '#B45309', 900: '#92400E' },
        danger:  { 50: '#FEF2F2', 600: '#DC2626', 700: '#B91C1C', 900: '#991B1B' },
      },
      boxShadow: {
        'card': '0 1px 2px 0 rgb(0 0 0 / 0.04)',
        'card-hover': '0 4px 6px -1px rgb(0 0 0 / 0.08)',
      },
    }
  },
  plugins: []
}
"@ | Set-Content "frontend/tailwind.config.js"
Write-Host "  [OK] tailwind.config.js" -ForegroundColor Green

# ============================================================
# index.css
# ============================================================
@"
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Manrope:wght@500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  html { font-family: 'Inter', system-ui, sans-serif; }
  body { background-color: #F3F4F6; color: #0F172A; -webkit-font-smoothing: antialiased; }
  h1, h2, h3, h4, h5 {
    font-family: 'Manrope', system-ui, sans-serif;
    font-weight: 700;
    letter-spacing: -0.02em;
  }
}

@layer components {
  .btn-primary { @apply bg-brand-800 hover:bg-brand-900 text-white font-medium px-4 py-2 rounded-lg transition-colors text-sm; }
  .btn-secondary { @apply bg-white hover:bg-gray-50 text-gray-700 border border-gray-300 font-medium px-4 py-2 rounded-lg transition-colors text-sm; }
  .card { @apply bg-white rounded-xl border border-gray-200 shadow-card; }
  .input { @apply w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-brand-800 focus:border-brand-800 transition; }
  .label { @apply block text-sm font-medium text-gray-700 mb-1; }
}

::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: #CBD5E1; border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: #94A3B8; }
"@ | Set-Content "frontend/src/index.css"
Write-Host "  [OK] index.css" -ForegroundColor Green

# ============================================================
# store/uiStore.ts
# ============================================================
@"
import { create } from 'zustand'

interface UIState {
  sidebarCollapsed: boolean
  toggleSidebar: () => void
  setSidebarCollapsed: (v: boolean) => void
}

const STORAGE_KEY = 'felicita_sidebar_collapsed'

export const useUIStore = create<UIState>((set) => ({
  sidebarCollapsed: localStorage.getItem(STORAGE_KEY) === 'true',
  toggleSidebar: () => set((state) => {
    const next = !state.sidebarCollapsed
    localStorage.setItem(STORAGE_KEY, String(next))
    return { sidebarCollapsed: next }
  }),
  setSidebarCollapsed: (v) => {
    localStorage.setItem(STORAGE_KEY, String(v))
    set({ sidebarCollapsed: v })
  },
}))
"@ | Set-Content "frontend/src/store/uiStore.ts"

# ============================================================
# components/Sidebar.tsx
# ============================================================
@'
import { NavLink, useNavigate } from 'react-router-dom'
import { LayoutDashboard, Building2, Calendar, FileText, Settings, LogOut, ChevronLeft, ChevronRight, Search } from 'lucide-react'
import { useAuthStore } from '../store/authStore'
import { useUIStore } from '../store/uiStore'

interface NavItem {
  to: string
  label: string
  icon: React.ComponentType<{ size?: number; className?: string }>
}

const NAV_PRINCIPAL: NavItem[] = [
  { to: '/dashboard',     label: 'Dashboard',     icon: LayoutDashboard },
  { to: '/empresas',      label: 'Empresas',      icon: Building2 },
  { to: '/calendario',    label: 'Calendario',    icon: Calendar },
  { to: '/declaraciones', label: 'Declaraciones', icon: FileText },
]

const NAV_CUENTA: NavItem[] = [
  { to: '/configuracion', label: 'Configuracion', icon: Settings },
]

export default function Sidebar() {
  const navigate = useNavigate()
  const { usuario, logout } = useAuthStore()
  const { sidebarCollapsed, toggleSidebar } = useUIStore()
  const handleLogout = () => { logout(); navigate('/login') }
  const collapsed = sidebarCollapsed
  const iniciales = usuario ? `${usuario.nombre[0]}${usuario.apellido[0]}`.toUpperCase() : '?'

  return (
    <aside
      className="bg-sidebar text-sidebar-text flex flex-col transition-all duration-200 h-screen sticky top-0"
      style={{ width: collapsed ? '64px' : '240px' }}
    >
      <div className="flex items-center justify-between px-3 py-3 border-b border-sidebar-border relative" style={{ minHeight: '56px' }}>
        {!collapsed && (
          <div className="flex items-center gap-2 overflow-hidden">
            <div className="w-8 h-8 bg-brand-800 rounded-lg flex items-center justify-center flex-shrink-0">
              <span className="text-white font-bold text-sm">F</span>
            </div>
            <span className="font-heading font-bold text-white text-base truncate">Felicita</span>
          </div>
        )}
        {collapsed && (
          <div className="w-8 h-8 bg-brand-800 rounded-lg flex items-center justify-center mx-auto">
            <span className="text-white font-bold text-sm">F</span>
          </div>
        )}
        <button
          onClick={toggleSidebar}
          className="p-1.5 hover:bg-sidebar-hover rounded-md transition-colors flex-shrink-0"
          title={collapsed ? 'Expandir' : 'Colapsar'}
          style={collapsed ? { position: 'absolute', top: 12, right: -12, background: '#1E293B', border: '1px solid #334155', zIndex: 10 } : {}}
        >
          {collapsed ? <ChevronRight size={16} className="text-sidebar-text" /> : <ChevronLeft size={16} className="text-sidebar-text" />}
        </button>
      </div>

      {!collapsed && (
        <div className="px-3 pt-3">
          <button className="w-full flex items-center gap-2 px-3 py-2 text-sm text-sidebar-muted bg-sidebar-hover rounded-lg hover:bg-sidebar-hover/80 transition-colors">
            <Search size={14} />
            <span>Buscar...</span>
            <span className="ml-auto text-xs border border-slate-600 rounded px-1 py-0.5 font-mono">Ctrl+K</span>
          </button>
        </div>
      )}

      <nav className="flex-1 px-2 py-3 overflow-y-auto">
        <NavSection label="Principal" collapsed={collapsed} />
        {NAV_PRINCIPAL.map(item => <SidebarItem key={item.to} {...item} collapsed={collapsed} />)}
        <div className="mt-5">
          <NavSection label="Cuenta" collapsed={collapsed} />
          {NAV_CUENTA.map(item => <SidebarItem key={item.to} {...item} collapsed={collapsed} />)}
        </div>
      </nav>

      <div className="border-t border-sidebar-border p-3">
        {!collapsed ? (
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 bg-brand-700 rounded-full flex items-center justify-center text-white text-sm font-semibold flex-shrink-0">{iniciales}</div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-white truncate">{usuario?.nombre} {usuario?.apellido}</p>
              <p className="text-xs text-sidebar-muted truncate">Plan {usuario?.plan_actual}</p>
            </div>
            <button onClick={handleLogout} className="p-1.5 hover:bg-sidebar-hover rounded-md transition-colors text-sidebar-muted hover:text-white" title="Cerrar sesion">
              <LogOut size={16} />
            </button>
          </div>
        ) : (
          <button onClick={handleLogout} className="w-full flex justify-center p-2 hover:bg-sidebar-hover rounded-md transition-colors text-sidebar-muted hover:text-white" title={`${usuario?.nombre} - Cerrar sesion`}>
            <div className="w-9 h-9 bg-brand-700 rounded-full flex items-center justify-center text-white text-sm font-semibold">{iniciales}</div>
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

function SidebarItem({ to, label, icon: Icon, collapsed }: NavItem & { collapsed: boolean }) {
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
      {!collapsed && <span className="truncate">{label}</span>}
    </NavLink>
  )
}
'@ | Set-Content "frontend/src/components/Sidebar.tsx"
Write-Host "  [OK] Sidebar.tsx" -ForegroundColor Green

# ============================================================
# components/AppLayout.tsx
# ============================================================
@'
import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar'

export default function AppLayout() {
  return (
    <div className="flex min-h-screen bg-gray-100">
      <Sidebar />
      <main className="flex-1 min-w-0 overflow-x-hidden">
        <Outlet />
      </main>
    </div>
  )
}
'@ | Set-Content "frontend/src/components/AppLayout.tsx"
Write-Host "  [OK] AppLayout.tsx" -ForegroundColor Green

# ============================================================
# components/PageHeader.tsx
# ============================================================
@'
import { ReactNode } from 'react'

interface PageHeaderProps {
  eyebrow?: string
  title: string
  description?: string
  actions?: ReactNode
}

export default function PageHeader({ eyebrow, title, description, actions }: PageHeaderProps) {
  return (
    <div className="bg-white border-b border-gray-200 px-6 lg:px-8 py-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          {eyebrow && (
            <div className="text-[11px] font-semibold text-brand-800 uppercase tracking-wider mb-1">{eyebrow}</div>
          )}
          <h1 className="text-2xl font-heading font-bold text-gray-900">{title}</h1>
          {description && <p className="text-sm text-gray-500 mt-1">{description}</p>}
        </div>
        {actions && <div className="flex items-center gap-2">{actions}</div>}
      </div>
    </div>
  )
}
'@ | Set-Content "frontend/src/components/PageHeader.tsx"
Write-Host "  [OK] PageHeader.tsx" -ForegroundColor Green

# ============================================================
# components/ui.tsx
# ============================================================
@'
import { ReactNode } from 'react'

interface MetricCardProps {
  label: string
  value: string | number
  accent?: 'brand' | 'success' | 'warning' | 'danger' | 'neutral'
  icon?: ReactNode
}

const ACCENT_STYLES = {
  brand:   { border: 'border-l-brand-800',   text: 'text-gray-900' },
  success: { border: 'border-l-success-600', text: 'text-success-900' },
  warning: { border: 'border-l-warning-600', text: 'text-warning-900' },
  danger:  { border: 'border-l-danger-600',  text: 'text-danger-900' },
  neutral: { border: 'border-l-gray-300',    text: 'text-gray-900' },
}

export function MetricCard({ label, value, accent = 'neutral', icon }: MetricCardProps) {
  const styles = ACCENT_STYLES[accent]
  return (
    <div className={`bg-white rounded-xl border border-gray-200 border-l-4 ${styles.border} p-4 shadow-card`}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{label}</p>
          <p className={`text-3xl font-heading font-bold mt-1.5 font-mono ${styles.text}`}>{value}</p>
        </div>
        {icon && <div className="text-gray-300">{icon}</div>}
      </div>
    </div>
  )
}

interface AlertBadgeProps {
  nivel: 'VERDE' | 'AMARILLO' | 'ROJO'
  showLabel?: boolean
}

export function AlertBadge({ nivel, showLabel = true }: AlertBadgeProps) {
  const config = {
    VERDE:    { dot: 'bg-success-600', bg: 'bg-success-50', text: 'text-success-900', label: 'Al dia' },
    AMARILLO: { dot: 'bg-warning-600', bg: 'bg-warning-50', text: 'text-warning-900', label: 'Atencion' },
    ROJO:     { dot: 'bg-danger-600',  bg: 'bg-danger-50',  text: 'text-danger-900',  label: 'Critico' },
  }[nivel]
  if (!showLabel) return <span className={`inline-block w-2.5 h-2.5 rounded-full ${config.dot}`} />
  return (
    <span className={`inline-flex items-center gap-1.5 ${config.bg} ${config.text} text-xs font-semibold px-2 py-0.5 rounded-full`}>
      <span className={`w-1.5 h-1.5 rounded-full ${config.dot}`} />
      {config.label}
    </span>
  )
}

interface EmptyStateProps {
  icon?: ReactNode
  title: string
  description?: string
  action?: ReactNode
}

export function EmptyState({ icon, title, description, action }: EmptyStateProps) {
  return (
    <div className="p-12 text-center">
      {icon && <div className="flex justify-center mb-3 text-gray-300">{icon}</div>}
      <p className="text-base font-medium text-gray-900">{title}</p>
      {description && <p className="text-sm text-gray-500 mt-1">{description}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  )
}
'@ | Set-Content "frontend/src/components/ui.tsx"
Write-Host "  [OK] ui.tsx (MetricCard, AlertBadge, EmptyState)" -ForegroundColor Green

# ============================================================
# pages/Login.tsx
# ============================================================
@'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../services/api'
import { useAuthStore } from '../store/authStore'

export default function LoginPage() {
  const navigate = useNavigate()
  const { login } = useAuthStore()
  const [form, setForm] = useState({ email: '', password: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true); setError('')
    try {
      const { data } = await api.post('/auth/login', form)
      login(data.access_token, data.usuario)
      navigate('/dashboard')
    } catch (err: any) {
      setError(err.response?.data?.detail || 'Error al iniciar sesion')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex">
      <div className="flex-1 flex items-center justify-center p-8 bg-white">
        <div className="w-full max-w-sm">
          <div className="mb-8">
            <div className="w-12 h-12 bg-brand-800 rounded-xl flex items-center justify-center mb-5">
              <span className="text-white text-xl font-bold">F</span>
            </div>
            <h1 className="text-3xl font-heading font-bold text-gray-900">Bienvenido de vuelta</h1>
            <p className="text-gray-500 text-sm mt-2">Inicia sesion para acceder a tu panel contable</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="label">Email</label>
              <input type="email" value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} className="input" placeholder="contador@email.com" required />
            </div>
            <div>
              <label className="label">Contrasena</label>
              <input type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} className="input" placeholder="........" required />
            </div>

            {error && (
              <div className="bg-danger-50 border border-danger-600/20 text-danger-900 text-sm rounded-lg px-4 py-2.5">{error}</div>
            )}

            <button type="submit" disabled={loading} className="btn-primary w-full py-2.5 disabled:opacity-50">
              {loading ? 'Ingresando...' : 'Iniciar sesion'}
            </button>
          </form>

          <div className="mt-8 pt-6 border-t border-gray-100">
            <p className="text-xs text-gray-400 text-center">
              Prueba: <span className="font-mono">ana.perez@felicita.pe</span> / <span className="font-mono">contador123</span>
            </p>
          </div>
        </div>
      </div>

      <div className="hidden lg:flex flex-1 bg-sidebar text-white items-center justify-center p-12 relative overflow-hidden">
        <div className="absolute inset-0 opacity-[0.03]" style={{ backgroundImage: 'radial-gradient(circle at 1px 1px, white 1px, transparent 0)', backgroundSize: '32px 32px' }} />
        <div className="relative z-10 max-w-md">
          <div className="inline-block bg-brand-800 text-xs font-semibold uppercase tracking-wider px-3 py-1 rounded-full mb-6">
            Felicita Plataforma contable
          </div>
          <h2 className="text-4xl font-heading font-bold mb-4 leading-tight">
            Gestiona todas tus empresas desde un solo lugar
          </h2>
          <p className="text-slate-300 text-base leading-relaxed">
            Calendario tributario consolidado, alertas automaticas y generacion de declaraciones para toda tu cartera de clientes.
          </p>
          <div className="grid grid-cols-3 gap-4 mt-10">
            <div>
              <div className="text-2xl font-heading font-bold text-white font-mono">30+</div>
              <div className="text-xs text-slate-400 mt-1">Empresas por contador</div>
            </div>
            <div>
              <div className="text-2xl font-heading font-bold text-white font-mono">100%</div>
              <div className="text-xs text-slate-400 mt-1">Compliance SUNAT</div>
            </div>
            <div>
              <div className="text-2xl font-heading font-bold text-white font-mono">24/7</div>
              <div className="text-xs text-slate-400 mt-1">Monitoreo automatico</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
'@ | Set-Content "frontend/src/pages/Login.tsx"
Write-Host "  [OK] Login.tsx" -ForegroundColor Green

# ============================================================
# pages/contador/Dashboard.tsx
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
    api.get('/empresas').then(r => setEmpresas(r.data)).finally(() => setLoading(false))
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
          <button className="btn-primary flex items-center gap-2">
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
              action={<button className="btn-primary flex items-center gap-2 mx-auto"><Plus size={16} /> Agregar empresa</button>}
            />
          ) : (
            <div className="divide-y divide-gray-100">
              {empresasOrdenadas.map(empresa => <EmpresaRow key={empresa.id} empresa={empresa} />)}
            </div>
          )}
        </div>
      </div>
    </>
  )
}

function EmpresaRow({ empresa }: { empresa: Empresa }) {
  return (
    <div className="px-5 py-4 flex items-center justify-between hover:bg-gray-50 transition-colors group">
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
  )
}
'@ | Set-Content "frontend/src/pages/contador/Dashboard.tsx"
Write-Host "  [OK] Dashboard.tsx" -ForegroundColor Green

# ============================================================
# pages/contador/Calendario.tsx
# ============================================================
@'
import { useState, useEffect } from 'react'
import { ChevronLeft, ChevronRight, Calendar, Clock, CheckCircle2 } from 'lucide-react'
import api from '../../services/api'
import PageHeader from '../../components/PageHeader'
import { AlertBadge, EmptyState } from '../../components/ui'

interface EventoCalendario {
  id: number
  empresa_id: number
  empresa_nombre: string
  empresa_ruc: string
  empresa_color: string
  tipo_evento: string
  titulo: string
  descripcion: string | null
  fecha_vencimiento: string
  estado: string
  nivel_alerta: 'VERDE' | 'AMARILLO' | 'ROJO'
}
interface DiasMes { [fecha: string]: EventoCalendario[] }
interface ProximoVencimiento {
  id: number
  empresa_id: number
  empresa_nombre: string
  empresa_ruc: string
  empresa_color: string
  nivel_alerta: 'VERDE' | 'AMARILLO' | 'ROJO'
  tipo_evento: string
  fecha_vencimiento: string
  dias_restantes: number
  estado: string
}

const MESES = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre']
const DIAS_SEMANA = ['Lun','Mar','Mie','Jue','Vie','Sab','Dom']
const getDiasDelMes = (a: number, m: number) => new Date(a, m, 0).getDate()
const getPrimerDia = (a: number, m: number) => { const d = new Date(a, m-1, 1).getDay(); return d === 0 ? 6 : d - 1 }
const formatFecha = (f: string) => { const [y,m,d] = f.split('-'); return `${d}/${m}/${y}` }

export default function CalendarioPage() {
  const hoy = new Date()
  const [ano, setAno] = useState(hoy.getFullYear())
  const [mes, setMes] = useState(hoy.getMonth() + 1)
  const [diasMes, setDiasMes] = useState<DiasMes>({})
  const [proximos, setProximos] = useState<ProximoVencimiento[]>([])
  const [diaSeleccionado, setDiaSeleccionado] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [totalEventos, setTotalEventos] = useState(0)

  useEffect(() => { cargarCalendario() }, [ano, mes])
  useEffect(() => { cargarProximos() }, [])

  async function cargarCalendario() {
    setLoading(true)
    try {
      const { data } = await api.get(`/calendario/mes/${ano}/${mes}`)
      setDiasMes(data.dias); setTotalEventos(data.total_eventos)
    } finally { setLoading(false) }
  }
  async function cargarProximos() {
    const { data } = await api.get('/calendario/proximos?dias=14')
    setProximos(data.vencimientos)
  }
  async function marcarCompletado(id: number) {
    await api.put(`/calendario/${id}/completar`)
    cargarCalendario(); cargarProximos()
  }
  function navMes(delta: number) {
    let nm = mes + delta, na = ano
    if (nm > 12) { nm = 1; na++ }
    if (nm < 1) { nm = 12; na-- }
    setMes(nm); setAno(na); setDiaSeleccionado(null)
  }

  const totalDias = getDiasDelMes(ano, mes)
  const primerDia = getPrimerDia(ano, mes)
  const celdas: (number | null)[] = [...Array(primerDia).fill(null), ...Array.from({length: totalDias}, (_, i) => i + 1)]
  while (celdas.length % 7 !== 0) celdas.push(null)
  const hoyStr = `${hoy.getFullYear()}-${String(hoy.getMonth()+1).padStart(2,'0')}-${String(hoy.getDate()).padStart(2,'0')}`
  const eventosDelDia = diaSeleccionado ? (diasMes[diaSeleccionado] || []) : []

  return (
    <>
      <PageHeader eyebrow="Obligaciones tributarias" title="Calendario Tributario" description="Vista consolidada de todos los vencimientos" />

      <div className="p-6 lg:p-8 grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-4">
          <div className="card">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
              <button onClick={() => navMes(-1)} className="p-2 hover:bg-gray-100 rounded-lg transition-colors">
                <ChevronLeft size={18} className="text-gray-600" />
              </button>
              <div className="text-center">
                <h2 className="font-heading font-bold text-gray-900 text-lg">{MESES[mes-1]} {ano}</h2>
                <p className="text-xs text-gray-500 mt-0.5">
                  {totalEventos} vencimiento{totalEventos !== 1 ? 's' : ''} este mes
                </p>
              </div>
              <button onClick={() => navMes(1)} className="p-2 hover:bg-gray-100 rounded-lg transition-colors">
                <ChevronRight size={18} className="text-gray-600" />
              </button>
            </div>

            <div className="p-4">
              <div className="grid grid-cols-7 mb-2">
                {DIAS_SEMANA.map(d => (
                  <div key={d} className="text-center text-[11px] font-semibold text-gray-400 uppercase tracking-wider py-2">{d}</div>
                ))}
              </div>
              {loading ? (
                <div className="h-64 flex items-center justify-center text-gray-400 text-sm">Cargando...</div>
              ) : (
                <div className="grid grid-cols-7 gap-1">
                  {celdas.map((dia, idx) => {
                    if (!dia) return <div key={`e-${idx}`} />
                    const fechaStr = `${ano}-${String(mes).padStart(2,'0')}-${String(dia).padStart(2,'0')}`
                    const eventos = diasMes[fechaStr] || []
                    const esHoy = fechaStr === hoyStr
                    const sel = fechaStr === diaSeleccionado
                    const tiene = eventos.length > 0
                    const tieneRojo = eventos.some(e => e.nivel_alerta === 'ROJO')
                    const tieneAmarillo = eventos.some(e => e.nivel_alerta === 'AMARILLO')
                    return (
                      <button
                        key={fechaStr}
                        onClick={() => setDiaSeleccionado(sel ? null : fechaStr)}
                        className={`relative rounded-lg text-sm font-medium transition-all min-h-[64px] p-1.5 flex flex-col items-center justify-start ${
                          esHoy && !sel ? 'ring-2 ring-brand-800' : ''
                        } ${
                          sel ? 'bg-brand-800 text-white' : tiene ? 'bg-brand-50 hover:bg-brand-100' : 'hover:bg-gray-50'
                        }`}
                      >
                        <span className={`${esHoy && !sel ? 'text-brand-800 font-bold' : ''}`}>{dia}</span>
                        {tiene && (
                          <div className="flex gap-0.5 mt-1 flex-wrap justify-center">
                            {eventos.slice(0, 3).map((ev, i) => (
                              <div key={i} className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: sel ? 'white' : ev.empresa_color }} />
                            ))}
                            {eventos.length > 3 && (
                              <span className={`text-[10px] ml-0.5 ${sel ? 'text-white/80' : 'text-gray-500'}`}>+{eventos.length - 3}</span>
                            )}
                          </div>
                        )}
                        {!sel && tieneRojo && <div className="absolute top-1 right-1 w-1.5 h-1.5 bg-danger-600 rounded-full" />}
                        {!sel && !tieneRojo && tieneAmarillo && <div className="absolute top-1 right-1 w-1.5 h-1.5 bg-warning-600 rounded-full" />}
                      </button>
                    )
                  })}
                </div>
              )}
            </div>
          </div>

          {diaSeleccionado && (
            <div className="card">
              <div className="px-5 py-4 border-b border-gray-100 flex items-center gap-2">
                <Calendar size={16} className="text-brand-800" />
                <h3 className="font-heading font-bold text-gray-900">Vencimientos del {formatFecha(diaSeleccionado)}</h3>
              </div>
              {eventosDelDia.length === 0 ? (
                <EmptyState title="No hay vencimientos este dia" />
              ) : (
                <div className="divide-y divide-gray-100">
                  {eventosDelDia.map(ev => (
                    <div key={ev.id} className="px-5 py-3 flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-1 h-10 rounded-full flex-shrink-0" style={{ backgroundColor: ev.empresa_color }} />
                        <div>
                          <p className="font-medium text-gray-900 text-sm">{ev.empresa_nombre}</p>
                          <p className="text-xs text-gray-500 font-mono">RUC {ev.empresa_ruc}</p>
                          {ev.descripcion && <p className="text-xs text-gray-400 mt-0.5">{ev.descripcion}</p>}
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className={`text-[11px] px-2 py-0.5 rounded-full font-semibold ${
                          ev.estado === 'COMPLETADO' ? 'bg-success-50 text-success-900' :
                          ev.estado === 'VENCIDO' ? 'bg-danger-50 text-danger-900' :
                          'bg-gray-100 text-gray-600'
                        }`}>{ev.estado}</span>
                        {ev.estado === 'PENDIENTE' && (
                          <button onClick={() => marcarCompletado(ev.id)} className="p-1.5 hover:bg-success-50 rounded-lg transition-colors" title="Marcar completado">
                            <CheckCircle2 size={18} className="text-success-600" />
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        <div className="space-y-4">
          <div className="card">
            <div className="px-5 py-4 border-b border-gray-100 flex items-center gap-2">
              <Clock size={16} className="text-warning-600" />
              <h3 className="font-heading font-bold text-gray-900">Proximos 14 dias</h3>
            </div>
            {proximos.length === 0 ? (
              <EmptyState title="Sin vencimientos proximos" />
            ) : (
              <div className="divide-y divide-gray-100">
                {proximos.map(v => (
                  <div key={v.id} className="px-5 py-3">
                    <div className="flex items-start justify-between mb-1 gap-2">
                      <div className="flex items-center gap-2 min-w-0">
                        <div className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ backgroundColor: v.empresa_color }} />
                        <p className="text-sm font-medium text-gray-900 truncate">{v.empresa_nombre}</p>
                      </div>
                      <AlertBadge nivel={v.nivel_alerta} showLabel={false} />
                    </div>
                    <p className="text-xs text-gray-500 ml-3.5">{v.tipo_evento.replace('_', ' ')} - {formatFecha(v.fecha_vencimiento)}</p>
                    <div className={`mt-1 ml-3.5 text-xs font-semibold ${
                      v.dias_restantes === 0 ? 'text-danger-600' :
                      v.dias_restantes <= 3 ? 'text-warning-600' :
                      v.dias_restantes <= 7 ? 'text-gray-600' : 'text-gray-500'
                    }`}>
                      {v.dias_restantes === 0 ? 'Vence HOY' :
                       v.dias_restantes === 1 ? 'Vence manana' :
                       `Faltan ${v.dias_restantes} dias`}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="card p-4">
            <h3 className="font-heading font-bold text-gray-900 text-sm mb-3">Leyenda</h3>
            <div className="space-y-2 text-xs text-gray-600">
              <div className="flex items-center gap-2"><span className="w-2 h-2 rounded-full bg-success-600" />Al dia</div>
              <div className="flex items-center gap-2"><span className="w-2 h-2 rounded-full bg-warning-600" />Atencion</div>
              <div className="flex items-center gap-2"><span className="w-2 h-2 rounded-full bg-danger-600" />Critico</div>
              <div className="flex items-center gap-2"><span className="w-3 h-3 ring-2 ring-brand-800 rounded" />Dia actual</div>
            </div>
          </div>
        </div>
      </div>
    </>
  )
}
'@ | Set-Content "frontend/src/pages/contador/Calendario.tsx"
Write-Host "  [OK] Calendario.tsx" -ForegroundColor Green

# ============================================================
# App.tsx
# ============================================================
@'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAuthStore } from './store/authStore'
import LoginPage from './pages/Login'
import AppLayout from './components/AppLayout'
import DashboardContador from './pages/contador/Dashboard'
import CalendarioPage from './pages/contador/Calendario'

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
          <Route path="/empresas" element={<PlaceholderPage title="Empresas" />} />
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
Write-Host "  [OK] App.tsx" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Redisenio aplicado!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vite debe haberse recargado solo." -ForegroundColor Yellow
Write-Host "Si no, reinicia: npm run dev" -ForegroundColor Yellow
Write-Host ""
