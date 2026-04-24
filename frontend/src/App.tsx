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
