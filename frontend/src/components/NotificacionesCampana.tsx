import { useEffect, useState, useRef } from 'react'
import { Bell, X, Mail, MessageCircle, Check, CheckCheck } from 'lucide-react'
import { notificacionService } from '../services/notificacionService'
import type { Notificacion } from '../services/notificacionService'

export default function NotificacionesCampana() {
  const [abierto, setAbierto] = useState(false)
  const [notifs, setNotifs] = useState<Notificacion[]>([])
  const [noLeidas, setNoLeidas] = useState(0)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => { cargar() }, [])
  useEffect(() => {
    const interval = setInterval(cargar, 60000) // cada 60s
    return () => clearInterval(interval)
  }, [])
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setAbierto(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [])

  async function cargar() {
    try {
      const data = await notificacionService.listar(undefined, 15)
      setNotifs(data.notificaciones)
      setNoLeidas(data.no_leidas)
    } catch {}
  }

  async function marcarLeida(id: number) {
    await notificacionService.marcarLeida(id)
    setNotifs(p => p.map(n => n.id === id ? { ...n, leido: true } : n))
    setNoLeidas(p => Math.max(0, p - 1))
  }

  async function marcarTodas() {
    await notificacionService.marcarTodasLeidas()
    setNotifs(p => p.map(n => ({ ...n, leido: true })))
    setNoLeidas(0)
  }

  return (
    <div ref={ref} className="relative">
      <button onClick={() => setAbierto(!abierto)} className="relative p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
        <Bell size={18} className="text-gray-600 dark:text-gray-300" />
        {noLeidas > 0 && (
          <span className="absolute -top-0.5 -right-0.5 bg-danger-600 text-white text-[9px] font-bold min-w-[16px] h-4 flex items-center justify-center rounded-full px-1">
            {noLeidas > 9 ? '9+' : noLeidas}
          </span>
        )}
      </button>

      {abierto && (
        <div className="absolute right-0 top-full mt-2 w-96 bg-white dark:bg-gray-800 rounded-xl shadow-xl border border-gray-200 dark:border-gray-700 z-50 overflow-hidden">
          <div className="px-4 py-3 border-b border-gray-100 dark:border-gray-700 flex items-center justify-between">
            <h3 className="font-heading font-bold text-sm text-gray-900 dark:text-white">Notificaciones</h3>
            <div className="flex gap-2">
              {noLeidas > 0 && (
                <button onClick={marcarTodas} className="text-[11px] text-brand-800 hover:underline flex items-center gap-1">
                  <CheckCheck size={12} /> Marcar todas
                </button>
              )}
              <button onClick={() => setAbierto(false)} className="text-gray-400 hover:text-gray-600"><X size={14} /></button>
            </div>
          </div>

          <div className="max-h-[400px] overflow-y-auto divide-y divide-gray-50 dark:divide-gray-700">
            {notifs.length === 0 ? (
              <div className="py-8 text-center text-gray-400 text-sm">Sin notificaciones</div>
            ) : notifs.map(n => (
              <div key={n.id} onClick={() => !n.leido && marcarLeida(n.id)}
                className={`px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-700/50 cursor-pointer transition-colors ${!n.leido ? 'bg-brand-50/30 dark:bg-brand-900/10' : ''}`}>
                <div className="flex items-start gap-2">
                  {!n.leido && <div className="w-2 h-2 rounded-full bg-brand-800 flex-shrink-0 mt-1.5" />}
                  <div className="flex-1 min-w-0">
                    <p className={`text-xs font-medium truncate ${!n.leido ? 'text-gray-900 dark:text-white' : 'text-gray-600 dark:text-gray-400'}`}>
                      {n.titulo}
                    </p>
                    <p className="text-[11px] text-gray-500 mt-0.5 line-clamp-2">{n.mensaje}</p>
                    <div className="flex items-center gap-2 mt-1">
                      <span className="text-[10px] text-gray-400">{new Date(n.fecha_envio).toLocaleDateString('es-PE')}</span>
                      {n.enviado_email && <Mail size={10} className="text-success-600" title="Enviado por email" />}
                      {n.enviado_whatsapp && <MessageCircle size={10} className="text-success-600" title="Enviado por WhatsApp" />}
                    </div>
                  </div>
                  <span className="text-xs font-mono font-bold text-gray-900 dark:text-white flex-shrink-0">
                    S/ {n.total_a_pagar.toLocaleString('es-PE', { minimumFractionDigits: 2 })}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
