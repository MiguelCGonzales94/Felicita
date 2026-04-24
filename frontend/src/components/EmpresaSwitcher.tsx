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
