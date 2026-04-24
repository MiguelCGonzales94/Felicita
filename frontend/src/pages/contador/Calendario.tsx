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
