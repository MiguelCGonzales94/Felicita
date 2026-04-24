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
