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
