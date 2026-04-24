import { ReactNode } from 'react'

interface PageHeaderProps {
  eyebrow?: string
  title: string
  description?: string
  actions?: ReactNode
}

export default function PageHeader({ eyebrow, title, description, actions }: PageHeaderProps) {
  return (
    <div className="bg-white border-b border-gray-200 px-6 lg:px-8 py-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          {eyebrow && (
            <div className="text-[11px] font-semibold text-brand-800 uppercase tracking-wider mb-1">{eyebrow}</div>
          )}
          <h1 className="text-2xl font-heading font-bold text-gray-900">{title}</h1>
          {description && <p className="text-sm text-gray-500 mt-1">{description}</p>}
        </div>
        {actions && <div className="flex items-center gap-2">{actions}</div>}
      </div>
    </div>
  )
}
