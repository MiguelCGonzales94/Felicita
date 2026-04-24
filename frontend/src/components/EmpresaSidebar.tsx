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
