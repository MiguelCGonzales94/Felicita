import { useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { Settings as SettingsIcon } from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import EmpresaForm from '../../components/EmpresaForm'
import { empresaService } from '../../services/empresaService'
import type { EmpresaDetalle } from '../../types/empresa'

interface Ctx {
  empresa: EmpresaDetalle
  recargar: () => void
}

export default function ConfiguracionEmpresa() {
  const { empresa, recargar } = useOutletContext<Ctx>()
  const [guardando, setGuardando] = useState(false)
  const [mensaje, setMensaje] = useState('')

  async function handleGuardar(data: any) {
    setGuardando(true)
    setMensaje('')
    try {
      await empresaService.actualizar(empresa.id, data)
      setMensaje('Cambios guardados correctamente')
      recargar()
      setTimeout(() => setMensaje(''), 3000)
    } catch (err: any) {
      throw err
    } finally {
      setGuardando(false)
    }
  }

  return (
    <>
      <PageHeader
        eyebrow={empresa.razon_social}
        title="Configuracion de la empresa"
        description="Datos, contacto y credenciales SUNAT"
      />

      <div className="p-6 lg:p-8">
        {mensaje && (
          <div className="bg-success-50 border border-success-600/20 text-success-900 text-sm rounded-lg px-4 py-2.5 mb-4">
            {mensaje}
          </div>
        )}

        <div className="card p-6">
          <EmpresaForm
            empresa={empresa}
            onSubmit={handleGuardar}
            onCancel={() => window.history.back()}
            loading={guardando}
          />
        </div>
      </div>
    </>
  )
}
