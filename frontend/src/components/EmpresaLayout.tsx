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
