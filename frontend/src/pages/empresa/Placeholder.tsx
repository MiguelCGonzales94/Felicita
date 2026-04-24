import { useOutletContext } from 'react-router-dom'
import { Construction } from 'lucide-react'
import PageHeader from '../../components/PageHeader'
import type { Empresa } from '../../types/empresa'

interface Ctx { empresa: Empresa }

interface PlaceholderProps {
  titulo: string
  descripcion: string
  icono: React.ComponentType<{ size?: number; className?: string }>
  eyebrow?: string
}

export default function ModuloPlaceholder({ titulo, descripcion, icono: Icon, eyebrow }: PlaceholderProps) {
  const { empresa } = useOutletContext<Ctx>()

  return (
    <>
      <PageHeader
        eyebrow={eyebrow || empresa.razon_social}
        title={titulo}
        description={descripcion}
      />
      <div className="p-6 lg:p-8">
        <div className="card p-12 text-center">
          <div className="w-16 h-16 bg-brand-50 rounded-full flex items-center justify-center mx-auto mb-4">
            <Icon size={28} className="text-brand-800" />
          </div>
          <h2 className="font-heading font-bold text-gray-900 text-lg mb-2">
            Modulo en construccion
          </h2>
          <p className="text-sm text-gray-500 max-w-md mx-auto">
            Estamos trabajando en este modulo. Muy pronto estara disponible con todas sus funcionalidades.
          </p>
          <div className="inline-flex items-center gap-2 mt-4 text-xs text-gray-400 bg-gray-50 px-3 py-1.5 rounded-full">
            <Construction size={12} />
            Proximamente
          </div>
        </div>
      </div>
    </>
  )
}
