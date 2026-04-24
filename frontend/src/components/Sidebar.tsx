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
