import { ReactNode } from 'react'

interface MetricCardProps {
  label: string
  value: string | number
  accent?: 'brand' | 'success' | 'warning' | 'danger' | 'neutral'
  icon?: ReactNode
}

const ACCENT_STYLES = {
  brand:   { border: 'border-l-brand-800',   text: 'text-gray-900' },
  success: { border: 'border-l-success-600', text: 'text-success-900' },
  warning: { border: 'border-l-warning-600', text: 'text-warning-900' },
  danger:  { border: 'border-l-danger-600',  text: 'text-danger-900' },
  neutral: { border: 'border-l-gray-300',    text: 'text-gray-900' },
}

export function MetricCard({ label, value, accent = 'neutral', icon }: MetricCardProps) {
  const styles = ACCENT_STYLES[accent]
  return (
    <div className={`bg-white rounded-xl border border-gray-200 border-l-4 ${styles.border} p-4 shadow-card`}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">{label}</p>
          <p className={`text-3xl font-heading font-bold mt-1.5 font-mono ${styles.text}`}>{value}</p>
        </div>
        {icon && <div className="text-gray-300">{icon}</div>}
      </div>
    </div>
  )
}

interface AlertBadgeProps {
  nivel: 'VERDE' | 'AMARILLO' | 'ROJO'
  showLabel?: boolean
}

export function AlertBadge({ nivel, showLabel = true }: AlertBadgeProps) {
  const config = {
    VERDE:    { dot: 'bg-success-600', bg: 'bg-success-50', text: 'text-success-900', label: 'Al dia' },
    AMARILLO: { dot: 'bg-warning-600', bg: 'bg-warning-50', text: 'text-warning-900', label: 'Atencion' },
    ROJO:     { dot: 'bg-danger-600',  bg: 'bg-danger-50',  text: 'text-danger-900',  label: 'Critico' },
  }[nivel]
  if (!showLabel) return <span className={`inline-block w-2.5 h-2.5 rounded-full ${config.dot}`} />
  return (
    <span className={`inline-flex items-center gap-1.5 ${config.bg} ${config.text} text-xs font-semibold px-2 py-0.5 rounded-full`}>
      <span className={`w-1.5 h-1.5 rounded-full ${config.dot}`} />
      {config.label}
    </span>
  )
}

interface EmptyStateProps {
  icon?: ReactNode
  title: string
  description?: string
  action?: ReactNode
}

export function EmptyState({ icon, title, description, action }: EmptyStateProps) {
  return (
    <div className="p-12 text-center">
      {icon && <div className="flex justify-center mb-3 text-gray-300">{icon}</div>}
      <p className="text-base font-medium text-gray-900">{title}</p>
      {description && <p className="text-sm text-gray-500 mt-1">{description}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  )
}
